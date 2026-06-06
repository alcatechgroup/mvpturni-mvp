<?php

namespace App\Http\Controllers\Turno;

use App\Http\Controllers\Controller;
use App\Models\Turno;
use App\Services\CancelarTurnoService;
use App\Services\TurnoNaoCancelavelException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * STORY-066 (CA-2) — POST /api/turnos/{turno}/cancelar, rota compartilhada pelos 2 papéis.
 *
 * RBAC (fail-secure, espelho do TurnoDetalheController): só o profissional OU o contratante
 * DESTE turno (403 cruzado). O lado da transição vem de quem cancelou — RBAC decide
 * `cancelado_pro` vs `cancelado_emp` (CA-2). Estado ≠ confirmado → 422 estado_invalido
 * (a UI recarrega a verdade — SCREEN-066 §A.6). Motivo opcional ≤280 (mesmo limite das
 * recusas 062/064).
 */
class CancelarTurnoController extends Controller
{
    public function __construct(private readonly CancelarTurnoService $service) {}

    public function cancelar(Request $request, Turno $turno): JsonResponse
    {
        $user = $request->user();
        $souProfissional = $user !== null && $user->id === $turno->profissional_id && $user->isProfissional();
        $souContratante = $user !== null && $user->id === $turno->contratante_id && $user->isContratante();

        abort_unless($souProfissional || $souContratante, 403); // cruzados 403 (fail-secure)

        $dados = $request->validate([
            'motivo' => ['nullable', 'string', 'max:280'],
        ]);

        try {
            return response()->json($this->service->cancelar($turno, $user, $dados['motivo'] ?? null));
        } catch (TurnoNaoCancelavelException $e) {
            return response()->json(['motivo' => 'estado_invalido', 'estado' => $e->estado], 422);
        }
    }
}
