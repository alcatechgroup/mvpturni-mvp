<?php

namespace App\Console\Commands;

use App\Enums\TurnoStatus;
use App\Events\TurnoNoShow;
use App\Models\AuditLog;
use App\Models\Turno;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/**
 * STORY-066 (CA-5) — `turnos:detectar-no-show`, everyMinute no worker (STORY-034).
 *
 * Turnos `confirmado` ou `aguardando_checkin` cujo `data_inicio + X horas < now()` viram
 * `no_show_pro` (X = config turno.no_show_horas — 2h, decisão do PO em chat 2026-06-06;
 * configurável por env sem deploy). Cada vencido: TRANSAÇÃO (transitionTo + audit
 * `turno.no_show_pro`) e evento TurnoNoShow pós-transição → liberação da pré-autorização
 * (CA-6) e notificação de ambos os lados (STORY-067).
 *
 * Idempotente por natureza: `no_show_pro` é terminal — o turno não reaparece na query no
 * tick seguinte. Um turno que falhe não derruba o lote (lock + try por linha).
 */
class DetectarNoShowCommand extends Command
{
    protected $signature = 'turnos:detectar-no-show';

    protected $description = 'Transita para no_show_pro turnos sem check-in até X horas após o início previsto (PDR-007 / STORY-066)';

    public function handle(): int
    {
        $horas = (int) config('turno.no_show_horas');
        $limite = now()->subHours($horas);

        $vencidos = Turno::query()
            ->whereIn('status', [TurnoStatus::Confirmado->value, TurnoStatus::AguardandoCheckin->value])
            ->where('data_inicio', '<', $limite)
            ->orderBy('data_inicio')
            ->get();

        foreach ($vencidos as $turno) {
            $this->vencer($turno, $horas);
        }

        $this->info("turnos:detectar-no-show — {$vencidos->count()} turno(s) vencido(s) (limite {$horas}h).");

        return self::SUCCESS;
    }

    private function vencer(Turno $turno, int $horas): void
    {
        try {
            $transitou = DB::transaction(function () use ($turno, $horas): bool {
                // Re-leitura com lock: o contratante pode ter validado o PIN entre a query
                // e este ponto — a transição só acontece sobre o estado ainda vencível.
                $atual = Turno::query()->lockForUpdate()->find($turno->id);

                if ($atual === null || ! in_array($atual->status, [TurnoStatus::Confirmado, TurnoStatus::AguardandoCheckin], true)) {
                    return false;
                }

                $atual->transitionTo(TurnoStatus::NoShowPro);

                AuditLog::create([
                    'actor_id' => null, // transição automática do sistema (cron)
                    'action' => 'turno.no_show_pro',
                    'target_type' => 'Turno',
                    'target_id' => $atual->id,
                    'payload' => [
                        'limite_horas' => $horas,
                        'data_inicio' => $atual->data_inicio->toIso8601String(),
                    ],
                ]);

                return true;
            });

            if ($transitou) {
                // Pós-commit: liberação (TurnoNoShowListener) + notificações (STORY-067).
                TurnoNoShow::dispatch($turno->id);
            }
        } catch (\Throwable $e) {
            // Um turno problemático não derruba o lote; o tick seguinte retenta.
            report($e);
            $this->error("turno {$turno->id}: {$e->getMessage()}");
        }
    }
}
