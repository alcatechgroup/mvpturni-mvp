<?php

// STORY-055 / ADR-015 (CA-4) — a máquina de estados como INVARIANTE DE BANCO: o trigger
// `enforce_turno_transition` aceita as transições válidas e rejeita as inválidas mesmo via
// SQL cru (à prova de bug de aplicação). Complementa o teste puro do enum (TurnoStatusTest).

use App\Enums\TurnoStatus;
use App\Models\Turno;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;

uses(RefreshDatabase::class);

/** UPDATE cru de status, contornando o domínio — exercita o trigger diretamente. */
function setStatusViaSql(Turno $turno, string $novo): void
{
    DB::statement('UPDATE turnos SET status = ? WHERE id = ?', [$novo, $turno->id]);
}

test('trigger aceita transição válida via SQL cru (confirmado → aguardando_checkin)', function () {
    $turno = Turno::factory()->status(TurnoStatus::Confirmado)->create();
    setStatusViaSql($turno, 'aguardando_checkin');
    expect($turno->fresh()->status)->toBe(TurnoStatus::AguardandoCheckin);
});

test('trigger REJEITA transição inválida via SQL cru (confirmado → finalizado)', function () {
    $turno = Turno::factory()->status(TurnoStatus::Confirmado)->create();
    expect(fn () => setStatusViaSql($turno, 'finalizado'))
        ->toThrow(Exception::class);
});

test('trigger impede pular o check-in (confirmado → ativo)', function () {
    $turno = Turno::factory()->status(TurnoStatus::Confirmado)->create();
    expect(fn () => setStatusViaSql($turno, 'ativo'))->toThrow(Exception::class);
});

test('trigger impede dois finais a partir de um terminal (cancelado_pro → ativo)', function () {
    $turno = Turno::factory()->status(TurnoStatus::CanceladoPro)->create();
    expect(fn () => setStatusViaSql($turno, 'ativo'))->toThrow(Exception::class);
});

test('trigger NÃO interfere em UPDATE que não muda o status (carimba check_in_at)', function () {
    $turno = Turno::factory()->status(TurnoStatus::Ativo)->create();
    DB::statement('UPDATE turnos SET check_in_at = NOW() WHERE id = ?', [$turno->id]);
    expect($turno->fresh()->check_in_at)->not->toBeNull();
});

test('todas as 14 transições válidas passam pelo trigger', function () {
    $validas = [
        [TurnoStatus::Confirmado, TurnoStatus::AguardandoCheckin],
        [TurnoStatus::Confirmado, TurnoStatus::CanceladoPro],
        [TurnoStatus::Confirmado, TurnoStatus::CanceladoEmp],
        // STORY-066 (CA-5) — cron de no-show vence turno cujo PIN nunca foi gerado.
        [TurnoStatus::Confirmado, TurnoStatus::NoShowPro],
        [TurnoStatus::AguardandoCheckin, TurnoStatus::Ativo],
        [TurnoStatus::AguardandoCheckin, TurnoStatus::Confirmado],
        [TurnoStatus::AguardandoCheckin, TurnoStatus::NoShowPro],
        [TurnoStatus::Ativo, TurnoStatus::AguardandoCheckout],
        [TurnoStatus::AguardandoCheckout, TurnoStatus::Finalizado],
        [TurnoStatus::AguardandoCheckout, TurnoStatus::EmDisputa],
        [TurnoStatus::AguardandoCheckout, TurnoStatus::Ativo],
        [TurnoStatus::EmDisputa, TurnoStatus::Finalizado],
        [TurnoStatus::EmDisputa, TurnoStatus::FinalizadoAjustado],
        [TurnoStatus::EmDisputa, TurnoStatus::DisputaResolvidaSemPagamento],
    ];

    foreach ($validas as [$de, $para]) {
        $turno = Turno::factory()->status($de)->create();
        setStatusViaSql($turno, $para->value);
        expect($turno->fresh()->status)->toBe($para, "{$de->value} → {$para->value} deveria passar");
    }
});

// ── Caminho do domínio (Turno::transitionTo) ──
test('transitionTo do domínio persiste e carimba check_in_at no →ativo', function () {
    $turno = Turno::factory()->status(TurnoStatus::AguardandoCheckin)->create(['check_in_at' => null]);
    $turno->transitionTo(TurnoStatus::Ativo);

    expect($turno->fresh()->status)->toBe(TurnoStatus::Ativo)
        ->and($turno->fresh()->check_in_at)->not->toBeNull();
});

test('transitionTo do domínio carimba check_out_at no →finalizado', function () {
    $turno = Turno::factory()->status(TurnoStatus::AguardandoCheckout)->create(['check_out_at' => null]);
    $turno->transitionTo(TurnoStatus::Finalizado);

    expect($turno->fresh()->status)->toBe(TurnoStatus::Finalizado)
        ->and($turno->fresh()->check_out_at)->not->toBeNull();
});

test('transitionTo do domínio lança DomainException em transição inválida (antes de tocar o banco)', function () {
    $turno = Turno::factory()->status(TurnoStatus::Confirmado)->create();
    expect(fn () => $turno->transitionTo(TurnoStatus::Finalizado))
        ->toThrow(DomainException::class);
});

test('caminho feliz completo confirmado → finalizado via domínio', function () {
    $turno = Turno::factory()->status(TurnoStatus::Confirmado)->create(['check_in_at' => null, 'check_out_at' => null]);

    $turno->transitionTo(TurnoStatus::AguardandoCheckin);
    $turno->transitionTo(TurnoStatus::Ativo);
    $turno->transitionTo(TurnoStatus::AguardandoCheckout);
    $turno->transitionTo(TurnoStatus::Finalizado);

    $fresh = $turno->fresh();
    expect($fresh->status)->toBe(TurnoStatus::Finalizado)
        ->and($fresh->check_in_at)->not->toBeNull()
        ->and($fresh->check_out_at)->not->toBeNull();
});
