<?php

namespace App\Listeners;

use App\Enums\NotificacaoTipo;
use App\Events\TurnoNoShow;
use App\Services\Notificacao\NotificarEventoTurnoService;

/**
 * STORY-067 (CA-1/CA-3) — `TurnoNoShow` (cron da STORY-066) → `no_show_pro` para AMBOS os
 * lados (uma notificação por destinatário; chave sufixada pelo destinatário porque a UNIQUE
 * é por linha). Copy neutra única ("o check-in não aconteceu no prazo" — SCREEN-067 §2);
 * `no_show_prazo` vem da mesma config do cron (`turno.no_show_horas`).
 */
class NotificarTurnoNoShow
{
    public function __construct(private readonly NotificarEventoTurnoService $svc) {}

    public function handle(TurnoNoShow $event): void
    {
        if (! $turno = $this->svc->turno($event->turnoId)) {
            return;
        }

        $horas = (int) config('turno.no_show_horas');
        $extras = ['no_show_prazo' => $horas.($horas === 1 ? ' hora' : ' horas')];

        foreach ([$turno->profissional_id, $turno->contratante_id] as $destinatarioId) {
            $this->svc->notificar(
                $turno,
                NotificacaoTipo::NoShowPro,
                $destinatarioId,
                $extras,
                sufixoChave: $destinatarioId,
            );
        }
    }
}
