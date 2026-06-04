<?php

// STORY-055 / ADR-015 (CA-2) — invariantes duras de `turnos` no banco: consistência
// financeira (total = valor + taxa), ordem de datas, valores não-negativos e 1 turno por
// candidatura.

use App\Models\Candidatura;
use App\Models\Turno;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

test('rejeita total_contratante inconsistente (≠ valor + taxa_turni)', function () {
    expect(fn () => Turno::factory()->create([
        'valor' => 100,
        'taxa_turni' => 15,
        'total_contratante' => 999, // inconsistente
    ]))->toThrow(Exception::class);
});

test('aceita total_contratante consistente', function () {
    $turno = Turno::factory()->create([
        'valor' => 100,
        'taxa_turni' => 15,
        'total_contratante' => 115,
    ]);
    expect((float) $turno->total_contratante)->toBe(115.0);
});

test('rejeita data_fim <= data_inicio', function () {
    expect(fn () => Turno::factory()->create([
        'data_inicio' => now()->addDay(),
        'data_fim' => now(), // antes do início
    ]))->toThrow(Exception::class);
});

test('rejeita valores negativos', function () {
    expect(fn () => Turno::factory()->create([
        'valor' => -10,
        'taxa_turni' => 0,
        'total_contratante' => -10,
    ]))->toThrow(Exception::class);
});

test('uma candidatura gera no máximo um turno (UNIQUE candidatura_id)', function () {
    $candidatura = Candidatura::factory()->create();
    Turno::factory()->create(['candidatura_id' => $candidatura->id]);

    expect(fn () => Turno::factory()->create(['candidatura_id' => $candidatura->id]))
        ->toThrow(Exception::class);
});
