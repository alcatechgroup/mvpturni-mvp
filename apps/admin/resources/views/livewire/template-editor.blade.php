<div data-testid="template-editor" x-data="{ placeholders: false }">
    <div class="narrow-warn">Backoffice é desktop-first (≥1024px). Alargue a janela para ver o shell completo.</div>

    <div class="crumb">Backoffice · Templates · Nova versão</div>
    <h1 class="main-h" style="margin-top:6px">Nova versão de "{{ $nomeAmigavel }}"</h1>
    <p class="main-d">Partindo da v{{ $versaoBase }} (ativa). Salvar cria a v{{ $versaoBase + 1 }} como rascunho.</p>

    {{-- Erro de validação: placeholder fora da lista canônica (CA-5) ou conteúdo vazio --}}
    @if ($tentouSalvar && ($this->vazio || count($this->placeholdersInvalidos)))
        <div class="banner err" data-testid="template-editor-erro" role="alert">
            <span class="ic" aria-hidden="true">!</span>
            <div>
                @if ($this->vazio)
                    O conteúdo não pode ficar vazio.
                @else
                    @php $inval = implode(', ', array_map(fn ($p) => '{{'.$p.'}}', $this->placeholdersInvalidos)); @endphp
                    O placeholder <span class="mono">{{ $inval }}</span> não existe. Use apenas os placeholders da lista (contratante.*, profissional.*, turno.*, aceite.*, habitualidade.*).
                @endif
            </div>
        </div>
    @endif

    {{-- Aviso soft: seção nomeada ausente (não bloqueia o salvamento) --}}
    @if (count($this->secoesFaltando))
        <div class="banner warn" data-testid="template-editor-aviso" role="status">
            <span class="ic" aria-hidden="true">!</span>
            <div>Aviso: não encontrei a seção "{{ implode('", "', $this->secoesFaltando) }}". Confira a estrutura antes de ativar.</div>
        </div>
    @endif

    <div class="editor-grid">
        <div class="pane">
            <div class="pane-h">Editor (Markdown)</div>
            <textarea data-testid="template-editor-textarea" wire:model.live.debounce.300ms="conteudo" spellcheck="false" aria-label="Editor do conteúdo do contrato em Markdown"></textarea>
        </div>
        <div class="pane">
            <div class="pane-h">Pré-visualização</div>
            <div class="preview doc" data-testid="template-editor-preview" aria-live="polite" aria-label="Pré-visualização do contrato">{!! $this->previewHtml !!}</div>
        </div>
    </div>

    <div class="help">
        <span class="ic" aria-hidden="true">ⓘ</span>
        <div>
            Use Markdown. Placeholders no formato <span class="mono">@{{namespace.campo}}</span>.<br>
            Disponíveis: contratante.* · profissional.* · turno.* · aceite.* · habitualidade.* —
            <a href="#" data-testid="template-editor-placeholders-link" x-on:click.prevent="placeholders = true">ver lista completa</a>
        </div>
    </div>

    <div class="editor-foot">
        <a class="btn btn-ghost" href="{{ route('templates.detalhe', ['slug' => $slug]) }}" wire:navigate data-testid="template-editor-cancelar">Cancelar</a>
        <button type="button" class="btn btn-success" wire:click="salvar" wire:loading.attr="disabled" @disabled($this->vazio) data-testid="template-editor-salvar">
            <span wire:loading.remove wire:target="salvar">Salvar nova versão</span>
            <span wire:loading wire:target="salvar">Salvando…</span>
        </button>
    </div>

    {{-- Diálogo: lista completa de placeholders canônicos --}}
    <div class="dlg-scrim" x-cloak x-show="placeholders" data-testid="template-editor-placeholders-dialog" role="dialog" aria-modal="true" aria-label="Placeholders disponíveis" x-on:keydown.escape.window="placeholders = false" x-on:click.self="placeholders = false">
        <div class="dlg" style="max-width:520px">
            <h4>Placeholders disponíveis</h4>
            <p>Use exatamente estes. Qualquer outro bloqueia o salvamento.</p>
            <ul class="ph-list">
                @foreach ($placeholdersCanonicos as $p)
                    <li>{!! '{{'.e($p).'}}' !!}</li>
                @endforeach
            </ul>
            <div class="dlg-actions" style="margin-top:18px">
                <button type="button" class="btn btn-ghost" x-on:click="placeholders = false" x-init="$el.focus()">Fechar</button>
            </div>
        </div>
    </div>
</div>
