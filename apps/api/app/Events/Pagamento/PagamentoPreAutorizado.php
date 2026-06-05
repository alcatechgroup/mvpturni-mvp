<?php

namespace App\Events\Pagamento;

use Illuminate\Foundation\Events\Dispatchable;

/**
 * STORY-058 (CA-6) — pré-autorização do turno CONCLUÍDA pela ACL (chamada síncrona do worker
 * ao gateway, via OperacaoIdempotente). Distinto de PreAutorizacaoCriada (que nasce do webhook
 * do provedor): este é o desfecho da operação disparada no aceite. Consumido por STORY-067
 * (notificações). Sem PII — só correlação.
 */
class PagamentoPreAutorizado
{
    use Dispatchable;

    public function __construct(
        public readonly string $turnoId,
        public readonly ?string $pagarmeChargeId = null,
    ) {}
}
