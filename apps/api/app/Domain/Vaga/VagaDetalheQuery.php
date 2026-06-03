<?php

namespace App\Domain\Vaga;

use App\Domain\Match\MatchScoring;
use App\Enums\CandidaturaEstado;
use App\Enums\VagaEstado;
use App\Models\Candidatura;
use App\Models\User;
use App\Models\Vaga;
use App\Support\Geo\Haversine;

/**
 * STORY-049 (CA-1, CA-3, CA-7) — monta o detalhe de UMA vaga para o profissional, reusando
 * o mesmo cálculo de match do feed (MatchScoring/ADR-014) e a mesma distância (Haversine).
 *
 * Visibilidade (→ 404 quando null): a vaga precisa existir, estar `aberta` e ter início no
 * futuro. Diferente do feed, o detalhe NÃO filtra por função nem por raio — o breakdown
 * existe justamente para explicar um match baixo (função `miss`, distância `miss`), então
 * uma vaga acessada por deep-link ainda renderiza um breakdown honesto. O 404 cobre só os
 * casos em que a vaga "não está mais disponível" (preenchida/encerrada/cancelada/no passado
 * — SCREEN-049 §4.7).
 */
final class VagaDetalheQuery
{
    public function __construct(
        private readonly MatchScoring $scoring = new MatchScoring,
    ) {}

    public function paraProfissional(User $profissional, string $vagaId): ?VagaDetalhe
    {
        $vaga = Vaga::query()
            ->where('id', $vagaId)
            ->where('estado', VagaEstado::Aberta)
            ->where('data_inicio', '>', now())
            ->with(['funcao:id,nome', 'contratante.contratanteProfile'])
            ->first();

        if ($vaga === null) {
            return null;
        }

        $perfil = $profissional->profissionalProfile;
        if ($perfil === null) {
            return null;
        }

        $distancia = Haversine::km(
            $perfil->lat !== null ? (float) $perfil->lat : null,
            $perfil->lng !== null ? (float) $perfil->lng : null,
            $vaga->lat !== null ? (float) $vaga->lat : null,
            $vaga->lng !== null ? (float) $vaga->lng : null,
        );

        $score = $this->scoring->paraEntidades($perfil, $vaga, $distancia);

        return new VagaDetalhe(
            vaga: $vaga,
            distanciaKm: $distancia,
            score: $score,
            candidatura: $this->candidaturaVigente($profissional->id, $vaga->id),
        );
    }

    /**
     * Candidatura vigente do profissional nesta vaga: pendente, em revisão pós-edição, ou
     * aprovada (estados que significam "já candidatou"). Retiradas/recusadas não contam.
     */
    private function candidaturaVigente(string $profissionalId, string $vagaId): ?Candidatura
    {
        return Candidatura::query()
            ->where('profissional_id', $profissionalId)
            ->where('vaga_id', $vagaId)
            ->whereIn('estado', [
                CandidaturaEstado::Pendente,
                CandidaturaEstado::PendenteRevisaoAposEdicao,
                CandidaturaEstado::Aprovada,
            ])
            ->latest('id')
            ->first();
    }
}
