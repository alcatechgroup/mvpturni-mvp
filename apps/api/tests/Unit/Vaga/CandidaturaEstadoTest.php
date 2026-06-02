<?php

// STORY-044 / ADR-013 — máquina de estados da Candidatura (domain/candidatura.md).
// Testes puros (sem DB).

use App\Enums\CandidaturaEstado;

test('valores do enum batem com o tipo Postgres (CA-4)', function () {
    expect(array_map(fn ($c) => $c->value, CandidaturaEstado::cases()))
        ->toBe([
            'pendente',
            'aprovada',
            'retirada',
            'pendente_revisao_apos_edicao',
            'retirada_por_edicao',
            'recusada',
        ]);
});

// ── Caminho feliz: transições permitidas ──
test('pendente pode ir para aprovada', function () {
    expect(CandidaturaEstado::Pendente->canTransitionTo(CandidaturaEstado::Aprovada))->toBeTrue();
});

test('pendente pode ir para retirada', function () {
    expect(CandidaturaEstado::Pendente->canTransitionTo(CandidaturaEstado::Retirada))->toBeTrue();
});

test('pendente pode ir para pendente_revisao_apos_edicao (PDR-009)', function () {
    expect(CandidaturaEstado::Pendente->canTransitionTo(CandidaturaEstado::PendenteRevisaoAposEdicao))->toBeTrue();
});

test('revisão pode voltar para pendente (confirma manutenção)', function () {
    expect(CandidaturaEstado::PendenteRevisaoAposEdicao->canTransitionTo(CandidaturaEstado::Pendente))->toBeTrue();
});

test('revisão pode ir para retirada_por_edicao (prazo/retirada)', function () {
    expect(CandidaturaEstado::PendenteRevisaoAposEdicao->canTransitionTo(CandidaturaEstado::RetiradaPorEdicao))->toBeTrue();
});

// ── Casos inválidos: transições proibidas ──
test('aprovada é terminal — não volta para pendente', function () {
    expect(CandidaturaEstado::Aprovada->canTransitionTo(CandidaturaEstado::Pendente))->toBeFalse();
});

test('retirada é terminal', function () {
    expect(CandidaturaEstado::Retirada->canTransitionTo(CandidaturaEstado::Pendente))->toBeFalse();
});

test('recusada não é alcançável no MVP (reservada — domain/candidatura.md §lacunas)', function () {
    expect(CandidaturaEstado::Pendente->canTransitionTo(CandidaturaEstado::Recusada))->toBeFalse();
});

// ── Borda ──
test('transição para o mesmo estado é inválida', function () {
    expect(CandidaturaEstado::Pendente->canTransitionTo(CandidaturaEstado::Pendente))->toBeFalse();
});
