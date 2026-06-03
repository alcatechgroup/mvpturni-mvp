<?php

namespace App\Services\Notificacao;

use App\Enums\NotificacaoTipo;
use App\Listeners\LinksWebApp;
use App\Models\Candidatura;
use App\Support\DataHora;

/**
 * STORY-053 (templates 4/5) — notifica o CONTRATANTE sobre o desfecho da revisão de uma candidatura
 * após edição material (PDR-009). Diferente dos templates 1/2/3, NÃO há evento de domínio para
 * "confirmar/retirar após edição"; estas notificações nascem nos hooks de:
 *   - RevisarCandidaturaService::manter()  → `candidatura_mantida` (template 4);
 *   - RevisarCandidaturaService::retirar() → `candidatura_retirada` (motivo `voluntaria`);
 *   - AutoRetirarAposEdicaoCommand          → `candidatura_retirada` (motivo `auto_24h`).
 *
 * Chamado DENTRO da transação da transição (consistência: rollback desfaz a notificação). O
 * `motivo_texto` é pré-resolvido aqui (o worker só interpola — mesmo padrão de `diff_texto`).
 * Idempotência por candidatura + versão da vaga (família "edição material", story §"Idempotência").
 */
class NotificarRevisaoAposEdicao
{
    public function __construct(private readonly CriarNotificacaoService $criar) {}

    /** Template 4 — o candidato confirmou que continua após a edição. */
    public function mantida(Candidatura $candidatura): void
    {
        $vaga = $candidatura->loadMissing('vaga.funcao')->vaga;

        $this->criar->criar(
            tipo: NotificacaoTipo::VagaEditadaMaterialCandidaturaMantida,
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
            idempotencyKey: "vaga_editada_material_candidatura_mantida:{$candidatura->id}:{$vaga->versao_atual}",
        );
    }

    /** Template 5 — o candidato saiu após a edição. `$motivo` ∈ {voluntaria, auto_24h}. */
    public function retirada(Candidatura $candidatura, string $motivo): void
    {
        $vaga = $candidatura->loadMissing('vaga.funcao')->vaga;
        $nome = $candidatura->profissional->name;
        $funcao = $vaga->funcao->nome;
        $dataInicio = DataHora::completa($vaga->data_inicio);

        $this->criar->criar(
            tipo: NotificacaoTipo::VagaEditadaMaterialCandidaturaRetirada,
            destinatarioId: $vaga->contratante_id,
            vagaId: $vaga->id,
            candidaturaId: $candidatura->id,
            payload: [
                'profissional_nome' => $nome,
                'vaga_id' => $vaga->id,
                'vaga_funcao' => $funcao,
                'vaga_data_inicio' => $dataInicio,
                'motivo' => $motivo,
                'motivo_texto' => $this->motivoTexto($motivo, $nome, $funcao, $dataInicio),
                'link_painel' => LinksWebApp::painelCandidatos($vaga->id),
            ],
            idempotencyKey: "vaga_editada_material_candidatura_retirada:{$candidatura->id}:{$vaga->versao_atual}",
        );
    }

    /** Parágrafo 1 do template 5, condicional ao motivo (texto-seed v1 do PO). */
    private function motivoTexto(string $motivo, string $nome, string $funcao, ?string $dataInicio): string
    {
        return $motivo === 'auto_24h'
            ? "{$nome} não respondeu à alteração da vaga de {$funcao} ({$dataInicio}) no prazo de 24h. A candidatura foi retirada automaticamente."
            : "{$nome} optou por não continuar candidatado à vaga de {$funcao} ({$dataInicio}) depois das alterações.";
    }
}
