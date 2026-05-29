@php
    use Illuminate\Support\Facades\Storage;

    // Buckets de SLA (CA-10): ≤12h verde · 12–20h amarelo · >20h vermelho. Ícone + cor + texto.
    $slaDe = function ($createdAt) {
        $h = (int) $createdAt->diffInHours(now());
        if ($h > 20) return ['class' => 'sla-late', 'label' => "há {$h}h", 'aria' => "há {$h} horas — risco de SLA"];
        if ($h >= 12) return ['class' => 'sla-warn', 'label' => "há {$h}h", 'aria' => "há {$h} horas"];
        return ['class' => 'sla-ok', 'label' => "há {$h}h", 'aria' => "há {$h} horas"];
    };
    $c = $this->contadores;
@endphp

<div data-testid="screen-aprovacoes"
     x-data="{ toast: null, type: 'success', t: null,
               show(m, ty){ this.toast = m; this.type = ty; clearTimeout(this.t); this.t = setTimeout(() => this.toast = null, 3500); } }"
     x-on:toast.window="show($event.detail.message, $event.detail.type)">

    <div class="narrow-warn">Backoffice é desktop-first (≥1024px). Alargue a janela para ver o shell completo.</div>

    <div class="crumb">Backoffice · Admin</div>
    <h1 class="main-h">Cadastros pendentes</h1>
    <p class="main-d" data-testid="aprovacoes-subtitle">
        {{ $cadastros->total() }} {{ $cadastros->total() === 1 ? 'cadastro' : 'cadastros' }}
        {{ ($papel !== 'todos' || $tipoPessoa) ? 'no filtro atual' : 'aguardando análise' }} · SLA público de 24h
    </p>

    {{-- Contadores agregados do backlog global (CA-8) --}}
    <div class="stats">
        <div class="stat" data-testid="aprovacoes-count-pendentes">
            <div class="k">Pendentes</div>
            <div class="v">{{ $c['total'] }}</div>
        </div>
        <div class="stat" data-testid="aprovacoes-count-profissionais">
            <div class="k">Profissionais</div>
            <div class="v">{{ $c['profissionais'] }}</div>
            <div class="sub">PF {{ $c['pf'] }} · MEI {{ $c['mei'] }} · PJ {{ $c['pj'] }}</div>
        </div>
        <div class="stat" data-testid="aprovacoes-count-contratantes">
            <div class="k">Contratantes</div>
            <div class="v">{{ $c['contratantes'] }}</div>
        </div>
    </div>

    @if ($this->emRiscoSla > 0)
        <div class="feedback" data-testid="aprovacoes-sla-banner" role="status">
            <span class="ic" aria-hidden="true">!</span>
            {{ $this->emRiscoSla }} {{ $this->emRiscoSla === 1 ? 'cadastro está' : 'cadastros estão' }} há mais de 20h na fila — priorize para não estourar o SLA.
        </div>
    @endif

    {{-- Filtros (CA-3) — persistem em querystring via #[Url] --}}
    <div class="filters" data-testid="aprovacoes-filter-papel">
        <div class="seg" role="group" aria-label="Filtrar por papel">
            <button type="button" wire:click="$set('papel','todos')" @class(['on' => $papel === 'todos']) data-testid="aprovacoes-filter-papel-todos">Todos</button>
            <button type="button" wire:click="$set('papel','profissional')" @class(['on' => $papel === 'profissional']) data-testid="aprovacoes-filter-papel-profissional">Profissional</button>
            <button type="button" wire:click="$set('papel','contratante')" @class(['on' => $papel === 'contratante']) data-testid="aprovacoes-filter-papel-contratante">Contratante</button>
        </div>
        @if ($papel === 'profissional')
            <span class="flabel">Tipo</span>
            <div class="seg" role="group" aria-label="Filtrar por tipo de pessoa">
                <button type="button" wire:click="filtrarTipo('PF')" @class(['on' => $tipoPessoa === 'PF']) data-testid="aprovacoes-filter-tipo-pf">PF</button>
                <button type="button" wire:click="filtrarTipo('MEI')" @class(['on' => $tipoPessoa === 'MEI']) data-testid="aprovacoes-filter-tipo-mei">MEI</button>
                <button type="button" wire:click="filtrarTipo('PJ')" @class(['on' => $tipoPessoa === 'PJ']) data-testid="aprovacoes-filter-tipo-pj">PJ</button>
            </div>
        @endif
    </div>

    <div class="panel">
        <div class="panel-h">
            <h3>Fila de análise</h3>
            <span class="res">{{ $cadastros->total() }} {{ $cadastros->total() === 1 ? 'resultado' : 'resultados' }}</span>
        </div>

        {{-- Skeleton durante navegação/filtro (CA — loading) --}}
        <div wire:loading.delay.flex style="display:none;padding:8px 0;flex-direction:column">
            @for ($i = 0; $i < 3; $i++)
                <div style="display:flex;gap:12px;align-items:center;padding:12px 20px">
                    <span class="sk" style="width:40px;height:40px;border-radius:999px"></span>
                    <div style="flex:1"><div class="sk" style="width:200px"></div><div class="sk" style="width:90px;margin-top:8px"></div></div>
                </div>
            @endfor
        </div>

        <div wire:loading.remove>
            @if ($cadastros->isEmpty())
                @if ($papel !== 'todos' || $tipoPessoa)
                    <div class="empty" data-testid="aprovacoes-empty-filter">
                        <div class="mark neutral" aria-hidden="true">∅</div>
                        <h4>Nenhum cadastro deste tipo na fila</h4>
                        <p>Ajuste os filtros para ver outros.</p>
                        <button type="button" class="btn btn-outline" wire:click="limparFiltros">Limpar filtros</button>
                    </div>
                @else
                    <div class="empty" data-testid="aprovacoes-empty">
                        <div class="mark" aria-hidden="true">✓</div>
                        <h4>Fila zerada — nada para analisar</h4>
                        <p>Novos cadastros aparecem aqui assim que profissionais e contratantes se pré-cadastrarem.</p>
                    </div>
                @endif
            @else
                <table aria-live="polite" data-testid="aprovacoes-list">
                    <thead><tr><th>Cadastro</th><th>Papel</th><th>Enviado</th><th class="right"><span class="sr-only">Ações</span></th></tr></thead>
                    <tbody>
                        @foreach ($cadastros as $u)
                            @php
                                $isProf = $u->role === 'profissional';
                                $prof = $u->profissionalProfile;
                                $contr = $u->contratanteProfile;
                                $sub = $isProf
                                    ? trim(($prof?->tipo_pessoa ?? '') . ($prof?->funcao?->nome ? ' · ' . $prof->funcao->nome : ''))
                                    : ($contr?->tipo_operacao ?? '');
                                $sla = $slaDe($u->created_at);
                                $foto = $isProf ? $prof?->foto_path : $contr?->foto_path;
                            @endphp
                            <tr wire:key="item-{{ $u->id }}" data-testid="aprovacoes-item-{{ $u->id }}">
                                <td>
                                    <div class="cell-id">
                                        <span class="av" aria-hidden="true">
                                            @if ($foto)
                                                <img src="{{ Storage::url($foto) }}" alt="" onerror="this.replaceWith(document.createTextNode('{{ mb_strtoupper(mb_substr($u->name,0,1)) }}'))">
                                            @else
                                                {{ mb_strtoupper(mb_substr($u->name, 0, 1)) }}
                                            @endif
                                        </span>
                                        <div>
                                            <div class="cell-name">{{ $u->name }}</div>
                                            @if ($sub)<div class="cell-sub">{{ $sub }}</div>@endif
                                        </div>
                                    </div>
                                </td>
                                <td>{{ $isProf ? 'Profissional' : 'Contratante' }}</td>
                                <td>
                                    <span class="chip {{ $sla['class'] }}" data-testid="aprovacoes-item-{{ $u->id }}-sla" aria-label="{{ $sla['aria'] }}">
                                        <span class="ic" aria-hidden="true"></span> {{ $sla['label'] }}
                                    </span>
                                </td>
                                <td class="right">
                                    <button type="button" class="btn btn-outline" wire:click="verDetalhes({{ $u->id }})" data-testid="aprovacoes-item-{{ $u->id }}-ver">
                                        Ver detalhes
                                    </button>
                                </td>
                            </tr>
                        @endforeach
                    </tbody>
                </table>
            @endif
        </div>
    </div>

    @if ($cadastros->hasPages())
        <div class="pager">{{ $cadastros->links() }}</div>
    @endif

    {{-- Drawer de detalhe (CA-4) --}}
    @if ($this->selecionado)
        @php
            $u = $this->selecionado;
            $isProf = $u->role === 'profissional';
            $prof = $u->profissionalProfile;
            $contr = $u->contratanteProfile;
            $tipoPessoaDet = $isProf ? $prof?->tipo_pessoa : null;
            $foto = $isProf ? $prof?->foto_path : $contr?->foto_path;
            $sla = $slaDe($u->created_at);
            // Template contratual aplicável (CA-4) — placeholder de leitura; modelo TemplateVersao é STORY-020.
            $templateLabel = ($tipoPessoaDet === 'PF') ? 'PF autônomo eventual · v1 (ativo)' : 'MEI/PJ B2B · v1 (ativo)';
            $templateLink = ($tipoPessoaDet === 'PF')
                ? 'docs/especificacao/contratos/template-pf-autonomo-eventual-v1.md'
                : 'docs/especificacao/contratos/template-mei-pj-b2b-v1.md';
        @endphp
        <div x-data="{ confirm: null }" @keydown.escape.window="$wire.fecharDetalhe()">
            <div class="scrim" wire:click="fecharDetalhe"></div>
            <aside class="drawer" role="dialog" aria-modal="true" aria-label="Detalhe do cadastro" data-testid="aprovacoes-detail">
                <div class="dw-h">
                    <h3>Detalhe do cadastro</h3>
                    <button type="button" class="dw-close" wire:click="fecharDetalhe" aria-label="Fechar detalhe" data-testid="aprovacoes-detail-close">✕</button>
                </div>
                <div class="dw-body">
                    <div class="dw-id">
                        <span class="av" aria-hidden="true">
                            @if ($foto)
                                <img src="{{ Storage::url($foto) }}" alt="Foto de {{ $u->name }}" onerror="this.replaceWith(document.createTextNode('{{ mb_strtoupper(mb_substr($u->name,0,1)) }}'))">
                            @else
                                {{ mb_strtoupper(mb_substr($u->name, 0, 1)) }}
                            @endif
                        </span>
                        <div>
                            <div class="nm">{{ $u->name }}</div>
                            <div class="ro">{{ $isProf ? 'Profissional' : 'Contratante' }}{{ $tipoPessoaDet ? ' · ' . $tipoPessoaDet : '' }}</div>
                            <div style="margin-top:6px">
                                <span class="chip {{ $sla['class'] }}"><span class="ic" aria-hidden="true"></span> {{ str_replace('há', 'há', $sla['label']) }} na fila</span>
                            </div>
                        </div>
                    </div>
                    <dl class="kv">
                        <dt>E-mail</dt><dd>{{ $u->email }}</dd>
                        @if ($isProf)
                            <dt>Telefone</dt><dd>{{ $prof?->telefone ?? '—' }}</dd>
                            <dt>Cidade</dt><dd>{{ $prof?->cidade ?? '—' }}</dd>
                            <dt>Bairro</dt><dd>{{ $prof?->bairro ?? '—' }}</dd>
                            <dt>Função</dt><dd>{{ $prof?->funcao?->nome ?? '—' }}</dd>
                        @else
                            <dt>Telefone</dt><dd>{{ $contr?->telefone ?? '—' }}</dd>
                            <dt>Cidade</dt><dd>{{ $contr?->cidade ?? '—' }}</dd>
                            <dt>Estabelecimento</dt><dd>{{ $contr?->nome_estabelecimento ?? '—' }}</dd>
                            <dt>Tipo de operação</dt><dd>{{ $contr?->tipo_operacao ?? '—' }}</dd>
                        @endif
                        <dt>Termos</dt>
                        <dd>
                            @php $termos = $isProf ? $prof?->termos_aceitos_at : $contr?->termos_aceitos_at; @endphp
                            {{ $termos ? 'aceitos em ' . $termos->format('d/m/Y H:i') : '—' }}
                        </dd>
                        <dt>Contrato aplicável</dt>
                        <dd><a href="/{{ $templateLink }}" target="_blank" rel="noopener">{{ $templateLabel }} ↗</a></dd>
                    </dl>
                </div>
                <div class="dw-foot">
                    <button type="button" class="btn btn-success btn-block" x-on:click="confirm = 'aprovar'" data-testid="aprovacoes-detail-aprovar">Aprovar cadastro</button>
                    <button type="button" class="btn btn-danger btn-block" x-on:click="confirm = 'remover'" data-testid="aprovacoes-detail-remover">Remover</button>
                </div>
            </aside>

            {{-- Diálogo aprovar --}}
            <template x-if="confirm === 'aprovar'">
                <div class="dlg-scrim" role="alertdialog" aria-modal="true" aria-label="Confirmar aprovação" x-on:keydown.escape.window="confirm = null">
                    <div class="dlg">
                        <h4>Confirmar aprovação?</h4>
                        <p>{{ $u->name }} poderá acessar o Turni e completar o cadastro. Um e-mail de aprovação será enviado.</p>
                        <div class="dlg-actions">
                            <button type="button" class="btn btn-ghost" x-on:click="confirm = null" data-testid="dialog-aprovar-cancel" x-init="$el.focus()">Cancelar</button>
                            <button type="button" class="btn btn-solid-success" wire:click="aprovar" x-on:click="confirm = null" data-testid="dialog-aprovar-confirm">Aprovar</button>
                        </div>
                    </div>
                </div>
            </template>

            {{-- Diálogo remover (confirmação dupla — CA-8) --}}
            <template x-if="confirm === 'remover'">
                <div class="dlg-scrim" role="alertdialog" aria-modal="true" aria-label="Confirmar remoção" x-on:keydown.escape.window="confirm = null">
                    <div class="dlg">
                        <h4>Remover este cadastro?</h4>
                        <p>Esta ação não pode ser desfeita. O cadastro de {{ $u->name }} será removido da plataforma e não receberá aviso.</p>
                        <div class="dlg-actions">
                            <button type="button" class="btn btn-ghost" x-on:click="confirm = null" data-testid="dialog-remover-cancel" x-init="$el.focus()">Cancelar</button>
                            <button type="button" class="btn btn-solid-danger" wire:click="remover" x-on:click="confirm = null" data-testid="dialog-remover-confirm">Remover definitivamente</button>
                        </div>
                    </div>
                </div>
            </template>
        </div>
    @endif

    {{-- Toast (CA-5/CA-6/CA-8) --}}
    <div class="toast" x-cloak x-show="toast" :class="{ 'err': type === 'error' }" data-testid="aprovacoes-toast" role="status" aria-live="polite" x-transition>
        <span class="dot"></span><span x-text="toast"></span>
    </div>
</div>
