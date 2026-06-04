<?php

namespace App\Support\Telemetry;

use App\Domain\Pagamento\Exceptions\OperacaoPagamentoException;
use App\Domain\Pagamento\ResultadoOperacao;
use App\Enums\TipoOperacaoPagamento;
use Illuminate\Support\Facades\Log;

/**
 * STORY-056 / ADR-016 (CA-9) — observabilidade financeira em log JSON estruturado (ADR-008),
 * espelhando MatchEvents (ADR-014). Uma linha por operação da ACL Pagar.me, correlacionável
 * por `request_id` (propagado api→fila→worker pelo mecanismo do ADR-008).
 *
 * MASCARAMENTO (ADR-008 / ADR-016 g): a chave Pix e dados bancários NUNCA entram no log.
 * Estes métodos recebem só identificadores opacos do provedor (`pagarme_id`) e metadados —
 * nenhum parâmetro carrega a chave Pix, então não há o que vazar.
 *
 * Estes eventos alimentam as log-based metrics do ADR-008: taxa de erro de operações
 * financeiras (SLO ≤ 1%), latência p95 de captura e latência p95 do webhook.
 */
final class PagamentoEvents
{
    /** Operação concluída no provedor (primeira vez). */
    public static function operacaoConcluida(
        TipoOperacaoPagamento $tipo,
        string $turnoId,
        string $chave,
        ResultadoOperacao $resultado,
        int $latenciaMs,
    ): void {
        Log::info('pagamento.operacao_concluida', [
            'event' => 'pagamento.operacao_concluida',
            'operacao' => $tipo->value,
            'turno_id' => $turnoId,
            'idempotencia_chave' => $chave,
            'pagarme_id' => $resultado->pagarmeTransferId ?? $resultado->pagarmeChargeId ?? $resultado->pagarmeOrderId,
            'latencia_ms' => $latenciaMs,
            'resultado' => 'ok',
        ]);
    }

    /** Operação reaproveitada do registro (idempotência — não chamou o provedor). */
    public static function operacaoReaproveitada(
        TipoOperacaoPagamento $tipo,
        string $turnoId,
        string $chave,
        ?string $pagarmeId,
    ): void {
        Log::info('pagamento.operacao_reaproveitada', [
            'event' => 'pagamento.operacao_reaproveitada',
            'operacao' => $tipo->value,
            'turno_id' => $turnoId,
            'idempotencia_chave' => $chave,
            'pagarme_id' => $pagarmeId,
            'latencia_ms' => 0,
            'resultado' => 'idempotente',
        ]);
    }

    /** Operação falhou no provedor — fatal de negócio ou recuperável (ver `recuperavel`). */
    public static function operacaoFalhou(
        TipoOperacaoPagamento $tipo,
        string $turnoId,
        string $chave,
        OperacaoPagamentoException $e,
        int $latenciaMs,
    ): void {
        Log::warning('pagamento.operacao_falhou', [
            'event' => 'pagamento.operacao_falhou',
            'operacao' => $tipo->value,
            'turno_id' => $turnoId,
            'idempotencia_chave' => $chave,
            'recuperavel' => $e->recuperavel,
            'latencia_ms' => $latenciaMs,
            'resultado' => 'erro',
            'erro' => $e->getMessage(),
        ]);
    }

    /** Webhook entrante processado (correlaciona a confirmação assíncrona do provedor). */
    public static function webhookProcessado(string $eventoDominio, ?string $turnoId, string $pagarmeEventId, int $latenciaMs): void
    {
        Log::info('pagamento.webhook_processado', [
            'event' => 'pagamento.webhook_processado',
            'evento_dominio' => $eventoDominio,
            'turno_id' => $turnoId,
            'pagarme_event_id' => $pagarmeEventId,
            'latencia_ms' => $latenciaMs,
            'resultado' => 'ok',
        ]);
    }
}
