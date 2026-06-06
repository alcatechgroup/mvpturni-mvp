<?php

namespace App\Services;

use App\Enums\TurnoStatus;
use App\Events\TurnoCancelado;
use App\Models\AuditLog;
use App\Models\Turno;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * STORY-066 (CA-2/CA-3) — cancelamento do turno antes do check-in (PDR-007, sem motor de
 * penalidade no MVP). O LADO vem de quem está autenticado (RBAC já garantido no controller):
 * profissional → `cancelado_pro`, contratante → `cancelado_emp`.
 *
 * TRANSAÇÃO: transitionTo (trigger do banco é a rede final) + `cancelamento`
 * { lado, motivo?, antecedencia_horas, em } (base do motor de penalidade futuro) + audit
 * `turno.cancelado` (timeline dos 2 lados — motivo visível a ambos, decisão do PO
 * 2026-06-06). Evento TurnoCancelado PÓS-COMMIT → liberação via ACL (TurnoCanceladoListener)
 * e notificações (STORY-067).
 */
class CancelarTurnoService
{
    public function __construct(private readonly Request $request) {}

    /**
     * @return array{estado: string}
     *
     * @throws TurnoNaoCancelavelException
     */
    public function cancelar(Turno $turno, User $ator, ?string $motivo): array
    {
        if (! $turno->status->podeCancelar()) {
            throw new TurnoNaoCancelavelException($turno->status->value);
        }

        $lado = $ator->id === $turno->profissional_id ? 'pro' : 'emp';
        $destino = $lado === 'pro' ? TurnoStatus::CanceladoPro : TurnoStatus::CanceladoEmp;

        // Antecedência em horas relativa ao início previsto (negativa se já passou) —
        // registro para o motor de penalidade pós-MVP (PDR-007), não usado em regra hoje.
        $antecedenciaHoras = round(now()->diffInHours($turno->data_inicio, absolute: false), 2);

        DB::transaction(function () use ($turno, $ator, $destino, $lado, $motivo, $antecedenciaHoras) {
            $turno->cancelamento = [
                'lado' => $lado,
                'motivo' => $motivo,
                'antecedencia_horas' => $antecedenciaHoras,
                'em' => now()->toIso8601String(),
            ];
            $turno->transitionTo($destino);

            AuditLog::create([
                'actor_id' => $ator->id,
                'action' => 'turno.cancelado',
                'target_type' => 'Turno',
                'target_id' => $turno->id,
                'payload' => [
                    'lado' => $lado,
                    'motivo' => $motivo,
                    'antecedencia_horas' => $antecedenciaHoras,
                ],
                'ip' => $this->request->ip(),
                'user_agent' => $this->request->userAgent(),
            ]);
        });

        // CA-3 — pós-commit: liberação (listener desta estória) + notificação (STORY-067).
        TurnoCancelado::dispatch($turno->id, $lado, $motivo);

        return ['estado' => $destino->value];
    }
}
