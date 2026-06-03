<?php

namespace App\Console\Commands;

use App\Enums\CandidaturaEstado;
use App\Models\AuditLog;
use App\Models\Candidatura;
use Illuminate\Console\Command;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * STORY-052 (CA-9) / PDR-009 — auto-retirada de candidaturas que não foram confirmadas após uma
 * edição material da vaga. Reusa a infra de cron da STORY-034 (Cloud Run Job + Cloud Scheduler):
 * agendado 1×/min em routes/console.php.
 *
 * Varre candidaturas em `pendente_revisao_apos_edicao` cujo prazo estourou — `revisao_prazo_em`
 * já carrega "24h ou início do turno, o que vier antes" (EditarVagaService). Como defesa extra
 * (e fidelidade ao texto da CA-9), também retira se o turno já começou (`vaga.data_inicio` no
 * passado), mesmo que o prazo carimbado estivesse à frente. Move para `retirada_por_edicao` e
 * registra audit `candidatura.retirada_por_edicao_auto`.
 *
 * Idempotente: só toca `pendente_revisao_apos_edicao`; após a transição a candidatura sai do
 * conjunto, então reexecuções não duplicam efeito nem auditoria.
 */
class AutoRetirarAposEdicaoCommand extends Command
{
    protected $signature = 'candidaturas:auto-retirar-apos-edicao';

    protected $description = 'Retira candidaturas não confirmadas após edição material da vaga (PDR-009 / STORY-052 CA-9).';

    public function handle(): int
    {
        $agora = Carbon::now();
        $retiradas = 0;

        Candidatura::query()
            ->where('estado', CandidaturaEstado::PendenteRevisaoAposEdicao)
            ->with('vaga:id,data_inicio')
            ->chunkById(200, function ($candidaturas) use ($agora, &$retiradas) {
                foreach ($candidaturas as $candidatura) {
                    if (! $this->prazoEstourado($candidatura, $agora)) {
                        continue;
                    }
                    $this->retirar($candidatura);
                    $retiradas++;
                }
            });

        $this->info("Candidaturas auto-retiradas após edição: {$retiradas}.");

        return self::SUCCESS;
    }

    private function prazoEstourado(Candidatura $candidatura, Carbon $agora): bool
    {
        $prazo = $candidatura->revisao_prazo_em;
        if ($prazo !== null && $prazo->lessThanOrEqualTo($agora)) {
            return true;
        }

        // Defesa CA-9: o turno já começou — não faz sentido manter a revisão aberta.
        $inicio = $candidatura->vaga?->data_inicio;

        return $inicio !== null && $inicio->lessThanOrEqualTo($agora);
    }

    private function retirar(Candidatura $candidatura): void
    {
        DB::transaction(function () use ($candidatura) {
            // Lock + revalida o estado dentro da transação: barra corrida com a confirmação
            // manual do profissional (CA-7) que pode chegar no mesmo instante.
            $fresh = Candidatura::query()->whereKey($candidatura->getKey())->lockForUpdate()->first();
            if ($fresh === null || $fresh->estado !== CandidaturaEstado::PendenteRevisaoAposEdicao) {
                return;
            }

            $fresh->transitionTo(CandidaturaEstado::RetiradaPorEdicao);

            AuditLog::create([
                'actor_id' => null, // sistema (cron), não o profissional.
                'action' => 'candidatura.retirada_por_edicao_auto',
                'target_type' => 'Candidatura',
                'target_id' => $fresh->id,
                'payload' => [
                    'vaga_id' => $fresh->vaga_id,
                    'profissional_id' => $fresh->profissional_id,
                ],
            ]);

            Log::info('candidatura.retirada_por_edicao_auto', [
                'event' => 'candidatura.retirada_por_edicao_auto',
                'candidatura_id' => $fresh->id,
                'vaga_id' => $fresh->vaga_id,
                'profissional_id' => $fresh->profissional_id,
            ]);
        });
    }
}
