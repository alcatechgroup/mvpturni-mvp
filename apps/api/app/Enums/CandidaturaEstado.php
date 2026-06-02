<?php

namespace App\Enums;

/**
 * STORY-044 / ADR-013 (CA-4, Decisão 2). Estados da Candidatura. Enum NATIVO do Postgres
 * (`candidatura_estado`); este enum PHP espelha os rótulos e as transições válidas.
 * Transições: domain/candidatura.md + PDR-009. `Recusada` existe para compat futura,
 * mas não é alcançável no MVP (domain/candidatura.md §lacunas).
 */
enum CandidaturaEstado: string
{
    case Pendente = 'pendente';
    case Aprovada = 'aprovada';
    case Retirada = 'retirada';
    case PendenteRevisaoAposEdicao = 'pendente_revisao_apos_edicao';
    case RetiradaPorEdicao = 'retirada_por_edicao';
    case Recusada = 'recusada';

    public function canTransitionTo(self $to): bool
    {
        return match ($this) {
            self::Pendente => in_array($to, [
                self::Aprovada,
                self::Retirada,
                self::PendenteRevisaoAposEdicao,
            ], true),
            // PDR-009: confirma manutenção (→pendente) ou retira/estoura prazo.
            self::PendenteRevisaoAposEdicao => in_array($to, [
                self::Pendente,
                self::RetiradaPorEdicao,
            ], true),
            // estados terminais
            self::Aprovada, self::Retirada, self::RetiradaPorEdicao, self::Recusada => false,
        };
    }
}
