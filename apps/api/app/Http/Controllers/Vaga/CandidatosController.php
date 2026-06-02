<?php

namespace App\Http\Controllers\Vaga;

use App\Enums\CandidaturaEstado;
use App\Http\Controllers\Controller;
use App\Models\Candidatura;
use App\Models\ProfissionalProfile;
use App\Models\Vaga;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Throwable;

/**
 * STORY-051 — painel de candidatos do contratante (GET /api/vagas/{vaga}/candidatos).
 *
 * Lado **espelho** do feed/detalhe do profissional: lista os candidatos `pendentes` da vaga
 * ranqueados por score, com o **mesmo** breakdown que o profissional viu (simetria de
 * `domain/match.md`). RBAC (CA-1): só o **contratante dono** da vaga; profissional ou
 * contratante não-dono → 403; vaga inexistente → 404 (model binding).
 *
 * O score e o breakdown são o **snapshot persistido** no instante da candidatura (STORY-050 +
 * a coluna `score_breakdown` desta estória) — a UI **não recalcula** (CA-2/CA-4); preserva o
 * porquê histórico mesmo que vaga/perfil mudem depois (ADR-014: match on-demand). Aprovar/recusar
 * é EPIC-003 — esta estória só **lê**.
 */
class CandidatosController extends Controller
{
    /**
     * Estados que representam um candidato vivo aguardando a decisão do contratante (CA-1).
     * `recusada` é Lacuna do MVP; `retirada`/`retirada_por_edicao`/`aprovada` não entram no painel.
     */
    private const ESTADOS_PENDENTES = [
        CandidaturaEstado::Pendente,
        CandidaturaEstado::PendenteRevisaoAposEdicao,
    ];

    public function index(Request $request, Vaga $vaga): JsonResponse
    {
        $user = $request->user();
        // RBAC (CA-1): contratante dono. Não-dono e profissional → 403 (não vaza a existência
        // dos candidatos para quem não é dono da vaga).
        abort_unless(
            $user !== null && $user->isContratante() && $vaga->contratante_id === $user->id,
            403,
        );

        // Ordenação (CA-2): score DESC, boost de plano DESC, candidatou_em ASC. O boost é stub
        // (ADR-014 Decisão 3 — sem plano do profissional modelado, todos empatam em 0), então a
        // ordem efetiva cai para score e data; mantemos o critério explícito p/ quando existir.
        // NULLS LAST mantém candidaturas legadas sem snapshot (nenhuma no MVP) no fim da lista.
        $candidaturas = Candidatura::query()
            ->where('vaga_id', $vaga->id)
            ->whereIn('estado', self::ESTADOS_PENDENTES)
            ->with(['profissional.profissionalProfile.funcao'])
            ->orderByRaw('score_no_momento DESC NULLS LAST')
            ->orderBy('created_at')
            ->get();

        return response()->json([
            'candidatos' => $candidaturas->map(fn (Candidatura $c) => $this->serializar($c))->all(),
            'total' => $candidaturas->count(),
        ]);
    }

    /** @return array<string,mixed> */
    private function serializar(Candidatura $candidatura): array
    {
        $profissional = $candidatura->profissional;
        $perfil = $profissional?->profissionalProfile;

        return [
            'id' => $candidatura->id,
            'profissional' => [
                'id' => $profissional?->id,
                'nome' => $profissional?->name,
                'foto_url' => $this->fotoUrl($perfil),
                'funcao_primaria' => $perfil?->funcao?->nome,
                // Rótulo da trilha (Iniciante/Confiável/Destaque/Elite) — persistido no perfil.
                'nivel' => $perfil?->nivel,
                'score_historico' => $perfil?->score !== null ? (float) $perfil->score : null,
                // Stub (STORY-045 CA-5): plano do profissional (Turni Ads/Turnificado) não está
                // modelado — sempre null; o badge da UI é slot pronto, sem render no MVP.
                'plano' => null,
            ],
            'score_no_momento' => $candidatura->score_no_momento,
            'score_breakdown' => $candidatura->score_breakdown,
            'candidatou_em' => $candidatura->created_at?->toIso8601String(),
            'alerta_habitualidade' => (bool) $candidatura->alerta_habitualidade,
        ];
    }

    /**
     * URL da foto do profissional (best-effort). A foto fica em disco privado (`store(...)` no
     * cadastro) que não serve URL pública no MVP — a UI cai para iniciais (fail-soft, SCREEN-051
     * §4/§8). Guardado para nunca quebrar a listagem por causa do avatar.
     */
    private function fotoUrl(?ProfissionalProfile $perfil): ?string
    {
        $path = $perfil?->foto_path;
        if ($path === null || $path === '') {
            return null;
        }

        try {
            return Storage::url($path);
        } catch (Throwable) {
            return null;
        }
    }
}
