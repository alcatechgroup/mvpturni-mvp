<?php

// STORY-044 / ADR-013 — modelo Candidatura: transições guardadas no domínio,
// relações, casts. PDR-009 (revisão após edição) e domain/candidatura.md.

use App\Enums\CandidaturaEstado;
use App\Models\Candidatura;
use App\Models\User;
use App\Models\Vaga;
use App\Models\VagaVersao;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

// ── Caminho feliz ──
test('transitionTo pendente→aprovada persiste estado e aprovada_em', function () {
    $c = Candidatura::factory()->create();

    $c->transitionTo(CandidaturaEstado::Aprovada);

    $c->refresh();
    expect($c->estado)->toBe(CandidaturaEstado::Aprovada)
        ->and($c->aprovada_em)->not->toBeNull();
});

test('transitionTo pendente→retirada persiste retirada_em', function () {
    $c = Candidatura::factory()->create();

    $c->transitionTo(CandidaturaEstado::Retirada);

    expect($c->fresh()->retirada_em)->not->toBeNull();
});

test('ciclo de revisão PDR-009: pendente→revisão→pendente', function () {
    $c = Candidatura::factory()->create();

    $c->transitionTo(CandidaturaEstado::PendenteRevisaoAposEdicao);
    expect($c->fresh()->estado)->toBe(CandidaturaEstado::PendenteRevisaoAposEdicao);

    $c->transitionTo(CandidaturaEstado::Pendente);
    expect($c->fresh()->estado)->toBe(CandidaturaEstado::Pendente);
});

test('estado é casteado para o enum CandidaturaEstado', function () {
    expect(Candidatura::factory()->create()->fresh()->estado)
        ->toBeInstanceOf(CandidaturaEstado::class);
});

// ── Caso inválido ──
test('transição proibida aprovada→pendente lança DomainException', function () {
    $c = Candidatura::factory()->create(['estado' => CandidaturaEstado::Aprovada]);

    expect(fn () => $c->transitionTo(CandidaturaEstado::Pendente))
        ->toThrow(DomainException::class);
});

// ── Relações ──
test('candidatura pertence a vaga, profissional e (opcional) versão', function () {
    $vaga = Vaga::factory()->create();
    $versao = VagaVersao::factory()->create(['vaga_id' => $vaga->id, 'versao' => 1]);
    $c = Candidatura::factory()->create(['vaga_id' => $vaga->id, 'vaga_versao_id' => $versao->id]);

    expect($c->vaga)->toBeInstanceOf(Vaga::class)
        ->and($c->profissional)->toBeInstanceOf(User::class)
        ->and($c->profissional->isProfissional())->toBeTrue()
        ->and($c->vagaVersao)->toBeInstanceOf(VagaVersao::class);
});
