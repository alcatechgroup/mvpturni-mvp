<?php

namespace App\Listeners;

use App\Enums\NotificacaoTipo;
use App\Events\CheckinSolicitado;
use App\Services\Notificacao\NotificarEventoTurnoService;

/**
 * STORY-067 (CA-1/CA-3) — `CheckinSolicitado` (STORY-061) → `checkin_solicitado` ao
 * CONTRATANTE ("valide para iniciar"). Chave com `geracao_pin_id`: PIN re-gerado
 * RE-notifica; redelivery do mesmo evento não duplica.
 */
class NotificarCheckinSolicitado
{
    public function __construct(private readonly NotificarEventoTurnoService $svc) {}

    public function handle(CheckinSolicitado $event): void
    {
        if (! $turno = $this->svc->turno($event->turnoId)) {
            return;
        }

        $this->svc->notificar(
            $turno,
            NotificacaoTipo::CheckinSolicitado,
            $turno->contratante_id,
            ['profissional_nome' => (string) $turno->profissional?->name],
            sufixoChave: $event->geracaoPinId,
        );
    }
}
