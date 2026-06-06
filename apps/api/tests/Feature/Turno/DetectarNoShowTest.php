<?php

// STORY-066 (CA-5/CA-6) — cron `turnos:detectar-no-show` (everyMinute, worker da STORY-034).
// Detecta turnos `confirmado`/`aguardando_checkin` cujo data_inicio + X horas < now()
// (X = 2h — decisão do PO em chat 2026-06-06; config turno.no_show_horas) e transita para
// `no_show_pro`: audit `turno.no_show_pro`, evento TurnoNoShow (STORY-067) e liberação da
// pré-autorização (LiberarPreAutorizacaoJob com motivo no_show). Exercitado via travel
// (padrões de qualidade da estória).

use App\Enums\TurnoStatus;
use App\Events\TurnoNoShow;
use App\Jobs\LiberarPreAutorizacaoJob;
use App\Models\AuditLog;
use App\Models\Turno;
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Queue;

uses(RefreshDatabase::class);

function turnoComInicio(TurnoStatus $status, DateTimeInterface $inicio): Turno
{
    return Turno::factory()->status($status)->create([
        'data_inicio' => $inicio,
        'data_fim' => (clone $inicio)->modify('+5 hours'),
    ]);
}

function detectar(): void
{
    test()->artisan('turnos:detectar-no-show')->assertSuccessful();
}

test('CA-5: confirmado com início há 2h+1min → no_show_pro + audit + liberação com motivo no_show', function () {
    Queue::fake();
    $turno = turnoComInicio(TurnoStatus::Confirmado, now()->subHours(2)->subMinute());

    detectar();

    expect($turno->fresh()->status)->toBe(TurnoStatus::NoShowPro);

    $log = AuditLog::where('action', 'turno.no_show_pro')
        ->where('target_type', 'Turno')->where('target_id', $turno->id)->first();
    expect($log)->not->toBeNull()
        ->and($log->actor_id)->toBeNull() // transição automática do sistema
        ->and($log->payload['limite_horas'])->toBe(2);

    Queue::assertPushed(LiberarPreAutorizacaoJob::class, fn (LiberarPreAutorizacaoJob $job) => $job->turnoId === $turno->id && $job->motivo === 'no_show');
});

test('CA-5: aguardando_checkin vencido também vira no_show_pro (PIN gerado mas nunca validado)', function () {
    Queue::fake();
    $turno = turnoComInicio(TurnoStatus::AguardandoCheckin, now()->subHours(3));

    detectar();

    expect($turno->fresh()->status)->toBe(TurnoStatus::NoShowPro);
});

test('CA-5: emite TurnoNoShow com turno_id UUID string (STORY-067 notifica ambos os lados)', function () {
    Event::fake([TurnoNoShow::class]);
    $turno = turnoComInicio(TurnoStatus::Confirmado, now()->subHours(2)->subMinute());

    detectar();

    Event::assertDispatched(TurnoNoShow::class, fn (TurnoNoShow $e) => $e->turnoId === $turno->id);
});

test('dentro da janela (1h59 de atraso) → permanece confirmado', function () {
    Queue::fake();
    $turno = turnoComInicio(TurnoStatus::Confirmado, now()->subHours(2)->addMinute());

    detectar();

    expect($turno->fresh()->status)->toBe(TurnoStatus::Confirmado);
    Queue::assertNotPushed(LiberarPreAutorizacaoJob::class);
});

test('check-in feito a tempo (ativo) ou turno encerrado → cron não toca', function () {
    Queue::fake();
    $ativo = turnoComInicio(TurnoStatus::Ativo, now()->subHours(4));
    $cancelado = turnoComInicio(TurnoStatus::CanceladoEmp, now()->subHours(4));
    $finalizado = turnoComInicio(TurnoStatus::Finalizado, now()->subHours(10));

    detectar();

    expect($ativo->fresh()->status)->toBe(TurnoStatus::Ativo)
        ->and($cancelado->fresh()->status)->toBe(TurnoStatus::CanceladoEmp)
        ->and($finalizado->fresh()->status)->toBe(TurnoStatus::Finalizado);
    Queue::assertNotPushed(LiberarPreAutorizacaoJob::class);
});

test('detecção em lote: vários turnos vencidos no mesmo tick, cada um com sua liberação', function () {
    Queue::fake();
    $a = turnoComInicio(TurnoStatus::Confirmado, now()->subHours(3));
    $b = turnoComInicio(TurnoStatus::AguardandoCheckin, now()->subHours(5));
    $dentro = turnoComInicio(TurnoStatus::Confirmado, now()->subHour());

    detectar();

    expect($a->fresh()->status)->toBe(TurnoStatus::NoShowPro)
        ->and($b->fresh()->status)->toBe(TurnoStatus::NoShowPro)
        ->and($dentro->fresh()->status)->toBe(TurnoStatus::Confirmado);
    Queue::assertPushed(LiberarPreAutorizacaoJob::class, 2);
});

test('idempotência do tick: rodar duas vezes não duplica audit nem liberação', function () {
    Queue::fake();
    $turno = turnoComInicio(TurnoStatus::Confirmado, now()->subHours(3));

    detectar();
    detectar();

    expect(AuditLog::where('action', 'turno.no_show_pro')->where('target_id', $turno->id)->count())->toBe(1);
    Queue::assertPushed(LiberarPreAutorizacaoJob::class, 1);
});

test('X configurável: turno.no_show_horas = 4 segura a transição até 4h (travel)', function () {
    config(['turno.no_show_horas' => 4]);
    Queue::fake();
    $turno = turnoComInicio(TurnoStatus::Confirmado, now()->subHours(3));

    detectar();
    expect($turno->fresh()->status)->toBe(TurnoStatus::Confirmado); // 3h < 4h

    $this->travel(1)->hours();
    $this->travel(1)->minutes();

    detectar();
    expect($turno->fresh()->status)->toBe(TurnoStatus::NoShowPro); // 4h01 > 4h
});

test('cron exercitado via travel (CA-8): turno futuro vira no_show após travel de 2h+1m do início', function () {
    Queue::fake();
    $turno = turnoComInicio(TurnoStatus::Confirmado, now()->addHour());

    detectar();
    expect($turno->fresh()->status)->toBe(TurnoStatus::Confirmado);

    $this->travelTo(now()->addHours(3)->addMinute()); // início (+1h) + 2h + 1m

    detectar();
    expect($turno->fresh()->status)->toBe(TurnoStatus::NoShowPro);
});

test('um turno problemático não derruba o lote (catch por linha; os demais transitam)', function () {
    Queue::fake();
    $quebrado = turnoComInicio(TurnoStatus::Confirmado, now()->subHours(3));
    $saudavel = turnoComInicio(TurnoStatus::Confirmado, now()->subHours(4));

    // Simula falha de persistência só no primeiro turno (ex.: deadlock/constraint).
    Turno::updating(function (Turno $model) use ($quebrado) {
        if ($model->id === $quebrado->id) {
            throw new RuntimeException('falha simulada de persistência');
        }
    });

    test()->artisan('turnos:detectar-no-show')->assertSuccessful();

    expect($quebrado->fresh()->status)->toBe(TurnoStatus::Confirmado) // tick seguinte retenta
        ->and($saudavel->fresh()->status)->toBe(TurnoStatus::NoShowPro);
    Queue::assertPushed(LiberarPreAutorizacaoJob::class, 1); // só o saudável libera
});

test('corrida: turno some entre a query e o lock → guard re-verificado, sem erro', function () {
    Queue::fake();
    $turno = turnoComInicio(TurnoStatus::Confirmado, now()->subHours(3));

    // Entre o ->get() do lote e o lockForUpdate()->find() por linha, o turno é validado
    // pelo contratante (vira ativo) — transição automática NÃO pode atropelar (CA-5).
    $disparado = false;
    Turno::retrieved(function (Turno $model) use ($turno, &$disparado) {
        if (! $disparado && $model->id === $turno->id) {
            $disparado = true; // só na 1ª recuperação (a do lote); SQL cru não re-dispara
            DB::statement("UPDATE turnos SET status = 'aguardando_checkin' WHERE id = ?", [$turno->id]);
            DB::statement("UPDATE turnos SET status = 'ativo' WHERE id = ?", [$turno->id]);
        }
    });

    test()->artisan('turnos:detectar-no-show')->assertSuccessful();

    expect($turno->fresh()->status)->toBe(TurnoStatus::Ativo); // intocado pelo cron
    Queue::assertNotPushed(LiberarPreAutorizacaoJob::class);
});

test('agendado em everyMinute no scheduler (reusa worker da STORY-034)', function () {
    $events = collect(app(Schedule::class)->events());
    $evento = $events->first(fn ($e) => str_contains((string) $e->command, 'turnos:detectar-no-show'));

    expect($evento)->not->toBeNull()
        ->and($evento->expression)->toBe('* * * * *');
});
