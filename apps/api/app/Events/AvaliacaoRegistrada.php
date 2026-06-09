<?php

namespace App\Events;

use Illuminate\Foundation\Events\Dispatchable;

/**
 * STORY-085 / ADR-019 Decisão 3 — evento de domínio disparado DENTRO da transação que insere
 * a linha em `avaliacoes`. Consumidor: RecalcularReputacaoListener (motor de reputação,
 * síncrono). Payload mínimo de IDs string UUID (ADR-018) — o listener recarrega o agregado.
 * Síncrono na transação (não pós-commit como TurnoFinalizado): avaliação e reputação commitam
 * juntas ou nada (consistência transacional + reputação visível em ≤1s).
 */
class AvaliacaoRegistrada
{
    use Dispatchable;

    public function __construct(
        public readonly string $avaliacaoId,
        public readonly string $avaliadoId,
        public readonly string $turnoId,
    ) {}
}
