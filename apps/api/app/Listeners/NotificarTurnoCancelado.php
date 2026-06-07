<?php

namespace App\Listeners;

use App\Enums\NotificacaoTipo;
use App\Events\TurnoCancelado;
use App\Services\Notificacao\NotificarEventoTurnoService;

/**
 * STORY-067 (CA-1) — `TurnoCancelado` (STORY-066) → `turno_cancelado` ao OUTRO lado:
 * `lado=pro` (profissional cancelou) notifica o contratante e vice-versa.
 *
 * `motivo_texto` é SEMPRE não-vazio (SCREEN-STORY-067 §5): o renderer de e-mail bloqueia
 * placeholder vazio — motivo ausente vira a frase padrão, nunca um `{motivo}` opcional.
 */
class NotificarTurnoCancelado
{
    public function __construct(private readonly NotificarEventoTurnoService $svc) {}

    public function handle(TurnoCancelado $event): void
    {
        if (! $turno = $this->svc->turno($event->turnoId)) {
            return;
        }

        $canceladoPeloProfissional = $event->lado === 'pro';

        $this->svc->notificar(
            $turno,
            NotificacaoTipo::TurnoCancelado,
            $canceladoPeloProfissional ? $turno->contratante_id : $turno->profissional_id,
            [
                'cancelado_por' => $canceladoPeloProfissional ? 'pelo profissional' : 'pelo contratante',
                'motivo_texto' => $event->motivo !== null && trim($event->motivo) !== ''
                    ? 'Motivo informado: "'.trim($event->motivo).'"'
                    : 'Nenhum motivo foi informado.',
            ],
        );
    }
}
