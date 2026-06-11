<?php

namespace App\Livewire;

use App\Models\Turno;
use App\Services\AuditLogService;
use App\Services\Disputas\ResolverDisputaClient;
use App\Services\Disputas\ResultadoResolucao;
use Illuminate\Contracts\View\View;
use Illuminate\Support\Collection;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Layout;
use Livewire\Component;

/**
 * STORY-096 / ADR-020 / DDR-005 — fila de disputas + caso com trilha + resolver "pagar integral".
 *
 * - **Fila** DERIVADA do estado `em_disputa` (ADR-020 Decisão 4 — sem tabela de fila), mais antiga
 *   primeiro (CA-1), com partes, valor e tempo decorrido vs SLA público de 30 min.
 * - **Caso** (drawer) = agregação de LEITURA sobre dados já existentes (ADR-020 Decisão 6):
 *   justificativa do contratante + trilha de `audit_logs` (api) + geofencing/cronômetro/vaga.
 *   O profissional não entra aqui; o admin vê a trilha completa para decidir.
 * - **Resolver** chama o comando da api (`ResolverDisputaClient` — IDR-032); o admin é CLIENTE,
 *   NUNCA escreve a transição/captura no banco. `nota_admin` é OBRIGATÓRIA (DDR-005 Decisão 3 /
 *   ADR-020 — diverge da CA-3 "opcional", resolvido a favor do ADR, com a chancela do PO no DDR-005).
 * - **Concorrência** (CA-4): race-check no banco antes de chamar + mapeamento do 422 `estado_invalido`
 *   da api → "já resolvida por outro admin", sem efeito duplicado.
 */
#[Layout('components.layouts.admin')]
class Disputas extends Component
{
    /** Id do turno aberto no drawer do caso (null = fila). */
    public ?string $casoId = null;

    /** Id do turno com o dialog de resolução aberto (null = fechado). */
    public ?string $resolvendoId = null;

    /** Nota da decisão — OBRIGATÓRIA (DDR-005 Decisão 3). */
    public string $nota = '';

    /** Rótulos amigáveis para as ações de auditoria que compõem a trilha do caso. */
    private const ROTULOS_TRILHA = [
        'turno.criado' => 'Turno confirmado',
        'turno.checkin_solicitado' => 'Check-in solicitado',
        'turno.checkin_validado' => 'Check-in validado',
        'turno.checkout_solicitado' => 'Check-out solicitado',
        'turno.checkout_recusado' => 'Check-out recusado',
        'turno.disputa_aberta' => 'Disputa aberta',
        'turno.disputa_resolvida' => 'Disputa resolvida',
    ];

    /** Fila de turnos em disputa, do mais antigo primeiro (CA-1). */
    #[Computed]
    public function fila(): Collection
    {
        return Turno::emDisputa()
            ->with([
                'contratante.contratanteProfile',
                'profissional.profissionalProfile.funcao',
            ])
            ->get()
            ->sortBy(fn (Turno $t) => $t->disputaAbertaEm()?->getTimestamp() ?? PHP_INT_MAX)
            ->values();
    }

    #[Computed]
    public function abertosCount(): int
    {
        return Turno::emDisputa()->count();
    }

    /** Disputas com o SLA público de 30 min estourado. */
    #[Computed]
    public function slaEstouradoCount(): int
    {
        return $this->fila()
            ->filter(fn (Turno $t) => $this->slaNivel($this->minutosEmAberto($t)) === 'late')
            ->count();
    }

    /** Caso aberto no drawer (com a trilha), ou null. */
    #[Computed]
    public function caso(): ?Turno
    {
        if ($this->casoId === null) {
            return null;
        }

        return Turno::emDisputa()
            ->with(['contratante.contratanteProfile', 'profissional.profissionalProfile.funcao', 'auditLogs'])
            ->find($this->casoId);
    }

    /** Minutos decorridos desde a abertura da disputa. */
    public function minutosEmAberto(Turno $turno): int
    {
        $aberta = $turno->disputaAbertaEm();

        return $aberta ? (int) $aberta->diffInMinutes(now()) : 0;
    }

    /** Classificação do SLA: 🟢 ≤15 · 🟡 15–30 · 🔴 >30 (DDR-005 Decisão 3). */
    public function slaNivel(int $minutos): string
    {
        return match (true) {
            $minutos <= 15 => 'ok',
            $minutos <= 30 => 'warn',
            default => 'late',
        };
    }

    /** Trilha do caso: audit_logs reais do turno com rótulos amigáveis (agregação de leitura). */
    public function trilha(Turno $turno): Collection
    {
        return $turno->auditLogs
            ->filter(fn ($log) => array_key_exists($log->action, self::ROTULOS_TRILHA))
            ->map(fn ($log) => [
                'rotulo' => self::ROTULOS_TRILHA[$log->action],
                'em' => $log->created_at,
            ])
            ->values();
    }

    public function abrirCaso(string $turnoId): void
    {
        $this->casoId = $turnoId;
        $this->fecharResolucao();
    }

    public function fecharCaso(): void
    {
        $this->casoId = null;
        $this->fecharResolucao();
    }

    public function abrirResolucao(): void
    {
        $this->resolvendoId = $this->casoId;
        $this->nota = '';
        $this->resetErrorBag();
    }

    public function fecharResolucao(): void
    {
        $this->resolvendoId = null;
        $this->nota = '';
        $this->resetErrorBag();
    }

    public function confirmarResolucao(ResolverDisputaClient $client, AuditLogService $audit): void
    {
        // Nota só de espaços não conta a história de ninguém (mesma postura do PixFalhas).
        $this->nota = trim($this->nota);
        $this->validate(
            ['nota' => 'required|string|max:2000'],
            ['nota.required' => 'Descreva o motivo da decisão antes de confirmar.'],
        );

        // Race-check no banco: só segue se AINDA está em disputa (outro admin pode ter resolvido).
        $turno = $this->resolvendoId ? Turno::emDisputa()->find($this->resolvendoId) : null;
        if ($turno === null) {
            $this->fecharCaso();
            $this->dispatch('toast', message: 'Esta disputa já foi resolvida por outro admin.', type: 'error');

            return;
        }

        $admin = auth()->user();
        $resultado = $client->resolver($turno->id, $admin->id, $this->nota);

        match ($resultado) {
            ResultadoResolucao::Ok => $this->aoResolver($audit, $turno, $admin),
            ResultadoResolucao::Concorrente => $this->aoConcorrer(),
            ResultadoResolucao::Erro => $this->dispatch('toast', message: 'Não foi possível resolver agora. Tente novamente.', type: 'error'),
        };
    }

    private function aoResolver(AuditLogService $audit, Turno $turno, $admin): void
    {
        // Trilha de auditoria do admin (quem clicou no backoffice). A trilha financeira/transição
        // canônica (turno.disputa_resolvida) é escrita pela api (ADR-020 Decisão 3).
        $audit->log(
            action: 'disputa.resolucao_solicitada',
            actorId: $admin->id,
            targetType: 'Turno',
            targetId: $turno->id,
            payload: ['resolucao' => 'paga_integral', 'nota' => $this->nota],
        );

        $this->fecharCaso();
        $this->dispatch('toast', message: 'Disputa resolvida — pagamento integral liberado.', type: 'success');
    }

    private function aoConcorrer(): void
    {
        $this->fecharCaso();
        $this->dispatch('toast', message: 'Esta disputa já foi resolvida por outro admin.', type: 'error');
    }

    public function render(): View
    {
        return view('livewire.disputas');
    }
}
