<?php

namespace App\Events;

use Illuminate\Foundation\Events\Dispatchable;

/**
 * STORY-062 (CA-1) — evento de domínio disparado quando o contratante valida o PIN de
 * check-in e o turno transita aguardando_checkin → ativo. Consumidores: STORY-063
 * (cronômetro) e STORY-067 (notificação ao profissional). Carrega o `turno_id` UUIDv7
 * como string (ADR-018) — o consumidor recarrega o agregado, evitando serializar o
 * modelo num evento que pode ir para fila.
 */
class TurnoIniciado
{
    use Dispatchable;

    public function __construct(public readonly string $turnoId) {}
}
