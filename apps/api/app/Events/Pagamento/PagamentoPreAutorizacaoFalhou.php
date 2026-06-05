<?php

namespace App\Events\Pagamento;

use Illuminate\Foundation\Events\Dispatchable;

/**
 * STORY-058 (CA-6) — pré-autorização do turno FALHOU de forma fatal (recusa do provedor —
 * PreAutorizacaoNegada). Registrada em `pagamento_operacoes` (status `falhou`) e no audit log;
 * o admin enxerga pela fila/Postgres. Sem retry automático (fora de escopo da estória; espelha
 * a postura do PDR-010 para Pix). Consumido por STORY-067 (alerta).
 */
class PagamentoPreAutorizacaoFalhou
{
    use Dispatchable;

    public function __construct(
        public readonly string $turnoId,
        public readonly string $motivo,
    ) {}
}
