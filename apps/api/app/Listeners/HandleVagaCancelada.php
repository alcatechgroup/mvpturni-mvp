<?php

namespace App\Listeners;

use App\Enums\CandidaturaEstado;
use App\Enums\NotificacaoTipo;
use App\Events\VagaCancelada;
use App\Services\Notificacao\CriarNotificacaoService;
use App\Support\DataHora;

/**
 * STORY-053 (CA-4) — `VagaCancelada` → 1 notificação por candidato pendente (`vaga_cancelada`),
 * para o PROFISSIONAL. O cancelamento não transiciona as candidaturas (STORY-047 só conta), então
 * consultamos as `pendente` da vaga aqui. O e-mail garante a chegada com o app fechado; a UI já
 * mostra o banner no momento da ação.
 */
class HandleVagaCancelada
{
    public function __construct(private readonly CriarNotificacaoService $criar) {}

    public function handle(VagaCancelada $event): void
    {
        $vaga = $event->vaga->loadMissing('funcao');

        $candidaturas = $vaga->candidaturas()
            ->where('estado', CandidaturaEstado::Pendente)
            ->get();

        foreach ($candidaturas as $candidatura) {
            $this->criar->criar(
                tipo: NotificacaoTipo::VagaCancelada,
                destinatarioId: $candidatura->profissional_id,
                vagaId: $vaga->id,
                candidaturaId: $candidatura->id,
                payload: [
                    'vaga_id' => $vaga->id,
                    'vaga_funcao' => $vaga->funcao->nome,
                    'vaga_data_inicio' => DataHora::completa($vaga->data_inicio),
                    'link_feed' => LinksWebApp::feed(),
                ],
                idempotencyKey: "vaga_cancelada:{$candidatura->id}",
            );
        }
    }
}
