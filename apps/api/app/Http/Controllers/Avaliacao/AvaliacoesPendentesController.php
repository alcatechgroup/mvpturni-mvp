<?php

namespace App\Http\Controllers\Avaliacao;

use App\Domain\Avaliacao\AvaliacoesPendentesContratante;
use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * STORY-046 CA-5 / PDR-005 — gate de publicação: o WebApp consulta este endpoint antes
 * de montar o formulário. RBAC (CA-1): só contratante (403 caso contrário); o FunnelGuard
 * já garante status=ativo na rota. Contrato: { pending: int, turnos: [...] }.
 */
class AvaliacoesPendentesController extends Controller
{
    public function __construct(private readonly AvaliacoesPendentesContratante $service) {}

    public function index(Request $request): JsonResponse
    {
        $user = $request->user();

        abort_unless(
            $user !== null && $user->isContratante(),
            403,
            'Apenas contratante consulta avaliações pendentes para publicar.',
        );

        return response()->json($this->service->para($user));
    }
}
