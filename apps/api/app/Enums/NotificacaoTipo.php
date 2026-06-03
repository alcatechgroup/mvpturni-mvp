<?php

namespace App\Enums;

/**
 * STORY-053 — Tipos de notificação (in-app + e-mail). Espelha o enum nativo
 * `notificacao_tipo` (migração `create_notificacoes_table`).
 *
 * Cada tipo conhece:
 *  - `templateSlug()` — o template editável no Backoffice (STORY-020, categoria `email`) cujo
 *    corpo ativo (`TemplateVersao`) é interpolado com o `payload` da notificação (CA-6, Path A);
 *  - `assuntoEmail()` — o assunto CANÔNICO do e-mail, fixado em código (texto-seed v1 do PO,
 *    2026-06-03). Mantido aqui — e NÃO no `Turni\Domain\Email\TipoEmail` — de propósito: o
 *    `TipoEmail` é contrato compartilhado com o `admin` (ADR-011 §d, "não reabrir sem PDR") e
 *    seu `match` é exaustivo; a família de notificação é nova e fica na api (IDR-053).
 *
 * O TÍTULO/RESUMO in-app (SCREEN-STORY-053 §5) é renderizado no WebApp a partir de `tipo` +
 * `payload` — a API devolve os dois crus; o cliente interpola (uma fonte de verdade no payload).
 */
enum NotificacaoTipo: string
{
    case CandidaturaRecebida = 'candidatura_recebida';
    case VagaEditadaMaterial = 'vaga_editada_material';
    case VagaCancelada = 'vaga_cancelada';
    case VagaEditadaMaterialCandidaturaMantida = 'vaga_editada_material_candidatura_mantida';
    case VagaEditadaMaterialCandidaturaRetirada = 'vaga_editada_material_candidatura_retirada';

    /** Slug do template editável correspondente (STORY-020, categoria `email`). */
    public function templateSlug(): string
    {
        // O slug do template é o próprio valor do enum: legível, estável, 1:1 com o tipo.
        return $this->value.'_email';
    }

    /** Assunto canônico do e-mail (texto-seed v1 do PO — STORY-053). */
    public function assuntoEmail(): string
    {
        return match ($this) {
            self::CandidaturaRecebida => 'Nova candidatura para sua vaga no Turni',
            // {prazo_em} é interpolado no envio a partir do payload.
            self::VagaEditadaMaterial => 'Vaga em que você se candidatou foi alterada — confirme até {prazo_em}',
            self::VagaCancelada => 'Vaga em que você se candidatou foi cancelada',
            self::VagaEditadaMaterialCandidaturaMantida => 'Candidato confirmou continuar na sua vaga editada',
            self::VagaEditadaMaterialCandidaturaRetirada => 'Candidato deixou sua vaga após a alteração',
        };
    }
}
