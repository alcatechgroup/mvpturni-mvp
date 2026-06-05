<?php

namespace App\Services;

use App\Enums\TurnoStatus;
use App\Events\TurnoFinalizado;
use App\Models\AuditLog;
use App\Models\Turno;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

/**
 * STORY-064 — validação do PIN de check-out pelo contratante e recusa (espelho da
 * ValidarCheckinService/062; PDR-008, ADR-015).
 *
 * Validação (CA-3/CA-7): compara o PIN com o hash da geração (Hash::check). Correto →
 * TRANSAÇÃO: aguardando_checkout→finalizado (transitionTo grava check_out_at FINAL — o
 * timestamp da validação, não o da solicitação), hash consumido, tentativas zeradas,
 * audit `turno.checkout_validado`; evento TurnoFinalizado APÓS o commit (065/067 consomem).
 * Errado → incrementa `pin_checkout_tentativas`; no 3º erro o PIN expira: hash limpo,
 * volta a `ativo` (cronômetro retoma; profissional gera novo), audit
 * `turno.checkout_pin_expirado` (CA-4). Rate limit por turno fica no controller.
 *
 * Recusa (CA-5/CA-7): aguardando_checkout→ativo (NUNCA `em_disputa` — EPIC-005 fora de
 * escopo), hash limpo, audit `turno.checkout_recusado` com motivo OPCIONAL (vive na
 * trilha do admin; a timeline das partes não o expõe — SCREEN-064 §4.12).
 */
class ValidarCheckoutService
{
    /** CA-4 — erros que expiram o PIN ativo (espelho da 062). */
    private const MAX_ERROS = 3;

    public function __construct(private readonly Request $request) {}

    /**
     * @return array{estado:string}
     *
     * @throws PinCheckinEstadoInvalidoException|PinInvalidoException|PinExpiradoException
     */
    public function validar(Turno $turno, string $pin): array
    {
        if ($turno->status !== TurnoStatus::AguardandoCheckout || $turno->pin_checkout_hash === null) {
            throw new PinCheckinEstadoInvalidoException($turno->status->value);
        }

        if (! Hash::check($pin, $turno->pin_checkout_hash)) {
            $this->registrarErro($turno);
        }

        $tentativas = $turno->pin_checkout_tentativas + 1; // erros anteriores + este acerto

        DB::transaction(function () use ($turno, $tentativas) {
            $turno->pin_checkout_hash = null; // uso único: consumido na validação
            $turno->pin_checkout_tentativas = 0;
            $turno->transitionTo(TurnoStatus::Finalizado); // grava check_out_at final (ADR-015)

            // CA-7 — nunca o PIN no payload.
            AuditLog::create([
                'actor_id' => $turno->contratante_id,
                'action' => 'turno.checkout_validado',
                'target_type' => 'Turno',
                'target_id' => $turno->id,
                'payload' => ['pin_tentativas_ate_acerto' => $tentativas],
                'ip' => $this->request->ip(),
                'user_agent' => $this->request->userAgent(),
            ]);
        });

        // CA-3 — contrato para 065 (captura + Pix) e 067 (notificações); pós-commit.
        TurnoFinalizado::dispatch($turno->id);

        return ['estado' => TurnoStatus::Finalizado->value];
    }

    /**
     * @return array{estado:string}
     *
     * @throws PinCheckinEstadoInvalidoException
     */
    public function recusar(Turno $turno, ?string $motivo): array
    {
        if ($turno->status !== TurnoStatus::AguardandoCheckout) {
            throw new PinCheckinEstadoInvalidoException($turno->status->value);
        }

        DB::transaction(function () use ($turno, $motivo) {
            $turno->pin_checkout_hash = null;
            $turno->pin_checkout_tentativas = 0;
            $turno->transitionTo(TurnoStatus::Ativo); // cronômetro retoma (CA-5)

            AuditLog::create([
                'actor_id' => $turno->contratante_id,
                'action' => 'turno.checkout_recusado',
                'target_type' => 'Turno',
                'target_id' => $turno->id,
                'payload' => ['motivo' => $motivo],
                'ip' => $this->request->ip(),
                'user_agent' => $this->request->userAgent(),
            ]);
        });

        return ['estado' => TurnoStatus::Ativo->value];
    }

    /**
     * PIN errado: incrementa o contador; no MAX_ERROS-ésimo erro expira o PIN e o turno
     * volta a `ativo` — estado de origem, espelho da 062 que voltava a `confirmado` (CA-4).
     *
     * @throws PinInvalidoException|PinExpiradoException
     */
    private function registrarErro(Turno $turno): never
    {
        $tentativas = $turno->pin_checkout_tentativas + 1;

        if ($tentativas < self::MAX_ERROS) {
            $turno->forceFill(['pin_checkout_tentativas' => $tentativas])->save();

            throw new PinInvalidoException;
        }

        DB::transaction(function () use ($turno, $tentativas) {
            $turno->pin_checkout_hash = null;
            $turno->pin_checkout_tentativas = 0;
            $turno->transitionTo(TurnoStatus::Ativo); // profissional gera novo PIN

            AuditLog::create([
                'actor_id' => $turno->contratante_id,
                'action' => 'turno.checkout_pin_expirado',
                'target_type' => 'Turno',
                'target_id' => $turno->id,
                'payload' => ['tentativas' => $tentativas],
                'ip' => $this->request->ip(),
                'user_agent' => $this->request->userAgent(),
            ]);
        });

        throw new PinExpiradoException;
    }
}
