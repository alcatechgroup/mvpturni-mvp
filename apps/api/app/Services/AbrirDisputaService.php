<?php

namespace App\Services;

use App\Enums\TurnoStatus;
use App\Events\DisputaAberta;
use App\Models\AuditLog;
use App\Models\Turno;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * STORY-092 / ADR-020 (Decisão 2) — abertura da disputa: o OUTRO ramo de `aguardando_checkout`
 * que a máquina de estados (ADR-015) já prevê. Distinto do `ValidarCheckoutService::recusar()`
 * (que devolve a `ativo` com motivo OPCIONAL = "peça novo PIN"): aqui o contratante CONTESTA
 * por mérito, a `justificativa_contratante` é OBRIGATÓRIA e o turno entra em `em_disputa`.
 *
 * Pré-condições (fail-secure, F3): turno em `aguardando_checkout`; `justificativa` não-vazia
 * (após trim). O RBAC ortogonal (ator = contratante dono do turno) vive no controller (ADR-007),
 * espelhando o ValidarCheckoutController.
 *
 * Efeito numa transação: grava `turnos.disputa = {aberta_*}` (Decisão 1A — jsonb, grão de
 * `cancelamento`), `transitionTo(em_disputa)` (passa pelo trigger `enforce_turno_transition`;
 * um 2º clique encontra o turno já em `em_disputa` e a transição falha — idempotência de
 * abertura por construção) e `AuditLog turno.disputa_aberta`. A pré-autorização permanece
 * BLOQUEADA: nada financeiro é disparado (a captura só ocorre via `TurnoFinalizado`/estado
 * `finalizado` — `domain/pagamento.md §Disputa`).
 *
 * Pós-commit: emite `DisputaAberta($turno->id)` (UUID string; o listener recarrega o agregado —
 * ADR-018/019), espelhando o ponto onde o ValidarCheckoutService emite `TurnoFinalizado`. Fora
 * da transação para não notificar sobre uma transição que pode dar rollback.
 */
class AbrirDisputaService
{
    public function __construct(private readonly Request $request) {}

    /**
     * @return array{estado:string}
     *
     * @throws PinCheckinEstadoInvalidoException|DisputaSemJustificativaException
     */
    public function abrir(Turno $turno, ?string $justificativa): array
    {
        if ($turno->status !== TurnoStatus::AguardandoCheckout) {
            throw new PinCheckinEstadoInvalidoException($turno->status->value);
        }

        $justificativa = trim((string) $justificativa);
        if ($justificativa === '') {
            throw new DisputaSemJustificativaException;
        }

        DB::transaction(function () use ($turno, $justificativa) {
            // PIN de check-out deixa de valer — o momento de validar passou (hygiene: não deixar
            // segredo pendurado num turno que saiu de `aguardando_checkout`, como recusar()/validar()).
            $turno->pin_checkout_hash = null;
            $turno->pin_checkout_tentativas = 0;

            // Decisão 1A — `disputa` jsonb com os atributos do MVP; `resolucao`/`nota_admin`/
            // `resolvida_*` nascem nulos (preenchidos só na resolução pelo admin — STORY-093).
            $turno->disputa = [
                'aberta_em' => now()->toIso8601String(),
                'aberta_por' => $turno->contratante_id, // sempre o contratante no MVP
                'justificativa_contratante' => $justificativa,
                'resolucao' => null,
                'nota_admin' => null,
                'resolvida_em' => null,
                'resolvida_por' => null,
            ];

            $turno->transitionTo(TurnoStatus::EmDisputa); // trigger do banco é a rede final (ADR-015)

            AuditLog::create([
                'actor_id' => $turno->contratante_id,
                'action' => 'turno.disputa_aberta',
                'target_type' => 'Turno',
                'target_id' => $turno->id,
                'payload' => ['justificativa' => $justificativa],
                'ip' => $this->request->ip(),
                'user_agent' => $this->request->userAgent(),
            ]);
        });

        // Notifica o profissional (in-app + e-mail) — pós-commit, ver DisputaAberta/NotificarDisputaAberta.
        DisputaAberta::dispatch($turno->id);

        return ['estado' => TurnoStatus::EmDisputa->value];
    }
}
