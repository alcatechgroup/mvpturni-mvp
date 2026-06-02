<?php

namespace App\Domain\Match;

use App\Models\ProfissionalProfile;
use App\Models\Vaga;

/**
 * STORY-045 / ADR-014 (CA-2). Adapter (cola) entre as entidades de domínio e o núcleo
 * puro: monta o MatchInput a partir de atributos JÁ hidratados de ProfissionalProfile e
 * Vaga + a distância computada pela query do feed (ADR-013), e delega ao MatchCalculator.
 * Esta é a fronteira que conhece o Eloquent — o cálculo em si permanece puro (CA-4).
 *
 * A distância NÃO é recomputada aqui: a query do feed já a calcula para filtrar por raio
 * (ADR-013); recomputá-la duplicaria trabalho e exigiria geo do profissional no cálculo.
 * Persistir lat/lng do profissional e injetar `distanciaKm` é trabalho de STORY-048.
 */
final class MatchScoring
{
    public function __construct(
        private readonly MatchCalculator $calculator = new MatchCalculator,
    ) {}

    public function paraEntidades(ProfissionalProfile $profissional, Vaga $vaga, ?float $distanciaKm): MatchScore
    {
        return $this->calculator->calcular(new MatchInput(
            funcaoVagaId: (int) $vaga->funcao_id,
            funcaoPrimariaProfId: (int) $profissional->funcao_id,
            funcoesSecundariasProfIds: array_map('intval', $profissional->funcoes_secundarias ?? []),
            distanciaKm: $distanciaKm,
            raioMaxKm: (int) ($profissional->raio_max_km ?? 0),
            scoreHistorico: $profissional->score !== null ? (float) $profissional->score : null,
            turnosRealizados: (int) ($profissional->turnos_realizados ?? 0),
            nivel: $profissional->nivel,
        ));
    }
}
