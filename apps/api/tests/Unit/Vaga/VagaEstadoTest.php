<?php

// STORY-044 / ADR-013 Decisão 2 e 4 — máquina de estados da Vaga (transições válidas
// no domínio; enum nativo só restringe o conjunto de valores). Testes puros (sem DB).

use App\Enums\VagaEstado;

test('valores do enum batem com o tipo Postgres (CA-4)', function () {
    expect(array_map(fn ($c) => $c->value, VagaEstado::cases()))
        ->toBe(['aberta', 'fechada', 'cancelada']);
});

// ── Caminho feliz: transições permitidas (domain/vaga.md) ──
test('aberta pode ir para fechada', function () {
    expect(VagaEstado::Aberta->canTransitionTo(VagaEstado::Fechada))->toBeTrue();
});

test('aberta pode ir para cancelada', function () {
    expect(VagaEstado::Aberta->canTransitionTo(VagaEstado::Cancelada))->toBeTrue();
});

// ── Casos inválidos: transições proibidas ──
test('fechada não pode ir para cancelada (domain/vaga.md)', function () {
    expect(VagaEstado::Fechada->canTransitionTo(VagaEstado::Cancelada))->toBeFalse();
});

test('fechada é terminal — não volta para aberta', function () {
    expect(VagaEstado::Fechada->canTransitionTo(VagaEstado::Aberta))->toBeFalse();
});

test('cancelada é terminal', function () {
    expect(VagaEstado::Cancelada->canTransitionTo(VagaEstado::Aberta))->toBeFalse();
    expect(VagaEstado::Cancelada->canTransitionTo(VagaEstado::Fechada))->toBeFalse();
});

// ── Borda: transição para o próprio estado é no-op inválido ──
test('transição para o mesmo estado é inválida', function () {
    expect(VagaEstado::Aberta->canTransitionTo(VagaEstado::Aberta))->toBeFalse();
});
