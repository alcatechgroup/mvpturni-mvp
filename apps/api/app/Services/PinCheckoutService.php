<?php

namespace App\Services;

use App\Domain\Turno\PinCheckin;
use App\Enums\TurnoStatus;
use App\Models\AuditLog;
use App\Models\Turno;
use App\Support\Geo\Geofencing;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

/**
 * STORY-064 — geração e cancelamento do PIN de check-out (espelho da PinCheckinService/061).
 *
 * Diferenças intencionais da estória: estado de origem é `ativo` (não `confirmado`); SEM
 * janela horária (CA-1 — turno pode estender); geofencing OPCIONAL e silencioso (capturado
 * com a mesma API, registrado no snapshot/trilha, mas sem aviso destacado na UI — CA-2).
 *
 * Geração (CA-2/CA-7): sorteia o PIN (PinCheckin — gerador genérico de 4 dígitos), grava SÓ
 * o hash (bcrypt), avalia geofencing (nunca bloqueia — PDR-008) e, em TRANSAÇÃO, transita
 * ativo→aguardando_checkout + snapshot + audit `turno.checkout_solicitado` (o cronômetro da
 * 063 deriva o `encerrado_em` exibido deste evento — CronometroController::encerradoEm).
 * Re-geração em `aguardando_checkout` troca o hash sem transição. Plaintext devolvido UMA
 * vez ao caller e nunca logado.
 *
 * Cancelamento: aguardando_checkout→ativo (cronômetro retoma — SCREEN-064 §4.6), hash
 * limpo, audit `turno.checkout_cancelado`.
 */
class PinCheckoutService
{
    public function __construct(private readonly Request $request) {}

    /**
     * @param  array{lat?:?float,lng?:?float,accuracy_m?:?float,razao?:?string}  $geo
     * @return array{pin:string,estado:string,geofencing_check_out:array<string,mixed>}
     *
     * @throws PinCheckinEstadoInvalidoException
     */
    public function gerar(Turno $turno, array $geo): array
    {
        $regeracao = $turno->status === TurnoStatus::AguardandoCheckout;

        if (! $regeracao && $turno->status !== TurnoStatus::Ativo) {
            throw new PinCheckinEstadoInvalidoException($turno->status->value);
        }

        $vaga = $turno->vaga; // geo do estabelecimento = snapshot da vaga (ADR-013).

        $snapshot = Geofencing::avaliar(
            $geo['lat'] ?? null,
            $geo['lng'] ?? null,
            $vaga?->lat !== null ? (float) $vaga->lat : null,
            $vaga?->lng !== null ? (float) $vaga->lng : null,
            razaoSemCoordenada: $geo['razao'] ?? null,
        ) + ['capturado_em' => now()->toIso8601String()];

        if (isset($geo['accuracy_m'])) {
            $snapshot['accuracy_m'] = (float) $geo['accuracy_m'];
        }

        $pin = PinCheckin::gerar();

        DB::transaction(function () use ($turno, $pin, $snapshot, $regeracao) {
            $turno->pin_checkout_hash = Hash::make($pin);
            $turno->pin_checkout_tentativas = 0; // PIN novo zera os erros de validação (CA-4)
            $turno->geofencing_check_out = $snapshot;

            if ($regeracao) {
                $turno->save(); // hash anterior invalidado; estado já é aguardando_checkout
            } else {
                $turno->transitionTo(TurnoStatus::AguardandoCheckout); // salva (ADR-015)
            }

            // CA-7 — snapshot completo na trilha; NUNCA o pin. O created_at deste evento é
            // o `encerrado_em` exibido pelo cronômetro em `aguardando_checkout` (063 §10).
            AuditLog::create([
                'actor_id' => $turno->profissional_id,
                'action' => 'turno.checkout_solicitado',
                'target_type' => 'Turno',
                'target_id' => $turno->id,
                'payload' => [
                    'geofencing_check_out' => $snapshot,
                    'pin_regerado' => $regeracao,
                ],
                'ip' => $this->request->ip(),
                'user_agent' => $this->request->userAgent(),
            ]);
        });

        return [
            'pin' => $pin, // única vez em plaintext (CA-2)
            'estado' => TurnoStatus::AguardandoCheckout->value,
            'geofencing_check_out' => $snapshot,
        ];
    }

    /**
     * @return array{estado:string}
     *
     * @throws PinCheckinEstadoInvalidoException
     */
    public function cancelar(Turno $turno): array
    {
        if ($turno->status !== TurnoStatus::AguardandoCheckout) {
            throw new PinCheckinEstadoInvalidoException($turno->status->value);
        }

        DB::transaction(function () use ($turno) {
            $turno->pin_checkout_hash = null;
            $turno->pin_checkout_tentativas = 0;
            $turno->transitionTo(TurnoStatus::Ativo); // check_in_at já existe — âncora intacta

            AuditLog::create([
                'actor_id' => $turno->profissional_id,
                'action' => 'turno.checkout_cancelado',
                'target_type' => 'Turno',
                'target_id' => $turno->id,
                'payload' => [],
                'ip' => $this->request->ip(),
                'user_agent' => $this->request->userAgent(),
            ]);
        });

        return ['estado' => TurnoStatus::Ativo->value];
    }
}
