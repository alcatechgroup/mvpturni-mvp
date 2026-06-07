<?php

// STORY-061 (CA-5) — POST /api/turnos/{turno}/cancelar-pin-checkin: "Não chegou ainda?
// Cancelar PIN" volta aguardando_checkin→confirmado, limpa o hash (o PIN antigo deixa de
// existir) e grava `turno.checkin_cancelado` na trilha (premissa da SCREEN-061 §4.10).

use App\Enums\TurnoStatus;
use App\Models\AuditLog;
use App\Models\Turno;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;

uses(RefreshDatabase::class);

function turnoAguardandoCheckin(): Turno
{
    $turno = Turno::factory()->status(TurnoStatus::AguardandoCheckin)->create([
        'data_inicio' => now()->addMinutes(15),
        'data_fim' => now()->addHours(6),
        'pin_checkin_hash' => Hash::make('4702'),
        'geofencing_check_in' => ['ok' => true, 'distancia_metros' => 12.0, 'razao' => null,
            'capturado_em' => now()->toIso8601String()],
    ]);

    return $turno->fresh(['profissional', 'contratante']);
}

// ── (a) caminho feliz ────────────────────────────────────────────────────────

test('cancelar em aguardando_checkin → confirmado, hash limpo e audit checkin_cancelado', function () {
    $turno = turnoAguardandoCheckin();

    test()->actingAs($turno->profissional)
        ->postJson("/api/turnos/{$turno->id}/cancelar-pin-checkin")
        ->assertStatus(200)
        ->assertJsonPath('estado', 'confirmado');

    $turno->refresh();
    expect($turno->status)->toBe(TurnoStatus::Confirmado)
        ->and($turno->pin_checkin_hash)->toBeNull();

    $log = AuditLog::query()->where('action', 'turno.checkin_cancelado')
        ->where('target_type', 'Turno')->where('target_id', $turno->id)->first();
    expect($log)->not->toBeNull()
        ->and($log->actor_id)->toBe($turno->profissional_id);
});

// ── (b) estado inválido ──────────────────────────────────────────────────────

test('cancelar em confirmado (sem PIN pendente) → 422 estado_invalido', function () {
    $turno = Turno::factory()->status(TurnoStatus::Confirmado)->create();

    test()->actingAs($turno->profissional->fresh())
        ->postJson("/api/turnos/{$turno->id}/cancelar-pin-checkin")
        ->assertStatus(422)
        ->assertJsonPath('motivo', 'estado_invalido');
});

test('cancelar em ativo (check-in já validado) → 422 e estado intacto', function () {
    $turno = Turno::factory()->status(TurnoStatus::Ativo)->create();

    test()->actingAs($turno->profissional->fresh())
        ->postJson("/api/turnos/{$turno->id}/cancelar-pin-checkin")
        ->assertStatus(422);

    expect($turno->refresh()->status)->toBe(TurnoStatus::Ativo);
});

// ── (c) RBAC / autenticação ──────────────────────────────────────────────────

test('contratante não cancela PIN do profissional → 403', function () {
    $turno = turnoAguardandoCheckin();

    test()->actingAs($turno->contratante)
        ->postJson("/api/turnos/{$turno->id}/cancelar-pin-checkin")
        ->assertStatus(403);
});

test('terceiro → 403', function () {
    $turno = turnoAguardandoCheckin();
    $estranho = User::factory()->profissional()->ativo()->create();

    test()->actingAs($estranho)
        ->postJson("/api/turnos/{$turno->id}/cancelar-pin-checkin")->assertStatus(403);
});

test('não autenticado → 401', function () {
    $turno = turnoAguardandoCheckin();

    test()->postJson("/api/turnos/{$turno->id}/cancelar-pin-checkin")->assertStatus(401);
});

// ── (d) borda — ciclo completo gerar→cancelar→gerar ──────────────────────────

test('cancelar e gerar de novo funciona (ciclo completo, novo PIN válido)', function () {
    $turno = Turno::factory()->status(TurnoStatus::Confirmado)->create([
        'data_inicio' => now()->addMinutes(15),
        'data_fim' => now()->addHours(6),
    ]);
    $turno->vaga->update(['lat' => -23.55, 'lng' => -46.63]);
    $profissional = $turno->profissional->fresh();

    $pin1 = test()->actingAs($profissional)
        ->postJson("/api/turnos/{$turno->id}/gerar-pin-checkin", [
            'pin_solicitado' => true, 'lat' => -23.55, 'lng' => -46.63,
        ])->assertStatus(200)->json('pin');

    test()->actingAs($profissional)
        ->postJson("/api/turnos/{$turno->id}/cancelar-pin-checkin")->assertStatus(200);

    $pin2 = test()->actingAs($profissional)
        ->postJson("/api/turnos/{$turno->id}/gerar-pin-checkin", [
            'pin_solicitado' => true, 'lat' => -23.55, 'lng' => -46.63,
        ])->assertStatus(200)->json('pin');

    $turno->refresh();
    expect($turno->status)->toBe(TurnoStatus::AguardandoCheckin)
        ->and(Hash::check($pin2, $turno->pin_checkin_hash))->toBeTrue();

    // Trilha completa: solicitado, cancelado, solicitado de novo (CA-7).
    // Ordena por `id` (UUIDv7 ordena no tempo — idioma da STORY-062): os 3 audits
    // podem cair no MESMO segundo e `created_at` (timestamp(0)) empata — a ordem
    // do empate é indeterminada no Postgres (flake pego na validação da 068).
    $acoes = AuditLog::query()->where('target_id', $turno->id)
        ->whereIn('action', ['turno.checkin_solicitado', 'turno.checkin_cancelado'])
        ->orderBy('id')->pluck('action')->all();
    expect($acoes)->toBe([
        'turno.checkin_solicitado', 'turno.checkin_cancelado', 'turno.checkin_solicitado',
    ]);

    expect($pin1)->toMatch('/^\d{4}$/'); // pin1 só prova que a 1ª geração devolveu plaintext
});
