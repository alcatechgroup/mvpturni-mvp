<?php

namespace App\Listeners;

use App\Enums\NotificacaoTipo;
use App\Events\TurnoIniciado;
use App\Services\Notificacao\NotificarEventoTurnoService;

/**
 * STORY-067 (CA-1) — `TurnoIniciado` (STORY-062, check-in validado) → `turno_ativo` ao
 * PROFISSIONAL ("o cronômetro está rodando"). Idempotente por `{tipo}:{turno_id}`.
 */
class NotificarTurnoIniciado
{
    public function __construct(private readonly NotificarEventoTurnoService $svc) {}

    public function handle(TurnoIniciado $event): void
    {
        if (! $turno = $this->svc->turno($event->turnoId)) {
            return;
        }

        $this->svc->notificar($turno, NotificacaoTipo::TurnoAtivo, $turno->profissional_id);
    }
}
