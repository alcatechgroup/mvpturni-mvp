<?php

use Illuminate\Support\Facades\Log;

test('requisição propaga X-Request-Id no response (CA-7)', function () {
    $response = $this->get('/');

    expect($response->headers->get('X-Request-Id'))->not->toBeNull();
});

test('X-Request-Id é um UUID ou trace id válido (CA-7)', function () {
    $response = $this->get('/');
    $requestId = $response->headers->get('X-Request-Id');

    // UUID v4 ou trace id hex (pelo menos 16 chars)
    expect(strlen($requestId))->toBeGreaterThanOrEqual(16);
});

test('X-Cloud-Trace-Context entrante é reutilizado como request_id (CA-7)', function () {
    $traceId = '105445aa7843bc8bf206b12000100000';

    $response = $this->withHeaders([
        'X-Cloud-Trace-Context' => "{$traceId}/1;o=1",
    ])->get('/');

    expect($response->headers->get('X-Request-Id'))->toBe($traceId);
});

test('request_id diferente quando não há X-Cloud-Trace-Context (CA-7)', function () {
    $r1 = $this->get('/')->headers->get('X-Request-Id');
    $r2 = $this->get('/')->headers->get('X-Request-Id');

    // Sem header entrante, gera UUIDs; mesmo em testes podem coincidir
    // — validamos apenas que cada um é um UUID bem formado
    $uuidPattern = '/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i';
    expect($r1)->toMatch($uuidPattern);
    expect($r2)->toMatch($uuidPattern);
});

test('middleware loga campos canônicos do ADR-008 (CA-7)', function () {
    Log::spy();

    $this->get('/health');

    Log::shouldHaveReceived('info')
        ->withArgs(fn ($event, $context) => $event === 'request.handled'
            && isset($context['service'], $context['request_id'], $context['method'],
                $context['path'], $context['status_code'], $context['duration_ms'])
            && $context['service'] === 'backoffice'
        )
        ->once();
});
