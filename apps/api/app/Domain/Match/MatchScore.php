<?php

namespace App\Domain\Match;

/**
 * STORY-045 / ADR-014 (CA-2, CA-3). Resultado do match: total (0–100), os 4 componentes
 * e o breakdown explicável. Value object imutável.
 *
 * Cap (CA-3): o total é clampado em 100. Com os pesos canônicos (40+20+30+10) o máximo
 * teórico já é exatamente 100, então o `min` é uma invariante defensiva — protege contra
 * futura mudança de pesos ou erro de arredondamento. Cada componente já vem clampado ao
 * seu teto pelo BreakdownItem.
 */
final class MatchScore
{
    public readonly int $total;

    /** @var array{funcao:int,distancia:int,historico:int,nivel:int} */
    public readonly array $componentes;

    public function __construct(
        public readonly BreakdownItem $funcao,
        public readonly BreakdownItem $distancia,
        public readonly BreakdownItem $historico,
        public readonly BreakdownItem $nivel,
    ) {
        $this->componentes = [
            'funcao' => $funcao->pontos,
            'distancia' => $distancia->pontos,
            'historico' => $historico->pontos,
            'nivel' => $nivel->pontos,
        ];

        $this->total = min(100, $funcao->pontos + $distancia->pontos + $historico->pontos + $nivel->pontos);
    }

    /**
     * @return array{
     *     total:int,
     *     componentes:array{funcao:int,distancia:int,historico:int,nivel:int},
     *     breakdown:array{funcao:array,distancia:array,historico:array,nivel:array}
     * }
     */
    public function toArray(): array
    {
        return [
            'total' => $this->total,
            'componentes' => $this->componentes,
            'breakdown' => [
                'funcao' => $this->funcao->toArray(),
                'distancia' => $this->distancia->toArray(),
                'historico' => $this->historico->toArray(),
                'nivel' => $this->nivel->toArray(),
            ],
        ];
    }
}
