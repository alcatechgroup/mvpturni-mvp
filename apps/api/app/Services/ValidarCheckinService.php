<?php

namespace App\Services;

use App\Enums\TurnoStatus;
use App\Events\TurnoIniciado;
use App\Models\AuditLog;
use App\Models\Turno;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

/**
 * STORY-062 — validação do PIN de check-in pelo contratante e recusa (PDR-008, ADR-015).
 *
 * Validação (CA-1/2/3/7): compara o PIN com o hash da 061 (Hash::check). Correto →
 * TRANSAÇÃO: aguardando_checkin→ativo (transitionTo grava check_in_at), hash consumido
 * (PIN é de uso único), tentativas zeradas, audit `turno.checkin_validado` com
 * `pin_tentativas_ate_acerto`; evento TurnoIniciado APÓS o commit (063/067 consomem).
 * Errado → incrementa `pin_checkin_tentativas`; no 3º erro o PIN expira: hash limpo,
 * volta a `confirmado` (profissional gera novo — 061), audit `turno.checkin_pin_expirado`.
 * O rate limit por turno (CA-2, 5/60s) fica no controller — é proteção de borda HTTP,
 * não regra de domínio.
 *
 * Recusa (CA-6/7): aguardando_checkin→confirmado, hash limpo, audit
 * `turno.checkin_recusado` com motivo OPCIONAL (vive na trilha do admin; a timeline
 * das partes não o expõe — SCREEN-062 §4.11).
 */
class ValidarCheckinService
{
    /** CA-3 — erros que expiram o PIN ativo. */
    private const MAX_ERROS = 3;

    public function __construct(private readonly Request $request) {}

    /**
     * @return array{estado:string}
     *
     * @throws PinCheckinEstadoInvalidoException|PinInvalidoException|PinExpiradoException
     */
    public function validar(Turno $turno, string $pin): array
    {
        if ($turno->status !== TurnoStatus::AguardandoCheckin || $turno->pin_checkin_hash === null) {
            throw new PinCheckinEstadoInvalidoException($turno->status->value);
        }

        if (! Hash::check($pin, $turno->pin_checkin_hash)) {
            $this->registrarErro($turno);
        }

        $tentativas = $turno->pin_checkin_tentativas + 1; // erros anteriores + este acerto

        DB::transaction(function () use ($turno, $tentativas) {
            $turno->pin_checkin_hash = null; // uso único: consumido na validação
            $turno->pin_checkin_tentativas = 0;
            $turno->transitionTo(TurnoStatus::Ativo); // grava check_in_at (ADR-015)

            // CA-7 — nunca o PIN no payload.
            AuditLog::create([
                'actor_id' => $turno->contratante_id,
                'action' => 'turno.checkin_validado',
                'target_type' => 'Turno',
                'target_id' => $turno->id,
                'payload' => ['pin_tentativas_ate_acerto' => $tentativas],
                'ip' => $this->request->ip(),
                'user_agent' => $this->request->userAgent(),
            ]);
        });

        // CA-1 — contrato para 063 (cronômetro) e 067 (notificações); pós-commit.
        TurnoIniciado::dispatch($turno->id);

        return ['estado' => TurnoStatus::Ativo->value];
    }

    /**
     * @return array{estado:string}
     *
     * @throws PinCheckinEstadoInvalidoException
     */
    public function recusar(Turno $turno, ?string $motivo): array
    {
        if ($turno->status !== TurnoStatus::AguardandoCheckin) {
            throw new PinCheckinEstadoInvalidoException($turno->status->value);
        }

        DB::transaction(function () use ($turno, $motivo) {
            $turno->pin_checkin_hash = null;
            $turno->pin_checkin_tentativas = 0;
            $turno->transitionTo(TurnoStatus::Confirmado);

            AuditLog::create([
                'actor_id' => $turno->contratante_id,
                'action' => 'turno.checkin_recusado',
                'target_type' => 'Turno',
                'target_id' => $turno->id,
                'payload' => ['motivo' => $motivo],
                'ip' => $this->request->ip(),
                'user_agent' => $this->request->userAgent(),
            ]);
        });

        return ['estado' => TurnoStatus::Confirmado->value];
    }

    /**
     * PIN errado: incrementa o contador; no MAX_ERROS-ésimo erro expira o PIN (CA-3).
     *
     * @throws PinInvalidoException|PinExpiradoException
     */
    private function registrarErro(Turno $turno): never
    {
        $tentativas = $turno->pin_checkin_tentativas + 1;

        if ($tentativas < self::MAX_ERROS) {
            $turno->forceFill(['pin_checkin_tentativas' => $tentativas])->save();

            throw new PinInvalidoException;
        }

        DB::transaction(function () use ($turno, $tentativas) {
            $turno->pin_checkin_hash = null;
            $turno->pin_checkin_tentativas = 0;
            $turno->transitionTo(TurnoStatus::Confirmado); // profissional gera novo (061)

            AuditLog::create([
                'actor_id' => $turno->contratante_id,
                'action' => 'turno.checkin_pin_expirado',
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
