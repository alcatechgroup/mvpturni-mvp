<?php

namespace App\Enums;

/**
 * STORY-085 / ADR-019 Decisão 1. Direção da avaliação recíproca — espelha o enum nativo
 * `avaliacao_direcao` (migração `create_avaliacoes_table`). O `UNIQUE (turno_id, direcao)`
 * exprime literalmente a regra "uma avaliação por direção por turno" (PDR-005).
 */
enum AvaliacaoDirecao: string
{
    case ContratanteParaProfissional = 'contratante_para_profissional';
    case ProfissionalParaContratante = 'profissional_para_contratante';

    /** A direção do papel que está avaliando — quem é o autor define o sentido. */
    public function ehAutorContratante(): bool
    {
        return $this === self::ContratanteParaProfissional;
    }
}
