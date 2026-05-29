<?php

// STORY-020 — renderização do template para a UI: Markdown seguro + chips de placeholder.

use App\Domain\Templates\TemplateRenderer;

function renderer(): TemplateRenderer
{
    return new TemplateRenderer;
}

test('renderiza markdown para html', function () {
    $html = renderer()->html("## Título\n\ntexto **forte**");

    expect($html)->toContain('<h2>Título</h2>')
        ->toContain('<strong>forte</strong>');
});

test('mantém placeholders visíveis como chips', function () {
    $html = renderer()->html('Nome: {{profissional.nome}}');

    expect($html)->toContain('class="ph"')
        ->toContain('⟦profissional.nome⟧')
        ->not->toContain('{{profissional.nome}}');
});

test('marca placeholder inválido com classe de erro', function () {
    $html = renderer()->html('{{contratante.razao_zocial}}', ['contratante.razao_zocial']);

    expect($html)->toContain('ph-bad')
        ->toContain('placeholder inválido');
});

test('descarta HTML bruto do admin (sem template injection / execução de código)', function () {
    $html = renderer()->html('<script>alert(1)</script> texto');

    expect($html)->not->toContain('<script>');
});
