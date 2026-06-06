{{-- STORY-065 (CA-5, CA-8) — fila de falhas (SCREEN-065 §B). Microcopy = spec §5.
     STORY-066 (CA-4, SCREEN-066 §B) generalizou para "Falhas de pagamento": casos de
     liberação de pré-autorização entram na MESMA fila, distinguidos por `tipo`
     (rename validado pelo PO 2026-06-06; rota e testids preservados). --}}

<div data-testid="screen-pix-falhas"
     x-data="{ toast: null, type: 'success', t: null,
               show(m, ty){ this.toast = m; this.type = ty; clearTimeout(this.t); this.t = setTimeout(() => this.toast = null, 3500); },
               copiar(chave, el){ navigator.clipboard?.writeText(chave).then(() => { el.dataset.ok = '1'; el.textContent = 'Copiada'; setTimeout(() => { delete el.dataset.ok; el.textContent = '⧉ Copiar'; }, 2000); }); } }"
     x-on:toast.window="show($event.detail.message, $event.detail.type)">

    <div class="narrow-warn">Backoffice é desktop-first (≥1024px). Alargue a janela para ver o shell completo.</div>

    <div class="crumb">Backoffice · Admin</div>
    <h1 class="main-h">Falhas de pagamento</h1>
    <p class="main-d" data-testid="pixfalhas-subtitle">
        @if ($this->pendentesCount > 0)
            {{ $this->pendentesCount }} {{ $this->pendentesCount === 1 ? 'caso aguardando' : 'casos aguardando' }} tratamento manual
        @else
            Nenhum caso aguardando tratamento
        @endif
    </p>

    {{-- Abas pendentes/resolvidos (CA-8) --}}
    <div class="seg" role="tablist" aria-label="Filtro de casos">
        <button type="button" wire:click="$set('aba','pendentes')" @class(['on' => $aba !== 'resolvidos'])
                role="tab" aria-selected="{{ $aba !== 'resolvidos' ? 'true' : 'false' }}"
                data-testid="pixfalhas-tab-pendentes">Pendentes ({{ $this->pendentesCount }})</button>
        <button type="button" wire:click="$set('aba','resolvidos')" @class(['on' => $aba === 'resolvidos'])
                role="tab" aria-selected="{{ $aba === 'resolvidos' ? 'true' : 'false' }}"
                data-testid="pixfalhas-tab-resolvidos">Resolvidos</button>
    </div>

    <div class="panel" style="margin-top:16px">
        <div class="panel-h">
            <h3>{{ $aba === 'resolvidos' ? 'Casos resolvidos' : 'Fila de tratamento manual' }}</h3>
        </div>

        @if ($casos->isEmpty())
            @if ($aba === 'resolvidos')
                <div class="empty" data-testid="pixfalhas-empty-resolvidos">
                    <div class="mark" style="background:var(--sunken);color:var(--text-subtle)">·</div>
                    <h4>Nenhum caso resolvido ainda</h4>
                    <p>Casos tratados manualmente ficam registrados aqui.</p>
                </div>
            @else
                <div class="empty" data-testid="pixfalhas-empty">
                    <div class="mark">✓</div>
                    <h4>Nenhuma falha de pagamento</h4>
                    <p>Falhas de transferência e de liberação aparecem aqui assim que o gateway reportar. Por enquanto, tudo certo.</p>
                </div>
            @endif
        @else
            <table data-testid="pixfalhas-list" aria-live="polite">
                <thead>
                    <tr>
                        <th>Turno</th>
                        <th>Valor</th>
                        <th>Chave Pix</th>
                        <th>Razão</th>
                        <th>Falhou em</th>
                        <th>{{ $aba === 'resolvidos' ? 'Resolução' : '' }}</th>
                    </tr>
                </thead>
                <tbody>
                    @foreach ($casos as $caso)
                        <tr data-testid="pixfalhas-item-{{ $caso->turno_id }}" wire:key="caso-{{ $caso->id }}">
                            <td>
                                @if ($aba === 'resolvidos')
                                    <span class="chip sla-ok" data-testid="pixfalhas-item-{{ $caso->turno_id }}-badge" style="margin-bottom:7px">
                                        <span class="ic" aria-hidden="true"></span>Resolvido manualmente
                                    </span>
                                @else
                                    {{-- Badge vermelho + microcopy fixados pelo CA-5/066 (por tipo) --}}
                                    <span class="chip sla-late" data-testid="pixfalhas-item-{{ $caso->turno_id }}-badge" style="margin-bottom:7px">
                                        <span class="ic" aria-hidden="true"></span>{{ $caso->tipo === 'liberacao' ? 'Liberação falhou — tratamento manual' : 'Pix falhou — tratamento manual' }}
                                    </span>
                                @endif
                                <div class="cell-name">{{ $caso->funcao ?? 'Turno' }}{{ $caso->estabelecimento ? ' · '.$caso->estabelecimento : '' }}</div>
                                <div class="cell-sub">{{ $caso->profissional_nome ?? '—' }}</div>
                            </td>
                            <td style="font-family:var(--m);font-weight:600;white-space:nowrap" data-testid="pixfalhas-item-{{ $caso->turno_id }}-valor">
                                {{ $caso->valor !== null ? 'R$ '.number_format((float) $caso->valor, 2, ',', '.') : '—' }}
                            </td>
                            <td>
                                @if ($caso->tipo === 'liberacao')
                                    {{-- Liberação não tem chave Pix — o tratamento é no gateway (SCREEN-066 §B.2) --}}
                                    <span data-testid="pixfalhas-item-{{ $caso->turno_id }}-chave">—</span>
                                @elseif ($caso->chave_pix)
                                    <span style="font-family:var(--m);font-size:12.5px;white-space:nowrap;display:inline-flex;align-items:center;gap:8px"
                                          data-testid="pixfalhas-item-{{ $caso->turno_id }}-chave">
                                        {{ $caso->chave_pix }}
                                        @if ($aba !== 'resolvidos')
                                            <button type="button" class="btn btn-outline" style="padding:3px 8px;font-size:11px"
                                                    aria-label="Copiar chave Pix de {{ $caso->profissional_nome }}"
                                                    data-testid="pixfalhas-item-{{ $caso->turno_id }}-copiar"
                                                    x-on:click="copiar(@js($caso->chave_pix), $el)">⧉ Copiar</button>
                                        @endif
                                    </span>
                                @else
                                    <span class="cell-sub">chave não cadastrada no perfil</span>
                                @endif
                            </td>
                            <td style="font-family:var(--m);font-size:12px;color:var(--text-subtle);max-width:260px"
                                data-testid="pixfalhas-item-{{ $caso->turno_id }}-razao">{{ $caso->razao }}</td>
                            <td style="font-size:13px;color:var(--text-muted);white-space:nowrap">
                                {{ $caso->falhou_em->timezone(config('app.timezone'))->format('d/m · H:i') }}
                            </td>
                            <td class="right">
                                @if ($aba === 'resolvidos')
                                    <div style="font-size:13px;max-width:280px;text-align:left">
                                        {{ $caso->nota_resolucao }}
                                        <div class="cell-sub">por {{ $caso->resolvidoPor?->name ?? '—' }} · {{ $caso->resolvido_em?->format('d/m H:i') }}</div>
                                    </div>
                                @else
                                    <button type="button" class="btn btn-outline" wire:click="abrirResolucao('{{ $caso->id }}')"
                                            data-testid="pixfalhas-item-{{ $caso->turno_id }}-resolver">Resolver</button>
                                @endif
                            </td>
                        </tr>
                    @endforeach
                </tbody>
            </table>
        @endif
    </div>

    @if ($casos->hasPages())
        <div class="pager">{{ $casos->links() }}</div>
    @endif

    {{-- Dialog de resolução (SCREEN-065 §B.4) — nota OBRIGATÓRIA --}}
    @if ($this->casoEmResolucao)
        @php($caso = $this->casoEmResolucao)
        <div class="dlg-scrim" style="display:flex" role="alertdialog" aria-modal="true"
             aria-labelledby="pixfalhas-dlg-titulo" data-testid="pixfalhas-dialog"
             x-on:keydown.escape.window="$wire.fecharResolucao()">
            <div class="dlg">
                <h4 id="pixfalhas-dlg-titulo">Marcar como resolvido manualmente?</h4>
                <p>Confirme apenas depois de tratar a transferência fora da plataforma. O caso sai da fila e fica registrado no histórico de auditoria.</p>
                <div style="background:var(--sunken);border:1px solid var(--border);border-radius:12px;padding:10px 14px;font-size:13.5px;margin-bottom:14px">
                    {{ $caso->funcao }}{{ $caso->estabelecimento ? ' · '.$caso->estabelecimento : '' }} — R$ {{ number_format((float) $caso->valor, 2, ',', '.') }}
                    @if ($caso->tipo === 'liberacao')
                        <div class="cell-sub" style="font-family:var(--m)">{{ $caso->profissional_nome }} · liberação de pré-autorização</div>
                    @else
                        <div class="cell-sub" style="font-family:var(--m)">{{ $caso->profissional_nome }}{{ $caso->chave_pix ? ' · '.$caso->chave_pix : '' }}</div>
                    @endif
                </div>
                <label for="pixfalhas-nota" style="display:block;font-size:13px;font-weight:600;margin-bottom:6px">O que foi feito (obrigatório)</label>
                <textarea id="pixfalhas-nota" wire:model="nota" maxlength="500" rows="3"
                          placeholder="Ex.: Pix manual feito pela conta Turni em 06/06 às 14:20"
                          aria-describedby="pixfalhas-nota-erro" data-testid="pixfalhas-dialog-nota"
                          style="width:100%;border:1px solid var(--border-strong);border-radius:12px;padding:10px 12px;font-family:var(--b);font-size:14px;background:var(--surface);color:var(--text);resize:vertical"></textarea>
                @error('nota')
                    <div id="pixfalhas-nota-erro" data-testid="pixfalhas-dialog-nota-erro"
                         style="color:var(--error);font-size:12.5px;margin-top:6px">{{ $message }}</div>
                @enderror
                <div class="dlg-actions" style="display:flex;gap:10px;justify-content:flex-end;margin-top:18px">
                    <button type="button" class="btn btn-ghost" wire:click="fecharResolucao"
                            data-testid="pixfalhas-dialog-cancelar" x-init="$el.focus()">Cancelar</button>
                    <button type="button" class="btn btn-primary" wire:click="confirmarResolucao"
                            data-testid="pixfalhas-dialog-confirmar">Confirmar resolução</button>
                </div>
            </div>
        </div>
    @endif

    <div class="toast" x-cloak x-show="toast" :class="{ 'err': type === 'error' }"
         data-testid="pixfalhas-toast" role="status" aria-live="polite" x-transition>
        <span class="dot"></span><span x-text="toast"></span>
    </div>
</div>
