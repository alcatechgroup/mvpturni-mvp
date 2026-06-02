<?php

// STORY-044 / ADR-013 — modelo Vaga: transições guardadas no domínio (CA-4),
// auto-fechamento ao preencher a última posição (domain/vaga.md), relações e casts.

use App\Enums\VagaEstado;
use App\Models\Candidatura;
use App\Models\Funcao;
use App\Models\User;
use App\Models\Vaga;
use App\Models\VagaVersao;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

// ── Caminho feliz ──
test('transitionTo aberta→fechada persiste estado e fechada_em', function () {
    $vaga = Vaga::factory()->create();

    $vaga->transitionTo(VagaEstado::Fechada);

    $vaga->refresh();
    expect($vaga->estado)->toBe(VagaEstado::Fechada)
        ->and($vaga->fechada_em)->not->toBeNull();
});

test('transitionTo aberta→cancelada persiste estado e cancelada_em', function () {
    $vaga = Vaga::factory()->create();

    $vaga->transitionTo(VagaEstado::Cancelada);

    $vaga->refresh();
    expect($vaga->estado)->toBe(VagaEstado::Cancelada)
        ->and($vaga->cancelada_em)->not->toBeNull();
});

test('estado é casteado para o enum VagaEstado', function () {
    $vaga = Vaga::factory()->create();
    expect($vaga->fresh()->estado)->toBeInstanceOf(VagaEstado::class);
});

// ── Caso inválido ──
test('transição proibida fechada→cancelada lança DomainException', function () {
    $vaga = Vaga::factory()->fechada()->create();

    expect(fn () => $vaga->transitionTo(VagaEstado::Cancelada))
        ->toThrow(DomainException::class);
});

test('transição proibida não persiste o estado novo', function () {
    $vaga = Vaga::factory()->fechada()->create();

    try {
        $vaga->transitionTo(VagaEstado::Aberta);
    } catch (DomainException) {
        // esperado
    }

    expect($vaga->fresh()->estado)->toBe(VagaEstado::Fechada);
});

// ── Borda: auto-fechamento por preenchimento de posições ──
test('preencherPosicao fecha a vaga só quando a última posição é preenchida', function () {
    $vaga = Vaga::factory()->create(['posicoes' => 2, 'posicoes_preenchidas' => 0]);

    $vaga->preencherPosicao();
    expect($vaga->fresh()->estado)->toBe(VagaEstado::Aberta)
        ->and($vaga->fresh()->posicoes_preenchidas)->toBe(1);

    $vaga->preencherPosicao();
    expect($vaga->fresh()->estado)->toBe(VagaEstado::Fechada)
        ->and($vaga->fresh()->posicoes_preenchidas)->toBe(2);
});

test('preencherPosicao em vaga de 1 posição fecha de imediato', function () {
    $vaga = Vaga::factory()->create(['posicoes' => 1, 'posicoes_preenchidas' => 0]);

    $vaga->preencherPosicao();

    expect($vaga->fresh()->estado)->toBe(VagaEstado::Fechada);
});

// ── Relações ──
test('vaga pertence a um contratante e a uma função', function () {
    $vaga = Vaga::factory()->create();
    expect($vaga->contratante)->toBeInstanceOf(User::class)
        ->and($vaga->contratante->isContratante())->toBeTrue()
        ->and($vaga->funcao)->toBeInstanceOf(Funcao::class);
});

test('vaga tem muitas versões e candidaturas', function () {
    $vaga = Vaga::factory()->create();
    VagaVersao::factory()->create(['vaga_id' => $vaga->id, 'versao' => 1]);
    Candidatura::factory()->create(['vaga_id' => $vaga->id]);

    expect($vaga->versoes)->toHaveCount(1)
        ->and($vaga->candidaturas)->toHaveCount(1);
});
