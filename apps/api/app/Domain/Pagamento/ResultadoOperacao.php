<?php

namespace App\Domain\Pagamento;

use App\Enums\StatusOperacaoPagamento;
use App\Enums\TipoOperacaoPagamento;

/**
 * STORY-056 / ADR-016 (CA-2). Retorno imutável de toda operação da ACL Pagar.me.
 *
 * Fala vocabulário Turni: o domínio vê `tipo`/`status` e identificadores OPACOS de
 * correlação (não PII) — nunca o shape cru do Pagar.me. O `raw` carrega a resposta
 * para a trilha de auditoria/persistência em `pagamento_operacoes` (ADR-016 b), mas o
 * domínio acima da ACL não deve depender da forma dele (princípio #5 / F1).
 */
final readonly class ResultadoOperacao
{
    public function __construct(
        public TipoOperacaoPagamento $tipo,
        public StatusOperacaoPagamento $status,
        public ?string $pagarmeOrderId = null,
        public ?string $pagarmeChargeId = null,
        public ?string $pagarmeTransferId = null,
        public array $raw = [],
    ) {}

    /** Reconstrói o resultado a partir de uma operação já concluída e guardada (idempotência). */
    public static function deOperacaoGuardada(
        TipoOperacaoPagamento $tipo,
        StatusOperacaoPagamento $status,
        ?string $orderId,
        ?string $chargeId,
        ?string $transferId,
        array $raw,
    ): self {
        return new self($tipo, $status, $orderId, $chargeId, $transferId, $raw);
    }
}
