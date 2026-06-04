<?php

namespace App\Events\Pagamento;

use Illuminate\Foundation\Events\Dispatchable;

/**
 * STORY-056 / ADR-016 (CA-6). Pré-autorização liberada (webhook `charge.canceled`/refunded):
 * cancelamento, no-show ou disputa sem pagamento. Consumido por STORY-066 e STORY-067
 * (`turno_cancelado` / `no_show_pro`).
 */
class PreAutorizacaoLiberada
{
    use Dispatchable;

    public function __construct(
        public readonly string $turnoId,
        public readonly string $pagarmeEventId,
        public readonly array $payload = [],
    ) {}
}
