<?php

namespace App\Support\Telemetry;

/**
 * STORY-045 / ADR-014 (CA-6). Motivos canônicos pelos quais uma vaga é filtrada do feed
 * antes de virar match — payload do evento `feed.vaga_filtrada` (domain/match.md).
 */
enum MotivoFiltro: string
{
    case FuncaoFora = 'funcao_fora';
    case ForaRaio = 'fora_raio';
    case ConflitoHorario = 'conflito_horario';
    case GateAvaliacao = 'gate_avaliacao';
}
