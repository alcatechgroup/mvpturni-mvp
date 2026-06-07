<?php

namespace App\Events;

use Illuminate\Foundation\Events\Dispatchable;

/**
 * STORY-067 (CA-1) — PIN de check-out gerado pelo profissional (STORY-064). Espelho do
 * CheckinSolicitado (mesma semântica de `geracaoPinId`/idempotência); disparado PÓS-COMMIT
 * pelo PinCheckoutService a cada geração. Consumidor: NotificarCheckoutSolicitado
 * (`checkout_solicitado` ao contratante).
 */
class CheckoutSolicitado
{
    use Dispatchable;

    public function __construct(
        public readonly string $turnoId,
        public readonly string $geracaoPinId,
    ) {}
}
