<?php

namespace App\Domain\Pagamento\Exceptions;

/**
 * STORY-056 / ADR-016. Liberação da pré-autorização falhou (cancelamento/no-show/disputa
 * sem pagamento — domain/pagamento.md §variações). STORY-066 consome.
 */
final class LiberacaoFalhou extends OperacaoPagamentoException {}
