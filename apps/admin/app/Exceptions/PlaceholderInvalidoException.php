<?php

namespace App\Exceptions;

use RuntimeException;

/**
 * STORY-020 (CA-5) — Lançada quando o conteúdo de uma versão contém um placeholder fora da
 * lista canônica (ADR-010). Carrega o placeholder problemático para uma mensagem acionável.
 */
class PlaceholderInvalidoException extends RuntimeException
{
    /** @param list<string> $placeholders */
    public function __construct(public readonly array $placeholders)
    {
        $lista = implode(', ', array_map(fn ($p) => '{{'.$p.'}}', $placeholders));

        parent::__construct("Placeholder fora da lista canônica: {$lista}");
    }
}
