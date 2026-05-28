<?php

test('health endpoint retorna 200 com campos obrigatórios (CA-4)', function () {
    $response = $this->getJson('/health');

    $response->assertStatus(200)
        ->assertJsonStructure(['status', 'version', 'timestamp', 'service'])
        ->assertJsonPath('status', 'ok')
        ->assertJsonPath('service', 'backoffice');
});

test('health campo service é sempre "backoffice" (CA-4)', function () {
    $this->getJson('/health')->assertJsonPath('service', 'backoffice');
    $this->getJson('/health?deep=0')->assertJsonPath('service', 'backoffice');
});

test('health endpoint sem deep=1 é liveness — não depende do banco (CA-5)', function () {
    $response = $this->getJson('/health');
    $response->assertStatus(200)->assertJsonPath('status', 'ok');
});

test('health endpoint com deep=1 retorna 503 quando banco falha (CA-5)', function () {
    config(['session.driver' => 'array']);
    config(['database.connections.pgsql_fail' => [
        'driver' => 'pgsql', 'host' => '127.0.0.1', 'port' => '19999',
        'database' => 'fake', 'username' => 'fake', 'password' => 'fake',
    ]]);
    config(['database.default' => 'pgsql_fail']);

    $response = $this->getJson('/health?deep=1');

    config(['database.default' => 'pgsql']);

    $response->assertStatus(503)
        ->assertJsonPath('status', 'degraded')
        ->assertJsonPath('service', 'backoffice');
});

test('health endpoint responde em menos de 500ms em condição normal (CA-6)', function () {
    $start = microtime(true);
    $this->getJson('/health')->assertStatus(200);
    $elapsed = (microtime(true) - $start) * 1000;

    expect($elapsed)->toBeLessThan(500);
});

test('health endpoint retorna timestamp ISO 8601 válido', function () {
    $body = $this->getJson('/health')->assertStatus(200)->json();

    expect($body['timestamp'])->toMatch('/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/');
});
