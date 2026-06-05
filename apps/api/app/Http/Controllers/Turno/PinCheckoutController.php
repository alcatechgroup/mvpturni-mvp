<?php

namespace App\Http\Controllers\Turno;

use App\Http\Controllers\Controller;
use App\Models\Turno;
use App\Services\PinCheckinEstadoInvalidoException;
use App\Services\PinCheckoutService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * STORY-064 — POST /api/turnos/{turno}/gerar-pin-checkout e /cancelar-pin-checkout.
 *
 * Espelho do PinCheckinController da 061 SEM a janela horária (CA-1 — turno pode
 * estender; gerar em `ativo` é sempre permitido). RBAC: só o PROFISSIONAL do turno —
 * contratante/terceiro recebem 403. Regras de estado, hash, geofencing e trilha vivem
 * no PinCheckoutService; aqui só HTTP.
 */
class PinCheckoutController extends Controller
{
    public function __construct(private readonly PinCheckoutService $service) {}

    public function gerar(Request $request, Turno $turno): JsonResponse
    {
        $this->autorizar($request, $turno);

        $dados = $request->validate([
            'pin_solicitado' => ['required', 'accepted'],
            'lat' => ['nullable', 'numeric', 'between:-90,90'],
            'lng' => ['nullable', 'numeric', 'between:-180,180'],
            'accuracy_m' => ['nullable', 'numeric', 'min:0'],
            'razao' => ['nullable', 'string', 'in:permissao_negada,timeout,indisponivel'],
        ]);

        try {
            return response()->json($this->service->gerar($turno, [
                'lat' => isset($dados['lat']) ? (float) $dados['lat'] : null,
                'lng' => isset($dados['lng']) ? (float) $dados['lng'] : null,
                'accuracy_m' => isset($dados['accuracy_m']) ? (float) $dados['accuracy_m'] : null,
                'razao' => $dados['razao'] ?? null,
            ]));
        } catch (PinCheckinEstadoInvalidoException $e) {
            return response()->json(['motivo' => 'estado_invalido', 'estado' => $e->estado], 422);
        }
    }

    public function cancelar(Request $request, Turno $turno): JsonResponse
    {
        $this->autorizar($request, $turno);

        try {
            return response()->json($this->service->cancelar($turno));
        } catch (PinCheckinEstadoInvalidoException $e) {
            return response()->json(['motivo' => 'estado_invalido', 'estado' => $e->estado], 422);
        }
    }

    private function autorizar(Request $request, Turno $turno): void
    {
        $user = $request->user();
        abort_unless($user !== null && $user->id === $turno->profissional_id && $user->isProfissional(), 403);
    }
}
