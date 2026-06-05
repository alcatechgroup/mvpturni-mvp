<?php

namespace App\Http\Controllers\Turno;

use App\Http\Controllers\Controller;
use App\Models\Turno;
use App\Services\PinCheckinEstadoInvalidoException;
use App\Services\PinExpiradoException;
use App\Services\PinInvalidoException;
use App\Services\ValidarCheckoutService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;

/**
 * STORY-064 — POST /api/turnos/{turno}/validar-checkout e /recusar-checkout.
 *
 * Espelho do ValidarCheckinController da 062. RBAC: só o CONTRATANTE do turno (403).
 * Rate limit (CA-4): requests/60s por TURNO (chave própria de check-out — janela
 * independente da do check-in), configurável via env; o limite de domínio (3 erros
 * expiram o PIN → turno volta a `ativo`) vive no ValidarCheckoutService.
 */
class ValidarCheckoutController extends Controller
{
    public function __construct(private readonly ValidarCheckoutService $service) {}

    public function validar(Request $request, Turno $turno): JsonResponse
    {
        $this->autorizar($request, $turno);

        $chave = "validar-checkout:{$turno->id}";
        if (RateLimiter::tooManyAttempts($chave, (int) config('turno.checkout_validacao_max_por_minuto'))) {
            return response()->json(['motivo' => 'rate_limit'], 429);
        }

        $dados = $request->validate([
            'pin' => ['required', 'string', 'regex:/^\d{4}$/'],
        ]);

        RateLimiter::hit($chave, 60); // só request bem-formado conta (formato inválido não)

        try {
            return response()->json($this->service->validar($turno, $dados['pin']));
        } catch (PinInvalidoException) {
            return response()->json(['motivo' => 'pin_invalido'], 422);
        } catch (PinExpiradoException) {
            return response()->json(['motivo' => 'pin_expirado'], 422);
        } catch (PinCheckinEstadoInvalidoException $e) {
            return response()->json(['motivo' => 'estado_invalido', 'estado' => $e->estado], 422);
        }
    }

    public function recusar(Request $request, Turno $turno): JsonResponse
    {
        $this->autorizar($request, $turno);

        $dados = $request->validate([
            'motivo' => ['nullable', 'string', 'max:280'],
        ]);

        try {
            return response()->json($this->service->recusar($turno, $dados['motivo'] ?? null));
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
