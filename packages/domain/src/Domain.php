<?php

declare(strict_types=1);

namespace Turni\Domain;

/**
 * Marcador do package de domínio compartilhado (ADR-002/ADR-003).
 *
 * Nesta estória (STORY-006) o domínio ainda não tem modelagem — agregados,
 * Eloquent models e regras de negócio (Cadastro, Vaga, Candidatura, Match,
 * Turno, Pagamento, Disputa) entram no EPIC-001 em diante. Esta classe existe
 * só para provar que o path repository está ligado e que api/admin conseguem
 * consumir o domínio in-process (sem rede).
 */
final class Domain
{
    public const PACKAGE = 'turni/domain';

    public static function bootstrapped(): bool
    {
        return true;
    }
}
