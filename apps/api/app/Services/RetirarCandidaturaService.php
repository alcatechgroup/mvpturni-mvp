<?php

namespace App\Services;

use App\Enums\CandidaturaEstado;
use App\Models\AuditLog;
use App\Models\Candidatura;
use DomainException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * STORY-050 (CA-8) — retirada voluntária de candidatura pelo profissional dono. Só uma
 * candidatura `pendente` pode ser retirada por aqui; em qualquer outro estado a transição
 * falha (DomainException, que o controller traduz em 409 — SCREEN-050 §4.9). Atômico:
 *  1. transita `pendente → retirada` (carimba `retirada_em` — Candidatura::transitionTo);
 *  2. registra `candidatura.retirada` em `audit_logs`;
 *  3. emite telemetria estruturada `candidatura.retirada` (ADR-008).
 *
 * A autorização (ser o profissional dono) é do controller. Aqui só retira quando chamado.
 *
 * @throws DomainException quando a candidatura não está em estado retirável (≠ pendente).
 */
class RetirarCandidaturaService
{
    public function __construct(private readonly Request $request) {}

    public function retirar(Candidatura $candidatura): Candidatura
    {
        return DB::transaction(function () use ($candidatura) {
            // Fail-closed: fora de `pendente`, transitionTo lança DomainException → 409.
            $candidatura->transitionTo(CandidaturaEstado::Retirada);

            AuditLog::create([
                'actor_id' => $candidatura->profissional_id,
                'action' => 'candidatura.retirada',
                'target_type' => 'Candidatura',
                'target_id' => $candidatura->id,
                'payload' => ['vaga_id' => $candidatura->vaga_id],
                'ip' => $this->request->ip(),
                'user_agent' => $this->request->userAgent(),
            ]);

            Log::info('candidatura.retirada', [
                'event' => 'candidatura.retirada',
                'candidatura_id' => $candidatura->id,
                'vaga_id' => $candidatura->vaga_id,
                'profissional_id' => $candidatura->profissional_id,
            ]);

            return $candidatura;
        });
    }
}
