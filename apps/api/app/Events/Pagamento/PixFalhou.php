<?php

namespace App\Events\Pagamento;

use Illuminate\Foundation\Events\Dispatchable;

/**
 * STORY-056 / ADR-016 (CA-6). Pix falhou (webhook `transfer.failed`). PDR-010: UMA tentativa,
 * SEM retry automático. STORY-065 wira a policy de ALERTA no admin a partir deste evento.
 */
class PixFalhou
{
    use Dispatchable;

    public function __construct(
        public readonly string $turnoId,
        public readonly string $pagarmeEventId,
        public readonly array $payload = [],
    ) {}
}
