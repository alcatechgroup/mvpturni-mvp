<div data-testid="template-detalhe"
     x-data="{ toast: null, type: 'success', t: null,
               show(m, ty){ this.toast = m; this.type = ty; clearTimeout(this.t); this.t = setTimeout(() => this.toast = null, 3500); } }"
     x-on:toast.window="show($event.detail.message, $event.detail.type)">

    <div class="narrow-warn">Backoffice é desktop-first (≥1024px). Alargue a janela para ver o shell completo.</div>

    <div class="crumb">Backoffice · Admin · Templates</div>
    <a class="back" href="{{ route('templates.catalogo') }}" wire:navigate data-testid="template-detalhe-voltar">‹ Voltar ao catálogo</a>

    <div class="head-row">
        <div>
            <h1 class="main-h">{{ $template->nome_amigavel }}</h1>
            <p class="main-d" style="margin-bottom:0">{{ $template->slug }} · ativa: {{ $ativa ? 'v'.$ativa->versao : '—' }}</p>
        </div>
        <a class="btn btn-primary" href="{{ route('templates.editor', ['slug' => $template->slug]) }}" wire:navigate data-testid="template-detalhe-criar-versao">Criar nova versão</a>
    </div>

    {{-- Versão ativa renderizada (CA-3) — placeholders permanecem visíveis como chips --}}
    <div class="panel" data-testid="template-detalhe-ativa" style="margin-bottom:18px">
        <div class="panel-h">
            <h3>Versão ativa{{ $ativa ? ' (v'.$ativa->versao.')' : '' }}</h3>
            @if ($ativa)<span class="chip active"><span class="ic" aria-hidden="true"></span> ativa</span>@endif
        </div>
        @if ($ativa)
            <div class="doc" aria-label="Conteúdo da versão ativa">{!! $ativaHtml !!}</div>
        @else
            <div class="empty"><div class="mark neutral" aria-hidden="true">∅</div><h4>Sem versão ativa</h4><p>Rode o seed (php artisan db:seed) ou crie e ative uma versão.</p></div>
        @endif
    </div>

    {{-- Histórico de versões (desc — CA-3) --}}
    <div class="panel" data-testid="template-detalhe-historico">
        <div class="panel-h"><h3>Histórico de versões</h3></div>
        @foreach ($template->versoes as $versao)
            <div class="hist-row" wire:key="versao-{{ $versao->id }}" data-testid="template-versao-{{ $versao->versao }}">
                @if ($versao->ativa)
                    <span class="chip active" data-testid="template-versao-{{ $versao->versao }}-status"><span class="ic" aria-hidden="true"></span> v{{ $versao->versao }} · ativa</span>
                @else
                    <span class="chip hist" data-testid="template-versao-{{ $versao->versao }}-status"><span class="ic" aria-hidden="true"></span> v{{ $versao->versao }} · histórica</span>
                @endif
                <div class="hist-meta"><span class="v">{{ $versao->created_at->format('d/m/Y H:i') }}</span> · {{ $versao->autor?->name ?? '—' }}</div>

                <button type="button" class="btn btn-ghost" wire:click="verCompleta({{ $versao->id }})" data-testid="template-versao-{{ $versao->versao }}-ver">
                    {{ $expandidaId === $versao->id ? 'Recolher' : 'Ver completa' }}
                </button>

                @unless ($versao->ativa)
                    <button type="button" class="btn btn-outline" wire:click="pedirAtivacao({{ $versao->id }})" data-testid="template-versao-{{ $versao->versao }}-ativar">Ativar esta versão</button>
                @endunless

                @if ($expandidaId === $versao->id)
                    <div class="hist-doc"><div class="doc">{!! $renderer->html($versao->conteudo) !!}</div></div>
                @endif
            </div>
        @endforeach
    </div>

    {{-- Diálogo de ativação — confirmação dupla que explica que aceites passados NÃO mudam (CA-8) --}}
    @if ($confirmandoAtivarId)
        @php $alvo = $template->versoes->firstWhere('id', $confirmandoAtivarId); @endphp
        @if ($alvo)
            <div class="dlg-scrim" role="alertdialog" aria-modal="true" aria-label="Confirmar ativação" x-on:keydown.escape.window="$wire.cancelarAtivacao()">
                <div class="dlg">
                    <h4>Ativar a versão {{ $alvo->versao }}?</h4>
                    <p>A partir de agora, novos cadastros aprovados usarão a versão {{ $alvo->versao }} deste contrato. Os aceites já assinados continuam apontando para a versão que estava ativa quando foram firmados — eles não mudam.</p>
                    <div class="dlg-actions">
                        <button type="button" class="btn btn-ghost" wire:click="cancelarAtivacao" data-testid="dialog-ativar-cancel" x-init="$el.focus()">Cancelar</button>
                        <button type="button" class="btn btn-primary" wire:click="confirmarAtivacao" data-testid="dialog-ativar-confirm">Ativar</button>
                    </div>
                </div>
            </div>
        @endif
    @endif

    {{-- Toast (incl. flash de redirect vindo do editor) --}}
    <div class="toast" x-cloak x-show="toast" :class="{ 'err': type === 'error' }" data-testid="templates-toast" role="status" aria-live="polite" x-transition>
        <span class="dot"></span><span x-text="toast"></span>
    </div>
    @if (session('toast'))
        <div x-init="show(@js(session('toast')['message']), @js(session('toast')['type']))"></div>
    @endif
</div>
