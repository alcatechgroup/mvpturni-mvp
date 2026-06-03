<?php

// STORY-053 (CA-6) — validação ciente da categoria: templates de e-mail usam `{snake_case}` e a
// lista de variáveis por slug do EmailTemplateCatalogo (não os placeholders `{{ns.campo}}` de contrato).

use App\Domain\Templates\EmailTemplateCatalogo;
use App\Domain\Templates\TemplateContentValidator;

function emailValidator(): TemplateContentValidator
{
    return new TemplateContentValidator;
}

test('extrai variáveis {snake_case} sem duplicatas', function () {
    $conteudo = 'Olá {profissional_nome}, vaga {vaga_funcao} e de novo {vaga_funcao}.';

    expect(emailValidator()->variaveisEmail($conteudo))->toBe(['profissional_nome', 'vaga_funcao']);
});

test('aceita as variáveis canônicas do template de e-mail (por slug)', function () {
    $slug = 'candidatura_recebida_email';
    $conteudo = collect(EmailTemplateCatalogo::variaveis($slug))->map(fn ($v) => '{'.$v.'}')->implode(' ');

    expect(emailValidator()->placeholdersDesconhecidosPara($slug, $conteudo))->toBe([]);
});

test('detecta variável de e-mail fora da lista do slug', function () {
    expect(emailValidator()->placeholdersDesconhecidosPara('vaga_cancelada_email', 'A vaga {vaga_funcao} foi cancelada por {profissional_score}.'))
        ->toBe(['profissional_score']); // profissional_score não está no payload de vaga_cancelada
});

test('para contrato, mantém a validação de {{ns.campo}}', function () {
    expect(emailValidator()->placeholdersDesconhecidosPara('pf_autonomo_eventual', 'Ok {{profissional.nome}} mas {{foo.bar}} não'))
        ->toBe(['foo.bar']);
});
