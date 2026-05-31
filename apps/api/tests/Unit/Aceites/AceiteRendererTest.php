<?php

// STORY-023 / ADR-010 Decisão 3A — Motor de renderização do aceite de adesão.

use App\Domain\Aceites\AceiteRenderer;
use App\Domain\Aceites\PlaceholderAusenteException;

function seedPf(): string
{
    return (string) file_get_contents(
        database_path('seeders/contracts/template-pf-autonomo-eventual-v1.md')
    );
}

$contextoCompleto = [
    'profissional.nome' => 'Diego Silva',
    'profissional.documento' => '529.982.247-25',
    'profissional.endereco_completo' => 'Centro, São Paulo',
    'aceite.timestamp' => '30/05/2026 14:00:00',
    'aceite.ip' => '203.0.113.7',
    'aceite.fingerprint' => 'abc123fingerprint',
];

test('substitui placeholders pelos valores do contexto', function () use ($contextoCompleto) {
    $render = (new AceiteRenderer)->substituir('Nome: {{profissional.nome}}', $contextoCompleto);
    expect($render)->toBe('Nome: Diego Silva');
});

test('placeholder ausente no contexto lança falha dura (aceite nunca incompleto)', function () {
    (new AceiteRenderer)->substituir('Olá {{profissional.inexistente}}', []);
})->throws(PlaceholderAusenteException::class);

test('renderAdesao do template PF: mantém Seção 1 + Assinatura, substitui os dados do usuário', function () use ($contextoCompleto) {
    $render = (new AceiteRenderer)->renderAdesao(seedPf(), $contextoCompleto);

    expect($render)
        ->toContain('Seção 1 — Termos gerais')
        ->toContain('Diego Silva')
        ->toContain('529.982.247-25')
        ->toContain('Centro, São Paulo')
        ->toContain('Assinatura eletrônica')
        ->toContain('203.0.113.7')
        ->toContain('abc123fingerprint');
});

test('renderAdesao omite a Seção 2 (turno) e os blocos de meta-autoria do template', function () use ($contextoCompleto) {
    $render = (new AceiteRenderer)->renderAdesao(seedPf(), $contextoCompleto);

    expect($render)
        ->not->toContain('Seção 2 — Termos do turno')
        ->not->toContain('Identificação do Contratante')
        ->not->toContain('Histórico de validação')
        ->not->toContain('Notas do PO')
        // nenhum placeholder remanescente no documento final
        ->not->toContain('{{');
});

test('renderAdesao não falha por placeholders de turno (eles ficam na Seção 2 omitida)', function () use ($contextoCompleto) {
    // O contexto NÃO tem contratante.*/turno.*; ainda assim renderiza, pois a Seção 2 é omitida.
    expect((new AceiteRenderer)->renderAdesao(seedPf(), $contextoCompleto))->toBeString();
});
