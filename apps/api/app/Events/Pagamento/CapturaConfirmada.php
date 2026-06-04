<?php

namespace App\Events\Pagamento;

use Illuminate\Foundation\Events\Dispatchable;

/**
 * STORY-056 / ADR-016 (CA-6). Captura do valor pré-autorizado confirmada (webhook). Consumido
 * por STORY-065 (dispara o Pix) e STORY-067 (`turno_finalizado`).
 */
class CapturaConfirmada
{
    use Dispatchable;

    public function __construct(
        public readonly string $turnoId,
        public readonly string $pagarmeEventId,
        public readonly array $payload = [],
    ) {}
}
