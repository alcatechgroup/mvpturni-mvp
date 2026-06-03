<?php

// STORY-053 (CA-5/CA-6) — EmailTemplateRenderer: parse do front-matter+corpo, interpolação
// `{snake_case}` com o payload, saudação a partir do nome, e falha dura em variável ausente.

use App\Services\Notificacao\EmailTemplateRenderer;
use App\Services\Notificacao\TemplateEmailIncompletoException;

beforeEach(function () {
    $this->renderer = new EmailTemplateRenderer;
});

function templateCandidatura(): string
{
    return <<<'MD'
    preheader: {profissional_nome} se candidatou à sua vaga de {vaga_funcao}.
    h1: Nova candidatura recebida
    cta_label: Ver candidatos
    cta_url: {link_painel}
    aviso:
    ---
    {profissional_nome} se candidatou à sua vaga de {vaga_funcao} em {vaga_data_inicio}.

    Score de match: {profissional_score}/100. O painel mostra o detalhamento.
    MD;
}

it('parseia front-matter e interpola o corpo com o payload', function () {
    $c = $this->renderer->renderizar(templateCandidatura(), [
        'profissional_nome' => 'Ana',
        'profissional_score' => 87,
        'vaga_funcao' => 'Garçom',
        'vaga_data_inicio' => '03/06/2026 18:00',
        'link_painel' => 'https://app.turni.com.br/contratante/vagas/9/candidatos',
    ], 'João');

    expect($c['preheader'])->toBe('Ana se candidatou à sua vaga de Garçom.')
        ->and($c['h1'])->toBe('Nova candidatura recebida')
        ->and($c['saudacao'])->toBe('Olá, João.')
        ->and($c['ctaLabel'])->toBe('Ver candidatos')
        ->and($c['ctaUrl'])->toBe('https://app.turni.com.br/contratante/vagas/9/candidatos')
        ->and($c['aviso'])->toBeNull()
        ->and($c['rodape'])->toContain('funil ativo de uma vaga no Turni')
        ->and($c['paragrafos'])->toBe([
            'Ana se candidatou à sua vaga de Garçom em 03/06/2026 18:00.',
            'Score de match: 87/100. O painel mostra o detalhamento.',
        ]);
});

it('usa "Olá." quando o destinatário não tem nome', function () {
    $c = $this->renderer->renderizar(templateCandidatura(), [
        'profissional_nome' => 'Ana', 'profissional_score' => 87, 'vaga_funcao' => 'Garçom',
        'vaga_data_inicio' => '03/06/2026 18:00', 'link_painel' => 'https://x',
    ], null);

    expect($c['saudacao'])->toBe('Olá.');
});

it('expande {diff_texto} multi-linha em um parágrafo por linha e interpola o aviso', function () {
    $template = <<<'MD'
    preheader: A vaga mudou.
    h1: Vaga editada
    cta_label: Confirmar
    cta_url: {link_detalhe}
    aviso: Sem resposta até {prazo_em}, sua candidatura é retirada.
    ---
    O contratante alterou a vaga de {vaga_funcao}. Veja o que mudou:

    {diff_texto}

    Você tem até {prazo_em} para confirmar.
    MD;

    $c = $this->renderer->renderizar($template, [
        'vaga_funcao' => 'Cozinheiro',
        'diff_texto' => "Início do turno: 03/06/2026 18:00 → 03/06/2026 20:00\nValor: R$ 100,00 → R$ 120,00",
        'prazo_em' => '04/06/2026 18:00',
        'link_detalhe' => 'https://app.turni.com.br/vaga/9',
    ], 'Maria');

    expect($c['aviso'])->toBe('Sem resposta até 04/06/2026 18:00, sua candidatura é retirada.')
        ->and($c['paragrafos'])->toBe([
            'O contratante alterou a vaga de Cozinheiro. Veja o que mudou:',
            'Início do turno: 03/06/2026 18:00 → 03/06/2026 20:00',
            'Valor: R$ 100,00 → R$ 120,00',
            'Você tem até 04/06/2026 18:00 para confirmar.',
        ]);
});

it('sem separador --- trata todo o conteúdo como corpo', function () {
    $c = $this->renderer->renderizar("Linha um {vaga_funcao}.\n\nLinha dois.", ['vaga_funcao' => 'Garçom'], 'Ana');

    expect($c['h1'])->toBe('')
        ->and($c['ctaUrl'])->toBe('')
        ->and($c['aviso'])->toBeNull()
        ->and($c['paragrafos'])->toBe(['Linha um Garçom.', 'Linha dois.']);
});

it('lança exceção quando uma variável do template não está no payload', function () {
    $this->renderer->renderizar(templateCandidatura(), [
        // falta vaga_data_inicio e link_painel
        'profissional_nome' => 'Ana', 'profissional_score' => 87, 'vaga_funcao' => 'Garçom',
    ], 'João');
})->throws(TemplateEmailIncompletoException::class);

it('trata valor nulo/vazio no payload como variável ausente (não envia incompleto)', function () {
    expect(fn () => $this->renderer->renderizar(templateCandidatura(), [
        'profissional_nome' => 'Ana', 'profissional_score' => 87, 'vaga_funcao' => 'Garçom',
        'vaga_data_inicio' => '03/06/2026 18:00', 'link_painel' => '',
    ], 'João'))->toThrow(TemplateEmailIncompletoException::class);
});
