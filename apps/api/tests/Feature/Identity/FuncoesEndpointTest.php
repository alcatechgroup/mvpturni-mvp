<?php

// STORY-017 — GET /api/funcoes — lista pública para o select do pré-cadastro.

use App\Models\Funcao;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

test('lista apenas funções ativas, ordenadas por nome, sem auth', function () {
    Funcao::create(['slug' => 'garcom', 'nome' => 'Garçom / Garçonete', 'ativo' => true]);
    Funcao::create(['slug' => 'bartender', 'nome' => 'Bartender', 'ativo' => true]);
    Funcao::create(['slug' => 'descontinuada', 'nome' => 'Antiga', 'ativo' => false]);

    $response = test()->getJson('/api/funcoes');

    $response->assertOk()->assertJsonStructure(['data' => [['id', 'slug', 'nome']]]);

    $nomes = collect($response->json('data'))->pluck('nome')->all();
    expect($nomes)->toBe(['Bartender', 'Garçom / Garçonete']); // ordem alfabética, sem a inativa
});

test('não expõe a coluna ativo no payload', function () {
    Funcao::create(['slug' => 'garcom', 'nome' => 'Garçom', 'ativo' => true]);

    $first = test()->getJson('/api/funcoes')->json('data.0');
    expect($first)->not->toHaveKey('ativo');
});
