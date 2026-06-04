<?php

namespace App\Domain\Pagamento\Exceptions;

/**
 * STORY-056 / ADR-016. Transferência Pix ao profissional falhou (chave inválida,
 * indisponibilidade). PDR-010: UMA tentativa, SEM retry automático — gera alerta no admin
 * e trilha de auditoria. STORY-065 wira a policy de alerta a partir do evento PixFalhou.
 */
final class PixFalhou extends OperacaoPagamentoException {}
