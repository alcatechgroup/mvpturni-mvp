<?php

// STORY-020 — camada de UI (Livewire): acesso (CA-1), catálogo (CA-2), detalhe (CA-3),
// editor + validação (CA-4/CA-5) e fluxo de ativação (CA-7/CA-8).

use App\Livewire\TemplateDetalhe;
use App\Livewire\TemplateEditor;
use App\Livewire\TemplatesCatalogo;
use App\Models\Template;
use App\Models\TemplateVersao;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;

uses(RefreshDatabase::class);

function umAdmin(): User
{
    return User::factory()->admin()->create();
}

function umTemplateComVersao(string $slug = 'pf_autonomo_eventual'): Template
{
    $template = Template::factory()->create(['slug' => $slug, 'nome_amigavel' => 'Contrato PF — Autônomo eventual']);
    TemplateVersao::factory()->for($template)->versao(1)->ativa()->create([
        'conteudo' => "## Termos gerais\n\nNome: {{profissional.nome}}\n\n## Termos do turno específico\n\nValor: {{turno.valor}}",
    ]);

    return $template;
}

// ── Acesso (CA-1) ───────────────────────────────────────────────

test('guest é redirecionado ao login (fail-secure)', function () {
    $this->get('/templates')->assertRedirect('/login');
});

test('não-admin recebe 403 fail-secure', function () {
    $this->actingAs(User::factory()->profissional()->create());
    $this->get('/templates')->assertForbidden();
});

test('admin acessa o catálogo (200)', function () {
    umTemplateComVersao();
    $this->actingAs(umAdmin());
    $this->get('/templates')->assertOk();
});

// ── Catálogo (CA-2) ─────────────────────────────────────────────

test('catálogo lista os templates com a versão ativa', function () {
    umTemplateComVersao('pf_autonomo_eventual');
    umTemplateComVersao('mei_pj_b2b');

    Livewire::actingAs(umAdmin())
        ->test(TemplatesCatalogo::class)
        ->assertSee('pf_autonomo_eventual')
        ->assertSee('mei_pj_b2b')
        ->assertSee('v1 · ativa');
});

// ── Detalhe (CA-3) ──────────────────────────────────────────────

test('detalhe renderiza a versão ativa com placeholder visível e o histórico', function () {
    $template = umTemplateComVersao();

    Livewire::actingAs(umAdmin())
        ->test(TemplateDetalhe::class, ['slug' => $template->slug])
        ->assertSee('Versão ativa')
        ->assertSee('⟦profissional.nome⟧', escape: false)
        ->assertSee('Histórico de versões');
});

test('slug desconhecido devolve 404', function () {
    $this->actingAs(umAdmin());
    $this->get('/templates/slug-inexistente')->assertNotFound();
});

// ── Editor (CA-4/CA-5/CA-6) ─────────────────────────────────────

test('editor pré-carrega o conteúdo da versão ativa', function () {
    $template = umTemplateComVersao();
    $conteudoAtivo = $template->versaoAtiva->conteudo;

    Livewire::actingAs(umAdmin())
        ->test(TemplateEditor::class, ['slug' => $template->slug])
        ->assertSet('conteudo', $conteudoAtivo)
        ->assertSet('versaoBase', 1);
});

test('salvar com placeholder inválido bloqueia e não cria versão (CA-5)', function () {
    $template = umTemplateComVersao();

    Livewire::actingAs(umAdmin())
        ->test(TemplateEditor::class, ['slug' => $template->slug])
        ->set('conteudo', 'Texto com {{contratante.razao_zocial}} inválido')
        ->call('salvar')
        ->assertSet('tentouSalvar', true)
        ->assertSee('contratante.razao_zocial');

    expect(TemplateVersao::where('template_id', $template->id)->count())->toBe(1);
});

test('salvar conteúdo válido cria nova versão (rascunho) e redireciona ao detalhe (CA-6)', function () {
    $template = umTemplateComVersao();

    Livewire::actingAs(umAdmin())
        ->test(TemplateEditor::class, ['slug' => $template->slug])
        ->set('conteudo', "## Termos gerais\n\n{{profissional.nome}}\n\n## Termos do turno específico\n\n{{turno.valor}}")
        ->call('salvar')
        ->assertRedirect(route('templates.detalhe', ['slug' => $template->slug]));

    $nova = TemplateVersao::where('template_id', $template->id)->where('versao', 2)->first();
    expect($nova)->not->toBeNull()
        ->and($nova->ativa)->toBeFalse();
});

// ── Ativação (CA-7/CA-8) ────────────────────────────────────────

test('ver completa expande e recolhe o conteúdo de uma versão do histórico', function () {
    $template = umTemplateComVersao();
    $v1 = $template->versaoAtiva;

    $comp = Livewire::actingAs(umAdmin())
        ->test(TemplateDetalhe::class, ['slug' => $template->slug])
        ->call('verCompleta', $v1->id)
        ->assertSet('expandidaId', $v1->id)
        ->call('verCompleta', $v1->id)
        ->assertSet('expandidaId', null);
});

test('ativar versão obsoleta (sumiu) devolve toast de erro e não quebra', function () {
    $template = umTemplateComVersao();

    Livewire::actingAs(umAdmin())
        ->test(TemplateDetalhe::class, ['slug' => $template->slug])
        ->call('pedirAtivacao', 999999)
        ->call('confirmarAtivacao')
        ->assertDispatched('toast', type: 'error');
});

test('fluxo de ativação: pedir confirmação e ativar a versão histórica', function () {
    $template = umTemplateComVersao();
    $v2 = TemplateVersao::factory()->for($template)->versao(2)->create();

    Livewire::actingAs(umAdmin())
        ->test(TemplateDetalhe::class, ['slug' => $template->slug])
        ->call('pedirAtivacao', $v2->id)
        ->assertSet('confirmandoAtivarId', $v2->id)
        ->call('confirmarAtivacao')
        ->assertSet('confirmandoAtivarId', null)
        ->assertDispatched('toast');

    expect($v2->fresh()->ativa)->toBeTrue()
        ->and($template->versaoAtiva->versao)->toBe(2);
});
