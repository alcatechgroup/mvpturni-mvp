<?php

namespace App\Http\Controllers\Turno;

use App\Http\Controllers\Controller;
use App\Models\Turno;
use App\Services\PinCheckinEstadoInvalidoException;
use App\Services\PinCheckinForaDaJanelaException;
use App\Services\PinCheckinService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * STORY-061 — POST /api/turnos/{turno}/gerar-pin-checkin e /cancelar-pin-checkin.
 *
 * RBAC (CA-8): só o PROFISSIONAL do turno — contratante/terceiro recebem 403 (o detalhe
 * já confirmou a existência do turno para as partes; aqui o 403 explicita "não é seu
 * papel", diferente do fail-secure 404 das rotas de leitura cruzada). Regras de janela,
 * estado, hash, geofencing e trilha vivem no PinCheckinService; aqui só HTTP.
 */
class PinCheckinController extends Controller
{
    public function __construct(private readonly PinCheckinService $service) {}

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
        } catch (PinCheckinForaDaJanelaException $e) {
            return response()->json([
                'motivo' => 'fora_da_janela',
                'janela' => ['abre_em' => $e->abreEm, 'fecha_em' => $e->fechaEm],
            ], 422);
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
