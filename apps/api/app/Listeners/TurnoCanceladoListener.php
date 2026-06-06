<?php

namespace App\Listeners;

use App\Events\TurnoCancelado;
use App\Jobs\LiberarPreAutorizacaoJob;

/**
 * STORY-066 (CA-2) — consome o TurnoCancelado e dispara a liberação da pré-autorização
 * em job na fila `database` (ADR-002 — gateway nunca na request do cancelamento).
 * Listener fino: a decisão de liberar pertence ao job (que re-verifica o estado).
 */
class TurnoCanceladoListener
{
    public function handle(TurnoCancelado $event): void
    {
        LiberarPreAutorizacaoJob::dispatch($event->turnoId, 'cancelamento');
    }
}
