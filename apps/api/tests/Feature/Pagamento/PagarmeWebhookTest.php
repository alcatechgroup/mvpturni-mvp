<?php

// STORY-056 / ADR-016 (CA-6) — endpoint público do webhook entrante. HMAC (401 se inválido),
// dedup por event_id (200 sem reprocessar), recepção rápida + enfileiramento async.

use App\Jobs\ProcessarWebhookPagarmeJob;
use App\Models\WebhookEventoPagarme;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Queue;

uses(RefreshDatabase::class);

beforeEach(function () {
    config()->set('services.pagarme.webhook_secret', 'whsec_test');
    Queue::fake();
});

function postWebhook(array $payload, ?string $segredo = 'whsec_test')
{
    $raw = json_encode($payload);
    $headers = $segredo !== null
        ? ['X-Pagarme-Signature' => hash_hmac('sha256', $raw, $segredo)]
        : [];

    return test()->call('POST', '/api/webhooks/pagarme', [], [], [], transformHeaders($headers), $raw);
}

function transformHeaders(array $headers): array
{
    $server = ['CONTENT_TYPE' => 'application/json'];
    foreach ($headers as $k => $v) {
        $server['HTTP_'.strtoupper(str_replace('-', '_', $k))] = $v;
    }

    return $server;
}

test('webhook com assinatura válida responde 200 e enfileira o processamento', function () {
    $payload = ['id' => 'evt_ok', 'type' => 'charge.paid', 'data' => ['external_reference' => '0190-turno']];

    $resp = postWebhook($payload);

    $resp->assertOk()->assertJson(['status' => 'recebido']);
    Queue::assertPushed(ProcessarWebhookPagarmeJob::class, 1);
    expect(WebhookEventoPagarme::where('event_id', 'evt_ok')->exists())->toBeTrue();
});

test('webhook com assinatura inválida responde 401 e não enfileira', function () {
    $resp = postWebhook(['id' => 'evt_x', 'type' => 'charge.paid'], segredo: 'segredo-errado');

    $resp->assertStatus(401);
    Queue::assertNothingPushed();
    expect(WebhookEventoPagarme::count())->toBe(0);
});

test('webhook sem assinatura responde 401', function () {
    postWebhook(['id' => 'evt_x'], segredo: null)->assertStatus(401);
    Queue::assertNothingPushed();
});

test('webhook sem event_id responde 422', function () {
    postWebhook(['type' => 'charge.paid'])->assertStatus(422);
    Queue::assertNothingPushed();
});

test('webhook duplicado (mesmo event_id) responde 200 sem reprocessar', function () {
    $payload = ['id' => 'evt_dup', 'type' => 'charge.paid', 'data' => ['external_reference' => 't1']];

    postWebhook($payload)->assertOk()->assertJson(['status' => 'recebido']);
    postWebhook($payload)->assertOk()->assertJson(['status' => 'duplicado']);

    Queue::assertPushed(ProcessarWebhookPagarmeJob::class, 1); // só a 1ª vez
    expect(WebhookEventoPagarme::where('event_id', 'evt_dup')->count())->toBe(1);
});
