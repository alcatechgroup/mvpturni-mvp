<?php

// STORY-066 (CA-2/CA-3) — POST /api/turnos/{turno}/cancelar.
// Cancelamento antes do check-in (PDR-007): só em `confirmado`; o lado vem do RBAC
// (profissional → cancelado_pro, contratante → cancelado_emp); grava `cancelamento`
// { lado, motivo, antecedencia_horas, em }; audit `turno.cancelado`; evento TurnoCancelado
// (STORY-067) e LiberarPreAutorizacaoJob (liberação via ACL) disparados pós-commit.

use App\Enums\TurnoStatus;
use App\Events\TurnoCancelado;
use App\Jobs\LiberarPreAutorizacaoJob;
use App\Models\AuditLog;
use App\Models\Turno;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Queue;
use Illuminate\Testing\TestResponse;

uses(RefreshDatabase::class);

function turnoConfirmado(array $attrs = []): Turno
{
    $turno = Turno::factory()->status(TurnoStatus::Confirmado)->create([
        'data_inicio' => now()->addHours(48),
        'data_fim' => now()->addHours(53),
        ...$attrs,
    ]);

    return $turno->fresh(['profissional', 'contratante']);
}

function cancelar(Turno $turno, User $ator, array $body = []): TestResponse
{
    return test()->actingAs($ator)->postJson("/api/turnos/{$turno->id}/cancelar", $body);
}

test('profissional cancela com motivo → 200 cancelado_pro, cancelamento gravado e audit turno.cancelado', function () {
    Queue::fake();
    $turno = turnoConfirmado();

    cancelar($turno, $turno->profissional, ['motivo' => 'Tive um imprevisto de saúde.'])
        ->assertStatus(200)
        ->assertJsonPath('estado', 'cancelado_pro');

    $turno->refresh();
    expect($turno->status)->toBe(TurnoStatus::CanceladoPro)
        ->and($turno->cancelamento['lado'])->toBe('pro')
        ->and($turno->cancelamento['motivo'])->toBe('Tive um imprevisto de saúde.')
        ->and($turno->cancelamento['em'])->not->toBeNull()
        // antecedência ~48h (base para o motor de penalidade futuro — PDR-007)
        ->and($turno->cancelamento['antecedencia_horas'])->toBeGreaterThan(47.9)
        ->and($turno->cancelamento['antecedencia_horas'])->toBeLessThan(48.1);

    $log = AuditLog::query()->where('action', 'turno.cancelado')
        ->where('target_type', 'Turno')->where('target_id', $turno->id)->first();
    expect($log)->not->toBeNull()
        ->and($log->actor_id)->toBe($turno->profissional_id)
        ->and($log->payload['lado'])->toBe('pro')
        ->and($log->payload['motivo'])->toBe('Tive um imprevisto de saúde.');
});

test('contratante cancela sem motivo (opcional) → 200 cancelado_emp, motivo null', function () {
    Queue::fake();
    $turno = turnoConfirmado();

    cancelar($turno, $turno->contratante)
        ->assertStatus(200)
        ->assertJsonPath('estado', 'cancelado_emp');

    $turno->refresh();
    expect($turno->status)->toBe(TurnoStatus::CanceladoEmp)
        ->and($turno->cancelamento['lado'])->toBe('emp')
        ->and($turno->cancelamento['motivo'])->toBeNull();
});

test('cancelamento dispara LiberarPreAutorizacaoJob com motivo cancelamento (CA-2 — liberar via ACL)', function () {
    Queue::fake();
    $turno = turnoConfirmado();

    cancelar($turno, $turno->profissional)->assertStatus(200);

    Queue::assertPushed(LiberarPreAutorizacaoJob::class, fn (LiberarPreAutorizacaoJob $job) => $job->turnoId === $turno->id && $job->motivo === 'cancelamento');
});

test('cancelamento emite evento TurnoCancelado com turno_id UUID string, lado e motivo (CA-3 — STORY-067 consome)', function () {
    Event::fake([TurnoCancelado::class]);
    $turno = turnoConfirmado();

    cancelar($turno, $turno->contratante, ['motivo' => 'O evento foi cancelado.'])->assertStatus(200);

    Event::assertDispatched(TurnoCancelado::class, fn (TurnoCancelado $e) => $e->turnoId === $turno->id && $e->lado === 'emp' && $e->motivo === 'O evento foi cancelado.');
});

test('antecedência negativa quando o cancelamento acontece após o início previsto (ainda confirmado)', function () {
    Queue::fake();
    $turno = turnoConfirmado(['data_inicio' => now()->subHour(), 'data_fim' => now()->addHours(4)]);

    cancelar($turno, $turno->contratante)->assertStatus(200);

    expect($turno->fresh()->cancelamento['antecedencia_horas'])->toBeLessThan(0);
});

// ── Estados não-canceláveis (PDR-007 — 422) ──

dataset('estados_nao_cancelaveis', [
    'aguardando_checkin' => [TurnoStatus::AguardandoCheckin],
    'ativo' => [TurnoStatus::Ativo],
    'aguardando_checkout' => [TurnoStatus::AguardandoCheckout],
    'finalizado' => [TurnoStatus::Finalizado],
    'cancelado_pro (terminal — idempotência de UX)' => [TurnoStatus::CanceladoPro],
    'no_show_pro (terminal)' => [TurnoStatus::NoShowPro],
]);

test('cancelar fora de confirmado → 422 estado_invalido, nada muda', function (TurnoStatus $estado) {
    Queue::fake();
    $turno = Turno::factory()->status($estado)->create([
        'data_inicio' => now()->subHours(2),
        'data_fim' => now()->addHours(3),
    ])->fresh(['profissional', 'contratante']);

    $cancelamentoAntes = $turno->cancelamento; // factory preenche nos `cancelado_*`

    cancelar($turno, $turno->contratante)
        ->assertStatus(422)
        ->assertJsonPath('motivo', 'estado_invalido')
        ->assertJsonPath('estado', $estado->value);

    expect($turno->fresh()->status)->toBe($estado)
        ->and($turno->fresh()->cancelamento)->toBe($cancelamentoAntes); // intocado
    Queue::assertNotPushed(LiberarPreAutorizacaoJob::class);
})->with('estados_nao_cancelaveis');

test('motivo acima de 280 caracteres → 422 de validação', function () {
    $turno = turnoConfirmado();

    cancelar($turno, $turno->profissional, ['motivo' => str_repeat('a', 281)])
        ->assertStatus(422)
        ->assertJsonValidationErrors(['motivo']);
});

// ── RBAC (fail-secure) ──

test('terceiro (outro profissional) → 403; nada muda', function () {
    Queue::fake();
    $turno = turnoConfirmado();
    $intruso = User::factory()->profissional()->ativo()->create();

    cancelar($turno, $intruso)->assertStatus(403);

    expect($turno->fresh()->status)->toBe(TurnoStatus::Confirmado);
    Queue::assertNotPushed(LiberarPreAutorizacaoJob::class);
});

test('contratante de OUTRO turno → 403', function () {
    $turno = turnoConfirmado();
    $outroContratante = User::factory()->contratante()->ativo()->create();

    cancelar($turno, $outroContratante)->assertStatus(403);
});

test('não autenticado → 401', function () {
    $turno = turnoConfirmado();

    test()->postJson("/api/turnos/{$turno->id}/cancelar")->assertStatus(401);
});
