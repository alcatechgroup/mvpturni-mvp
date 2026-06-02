<?php

namespace App\Http\Controllers\Vaga;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreVagaRequest;
use App\Services\PublicarVagaService;
use Illuminate\Http\JsonResponse;

/**
 * STORY-046 — publicação de vaga pelo contratante (CA-6). O RBAC (CA-1) vem do
 * authorize() do StoreVagaRequest (403 para não-contratante); o status=ativo é
 * garantido pelo FunnelGuard na rota. A criação atômica (vaga + versão 1 + audit +
 * telemetria) é do PublicarVagaService.
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
}
