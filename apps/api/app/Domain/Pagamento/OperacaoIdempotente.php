<?php

namespace App\Domain\Pagamento;

use App\Domain\Pagamento\Exceptions\OperacaoPagamentoException;
use App\Enums\StatusOperacaoPagamento;
use App\Enums\TipoOperacaoPagamento;
use App\Models\PagamentoOperacao;
use App\Support\Telemetry\PagamentoEvents;
use Closure;

/**
 * STORY-056 / ADR-016 (CA-5, b) — NÚCLEO da idempotência financeira. Envolve uma operação do
 * GatewayPagamento garantindo "uma chave = uma operação no provedor".
 *
 * Regra (ADR-016 b): se já existe uma operação `concluida` para `(turno_id, tipo_operacao)`,
 * devolve o resultado guardado SEM chamar o provedor — é o curto-circuito que protege do
 * clique-duplo no aceite e do retry do worker (PDR-004). Caso contrário grava `pendente`,
 * chama o provedor (que recebe a mesma chave como Idempotency-Key — defesa dupla) e grava
 * `concluida`+resposta ou `falhou`+erro.
 *
 * É o ÚNICO ponto de observabilidade financeira (ADR-016 g): emite a linha JSON com latência.
 * Não conhece HTTP — recebe o `request` já MASCARADO pelo chamador (a chave Pix nunca entra
 * aqui) e uma closure que devolve o ResultadoOperacao. Isso o mantém testável sem rede.
 */
class OperacaoIdempotente
{
    /**
     * @param  array  $request  descritor da operação a logar (SEM PII — chave Pix jamais)
     * @param  Closure():ResultadoOperacao  $operacao  chamada ao gateway
     *
     * @throws OperacaoPagamentoException repassada da operação (registrada como `falhou`)
     */
    public function executar(string $turnoId, TipoOperacaoPagamento $tipo, array $request, Closure $operacao): ResultadoOperacao
    {
        $chave = $tipo->chaveIdempotente($turnoId);

        // firstOrCreate é atômico sobre o índice único (turno_id, tipo_operacao): se duas
        // requisições corrierem, só uma cria a linha; a outra recebe a existente.
        $operacaoRegistro = PagamentoOperacao::firstOrCreate(
            ['turno_id' => $turnoId, 'tipo_operacao' => $tipo],
            ['idempotencia_chave' => $chave, 'status' => StatusOperacaoPagamento::Pendente, 'request_payload' => $request],
        );

        // Curto-circuito: operação já concluída → devolve o guardado, zero chamada ao provedor.
        if ($operacaoRegistro->concluida()) {
            PagamentoEvents::operacaoReaproveitada($tipo, $turnoId, $chave, $operacaoRegistro->pagarmeId());

            return $operacaoRegistro->resultadoGuardado();
        }

        $inicio = microtime(true);

        try {
            $resultado = $operacao();
        } catch (OperacaoPagamentoException $e) {
            $operacaoRegistro->update([
                'status' => StatusOperacaoPagamento::Falhou,
                'erro' => $e->getMessage(),
            ]);
            PagamentoEvents::operacaoFalhou($tipo, $turnoId, $chave, $e, self::latenciaMs($inicio));

            throw $e;
        }

        $operacaoRegistro->update([
            'status' => StatusOperacaoPagamento::Concluida,
            'response_payload' => $resultado->raw,
            'pagarme_order_id' => $resultado->pagarmeOrderId,
            'pagarme_charge_id' => $resultado->pagarmeChargeId,
            'pagarme_transfer_id' => $resultado->pagarmeTransferId,
        ]);
        PagamentoEvents::operacaoConcluida($tipo, $turnoId, $chave, $resultado, self::latenciaMs($inicio));

        return $resultado;
    }

    private static function latenciaMs(float $inicio): int
    {
        return (int) round((microtime(true) - $inicio) * 1000);
    }
}
