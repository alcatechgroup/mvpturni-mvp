<?php

namespace App\Listeners;

use App\Enums\NotificacaoTipo;
use App\Events\CandidaturaEnviada;
use App\Services\Notificacao\CriarNotificacaoService;
use App\Support\DataHora;

/**
 * STORY-053 (CA-2) — `CandidaturaEnviada` → 1 notificação para o CONTRATANTE dono da vaga
 * (`candidatura_recebida`), com nome e score do profissional (CA-10: sem CPF/telefone). Síncrono
 * dentro da transação que cria a candidatura — rollback da candidatura desfaz a notificação.
 */
class HandleCandidaturaEnviada
{
    public function __construct(private readonly CriarNotificacaoService $criar) {}

    public function handle(CandidaturaEnviada $event): void
    {
        $candidatura = $event->candidatura->loadMissing(['vaga.funcao', 'profissional']);
        $vaga = $candidatura->vaga;

        $this->criar->criar(
            tipo: NotificacaoTipo::CandidaturaRecebida,
            destinatarioId: $vaga->contratante_id,
            vagaId: $vaga->id,
            candidaturaId: $candidatura->id,
            payload: [
                'profissional_nome' => $candidatura->profissional->name,
                'profissional_score' => $candidatura->score_no_momento,
                'vaga_id' => $vaga->id,
                'vaga_funcao' => $vaga->funcao->nome,
                'vaga_data_inicio' => DataHora::completa($vaga->data_inicio),
                'link_painel' => LinksWebApp::painelCandidatos($vaga->id),
            ],
            idempotencyKey: "candidatura_recebida:{$candidatura->id}",
        );
    }
}
