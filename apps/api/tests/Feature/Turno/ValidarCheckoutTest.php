<?php

// STORY-064 (CA-3/CA-4/CA-7) — POST /api/turnos/{turno}/validar-checkout.
// Contratante do turno em `aguardando_checkout` valida o PIN: correto → transação
// aguardando_checkout→finalizado + check_out_at FINAL (timestamp da validação — CA-3)
// + evento TurnoFinalizado (065/067 consomem) + audit turno.checkout_validado.
// Errado → 422 pin_invalido; no 3º erro o PIN expira: hash limpo, volta a `ativo`
// (cronômetro retoma — CA-4, espelho da 062 que voltava a confirmado), audit
// turno.checkout_pin_expirado. Rate limit por turno configurável. RBAC: só contratante.

use App\Enums\TurnoStatus;
use App\Events\TurnoFinalizado;
use App\Models\AuditLog;
use App\Models\Turno;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Hash;
use Illuminate\Testing\TestResponse;

uses(RefreshDatabase::class);

const PIN_CHECKOUT_CERTO = '8341';

/** Turno `aguardando_checkout` com PIN conhecido (hash bcrypt — como a geração grava). */
function turnoAguardandoCheckoutValidacao(): Turno
{
    $turno = Turno::factory()->status(TurnoStatus::AguardandoCheckout)->create([
        'data_inicio' => now()->subHours(5),
        'data_fim' => now()->subMinutes(10),
        'check_in_at' => now()->subHours(5),
        'pin_checkout_hash' => Hash::make(PIN_CHECKOUT_CERTO),
        'geofencing_check_out' => [
            'ok' => true, 'distancia_metros' => 18.0,
            'razao' => null, 'capturado_em' => now()->toIso8601String(),
        ],
    ]);

    return $turno->fresh(['profissional', 'contratante']);
}

function validarCheckout(Turno $turno, string $pin = PIN_CHECKOUT_CERTO): TestResponse
{
    return test()->actingAs($turno->contratante)
        ->postJson("/api/turnos/{$turno->id}/validar-checkout", ['pin' => $pin]);
}

// ── (a) caminho feliz (CA-3) ─────────────────────────────────────────────────

test('PIN correto → 200 finalizado, check_out_at FINAL gravado, hash consumido e evento TurnoFinalizado', function () {
    Event::fake([TurnoFinalizado::class]);
    $turno = turnoAguardandoCheckoutValidacao();

    validarCheckout($turno)
        ->assertStatus(200)
        ->assertJsonPath('estado', 'finalizado');

    $turno->refresh();
    expect($turno->status)->toBe(TurnoStatus::Finalizado)
        ->and($turno->check_out_at)->not->toBeNull()
        // CA-3: o check_out_at FINAL é o da validação (agora), não o da solicitação.
        ->and($turno->check_out_at->diffInSeconds(now()))->toBeLessThan(5.0)
        ->and($turno->pin_checkout_hash)->toBeNull()     // PIN é de uso único (consumido)
        ->and($turno->pin_checkout_tentativas)->toBe(0)
        ->and($turno->check_in_at)->not->toBeNull();     // duração final = check_out − check_in

    // ADR-018 — o evento carrega o turno_id UUID string (contrato p/ 065/067).
    Event::assertDispatched(TurnoFinalizado::class, fn ($e) => $e->turnoId === $turno->id);
});

test('CA-7: audit turno.checkout_validado com pin_tentativas_ate_acerto', function () {
    $turno = turnoAguardandoCheckoutValidacao();

    validarCheckout($turno, '1111')->assertStatus(422); // 1 erro antes de acertar
    validarCheckout($turno->fresh(['contratante']))->assertStatus(200);

    $log = AuditLog::query()
        ->where('action', 'turno.checkout_validado')
        ->where('target_type', 'Turno')->where('target_id', $turno->id)
        ->first();

    expect($log)->not->toBeNull()
        ->and($log->actor_id)->toBe($turno->contratante_id)
        ->and($log->payload['pin_tentativas_ate_acerto'])->toBe(2);

    // O PIN plaintext não vaza para a trilha.
    expect(json_encode($log->payload))->not->toContain(PIN_CHECKOUT_CERTO);
});

// ── (b) PIN errado (CA-4) ────────────────────────────────────────────────────

test('PIN de check-out errado → 422 pin_invalido sem expor tentativas; estado intacto', function () {
    Event::fake([TurnoFinalizado::class]);
    $turno = turnoAguardandoCheckoutValidacao();

    $res = validarCheckout($turno, '0000');

    $res->assertStatus(422)->assertJsonPath('motivo', 'pin_invalido');
    expect(json_encode($res->json()))->not->toContain('tentativa');

    $turno->refresh();
    expect($turno->status)->toBe(TurnoStatus::AguardandoCheckout)
        ->and($turno->pin_checkout_hash)->not->toBeNull()
        ->and($turno->pin_checkout_tentativas)->toBe(1);

    Event::assertNotDispatched(TurnoFinalizado::class);
});

// ── (c) 3 erros → PIN expira e volta a `ativo` (CA-4 — cronômetro retoma) ────

test('3º PIN errado → 422 pin_expirado: hash limpo, volta a ATIVO, audit checkout_pin_expirado', function () {
    $turno = turnoAguardandoCheckoutValidacao();

    validarCheckout($turno, '0000')->assertStatus(422)->assertJsonPath('motivo', 'pin_invalido');
    validarCheckout($turno->fresh(['contratante']), '1111')->assertStatus(422)->assertJsonPath('motivo', 'pin_invalido');
    validarCheckout($turno->fresh(['contratante']), '2222')->assertStatus(422)->assertJsonPath('motivo', 'pin_expirado');

    $turno->refresh();
    expect($turno->status)->toBe(TurnoStatus::Ativo)        // origem (espelho 062→confirmado)
        ->and($turno->pin_checkout_hash)->toBeNull()
        ->and($turno->pin_checkout_tentativas)->toBe(0)
        ->and($turno->check_in_at)->not->toBeNull()          // âncora intacta — cronômetro retoma
        ->and($turno->check_out_at)->toBeNull();

    $log = AuditLog::query()->where('action', 'turno.checkout_pin_expirado')
        ->where('target_id', $turno->id)->first();
    expect($log)->not->toBeNull()
        ->and($log->payload['tentativas'])->toBe(3);
});

test('PIN de check-out CORRETO na 3ª tentativa ainda valida (limite é de ERROS)', function () {
    $turno = turnoAguardandoCheckoutValidacao();

    validarCheckout($turno, '0000')->assertStatus(422);
    validarCheckout($turno->fresh(['contratante']), '1111')->assertStatus(422);
    validarCheckout($turno->fresh(['contratante']))->assertStatus(200);

    expect($turno->refresh()->status)->toBe(TurnoStatus::Finalizado);
});

test('depois de expirado, validar de novo → 422 estado_invalido (turno está ativo)', function () {
    $turno = turnoAguardandoCheckoutValidacao();
    foreach (['0000', '1111', '2222'] as $errado) {
        validarCheckout($turno->fresh(['contratante']), $errado);
    }

    validarCheckout($turno->fresh(['contratante']))
        ->assertStatus(422)
        ->assertJsonPath('motivo', 'estado_invalido');
});

// ── (d) estado inválido ──────────────────────────────────────────────────────

test('turno ativo (sem PIN de check-out gerado) → 422 estado_invalido', function () {
    $turno = Turno::factory()->status(TurnoStatus::Ativo)->create(['check_in_at' => now()->subHours(2)]);

    test()->actingAs($turno->contratante)
        ->postJson("/api/turnos/{$turno->id}/validar-checkout", ['pin' => PIN_CHECKOUT_CERTO])
        ->assertStatus(422)
        ->assertJsonPath('motivo', 'estado_invalido');
});

test('turno já finalizado → 422 estado_invalido (validação dupla em outra aba)', function () {
    $turno = Turno::factory()->status(TurnoStatus::Finalizado)->create([
        'check_in_at' => now()->subHours(6), 'check_out_at' => now()->subHour(),
    ]);

    test()->actingAs($turno->contratante)
        ->postJson("/api/turnos/{$turno->id}/validar-checkout", ['pin' => PIN_CHECKOUT_CERTO])
        ->assertStatus(422)
        ->assertJsonPath('motivo', 'estado_invalido');
});

// ── (e) payload inválido ─────────────────────────────────────────────────────

test('pin de check-out ausente ou fora do formato → 422 de validação sem consumir tentativa', function () {
    $turno = turnoAguardandoCheckoutValidacao();

    test()->actingAs($turno->contratante)
        ->postJson("/api/turnos/{$turno->id}/validar-checkout", [])
        ->assertStatus(422);

    test()->actingAs($turno->contratante)
        ->postJson("/api/turnos/{$turno->id}/validar-checkout", ['pin' => '12345'])
        ->assertStatus(422);

    test()->actingAs($turno->contratante)
        ->postJson("/api/turnos/{$turno->id}/validar-checkout", ['pin' => 'abcd'])
        ->assertStatus(422);

    expect($turno->refresh()->pin_checkout_tentativas)->toBe(0);
});

// ── (f) RBAC ─────────────────────────────────────────────────────────────────

test('profissional do turno não valida o próprio PIN de check-out → 403', function () {
    $turno = turnoAguardandoCheckoutValidacao();

    test()->actingAs($turno->profissional)
        ->postJson("/api/turnos/{$turno->id}/validar-checkout", ['pin' => PIN_CHECKOUT_CERTO])
        ->assertStatus(403);
});

test('terceiro não valida check-out → 403', function () {
    $turno = turnoAguardandoCheckoutValidacao();
    $estranho = User::factory()->contratante()->ativo()->create();

    test()->actingAs($estranho)
        ->postJson("/api/turnos/{$turno->id}/validar-checkout", ['pin' => PIN_CHECKOUT_CERTO])
        ->assertStatus(403);
});

test('não autenticado não valida check-out → 401', function () {
    $turno = turnoAguardandoCheckoutValidacao();

    test()->postJson("/api/turnos/{$turno->id}/validar-checkout", ['pin' => PIN_CHECKOUT_CERTO])
        ->assertStatus(401);
});

// ── (g) rate limit (CA-4 — espelho da 062, janela própria por turno) ─────────

test('6ª tentativa de check-out em 60s no MESMO turno → 429', function () {
    config(['turno.checkout_validacao_max_por_minuto' => 5]);
    $turno = turnoAguardandoCheckoutValidacao();

    foreach (['0000', '1111', '2222', '3333', '4444'] as $pin) {
        validarCheckout($turno->fresh(['contratante']), $pin)->assertStatus(422);
    }

    validarCheckout($turno->fresh(['contratante']), '5555')->assertStatus(429);
});

test('rate limit do check-out é por turno: outro turno não é afetado', function () {
    config(['turno.checkout_validacao_max_por_minuto' => 2]);
    $turno = turnoAguardandoCheckoutValidacao();

    validarCheckout($turno, '0000')->assertStatus(422);
    validarCheckout($turno->fresh(['contratante']), '1111')->assertStatus(422);
    validarCheckout($turno->fresh(['contratante']), '2222')->assertStatus(429);

    $outro = turnoAguardandoCheckoutValidacao();
    validarCheckout($outro)->assertStatus(200); // turno diferente, janela própria
});
