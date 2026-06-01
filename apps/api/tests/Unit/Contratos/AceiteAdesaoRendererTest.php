<?php

use App\Domain\Contratos\AceiteAdesaoRenderer;
use App\Domain\Contratos\RenderizacaoIncompletaException;

function templatePf(): string
{
    return file_get_contents(database_path('seeders/contracts/template-pf-autonomo-eventual-v1.md'));
}

function contextoAdesao(): array
{
    return [
        'profissional.nome' => 'Maria Silva',
        'profissional.documento' => '111.444.777-35',
        'profissional.endereco_completo' => 'Centro, São Paulo',
        'aceite.timestamp' => '01/06/2026 10:00',
        'aceite.ip' => '203.0.113.7',
        'aceite.fingerprint' => 'abc123',
    ];
}

test('extrairCorpoAdesao mantém Seção 1 e Assinatura, descarta Seção 2 e notas internas', function () {
    $corpo = (new AceiteAdesaoRenderer)->extrairCorpoAdesao(templatePf());

    expect($corpo)
        ->toContain('## Seção 1 — Termos gerais')
        ->toContain('## Assinatura eletrônica')
        ->not->toContain('## Seção 2')
        ->not->toContain('## Histórico de validação')
        ->not->toContain('## Notas do PO')
        ->not->toContain('{{contratante.')
        ->not->toContain('{{turno.');
});

test('renderiza o aceite de adesão com os dados do profissional', function () {
    $doc = (new AceiteAdesaoRenderer)->renderizar(templatePf(), contextoAdesao());

    expect($doc)
        ->toContain('Maria Silva')
        ->toContain('111.444.777-35')
        ->toContain('Centro, São Paulo')
        ->toContain('01/06/2026 10:00')
        ->toContain('203.0.113.7')
        ->not->toContain('{{'); // nenhum placeholder remanescente
});

test('placeholder ausente causa falha dura (nenhum aceite incompleto)', function () {
    $contexto = contextoAdesao();
    unset($contexto['profissional.documento']);

    expect(fn () => (new AceiteAdesaoRenderer)->renderizar(templatePf(), $contexto))
        ->toThrow(RenderizacaoIncompletaException::class);
});

test('preview usa marcador pendente nos campos de assinatura e bate com o corpo do aceite', function () {
    $renderer = new AceiteAdesaoRenderer;

    $previewContexto = [
        'profissional.nome' => 'Maria Silva',
        'profissional.documento' => '111.444.777-35',
        'profissional.endereco_completo' => 'Centro, São Paulo',
        'aceite.timestamp' => AceiteAdesaoRenderer::ASSINATURA_PENDENTE,
        'aceite.ip' => AceiteAdesaoRenderer::ASSINATURA_PENDENTE,
        'aceite.fingerprint' => AceiteAdesaoRenderer::ASSINATURA_PENDENTE,
    ];

    $preview = $renderer->renderizar(templatePf(), $previewContexto);
    $final = $renderer->renderizar(templatePf(), contextoAdesao());

    // O corpo contratual (tudo antes da Assinatura) é idêntico entre preview e aceite (IDR-022 b).
    $corpoPreview = strstr($preview, '## Assinatura eletrônica', true);
    $corpoFinal = strstr($final, '## Assinatura eletrônica', true);
    expect($corpoPreview)->toBe($corpoFinal);
    expect($preview)->toContain(AceiteAdesaoRenderer::ASSINATURA_PENDENTE);
});
