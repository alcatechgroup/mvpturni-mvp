<?php

namespace App\Listeners;

use App\Enums\NotificacaoTipo;
use App\Events\TurnoCriado;
use App\Services\Notificacao\NotificarEventoTurnoService;
use App\Services\Notificacao\PayloadNotificacaoTurno;

/**
 * STORY-067 (CA-1) — `TurnoCriado` (STORY-058) → `turno_confirmado` ao PROFISSIONAL,
 * com o valor que ele recebe (SCREEN-STORY-067 §2). Idempotente por `{tipo}:{turno_id}`.
 */
class NotificarTurnoCriado
{
    public function __construct(private readonly NotificarEventoTurnoService $svc) {}

    public function handle(TurnoCriado $event): void
    {
        if (! $turno = $this->svc->turno($event->turnoId)) {
            return;
        }

        $this->svc->notificar($turno, NotificacaoTipo::TurnoConfirmado, $turno->profissional_id, [
            'valor' => PayloadNotificacaoTurno::valor($turno),
        ]);
    }
}
