---
pdr_id: PDR-009
slug: edicao-de-vaga-pos-candidatura
title: Edição de vaga após receber candidaturas é permitida e notifica candidatos
status: accepted
decided_at: 2026-05-26
decided_by: PO (Alexandro / Claude)
supersedes: null
superseded_by: null
related_epics: []
related_adrs: []
---

# PDR-009 — Edição de vaga pós-candidatura permitida com notificação

## Contexto

Contratantes esquecem detalhes ao publicar e descobrem depois (horário errado, valor desatualizado, observação faltando). Bloquear edição após a primeira candidatura força cancelar e republicar — perde candidatos já alinhados e cria churn desnecessário.

## Decisão

> **Edição de vaga é permitida após receber candidaturas. Toda alteração relevante notifica os candidatos pendentes, que podem manter, retirar ou ajustar a candidatura conforme o caso.**

Campos com **notificação obrigatória** (alteração material):

- Data e hora (início ou fim).
- Valor do turno.
- Função.
- Número de posições (vagas).
- Localização do estabelecimento (caso aplicável).
- Observações do contratante (texto livre que afeta expectativa).

Campos com **edição livre** (sem notificação):

- Detalhes não materiais (ortografia, formatação).

A notificação informa o que mudou (diff antes/depois) e dá ao candidato 24h ou até o início do turno (o que ocorrer antes) para confirmar a manutenção da candidatura. Sem confirmação no prazo, candidatura é retirada automaticamente.

## Justificativa

Permitir edição reduz churn de vagas e candidaturas válidas. Notificar candidatos preserva a confiança (ninguém aceita o que não viu). A regra de prazo evita candidatura zumbi.

## Consequências

### Positivas
- Menos vagas canceladas e republicadas.
- Contratantes operam com menos atrito.
- Candidatos têm informação atualizada antes de assumir compromisso.

### Negativas / trade-offs aceitos
- Notificação em massa quando vaga tem muitos candidatos (limita a percepção de spam — UX precisa ser leve, mensagem clara).
- Edição mal-intencionada (mudar valor para menor após candidatura) é possível — mitigado por: candidato vê o diff antes de confirmar; padrões suspeitos podem virar caso de admin.

### Para o time técnico
- ADRs prováveis: modelo de dados de versão da vaga (snapshot original + edições); notificação ao candidato; estado da candidatura ("pendente_revisão" após edição material).
- Impacto em épicos: EPIC de publicação/gestão de vaga; EPIC de candidatura.

## Sinais de revisão

- Se taxa de retirada após edição > 40%, reabrir copy da notificação e timeline.
- Se padrões de edição mal-intencionada forem detectados, bloquear edição material após X candidaturas ou após determinado tempo.
