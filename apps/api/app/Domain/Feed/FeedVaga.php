<?php

namespace App\Domain\Feed;

use App\Domain\Match\MatchScore;
use App\Models\Vaga;

/**
 * STORY-048 (CA-1). Uma vaga já pontuada para o feed: a entidade, a distância calculada
 * (null = geo do profissional/vaga indisponível) e o MatchScore (ADR-014). `jaCandidatou`
 * marca se o profissional já tem candidatura ativa nesta vaga.
 */
final class FeedVaga
{
    public function __construct(
        public readonly Vaga $vaga,
        public readonly ?float $distanciaKm,
        public readonly MatchScore $score,
        public readonly bool $jaCandidatou,
    ) {}
}
