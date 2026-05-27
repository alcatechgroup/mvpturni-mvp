<?php

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Livewire\Livewire;

uses(RefreshDatabase::class);

// CA-6: o Backoffice também conecta no PostgreSQL real (mesmo banco do api, ADR-002).
test('o admin conecta no PostgreSQL', function () {
    expect(DB::connection()->getDriverName())->toBe('pgsql');
});

// CA-2: o processo admin aceita requisições — a rota raiz responde 200.
test('a rota raiz do admin responde 200', function () {
    $this->get('/')->assertOk();
});

// Livewire 4 (ADR-001) está instalado e operante no Backoffice.
test('Livewire está disponível no admin', function () {
    expect(class_exists(Livewire::class))->toBeTrue();
});
