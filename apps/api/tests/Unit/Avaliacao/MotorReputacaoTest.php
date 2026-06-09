<?php

// STORY-085 / ADR-019 Decisão 4 (CA-4/CA-5) — MotorReputacao: recomputa score/XP/nível do
// avaliado a partir dos FATOS CANÔNICOS (avaliações recebidas + turnos finalizados), nunca
// por delta. Idempotente por construção; nível é high-water-mark (sobe, nunca rebaixa).
// Núcleo do épico — cobertura-alvo ≥98% (quality-standards).

use App\Domain\Avaliacao\MotorReputacao;
use App\Enums\NivelProfissional;
use App\Enums\TurnoStatus;
use App\Models\Avaliacao;
use App\Models\ContratanteProfile;
use App\Models\ProfissionalProfile;
use App\Models\Turno;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

/** Profissional com perfil cold-start (Iniciante, 0). */
function profissionalComPerfil(): User
{
    $pro = User::factory()->profissional()->ativo()->create();
    ProfissionalProfile::factory()->coldStart()->create(['user_id' => $pro->id]);

    return $pro->fresh();
}

/** Cria N turnos finalizados do profissional e devolve a coleção. */
function turnosFinalizadosDoPro(User $pro, int $n)
{
    return Turno::factory()->count($n)->status(TurnoStatus::Finalizado)
        ->create(['profissional_id' => $pro->id]);
}

function motor(): MotorReputacao
{
    return app(MotorReputacao::class);
}

// ── Score (média das estrelas recebidas) — CA-4 ──────────────────────────────────────────

test('score é a média aritmética das estrelas recebidas, persistida com 2 casas', function () {
    $pro = profissionalComPerfil();
    $turnos = turnosFinalizadosDoPro($pro, 3);
    Avaliacao::factory()->paraTurno($turnos[0])->estrelas(5)->create();
    Avaliacao::factory()->paraTurno($turnos[1])->estrelas(4)->create();
    Avaliacao::factory()->paraTurno($turnos[2])->estrelas(3)->create(); // média 4.0

    motor()->recalcular($pro);

    expect((float) $pro->profissionalProfile->fresh()->score)->toBe(4.0);
});

test('score arredonda média não-exata para 2 casas', function () {
    $pro = profissionalComPerfil();
    $turnos = turnosFinalizadosDoPro($pro, 3);
    Avaliacao::factory()->paraTurno($turnos[0])->estrelas(5)->create();
    Avaliacao::factory()->paraTurno($turnos[1])->estrelas(5)->create();
    Avaliacao::factory()->paraTurno($turnos[2])->estrelas(4)->create(); // 14/3 = 4.666...

    motor()->recalcular($pro);

    expect((float) $pro->profissionalProfile->fresh()->score)->toBe(4.67);
});

test('sem avaliações recebidas o score é 0 (borda — lista vazia)', function () {
    $pro = profissionalComPerfil();
    turnosFinalizadosDoPro($pro, 1); // turno finalizado, ninguém avaliou ainda

    motor()->recalcular($pro);

    expect((float) $pro->profissionalProfile->fresh()->score)->toBe(0.0);
});

// ── XP (30 × turnos + bônus por estrela) — CA-4 ──────────────────────────────────────────

test('XP = 30 × turnos finalizados + bônus por estrela conforme a tabela da spec', function (int $estrelas, int $xpEsperado) {
    $pro = profissionalComPerfil();
    $turnos = turnosFinalizadosDoPro($pro, 1); // 30 base
    Avaliacao::factory()->paraTurno($turnos[0])->estrelas($estrelas)->create();

    motor()->recalcular($pro);

    expect($pro->profissionalProfile->fresh()->xp)->toBe($xpEsperado);
})->with([
    '5★ → +10' => [5, 40],
    '4★ → +3' => [4, 33],
    '3★ → 0' => [3, 30],
    '2★ → -5' => [2, 25],
    '1★ → -5' => [1, 25],
]);

test('turnos_realizados é recomputado como a contagem de turnos finalizados', function () {
    $pro = profissionalComPerfil();
    turnosFinalizadosDoPro($pro, 4);
    // turno não-finalizado não conta
    Turno::factory()->status(TurnoStatus::Ativo)->create(['profissional_id' => $pro->id]);

    motor()->recalcular($pro);

    expect((int) $pro->profissionalProfile->fresh()->turnos_realizados)->toBe(4);
});

test('finalizado_ajustado também conta como turno realizado', function () {
    $pro = profissionalComPerfil();
    turnosFinalizadosDoPro($pro, 2);
    Turno::factory()->status(TurnoStatus::FinalizadoAjustado)->create(['profissional_id' => $pro->id]);

    motor()->recalcular($pro);

    expect((int) $pro->profissionalProfile->fresh()->turnos_realizados)->toBe(3);
});

// Nota (descoberta): no MVP o XP não fica negativo via avaliações — cada avaliação recebida
// vem de um turno finalizado (+30) e o pior bônus é -5 (1–2★), logo o líquido por turno é ≥ +25.
// O negativo só surgiria das penalidades placeholder (cancelamento/no-show — PDR-007, fora do
// MVP). O que o CA-5 exige do MOTOR é: (a) coluna signed que TOLERA negativo, e (b) high-water-
// mark que não rebaixa quando o XP recomputado cai abaixo do limiar. A tolerância a negativo é
// coberta por NivelProfissionalTest (nivelPara(-50) = Iniciante); o não-rebaixamento, abaixo.

test('XP recomputado baixo NÃO rebaixa o nível (high-water-mark) — CA-5', function () {
    $pro = profissionalComPerfil();
    $pro->profissionalProfile->update(['nivel' => NivelProfissional::Elite->value]); // já foi Elite

    $turnos = turnosFinalizadosDoPro($pro, 1); // +30
    Avaliacao::factory()->paraTurno($turnos[0])->estrelas(1)->create(); // -5 → XP 25 (Iniciante)

    motor()->recalcular($pro);

    // XP modesto (25 = faixa Iniciante), mas o nível permanece Elite (nunca rebaixa).
    expect($pro->profissionalProfile->fresh()->nivel)->toBe(NivelProfissional::Elite->value)
        ->and($pro->profissionalProfile->fresh()->xp)->toBe(25);
});

// ── Nível (sobe automático nos limiares; nunca rebaixa) — CA-5 ───────────────────────────

test('nível sobe automaticamente ao cruzar o limiar de Confiável (500 XP)', function () {
    $pro = profissionalComPerfil();
    turnosFinalizadosDoPro($pro, 17); // 17 × 30 = 510 ≥ 500

    motor()->recalcular($pro);

    expect($pro->profissionalProfile->fresh()->nivel)->toBe(NivelProfissional::Confiavel->value);
});

test('nível nunca rebaixa: já Destaque, recompute com XP de Iniciante mantém Destaque', function () {
    $pro = profissionalComPerfil();
    $pro->profissionalProfile->update(['nivel' => NivelProfissional::Destaque->value]);
    turnosFinalizadosDoPro($pro, 1); // XP 30 → Iniciante

    motor()->recalcular($pro);

    expect($pro->profissionalProfile->fresh()->nivel)->toBe(NivelProfissional::Destaque->value);
});

// ── Idempotência (recompute não soma em dobro) — CA-5/F1 ─────────────────────────────────

test('recalcular duas vezes produz o mesmo XP/score (idempotente por construção)', function () {
    $pro = profissionalComPerfil();
    $turnos = turnosFinalizadosDoPro($pro, 2);
    Avaliacao::factory()->paraTurno($turnos[0])->estrelas(5)->create();
    Avaliacao::factory()->paraTurno($turnos[1])->estrelas(4)->create();

    motor()->recalcular($pro);
    $xp1 = $pro->profissionalProfile->fresh()->xp;
    $score1 = (float) $pro->profissionalProfile->fresh()->score;

    motor()->recalcular($pro);
    $xp2 = $pro->profissionalProfile->fresh()->xp;
    $score2 = (float) $pro->profissionalProfile->fresh()->score;

    expect($xp2)->toBe($xp1)->and($score2)->toBe($score1)
        ->and($xp1)->toBe(60 + 10 + 3); // 30×2 + 10 + 3 = 73
});

// ── Reciprocidade: contratante tem score, sem XP/nível — CA-4 ────────────────────────────

test('contratante avaliado recebe score (média), sem XP nem nível', function () {
    $contratante = User::factory()->contratante()->ativo()->create();
    ContratanteProfile::factory()->create(['user_id' => $contratante->id]);

    $turno = Turno::factory()->status(TurnoStatus::Finalizado)
        ->create(['contratante_id' => $contratante->id, 'estabelecimento_id' => $contratante->id]);
    Avaliacao::factory()->doProfissional()->paraTurno($turno)->estrelas(5)->create(); // avaliado = contratante

    motor()->recalcular($contratante);

    expect((float) $contratante->contratanteProfile->fresh()->score)->toBe(5.0);
});
