<?php

namespace App\Listeners;

use App\Enums\NotificacaoTipo;
use App\Events\VagaEditadaMaterialmente;
use App\Models\Candidatura;
use App\Services\Notificacao\CriarNotificacaoService;
use App\Services\Notificacao\DiffParaTexto;
use App\Support\DataHora;

/**
 * STORY-053 (CA-3) — `VagaEditadaMaterialmente` → 1 notificação por candidato recém-movido para
 * revisão (`vaga_editada_material`), para o PROFISSIONAL, com o diff do que mudou e o prazo de
 * confirmação. O `diff` já vem pronto no evento (STORY-052); aqui formatamos em texto pt-BR e
 * guardamos no payload (o worker só interpola). Idempotência por candidatura + versão da vaga.
 */
class HandleVagaEditadaMaterialmente
{
    public function __construct(private readonly CriarNotificacaoService $criar) {}

    public function handle(VagaEditadaMaterialmente $event): void
    {
        $vaga = $event->vaga->loadMissing('funcao');
        $diffTexto = DiffParaTexto::gerar($event->diff);

        $candidaturas = Candidatura::query()
            ->with('profissional')
            ->whereIn('id', $event->candidatosNotificadosIds)
            ->get();

        foreach ($candidaturas as $candidatura) {
            $this->criar->criar(
                tipo: NotificacaoTipo::VagaEditadaMaterial,
                destinatarioId: $candidatura->profissional_id,
                vagaId: $vaga->id,
                candidaturaId: $candidatura->id,
                payload: [
                    'vaga_id' => $vaga->id,
                    'vaga_funcao' => $vaga->funcao->nome,
                    'diff' => $event->diff,
                    'diff_texto' => $diffTexto,
                    'prazo_em' => DataHora::completa($candidatura->revisao_prazo_em),
                    'link_detalhe' => LinksWebApp::detalheVaga($vaga->id),
                ],
                idempotencyKey: "vaga_editada_material:{$candidatura->id}:{$vaga->versao_atual}",
            );
        }
    }
}
