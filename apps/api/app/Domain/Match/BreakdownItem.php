<?php

namespace App\Domain\Match;

/**
 * STORY-045 / ADR-014 (CA-2). Um item do breakdown explicável do match: pontos obtidos,
 * teto do componente, estado visual e descrição em prosa curta. Value object imutável.
 * Defensivo: `pontos` é sempre clampado em [0, pontosMax] — nenhum componente passa do
 * seu teto (sustenta o cap de 100 do MatchScore mesmo diante de erro do cálculo).
 */
final class BreakdownItem
{
    public readonly int $pontos;

    public function __construct(
        int $pontos,
        public readonly int $pontosMax,
        public readonly EstadoComponente $estado,
        public readonly string $descricao,
    ) {
        $this->pontos = max(0, min($pontos, $pontosMax));
    }

    /** @return array{pontos:int,pontos_max:int,estado:string,descricao:string} */
    public function toArray(): array
    {
        return [
            'pontos' => $this->pontos,
            'pontos_max' => $this->pontosMax,
            'estado' => $this->estado->value,
            'descricao' => $this->descricao,
        ];
    }
}
