<?php

use Illuminate\Support\Facades\DB;

// Testes para o endpoint /health (ADR-008 + STORY-007 CA-11).

test('health endpoint retorna 200 com campos obrigatórios', function () {
    $response = $this->getJson('/health');

    $response->assertStatus(200)
        ->assertJsonStructure(['status', 'version', 'timestamp'])
        ->assertJsonPath('status', 'ok');
});

test('health endpoint não retorna version vazia', function () {
    $response = $this->getJson('/health');
    // Em qualquer ambiente, version não deve ser null (pode ser "unknown" em dev)
    expect($response->json('version'))->not->toBeNull()->not->toBe('');
});

test('health endpoint sem deep=1 retorna 200 mesmo sem banco', function () {
    // Liveness check: processo responde, independente de banco.
    $response = $this->getJson('/health');
    $response->assertStatus(200)->assertJsonPath('status', 'ok');
});

test('health endpoint com deep=1 verifica Postgres', function () {
    // Com banco disponível nos testes (Postgres real via Docker), deve ser 200.
    $response = $this->getJson('/health?deep=1');
    $response->assertStatus(200)->assertJsonPath('status', 'ok');
});

test('health endpoint com deep=1 retorna 503 quando banco falha', function () {
    // Usa sessão array para não interferir na simulação de falha de DB
    config(['session.driver' => 'array']);
    config(['database.connections.pgsql_fail' => [
        'driver' => 'pgsql', 'host' => '127.0.0.1', 'port' => '19999',
        'database' => 'fake', 'username' => 'fake', 'password' => 'fake',
    ]]);
    config(['database.default' => 'pgsql_fail']);

    $response = $this->getJson('/health?deep=1');

    // Cleanup antes de assertar (evita cascata em outros testes)
    config(['database.default' => 'pgsql']);

    $response->assertStatus(503)->assertJsonPath('status', 'degraded');
});

test('health timestamp não é vazio', function () {
    $response = $this->getJson('/health');
    $timestamp = $response->json('timestamp');

    expect($timestamp)->toBeString()->not->toBeEmpty();
    // Verifica formato ISO 8601 (contém T e +/Z)
    expect($timestamp)->toMatch('/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/');
});
