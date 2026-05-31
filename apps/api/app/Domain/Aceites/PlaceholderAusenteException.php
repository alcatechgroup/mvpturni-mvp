<?php

namespace App\Domain\Aceites;

use RuntimeException;

/**
 * STORY-023 / ADR-010 Decisão 3A — falha dura: o aceite NUNCA é gerado com texto incompleto.
 * Lançada quando o template referencia um placeholder sem valor no contexto de renderização.
 */
class PlaceholderAusenteException extends RuntimeException
{
    public function __construct(public readonly string $placeholder)
    {
        parent::__construct("Placeholder sem valor no contexto de renderização: {{{$placeholder}}}");
    }
}
