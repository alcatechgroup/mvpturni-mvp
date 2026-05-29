<x-layouts.admin title="Turni · Backoffice">
    <div class="crumb">Backoffice · Admin</div>
    <h1 class="main-h">Bem-vindo, {{ auth()->user()->name }}.</h1>
    <p class="main-d">Backoffice Turni. Use o menu à esquerda para operar a fila de cadastros.</p>

    <div class="stats">
        <a href="{{ route('aprovacoes') }}" class="stat" style="text-decoration:none;display:block" wire:navigate>
            <div class="k">Operação</div>
            <div class="v" style="font-size:20px">Cadastros pendentes →</div>
            <div class="sub">Analisar, aprovar ou remover pré-cadastros (SLA 24h).</div>
        </a>
    </div>
</x-layouts.admin>
