<?php

namespace App\Enums;

/**
 * STORY-056 / ADR-016 (CA-2, CA-5). As 5 operações financeiras que a ACL Pagar.me expõe,
 * em vocabulário do domínio Turni (domain/pagamento.md) — nenhuma cita o provedor.
 *
 * O valor de cada caso entra na chave idempotente determinística `"{tipo}:{turno_id}"`
 * (ADR-005 d) e na coluna `tipo_operacao` da `pagamento_operacoes`, cujo índice único
 * `(turno_id, tipo_operacao)` é a barreira de não-duplicação.
 *
 * `capturaParcial` existe desde já para o EPIC-005 (disputa, PDR-006), mas só é exercitada
 * quando a disputa for implementada — exposta na interface, não antecipada no fluxo.
 */
enum TipoOperacaoPagamento: string
{
    case PreAutorizacao = 'pre_autorizacao';
    case Captura = 'captura';
    case CapturaParcial = 'captura_parcial';
    case Liberacao = 'liberacao';
    case Pix = 'pix';

    /** Chave idempotente determinística da operação para um turno (ADR-005 d / ADR-016 b). */
    public function chaveIdempotente(string $turnoId): string
    {
        return "{$this->value}:{$turnoId}";
    }
}
