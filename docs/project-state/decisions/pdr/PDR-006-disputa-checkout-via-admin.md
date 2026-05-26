---
pdr_id: PDR-006
slug: disputa-checkout-via-admin
title: Disputa de check-out marca turno como "em_disputa" e é resolvida no backoffice admin
status: accepted
decided_at: 2026-05-26
decided_by: PO (Alexandro / Claude)
supersedes: null
superseded_by: null
related_epics: []
related_adrs: []
---

# PDR-006 — Disputa de check-out via admin

## Contexto

O check-out é o momento mais sensível do turno: profissional encerrou, gerou PIN, contratante valida. Se o contratante discordar do valor ou do desempenho, o protótipo apenas remove o PIN e mostra mensagem ambígua. A operação real precisa de estado e fluxo claros.

## Decisão

> **Quando o contratante recusa validar o check-out, o turno transita para o estado `em_disputa`. O caso entra na fila de disputas do backoffice admin e é resolvido manualmente pela equipe Turni, com prazo público de 30 minutos.**

O profissional é notificado da abertura da disputa. O contratante pode anexar justificativa textual ao recusar a validação. O admin tem acesso ao histórico completo do turno (chat, geofencing, checklist, cronômetro, vaga original) para decidir.

Resultados possíveis da resolução:

- **Pagar integralmente** ao profissional — admin libera o check-out manualmente.
- **Pagar parcialmente** (valor ajustado para baixo) — admin registra valor revisado, profissional recebe o ajustado, contratante paga o ajustado + taxa Turni proporcional.
- **Não pagar** — admin marca turno como `disputa_resolvida_sem_pagamento`, com justificativa registrada (impacta score de ambos os lados).

## Justificativa

Disputa é evento raro mas crítico — precisa de processo, não de improviso. Resolver no admin com prazo curto preserva confiança bilateral. Permitir três resoluções distintas evita decisões binárias forçadas quando a verdade está no meio.

## Consequências

### Positivas
- Estado e fluxo claros, auditáveis.
- Confiança bilateral preservada (lado prejudicado tem para onde recorrer).
- Trilha de auditoria completa para análise posterior.

### Negativas / trade-offs aceitos
- Operação Turni assume carga de mediação manual (limita escala antes de automação).
- Pagar.me precisa suportar captura parcial ou estorno — depende de implementação.
- SLA de 30 min é promessa pública que vira pressão operacional.

### Para o time técnico
- ADRs prováveis: integração Pagar.me com captura parcial e estorno; modelo de dados de disputa (justificativa, anexos, decisão, audit trail).
- Impacto em épicos: EPIC de check-out e pagamento; EPIC de backoffice mínimo viável (precisa contemplar fila de disputas desde a primeira onda).

## Sinais de revisão

- Se taxa de disputa > 3% dos turnos finalizados (limite definido na métrica de apoio M3), reabrir análise de causa-raiz.
- Se SLA de 30 min for descumprido em mais de 10% dos casos, repensar processo ou capacidade.
- Se padrões de disputa repetitivos forem detectados (mesmo contratante abrindo disputas frequentes contra profissionais distintos), abrir fluxo de penalização específico via novo PDR.
