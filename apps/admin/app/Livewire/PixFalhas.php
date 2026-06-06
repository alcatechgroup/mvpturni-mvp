<?php

namespace App\Livewire;

use App\Models\PixFalha;
use App\Services\AuditLogService;
use Illuminate\Contracts\View\View;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Layout;
use Livewire\Attributes\Url;
use Livewire\Component;
use Livewire\WithPagination;

/**
 * STORY-065 (CA-5, CA-8) — fila "Pix com falha" do Backoffice (SCREEN-065 §B).
 *
 * PDR-010: Pix tem UMA tentativa, sem retry automático — esta fila é o único caminho de
 * tratamento. Pendentes em ordem de falha DESC; resolução manual exige NOTA (o audit
 * trail precisa da história) e é race-safe entre admins. Quem escreve os casos é o
 * worker da api (snapshot operacional — IDR-028); aqui só leitura + resolução.
 */
#[Layout('components.layouts.admin')]
class PixFalhas extends Component
{
    use WithPagination;

    /** Aba ativa: pendentes | resolvidos (persistida na querystring). */
    #[Url]
    public string $aba = 'pendentes';

    /** Id do caso aberto no dialog de resolução (null = fechado). */
    public ?string $resolvendoId = null;

    /** Nota obrigatória da resolução (CA-8 — sem nota o audit log não conta a história). */
    public string $nota = '';

    public function updatedAba(): void
    {
        $this->resetPage();
    }

    public function abrirResolucao(string $casoId): void
    {
        $this->resolvendoId = $casoId;
        $this->nota = '';
        $this->resetErrorBag();
    }

    public function fecharResolucao(): void
    {
        $this->resolvendoId = null;
        $this->nota = '';
        $this->resetErrorBag();
    }

    public function confirmarResolucao(AuditLogService $audit): void
    {
        // trim antes de validar: nota só de espaços não conta a história de ninguém.
        $this->nota = trim($this->nota);
        $this->validate(
            ['nota' => 'required|string|max:500'],
            ['nota.required' => 'Descreva o que foi feito antes de confirmar.'],
        );

        // Race-safe: só resolve se AINDA está pendente (outro admin pode ter fechado).
        $caso = $this->resolvendoId
            ? PixFalha::pendentes()->find($this->resolvendoId)
            : null;

        if ($caso === null) {
            $this->fecharResolucao();
            $this->dispatch('toast', message: 'Este caso já foi resolvido por outro admin.', type: 'error');

            return;
        }

        $admin = auth()->user();

        $caso->update([
            'resolvido_em' => now(),
            'resolvido_por' => $admin->id,
            'nota_resolucao' => $this->nota,
        ]);

        $audit->log(
            action: 'pix_falha.resolvida',
            actorId: $admin->id,
            targetType: 'PixFalha',
            targetId: $caso->id,
            payload: ['turno_id' => $caso->turno_id, 'nota' => $this->nota],
        );

        $this->fecharResolucao();
        $this->dispatch('toast', message: 'Caso resolvido. Registrado no histórico de auditoria.', type: 'success');
    }

    /** Caso aberto no dialog (resumo exibido — SCREEN-065 §B.4). */
    #[Computed]
    public function casoEmResolucao(): ?PixFalha
    {
        return $this->resolvendoId ? PixFalha::find($this->resolvendoId) : null;
    }

    #[Computed]
    public function pendentesCount(): int
    {
        return PixFalha::pendentes()->count();
    }

    public function render(): View
    {
        $query = $this->aba === 'resolvidos'
            ? PixFalha::with('resolvidoPor:id,name')->whereNotNull('resolvido_em')->orderByDesc('resolvido_em')
            : PixFalha::pendentes()->orderByDesc('falhou_em'); // CA-8 — desc

        return view('livewire.pix-falhas', [
            'casos' => $query->paginate(20),
        ]);
    }
}
