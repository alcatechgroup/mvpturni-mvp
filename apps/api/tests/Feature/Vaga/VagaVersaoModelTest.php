<?php

// STORY-044 / ADR-013 Decisão 1 — relações e casts do snapshot VagaVersao (núcleo).

use App\Models\User;
use App\Models\Vaga;
use App\Models\VagaVersao;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

test('versão pertence a uma vaga', function () {
    $vaga = Vaga::factory()->create();
    $versao = VagaVersao::factory()->create(['vaga_id' => $vaga->id, 'versao' => 1]);

    expect($versao->vaga)->toBeInstanceOf(Vaga::class)
        ->and($versao->vaga->id)->toBe($vaga->id);
});

test('versão registra quem editou (editadoPor)', function () {
    $contratante = User::factory()->contratante()->ativo()->create();
    $versao = VagaVersao::factory()->create(['editado_por' => $contratante->id]);

    expect($versao->editadoPor)->toBeInstanceOf(User::class)
        ->and($versao->editadoPor->id)->toBe($contratante->id);
});

test('snapshot é casteado para array', function () {
    $versao = VagaVersao::factory()->create([
        'snapshot' => ['valor' => 150.0, 'posicoes' => 2],
    ]);

    expect($versao->fresh()->snapshot)->toBeArray()
        ->toEqual(['valor' => 150.0, 'posicoes' => 2]);
});
