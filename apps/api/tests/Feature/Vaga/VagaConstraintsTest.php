<?php

// STORY-044 / ADR-013 — invariantes duras garantidas no banco (CA-5):
// posicoes>=1, data_fim>data_inicio, posicoes_preenchidas no range, unicidade da candidatura.

use App\Models\Candidatura;
use App\Models\User;
use App\Models\Vaga;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

test('posicoes < 1 é rejeitado pelo banco', function () {
    expect(fn () => Vaga::factory()->create(['posicoes' => 0]))
        ->toThrow(QueryException::class);
});

test('data_fim <= data_inicio é rejeitado pelo banco', function () {
    expect(fn () => Vaga::factory()->create([
        'data_inicio' => now()->addDay(),
        'data_fim' => now()->addDay(),
    ]))->toThrow(QueryException::class);
});

test('posicoes_preenchidas acima de posicoes é rejeitado', function () {
    expect(fn () => Vaga::factory()->create([
        'posicoes' => 1,
        'posicoes_preenchidas' => 2,
    ]))->toThrow(QueryException::class);
});

test('posicoes_preenchidas negativo é rejeitado', function () {
    expect(fn () => Vaga::factory()->create([
        'posicoes' => 1,
        'posicoes_preenchidas' => -1,
    ]))->toThrow(QueryException::class);
});

test('mesmo profissional não candidata 2x na mesma vaga (UNIQUE)', function () {
    $vaga = Vaga::factory()->create();
    $prof = User::factory()->profissional()->ativo()->create();

    Candidatura::factory()->create(['vaga_id' => $vaga->id, 'profissional_id' => $prof->id]);

    expect(fn () => Candidatura::factory()->create([
        'vaga_id' => $vaga->id,
        'profissional_id' => $prof->id,
    ]))->toThrow(QueryException::class);
});

test('profissionais diferentes podem candidatar na mesma vaga', function () {
    $vaga = Vaga::factory()->create();

    Candidatura::factory()->create(['vaga_id' => $vaga->id]);
    Candidatura::factory()->create(['vaga_id' => $vaga->id]);

    expect(Candidatura::where('vaga_id', $vaga->id)->count())->toBe(2);
});
