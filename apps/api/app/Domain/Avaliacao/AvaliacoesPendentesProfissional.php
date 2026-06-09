<?php

namespace App\Domain\Avaliacao;

use App\Enums\AvaliacaoDirecao;
use App\Enums\TurnoStatus;
use App\Models\Turno;
use App\Models\User;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * STORY-048 CA-8 / STORY-086 / ADR-019 (D2/D5) / PDR-005 — fonte do gate de candidatura do
 * profissional. Pendência **derivada do estado** (ADR-019 D2): um turno está pendente para o
 * profissional sse está em estado avaliável (`finalizado`/`finalizado_ajustado`) e ainda não
 * existe avaliação na direção `profissional_para_contratante`. Não há tabela de pendências —
 * é uma query (idempotente por construção, impossível divergir do estado real do turno).
 *
 * O gate bloqueia AÇÃO, não VISIBILIDADE (PDR-005): o feed continua visível; só candidatar-se
 * é barrado. `turnoPendente()` devolve o turno **mais antigo** por avaliar (deep-link da tela de
 * avaliação — STORY-087/088). `podeCandidatar()` é o julgamento booleano que o feed/detalhe já
 * consome (STORY-048) — fail-secure: erro de consulta ⇒ trata como bloqueado.
 */
class AvaliacoesPendentesProfissional
{
    /**
     * Turno avaliável mais antigo do profissional sem avaliação na direção dele, ou null se em
     * dia. Pode lançar (erro de banco): o chamador decide a postura fail-secure — o gate de
     * candidatura bloqueia (GateAvaliacao); o feed/detalhe usam `podeCandidatar()`, que abafa.
     */
    public function turnoPendente(User $profissional): ?Turno
    {
        return Turno::query()
            ->where('profissional_id', $profissional->id)
            ->whereIn('status', [TurnoStatus::Finalizado, TurnoStatus::FinalizadoAjustado])
            ->whereDoesntHave('avaliacoes', fn ($q) => $q->where('direcao', AvaliacaoDirecao::ProfissionalParaContratante))
            ->orderBy('data_fim')
            ->first();
    }

    /**
     * O profissional pode se candidatar se não tem turno por avaliar. Fail-secure (F2): se a
     * consulta falhar, retorna false — na dúvida, bloqueia (a UI mostra "avalie seu turno").
     */
    public function podeCandidatar(User $profissional): bool
    {
        try {
            return $this->turnoPendente($profissional) === null;
        } catch (Throwable $e) {
            Log::warning('gate_avaliacao.consulta_falhou', [
                'papel' => 'profissional',
                'user_id' => $profissional->id,
                'erro' => $e->getMessage(),
            ]);

            return false;
        }
    }
}
