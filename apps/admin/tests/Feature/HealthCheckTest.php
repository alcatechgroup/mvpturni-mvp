<?php

test('health endpoint retorna 200 com campos obrigatórios', function () {
    $response = $this->getJson('/health');

    $response->assertStatus(200)
        ->assertJsonStructure(['status', 'version', 'timestamp'])
        ->assertJsonPath('status', 'ok');
});

test('health endpoint sem deep=1 é liveness (sem banco)', function () {
    $response = $this->getJson('/health');
    $response->assertStatus(200)->assertJsonPath('status', 'ok');
});

test('health endpoint com deep=1 retorna 503 quando banco falha', function () {
    config(['session.driver' => 'array']);
    config(['database.connections.pgsql_fail' => [
        'driver' => 'pgsql', 'host' => '127.0.0.1', 'port' => '19999',
        'database' => 'fake', 'username' => 'fake', 'password' => 'fake',
    ]]);
    config(['database.default' => 'pgsql_fail']);

    $response = $this->getJson('/health?deep=1');

    config(['database.default' => 'pgsql']);

    $response->assertStatus(503)->assertJsonPath('status', 'degraded');
});
