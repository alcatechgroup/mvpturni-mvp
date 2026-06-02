<?php

namespace App\Services;

use App\Enums\CandidaturaEstado;
use App\Enums\VagaEstado;
use App\Events\VagaCancelada;
use App\Models\AuditLog;
use App\Models\Vaga;
use DomainException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * STORY-047 (CA-4/CA-5) — cancela uma vaga do contratante de forma atômica:
 *  1. valida a transição `aberta → cancelada` (o domínio é fail-closed — Vaga::transitionTo
 *     lança DomainException fora de `aberta`, que o controller traduz em 409);
 *  2. apura `candidatos_pendentes` ANTES da transição (a contagem alimenta o evento);
 *  3. carimba `cancelada_em` e persiste o estado (Vaga::transitionTo);
 *  4. registra o evento de domínio `vaga.cancelada` em `audit_logs`;
 *  5. dispara o evento `VagaCancelada` (consumido por STORY-053 para notificar pendentes);
 *  6. emite telemetria estruturada `vaga.cancelada` (ADR-008).
 *
 * A autorização (papel contratante + ser o dono) é responsabilidade do controller/rota,
 * não deste serviço. Aqui só cancela quando chamado.
 */
class CancelarVagaService
{
    public function __construct(private readonly Request $request) {}

    /** @throws DomainException se a vaga não estiver em estado cancelável (aberta). */
    public function cancelar(Vaga $vaga): Vaga
    {
        return DB::transaction(function () use ($vaga) {
            $pendentes = $vaga->candidaturas()
                ->where('estado', CandidaturaEstado::Pendente)
                ->count();

            // Fail-closed: fora de `aberta`, transitionTo lança DomainException → 409.
            $vaga->transitionTo(VagaEstado::Cancelada);

            AuditLog::create([
                'actor_id' => $this->request->user()?->id,
                'action' => 'vaga.cancelada',
                'target_type' => 'Vaga',
                'target_id' => $vaga->id,
                'payload' => ['candidatos_pendentes' => $pendentes],
                'ip' => $this->request->ip(),
                'user_agent' => $this->request->userAgent(),
            ]);

            VagaCancelada::dispatch($vaga, $pendentes);

            Log::info('vaga.cancelada', [
                'event' => 'vaga.cancelada',
                'vaga_id' => $vaga->id,
                'contratante_id' => $vaga->contratante_id,
                'candidatos_pendentes' => $pendentes,
            ]);

            return $vaga;
        });
    }
}
