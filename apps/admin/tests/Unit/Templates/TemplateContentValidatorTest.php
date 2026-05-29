<?php

// STORY-020 — núcleo de validação de conteúdo de template (CA-5). Função pura, sem banco.

use App\Domain\Templates\TemplateContentValidator;

function contentValidator(): TemplateContentValidator
{
    return new TemplateContentValidator;
}

test('extrai placeholders sem duplicatas e tolera espaços', function () {
    $conteudo = 'Nome {{profissional.nome}} e de novo {{ profissional.nome }} e {{turno.valor}}';

    expect(contentValidator()->placeholders($conteudo))
        ->toBe(['profissional.nome', 'turno.valor']);
});

test('aceita todos os placeholders canônicos (ADR-010)', function () {
    $conteudo = collect(TemplateContentValidator::CANONICOS)
        ->map(fn ($p) => '{{'.$p.'}}')
        ->implode("\n");

    expect(contentValidator()->placeholdersDesconhecidos($conteudo))->toBe([]);
});

test('detecta placeholder fora da lista canônica e o devolve por extenso', function () {
    $conteudo = 'Ok {{profissional.nome}} mas {{contratante.razao_zocial}} está errado';

    expect(contentValidator()->placeholdersDesconhecidos($conteudo))
        ->toBe(['contratante.razao_zocial']);
});

test('conteúdo sem placeholders não acusa desconhecidos', function () {
    expect(contentValidator()->placeholdersDesconhecidos('texto puro, sem chaves'))->toBe([]);
});

test('aviso soft: detecta seções nomeadas ausentes', function () {
    expect(contentValidator()->secoesFaltando('## Termos gerais\n\nsó isso'))
        ->toBe(['Termos do turno']);

    expect(contentValidator()->secoesFaltando('## Termos gerais ... ## Termos do turno específico'))
        ->toBe([]);
});
