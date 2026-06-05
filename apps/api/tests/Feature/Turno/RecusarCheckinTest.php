<?php

// STORY-062 (CA-6/CA-7) — POST /api/turnos/{turno}/recusar-checkin.
// Contratante recusa o check-in em `aguardando_checkin`: turno volta para `confirmado`,
// PIN invalidado (hash limpo), audit turno.checkin_recusado com motivo OPCIONAL no
// payload (motivo vive na trilha completa do admin — SCREEN-062 §4.11; a timeline das
// partes mostra só "Recusado pelo contratante"). Profissional gera novo PIN (061).

use App\Enums\TurnoStatus;
use App\Models\AuditLog;
use App\Models\Turno;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Testing\TestResponse;

uses(RefreshDatabase::class);

function turnoComPinAtivo(): Turno
{
    $turno = Turno::factory()->status(TurnoStatus::AguardandoCheckin)->create([
        'pin_checkin_hash' => Hash::make('4702'),
        'pin_checkin_tentativas' => 1,
    ]);

    return $turno->fresh(['profissional', 'contratante']);
}

function recusarCheckin(Turno $turno, array $body = []): TestResponse
{
    return test()->actingAs($turno->contratante)
        ->postJson("/api/turnos/{$turno->id}/recusar-checkin", $body);
}

// ── caminho feliz (CA-6) ─────────────────────────────────────────────────────

test('recusa sem motivo → 200 confirmado, hash limpo, tentativas zeradas, audit checkin_recusado', function () {
    $turno = turnoComPinAtivo();

    recusarCheckin($turno)
        ->assertStatus(200)
        ->assertJsonPath('estado', 'confirmado');

    $turno->refresh();
    expect($turno->status)->toBe(TurnoStatus::Confirmado)
        ->and($turno->pin_checkin_hash)->toBeNull()
        ->and($turno->pin_checkin_tentativas)->toBe(0)
        ->and($turno->check_in_at)->toBeNull();

    $log = AuditLog::query()->where('action', 'turno.checkin_recusado')
        ->where('target_type', 'Turno')->where('target_id', $turno->id)->first();
    expect($log)->not->toBeNull()
        ->and($log->actor_id)->toBe($turno->contratante_id)
        ->and($log->payload['motivo'])->toBeNull();
});

test('recusa com motivo → motivo no payload do audit (CA-6/CA-7)', function () {
    $turno = turnoComPinAtivo();

    recusarCheckin($turno, ['motivo' => 'O profissional ainda não chegou ao estabelecimento'])
        ->assertStatus(200);

    $log = AuditLog::query()->where('action', 'turno.checkin_recusado')
        ->where('target_id', $turno->id)->first();
    expect($log->payload['motivo'])->toBe('O profissional ainda não chegou ao estabelecimento');
});

test('depois da recusa, o profissional pode gerar novo PIN (ciclo da 061 reabre)', function () {
    $turno = turnoComPinAtivo();
    $turno->forceFill(['data_inicio' => now()->addMinutes(15), 'data_fim' => now()->addHours(6)])->save();
    $turno->vaga->update(['lat' => -23.55, 'lng' => -46.63]);
    recusarCheckin($turno->fresh(['contratante']))->assertStatus(200);

    test()->actingAs($turno->profissional)
        ->postJson("/api/turnos/{$turno->id}/gerar-pin-checkin", [
            'pin_solicitado' => true, 'lat' => -23.55, 'lng' => -46.63,
        ])
        ->assertStatus(200)
        ->assertJsonPath('estado', 'aguardando_checkin');
});

// ── validação e estado ───────────────────────────────────────────────────────

test('motivo acima de 280 caracteres → 422 de validação', function () {
    recusarCheckin(turnoComPinAtivo(), ['motivo' => str_repeat('x', 281)])
        ->assertStatus(422);
});

test('turno fora de aguardando_checkin → 422 estado_invalido', function () {
    $turno = Turno::factory()->status(TurnoStatus::Confirmado)->create();

    test()->actingAs($turno->contratante)
        ->postJson("/api/turnos/{$turno->id}/recusar-checkin")
        ->assertStatus(422)
        ->assertJsonPath('motivo', 'estado_invalido');
});

// ── RBAC ─────────────────────────────────────────────────────────────────────

test('profissional não recusa o próprio check-in → 403', function () {
    $turno = turnoComPinAtivo();

    test()->actingAs($turno->profissional)
        ->postJson("/api/turnos/{$turno->id}/recusar-checkin")
        ->assertStatus(403);
});

test('terceiro (outro contratante) → 403', function () {
    $turno = turnoComPinAtivo();
    $estranho = User::factory()->contratante()->ativo()->create();

    test()->actingAs($estranho)
        ->postJson("/api/turnos/{$turno->id}/recusar-checkin")
        ->assertStatus(403);
});

test('não autenticado → 401', function () {
    $turno = turnoComPinAtivo();

    test()->postJson("/api/turnos/{$turno->id}/recusar-checkin")
        ->assertStatus(401);
});
