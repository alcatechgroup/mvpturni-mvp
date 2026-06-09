<?php

namespace App\Domain\Avaliacao\Exceptions;

use DomainException;

/**
 * STORY-085 (CA-3) — só `finalizado`/`finalizado_ajustado` são avaliáveis (ADR-015/019).
 * Carrega o estado atual para a mensagem do cliente.
 */
class TurnoNaoAvaliavelException extends DomainException
{
    public function __construct(public readonly string $estado)
    {
        parent::__construct("Turno não avaliável no estado {$estado}.");
    }
}
