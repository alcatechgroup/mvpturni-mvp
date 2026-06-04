<?php

namespace App\Domain\Pagamento\Exceptions;

/**
 * STORY-056 / ADR-016. Captura do valor pré-autorizado falhou. Pode ser recuperável
 * (transiente, antes do Pix — o worker retenta, ADR-005 f) ou fatal; o adapter decide
 * pelo status HTTP. STORY-065 consome.
 */
final class CapturaFalhou extends OperacaoPagamentoException {}
