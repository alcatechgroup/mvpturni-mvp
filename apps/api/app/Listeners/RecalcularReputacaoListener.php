<?php

namespace App\Listeners;

use App\Domain\Avaliacao\MotorReputacao;
use App\Events\AvaliacaoRegistrada;
use App\Models\User;

/**
 * STORY-085 / ADR-019 Decisão 3/4 — roda o MotorReputacao síncrono ao `AvaliacaoRegistrada`.
 * Recarrega o avaliado pelo id (defensivo: id desconhecido = no-op, não derruba a transação)
 * e recomputa score/XP/nível dele. Idempotente por construção (o motor recomputa do zero).
 */
class RecalcularReputacaoListener
{
    public function __construct(private readonly MotorReputacao $motor) {}

    public function handle(AvaliacaoRegistrada $event): void
    {
        if (! $avaliado = User::find($event->avaliadoId)) {
            return;
        }

        $this->motor->recalcular($avaliado);
    }
}
