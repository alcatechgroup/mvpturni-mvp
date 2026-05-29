<?php

namespace App\Livewire;

use App\Domain\Templates\TemplateContentValidator;
use App\Domain\Templates\TemplateRenderer;
use App\Exceptions\PlaceholderInvalidoException;
use App\Models\Template;
use App\Services\TemplateService;
use Illuminate\Contracts\View\View;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Layout;
use Livewire\Component;

/**
 * STORY-020 — Editor de nova versão (CA-4/CA-5/CA-6).
 *
 * Abre com o conteúdo da versão ativa pré-carregado (edição parte do existente, não do zero).
 * Preview ao vivo (Markdown renderizado + placeholders destacados). Salvar valida: conteúdo
 * não-vazio e nenhum placeholder fora da lista canônica (bloqueia com mensagem acionável).
 * Aviso soft (não bloqueia) se faltar seção nomeada.
 */
#[Layout('components.layouts.admin')]
class TemplateEditor extends Component
{
    public string $slug;

    public string $nomeAmigavel = '';

    public int $versaoBase = 0;

    public string $conteudo = '';

    /** Vira true após a primeira tentativa de salvar — controla o banner de erro (CA-5). */
    public bool $tentouSalvar = false;

    public function mount(string $slug, TemplateService $service): void
    {
        $template = Template::where('slug', $slug)->with('versaoAtiva')->first();

        if (! $template) {
            abort(404);
        }

        $this->slug = $slug;
        $this->nomeAmigavel = $template->nome_amigavel;
        $this->versaoBase = $template->versaoAtiva?->versao ?? 0;
        // Pré-carrega o conteúdo da versão ativa (CA-4).
        $this->conteudo = $template->versaoAtiva?->conteudo ?? '';
    }

    /** @return list<string> */
    #[Computed]
    public function placeholdersInvalidos(): array
    {
        return app(TemplateContentValidator::class)->placeholdersDesconhecidos($this->conteudo);
    }

    /** @return list<string> */
    #[Computed]
    public function secoesFaltando(): array
    {
        return app(TemplateContentValidator::class)->secoesFaltando($this->conteudo);
    }

    #[Computed]
    public function vazio(): bool
    {
        return trim($this->conteudo) === '';
    }

    #[Computed]
    public function previewHtml(): string
    {
        return app(TemplateRenderer::class)->html($this->conteudo, $this->placeholdersInvalidos);
    }

    public function salvar(TemplateService $service): mixed
    {
        $this->tentouSalvar = true;

        if ($this->vazio || $this->placeholdersInvalidos !== []) {
            // Banner de erro renderiza a partir do estado computado — nada é salvo (CA-5).
            return null;
        }

        $template = Template::where('slug', $this->slug)->firstOrFail();

        try {
            $versao = $service->criarVersao($template, $this->conteudo, auth()->user());
        } catch (PlaceholderInvalidoException) {
            // Defesa em profundidade: o service revalida; mantém no editor.
            return null;
        }

        session()->flash('toast', [
            'message' => "Versão {$versao->versao} criada como rascunho. Ative quando quiser publicá-la.",
            'type' => 'success',
        ]);

        return $this->redirect(route('templates.detalhe', ['slug' => $this->slug]), navigate: true);
    }

    public function render(): View
    {
        return view('livewire.template-editor', [
            'placeholdersCanonicos' => TemplateContentValidator::CANONICOS,
        ]);
    }
}
