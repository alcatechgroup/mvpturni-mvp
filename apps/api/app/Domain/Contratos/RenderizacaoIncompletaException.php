<?php

namespace App\Domain\Contratos;

use RuntimeException;

/**
 * Placeholder do template sem valor no contexto de renderização (ADR-010 Decisão 3:
 * falha dura — nunca renderiza texto jurídico com lacuna silenciosa). Impede a
 * criação de um AceiteEletronico incompleto.
 */
class RenderizacaoIncompletaException extends RuntimeException
{
    /** @param list<string> $placeholders */
    public function __construct(public readonly array $placeholders)
    {
        parent::__construct('Placeholder(s) sem valor na renderização do aceite: '.implode(', ', $placeholders));
    }
}
