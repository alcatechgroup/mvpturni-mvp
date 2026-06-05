<?php

// STORY-058 (CA-2, CA-3, CA-4, CA-9) — gate de habitualidade DO ACEITE (PDR-002 sobre a tabela
// `turnos`, índice de ADR-006/ADR-015). Diferente do GateHabitualidade da candidatura (STORY-050,
// que conta candidaturas vivas), aqui a contagem é de TURNOS reais do par profissional ×
// estabelecimento na semana corrida (segunda→domingo) da vaga-alvo. Turnos cancelados e no-show
// não contam (a alocação foi desfeita — PDR-007).

use App\Domain\Turno\GateHabitualidadeAceite;
use App\Domain\Turno\HabitualidadeAceite;
use App\Enums\TurnoStatus;
use App\Models\ProfissionalProfile;
use App\Models\Turno;
use App\Models\User;
use App\Models\Vaga;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

/** Quarta-feira da semana-alvo, 18h — base estável para as bordas de semana. */
function inicioAlvo(): CarbonImmutable
{
    return CarbonImmutable::now()->addWeeks(2)->startOfWeek()->addDays(2)->setTime(18, 0);
}

function profAceite(string $tipo = 'PF'): User
{
    $user = User::factory()->profissional()->ativo()->create();
    ProfissionalProfile::factory()->create(['user_id' => $user->id, 'tipo_pessoa' => $tipo]);

    return $user;
}

function vagaAlvo(User $contratante, ?CarbonImmutable $inicio = null): Vaga
{
    $inicio ??= inicioAlvo();

    return Vaga::factory()->create([
        'contratante_id' => $contratante->id,
        'data_inicio' => $inicio,
        'data_fim' => $inicio->addHours(6),
    ]);
}

/** Turno do par (profissional × contratante=estabelecimento) com início em $inicio. */
function turnoNaSemana(User $prof, User $contratante, CarbonImmutable $inicio, TurnoStatus $status = TurnoStatus::Confirmado): Turno
{
    return Turno::factory()->status($status)->create([
        'profissional_id' => $prof->id,
        'contratante_id' => $contratante->id,
        'estabelecimento_id' => $contratante->id,
        'data_inicio' => $inicio,
        'data_fim' => $inicio->addHours(6),
    ]);
}

// ─── (a) caminho feliz — 0/1 turnos liberam ──────────────────────────────────

it('libera quando o par não tem nenhum turno na semana (PF e PJ)', function (string $tipo) {
    $contratante = User::factory()->contratante()->ativo()->create();
    $prof = profAceite($tipo);

    $resultado = (new GateHabitualidadeAceite)->verificar($prof, vagaAlvo($contratante));

    expect($resultado)->toBe(HabitualidadeAceite::Liberado);
})->with(['PF', 'MEI', 'PJ']);

it('libera a 2ª alocação da semana (1 turno existente)', function () {
    $contratante = User::factory()->contratante()->ativo()->create();
    $prof = profAceite('PF');
    turnoNaSemana($prof, $contratante, inicioAlvo()->subDay());

    $resultado = (new GateHabitualidadeAceite)->verificar($prof, vagaAlvo($contratante));

    expect($resultado)->toBe(HabitualidadeAceite::Liberado);
});

// ─── (b) casos inválidos — a 3ª bloqueia/exige override (PDR-002) ────────────

it('PF na 3ª alocação da semana → bloqueio duro', function () {
    $contratante = User::factory()->contratante()->ativo()->create();
    $prof = profAceite('PF');
    turnoNaSemana($prof, $contratante, inicioAlvo()->subDays(2));
    turnoNaSemana($prof, $contratante, inicioAlvo()->subDay());

    $resultado = (new GateHabitualidadeAceite)->verificar($prof, vagaAlvo($contratante));

    expect($resultado)->toBe(HabitualidadeAceite::BloqueadoPf);
});

it('MEI/PJ na 3ª alocação da semana → exige override do contratante', function (string $tipo) {
    $contratante = User::factory()->contratante()->ativo()->create();
    $prof = profAceite($tipo);
    turnoNaSemana($prof, $contratante, inicioAlvo()->subDays(2));
    turnoNaSemana($prof, $contratante, inicioAlvo()->subDay());

    $resultado = (new GateHabitualidadeAceite)->verificar($prof, vagaAlvo($contratante));

    expect($resultado)->toBe(HabitualidadeAceite::RequerOverride);
})->with(['MEI', 'PJ']);

it('tipo_pessoa ausente é tratado como PF (default conservador)', function () {
    $contratante = User::factory()->contratante()->ativo()->create();
    $prof = User::factory()->profissional()->ativo()->create(); // sem profile
    turnoNaSemana($prof, $contratante, inicioAlvo()->subDays(2));
    turnoNaSemana($prof, $contratante, inicioAlvo()->subDay());

    $resultado = (new GateHabitualidadeAceite)->verificar($prof, vagaAlvo($contratante));

    expect($resultado)->toBe(HabitualidadeAceite::BloqueadoPf);
});

// ─── (c) o que NÃO conta como alocação ───────────────────────────────────────

it('turnos cancelados e no-show não contam (alocação desfeita — PDR-007)', function () {
    $contratante = User::factory()->contratante()->ativo()->create();
    $prof = profAceite('PF');
    turnoNaSemana($prof, $contratante, inicioAlvo()->subDays(2), TurnoStatus::CanceladoPro);
    turnoNaSemana($prof, $contratante, inicioAlvo()->subDays(1), TurnoStatus::CanceladoEmp);
    turnoNaSemana($prof, $contratante, inicioAlvo()->subHours(30), TurnoStatus::NoShowPro);

    $resultado = (new GateHabitualidadeAceite)->verificar($prof, vagaAlvo($contratante));

    expect($resultado)->toBe(HabitualidadeAceite::Liberado);
});

it('turnos em OUTRO estabelecimento não contam', function () {
    $contratante = User::factory()->contratante()->ativo()->create();
    $outro = User::factory()->contratante()->ativo()->create();
    $prof = profAceite('PF');
    turnoNaSemana($prof, $outro, inicioAlvo()->subDays(2));
    turnoNaSemana($prof, $outro, inicioAlvo()->subDay());

    $resultado = (new GateHabitualidadeAceite)->verificar($prof, vagaAlvo($contratante));

    expect($resultado)->toBe(HabitualidadeAceite::Liberado);
});

it('turnos de OUTRO profissional não contam', function () {
    $contratante = User::factory()->contratante()->ativo()->create();
    $prof = profAceite('PF');
    $outroProf = profAceite('PF');
    turnoNaSemana($outroProf, $contratante, inicioAlvo()->subDays(2));
    turnoNaSemana($outroProf, $contratante, inicioAlvo()->subDay());

    $resultado = (new GateHabitualidadeAceite)->verificar($prof, vagaAlvo($contratante));

    expect($resultado)->toBe(HabitualidadeAceite::Liberado);
});

// ─── (d) bordas — semana corrida segunda→domingo (CA-9: virada reseta) ───────

it('transição de semana reseta a contagem (2 turnos na semana anterior liberam)', function () {
    $contratante = User::factory()->contratante()->ativo()->create();
    $prof = profAceite('PF');
    $semanaAnterior = inicioAlvo()->subWeek();
    turnoNaSemana($prof, $contratante, $semanaAnterior);
    turnoNaSemana($prof, $contratante, $semanaAnterior->addDay());

    $resultado = (new GateHabitualidadeAceite)->verificar($prof, vagaAlvo($contratante));

    expect($resultado)->toBe(HabitualidadeAceite::Liberado);
});

it('segunda 00:00 e domingo 23:59 da mesma semana contam (bordas inclusivas)', function () {
    $contratante = User::factory()->contratante()->ativo()->create();
    $prof = profAceite('PF');
    $segunda = inicioAlvo()->startOfWeek();                  // segunda 00:00:00
    $domingo = inicioAlvo()->endOfWeek()->setTime(23, 59);   // domingo 23:59
    turnoNaSemana($prof, $contratante, $segunda);
    turnoNaSemana($prof, $contratante, $domingo);

    $resultado = (new GateHabitualidadeAceite)->verificar($prof, vagaAlvo($contratante));

    expect($resultado)->toBe(HabitualidadeAceite::BloqueadoPf);
});

it('domingo 23:59 da semana ANTERIOR não conta na semana-alvo', function () {
    $contratante = User::factory()->contratante()->ativo()->create();
    $prof = profAceite('PF');
    $domingoAnterior = inicioAlvo()->startOfWeek()->subMinute(); // domingo 23:59 anterior
    turnoNaSemana($prof, $contratante, $domingoAnterior);
    turnoNaSemana($prof, $contratante, inicioAlvo()->subDay());

    $resultado = (new GateHabitualidadeAceite)->verificar($prof, vagaAlvo($contratante));

    expect($resultado)->toBe(HabitualidadeAceite::Liberado); // só 1 na semana-alvo
});
