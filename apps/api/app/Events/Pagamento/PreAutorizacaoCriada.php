<?php

namespace App\Events\Pagamento;

use Illuminate\Foundation\Events\Dispatchable;

/**
 * STORY-056 / ADR-016 (CA-6). Pré-autorização confirmada pelo provedor (webhook). Consumido
 * por STORY-067 (notifica `turno_confirmado`). `payload` carrega o evento bruto do provedor
 * para a trilha; nenhuma PII (chave Pix) trafega nestes eventos financeiros.
 */
class PreAutorizacaoCriada
{
    use Dispatchable;

    public function __construct(
        public readonly string $turnoId,
        public readonly string $pagarmeEventId,
        public readonly array $payload = [],
    ) {}
}
