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
 * STORY-052 (CA-7/CA-8) — resposta do profissional à edição material da vaga (PDR-009). A
 * candidatura precisa estar em `pendente_revisao_apos_edicao`; em qualquer outro estado a
 * transição falha (DomainException → 409 no controller). Dois desfechos, ambos atômicos:
 *
 *  - **manter** (CA-7): `pendente_revisao_apos_edicao → pendente`, limpa `revisao_prazo_em`,
 *    audit `candidatura.mantida_apos_edicao`.
 *  - **retirar** (CA-8): `pendente_revisao_apos_edicao → retirada_por_edicao`, audit
 *    `candidatura.retirada_por_edicao_voluntaria`.
 *
 * A autorização (ser o profissional dono) é do controller. Aqui só executa quando chamado.
 *
 * @throws DomainException quando a candidatura não está em revisão (transição inválida).
 */
class RevisarCandidaturaService
{
    public function __construct(private readonly Request $request) {}

    public function manter(Candidatura $candidatura): Candidatura
    {
        return DB::transaction(function () use ($candidatura) {
            // Fail-closed: fora de `pendente_revisao_apos_edicao`, transitionTo lança → 409.
            $candidatura->revisao_prazo_em = null;
            $candidatura->transitionTo(CandidaturaEstado::Pendente);

            $this->audit($candidatura, 'candidatura.mantida_apos_edicao');
            $this->telemetria('candidatura.mantida_apos_edicao', $candidatura);

            return $candidatura;
        });
    }

    public function retirar(Candidatura $candidatura): Candidatura
    {
        return DB::transaction(function () use ($candidatura) {
            $candidatura->transitionTo(CandidaturaEstado::RetiradaPorEdicao);

            $this->audit($candidatura, 'candidatura.retirada_por_edicao_voluntaria');
            $this->telemetria('candidatura.retirada_por_edicao_voluntaria', $candidatura);

            return $candidatura;
        });
    }

    private function audit(Candidatura $candidatura, string $action): void
    {
        AuditLog::create([
            'actor_id' => $candidatura->profissional_id,
            'action' => $action,
            'target_type' => 'Candidatura',
            'target_id' => $candidatura->id,
            'payload' => ['vaga_id' => $candidatura->vaga_id],
            'ip' => $this->request->ip(),
            'user_agent' => $this->request->userAgent(),
        ]);
    }

    private function telemetria(string $event, Candidatura $candidatura): void
    {
        Log::info($event, [
            'event' => $event,
            'candidatura_id' => $candidatura->id,
            'vaga_id' => $candidatura->vaga_id,
            'profissional_id' => $candidatura->profissional_id,
        ]);
    }
}
