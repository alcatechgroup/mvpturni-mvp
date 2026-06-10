<?php

namespace App\Services;

use App\Enums\TurnoStatus;
use App\Events\TurnoFinalizado;
use App\Models\AuditLog;
use App\Models\Turno;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * STORY-093 / ADR-020 (Decisão 3A) — resolução "pagar integral" da disputa pelo ADMIN. É o
 * desfecho do turno em `em_disputa`: o admin decide pagar, e a partir daí NADA de novo acontece
 * no caminho financeiro (F1 — não criar segunda fonte de bugs de dinheiro). Espelha o
 * ValidarCheckoutService::validar()/AbrirDisputaService: transita na transação, emite o evento
 * pós-commit.
 *
 * Pré-condições (fail-secure): turno em `em_disputa`; `nota_admin` não-vazia (após trim). O RBAC
 * (ator = admin) é ortogonal e vive no canal/controller (ADR-007). A obrigatoriedade da nota é
 * decisão de modelo do ADR-020 (Decisão 3, passo 1) — a CA-3 dizia "opcional"; o conflito foi
 * resolvido a favor do ADR (ver Notas do agente da STORY-093).
 *
 * Efeito numa transação: completa `turnos.disputa` (resolucao/nota_admin/resolvida_em/resolvida_por,
 * preservando a abertura — trilha de quem abriu E de quem resolveu), `transitionTo(finalizado)`
 * (passa pelo trigger `enforce_turno_transition` — ADR-015; um 2º "pagar integral" encontra o turno
 * já `finalizado` e a transição falha: idempotência de resolução por construção) e `AuditLog
 * turno.disputa_resolvida`.
 *
 * Pós-commit: emite o MESMO `TurnoFinalizado` do check-out feliz — que já dispara a captura padrão
 * + Pix (TurnoFinalizadoListener → CapturarEPagarTurnoJob, idempotente por operação — ADR-016), a
 * notificação ao profissional (NotificarTurnoFinalizado — CA-7) e o gate de avaliação recíproca
 * (NotificarAvaliacaoPendente — CA-2). Falha de Pix segue PDR-010 (uma tentativa → alerta no
 * backoffice, sem travar o `finalizado` — CA-6), tudo herdado da máquina do EPIC-004/STORY-065.
 */
class ResolverDisputaService
{
    /** Única resolução do MVP (paga_parcial/sem_pagamento ficam para o EPIC-007 — ADR-020 Decisão 5). */
    private const RESOLUCAO_PAGA_INTEGRAL = 'paga_integral';

    public function __construct(private readonly Request $request) {}

    /**
     * @return array{estado:string}
     *
     * @throws PinCheckinEstadoInvalidoException|NotaAdminObrigatoriaException
     */
    public function resolverPagaIntegral(Turno $turno, User $admin, ?string $notaAdmin): array
    {
        if ($turno->status !== TurnoStatus::EmDisputa) {
            throw new PinCheckinEstadoInvalidoException($turno->status->value);
        }

        $nota = trim((string) $notaAdmin);
        if ($nota === '') {
            throw new NotaAdminObrigatoriaException;
        }

        DB::transaction(function () use ($turno, $admin, $nota) {
            // Completa a disputa preservando a abertura (aberta_em/aberta_por/justificativa).
            $turno->disputa = array_merge($turno->disputa ?? [], [
                'resolucao' => self::RESOLUCAO_PAGA_INTEGRAL,
                'nota_admin' => $nota,
                'resolvida_em' => now()->toIso8601String(),
                'resolvida_por' => $admin->id,
            ]);

            $turno->transitionTo(TurnoStatus::Finalizado); // trigger do banco é a rede final (ADR-015)

            AuditLog::create([
                'actor_id' => $admin->id,
                'action' => 'turno.disputa_resolvida',
                'target_type' => 'Turno',
                'target_id' => $turno->id,
                'payload' => ['resolucao' => self::RESOLUCAO_PAGA_INTEGRAL, 'nota_admin' => Str::limit($nota, 500)],
                'ip' => $this->request->ip(),
                'user_agent' => $this->request->userAgent(),
            ]);
        });

        // Mesmo evento do check-out feliz: captura+Pix, notificação e gate de avaliação — pós-commit.
        TurnoFinalizado::dispatch($turno->id);

        return ['estado' => TurnoStatus::Finalizado->value];
    }
}
