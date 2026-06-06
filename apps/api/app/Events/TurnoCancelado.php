<?php

namespace App\Events;

use Illuminate\Foundation\Events\Dispatchable;

/**
 * STORY-066 (CA-3) — turno cancelado antes do check-in (PDR-007). Disparado PÓS-COMMIT pelo
 * CancelarTurnoService. Consumidores: TurnoCanceladoListener (liberação da pré-autorização
 * via ACL — esta estória) e STORY-067 (notificação ao outro lado, com o motivo).
 * ADR-018: `turnoId` é UUIDv7 string.
 */
class TurnoCancelado
{
    use Dispatchable;

    /** @param  'pro'|'emp'  $lado */
    public function __construct(
        public readonly string $turnoId,
        public readonly string $lado,
        public readonly ?string $motivo = null,
    ) {}
}
