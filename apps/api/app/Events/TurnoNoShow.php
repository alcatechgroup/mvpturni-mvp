<?php

namespace App\Events;

use Illuminate\Foundation\Events\Dispatchable;

/**
 * STORY-066 (CA-5/CA-6) — transição automática `confirmado|aguardando_checkin → no_show_pro`
 * detectada pelo cron `turnos:detectar-no-show` (X horas após o início previsto sem check-in;
 * X = config turno.no_show_horas — 2h, decisão do PO 2026-06-06). Consumidores:
 * TurnoNoShowListener (liberação da pré-autorização) e STORY-067 (notifica ambos os lados).
 * ADR-018: `turnoId` é UUIDv7 string.
 */
class TurnoNoShow
{
    use Dispatchable;

    public function __construct(public readonly string $turnoId) {}
}
