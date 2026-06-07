<?php

namespace App\Events;

use Illuminate\Foundation\Events\Dispatchable;

/**
 * STORY-067 (CA-1) — evento de domínio do turno criado em `confirmado` (aprovação da
 * candidatura, STORY-058). A 058 gravou a trilha (`turno.criado` em audit_logs) mas não
 * emitia o evento que a 067 consome — esta classe fecha o contrato. Disparado PÓS-COMMIT
 * pelo AprovarCandidaturaService (mesmo racional do TurnoCancelado/066). Consumidor:
 * NotificarTurnoCriado (`turno_confirmado` ao profissional). ADR-018: UUIDv7 string.
 */
class TurnoCriado
{
    use Dispatchable;

    public function __construct(public readonly string $turnoId) {}
}
