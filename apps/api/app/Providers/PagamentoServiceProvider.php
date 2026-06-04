<?php

namespace App\Providers;

use App\Domain\Pagamento\GatewayPagamento;
use App\Domain\Pagamento\Pagarme\PagarmeGateway;
use App\Domain\Pagamento\Webhook\PagarmeWebhookValidator;
use Illuminate\Support\ServiceProvider;

/**
 * STORY-056 / ADR-016 (CA-2, CA-3, Decisão 2A). Bindings da ACL Pagar.me.
 *
 * - GatewayPagamento → PagarmeGateway: há UM adapter; o driver (mock|sandbox|live) só troca
 *   base_url + credencial em config (services.pagarme), sem ramificação de código.
 * - PagarmeWebhookValidator recebe o segredo HMAC do webhook (services.pagarme.webhook_secret).
 */
class PagamentoServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->bind(GatewayPagamento::class, PagarmeGateway::class);

        $this->app->bind(
            PagarmeWebhookValidator::class,
            fn () => new PagarmeWebhookValidator((string) config('services.pagarme.webhook_secret')),
        );
    }
}
