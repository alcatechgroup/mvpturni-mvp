<?php

namespace App\Services;

use App\Domain\Turno\PinCheckin;
use App\Enums\TurnoStatus;
use App\Events\CheckinSolicitado;
use App\Models\AuditLog;
use App\Models\Turno;
use App\Support\Geo\Geofencing;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

/**
 * STORY-061 — geração e cancelamento do PIN de check-in (PDR-008, ADR-015/017).
 *
 * Geração (CA-2/3/4/6/7): valida a janela [data_inicio−antes, data_inicio+depois]
 * (config/turno.php), sorteia o PIN (PinCheckin), grava SÓ o hash (bcrypt — EPIC-001),
 * avalia o geofencing (Geofencing/Haversine — reuso 057/049, nunca bloqueia) e, em
 * TRANSAÇÃO, transita confirmado→aguardando_checkin + persiste snapshot + audit log.
 * Re-geração em `aguardando_checkin` troca o hash (invalida o anterior) sem transição.
 * O plaintext do PIN é devolvido UMA vez ao caller e nunca logado (CA-4).
 *
 * Cancelamento (CA-5): aguardando_checkin→confirmado, hash limpo, audit
 * `turno.checkin_cancelado` (premissa registrada na SCREEN-061 §4.10).
 */
class PinCheckinService
{
    public function __construct(private readonly Request $request) {}

    /**
     * @param  array{lat?:?float,lng?:?float,accuracy_m?:?float,razao?:?string}  $geo
     * @return array{pin:string,estado:string,geofencing_check_in:array<string,mixed>}
     *
     * @throws PinCheckinForaDaJanelaException|PinCheckinEstadoInvalidoException
     */
    public function gerar(Turno $turno, array $geo): array
    {
        $regeracao = $turno->status === TurnoStatus::AguardandoCheckin;

        if (! $regeracao && $turno->status !== TurnoStatus::Confirmado) {
            throw new PinCheckinEstadoInvalidoException($turno->status->value);
        }

        [$abre, $fecha] = self::janela($turno);
        if (now()->lt($abre) || now()->gt($fecha)) {
            throw new PinCheckinForaDaJanelaException($abre->toIso8601String(), $fecha->toIso8601String());
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
        // STORY-067 — identifica ESTA geração de PIN (chave de idempotência da notificação;
        // re-geração = id novo = contratante re-notificado). Também vai à trilha.
        $geracaoPinId = (string) Str::uuid7();

        DB::transaction(function () use ($turno, $pin, $snapshot, $regeracao, $geracaoPinId) {
            $turno->pin_checkin_hash = Hash::make($pin);
            $turno->pin_checkin_tentativas = 0; // STORY-062 (CA-3): PIN novo zera os erros de validação
            $turno->geofencing_check_in = $snapshot;

            if ($regeracao) {
                $turno->save(); // hash anterior invalidado; estado já é aguardando_checkin
            } else {
                $turno->transitionTo(TurnoStatus::AguardandoCheckin); // salva (ADR-015)
            }

            // CA-7 — snapshot completo na trilha; NUNCA o pin (CA-4).
            AuditLog::create([
                'actor_id' => $turno->profissional_id,
                'action' => 'turno.checkin_solicitado',
                'target_type' => 'Turno',
                'target_id' => $turno->id,
                'payload' => [
                    'geofencing_check_in' => $snapshot,
                    'pin_regerado' => $regeracao,
                    'geracao_pin_id' => $geracaoPinId,
                ],
                'ip' => $this->request->ip(),
                'user_agent' => $this->request->userAgent(),
            ]);
        });

        // STORY-067 (CA-1) — pós-commit: notificação `checkin_solicitado` ao contratante.
        CheckinSolicitado::dispatch($turno->id, $geracaoPinId);

        return [
            'pin' => $pin, // única vez em plaintext (CA-4)
            'estado' => TurnoStatus::AguardandoCheckin->value,
            'geofencing_check_in' => $snapshot,
        ];
    }

    /**
     * @return array{estado:string}
     *
     * @throws PinCheckinEstadoInvalidoException
     */
    public function cancelar(Turno $turno): array
    {
        if ($turno->status !== TurnoStatus::AguardandoCheckin) {
            throw new PinCheckinEstadoInvalidoException($turno->status->value);
        }

        DB::transaction(function () use ($turno) {
            $turno->pin_checkin_hash = null;
            $turno->transitionTo(TurnoStatus::Confirmado);

            AuditLog::create([
                'actor_id' => $turno->profissional_id,
                'action' => 'turno.checkin_cancelado',
                'target_type' => 'Turno',
                'target_id' => $turno->id,
                'payload' => [],
                'ip' => $this->request->ip(),
                'user_agent' => $this->request->userAgent(),
            ]);
        });

        return ['estado' => TurnoStatus::Confirmado->value];
    }

    /** Janela de geração (CA-1), bordas inclusivas. @return array{0:\Carbon\Carbon,1:\Carbon\Carbon} */
    public static function janela(Turno $turno): array
    {
        return [
            $turno->data_inicio->copy()->subMinutes((int) config('turno.checkin_janela_antes_min')),
            $turno->data_inicio->copy()->addMinutes((int) config('turno.checkin_janela_depois_min')),
        ];
    }
}

// STORY-062: PinCheckinForaDaJanelaException e PinCheckinEstadoInvalidoException foram
// extraídas para arquivos próprios (PSR-4) — classes no mesmo arquivo do service não são
// autoloadáveis por quem não carrega o service (o ValidarCheckinService reusa a de estado).
