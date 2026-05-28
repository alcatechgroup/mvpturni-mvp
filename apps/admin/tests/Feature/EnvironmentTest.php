<?php

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Livewire\Livewire;

uses(RefreshDatabase::class);

// CA-6: o Backoffice também conecta no PostgreSQL real (mesmo banco do api, ADR-002).
test('o admin conecta no PostgreSQL', function () {
    expect(DB::connection()->getDriverName())->toBe('pgsql');
});

// CA-2: o processo admin aceita requisições — rota raiz redireciona para /login (agora com auth).
test('a rota raiz do admin responde (redireciona para login sem auth)', function () {
    $this->get('/')->assertRedirect('/login');
});

// Livewire 4 (ADR-001) está instalado e operante no Backoffice.
test('Livewire está disponível no admin', function () {
    expect(class_exists(Livewire::class))->toBeTrue();
});
