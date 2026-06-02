<?php

namespace App\Events;

use App\Models\Candidatura;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * STORY-050 (CA-7) — evento de domínio disparado quando um profissional envia uma candidatura
 * (`pendente`). STORY-053 consome este evento para notificar o contratante da vaga (in-app +
 * e-mail) com nome e score do profissional. A candidatura carrega o `score_no_momento` e a
 * vaga relacionada — a notificação é responsabilidade do consumidor, não deste disparo.
 */
class CandidaturaEnviada
{
    use Dispatchable;
    use SerializesModels;

    public function __construct(public readonly Candidatura $candidatura) {}
}
