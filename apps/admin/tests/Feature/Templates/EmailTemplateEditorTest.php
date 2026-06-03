<?php

// STORY-053 (CA-6) — editor ciente da categoria `email`: valida `{snake_case}` contra a lista do
// slug (EmailTemplateCatalogo), documenta as variáveis disponíveis e cria nova versão.

use App\Livewire\TemplateEditor;
use App\Models\Template;
use App\Models\TemplateVersao;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;

uses(RefreshDatabase::class);

function adminEmail(): User
{
    return User::factory()->admin()->create();
}

function templateEmail(string $slug = 'candidatura_recebida_email'): Template
{
    $template = Template::factory()->create([
        'slug' => $slug,
        'categoria' => 'email',
        'nome_amigavel' => 'E-mail — Nova candidatura recebida (contratante)',
    ]);
    TemplateVersao::factory()->for($template)->versao(1)->ativa()->create([
        'conteudo' => "preheader: {profissional_nome} se candidatou.\nh1: Nova candidatura\ncta_label: Ver\ncta_url: {link_painel}\naviso:\n---\n{profissional_nome} se candidatou à vaga de {vaga_funcao}.",
    ]);

    return $template;
}

test('editor de e-mail expõe isEmail e a lista de variáveis disponíveis (CA-6)', function () {
    $template = templateEmail();

    Livewire::actingAs(adminEmail())
        ->test(TemplateEditor::class, ['slug' => $template->slug])
        ->assertSet('slug', $template->slug)
        ->assertSeeHtml('data-testid="template-editor-variaveis-email"')
        ->assertSee('{vaga_funcao}');
});

test('variável de e-mail fora da lista do slug bloqueia o salvamento', function () {
    $template = templateEmail();

    Livewire::actingAs(adminEmail())
        ->test(TemplateEditor::class, ['slug' => $template->slug])
        ->set('conteudo', "h1: Olá\n---\nTexto com {variavel_inexistente} no corpo.")
        ->call('salvar')
        ->assertSet('tentouSalvar', true)
        ->assertSee('variavel_inexistente');

    expect(TemplateVersao::where('template_id', $template->id)->count())->toBe(1);
});

test('corpo de e-mail válido cria nova versão (rascunho)', function () {
    $template = templateEmail();

    Livewire::actingAs(adminEmail())
        ->test(TemplateEditor::class, ['slug' => $template->slug])
        ->set('conteudo', "preheader: {profissional_nome} se candidatou.\nh1: Nova candidatura\ncta_label: Ver\ncta_url: {link_painel}\naviso:\n---\nScore {profissional_score}/100 para {vaga_funcao}.")
        ->call('salvar')
        ->assertRedirect(route('templates.detalhe', ['slug' => $template->slug]));

    expect(TemplateVersao::where('template_id', $template->id)->where('versao', 2)->exists())->toBeTrue();
});
