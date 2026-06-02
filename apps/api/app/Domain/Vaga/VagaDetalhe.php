<?php

namespace App\Domain\Vaga;

use App\Domain\Match\MatchScore;
use App\Models\Candidatura;
use App\Models\Vaga;

/**
 * STORY-049 (CA-1). Detalhe de uma vaga já pontuada para o profissional: a entidade (com
 * função + contratante hidratados), a distância calculada (null = geo indisponível), o
 * MatchScore com breakdown completo (ADR-014), e a candidatura vigente do profissional
 * nesta vaga (null se não candidatou) — fonte de `ja_candidatou` e do estado "Você já se
 * candidatou" (SCREEN-049 §4.3).
 */
final class VagaDetalhe
{
    public function __construct(
        public readonly Vaga $vaga,
        public readonly ?float $distanciaKm,
        public readonly MatchScore $score,
        public readonly ?Candidatura $candidatura,
    ) {}

    public function jaCandidatou(): bool
    {
        return $this->candidatura !== null;
    }
}
