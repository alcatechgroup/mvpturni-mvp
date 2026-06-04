<?php

// STORY-055 / ADR-015 (CA-4, CA-8 núcleo ≥98%) — máquina de estados do Turno
// (domain/turno.md). Testes puros (sem DB) das 13 transições válidas + inválidas.

use App\Enums\TurnoStatus;

test('os 11 estados batem com o tipo Postgres turno_status (CA-2)', function () {
    expect(array_map(fn ($c) => $c->value, TurnoStatus::cases()))
        ->toBe([
            'confirmado',
            'aguardando_checkin',
            'ativo',
            'aguardando_checkout',
            'em_disputa',
            'finalizado',
            'finalizado_ajustado',
            'disputa_resolvida_sem_pagamento',
            'cancelado_pro',
            'cancelado_emp',
            'no_show_pro',
        ]);
});

// ── As 13 transições válidas (domain/turno.md) ──
dataset('transicoes_validas', [
    'confirmado → aguardando_checkin' => [TurnoStatus::Confirmado, TurnoStatus::AguardandoCheckin],
    'confirmado → cancelado_pro' => [TurnoStatus::Confirmado, TurnoStatus::CanceladoPro],
    'confirmado → cancelado_emp' => [TurnoStatus::Confirmado, TurnoStatus::CanceladoEmp],
    'aguardando_checkin → ativo' => [TurnoStatus::AguardandoCheckin, TurnoStatus::Ativo],
    'aguardando_checkin → confirmado (recusa)' => [TurnoStatus::AguardandoCheckin, TurnoStatus::Confirmado],
    'aguardando_checkin → no_show_pro (timeout)' => [TurnoStatus::AguardandoCheckin, TurnoStatus::NoShowPro],
    'ativo → aguardando_checkout' => [TurnoStatus::Ativo, TurnoStatus::AguardandoCheckout],
    'aguardando_checkout → finalizado' => [TurnoStatus::AguardandoCheckout, TurnoStatus::Finalizado],
    'aguardando_checkout → em_disputa' => [TurnoStatus::AguardandoCheckout, TurnoStatus::EmDisputa],
    'aguardando_checkout → ativo (cancela solicitação)' => [TurnoStatus::AguardandoCheckout, TurnoStatus::Ativo],
    'em_disputa → finalizado' => [TurnoStatus::EmDisputa, TurnoStatus::Finalizado],
    'em_disputa → finalizado_ajustado' => [TurnoStatus::EmDisputa, TurnoStatus::FinalizadoAjustado],
    'em_disputa → disputa_resolvida_sem_pagamento' => [TurnoStatus::EmDisputa, TurnoStatus::DisputaResolvidaSemPagamento],
]);

test('transição válida é aceita', function (TurnoStatus $de, TurnoStatus $para) {
    expect($de->canTransitionTo($para))->toBeTrue();
})->with('transicoes_validas');

test('existem exatamente 13 transições válidas no total', function () {
    $total = 0;
    foreach (TurnoStatus::cases() as $de) {
        foreach (TurnoStatus::cases() as $para) {
            if ($de->canTransitionTo($para)) {
                $total++;
            }
        }
    }
    expect($total)->toBe(13);
});

// ── Transições inválidas representativas ──
dataset('transicoes_invalidas', [
    'confirmado → finalizado (pula tudo)' => [TurnoStatus::Confirmado, TurnoStatus::Finalizado],
    'confirmado → ativo (pula check-in)' => [TurnoStatus::Confirmado, TurnoStatus::Ativo],
    'aguardando_checkin → aguardando_checkout (pula ativo)' => [TurnoStatus::AguardandoCheckin, TurnoStatus::AguardandoCheckout],
    'ativo → finalizado (pula check-out)' => [TurnoStatus::Ativo, TurnoStatus::Finalizado],
    'finalizado → ativo (terminal)' => [TurnoStatus::Finalizado, TurnoStatus::Ativo],
    'cancelado_pro → confirmado (terminal)' => [TurnoStatus::CanceladoPro, TurnoStatus::Confirmado],
    'no_show_pro → ativo (terminal)' => [TurnoStatus::NoShowPro, TurnoStatus::Ativo],
    'ativo → cancelado_pro (cancelar fora de confirmado, PDR-007)' => [TurnoStatus::Ativo, TurnoStatus::CanceladoPro],
]);

test('transição inválida é recusada', function (TurnoStatus $de, TurnoStatus $para) {
    expect($de->canTransitionTo($para))->toBeFalse();
})->with('transicoes_invalidas');

test('transição para o mesmo estado é inválida', function () {
    foreach (TurnoStatus::cases() as $estado) {
        expect($estado->canTransitionTo($estado))->toBeFalse();
    }
});

// ── Estados terminais ──
test('estados terminais não têm transição de saída', function () {
    $terminais = [
        TurnoStatus::Finalizado,
        TurnoStatus::FinalizadoAjustado,
        TurnoStatus::DisputaResolvidaSemPagamento,
        TurnoStatus::CanceladoPro,
        TurnoStatus::CanceladoEmp,
        TurnoStatus::NoShowPro,
    ];
    foreach ($terminais as $t) {
        expect($t->ehTerminal())->toBeTrue();
        foreach (TurnoStatus::cases() as $para) {
            expect($t->canTransitionTo($para))->toBeFalse();
        }
    }
});

test('estados não-terminais têm ehTerminal() false', function () {
    foreach ([TurnoStatus::Confirmado, TurnoStatus::AguardandoCheckin, TurnoStatus::Ativo, TurnoStatus::AguardandoCheckout, TurnoStatus::EmDisputa] as $e) {
        expect($e->ehTerminal())->toBeFalse();
    }
});

// ── Cancelamento permitido só em confirmado (PDR-007) ──
test('cancelamento é permitido apenas em confirmado (PDR-007)', function () {
    expect(TurnoStatus::Confirmado->podeCancelar())->toBeTrue();
    foreach (TurnoStatus::cases() as $e) {
        if ($e !== TurnoStatus::Confirmado) {
            expect($e->podeCancelar())->toBeFalse();
        }
    }
});
