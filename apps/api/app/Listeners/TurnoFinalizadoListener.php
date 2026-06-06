<?php

namespace App\Listeners;

use App\Events\TurnoFinalizado;
use App\Jobs\CapturarEPagarTurnoJob;

/**
 * STORY-065 (CA-1) — consome o `TurnoFinalizado` da STORY-064 e dispara o ciclo
 * financeiro pós-turno (captura + Pix) em job na fila `database` (ADR-002 — o
 * trabalho pesado roda no worker, nunca na request do check-out).
 *
 * Listener fino de propósito: a decisão de capturar pertence ao job (que re-verifica
 * o estado do turno — CA-9); aqui só traduzimos evento → job, síncrono dentro da
 * transação que finalizou o turno (mesmo racional do registro explícito da STORY-053).
 */
class TurnoFinalizadoListener
{
    public function handle(TurnoFinalizado $event): void
    {
        CapturarEPagarTurnoJob::dispatch($event->turnoId);
    }
}
