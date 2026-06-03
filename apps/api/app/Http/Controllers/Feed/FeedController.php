<?php

namespace App\Http\Controllers\Feed;

use App\Domain\Avaliacao\AvaliacoesPendentesProfissional;
use App\Domain\Feed\FeedFiltro;
use App\Domain\Feed\FeedQuery;
use App\Domain\Feed\FeedVaga;
use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * STORY-048 — feed ranqueado do profissional (GET /api/feed). RBAC (CA-1): só `profissional`
 * (status=ativo garantido pelo FunnelGuard na rota); contratante → 403. A visibilidade,
 * distância, ranqueamento e telemetria ficam no FeedQuery (ADR-013/ADR-014); aqui só RBAC,
 * leitura de parâmetros, gate PDR-005 e serialização do contrato.
 */
class FeedController extends Controller
{
    public function __construct(private readonly FeedQuery $feed) {}

    public function index(Request $request, AvaliacoesPendentesProfissional $gate): JsonResponse
    {
        $user = $request->user();
        abort_unless($user !== null && $user->isProfissional(), 403);

        $filtro = FeedFiltro::fromParam($request->query('filtro'));
        $page = (int) $request->query('page', '1');

        $resultado = $this->feed->paraProfissional($user, $filtro, $page);

        // Gate PDR-005 (CA-8): uniforme por request — o feed permanece visível, só a AÇÃO de
        // candidatar é bloqueada. Marcado em cada vaga para a UI desabilitar o botão.
        $podeCandidatar = $gate->podeCandidatar($user);

        return response()->json([
            'vagas' => array_map(
                fn (FeedVaga $fv) => $this->serializar($fv, $podeCandidatar),
                $resultado->vagas,
            ),
            'page' => $resultado->page,
            'has_next' => $resultado->hasNext,
        ]);
    }

    /** @return array<string,mixed> */
    private function serializar(FeedVaga $fv, bool $podeCandidatar): array
    {
        $vaga = $fv->vaga;

        return [
            'id' => $vaga->id,
            'funcao' => $vaga->funcao?->nome,
            'data_inicio' => $vaga->data_inicio->toIso8601String(),
            'data_fim' => $vaga->data_fim->toIso8601String(),
            'valor' => (float) $vaga->valor,
            'distancia_km' => $fv->distanciaKm !== null ? round($fv->distanciaKm, 1) : null,
            'score' => [
                'total' => $fv->score->total,
                'componentes' => $fv->score->componentes,
            ],
            'ja_candidatou' => $fv->jaCandidatou,
            // STORY-052 CA-11 — selo "Vaga editada — confirme" no card (sem abrir o detalhe).
            'em_revisao' => $fv->emRevisao,
            'pode_candidatar' => $podeCandidatar,
        ];
    }
}
