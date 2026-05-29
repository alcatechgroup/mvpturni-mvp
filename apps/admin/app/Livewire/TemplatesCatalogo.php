<?php

namespace App\Livewire;

use App\Models\Template;
use Illuminate\Contracts\View\View;
use Livewire\Attributes\Layout;
use Livewire\Component;

/**
 * STORY-020 — Catálogo de templates contratuais (CA-2).
 *
 * Lista os 2 templates fixos do MVP com a versão ativa, autor e data de ativação.
 * Acessível apenas a admin (middleware AdminOnly na rota — CA-1).
 */
#[Layout('components.layouts.admin')]
class TemplatesCatalogo extends Component
{
    public function render(): View
    {
        $templates = Template::query()
            ->with(['versaoAtiva.autor'])
            ->orderBy('id')
            ->get();

        return view('livewire.templates-catalogo', [
            'templates' => $templates,
        ]);
    }
}
