<?php

namespace App\Events;

use Illuminate\Foundation\Events\Dispatchable;

/**
 * STORY-064 (CA-3) — evento de domínio disparado quando o contratante valida o PIN de
 * check-out e o turno transita aguardando_checkout → finalizado. Consumidores: STORY-065
 * (captura do pagamento + Pix) e STORY-067 (notificação). Carrega o `turno_id` UUIDv7
 * como string (ADR-018) — o consumidor recarrega o agregado, evitando serializar o
 * modelo num evento que pode ir para fila. Espelho do TurnoIniciado da 062.
 */
class TurnoFinalizado
{
    use Dispatchable;

    public function __construct(public readonly string $turnoId) {}
}
