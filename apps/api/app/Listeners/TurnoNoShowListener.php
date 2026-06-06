<?php

namespace App\Listeners;

use App\Events\TurnoNoShow;
use App\Jobs\LiberarPreAutorizacaoJob;

/**
 * STORY-066 (CA-6) — consome o TurnoNoShow do cron e libera a pré-autorização igual ao
 * cancelamento, com motivo `no_show` (audit `pagamento.liberado` carrega o motivo).
 */
class TurnoNoShowListener
{
    public function handle(TurnoNoShow $event): void
    {
        LiberarPreAutorizacaoJob::dispatch($event->turnoId, 'no_show');
    }
}
