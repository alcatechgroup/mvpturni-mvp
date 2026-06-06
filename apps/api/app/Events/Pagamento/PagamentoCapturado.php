<?php

namespace App\Events\Pagamento;

use Carbon\CarbonImmutable;
use Illuminate\Foundation\Events\Dispatchable;

/**
 * STORY-065 (CA-2) — captura do valor pré-autorizado SUCEDEU na resposta síncrona do
 * gateway (iniciativa do CapturarEPagarTurnoJob). Consumido por STORY-067 (notificação).
 *
 * Não confundir com CapturaConfirmada (STORY-056): aquele nasce do WEBHOOK e é a fonte
 * de verdade assíncrona do estado do pagamento (CA-6); este registra o desfecho da
 * chamada que o Turni iniciou, com os dados que a estória fixa (charge_id, valor
 * capturado, timestamp).
 */
class PagamentoCapturado
{
    use Dispatchable;

    public function __construct(
        public readonly string $turnoId,
        public readonly string $pagarmeChargeId,
        public readonly string $valorCapturado,
        public readonly CarbonImmutable $capturadoEm,
    ) {}
}
