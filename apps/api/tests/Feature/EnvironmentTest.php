<?php

use App\Models\User;
use Database\Seeders\AdminUserSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

uses(RefreshDatabase::class);

// CA-6: testes de integração rodam contra PostgreSQL real (não sqlite/mock).
test('a aplicação conecta no PostgreSQL', function () {
    expect(DB::connection()->getDriverName())->toBe('pgsql');
    expect(DB::select('select 1 as ok')[0]->ok)->toBe(1);
});

// CA-3: a migração inicial aplica o schema base do framework (idempotente).
// A tabela `jobs` é exigida pela fila driver `database` (ADR-002).
test('as migrações criam as tabelas base do framework', function () {
    expect(Schema::hasTable('migrations'))->toBeTrue();
    expect(Schema::hasTable('users'))->toBeTrue();
    expect(Schema::hasTable('jobs'))->toBeTrue();
    expect(Schema::hasTable('cache'))->toBeTrue();
});

// CA-2: o processo api aceita requisições — a rota raiz responde 200.
test('a rota raiz do api responde 200', function () {
    $this->get('/')->assertOk();
});

// CA-7: o seed mínimo cria o admin de teste (via DatabaseSeeder, o ponto de entrada).
test('o seed cria o usuário admin de teste', function () {
    $this->seed();

    expect(User::where('email', 'admin@turni.local')->count())->toBe(1);
});

// CA-7: o seed do admin é idempotente — rodar duas vezes não duplica.
test('o seed do admin é idempotente', function () {
    $seeder = new AdminUserSeeder;
    $seeder->run();
    $seeder->run();

    expect(User::where('email', 'admin@turni.local')->count())->toBe(1);
});
