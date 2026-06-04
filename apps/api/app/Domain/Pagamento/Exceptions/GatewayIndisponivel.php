<?php

namespace App\Domain\Pagamento\Exceptions;

/**
 * STORY-056 / ADR-016 (Decisão 3A). Falha RECUPERÁVEL genérica do gateway: timeout, 5xx,
 * erro de rede. Sinaliza ao worker que pode retentar com backoff (ADR-005 d). Distinta das
 * exceções fatais de negócio (PreAutorizacaoNegada etc.), que não devem ser retentadas.
 */
final class GatewayIndisponivel extends OperacaoPagamentoException
{
    public function __construct(string $message, array $contexto = [])
    {
        parent::__construct($message, recuperavel: true, contexto: $contexto);
    }
}
