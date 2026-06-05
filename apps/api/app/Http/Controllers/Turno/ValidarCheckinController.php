<?php

namespace App\Http\Controllers\Turno;

use App\Http\Controllers\Controller;
use App\Models\Turno;
use App\Services\PinCheckinEstadoInvalidoException;
use App\Services\PinExpiradoException;
use App\Services\PinInvalidoException;
use App\Services\ValidarCheckinService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;

/**
 * STORY-062 — POST /api/turnos/{turno}/validar-checkin e /recusar-checkin.
 *
 * RBAC (CA-1): só o CONTRATANTE do turno — profissional/terceiro recebem 403 (espelho
 * do PinCheckinController da 061, que só aceita o profissional). Rate limit (CA-2):
 * 5 requests/60s por TURNO (chave = turno_id UUID — ADR-018), configurável via env;
 * proteção de borda contra força bruta — o limite de domínio (3 erros expiram o PIN)
 * vive no ValidarCheckinService. Regras de hash, transição e trilha no service.
 */
class ValidarCheckinController extends Controller
{
    public function __construct(private readonly ValidarCheckinService $service) {}

    public function validar(Request $request, Turno $turno): JsonResponse
    {
        $this->autorizar($request, $turno);

        $chave = "validar-checkin:{$turno->id}";
        if (RateLimiter::tooManyAttempts($chave, (int) config('turno.checkin_validacao_max_por_minuto'))) {
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
