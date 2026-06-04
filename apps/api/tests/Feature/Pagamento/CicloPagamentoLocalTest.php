<?php

// STORY-056 / ADR-016 (CA-7, CA-9) — E2E LOCAL do ciclo financeiro pré-auth → captura → Pix
// → webhook, SEM internet (Http::fake simula o mock; Http::preventStrayRequests garante 0 rede).
// Também verifica a observabilidade (CA-9): a chave Pix NUNCA aparece no log.

use App\Domain\Pagamento\GatewayPagamento;
use App\Domain\Pagamento\OperacaoIdempotente;
use App\Domain\Pagamento\Webhook\PagarmeWebhookValidator;
use App\Enums\StatusOperacaoPagamento;
use App\Enums\TipoOperacaoPagamento;
use App\Events\Pagamento\CapturaConfirmada;
use App\Events\Pagamento\PixEnviado;
use App\Events\Pagamento\PreAutorizacaoCriada;
use App\Jobs\ProcessarWebhookPagarmeJob;
use App\Models\PagamentoOperacao;
use App\Models\Turno;
use App\Models\WebhookEventoPagarme;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

uses(RefreshDatabase::class);

beforeEach(function () {
    config()->set('services.pagarme.base_url', 'http://pagarme-mock:8080');
    config()->set('services.pagarme.webhook_secret', 'whsec_test');
    Http::preventStrayRequests(); // qualquer chamada não-fakeada = falha (prova "sem internet")
});

/** Simula o webhook que o mock devolveria, processando-o de ponta a ponta. */
function entregarWebhook(string $type, string $turnoId): void
{
    $payload = ['id' => 'evt_'.uniqid(), 'type' => $type, 'data' => ['external_reference' => $turnoId]];
    $raw = json_encode($payload);
    $resp = test()->call(
        'POST', '/api/webhooks/pagarme', [], [], [],
        ['CONTENT_TYPE' => 'application/json', 'HTTP_X_PAGARME_SIGNATURE' => hash_hmac('sha256', $raw, 'whsec_test')],
        $raw,
    );
    $resp->assertOk();
    // Processa o job inline (o worker faria isso async).
    (new ProcessarWebhookPagarmeJob($payload['id']))->handle(app(PagarmeWebhookValidator::class));
}

test('ciclo completo pré-auth → captura → Pix → webhook roda local sem internet', function () {
    // Captura toda linha de log para provar que a chave Pix nunca aparece (CA-9).
    $logs = [];
    Log::listen(function ($evento) use (&$logs) {
        $logs[] = $evento->message.' '.json_encode($evento->context);
    });
    Event::fake([PreAutorizacaoCriada::class, CapturaConfirmada::class, PixEnviado::class]);

    $turno = Turno::factory()->create(['valor' => '100.00', 'taxa_turni' => '15.00', 'total_contratante' => '115.00']);
    $gateway = app(GatewayPagamento::class);
    $idem = app(OperacaoIdempotente::class);
    $chavePix = 'profissional-secreto@pix.com';

    // 1) Pré-autorização (aprovação da candidatura)
    Http::fake(['*/orders' => Http::response(['id' => 'or_1', 'charges' => [['id' => 'ch_1', 'status' => 'authorized']]])]);
    $idem->executar($turno->id, TipoOperacaoPagamento::PreAutorizacao, ['total_contratante' => '115.00'],
        fn () => $gateway->preAutorizar($turno->id, '115.00', 'tok_x'));
    entregarWebhook('charge.pending', $turno->id);

    // 2) Captura (check-out validado)
    Http::fake(['*/charges/ch_1/capture' => Http::response(['id' => 'ch_1', 'status' => 'paid'])]);
    $idem->executar($turno->id, TipoOperacaoPagamento::Captura, [],
        fn () => $gateway->capturar($turno->id));
    entregarWebhook('charge.paid', $turno->id);

    // 3) Pix ao profissional (valor integral)
    Http::fake(['*/transfers' => Http::response(['id' => 'tr_1', 'status' => 'paid'])]);
    $idem->executar($turno->id, TipoOperacaoPagamento::Pix, ['valor' => '100.00'],
        fn () => $gateway->transferirPix($turno->id, '100.00', $chavePix));
    entregarWebhook('transfer.paid', $turno->id);

    // Estado final: 3 operações concluídas + 3 webhooks processados + eventos de domínio emitidos.
    expect(PagamentoOperacao::where('turno_id', $turno->id)->where('status', StatusOperacaoPagamento::Concluida)->count())->toBe(3)
        ->and(WebhookEventoPagarme::whereNotNull('processado_em')->count())->toBe(3);

    Event::assertDispatched(PreAutorizacaoCriada::class);
    Event::assertDispatched(CapturaConfirmada::class);
    Event::assertDispatched(PixEnviado::class);

    // CA-9: a chave Pix JAMAIS entra em log estruturado nem nos payloads persistidos.
    expect($logs)->not->toBeEmpty();
    foreach ($logs as $linha) {
        expect($linha)->not->toContain($chavePix);
    }
    $opPix = PagamentoOperacao::where('turno_id', $turno->id)->where('tipo_operacao', TipoOperacaoPagamento::Pix)->first();
    expect(json_encode($opPix->request_payload))->not->toContain($chavePix)
        ->and(json_encode($opPix->response_payload))->not->toContain($chavePix);
});
