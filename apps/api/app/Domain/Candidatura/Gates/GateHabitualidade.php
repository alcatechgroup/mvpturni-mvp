<?php

namespace App\Domain\Candidatura\Gates;

use App\Domain\Candidatura\GateResultado;
use App\Enums\CandidaturaEstado;
use App\Models\Candidatura;
use App\Models\User;
use App\Models\Vaga;
use Carbon\CarbonInterface;

/**
 * STORY-050 Gate 3 (CA-4) — habitualidade (PDR-002 + business-rules.md). Conta as alocações do
 * profissional na **semana corrida (segunda→domingo)** da vaga-alvo, no **mesmo estabelecimento**
 * (no MVP, estabelecimento = `contratante_id` da vaga — não há entidade Estabelecimento separada).
 *
 * Limite: 2 alocações/semana/estabelecimento. Na **3ª**:
 *  - **PF**  → bloqueio duro (`habitualidade_bloqueio`).
 *  - **MEI/PJ** → NÃO bloqueia; emite alerta (`detalhe.alerta=true`) p/ o painel do contratante
 *    (STORY-051). O "override do contratante" é EPIC-003 (no aceite), fora desta estória.
 *
 * Alocação = candidatura viva (`pendente`/`pendente_revisao_apos_edicao`) ou já `aprovada` —
 * todas representam um compromisso semanal naquele local. A vaga-alvo é excluída da contagem.
 */
final class GateHabitualidade
{
    private const LIMITE_SEMANAL = 2;

    public function verificar(User $profissional, Vaga $vaga): GateResultado
    {
        $inicioSemana = $vaga->data_inicio->copy()->startOfWeek(CarbonInterface::MONDAY);
        $fimSemana = $vaga->data_inicio->copy()->endOfWeek(CarbonInterface::SUNDAY);

        $alocacoes = Candidatura::query()
            ->where('profissional_id', $profissional->id)
            ->where('vaga_id', '!=', $vaga->id)
            ->whereIn('estado', [
                CandidaturaEstado::Pendente,
                CandidaturaEstado::PendenteRevisaoAposEdicao,
                CandidaturaEstado::Aprovada,
            ])
            ->whereHas('vaga', function ($q) use ($vaga, $inicioSemana, $fimSemana) {
                $q->where('contratante_id', $vaga->contratante_id)
                    ->whereBetween('data_inicio', [$inicioSemana, $fimSemana]);
            })
            ->count();

        if ($alocacoes < self::LIMITE_SEMANAL) {
            return GateResultado::passou();
        }

        // Atingiu o limite: a candidatura atual seria a 3ª (ou além) na semana neste local.
        if ($this->ehPessoaFisica($profissional)) {
            return GateResultado::bloqueio(
                'habitualidade_bloqueio',
                'Você já tem 2 turnos nesta semana neste estabelecimento.',
                ['alocacoes_na_semana' => $alocacoes],
            );
        }

        // MEI/PJ: passa com alerta (não bloqueia — CA-4).
        return GateResultado::alerta('habitualidade');
    }

    private function ehPessoaFisica(User $profissional): bool
    {
        $tipo = $profissional->profissionalProfile?->tipo_pessoa;

        // Default conservador: ausência de tipo é tratada como PF (regra mais restritiva).
        return $tipo === null || strtoupper((string) $tipo) === 'PF';
    }
}
