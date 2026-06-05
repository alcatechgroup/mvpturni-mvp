<?php

namespace App\Domain\Turno;

use App\Enums\TurnoStatus;
use App\Models\Turno;
use App\Models\User;
use App\Models\Vaga;
use Carbon\CarbonInterface;

/**
 * STORY-058 (CA-2/CA-3/CA-4) — habitualidade NO ACEITE (PDR-002), contada sobre TURNOS.
 *
 * Diferente do GateHabitualidade da candidatura (STORY-050, que conta candidaturas vivas como
 * compromissos), aqui a alocação é o turno real do par profissional × estabelecimento na semana
 * corrida (segunda→domingo) da vaga-alvo — a tabela-alvo do índice composto de ADR-006/ADR-015
 * (`idx_turnos_habitualidade`). Turnos cancelados e no-show NÃO contam: a alocação foi desfeita
 * (PDR-007) e não representa habitualidade.
 *
 * Limite: 2 turnos/semana/estabelecimento. Na 3ª: PF bloqueia duro; MEI/PJ exige o override
 * explícito do contratante (cláusula de risco no aceite eletrônico). Ausência de tipo_pessoa é
 * tratada como PF — default conservador (mesma regra do gate da candidatura).
 */
final class GateHabitualidadeAceite
{
    private const LIMITE_SEMANAL = 2;

    /** Estados que não representam alocação (desfeitas — PDR-007). */
    private const STATUS_DESFEITOS = [
        TurnoStatus::CanceladoPro,
        TurnoStatus::CanceladoEmp,
        TurnoStatus::NoShowPro,
    ];

    public function verificar(User $profissional, Vaga $vaga): HabitualidadeAceite
    {
        $inicioSemana = $vaga->data_inicio->copy()->startOfWeek(CarbonInterface::MONDAY);
        $fimSemana = $vaga->data_inicio->copy()->endOfWeek(CarbonInterface::SUNDAY);

        // Shape exato do idx_turnos_habitualidade (estabelecimento, profissional, data_inicio).
        $alocacoes = Turno::query()
            ->where('estabelecimento_id', $vaga->contratante_id) // MVP: estabelecimento = contratante
            ->where('profissional_id', $profissional->id)
            ->whereBetween('data_inicio', [$inicioSemana, $fimSemana])
            ->whereNotIn('status', self::STATUS_DESFEITOS)
            ->count();

        if ($alocacoes < self::LIMITE_SEMANAL) {
            return HabitualidadeAceite::Liberado;
        }

        return $this->ehPessoaFisica($profissional)
            ? HabitualidadeAceite::BloqueadoPf
            : HabitualidadeAceite::RequerOverride;
    }

    private function ehPessoaFisica(User $profissional): bool
    {
        $tipo = $profissional->profissionalProfile?->tipo_pessoa;

        // Default conservador: ausência de tipo é tratada como PF (regra mais restritiva).
        return $tipo === null || strtoupper((string) $tipo) === 'PF';
    }
}
