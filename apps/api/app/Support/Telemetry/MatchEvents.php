<?php

namespace App\Support\Telemetry;

use App\Domain\Match\MatchScore;
use Illuminate\Support\Facades\Log;

/**
 * STORY-045 / ADR-014 (CA-6). Eventos de telemetria do Match emitidos como log JSON
 * estruturado (ADR-008) — sem tabela própria no MVP. O campo `event` nomeia o
 * acontecimento e o restante é o payload mínimo fixado na ADR. Estes sinais alimentam
 * o refino futuro do algoritmo (match.md "Lacunas conhecidas") e o motor de notificação.
 *
 * Nomes canônicos (notação com ponto, ADR-014 CA-6):
 *   feed.vaga_apresentada · feed.vaga_filtrada · match.candidatura_enviada · match.candidatura_aprovada
 */
final class MatchEvents
{
    /** Vaga entrou no feed do profissional com um score. */
    public static function vagaApresentada(string $vagaId, string $profissionalId, MatchScore $score): void
    {
        Log::info('feed.vaga_apresentada', [
            'event' => 'feed.vaga_apresentada',
            'vaga_id' => $vagaId,
            'profissional_id' => $profissionalId,
            'score_total' => $score->total,
            'componentes' => $score->componentes,
        ]);
    }

    /** Vaga ficou de fora do feed por um filtro (função, raio, horário, gate de avaliação). */
    public static function vagaFiltrada(string $vagaId, string $profissionalId, MotivoFiltro $motivo): void
    {
        Log::info('feed.vaga_filtrada', [
            'event' => 'feed.vaga_filtrada',
            'vaga_id' => $vagaId,
            'profissional_id' => $profissionalId,
            'motivo_filtro' => $motivo->value,
        ]);
    }

    /** Profissional se candidatou; o score do momento é registrado. */
    public static function candidaturaEnviada(string $vagaId, string $profissionalId, string $candidaturaId, MatchScore $score): void
    {
        Log::info('match.candidatura_enviada', [
            'event' => 'match.candidatura_enviada',
            'vaga_id' => $vagaId,
            'profissional_id' => $profissionalId,
            'candidatura_id' => $candidaturaId,
            'score_total' => $score->total,
            'componentes' => $score->componentes,
        ]);
    }

    /** Contratante aprovou a candidatura; o score do momento é registrado. */
    public static function candidaturaAprovada(string $vagaId, string $profissionalId, string $candidaturaId, MatchScore $score): void
    {
        Log::info('match.candidatura_aprovada', [
            'event' => 'match.candidatura_aprovada',
            'vaga_id' => $vagaId,
            'profissional_id' => $profissionalId,
            'candidatura_id' => $candidaturaId,
            'score_total' => $score->total,
            'componentes' => $score->componentes,
        ]);
    }
}
