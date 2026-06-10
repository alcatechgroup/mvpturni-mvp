<?php

namespace App\Listeners;

use App\Enums\NotificacaoTipo;
use App\Events\DisputaAberta;
use App\Services\Notificacao\NotificarEventoTurnoService;

/**
 * STORY-092 / ADR-020 (Decisão 4) — `DisputaAberta` (AbrirDisputaService) → `disputa_aberta`
 * ao PROFISSIONAL ("valor em disputa — mediação em até 30 min"). A justificativa do contratante
 * NÃO entra no payload — o profissional não a vê em lugar nenhum (DDR-005 Decisão 2); só o
 * payload comum (vaga/estabelecimento/data/link). Idempotente pela chave `disputa_aberta:{turno}`
 * do CriarNotificacaoService (reprocesso/replay não duplica — CA-6).
 */
class NotificarDisputaAberta
{
    public function __construct(private readonly NotificarEventoTurnoService $svc) {}

    public function handle(DisputaAberta $event): void
    {
        if (! $turno = $this->svc->turno($event->turnoId)) {
            return;
        }

        $this->svc->notificar($turno, NotificacaoTipo::DisputaAberta, $turno->profissional_id);
    }
}
