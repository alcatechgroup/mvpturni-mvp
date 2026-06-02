<?php

namespace App\Services;

use App\Domain\Candidatura\CriarCandidaturaResultado;
use App\Domain\Candidatura\Gates\GateAvaliacao;
use App\Domain\Candidatura\Gates\GateConflitoHorario;
use App\Domain\Candidatura\Gates\GateHabitualidade;
use App\Domain\Match\MatchScore;
use App\Domain\Match\MatchScoring;
use App\Enums\CandidaturaEstado;
use App\Enums\VagaEstado;
use App\Events\CandidaturaEnviada;
use App\Models\AuditLog;
use App\Models\Candidatura;
use App\Models\User;
use App\Models\Vaga;
use App\Models\VagaVersao;
use App\Support\Geo\Haversine;
use App\Support\Telemetry\MatchEvents;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * STORY-050 — cria a candidatura de um profissional a uma vaga aplicando os 3 gates server-side
 * (ordem barato→caro: pré-condições → idempotência → conflito → habitualidade → avaliação) e,
 * se liberado, persiste de forma atômica:
 *  1. cria (ou reativa, se houvera retirada anterior) a `candidaturas` em `pendente` com o
 *     `score_no_momento` (snapshot do match — CA-1);
 *  2. registra o evento de domínio `candidatura.criada` em `audit_logs` (CA-7);
 *  3. emite a telemetria estruturada `match.candidatura_enviada` (helper STORY-045 / CA-7);
 *  4. dispara o evento `CandidaturaEnviada` (consumido por STORY-053 — notificar contratante).
 *
 * A autorização (papel profissional `ativo`) é do controller/rota. Aqui só decide e cria.
 */
class CriarCandidaturaService
{
    public function __construct(
        private readonly Request $request,
        private readonly GateAvaliacao $gateAvaliacao,
        private readonly GateConflitoHorario $gateConflito,
        private readonly GateHabitualidade $gateHabitualidade,
        private readonly MatchScoring $scoring = new MatchScoring,
    ) {}

    public function criar(User $profissional, Vaga $vaga): CriarCandidaturaResultado
    {
        // CA-5 — pré-condições básicas: vaga aberta e com início no futuro.
        if ($vaga->estado !== VagaEstado::Aberta || $vaga->data_inicio->isPast()) {
            return CriarCandidaturaResultado::bloqueada(
                'vaga_fechada',
                'Esta vaga não está mais aberta para candidaturas.',
                null,
                422,
            );
        }

        // CA-6 — idempotência: candidatura viva nesta vaga → 409. Uma candidatura "morta"
        // (retirada) é reativada adiante (o UNIQUE de STORY-044 cobre o par vaga+profissional).
        $existente = $this->candidaturaExistente($profissional->id, $vaga->id);
        if ($existente !== null && $this->estaViva($existente)) {
            return CriarCandidaturaResultado::bloqueada(
                'ja_candidatou',
                'Você já se candidatou a esta vaga.',
                ['candidatura' => [
                    'id' => $existente->id,
                    'estado' => $existente->estado->value,
                    'criada_em' => $existente->created_at?->toIso8601String(),
                ]],
                409,
            );
        }

        // Gates (CA-2/CA-3/CA-4) — o primeiro bloqueio vence (422). A habitualidade pode
        // "passar com alerta" (MEI/PJ): não barra, mas marca o payload.
        $alerta = false;
        foreach ([$this->gateConflito, $this->gateHabitualidade, $this->gateAvaliacao] as $gate) {
            $r = $gate->verificar($profissional, $vaga);
            if ($r->bloqueado) {
                return CriarCandidaturaResultado::bloqueada($r->erro, $r->mensagem, $r->detalhe, 422);
            }
            $alerta = $alerta || $r->temAlerta;
        }

        $score = $this->calcularScore($profissional, $vaga);

        $candidatura = DB::transaction(function () use ($profissional, $vaga, $score, $existente, $alerta) {
            $candidatura = $this->criarOuReativar($profissional, $vaga, $score, $existente, $alerta);

            AuditLog::create([
                'actor_id' => $profissional->id,
                'action' => 'candidatura.criada',
                'target_type' => 'Candidatura',
                'target_id' => $candidatura->id,
                'payload' => ['vaga_id' => $vaga->id, 'score_no_momento' => $score->total],
                'ip' => $this->request->ip(),
                'user_agent' => $this->request->userAgent(),
            ]);

            MatchEvents::candidaturaEnviada($vaga->id, $profissional->id, $candidatura->id, $score);

            CandidaturaEnviada::dispatch($candidatura);

            return $candidatura;
        });

        return CriarCandidaturaResultado::criada($candidatura, $alerta);
    }

    /**
     * Cria a candidatura nova ou reativa uma retirada anterior (mesmo par vaga+profissional —
     * o UNIQUE de STORY-044 impede duas linhas, então a retirada é "ressuscitada" como nova:
     * volta a `pendente`, novo score, novo carimbo de criação — SCREEN-050 §4.9).
     */
    private function criarOuReativar(User $profissional, Vaga $vaga, MatchScore $score, ?Candidatura $existente, bool $alerta): Candidatura
    {
        $versaoId = $this->versaoAtualId($vaga);

        if ($existente !== null) {
            $existente->forceFill([
                'estado' => CandidaturaEstado::Pendente,
                'vaga_versao_id' => $versaoId,
                'score_no_momento' => $score->total,
                // Snapshot do match no instante da (re)candidatura — o painel lê sem recalcular
                // (STORY-051 CA-2/CA-4). A reativação carimba o snapshot novo, como deve.
                'score_breakdown' => $score->toArray(),
                'alerta_habitualidade' => $alerta,
                'revisao_prazo_em' => null,
                'aprovada_em' => null,
                'retirada_em' => null,
                'created_at' => now(),
                'updated_at' => now(),
            ])->save();

            return $existente;
        }

        return Candidatura::create([
            'vaga_id' => $vaga->id,
            'profissional_id' => $profissional->id,
            'estado' => CandidaturaEstado::Pendente,
            'vaga_versao_id' => $versaoId,
            'score_no_momento' => $score->total,
            'score_breakdown' => $score->toArray(),
            'alerta_habitualidade' => $alerta,
        ]);
    }

    /** Candidatura (de qualquer estado) deste profissional nesta vaga — para idempotência/reativação. */
    private function candidaturaExistente(int $profissionalId, int $vagaId): ?Candidatura
    {
        return Candidatura::query()
            ->where('profissional_id', $profissionalId)
            ->where('vaga_id', $vagaId)
            ->first();
    }

    /** Estados que significam "já candidatou" (idempotência — CA-6). */
    private function estaViva(Candidatura $c): bool
    {
        return in_array($c->estado, [
            CandidaturaEstado::Pendente,
            CandidaturaEstado::PendenteRevisaoAposEdicao,
            CandidaturaEstado::Aprovada,
        ], true);
    }

    private function versaoAtualId(Vaga $vaga): ?int
    {
        return VagaVersao::query()
            ->where('vaga_id', $vaga->id)
            ->where('versao', $vaga->versao_atual)
            ->value('id');
    }

    private function calcularScore(User $profissional, Vaga $vaga): MatchScore
    {
        $perfil = $profissional->profissionalProfile;

        $distancia = Haversine::km(
            $perfil?->lat !== null ? (float) $perfil->lat : null,
            $perfil?->lng !== null ? (float) $perfil->lng : null,
            $vaga->lat !== null ? (float) $vaga->lat : null,
            $vaga->lng !== null ? (float) $vaga->lng : null,
        );

        return $this->scoring->paraEntidades($perfil, $vaga, $distancia);
    }
}
