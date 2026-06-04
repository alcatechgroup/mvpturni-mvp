<?php

namespace App\Domain\Pagamento;

use App\Domain\Pagamento\Exceptions\CapturaFalhou;
use App\Domain\Pagamento\Exceptions\GatewayIndisponivel;
use App\Domain\Pagamento\Exceptions\LiberacaoFalhou;
use App\Domain\Pagamento\Exceptions\PixFalhou;
use App\Domain\Pagamento\Exceptions\PreAutorizacaoNegada;

/**
 * STORY-056 / ADR-016 (CA-2). Anti-Corruption Layer da integração financeira (ADR-005).
 *
 * O domínio Turni fala com ESTA interface em vocabulário próprio; o adapter Pagar.me
 * (App\Domain\Pagamento\Pagarme\PagarmeGateway) é o ÚNICO lugar que conhece o provedor.
 * Trocar de PSP = reescrever o adapter, sem tocar o domínio (princípio #5/#7, F1).
 *
 * Valores monetários trafegam como STRING DECIMAL ("123.45") — coerente com o cast
 * `decimal:2` do Turno (ADR-015) e à prova de erro de ponto flutuante; o adapter converte
 * para centavos inteiros na fronteira com o provedor.
 *
 * Erros: falha fatal de negócio vira exceção de domínio tipada (PreAutorizacaoNegada,
 * CapturaFalhou, PixFalhou, LiberacaoFalhou); falha transiente vira GatewayIndisponivel
 * (recuperável — o worker pode retentar). Nenhum HTTP do Pagar.me sobe daqui (Decisão 3A).
 *
 * A IDEMPOTÊNCIA não é responsabilidade de quem chama: o runner OperacaoIdempotente
 * envolve estas operações, garantindo "uma chave = uma operação no provedor" (ADR-016 b).
 */
interface GatewayPagamento
{
    /**
     * Pré-autoriza `total_contratante` no meio de pagamento do contratante, na aprovação da
     * candidatura (turno `confirmado`). `meioPagamentoToken` é tokenizado pela STORY-058.
     *
     * @throws PreAutorizacaoNegada falha fatal (recusa, antifraude, dados inválidos)
     * @throws GatewayIndisponivel falha transiente (timeout, 5xx, rede)
     */
    public function preAutorizar(string $turnoId, string $totalContratante, string $meioPagamentoToken): ResultadoOperacao;

    /**
     * Captura o valor integral pré-autorizado no check-out validado (turno `finalizado`).
     *
     * @throws CapturaFalhou
     * @throws GatewayIndisponivel
     */
    public function capturar(string $turnoId): ResultadoOperacao;

    /**
     * Captura ajustada para `valorRevisado` (disputa `paga_parcial` — EPIC-005/PDR-006).
     * Exposta desde já; não exercitada antes do EPIC-005.
     *
     * @throws CapturaFalhou
     * @throws GatewayIndisponivel
     */
    public function capturarParcial(string $turnoId, string $valorRevisado): ResultadoOperacao;

    /**
     * Libera a pré-autorização sem capturar (cancelamento, no-show, disputa sem pagamento).
     *
     * @throws LiberacaoFalhou
     * @throws GatewayIndisponivel
     */
    public function liberar(string $turnoId): ResultadoOperacao;

    /**
     * Transfere o `valorProfissional` (integral) via Pix para a chave do profissional, após
     * a captura. PDR-010: uma tentativa. A `chavePix` é DADO SENSÍVEL — nunca logada em claro.
     *
     * @throws PixFalhou
     * @throws GatewayIndisponivel
     */
    public function transferirPix(string $turnoId, string $valorProfissional, string $chavePix): ResultadoOperacao;
}
