<?php

namespace App\Http\Controllers\Vaga;

use App\Enums\CandidaturaEstado;
use App\Enums\VagaEstado;
use App\Http\Controllers\Controller;
use App\Http\Requests\StoreVagaRequest;
use App\Http\Requests\UpdateVagaRequest;
use App\Models\Vaga;
use App\Services\CancelarVagaService;
use App\Services\EditarVagaService;
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
     * STORY-052 CA-10 — carrega os valores atuais da vaga para o formulário de edição
     * (`/contratante/vagas/{id}/editar`) + a contagem de candidatos pendentes que serão avisados.
     * RBAC: só o contratante dono (403 caso contrário); vaga inexistente → 404 (model binding).
     * Não recalcula nada — devolve o estado material vigente para pré-preencher o form de 046.
     */
    public function editar(Request $request, Vaga $vaga): JsonResponse
    {
        $user = $request->user();
        abort_unless($user !== null && $user->isContratante() && $vaga->contratante_id === $user->id, 403);

        $candidatosEmRevisao = $vaga->candidaturas()
            ->whereIn('estado', [CandidaturaEstado::Pendente, CandidaturaEstado::PendenteRevisaoAposEdicao])
            ->count();

        return response()->json([
            'id' => $vaga->id,
            'estado' => $vaga->estado->value,
            'editavel' => $vaga->estado === VagaEstado::Aberta,
            'funcao_id' => $vaga->funcao_id,
            'data_inicio' => $vaga->data_inicio->toIso8601String(),
            'data_fim' => $vaga->data_fim->toIso8601String(),
            'valor' => (float) $vaga->valor,
            'posicoes' => $vaga->posicoes,
            'observacoes' => $vaga->observacoes,
            'candidatos_em_revisao' => $candidatosEmRevisao,
        ]);
    }

    /**
     * STORY-052 CA-1/CA-3/CA-4/CA-5 — edita a vaga (PDR-009). RBAC (papel contratante) no
     * UpdateVagaRequest::authorize(); a posse (ser o dono) é verificada aqui (403). O detector de
     * edição material, o snapshot, a transição das candidaturas pendentes, o audit e o evento
     * `VagaEditadaMaterialmente` ficam no EditarVagaService. Vaga fora de `aberta` → 409. O
     * response descreve o diff + quantos candidatos foram notificados (contrato do passo de
     * confirmação do WebApp — SCREEN-052 §10).
     */
    public function update(UpdateVagaRequest $request, Vaga $vaga, EditarVagaService $editar): JsonResponse
    {
        $user = $request->user();
        abort_unless($vaga->contratante_id === $user->id, 403);

        try {
            $resultado = $editar->editar($user, $vaga, $request->validated());
        } catch (DomainException) {
            return response()->json(['message' => 'Esta vaga não pode mais ser editada.'], 409);
        }

        return response()->json([
            'id' => $resultado->vaga->id,
            'estado' => $resultado->vaga->estado->value,
            'material' => $resultado->material,
            'diff' => $resultado->diff,
            'candidatos_notificados' => count($resultado->candidatosNotificadosIds),
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
