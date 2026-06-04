<?php

namespace App\Enums;

/**
 * STORY-055 / ADR-015 (CA-2, CA-4). Os 11 estados do Turno (domain/turno.md). O tipo é um
 * enum NATIVO do Postgres (`turno_status`); este enum PHP espelha os rótulos e carrega as
 * 13 transições válidas.
 *
 * Diferente de VagaEstado/CandidaturaEstado (ADR-013, transições só no domínio), aqui a
 * máquina de estados também é INVARIANTE DE BANCO: o trigger `enforce_turno_transition`
 * (migration) é a garantia dura (CA-4); este enum é a camada ergonômica (fail-closed) usada
 * pelo domínio e pelos testes. Os dois devem concordar — qualquer divergência é bug.
 */
enum TurnoStatus: string
{
    case Confirmado = 'confirmado';
    case AguardandoCheckin = 'aguardando_checkin';
    case Ativo = 'ativo';
    case AguardandoCheckout = 'aguardando_checkout';
    case EmDisputa = 'em_disputa';
    case Finalizado = 'finalizado';
    case FinalizadoAjustado = 'finalizado_ajustado';
    case DisputaResolvidaSemPagamento = 'disputa_resolvida_sem_pagamento';
    case CanceladoPro = 'cancelado_pro';
    case CanceladoEmp = 'cancelado_emp';
    case NoShowPro = 'no_show_pro';

    /** Uma transição é válida apenas se mapeada aqui (fail-closed) — as 13 de turno.md. */
    public function canTransitionTo(self $to): bool
    {
        return match ($this) {
            // confirmado → aguardando_checkin (gera PIN) | cancelado_pro | cancelado_emp
            self::Confirmado => in_array($to, [
                self::AguardandoCheckin,
                self::CanceladoPro,
                self::CanceladoEmp,
            ], true),
            // aguardando_checkin → ativo (valida) | confirmado (recusa, novo PIN) | no_show_pro (timeout)
            self::AguardandoCheckin => in_array($to, [
                self::Ativo,
                self::Confirmado,
                self::NoShowPro,
            ], true),
            // ativo → aguardando_checkout (gera PIN check-out)
            self::Ativo => $to === self::AguardandoCheckout,
            // aguardando_checkout → finalizado (valida) | em_disputa (contesta) | ativo (cancela solicitação)
            self::AguardandoCheckout => in_array($to, [
                self::Finalizado,
                self::EmDisputa,
                self::Ativo,
            ], true),
            // em_disputa → finalizado | finalizado_ajustado | disputa_resolvida_sem_pagamento (admin resolve)
            self::EmDisputa => in_array($to, [
                self::Finalizado,
                self::FinalizadoAjustado,
                self::DisputaResolvidaSemPagamento,
            ], true),
            // terminais: finalizado*, disputa_resolvida_sem_pagamento, cancelado_*, no_show_pro
            self::Finalizado,
            self::FinalizadoAjustado,
            self::DisputaResolvidaSemPagamento,
            self::CanceladoPro,
            self::CanceladoEmp,
            self::NoShowPro => false,
        };
    }

    /** Estados em que o cancelamento é permitido (PDR-007 — só antes do check-in). */
    public function podeCancelar(): bool
    {
        return $this === self::Confirmado;
    }

    /** True para os estados terminais (não há transição de saída). */
    public function ehTerminal(): bool
    {
        return match ($this) {
            self::Finalizado,
            self::FinalizadoAjustado,
            self::DisputaResolvidaSemPagamento,
            self::CanceladoPro,
            self::CanceladoEmp,
            self::NoShowPro => true,
            default => false,
        };
    }
}
