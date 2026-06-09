<?php

namespace App\Http\Controllers\Turno;

use App\Enums\AvaliacaoDirecao;
use App\Enums\TurnoStatus;
use App\Http\Controllers\Controller;
use App\Models\Turno;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * STORY-059 — listas "Meus turnos" (profissional) e "Turnos" (contratante).
 *
 * GET /api/profissional/turnos e GET /api/contratante/turnos devolvem os turnos do usuário
 * autenticado AGRUPADOS por estado (CA-1/CA-2), na ordem fixa do ciclo de vida de
 * domain/turno.md (SCREEN-059 §4.1). O servidor entrega ordenado — o front não reordena:
 * grupos "futuros" (confirmado → aguardando_checkout) por data_inicio ascendente; grupos
 * "passados" (em_disputa, finalizado, encerrado) por data_fim descendente. Grupo vazio é
 * omitido da resposta.
 *
 * Visibilidade financeira (PDR-004 / domain/pagamento.md): o profissional vê `valor` (o que
 * recebe); o contratante vê `total_contratante` (valor + taxa). RBAC fail-secure (CA-5): 403
 * para o papel errado em cada rota.
 */
class TurnosController extends Controller
{
    /**
     * Ordem fixa das seções (SCREEN-059 §4.1). `em_disputa` é seção própria — decisão do PO
     * em chat (2026-06-05): turno em disputa não pode ficar invisível para as partes.
     * `asc` = grupos voltados ao futuro (próximo turno primeiro); `desc` = histórico
     * (mais recente primeiro).
     */
    private const GRUPOS = [
        'confirmado' => [[TurnoStatus::Confirmado], 'asc'],
        'aguardando_checkin' => [[TurnoStatus::AguardandoCheckin], 'asc'],
        'ativo' => [[TurnoStatus::Ativo], 'asc'],
        'aguardando_checkout' => [[TurnoStatus::AguardandoCheckout], 'asc'],
        'em_disputa' => [[TurnoStatus::EmDisputa], 'desc'],
        'finalizado' => [[TurnoStatus::Finalizado, TurnoStatus::FinalizadoAjustado], 'desc'],
        'encerrado' => [[
            TurnoStatus::CanceladoPro,
            TurnoStatus::CanceladoEmp,
            TurnoStatus::NoShowPro,
            TurnoStatus::DisputaResolvidaSemPagamento,
        ], 'desc'],
    ];

    /** CA-1 — turnos do profissional autenticado. 403 fail-secure para contratante (CA-5). */
    public function doProfissional(Request $request): JsonResponse
    {
        $user = $request->user();
        abort_unless($user !== null && $user->isProfissional(), 403);

        $turnos = Turno::query()
            ->where('profissional_id', $user->id)
            ->with(['vaga.funcao:id,nome', 'contratante.contratanteProfile', 'avaliacoes:id,turno_id,direcao'])
            ->get();

        return response()->json([
            'grupos' => $this->agrupar($turnos, fn (Turno $t) => [
                'id' => $t->id,
                'funcao' => $t->vaga?->funcao?->nome,
                'data_inicio' => $t->data_inicio->toIso8601String(),
                'data_fim' => $t->data_fim->toIso8601String(),
                'estado' => $t->status->value,
                'valor' => (float) $t->valor,
                // STORY-088 — marca na lista os turnos que o PROFISSIONAL ainda precisa avaliar
                // (direção dele): finalizado/ajustado sem avaliação `profissional_para_contratante`.
                'avaliacao_pendente' => $this->avaliacaoPendente($t, AvaliacaoDirecao::ProfissionalParaContratante),
                'estabelecimento' => ['nome' => $this->nomeEstabelecimento($t)],
            ]),
        ]);
    }

    /** CA-2 — espelho: turnos das vagas do contratante. 403 fail-secure para profissional. */
    public function doContratante(Request $request): JsonResponse
    {
        $user = $request->user();
        abort_unless($user !== null && $user->isContratante(), 403);

        $turnos = Turno::query()
            ->where('contratante_id', $user->id)
            ->with(['vaga.funcao:id,nome', 'profissional:id,name', 'avaliacoes:id,turno_id,direcao'])
            ->get();

        return response()->json([
            'grupos' => $this->agrupar($turnos, fn (Turno $t) => [
                'id' => $t->id,
                'funcao' => $t->vaga?->funcao?->nome,
                'data_inicio' => $t->data_inicio->toIso8601String(),
                'data_fim' => $t->data_fim->toIso8601String(),
                'estado' => $t->status->value,
                'total_contratante' => (float) $t->total_contratante,
                // STORY-088 — espelho: direção do CONTRATANTE (`contratante_para_profissional`).
                'avaliacao_pendente' => $this->avaliacaoPendente($t, AvaliacaoDirecao::ContratanteParaProfissional),
                'profissional' => ['nome' => $t->profissional?->name],
            ]),
        ]);
    }

    /**
     * Agrupa na ordem fixa de GRUPOS e ordena dentro do grupo (CA-1). Devolve lista de
     * `{ grupo, turnos }` — array (não objeto) para a ordem das seções sobreviver ao JSON.
     */
    private function agrupar(Collection $turnos, callable $mapItem): array
    {
        $grupos = [];

        foreach (self::GRUPOS as $slug => [$estados, $direcao]) {
            $doGrupo = $turnos->filter(fn (Turno $t) => in_array($t->status, $estados, true));

            if ($doGrupo->isEmpty()) {
                continue; // seção vazia é omitida (SCREEN-059 §4.1)
            }

            $doGrupo = $direcao === 'asc'
                ? $doGrupo->sortBy('data_inicio')
                : $doGrupo->sortByDesc('data_fim');

            $grupos[] = [
                'grupo' => $slug,
                'turnos' => $doGrupo->map($mapItem)->values()->all(),
            ];
        }

        return $grupos;
    }

    /**
     * STORY-088 / ADR-019 D2 — o turno está pendente de avaliação para ESTE usuário (direção dada)
     * sse está em estado avaliável (`finalizado`/`finalizado_ajustado`) e ainda não há avaliação na
     * direção dele. Derivado do estado (sem tabela de pendências), coerente com o gate PDR-005.
     * Usa as `avaliacoes` já eager-loaded (sem N+1).
     */
    private function avaliacaoPendente(Turno $turno, AvaliacaoDirecao $direcao): bool
    {
        if (! in_array($turno->status, [TurnoStatus::Finalizado, TurnoStatus::FinalizadoAjustado], true)) {
            return false;
        }

        return ! $turno->avaliacoes->contains(fn ($a) => $a->direcao === $direcao);
    }

    /**
     * Mesma regra de exibição do detalhe da vaga (STORY-049): apelido quando houver. Fallback
     * final: `name` do contratante (estabelecimento = contratante, convenção MVP) — contratante
     * sem ContratanteProfile (ex.: seeds, contas antigas) não pode deixar o card sem "onde".
     */
    private function nomeEstabelecimento(Turno $turno): ?string
    {
        $perfil = $turno->contratante?->contratanteProfile;

        return $perfil?->apelido_estabelecimento
            ?: $perfil?->nome_estabelecimento
            ?: $turno->contratante?->name;
    }
}
