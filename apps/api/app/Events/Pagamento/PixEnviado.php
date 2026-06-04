<?php

namespace App\Events\Pagamento;

use Illuminate\Foundation\Events\Dispatchable;

/**
 * STORY-056 / ADR-016 (CA-6). Pix ao profissional confirmado pelo provedor (webhook).
 * Consumido por STORY-065 e STORY-067 (`pix_enviado`). Sem chave Pix no payload.
 */
class PixEnviado
{
    use Dispatchable;

    public function __construct(
        public readonly string $turnoId,
        public readonly string $pagarmeEventId,
        public readonly array $payload = [],
    ) {}
}
