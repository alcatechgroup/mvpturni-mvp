<?php

namespace App\Domain\Candidatura\Gates;

use App\Domain\Candidatura\GateResultado;
use App\Enums\CandidaturaEstado;
use App\Models\Candidatura;
use App\Models\ContratanteProfile;
use App\Models\User;
use App\Models\Vaga;

/**
 * STORY-050 Gate 2 (CA-3) — conflito de horário (domain/candidatura.md). O profissional não
 * pode se candidatar a uma vaga que se sobrepõe no tempo a:
 *  - outra candidatura sua ainda viva (`pendente` ou `pendente_revisao_apos_edicao`);
 *  - um turno `confirmado` seu (EPIC-003 — turnos ainda não existem no schema; o slot do
 *    contrato `conflito_com.tipo='turno'` está reservado, mas só candidaturas são checadas hoje).
 *
 * Sobreposição de intervalos [início, fim): existe.inicio < alvo.fim E existe.fim > alvo.inicio.
 * A própria vaga é excluída (a idempotência de "já candidatou" é tratada antes, no serviço).
 */
final class GateConflitoHorario
{
    public function verificar(User $profissional, Vaga $vaga): GateResultado
    {
        $conflito = Candidatura::query()
            ->where('profissional_id', $profissional->id)
            ->where('vaga_id', '!=', $vaga->id)
            ->whereIn('estado', [
                CandidaturaEstado::Pendente,
                CandidaturaEstado::PendenteRevisaoAposEdicao,
            ])
            ->whereHas('vaga', function ($q) use ($vaga) {
                $q->where('data_inicio', '<', $vaga->data_fim)
                    ->where('data_fim', '>', $vaga->data_inicio);
            })
            ->with(['vaga.funcao:id,nome', 'vaga.contratante.contratanteProfile'])
            ->first();

        if ($conflito === null) {
            return GateResultado::passou();
        }

        $vagaConflito = $conflito->vaga;

        return GateResultado::bloqueio(
            'conflito_horario',
            'Você já tem um compromisso neste horário.',
            [
                'conflito_com' => [
                    'tipo' => 'candidatura',
                    'id' => $conflito->id,
                    'vaga_id' => $vagaConflito->id,
                    'funcao' => $vagaConflito->funcao?->nome,
                    'estabelecimento' => $this->estabelecimento($vagaConflito),
                    'data_inicio' => $vagaConflito->data_inicio->toIso8601String(),
                    'data_fim' => $vagaConflito->data_fim->toIso8601String(),
                ],
            ],
        );
    }

    /** Nome curto do estabelecimento p/ o card de conflito (SCREEN-050 §4.5); null se ausente. */
    private function estabelecimento(Vaga $vaga): ?string
    {
        /** @var ContratanteProfile|null $perfil */
        $perfil = $vaga->contratante?->contratanteProfile;

        return $perfil?->apelido_estabelecimento ?: $perfil?->nome_estabelecimento;
    }
}
