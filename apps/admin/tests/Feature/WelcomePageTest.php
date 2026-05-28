<?php

test('rota raiz retorna 200 (CA-1)', function () {
    $this->get('/')->assertStatus(200);
});

test('página raiz contém identificador "Turni — Backoffice (Admin)" (CA-1)', function () {
    $this->get('/')
        ->assertStatus(200)
        ->assertSee('Turni — Backoffice (Admin)');
});

test('página raiz contém link explícito para /health (CA-1)', function () {
    $this->get('/')
        ->assertStatus(200)
        ->assertSee('href="/health"', escape: false);
});

test('página raiz exibe campo de versão (CA-1)', function () {
    $this->get('/')
        ->assertStatus(200)
        ->assertSee('data-testid="app-version"', escape: false);
});

test('título da página identifica inequivocamente o Backoffice (CA-1)', function () {
    $this->get('/')
        ->assertStatus(200)
        ->assertSee('<title>Turni — Backoffice (Admin)</title>', escape: false);
});
