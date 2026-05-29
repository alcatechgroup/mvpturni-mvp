<?php

namespace App\Livewire;

use App\Exceptions\CadastroJaProcessadoException;
use App\Models\User;
use App\Services\ApprovalService;
use Illuminate\Contracts\View\View;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Layout;
use Livewire\Attributes\Url;
use Livewire\Component;
use Livewire\WithPagination;

/**
 * STORY-019 — Fila de aprovação do Backoffice.
 *
 * Lista cadastros em `pendente_aprovacao` (FIFO), filtra por papel/tipo_pessoa
 * (persistido na querystring), abre detalhe e despacha veredito (aprovar/remover)
 * via ApprovalService. Acessível apenas a admin (middleware AdminOnly na rota).
 */
#[Layout('components.layouts.admin')]
class FilaAprovacao extends Component
{
    use WithPagination;

    /** Filtro de papel: todos | profissional | contratante (CA-3 — querystring). */
    #[Url]
    public string $papel = 'todos';

    /** Sub-filtro de tipo de pessoa do profissional: PF | MEI | PJ (CA-3). */
    #[Url]
    public ?string $tipoPessoa = null;

    /** Id do usuário aberto no drawer de detalhe (null = fechado). */
    public ?int $selectedId = null;

    public function updatedPapel(): void
    {
        // tipo_pessoa só faz sentido para profissional; limpa ao sair desse filtro.
        if ($this->papel !== 'profissional') {
            $this->tipoPessoa = null;
        }
        $this->resetPage();
    }

    public function updatedTipoPessoa(): void
    {
        $this->resetPage();
    }

    /** Alterna o sub-filtro de tipo de pessoa (clicar no ativo limpa). */
    public function filtrarTipo(string $tipo): void
    {
        $this->tipoPessoa = $this->tipoPessoa === $tipo ? null : $tipo;
        $this->resetPage();
    }

    public function limparFiltros(): void
    {
        $this->papel = 'todos';
        $this->tipoPessoa = null;
        $this->resetPage();
    }

    public function verDetalhes(int $userId): void
    {
        $this->selectedId = $userId;
    }

    public function fecharDetalhe(): void
    {
        $this->selectedId = null;
    }

    public function aprovar(ApprovalService $service): void
    {
        $this->despachar(fn (User $alvo, User $admin) => $service->approve($alvo, $admin), aprovacao: true);
    }

    public function remover(ApprovalService $service): void
    {
        $this->despachar(fn (User $alvo, User $admin) => $service->remove($alvo, $admin), aprovacao: false);
    }

    private function despachar(callable $acao, bool $aprovacao): void
    {
        $alvo = $this->selectedId ? User::find($this->selectedId) : null;

        if (! $alvo) {
            $this->fecharDetalhe();
            $this->dispatch('toast', message: 'Este cadastro já foi processado por outro admin.', type: 'error');

            return;
        }

        try {
            $acao($alvo, auth()->user());
        } catch (CadastroJaProcessadoException $e) {
            $this->fecharDetalhe();
            $this->dispatch('toast', message: $e->getMessage(), type: 'error');

            return;
        }

        $this->fecharDetalhe();

        if ($aprovacao) {
            $this->dispatch('toast', message: "Cadastro aprovado. E-mail enviado a {$this->mascarar($alvo->email)}.", type: 'success');
        } else {
            $this->dispatch('toast', message: 'Cadastro removido.', type: 'success');
        }
    }

    private function mascarar(string $email): string
    {
        [$local, $dominio] = array_pad(explode('@', $email, 2), 2, '');

        return $dominio === '' ? mb_substr($local, 0, 1).'•••' : mb_substr($local, 0, 1).'•••@'.$dominio;
    }

    /** Conta global do backlog por papel/tipo (CA-8) — independente do filtro ativo. */
    #[Computed]
    public function contadores(): array
    {
        $base = User::query()->where('status', 'pendente_aprovacao');

        $porTipo = (clone $base)
            ->where('role', 'profissional')
            ->join('profissional_profiles', 'profissional_profiles.user_id', '=', 'users.id')
            ->selectRaw('tipo_pessoa, COUNT(*) as total')
            ->groupBy('tipo_pessoa')
            ->pluck('total', 'tipo_pessoa');

        $profissionais = (clone $base)->where('role', 'profissional')->count();
        $contratantes = (clone $base)->where('role', 'contratante')->count();

        return [
            'total' => $profissionais + $contratantes,
            'profissionais' => $profissionais,
            'contratantes' => $contratantes,
            'pf' => (int) $porTipo->get('PF', 0),
            'mei' => (int) $porTipo->get('MEI', 0),
            'pj' => (int) $porTipo->get('PJ', 0),
        ];
    }

    /** Quantos cadastros estão há mais de 20h na fila (alerta de SLA — CA-9). */
    #[Computed]
    public function emRiscoSla(): int
    {
        return User::query()
            ->where('status', 'pendente_aprovacao')
            ->where('created_at', '<', now()->subHours(20))
            ->count();
    }

    /** Usuário aberto no detalhe, com perfil e função carregados (CA-4). */
    #[Computed]
    public function selecionado(): ?User
    {
        if (! $this->selectedId) {
            return null;
        }

        return User::with(['profissionalProfile.funcao', 'contratanteProfile'])
            ->where('status', 'pendente_aprovacao')
            ->find($this->selectedId);
    }

    public function render(): View
    {
        $query = User::query()
            ->with(['profissionalProfile.funcao', 'contratanteProfile'])
            ->pendentesFifo();

        if (in_array($this->papel, ['profissional', 'contratante'], true)) {
            $query->where('role', $this->papel);
        }

        if ($this->papel === 'profissional' && in_array($this->tipoPessoa, ['PF', 'MEI', 'PJ'], true)) {
            $query->whereHas('profissionalProfile', fn ($q) => $q->where('tipo_pessoa', $this->tipoPessoa));
        }

        return view('livewire.fila-aprovacao', [
            'cadastros' => $query->paginate(20),
        ]);
    }
}
