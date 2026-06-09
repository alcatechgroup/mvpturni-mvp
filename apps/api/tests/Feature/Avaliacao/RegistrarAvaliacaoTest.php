<?php

// STORY-085 / ADR-019 (CA-3/CA-4) — POST /api/turnos/{turno}/avaliar.
// Participante do turno (profissional OU contratante) avalia o outro lado: estrelas
// obrigatórias 1–5 + comentário opcional; direção/avaliado derivam do papel do autor
// (RBAC fail-secure). Insere a linha + dispara AvaliacaoRegistrada na transação → motor
// recomputa a reputação do avaliado. Cobre feliz, inválidos, RBAC, estado e duplicata.

use App\Enums\AvaliacaoDirecao;
use App\Enums\TurnoStatus;
use App\Events\AvaliacaoRegistrada;
use App\Models\Avaliacao;
use App\Models\ContratanteProfile;
use App\Models\ProfissionalProfile;
use App\Models\Turno;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;

uses(RefreshDatabase::class);

/** Turno finalizado com perfis nos dois lados (o motor recomputa reputação do avaliado). */
function turnoFinalizadoComPerfis(): Turno
{
    $turno = Turno::factory()->status(TurnoStatus::Finalizado)->create();
    ProfissionalProfile::factory()->coldStart()->create(['user_id' => $turno->profissional_id]);
    ContratanteProfile::factory()->create(['user_id' => $turno->contratante_id]);

    return $turno->fresh(['profissional', 'contratante']);
}

// ── (a) caminho feliz ────────────────────────────────────────────────────────

test('contratante avalia o profissional → 201, linha na direção certa e reputação recomputada', function () {
    $turno = turnoFinalizadoComPerfis();

    test()->actingAs($turno->contratante)
        ->postJson("/api/turnos/{$turno->id}/avaliar", ['estrelas' => 5, 'comentario' => 'Excelente'])
        ->assertStatus(201)
        ->assertJsonPath('direcao', AvaliacaoDirecao::ContratanteParaProfissional->value)
        ->assertJsonPath('estrelas', 5);

    $avaliacao = Avaliacao::where('turno_id', $turno->id)->sole();
    expect($avaliacao->avaliado_id)->toBe($turno->profissional_id)
        ->and($avaliacao->autor_id)->toBe($turno->contratante_id);

    // Motor rodou síncrono: profissional ganhou XP (30 turno + 10 do 5★) e score 5.0.
    $profile = User::find($turno->profissional_id)->profissionalProfile;
    expect($profile->xp)->toBe(40)->and((float) $profile->score)->toBe(5.0);
});

test('profissional avalia o contratante → direção oposta e score do contratante recomputado', function () {
    $turno = turnoFinalizadoComPerfis();

    test()->actingAs($turno->profissional)
        ->postJson("/api/turnos/{$turno->id}/avaliar", ['estrelas' => 4])
        ->assertStatus(201)
        ->assertJsonPath('direcao', AvaliacaoDirecao::ProfissionalParaContratante->value);

    $avaliacao = Avaliacao::where('turno_id', $turno->id)->sole();
    expect($avaliacao->avaliado_id)->toBe($turno->contratante_id);

    expect((float) User::find($turno->contratante_id)->contratanteProfile->score)->toBe(4.0);
});

test('comentário em branco não vira depoimento (normalizado para null)', function () {
    $turno = turnoFinalizadoComPerfis();

    test()->actingAs($turno->contratante)
        ->postJson("/api/turnos/{$turno->id}/avaliar", ['estrelas' => 3, 'comentario' => '   '])
        ->assertStatus(201);

    expect(Avaliacao::where('turno_id', $turno->id)->sole()->comentario)->toBeNull();
});

test('dispara o evento AvaliacaoRegistrada com o avaliado correto', function () {
    Event::fake([AvaliacaoRegistrada::class]);
    $turno = turnoFinalizadoComPerfis();

    test()->actingAs($turno->contratante)
        ->postJson("/api/turnos/{$turno->id}/avaliar", ['estrelas' => 5])
        ->assertStatus(201);

    Event::assertDispatched(AvaliacaoRegistrada::class, fn ($e) => $e->avaliadoId === $turno->profissional_id
        && $e->turnoId === $turno->id);
});

// ── (b) casos inválidos ──────────────────────────────────────────────────────

test('estrelas ausente → 422 (obrigatória — PDR-005)', function () {
    $turno = turnoFinalizadoComPerfis();

    test()->actingAs($turno->contratante)
        ->postJson("/api/turnos/{$turno->id}/avaliar", ['comentario' => 'sem nota'])
        ->assertStatus(422)
        ->assertJsonValidationErrors('estrelas');
});

test('estrelas fora de 1–5 → 422', function (int $estrelas) {
    $turno = turnoFinalizadoComPerfis();

    test()->actingAs($turno->contratante)
        ->postJson("/api/turnos/{$turno->id}/avaliar", ['estrelas' => $estrelas])
        ->assertStatus(422)
        ->assertJsonValidationErrors('estrelas');
})->with([0, 6, -1, 99]);

test('comentário acima de 1000 caracteres → 422', function () {
    $turno = turnoFinalizadoComPerfis();

    test()->actingAs($turno->contratante)
        ->postJson("/api/turnos/{$turno->id}/avaliar", ['estrelas' => 5, 'comentario' => str_repeat('x', 1001)])
        ->assertStatus(422)
        ->assertJsonValidationErrors('comentario');
});

// ── (c) RBAC / exceções ──────────────────────────────────────────────────────

test('quem não participou do turno não pode avaliar → 403', function () {
    $turno = turnoFinalizadoComPerfis();
    $intruso = User::factory()->profissional()->ativo()->create();

    test()->actingAs($intruso)
        ->postJson("/api/turnos/{$turno->id}/avaliar", ['estrelas' => 5])
        ->assertStatus(403);

    expect(Avaliacao::where('turno_id', $turno->id)->count())->toBe(0);
});

test('turno não-avaliável (ativo) → 422 estado_invalido', function () {
    $turno = Turno::factory()->status(TurnoStatus::Ativo)->create();

    test()->actingAs($turno->contratante)
        ->postJson("/api/turnos/{$turno->id}/avaliar", ['estrelas' => 5])
        ->assertStatus(422)
        ->assertJsonPath('motivo', 'estado_invalido');
});

// ── (d) bordas ───────────────────────────────────────────────────────────────

test('reenvio na mesma direção → 409 ja_avaliado (uma por direção/turno)', function () {
    $turno = turnoFinalizadoComPerfis();

    test()->actingAs($turno->contratante)
        ->postJson("/api/turnos/{$turno->id}/avaliar", ['estrelas' => 5])
        ->assertStatus(201);

    test()->actingAs($turno->contratante)
        ->postJson("/api/turnos/{$turno->id}/avaliar", ['estrelas' => 3])
        ->assertStatus(409)
        ->assertJsonPath('motivo', 'ja_avaliado');

    expect(Avaliacao::where('turno_id', $turno->id)->count())->toBe(1);
});

test('as duas direções coexistem no mesmo turno (cada lado avalia uma vez)', function () {
    $turno = turnoFinalizadoComPerfis();

    test()->actingAs($turno->contratante)
        ->postJson("/api/turnos/{$turno->id}/avaliar", ['estrelas' => 5])->assertStatus(201);
    test()->actingAs($turno->profissional)
        ->postJson("/api/turnos/{$turno->id}/avaliar", ['estrelas' => 4])->assertStatus(201);

    expect(Avaliacao::where('turno_id', $turno->id)->count())->toBe(2);
});
