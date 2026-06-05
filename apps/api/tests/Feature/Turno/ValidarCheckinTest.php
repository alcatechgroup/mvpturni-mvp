<?php

// STORY-062 (CA-1..CA-4, CA-7) — POST /api/turnos/{turno}/validar-checkin.
// Contratante do turno em `aguardando_checkin` valida o PIN contra o hash server-side
// da STORY-061: correto → transação aguardando_checkin→ativo + check_in_at + evento
// TurnoIniciado (consumido por 063/067) + audit turno.checkin_validado com
// pin_tentativas_ate_acerto (CA-7). Errado → 422 pin_invalido (CA-2, sem expor
// tentativas restantes); no 3º erro o PIN expira: hash limpo, volta a `confirmado`,
// audit turno.checkin_pin_expirado (CA-3 / SCREEN-062 §4.5). Rate limit 5/60s por
// turno, configurável via env (CA-2). RBAC: só o contratante do turno (CA-1).

use App\Enums\TurnoStatus;
use App\Events\TurnoIniciado;
use App\Models\AuditLog;
use App\Models\Turno;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Hash;
use Illuminate\Testing\TestResponse;

uses(RefreshDatabase::class);

const PIN_CERTO = '4702';

/** Turno `aguardando_checkin` com PIN conhecido (hash bcrypt — como a 061 grava). */
function turnoAguardandoValidacao(): Turno
{
    $turno = Turno::factory()->status(TurnoStatus::AguardandoCheckin)->create([
        'data_inicio' => now()->addMinutes(10),
        'data_fim' => now()->addHours(6),
        'pin_checkin_hash' => Hash::make(PIN_CERTO),
        'geofencing_check_in' => [
            'ok' => true, 'distancia_metros' => 23.0,
            'razao' => null, 'capturado_em' => now()->toIso8601String(),
        ],
    ]);

    return $turno->fresh(['profissional', 'contratante']);
}

function validarCheckin(Turno $turno, string $pin = PIN_CERTO): TestResponse
{
    return test()->actingAs($turno->contratante)
        ->postJson("/api/turnos/{$turno->id}/validar-checkin", ['pin' => $pin]);
}

// ── (a) caminho feliz (CA-1) ─────────────────────────────────────────────────

test('PIN correto → 200 ativo, check_in_at gravado, hash consumido e evento TurnoIniciado', function () {
    Event::fake([TurnoIniciado::class]);
    $turno = turnoAguardandoValidacao();

    validarCheckin($turno)
        ->assertStatus(200)
        ->assertJsonPath('estado', 'ativo');

    $turno->refresh();
    expect($turno->status)->toBe(TurnoStatus::Ativo)
        ->and($turno->check_in_at)->not->toBeNull()
        ->and($turno->pin_checkin_hash)->toBeNull()      // PIN é de uso único (consumido)
        ->and($turno->pin_checkin_tentativas)->toBe(0);

    // ADR-018 — o evento carrega o turno_id UUID string (contrato p/ 063/067).
    Event::assertDispatched(TurnoIniciado::class, fn ($e) => $e->turnoId === $turno->id);
});

test('CA-7: audit turno.checkin_validado com pin_tentativas_ate_acerto', function () {
    $turno = turnoAguardandoValidacao();

    validarCheckin($turno, '1111')->assertStatus(422); // 1 erro antes de acertar
    validarCheckin($turno->fresh(['contratante']))->assertStatus(200);

    $log = AuditLog::query()
        ->where('action', 'turno.checkin_validado')
        ->where('target_type', 'Turno')->where('target_id', $turno->id)
        ->first();

    expect($log)->not->toBeNull()
        ->and($log->actor_id)->toBe($turno->contratante_id)
        ->and($log->payload['pin_tentativas_ate_acerto'])->toBe(2);

    // O PIN plaintext não vaza para a trilha.
    expect(json_encode($log->payload))->not->toContain(PIN_CERTO);
});

// ── (b) PIN errado (CA-2) ────────────────────────────────────────────────────

test('PIN errado → 422 pin_invalido sem expor tentativas; estado intacto', function () {
    Event::fake([TurnoIniciado::class]);
    $turno = turnoAguardandoValidacao();

    $res = validarCheckin($turno, '0000');

    $res->assertStatus(422)->assertJsonPath('motivo', 'pin_invalido');
    // Segurança: a resposta não dá pista de quantas tentativas restam (CA-2).
    expect(json_encode($res->json()))->not->toContain('tentativa');

    $turno->refresh();
    expect($turno->status)->toBe(TurnoStatus::AguardandoCheckin)
        ->and($turno->pin_checkin_hash)->not->toBeNull()
        ->and($turno->pin_checkin_tentativas)->toBe(1);

    Event::assertNotDispatched(TurnoIniciado::class);
});

// ── (c) 3 erros → PIN expira (CA-3) ──────────────────────────────────────────

test('3º PIN errado → 422 pin_expirado: hash limpo, volta a confirmado, audit checkin_pin_expirado', function () {
    $turno = turnoAguardandoValidacao();

    validarCheckin($turno, '0000')->assertStatus(422)->assertJsonPath('motivo', 'pin_invalido');
    validarCheckin($turno->fresh(['contratante']), '1111')->assertStatus(422)->assertJsonPath('motivo', 'pin_invalido');
    validarCheckin($turno->fresh(['contratante']), '2222')->assertStatus(422)->assertJsonPath('motivo', 'pin_expirado');

    $turno->refresh();
    expect($turno->status)->toBe(TurnoStatus::Confirmado)   // profissional gera novo PIN (061)
        ->and($turno->pin_checkin_hash)->toBeNull()
        ->and($turno->pin_checkin_tentativas)->toBe(0)
        ->and($turno->check_in_at)->toBeNull();

    $log = AuditLog::query()->where('action', 'turno.checkin_pin_expirado')
        ->where('target_id', $turno->id)->first();
    expect($log)->not->toBeNull()
        ->and($log->payload['tentativas'])->toBe(3);
});

test('PIN CORRETO na 3ª tentativa ainda valida (o limite é de ERROS, não de tentativas)', function () {
    $turno = turnoAguardandoValidacao();

    validarCheckin($turno, '0000')->assertStatus(422);
    validarCheckin($turno->fresh(['contratante']), '1111')->assertStatus(422);
    validarCheckin($turno->fresh(['contratante']), PIN_CERTO)->assertStatus(200);

    expect($turno->refresh()->status)->toBe(TurnoStatus::Ativo);
});

test('depois de expirado, validar de novo → 422 estado_invalido (turno está confirmado)', function () {
    $turno = turnoAguardandoValidacao();
    foreach (['0000', '1111', '2222'] as $errado) {
        validarCheckin($turno->fresh(['contratante']), $errado);
    }

    validarCheckin($turno->fresh(['contratante']))
        ->assertStatus(422)
        ->assertJsonPath('motivo', 'estado_invalido');
});

// ── (d) estado inválido ──────────────────────────────────────────────────────

test('turno confirmado (sem PIN gerado) → 422 estado_invalido', function () {
    $turno = Turno::factory()->status(TurnoStatus::Confirmado)->create();

    test()->actingAs($turno->contratante)
        ->postJson("/api/turnos/{$turno->id}/validar-checkin", ['pin' => PIN_CERTO])
        ->assertStatus(422)
        ->assertJsonPath('motivo', 'estado_invalido');
});

test('turno já ativo → 422 estado_invalido (validação dupla em outra aba)', function () {
    $turno = Turno::factory()->status(TurnoStatus::Ativo)->create();

    test()->actingAs($turno->contratante)
        ->postJson("/api/turnos/{$turno->id}/validar-checkin", ['pin' => PIN_CERTO])
        ->assertStatus(422)
        ->assertJsonPath('motivo', 'estado_invalido');
});

// ── (e) payload inválido ─────────────────────────────────────────────────────

test('pin ausente ou fora do formato 4 dígitos → 422 de validação', function () {
    $turno = turnoAguardandoValidacao();

    test()->actingAs($turno->contratante)
        ->postJson("/api/turnos/{$turno->id}/validar-checkin", [])
        ->assertStatus(422);

    test()->actingAs($turno->contratante)
        ->postJson("/api/turnos/{$turno->id}/validar-checkin", ['pin' => '12345'])
        ->assertStatus(422);

    test()->actingAs($turno->contratante)
        ->postJson("/api/turnos/{$turno->id}/validar-checkin", ['pin' => 'abcd'])
        ->assertStatus(422);

    // Formato inválido NÃO consome tentativa do PIN.
    expect($turno->refresh()->pin_checkin_tentativas)->toBe(0);
});

// ── (f) RBAC (CA-1) ──────────────────────────────────────────────────────────

test('profissional do turno não valida o próprio PIN → 403', function () {
    $turno = turnoAguardandoValidacao();

    test()->actingAs($turno->profissional)
        ->postJson("/api/turnos/{$turno->id}/validar-checkin", ['pin' => PIN_CERTO])
        ->assertStatus(403);
});

test('terceiro (outro contratante) → 403', function () {
    $turno = turnoAguardandoValidacao();
    $estranho = User::factory()->contratante()->ativo()->create();

    test()->actingAs($estranho)
        ->postJson("/api/turnos/{$turno->id}/validar-checkin", ['pin' => PIN_CERTO])
        ->assertStatus(403);
});

test('não autenticado → 401', function () {
    $turno = turnoAguardandoValidacao();

    test()->postJson("/api/turnos/{$turno->id}/validar-checkin", ['pin' => PIN_CERTO])
        ->assertStatus(401);
});

// ── (g) rate limit (CA-2 — 5/60s por turno, configurável) ────────────────────

test('6ª tentativa em 60s no MESMO turno → 429 (sem consumir tentativa do PIN)', function () {
    config(['turno.checkin_validacao_max_por_minuto' => 5]);
    $turno = turnoAguardandoValidacao();

    // 3 erros expiram o PIN; o rate limit continua contando requests do turno.
    foreach (['0000', '1111', '2222', '3333', '4444'] as $pin) {
        validarCheckin($turno->fresh(['contratante']), $pin)->assertStatus(422);
    }

    validarCheckin($turno->fresh(['contratante']), '5555')->assertStatus(429);
});

test('rate limit é por turno: outro turno do mesmo contratante não é afetado', function () {
    config(['turno.checkin_validacao_max_por_minuto' => 2]);
    $turno = turnoAguardandoValidacao();

    validarCheckin($turno, '0000')->assertStatus(422);
    validarCheckin($turno->fresh(['contratante']), '1111')->assertStatus(422);
    validarCheckin($turno->fresh(['contratante']), '2222')->assertStatus(429);

    $outro = turnoAguardandoValidacao();
    validarCheckin($outro)->assertStatus(200); // turno diferente, janela própria
});
