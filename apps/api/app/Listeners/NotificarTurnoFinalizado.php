<?php

namespace App\Listeners;

use App\Enums\NotificacaoTipo;
use App\Events\TurnoFinalizado;
use App\Services\Notificacao\NotificarEventoTurnoService;
use App\Services\Notificacao\PayloadNotificacaoTurno;

/**
 * STORY-067 (CA-1) — `TurnoFinalizado` (STORY-064, check-out validado) → `turno_finalizado`
 * ao PROFISSIONAL ("pagamento em processamento"). Convive com o TurnoFinalizadoListener da
 * 065 (captura+Pix) no mesmo evento — responsabilidades separadas, listeners separados.
 */
class NotificarTurnoFinalizado
{
    public function __construct(private readonly NotificarEventoTurnoService $svc) {}

    public function handle(TurnoFinalizado $event): void
    {
        if (! $turno = $this->svc->turno($event->turnoId)) {
            return;
        }

        $this->svc->notificar($turno, NotificacaoTipo::TurnoFinalizado, $turno->profissional_id, [
            'valor' => PayloadNotificacaoTurno::valor($turno),
        ]);
    }
}
