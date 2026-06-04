<?php

namespace App\Domain\Pagamento\Exceptions;

use RuntimeException;

/**
 * STORY-056 / ADR-016 (CA-2, Decisão 3A). Base das exceções de domínio da ACL Pagar.me.
 *
 * Nenhum `HTTP 4xx/5xx` do Pagar.me sobe da ACL: o adapter mapeia toda falha para uma
 * subclasse desta (F1 — o domínio só conhece erros DELE). `$recuperavel` distingue a falha
 * transiente (timeout, 5xx, rede — o worker pode retentar com backoff) da fatal de negócio
 * (recusa, dados inválidos — sem retry). O `$contexto` carrega dados não-sensíveis para log.
 */
abstract class OperacaoPagamentoException extends RuntimeException
{
    public function __construct(
        string $message,
        public readonly bool $recuperavel = false,
        public readonly array $contexto = [],
    ) {
        parent::__construct($message);
    }
}
