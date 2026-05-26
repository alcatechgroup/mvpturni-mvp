---
pdr_id: PDR-010
slug: refresh-pix-fora-de-escopo-mvp
title: Tratamento de falha de Pix após 15 min está fora do escopo do MVP
status: accepted
decided_at: 2026-05-26
decided_by: PO (Alexandro / Claude)
supersedes: null
superseded_by: null
related_epics: []
related_adrs: []
---

# PDR-010 — Refresh / falha de Pix após 15 min fora do MVP

## Contexto

A promessa pública do Turni é "Pix em até 15 minutos após o check-out validado". Pagar.me é a infraestrutura de pagamento. Falhas pontuais (instabilidade Pagar.me, chave Pix inválida, banco intermitente) podem fazer o SLA estourar. O tratamento sofisticado dessas falhas — retry inteligente, fallback, comunicação proativa, ressarcimento por SLA descumprido — exige design de produto, regras claras e talvez integração com sistemas de suporte que não cabem no MVP.

## Decisão

> **No MVP, o sistema executa a transferência Pix uma única vez após o check-out validado. Falhas no Pagar.me geram alerta no backoffice admin para tratamento manual pela equipe Turni. Não há motor automático de retry, fallback ou comunicação proativa ao profissional.**

A promessa pública de 15 minutos é mantida como **promessa de design**, não como SLA contratual com remediation automática. Casos de falha viram tickets internos resolvidos pelo admin via comunicação direta com Pagar.me e profissional afetado.

## Justificativa

Tratamento sofisticado de falha de pagamento é trabalho denso (retry exponencial, decisão de fallback, comunicação automatizada, política de SLA contratual). No MVP, o volume baixo de turnos permite tratamento manual com qualidade. Construir motor automático prematuramente seria overengineering antes de conhecer os modos reais de falha.

## Consequências

### Positivas
- MVP de pagamento entrega o caminho feliz sem custo de cenários de borda.
- Equipe Turni vê cada falha de Pix e aprende o padrão real antes da automação.

### Negativas / trade-offs aceitos
- Profissional pode esperar mais do que 15 min em casos de falha real, com comunicação não-automatizada.
- Operação Turni assume carga manual de resolução.
- Se o volume crescer e a equipe virar gargalo, esta decisão precisa ser revertida.

### Para o time técnico
- ADRs prováveis: integração Pagar.me com captura de erro e notificação ao backoffice; modelo de dados de evento de pagamento com status (`pendente`, `enviado`, `falhou`, `manual`).
- Impacto em épicos: EPIC de pagamento (escopo reduzido); EPIC de backoffice precisa ter visão de pagamentos com falha desde a primeira onda.

## Sinais de revisão

- Se taxa de falha de Pix > 1% das transferências, antecipar motor de retry/fallback.
- Se SLA público de 15 min for descumprido em mais de 5% dos casos, reabrir prioridade.
- Após 6 meses de operação, abrir PDR de evolução com base no padrão de falha observado.
