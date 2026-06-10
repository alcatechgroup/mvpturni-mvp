<?php

namespace App\Events;

use Illuminate\Foundation\Events\Dispatchable;

/**
 * STORY-092 / ADR-020 (Decisão 4) — evento NOVO disparado pós-commit da transição
 * `aguardando_checkout → em_disputa` (AbrirDisputaService). Consumidor: NotificarDisputaAberta
 * (in-app + e-mail ao PROFISSIONAL — "valor em disputa, mediação em até 30 min"). Carrega só o
 * `turno_id` UUIDv7 como string (ADR-018); o listener recarrega o agregado. Espelho do
 * TurnoFinalizado da 064.
 */
class DisputaAberta
{
    use Dispatchable;

    public function __construct(public readonly string $turnoId) {}
}
