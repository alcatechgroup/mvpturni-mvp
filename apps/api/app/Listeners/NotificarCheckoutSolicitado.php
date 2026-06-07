<?php

namespace App\Listeners;

use App\Enums\NotificacaoTipo;
use App\Events\CheckoutSolicitado;
use App\Services\Notificacao\NotificarEventoTurnoService;

/**
 * STORY-067 (CA-1/CA-3) — `CheckoutSolicitado` (STORY-064) → `checkout_solicitado` ao
 * CONTRATANTE ("valide para encerrar"). Espelho do check-in (chave por geração de PIN).
 */
class NotificarCheckoutSolicitado
{
    public function __construct(private readonly NotificarEventoTurnoService $svc) {}

    public function handle(CheckoutSolicitado $event): void
    {
        if (! $turno = $this->svc->turno($event->turnoId)) {
            return;
        }

        $this->svc->notificar(
            $turno,
            NotificacaoTipo::CheckoutSolicitado,
            $turno->contratante_id,
            ['profissional_nome' => (string) $turno->profissional?->name],
            sufixoChave: $event->geracaoPinId,
        );
    }
}
