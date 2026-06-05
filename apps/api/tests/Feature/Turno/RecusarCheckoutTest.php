<?php

// STORY-064 (CA-5/CA-7) — POST /api/turnos/{turno}/recusar-checkout.
// Contratante recusa: aguardando_checkout→ATIVO (cronômetro retoma; NUNCA `em_disputa` —
// EPIC-005 fora de escopo), PIN deixa de valer, audit turno.checkout_recusado com motivo
// OPCIONAL (≤280 — vive na trilha do admin; a timeline das partes não o expõe).

use App\Enums\TurnoStatus;
use App\Models\AuditLog;
use App\Models\Turno;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Testing\TestResponse;

uses(RefreshDatabase::class);

/** Turno `aguardando_checkout` com PIN de check-out vigente e 1 erro acumulado. */
function turnoComPinCheckoutAtivo(): Turno
{
    $turno = Turno::factory()->status(TurnoStatus::AguardandoCheckout)->create([
        'data_inicio' => now()->subHours(5),
        'data_fim' => now()->subMinutes(10),
        'check_in_at' => now()->subHours(5),
        'pin_checkout_hash' => Hash::make('8341'),
        'pin_checkout_tentativas' => 1,
    ]);

    return $turno->fresh(['profissional', 'contratante']);
}

function recusarCheckout(Turno $turno, array $body = []): TestResponse
{
    return test()->actingAs($turno->contratante)
        ->postJson("/api/turnos/{$turno->id}/recusar-checkout", $body);
}

test('recusa com motivo → 200 ATIVO (não em_disputa), hash limpo e audit checkout_recusado com motivo', function () {
    $turno = turnoComPinCheckoutAtivo();

    recusarCheckout($turno, ['motivo' => 'O turno ainda não terminou — bar cheio.'])
        ->assertStatus(200)
        ->assertJsonPath('estado', 'ativo');

    $turno->refresh();
    expect($turno->status)->toBe(TurnoStatus::Ativo)         // CA-5: NUNCA em_disputa
        ->and($turno->pin_checkout_hash)->toBeNull()
        ->and($turno->pin_checkout_tentativas)->toBe(0)
        ->and($turno->check_in_at)->not->toBeNull()           // cronômetro retoma da âncora
        ->and($turno->check_out_at)->toBeNull();

    $log = AuditLog::query()->where('action', 'turno.checkout_recusado')
        ->where('target_type', 'Turno')->where('target_id', $turno->id)->first();
    expect($log)->not->toBeNull()
        ->and($log->actor_id)->toBe($turno->contratante_id)
        ->and($log->payload['motivo'])->toBe('O turno ainda não terminou — bar cheio.');
});

test('recusa SEM motivo (opcional) → 200 ativo, audit com motivo null', function () {
    $turno = turnoComPinCheckoutAtivo();

    recusarCheckout($turno)->assertStatus(200)->assertJsonPath('estado', 'ativo');

    $log = AuditLog::query()->where('action', 'turno.checkout_recusado')
        ->where('target_id', $turno->id)->first();
    expect($log->payload['motivo'])->toBeNull();
});

test('motivo acima de 280 caracteres → 422 de validação, estado intacto', function () {
    $turno = turnoComPinCheckoutAtivo();

    recusarCheckout($turno, ['motivo' => str_repeat('x', 281)])->assertStatus(422);

    expect($turno->refresh()->status)->toBe(TurnoStatus::AguardandoCheckout);
});

test('recusar fora de aguardando_checkout (ativo) → 422 estado_invalido', function () {
    $turno = Turno::factory()->status(TurnoStatus::Ativo)->create(['check_in_at' => now()->subHours(2)]);

    recusarCheckout($turno->fresh(['contratante']))
        ->assertStatus(422)
        ->assertJsonPath('motivo', 'estado_invalido');
});

test('profissional não recusa o próprio check-out → 403', function () {
    $turno = turnoComPinCheckoutAtivo();

    test()->actingAs($turno->profissional)
        ->postJson("/api/turnos/{$turno->id}/recusar-checkout")
        ->assertStatus(403);
});

test('não autenticado não recusa check-out → 401', function () {
    $turno = turnoComPinCheckoutAtivo();

    test()->postJson("/api/turnos/{$turno->id}/recusar-checkout")
        ->assertStatus(401);
});
