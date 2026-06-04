<?php

// STORY-056 / ADR-016 (CA-6) — job que processa o webhook no worker: mapeia type do provedor
// → evento de domínio, marca processado e é idempotente.

use App\Domain\Pagamento\Webhook\PagarmeWebhookValidator;
use App\Events\Pagamento\CapturaConfirmada;
use App\Events\Pagamento\PixEnviado;
use App\Events\Pagamento\PixFalhou;
use App\Events\Pagamento\PreAutorizacaoCriada;
use App\Events\Pagamento\PreAutorizacaoLiberada;
use App\Jobs\ProcessarWebhookPagarmeJob;
use App\Models\WebhookEventoPagarme;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;

uses(RefreshDatabase::class);

/** Só os eventos de domínio — evita capturar eventos de framework (QueryExecuted etc.). */
const EVENTOS_DOMINIO = [
    PreAutorizacaoCriada::class, CapturaConfirmada::class,
    PixEnviado::class, PixFalhou::class, PreAutorizacaoLiberada::class,
];

function gravarEvento(string $eventId, string $type, ?string $turnoId = 't1'): WebhookEventoPagarme
{
    return WebhookEventoPagarme::create([
        'event_id' => $eventId,
        'tipo' => $type,
        'turno_id' => $turnoId,
        'payload' => ['id' => $eventId, 'type' => $type, 'data' => array_filter(['external_reference' => $turnoId])],
        'recebido_em' => now(),
    ]);
}

test('processa charge.paid emitindo CapturaConfirmada e marca processado', function () {
    Event::fake([CapturaConfirmada::class]);
    gravarEvento('evt_cap', 'charge.paid', '0190-turno');

    (new ProcessarWebhookPagarmeJob('evt_cap'))->handle(app(PagarmeWebhookValidator::class));

    Event::assertDispatched(CapturaConfirmada::class, fn ($e) => $e->turnoId === '0190-turno' && $e->pagarmeEventId === 'evt_cap');
    expect(WebhookEventoPagarme::where('event_id', 'evt_cap')->first()->processado_em)->not->toBeNull();
});

test('transfer.failed emite PixFalhou (gancho do alerta PDR-010)', function () {
    Event::fake([PixFalhou::class]);
    gravarEvento('evt_pixfail', 'transfer.failed', 't9');

    (new ProcessarWebhookPagarmeJob('evt_pixfail'))->handle(app(PagarmeWebhookValidator::class));

    Event::assertDispatched(PixFalhou::class);
});

test('job é idempotente: 2ª execução não reemite o evento', function () {
    Event::fake([CapturaConfirmada::class]);
    gravarEvento('evt_2x', 'charge.paid');

    $validator = app(PagarmeWebhookValidator::class);
    (new ProcessarWebhookPagarmeJob('evt_2x'))->handle($validator);
    (new ProcessarWebhookPagarmeJob('evt_2x'))->handle($validator);

    Event::assertDispatchedTimes(CapturaConfirmada::class, 1);
});

test('type desconhecido marca processado sem emitir evento de domínio', function () {
    Event::fake(EVENTOS_DOMINIO);
    gravarEvento('evt_unknown', 'charge.misterioso');

    (new ProcessarWebhookPagarmeJob('evt_unknown'))->handle(app(PagarmeWebhookValidator::class));

    expect(WebhookEventoPagarme::where('event_id', 'evt_unknown')->first()->processado_em)->not->toBeNull();
});

test('event_id inexistente é no-op', function () {
    Event::fake(EVENTOS_DOMINIO);

    (new ProcessarWebhookPagarmeJob('nao_existe'))->handle(app(PagarmeWebhookValidator::class));

    Event::assertNothingDispatched();
});
