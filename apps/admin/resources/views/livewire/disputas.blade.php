{{-- STORY-096 / ADR-020 / DDR-005 — fila de disputas + caso (drawer) + resolver "pagar integral".
     Fila DERIVADA do estado em_disputa (sem tabela). Caso = agregação de leitura (justificativa +
     trilha de audit_logs + geofencing/cronômetro/vaga). Resolução = comando da api (IDR-032), nota
     OBRIGATÓRIA (DDR-005 Decisão 3). Microcopy e testids = protótipo SCREEN-STORY-091-disputa. --}}

@php
    $fmtMoeda = fn ($v) => 'R$ '.number_format((float) $v, 2, ',', '.');
    $slaIcone = ['ok' => '🟢', 'warn' => '🟡', 'late' => '🔴'];
@endphp

<div data-testid="screen-disputas"
     x-data="{ toast: null, type: 'success', t: null,
               show(m, ty){ this.toast = m; this.type = ty; clearTimeout(this.t); this.t = setTimeout(() => this.toast = null, 3500); } }"
     x-on:toast.window="show($event.detail.message, $event.detail.type)">

    <div class="narrow-warn">Backoffice é desktop-first (≥1024px). Alargue a janela para ver o shell completo.</div>

    <div class="crumb">Backoffice · Admin</div>
    <h1 class="main-h">Disputas</h1>
    <p class="main-d">
        @if ($this->abertosCount > 0)
            {{ $this->abertosCount }} {{ $this->abertosCount === 1 ? 'disputa em aberto' : 'disputas em aberto' }} · SLA público de 30 min
        @else
            Nenhuma disputa aberta · SLA público de 30 min
        @endif
    </p>

    @if ($this->abertosCount > 0)
        <div class="stats" style="grid-template-columns:repeat(2,1fr)">
            <div class="stat">
                <div class="k">Em aberto</div>
                <div class="v" data-testid="disputas-count-aberto">{{ $this->abertosCount }}</div>
            </div>
            <div class="stat">
                <div class="k">Com SLA estourado</div>
                <div class="v" data-testid="disputas-count-sla">{{ $this->slaEstouradoCount }}</div>
            </div>
        </div>

        @if ($this->slaEstouradoCount > 0)
            <div class="feedback" data-testid="disputas-sla-banner" role="status"
                 style="background:var(--error-soft)">
                <span class="ic" aria-hidden="true" style="background:var(--error)">!</span>
                {{ $this->slaEstouradoCount }} {{ $this->slaEstouradoCount === 1 ? 'disputa há' : 'disputas há' }}
                mais de 30 min em aberto — priorize.
            </div>
        @endif
    @endif

    <div class="panel" style="margin-top:8px">
        <div class="panel-h"><h3>Fila de disputas</h3></div>

        @if ($this->fila->isEmpty())
            <div class="empty" data-testid="disputas-empty">
                <div class="mark">✓</div>
                <h4>Nenhuma disputa aberta</h4>
                <p>Quando um contratante contestar um check-out, a disputa aparece aqui para mediação em até 30 min.</p>
            </div>
        @else
            <table data-testid="disputas-list" aria-live="polite">
                <thead>
                    <tr><th>Partes</th><th>Valor</th><th>Aberta há</th><th></th></tr>
                </thead>
                <tbody>
                    @foreach ($this->fila as $turno)
                        @php
                            $min = $this->minutosEmAberto($turno);
                            $nivel = $this->slaNivel($min);
                            $estab = $turno->contratante->contratanteProfile->nome_estabelecimento
                                ?? $turno->contratante->name;
                            $funcao = $turno->profissional->profissionalProfile->funcao->nome ?? 'Turno';
                        @endphp
                        <tr data-testid="disputas-item-{{ $turno->id }}" wire:key="disputa-{{ $turno->id }}">
                            <td>
                                <div class="cell-name">{{ $estab }} &nbsp;⇄&nbsp; {{ $turno->profissional->name }}</div>
                                <div class="cell-sub">{{ $funcao }}</div>
                            </td>
                            <td style="font-weight:600;white-space:nowrap">{{ $fmtMoeda($turno->valor) }}</td>
                            <td>
                                <span class="chip sla-{{ $nivel }}" data-testid="disputas-item-{{ $turno->id }}-sla">
                                    <span class="ic" aria-hidden="true"></span>{{ $slaIcone[$nivel] }} há {{ $min }} min
                                </span>
                            </td>
                            <td class="right">
                                <button type="button" class="btn btn-outline" wire:click="abrirCaso('{{ $turno->id }}')"
                                        data-testid="disputas-item-{{ $turno->id }}-ver">Ver caso</button>
                            </td>
                        </tr>
                    @endforeach
                </tbody>
            </table>
        @endif
    </div>

    {{-- Caso (drawer lateral) — trilha completa + resolver (DDR-005 Decisão 3) --}}
    @if ($this->caso)
        @php
            $caso = $this->caso;
            $min = $this->minutosEmAberto($caso);
            $nivel = $this->slaNivel($min);
            $estab = $caso->contratante->contratanteProfile->nome_estabelecimento ?? $caso->contratante->name;
            $funcao = $caso->profissional->profissionalProfile->funcao->nome ?? 'Turno';
        @endphp
        <div class="scrim" wire:click="fecharCaso"></div>
        <aside class="drawer" data-testid="disputas-caso" role="dialog" aria-modal="true" aria-labelledby="caso-titulo"
               x-data x-on:keydown.escape.window="$wire.fecharCaso()">
            <div class="dw-h">
                <div>
                    <h3 id="caso-titulo">{{ $estab }} &nbsp;⇄&nbsp; {{ $caso->profissional->name }}</h3>
                    <div class="cell-sub">
                        {{ $funcao }} · {{ $fmtMoeda($caso->valor) }} ·
                        <span class="chip sla-{{ $nivel }}"><span class="ic" aria-hidden="true"></span>{{ $slaIcone[$nivel] }} há {{ $min }} min · SLA 30 min</span>
                    </div>
                </div>
                <button type="button" class="dw-close" wire:click="fecharCaso"
                        data-testid="disputas-caso-close" aria-label="Fechar caso" x-init="$el.focus()">✕</button>
            </div>

            <div class="dw-body">
                <div class="sb-sec" style="padding:0 0 6px;color:var(--text-subtle)">Justificativa do contratante</div>
                <div data-testid="caso-justificativa"
                     style="background:var(--sunken);border:1px solid var(--border);border-radius:12px;padding:12px 14px;font-size:14px">
                    {{ $caso->justificativaContratante() ?? '—' }}
                </div>

                <div class="sb-sec" style="padding:18px 0 6px;color:var(--text-subtle)">Trilha do turno</div>
                <div data-testid="caso-trilha">
                    @forelse ($this->trilha($caso) as $ev)
                        <div style="display:flex;gap:10px;padding:8px 0;border-bottom:1px solid var(--border)">
                            <span style="width:8px;height:8px;border-radius:999px;background:var(--accent);margin-top:6px;flex-shrink:0"></span>
                            <div>
                                <div style="font-weight:500;font-size:14px">{{ $ev['rotulo'] }}</div>
                                <div class="cell-sub">{{ $ev['em']?->timezone(config('app.timezone'))->translatedFormat('D, d/m · H:i') }}</div>
                            </div>
                        </div>
                    @empty
                        <div class="cell-sub">Sem eventos de auditoria registrados para este turno.</div>
                    @endforelse

                    {{-- Geofencing do check-out (alerta-e-registra, PDR-008) --}}
                    @if (!empty($caso->geofencing_check_out))
                        <div style="display:flex;gap:10px;padding:8px 0;border-bottom:1px solid var(--border)" data-testid="caso-geofencing">
                            <span style="width:8px;height:8px;border-radius:999px;background:var(--accent);margin-top:6px;flex-shrink:0"></span>
                            <div>
                                <div style="font-weight:500;font-size:14px">Geofencing do check-out</div>
                                <div class="cell-sub">
                                    @if (isset($caso->geofencing_check_out['distancia_metros']))
                                        a {{ $caso->geofencing_check_out['distancia_metros'] }} m do estabelecimento
                                    @else
                                        registrado
                                    @endif
                                </div>
                            </div>
                        </div>
                    @endif

                    {{-- Cronômetro: check-in validado → fim combinado --}}
                    @if ($caso->check_in_at)
                        <div style="display:flex;gap:10px;padding:8px 0;border-bottom:1px solid var(--border)" data-testid="caso-cronometro">
                            <span style="width:8px;height:8px;border-radius:999px;background:var(--accent);margin-top:6px;flex-shrink:0"></span>
                            <div>
                                <div style="font-weight:500;font-size:14px">Cronômetro</div>
                                <div class="cell-sub">
                                    Check-in {{ $caso->check_in_at->timezone(config('app.timezone'))->format('d/m · H:i') }}
                                    @if ($caso->data_fim)
                                        · fim combinado {{ $caso->data_fim->timezone(config('app.timezone'))->format('H:i') }}
                                    @endif
                                </div>
                            </div>
                        </div>
                    @endif

                    {{-- Vaga original (snapshot congelado no turno — sem rota de detalhe no MVP) --}}
                    <details style="padding:8px 0">
                        <summary data-testid="caso-vaga-original" style="cursor:pointer;font-weight:500;font-size:14px;color:var(--accent)">Vaga original</summary>
                        <div class="cell-sub" style="margin-top:6px">
                            {{ $funcao }} · {{ $fmtMoeda($caso->valor) }}
                            @if ($caso->data_inicio && $caso->data_fim)
                                · {{ $caso->data_inicio->timezone(config('app.timezone'))->format('d/m H:i') }}–{{ $caso->data_fim->timezone(config('app.timezone'))->format('H:i') }}
                            @endif
                        </div>
                    </details>
                </div>
            </div>

            <div class="dw-foot">
                <button type="button" class="btn btn-success btn-block" wire:click="abrirResolucao"
                        data-testid="disputas-caso-resolver">Resolver: pagar integral</button>
            </div>
        </aside>
    @endif

    {{-- Dialog de resolução — nota OBRIGATÓRIA (DDR-005 Decisão 3) --}}
    @if ($this->resolvendoId)
        <div class="dlg-scrim" role="alertdialog" aria-modal="true" aria-labelledby="resolver-titulo"
             data-testid="dialog-resolver" x-data x-on:keydown.escape.window="$wire.fecharResolucao()">
            <div class="dlg">
                <h4 id="resolver-titulo">Resolver: pagar integral?</h4>
                <p>Captura o valor e libera o Pix ao profissional. O turno será finalizado. Esta ação é irreversível.</p>
                <label for="resolver-nota" style="display:block;font-size:13px;font-weight:600;margin-bottom:6px">Nota da decisão (obrigatória)</label>
                <textarea id="resolver-nota" wire:model="nota" maxlength="2000" rows="3"
                          placeholder="Ex.: Justificativa do contratante procede; pagar integral."
                          aria-describedby="resolver-nota-erro" data-testid="resolver-nota-input"
                          style="width:100%;border:1px solid var(--border-strong);border-radius:12px;padding:10px 12px;font-family:inherit;font-size:14px;background:var(--surface);color:var(--text);resize:vertical"></textarea>
                @error('nota')
                    <div id="resolver-nota-erro" data-testid="resolver-nota-erro"
                         style="color:var(--error);font-size:12.5px;margin-top:6px">{{ $message }}</div>
                @enderror
                <div class="dlg-actions" style="margin-top:18px">
                    <button type="button" class="btn btn-ghost" wire:click="fecharResolucao"
                            data-testid="dialog-resolver-cancel">Voltar</button>
                    <button type="button" class="btn btn-solid-success" wire:click="confirmarResolucao"
                            data-testid="dialog-resolver-confirm">Pagar integral</button>
                </div>
            </div>
        </div>
    @endif

    <div class="toast" x-cloak x-show="toast" :class="{ 'err': type === 'error' }"
         data-testid="disputas-toast" role="status" aria-live="polite" x-transition>
        <span class="dot"></span><span x-text="toast"></span>
    </div>
</div>
