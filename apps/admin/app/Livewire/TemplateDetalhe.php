<?php

namespace App\Livewire;

use App\Domain\Templates\TemplateRenderer;
use App\Models\Template;
use App\Models\TemplateVersao;
use App\Services\TemplateService;
use Illuminate\Contracts\View\View;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Layout;
use Livewire\Component;

/**
 * STORY-020 — Detalhe de um template: versão ativa renderizada + histórico de versões
 * (CA-3), com criação de nova versão (link para o editor) e ativação de versão histórica
 * — incluindo "voltar para versão anterior" (CA-11) — sob confirmação dupla (CA-8).
 */
#[Layout('components.layouts.admin')]
class TemplateDetalhe extends Component
{
    public string $slug;

    /** Versão cujo conteúdo está expandido inline ("ver completa"). */
    public ?int $expandidaId = null;

    /** Versão pendente de confirmação de ativação (abre o diálogo). */
    public ?int $confirmandoAtivarId = null;

    public function mount(string $slug): void
    {
        // 404 fail-secure para slug fora do catálogo fixo.
        if (! Template::where('slug', $slug)->exists()) {
            abort(404);
        }

        $this->slug = $slug;
    }

    #[Computed]
    public function template(): Template
    {
        return Template::query()
            ->where('slug', $this->slug)
            ->with(['versoes.autor'])
            ->firstOrFail();
    }

    public function verCompleta(int $versaoId): void
    {
        $this->expandidaId = $this->expandidaId === $versaoId ? null : $versaoId;
    }

    public function pedirAtivacao(int $versaoId): void
    {
        $this->confirmandoAtivarId = $versaoId;
    }

    public function cancelarAtivacao(): void
    {
        $this->confirmandoAtivarId = null;
    }

    public function confirmarAtivacao(TemplateService $service): void
    {
        $versao = $this->confirmandoAtivarId
            ? TemplateVersao::with('template')->find($this->confirmandoAtivarId)
            : null;

        $this->confirmandoAtivarId = null;

        // Versão não pertence a este template, sumiu, ou já é a ativa → estado obsoleto.
        if (! $versao || $versao->template->slug !== $this->slug) {
            $this->dispatch('toast', message: 'Não foi possível concluir a ação. Tente novamente.', type: 'error');

            return;
        }

        $numero = $versao->versao;
        $service->ativar($versao, auth()->user());
        unset($this->template);

        $this->dispatch('toast', message: "Versão {$numero} ativada. Novos cadastros passam a usar esta versão.", type: 'success');
    }

    public function render(TemplateRenderer $renderer): View
    {
        $template = $this->template;
        $ativa = $template->versoes->firstWhere('ativa', true);

        return view('livewire.template-detalhe', [
            'template' => $template,
            'ativa' => $ativa,
            'ativaHtml' => $ativa ? $renderer->html($ativa->conteudo) : null,
            'renderer' => $renderer,
        ]);
    }
}
