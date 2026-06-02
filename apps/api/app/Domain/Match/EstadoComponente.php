<?php

namespace App\Domain\Match;

/**
 * STORY-045 / ADR-014 (CA-2). Estado visual de um componente do breakdown explicável
 * (domain/match.md): `ok` (pontuou cheio), `partial` (pontuou parcial), `miss` (zerou).
 * Como o breakdown é exibido a partir disto é decisão do Designer (STORY-049).
 */
enum EstadoComponente: string
{
    case Ok = 'ok';
    case Partial = 'partial';
    case Miss = 'miss';
}
