<?php

namespace App\Domain\Avaliacao;

use App\Enums\NivelProfissional;
use App\Enums\TurnoStatus;
use App\Models\Avaliacao;
use App\Models\Turno;
use App\Models\User;

/**
 * STORY-085 / ADR-019 Decisão 4. Motor de reputação por RECOMPUTAÇÃO IDEMPOTENTE: a cada
 * avaliação registrada, recomputa score/XP/nível do AVALIADO a partir dos fatos canônicos
 * (avaliações recebidas + turnos finalizados) e persiste no profile (denormalização que o
 * Match lê — ADR-014).
 *
 * Idempotência por construção (F1): score/xp/turnos são funções puras do conjunto ATUAL de
 * fatos, não somas incrementais — reprocessar o mesmo evento produz o mesmo profile, sem
 * ledger nem chave de idempotência. O nível é high-water-mark: `max(nível_atual, nivelPara(xp))`
 * — sobe automático nos limiares, nunca rebaixa (F6), mesmo que o XP recomputado caia.
 *
 * Reciprocidade: o profissional ganha score + XP + nível; o contratante ganha só score
 * (sem nível/XP no MVP — niveis-e-score.md).
 *
 * Sem dependência de relógio — testável a 98%+. O viés de recência do score
 * (niveis-e-score.md) é hook fora do MVP (ADR-019): o ponto de extensão é `scoreDe()`.
 */
class MotorReputacao
{
    /** Estados terminais que contam como turno realizado (ADR-015). */
    private const ESTADOS_REALIZADOS = [
        TurnoStatus::Finalizado->value,
        TurnoStatus::FinalizadoAjustado->value,
    ];

    public function recalcular(User $avaliado): void
    {
        $score = $this->scoreDe($avaliado);

        if ($avaliado->isProfissional()) {
            $this->recalcularProfissional($avaliado, $score);

            return;
        }

        if ($avaliado->isContratante()) {
            $avaliado->contratanteProfile()->update(['score' => $score]);
        }
    }

    /**
     * Score = média aritmética das estrelas recebidas (todas as direções/turnos), 2 casas.
     * Sem avaliações recebidas → 0. Ponto de extensão do viés de recência (fora do MVP).
     */
    public function scoreDe(User $avaliado): float
    {
        $media = Avaliacao::query()->where('avaliado_id', $avaliado->id)->avg('estrelas');

        return $media === null ? 0.0 : round((float) $media, 2);
    }

    private function recalcularProfissional(User $pro, float $score): void
    {
        $turnos = $this->turnosRealizados($pro);
        $xp = $this->xpDe($pro, $turnos);
        $profile = $pro->profissionalProfile;

        // High-water-mark: o nível nunca rebaixa. Nível inválido/ausente parte de Iniciante.
        $nivelAtual = NivelProfissional::tryFrom((string) $profile->nivel) ?? NivelProfissional::Iniciante;
        $nivel = $nivelAtual->maiorEntre(NivelProfissional::nivelPara($xp));

        $profile->update([
            'score' => $score,
            'xp' => $xp,
            'turnos_realizados' => $turnos,
            'nivel' => $nivel->value,
        ]);
    }

    private function turnosRealizados(User $pro): int
    {
        return Turno::query()
            ->where('profissional_id', $pro->id)
            ->whereIn('status', self::ESTADOS_REALIZADOS)
            ->count();
    }

    /** XP = 30 × turnos finalizados + Σ bônus por estrela das avaliações recebidas. */
    private function xpDe(User $pro, int $turnos): int
    {
        $bonus = Avaliacao::query()
            ->where('avaliado_id', $pro->id)
            ->pluck('estrelas')
            ->sum(fn (int $estrelas) => $this->bonusXp($estrelas));

        return 30 * $turnos + $bonus;
    }

    /** Bônus de XP por estrela (niveis-e-score.md): 5★ +10, 4★ +3, 3★ 0, 1–2★ −5. */
    private function bonusXp(int $estrelas): int
    {
        return match ($estrelas) {
            5 => 10,
            4 => 3,
            3 => 0,
            default => -5, // 1 ou 2 estrelas (penalidade)
        };
    }
}
