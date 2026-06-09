<?php

namespace App\Domain\Avaliacao;

use App\Enums\AvaliacaoDirecao;
use App\Enums\TurnoStatus;
use App\Models\Turno;
use App\Models\User;

/**
 * STORY-046 CA-5 / STORY-086 / ADR-019 (D2/D5) / PDR-005 — fonte do gate de publicação do
 * contratante. Pendência **derivada do estado** (ADR-019 D2): conta os turnos avaliáveis do
 * contratante (`finalizado`/`finalizado_ajustado`) sem avaliação na direção
 * `contratante_para_profissional`. Não há tabela de pendências — é uma query.
 *
 * Contrato `{ pending: int, turnos: [...] }`: o endpoint de leitura (AvaliacoesPendentesController)
 * o devolve ao WebApp antes de montar o formulário; o gate de `PublicarVagaService` o consome
 * para barrar a publicação (turnos ordenados do mais antigo — o 1º guia o deep-link da avaliação).
 */
class AvaliacoesPendentesContratante
{
    /** @return array{pending:int, turnos:list<array{turno_id:string, data_fim:?string}>} */
    public function para(User $contratante): array
    {
        $turnos = Turno::query()
            ->where('contratante_id', $contratante->id)
            ->whereIn('status', [TurnoStatus::Finalizado, TurnoStatus::FinalizadoAjustado])
            ->whereDoesntHave('avaliacoes', fn ($q) => $q->where('direcao', AvaliacaoDirecao::ContratanteParaProfissional))
            ->orderBy('data_fim')
            ->get(['id', 'data_fim']);

        return [
            'pending' => $turnos->count(),
            'turnos' => $turnos->map(fn (Turno $t) => [
                'turno_id' => $t->id,
                'data_fim' => $t->data_fim?->toIso8601String(),
            ])->all(),
        ];
    }
}
