<?php

namespace App\Enums;

/**
 * STORY-056 / ADR-016 (CA-5). Estado de uma linha em `pagamento_operacoes`.
 *
 * `pendente` — gravada antes de chamar o provedor (a chamada pode estar em curso).
 * `concluida` — provedor confirmou; é o ÚNICO estado que curto-circuita a idempotência
 *               (repetir a operação devolve o resultado guardado, sem nova chamada).
 * `falhou` — o provedor recusou/erro; o erro fica em `erro`. Retry (se recuperável) é
 *            decisão do worker (ADR-005 d), não desta camada.
 */
enum StatusOperacaoPagamento: string
{
    case Pendente = 'pendente';
    case Concluida = 'concluida';
    case Falhou = 'falhou';
}
