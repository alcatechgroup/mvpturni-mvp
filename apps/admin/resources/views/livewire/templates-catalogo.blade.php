<div data-testid="templates-catalogo">
    <div class="narrow-warn">Backoffice é desktop-first (≥1024px). Alargue a janela para ver o shell completo.</div>

    <div class="crumb">Backoffice · Admin</div>
    <h1 class="main-h">Templates contratuais</h1>
    <p class="main-d">Edite os contratos sem precisar de deploy. Cada edição cria uma nova versão; a ativa vale para novos cadastros.</p>

    <div class="panel">
        <div class="panel-h"><h3>Catálogo</h3></div>
        <table>
            <thead>
                <tr><th>Template</th><th>Slug</th><th>Versão ativa</th><th>Ativada em</th><th class="right"><span class="sr-only">Ações</span></th></tr>
            </thead>
            <tbody>
                @foreach ($templates as $template)
                    @php $ativa = $template->versaoAtiva; @endphp
                    <tr wire:key="tpl-{{ $template->id }}" data-testid="templates-catalogo-item-{{ $template->slug }}">
                        <td>
                            <div class="t-name">{{ $template->nome_amigavel }}</div>
                        </td>
                        <td><span class="mono" style="font-size:13px;color:var(--text-muted)">{{ $template->slug }}</span></td>
                        <td>
                            @if ($ativa)
                                <span class="chip active" data-testid="templates-catalogo-item-{{ $template->slug }}-ativa">
                                    <span class="ic" aria-hidden="true"></span> v{{ $ativa->versao }} · ativa
                                </span>
                            @else
                                <span class="chip" style="background:var(--warning-soft);color:var(--text)">— sem versão ativa · rode o seed (php artisan db:seed)</span>
                            @endif
                        </td>
                        <td>
                            @if ($ativa)
                                <div class="t-sub" style="margin:0">desde {{ $ativa->created_at->format('d/m') }} · por {{ $ativa->autor?->name ?? '—' }}</div>
                            @else
                                <div class="t-sub" style="margin:0">—</div>
                            @endif
                        </td>
                        <td class="right">
                            <a class="btn btn-outline" href="{{ route('templates.detalhe', ['slug' => $template->slug]) }}" wire:navigate data-testid="templates-catalogo-item-{{ $template->slug }}-abrir">Abrir</a>
                        </td>
                    </tr>
                @endforeach
            </tbody>
        </table>
    </div>
</div>
