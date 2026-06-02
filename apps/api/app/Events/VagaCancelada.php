<?php

namespace App\Events;

use App\Models\Vaga;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * STORY-047 (CA-5) — evento de domínio disparado quando o contratante cancela uma
 * vaga (`aberta → cancelada`). STORY-053 consome este evento para notificar os
 * candidatos pendentes do cancelamento. `candidatosPendentes` carrega a contagem
 * apurada no momento do cancelamento (a notificação é responsabilidade do consumidor).
 */
class VagaCancelada
{
    use Dispatchable;
    use SerializesModels;

    public function __construct(
        public readonly Vaga $vaga,
        public readonly int $candidatosPendentes,
    ) {}
}
