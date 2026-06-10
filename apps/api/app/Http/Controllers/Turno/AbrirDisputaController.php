<?php

namespace App\Http\Controllers\Turno;

use App\Http\Controllers\Controller;
use App\Models\Turno;
use App\Services\AbrirDisputaService;
use App\Services\DisputaSemJustificativaException;
use App\Services\PinCheckinEstadoInvalidoException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * STORY-092 / ADR-020 (Decisão 2) — POST /api/turnos/{turno}/abrir-disputa.
 *
 * O ramo "contestar por mérito" do check-out, DISTINTO de /recusar-checkout (que devolve a
 * `ativo`). Transita `aguardando_checkout → em_disputa` com justificativa OBRIGATÓRIA e mantém
 * a pré-autorização bloqueada. RBAC (CA-5, fail-secure): só o CONTRATANTE dono do turno; o
 * profissional, outro contratante ou não-papel recebem 403; não autenticado 401. Espelha o
 * ValidarCheckoutController.
 */
class AbrirDisputaController extends Controller
{
    public function __construct(private readonly AbrirDisputaService $service) {}

    public function abrir(Request $request, Turno $turno): JsonResponse
    {
        $this->autorizar($request, $turno);

        $dados = $request->validate([
            'justificativa' => ['required', 'string', 'max:2000'],
        ]);

        try {
            return response()->json($this->service->abrir($turno, $dados['justificativa']));
        } catch (DisputaSemJustificativaException) {
            return response()->json(['motivo' => 'justificativa_obrigatoria'], 422);
        } catch (PinCheckinEstadoInvalidoException $e) {
            return response()->json(['motivo' => 'estado_invalido', 'estado' => $e->estado], 422);
        }
    }

    private function autorizar(Request $request, Turno $turno): void
    {
        $user = $request->user();
        abort_unless($user !== null && $user->id === $turno->contratante_id && $user->isContratante(), 403);
    }
}
