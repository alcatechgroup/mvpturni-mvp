<?php

// STORY-044 / ADR-013 (CA-7) — seed mínimo: 1 contratante + 5 vagas em estados
// variados (3 abertas, 1 fechada, 1 cancelada) com funções distintas.

use App\Enums\VagaEstado;
use App\Models\Vaga;
use Database\Seeders\FuncaoSeeder;
use Database\Seeders\VagasSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

beforeEach(function () {
    $this->seed(FuncaoSeeder::class);
    $this->seed(VagasSeeder::class);
});

test('cria exatamente 5 vagas', function () {
    expect(Vaga::count())->toBe(5);
});

test('distribuição de estados é 3 abertas, 1 fechada, 1 cancelada', function () {
    expect(Vaga::where('estado', VagaEstado::Aberta)->count())->toBe(3)
        ->and(Vaga::where('estado', VagaEstado::Fechada)->count())->toBe(1)
        ->and(Vaga::where('estado', VagaEstado::Cancelada)->count())->toBe(1);
});

test('as 5 vagas têm funções distintas', function () {
    expect(Vaga::distinct('funcao_id')->count('funcao_id'))->toBe(5);
});

test('todas as vagas pertencem ao mesmo contratante seed e têm versão 1', function () {
    expect(Vaga::distinct('contratante_id')->count('contratante_id'))->toBe(1)
        ->and(Vaga::where('versao_atual', 1)->count())->toBe(5);
});

test('seed é idempotente — rodar de novo não duplica', function () {
    $this->seed(VagasSeeder::class);
    expect(Vaga::count())->toBe(5);
});
