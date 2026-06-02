<?php

namespace App\Http\Controllers\Vaga;

use App\Enums\CandidaturaEstado;
use App\Http\Controllers\Controller;
use App\Http\Requests\StoreVagaRequest;
use App\Models\Vaga;
use App\Services\CancelarVagaService;
use App\Services\PublicarVagaService;
use DomainException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * STORY-046/047 — vagas do contratante. RBAC (CA-1) na publicação vem do authorize()
 * do StoreVagaRequest; nas leituras/cancelamento é verificado aqui (papel + dono). O
 * status=ativo é garantido pelo FunnelGuard na rota. Criação/cancelamento atômicos
 * ficam nos services (vaga + versão/transição + audit + evento + telemetria).
 */
class VagaController extends Controller
{
    public function __construct(private readonly PublicarVagaService $service) {}

    public function store(StoreVagaRequest $request): JsonResponse
    {
        $vaga = $this->service->publicar($request->user(), $request->validated());

        return response()->json([
            'id' => $vaga->id,
            'estado' => $vaga->estado->value,
            'funcao_id' => $vaga->funcao_id,
            'data_inicio' => $vaga->data_inicio->toIso8601String(),
            'data_fim' => $vaga->data_fim->toIso8601String(),
            'valor' => (float) $vaga->valor,
            'posicoes' => $vaga->posicoes,
            'observacoes' => $vaga->observacoes,
            'cidade' => $vaga->cidade,
            'uf' => $vaga->uf,
        ], 201);
    }

    /**
     * STORY-047 CA-1/CA-2 — lista as vagas do contratante autenticado (só as próprias).
     * Devolve todos os estados; o filtro ("Ativas"/abertas/…) é client-side (a estória não
     * pede paginação). Cada item traz o necessário ao card, incluindo a contagem de
     * candidatos pendentes.
     */
    public function minhas(Request $request): JsonResponse
    {
        $user = $request->user();
        abort_unless($user !== null && $user->isContratante(), 403);

        $vagas = Vaga::query()
            ->where('contratante_id', $user->id)
            ->with('funcao:id,nome')
            ->withCount(['candidaturas as candidatos_pendentes' => fn ($q) => $q->where('estado', CandidaturaEstado::Pendente)])
            ->orderBy('data_inicio')
            ->get();

        return response()->json([
            'data' => $vagas->map(fn (Vaga $vaga) => [
                'id' => $vaga->id,
                'funcao' => $vaga->funcao?->nome,
                'funcao_id' => $vaga->funcao_id,
                'data_inicio' => $vaga->data_inicio->toIso8601String(),
                'data_fim' => $vaga->data_fim->toIso8601String(),
                'valor' => (float) $vaga->valor,
                'posicoes' => $vaga->posicoes,
                'posicoes_preenchidas' => $vaga->posicoes_preenchidas,
                'estado' => $vaga->estado->value,
                'candidatos_pendentes' => (int) $vaga->candidatos_pendentes,
            ])->all(),
        ]);
    }

    /**
     * STORY-047 CA-4/CA-5 — cancela uma vaga (soft, transição aberta→cancelada). RBAC:
     * só o contratante dono (403 caso contrário). Transição fora de `aberta` → 409. O
     * audit `vaga.cancelada` + evento `VagaCancelada` ficam no CancelarVagaService.
     */
    public function destroy(Request $request, Vaga $vaga, CancelarVagaService $cancelar): JsonResponse
    {
        $user = $request->user();
        abort_unless($user !== null && $user->isContratante() && $vaga->contratante_id === $user->id, 403);

        try {
            $cancelar->cancelar($vaga);
        } catch (DomainException) {
            // Transição inválida (vaga não está mais `aberta`) — fail-closed.
            return response()->json(['message' => 'Esta vaga não pode mais ser cancelada.'], 409);
        }

        return response()->json([
            'id' => $vaga->id,
            'estado' => $vaga->estado->value,
        ]);
    }
}
