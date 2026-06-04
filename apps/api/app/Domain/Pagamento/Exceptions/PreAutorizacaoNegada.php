<?php

namespace App\Domain\Pagamento\Exceptions;

/**
 * STORY-056 / ADR-016. Pré-autorização recusada pelo provedor (cartão sem limite, dados
 * inválidos, antifraude). Falha FATAL de negócio — sem retry. STORY-058 traduz para UX que
 * impede a confirmação efetiva do turno (domain/pagamento.md §ciclo).
 */
final class PreAutorizacaoNegada extends OperacaoPagamentoException {}
