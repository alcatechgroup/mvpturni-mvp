<?php

namespace App\Http\Controllers\Candidatura;

use App\Http\Controllers\Controller;
use App\Models\Candidatura;
use App\Models\Vaga;
use App\Services\CriarCandidaturaService;
use App\Services\RetirarCandidaturaService;
use DomainException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * STORY-050 — candidatura em 1 toque com 3 gates (POST) + retirada voluntária (DELETE).
 *
 * RBAC (CA-1): só `profissional` (status=ativo garantido pelo FunnelGuard na rota); contratante
 * → 403. Os 3 gates (PDR-005 avaliação, conflito de horário, habitualidade PDR-002), a
 * idempotência (CA-6) e o snapshot de score (CA-1) ficam no CriarCandidaturaService; aqui só
 * RBAC e a tradução do desfecho para HTTP. Nenhum texto técnico vaza: a `mensagem` de cada
 * gate é prosa pronta para o usuário (CA-9).
 */
class CandidaturaController extends Controller
{
    /** POST /api/vagas/{vaga}/candidaturas — cria a candidatura ou bloqueia por gate (CA-1..CA-6). */
    public function store(Request $request, Vaga $vaga, CriarCandidaturaService $service): JsonResponse
    {
        $user = $request->user();
        abort_unless($user !== null && $user->isProfissional(), 403);

        $resultado = $service->criar($user, $vaga);

        if (! $resultado->sucesso()) {
            return response()->json(array_filter([
                'erro' => $resultado->erro,
                'mensagem' => $resultado->mensagem,
                'detalhe' => $resultado->detalhe,
            ], static fn ($v) => $v !== null), $resultado->status);
        }

        $candidatura = $resultado->candidatura;

        return response()->json([
            'id' => $candidatura->id,
            'estado' => $candidatura->estado->value,
            'score_no_momento' => $candidatura->score_no_momento,
            'candidatou_em' => $candidatura->created_at?->toIso8601String(),
            'alerta' => $resultado->alerta,
        ], 201);
    }

    /** DELETE /api/candidaturas/{candidatura} — retirada voluntária pelo dono (CA-8). */
    public function destroy(Request $request, Candidatura $candidatura, RetirarCandidaturaService $service): JsonResponse
    {
        $user = $request->user();
        abort_unless($user !== null && $user->isProfissional(), 403);
        // Só o dono retira a própria candidatura (404 esconde a existência p/ terceiros).
        abort_unless($candidatura->profissional_id === $user->id, 404);

        try {
            $service->retirar($candidatura);
        } catch (DomainException) {
            return response()->json([
                'erro' => 'estado_invalido',
                'mensagem' => 'Esta candidatura não pode mais ser retirada.',
            ], 409);
        }

        return response()->json(['estado' => $candidatura->estado->value]);
    }
}
