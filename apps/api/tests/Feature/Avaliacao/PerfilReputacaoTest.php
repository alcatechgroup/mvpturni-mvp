<?php

// STORY-085 / ADR-019 + DDR-004 (CA-6) — GET /api/perfil/{user}: reputação consultável.
// Profissional (self) vê score 1 casa + nível + XP atual + XP até o próximo nível + turnos +
// depoimentos (comentário não-vazio, mais recentes 1º). Contratante/terceiro NÃO vê o XP do
// outro (visibilidade — niveis-e-score.md). Assimetria LGPD (DDR-004): depoimento sobre o
// PROFISSIONAL mostra o estabelecimento (nominal); depoimento sobre o CONTRATANTE NÃO traz o
// nome do profissional (anônimo).

use App\Enums\TurnoStatus;
use App\Models\Avaliacao;
use App\Models\ContratanteProfile;
use App\Models\Funcao;
use App\Models\ProfissionalProfile;
use App\Models\Turno;
use App\Models\User;
use App\Models\Vaga;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

/** Profissional com perfil de reputação fixado (para asserções diretas). */
function profissionalReputado(array $profile = []): User
{
    $pro = User::factory()->profissional()->ativo()->create(['name' => 'Maria Profissional']);
    ProfissionalProfile::factory()->coldStart()->create(array_merge([
        'user_id' => $pro->id,
        'score' => 4.67,
        'nivel' => 'Confiavel',
        'xp' => 510,
        'turnos_realizados' => 17,
    ], $profile));

    return $pro->fresh();
}

/** Turno finalizado entre $pro e um contratante nomeado, na direção contratante→profissional. */
function depoimentoSobreProfissional(User $pro, string $estabelecimento, int $estrelas, ?string $comentario): Avaliacao
{
    $contratante = User::factory()->contratante()->ativo()->create();
    ContratanteProfile::factory()->create([
        'user_id' => $contratante->id,
        'nome_estabelecimento' => $estabelecimento,
        'apelido_estabelecimento' => null,
    ]);
    $turno = Turno::factory()->status(TurnoStatus::Finalizado)->create([
        'profissional_id' => $pro->id,
        'contratante_id' => $contratante->id,
        'estabelecimento_id' => $contratante->id,
    ]);

    return Avaliacao::factory()->paraTurno($turno)->estrelas($estrelas)->create(['comentario' => $comentario]);
}

// ── perfil do profissional (self) — CA-6 ─────────────────────────────────────

test('profissional vê o próprio perfil: score 1 casa, nível, XP atual e XP até o próximo', function () {
    $pro = profissionalReputado();

    test()->actingAs($pro)
        ->getJson("/api/perfil/{$pro->id}")
        ->assertStatus(200)
        ->assertJsonPath('papel', 'profissional')
        ->assertJsonPath('score', 4.7)          // 4.67 exibido com 1 casa
        ->assertJsonPath('nivel', 'Confiavel')
        ->assertJsonPath('xp', 510)
        ->assertJsonPath('xp_proximo_nivel', 490) // 1000 − 510
        ->assertJsonPath('turnos_realizados', 17);
});

test('profissional Elite não tem xp_proximo_nivel (null — topo da trilha)', function () {
    $pro = profissionalReputado(['nivel' => 'Elite', 'xp' => 3200]);

    test()->actingAs($pro)
        ->getJson("/api/perfil/{$pro->id}")
        ->assertStatus(200)
        ->assertJsonPath('xp_proximo_nivel', null);
});

// ── depoimentos: comentário não-vazio, mais recentes primeiro — CA-6 ─────────

test('depoimentos trazem só comentário não-vazio, do mais recente ao mais antigo', function () {
    $pro = profissionalReputado();
    $a = depoimentoSobreProfissional($pro, 'Bar A', 5, 'Pontual e atencioso');
    $a->created_at = now()->subDays(3);
    $a->save(); // created_at não é fillable — set direto bypassa o mass-assignment
    $b = depoimentoSobreProfissional($pro, 'Bar B', 4, 'Bom atendimento');
    $b->created_at = now()->subDay();
    $b->save();
    depoimentoSobreProfissional($pro, 'Bar C', 3, null); // sem comentário → não é depoimento

    $resp = test()->actingAs($pro)->getJson("/api/perfil/{$pro->id}")->assertStatus(200);

    $depo = $resp->json('depoimentos');
    expect($depo)->toHaveCount(2)
        ->and($depo[0]['comentario'])->toBe('Bom atendimento') // mais recente primeiro
        ->and($depo[1]['comentario'])->toBe('Pontual e atencioso');
});

test('depoimento sobre o PROFISSIONAL mostra o estabelecimento (nominal — DDR-004)', function () {
    $pro = profissionalReputado();
    depoimentoSobreProfissional($pro, 'Restaurante do Zé', 5, 'Top');

    $depo = test()->actingAs($pro)->getJson("/api/perfil/{$pro->id}")->json('depoimentos.0');

    expect($depo['autor_nome'])->toBe('Restaurante do Zé');
});

// ── função do depoimento (STORY-088 — vem do turno avaliado) ──────────────────

test('depoimento traz a função do turno (STORY-088 — avaliacao.turno.vaga.funcao.nome)', function () {
    $pro = profissionalReputado();
    $contratante = User::factory()->contratante()->ativo()->create();
    ContratanteProfile::factory()->create([
        'user_id' => $contratante->id,
        'nome_estabelecimento' => 'Bar do Porto',
    ]);
    $funcao = Funcao::factory()->create(['nome' => 'Garçom']);
    $vaga = Vaga::factory()->create(['funcao_id' => $funcao->id, 'contratante_id' => $contratante->id]);
    $turno = Turno::factory()->status(TurnoStatus::Finalizado)->create([
        'profissional_id' => $pro->id,
        'contratante_id' => $contratante->id,
        'estabelecimento_id' => $contratante->id,
        'vaga_id' => $vaga->id,
    ]);
    Avaliacao::factory()->paraTurno($turno)->estrelas(5)->create(['comentario' => 'Pontual']);

    $depo = test()->actingAs($pro)->getJson("/api/perfil/{$pro->id}")->json('depoimentos.0');

    expect($depo['funcao'])->toBe('Garçom');
});

test('depoimento ANÔNIMO sobre o contratante também traz a função (sem nome do profissional)', function () {
    $contratante = User::factory()->contratante()->ativo()->create();
    ContratanteProfile::factory()->create(['user_id' => $contratante->id, 'score' => 4.5]);
    $pro = User::factory()->profissional()->ativo()->create(['name' => 'João Garçom']);
    $funcao = Funcao::factory()->create(['nome' => 'Cozinheiro']);
    $vaga = Vaga::factory()->create(['funcao_id' => $funcao->id, 'contratante_id' => $contratante->id]);
    $turno = Turno::factory()->status(TurnoStatus::Finalizado)->create([
        'profissional_id' => $pro->id,
        'contratante_id' => $contratante->id,
        'estabelecimento_id' => $contratante->id,
        'vaga_id' => $vaga->id,
    ]);
    Avaliacao::factory()->doProfissional()->paraTurno($turno)->estrelas(5)
        ->create(['comentario' => 'Ambiente ótimo']);

    $depo = test()->actingAs($pro)->getJson("/api/perfil/{$contratante->id}")->json('depoimentos.0');

    expect($depo['funcao'])->toBe('Cozinheiro')
        ->and($depo['autor_nome'])->toBeNull();
});

test('depoimento sobre o CONTRATANTE NÃO traz o nome do profissional (anônimo — LGPD/DDR-004)', function () {
    $contratante = User::factory()->contratante()->ativo()->create();
    ContratanteProfile::factory()->create(['user_id' => $contratante->id, 'score' => 4.5]);
    $pro = User::factory()->profissional()->ativo()->create(['name' => 'João Garçom']);
    $turno = Turno::factory()->status(TurnoStatus::Finalizado)->create([
        'profissional_id' => $pro->id,
        'contratante_id' => $contratante->id,
        'estabelecimento_id' => $contratante->id,
    ]);
    Avaliacao::factory()->doProfissional()->paraTurno($turno)->estrelas(5)
        ->create(['comentario' => 'Ambiente ótimo']); // avaliado = contratante

    $resp = test()->actingAs($pro)->getJson("/api/perfil/{$contratante->id}")->assertStatus(200);

    expect($resp->json('papel'))->toBe('contratante')
        ->and($resp->json('depoimentos.0.comentario'))->toBe('Ambiente ótimo')
        ->and($resp->json('depoimentos.0.autor_nome'))->toBeNull(); // sem nome do profissional
    // E o corpo inteiro não pode conter o nome do profissional em lugar nenhum.
    expect($resp->getContent())->not->toContain('João Garçom');
});

// ── visibilidade: XP é privado do profissional — niveis-e-score.md ───────────

test('contratante vê o score/nível/turnos do candidato, mas NÃO o XP', function () {
    $pro = profissionalReputado();
    $contratante = User::factory()->contratante()->ativo()->create();
    ContratanteProfile::factory()->create(['user_id' => $contratante->id]);

    $resp = test()->actingAs($contratante)->getJson("/api/perfil/{$pro->id}")->assertStatus(200);

    expect($resp->json('score'))->toBe(4.7)
        ->and($resp->json('nivel'))->toBe('Confiavel')
        ->and($resp->json('turnos_realizados'))->toBe(17)
        ->and($resp->json())->not->toHaveKey('xp')
        ->and($resp->json())->not->toHaveKey('xp_proximo_nivel');
});

// ── selo "Novo" (DDR-004) ────────────────────────────────────────────────────

test('selo "Novo" enquanto houver menos de 3 avaliações recebidas (DDR-004)', function () {
    $pro = profissionalReputado();
    depoimentoSobreProfissional($pro, 'Bar A', 5, 'ok'); // 1 avaliação

    $resp = test()->actingAs($pro)->getJson("/api/perfil/{$pro->id}")->assertStatus(200);

    expect($resp->json('total_avaliacoes'))->toBe(1)
        ->and($resp->json('selo_novo'))->toBeTrue();
});
