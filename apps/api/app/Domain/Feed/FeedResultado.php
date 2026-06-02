<?php

namespace App\Domain\Feed;

/**
 * STORY-048 (CA-1, CA-10). Página do feed: as vagas pontuadas e ordenadas (score DESC,
 * boost DESC, data ASC), a página atual e se há próxima. Paginação page-based (page size
 * 20) sobre o conjunto candidato já capado em 100 (ADR-013/ADR-014).
 */
final class FeedResultado
{
    /** @param list<FeedVaga> $vagas */
    public function __construct(
        public readonly array $vagas,
        public readonly int $page,
        public readonly bool $hasNext,
    ) {}
}
