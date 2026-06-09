<?php

namespace App\Listeners;

use App\Enums\NotificacaoTipo;
use App\Events\TurnoFinalizado;
use App\Services\Notificacao\NotificarEventoTurnoService;

/**
 * STORY-085 / ADR-019 Decisão 3 (CA-2) — `TurnoFinalizado` → `avaliacao_pendente` ("avalie seu
 * turno") para AMBOS os lados (uma notificação por destinatário; chave sufixada pelo
 * destinatário porque a UNIQUE de `notificacoes` é por linha). Convive com os outros listeners
 * do mesmo evento (financeiro da 065 + `turno_finalizado`/pagamento da 067) — responsabilidade
 * separada, listener separado.
 *
 * NÃO cria pendência (ADR-019 Decisão 2: pendência é DERIVADA do estado, não materializada) —
 * só notifica. O gate (STORY-086) lê a pendência derivada na hora da ação.
 *
 * Idempotente: reprocessar o evento não duplica (chave `avaliacao_pendente:{turno}:{destinatario}`
 * deduplicada no CriarNotificacaoService).
 */
class NotificarAvaliacaoPendente
{
    public function __construct(private readonly NotificarEventoTurnoService $svc) {}

    public function handle(TurnoFinalizado $event): void
    {
        if (! $turno = $this->svc->turno($event->turnoId)) {
            return;
        }

        foreach ([$turno->profissional_id, $turno->contratante_id] as $destinatarioId) {
            $this->svc->notificar(
                $turno,
                NotificacaoTipo::AvaliacaoPendente,
                $destinatarioId,
                sufixoChave: $destinatarioId,
            );
        }
    }
}
