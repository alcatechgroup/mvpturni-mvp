<?php

namespace App\Http\Controllers\Candidatura;

use App\Http\Controllers\Controller;
use App\Models\Candidatura;
use App\Services\AprovarCandidaturaService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * STORY-058 (CA-1) — POST /api/candidaturas/{candidatura}/aprovar.
 *
 * RBAC: só o CONTRATANTE DONO da vaga aprova (decisão PO 2026-06-04 — corrige o "Backoffice"
 * do texto original; quem aprova é o contratante no WebApp, domain/candidatura.md §aprovação).
 * Profissional e contratante não-dono → 403 (não vaza decisão alheia); inexistente → 404.
 * Corpo: `{ override?: bool }` — exigido na 3ª alocação semanal de MEI/PJ (PDR-002/CA-4).
 *
 * Desfechos (contrato da SCREEN-058 §10): 201 turno; 409 ja_aprovada (idempotência CA-5);
 * 422 habitualidade_bloqueio | requer_override | vaga_fechada | candidatura_invalida.
 */
class AprovarCandidaturaController extends Controller
{
    public function __invoke(Request $request, Candidatura $candidatura, AprovarCandidaturaService $service): JsonResponse
    {
        $user = $request->user();
        abort_unless(
            $user !== null && $user->isContratante() && $candidatura->vaga->contratante_id === $user->id,
            403,
        );

        $validado = $request->validate(['override' => ['sometimes', 'boolean']]);

        $resultado = $service->aprovar($user, $candidatura, (bool) ($validado['override'] ?? false));

        if ($resultado->turno !== null) {
            $turno = $resultado->turno;

            return response()->json([
                'turno' => [
                    'id' => $turno->id,
                    'status' => $turno->status->value,
                    'valor' => $turno->valor,
                    'taxa_turni' => $turno->taxa_turni,
                    'total_contratante' => $turno->total_contratante,
                ],
            ], 201);
        }

        if ($resultado->erro === 'ja_aprovada') {
            return response()->json([
                'erro' => 'ja_aprovada',
                'turno_id' => $resultado->turnoIdExistente,
            ], 409);
        }

        return response()->json([
            'erro' => $resultado->erro,
            'mensagem' => $resultado->mensagem,
        ], 422);
    }
}
