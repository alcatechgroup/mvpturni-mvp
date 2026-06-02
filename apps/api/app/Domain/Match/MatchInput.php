<?php

namespace App\Domain\Match;

/**
 * STORY-045 / ADR-014 (CA-2, CA-4). Entrada do cálculo de match — value object montado
 * pelo caller (feed/painel) a partir das entidades de domínio e da distância já computada
 * pela query do feed (ADR-013). Tudo explícito: o cálculo não lê banco nem relógio.
 *
 * `distanciaKm` null = geolocalização indisponível → componente de distância zera.
 * `raioMaxKm` é o raio máximo do profissional (parâmetro da entidade — CA-4).
 */
final class MatchInput
{
    /** @param list<int> $funcoesSecundariasProfIds */
    public function __construct(
        public readonly int $funcaoVagaId,
        public readonly int $funcaoPrimariaProfId,
        public readonly array $funcoesSecundariasProfIds,
        public readonly ?float $distanciaKm,
        public readonly int $raioMaxKm,
        public readonly ?float $scoreHistorico,
        public readonly int $turnosRealizados,
        public readonly ?string $nivel,
    ) {}
}
