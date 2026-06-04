<?php

// STORY-056 / ADR-016 (CA-6, CA-10) — NÚCLEO: validação HMAC + parsing do webhook. Puro,
// sem DB. Cobre assinatura válida/inválida/ausente, extração de event_id/turno_id e o mapa
// completo de type → evento de domínio (incl. desconhecido).

use App\Domain\Pagamento\Webhook\PagarmeWebhookValidator;
use App\Events\Pagamento\CapturaConfirmada;
use App\Events\Pagamento\PixEnviado;
use App\Events\Pagamento\PixFalhou;
use App\Events\Pagamento\PreAutorizacaoCriada;
use App\Events\Pagamento\PreAutorizacaoLiberada;

const SEGREDO = 'whsec_teste';

function webhookValidator(): PagarmeWebhookValidator
{
    return new PagarmeWebhookValidator(SEGREDO);
}

test('assinatura HMAC correta é aceita', function () {
    $corpo = '{"id":"evt_1","type":"charge.paid"}';
    $assinatura = hash_hmac('sha256', $corpo, SEGREDO);

    expect(webhookValidator()->assinaturaValida($corpo, $assinatura))->toBeTrue();
});

test('assinatura HMAC errada é rejeitada', function () {
    $corpo = '{"id":"evt_1"}';

    expect(webhookValidator()->assinaturaValida($corpo, 'deadbeef'))->toBeFalse();
});

test('assinatura ausente ou vazia é rejeitada', function () {
    $corpo = '{"id":"evt_1"}';

    expect(webhookValidator()->assinaturaValida($corpo, null))->toBeFalse()
        ->and(webhookValidator()->assinaturaValida($corpo, ''))->toBeFalse();
});

test('assinatura é sensível a qualquer alteração do corpo', function () {
    $assinatura = hash_hmac('sha256', '{"a":1}', SEGREDO);

    expect(webhookValidator()->assinaturaValida('{"a":2}', $assinatura))->toBeFalse();
});

test('event_id é extraído quando presente e válido', function () {
    expect(webhookValidator()->eventId(['id' => 'evt_42']))->toBe('evt_42')
        ->and(webhookValidator()->eventId(['id' => '']))->toBeNull()
        ->and(webhookValidator()->eventId([]))->toBeNull()
        ->and(webhookValidator()->eventId(['id' => 123]))->toBeNull();
});

test('turno_id vem do external_reference', function () {
    $payload = ['data' => ['external_reference' => '0190-uuid-turno']];

    expect(webhookValidator()->turnoId($payload))->toBe('0190-uuid-turno')
        ->and(webhookValidator()->turnoId(['data' => []]))->toBeNull()
        ->and(webhookValidator()->turnoId([]))->toBeNull();
});

test('mapa type → evento de domínio cobre todos os tipos canônicos', function (string $type, string $classe) {
    expect(webhookValidator()->eventoDominio(['type' => $type]))->toBe($classe);
})->with([
    ['charge.pending', PreAutorizacaoCriada::class],
    ['charge.authorized', PreAutorizacaoCriada::class],
    ['charge.paid', CapturaConfirmada::class],
    ['charge.captured', CapturaConfirmada::class],
    ['transfer.paid', PixEnviado::class],
    ['transfer.created', PixEnviado::class],
    ['transfer.failed', PixFalhou::class],
    ['charge.canceled', PreAutorizacaoLiberada::class],
    ['charge.refunded', PreAutorizacaoLiberada::class],
]);

test('type desconhecido ou ausente mapeia para null (aceito sem evento)', function () {
    expect(webhookValidator()->eventoDominio(['type' => 'charge.inventado']))->toBeNull()
        ->and(webhookValidator()->eventoDominio([]))->toBeNull();
});
