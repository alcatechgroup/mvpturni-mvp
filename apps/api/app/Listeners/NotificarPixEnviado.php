<?php

namespace App\Listeners;

use App\Enums\NotificacaoTipo;
use App\Events\Pagamento\PixEnviado;
use App\Services\Notificacao\NotificarEventoTurnoService;
use App\Services\Notificacao\PayloadNotificacaoTurno;

/**
 * STORY-067 (CA-1/CA-3) — `PixEnviado` (webhook do gateway, STORY-065) → `pix_enviado` ao
 * PROFISSIONAL. Redelivery do provedor traz `pagarme_event_id` NOVO para o mesmo Pix — a
 * chave usa só `{tipo}:{turno_id}` (PDR-010: um único Pix por turno), então não duplica.
 * Convive com o HandlePixEnviado da 065 (audit/timeline) no mesmo evento.
 */
class NotificarPixEnviado
{
    public function __construct(private readonly NotificarEventoTurnoService $svc) {}

    public function handle(PixEnviado $event): void
    {
        if (! $turno = $this->svc->turno($event->turnoId)) {
            return; // referência desconhecida não derruba o worker (mesmo racional da 065)
        }

        $this->svc->notificar($turno, NotificacaoTipo::PixEnviado, $turno->profissional_id, [
            'valor' => PayloadNotificacaoTurno::valor($turno),
        ]);
    }
}
