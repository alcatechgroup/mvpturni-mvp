<?php

// STORY-064 (SCREEN-064 §4.6) — POST /api/turnos/{turno}/cancelar-pin-checkout.
// Profissional desfaz a solicitação: aguardando_checkout→ativo (o cronômetro RETOMA —
// a âncora check_in_at fica intacta e check_out_at segue null), hash limpo e audit
// turno.checkout_cancelado. Espelho do cancelamento da 061 (que voltava a confirmado).

use App\Enums\TurnoStatus;
use App\Models\AuditLog;
use App\Models\Turno;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;

uses(RefreshDatabase::class);

/** Turno `aguardando_checkout` com PIN de check-out vigente. */
function turnoAguardandoCheckout(): Turno
{
    $turno = Turno::factory()->status(TurnoStatus::AguardandoCheckout)->create([
        'data_inicio' => now()->subHours(5),
        'data_fim' => now()->subMinutes(10),
        'check_in_at' => now()->subHours(5),
        'pin_checkout_hash' => Hash::make('8341'),
    ]);

    return $turno->fresh(['profissional', 'contratante']);
}

test('cancelamento → 200 ativo, hash limpo, âncora do cronômetro intacta e audit checkout_cancelado', function () {
    $turno = turnoAguardandoCheckout();
    $checkInOriginal = $turno->check_in_at;

    test()->actingAs($turno->profissional)
        ->postJson("/api/turnos/{$turno->id}/cancelar-pin-checkout")
        ->assertStatus(200)
        ->assertJsonPath('estado', 'ativo');

    $turno->refresh();
    expect($turno->status)->toBe(TurnoStatus::Ativo)
        ->and($turno->pin_checkout_hash)->toBeNull()
        ->and($turno->pin_checkout_tentativas)->toBe(0)
        ->and($turno->check_in_at->equalTo($checkInOriginal))->toBeTrue() // cronômetro retoma da mesma âncora
        ->and($turno->check_out_at)->toBeNull();

    $log = AuditLog::query()->where('action', 'turno.checkout_cancelado')
        ->where('target_type', 'Turno')->where('target_id', $turno->id)->first();
    expect($log)->not->toBeNull()
        ->and($log->actor_id)->toBe($turno->profissional_id);
});

test('cancelar fora de aguardando_checkout (ativo) → 422 estado_invalido', function () {
    $turno = Turno::factory()->status(TurnoStatus::Ativo)->create([
        'check_in_at' => now()->subHours(2),
    ]);

    test()->actingAs($turno->profissional)
        ->postJson("/api/turnos/{$turno->id}/cancelar-pin-checkout")
        ->assertStatus(422)
        ->assertJsonPath('motivo', 'estado_invalido');
});

test('contratante não cancela o PIN de check-out do profissional → 403', function () {
    $turno = turnoAguardandoCheckout();

    test()->actingAs($turno->contratante)
        ->postJson("/api/turnos/{$turno->id}/cancelar-pin-checkout")
        ->assertStatus(403);
});

test('não autenticado não cancela PIN de check-out → 401', function () {
    $turno = turnoAguardandoCheckout();

    test()->postJson("/api/turnos/{$turno->id}/cancelar-pin-checkout")
        ->assertStatus(401);
});
