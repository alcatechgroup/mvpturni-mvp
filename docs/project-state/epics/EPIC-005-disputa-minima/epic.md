---
epic_id: EPIC-005
slug: disputa-minima
title: Disputa mínima de check-out via backoffice
wave: WAVE-2026-01
status: draft
owner_role: po
created_at: 2026-05-26
updated_at: 2026-05-26
target_completion: 2026-09-01  # estimativa orientativa
---

# EPIC-005 — Disputa mínima via backoffice

## Por que existimos (problema do usuário)

Sem este épico, contratante que recusar check-out cria estado fantasma — o turno fica preso entre `aguardando_checkout` e `finalizado`, ninguém recebe Pix, ninguém é notificado, e o admin não tem ferramenta para mediar. A WAVE-2026-01 entrega o caminho feliz; este épico garante que o **caminho de exceção mais crítico** tem tratamento mínimo defensável.

PDR-006 define o fluxo completo de disputa com três resoluções (`paga_integral`, `paga_parcial`, `sem_pagamento`). No MVP, apenas a primeira resolução é implementada — captura parcial e sem_pagamento ficam para EPIC-007 da próxima onda.

## Resultado esperado (outcome)

Ao fim deste épico, contratante consegue recusar validação do check-out com justificativa textual obrigatória; turno transita para `em_disputa`; admin vê o item na fila do backoffice; admin resolve com **"paga integral"** (executa captura padrão e libera Pix sandbox); profissional é notificado do início e do desfecho da disputa.

Casos "paga parcial" e "sem pagamento" ficam **fora do MVP** — o admin, no MVP, escolhe entre "paga integral" (resolve) ou comunica externamente o usuário e marca para tratar na próxima onda.

## Métrica de sucesso (como saberemos que funcionou)

- **Primária**: contratante recusa check-out em homologação → turno transita para `em_disputa` em ≤ 1s → admin vê na fila → admin resolve com "paga integral" → Pix sandbox sai em ≤ 15 min após resolução.
- **Trilha de auditoria**: 100% das disputas registram justificativa do contratante + timestamp + admin que resolveu + decisão.
- **Notificação**: profissional recebe notificação in-app + e-mail dentro de 30s após abertura e dentro de 30s após resolução.

## Entregável visível no fim do épico

- [ ] No fluxo de validação do check-out, contratante tem ação "Recusar e abrir disputa" com campo de justificativa obrigatório.
- [ ] Ao recusar, turno transita para `em_disputa`; Pagar.me mantém pré-autorização (sem liberar nem capturar).
- [ ] Profissional vê banner "valor em disputa — equipe Turni vai mediar em até 30 min" + recebe e-mail.
- [ ] Admin vê turno em `em_disputa` em `admin.homolog.turni.com.br/disputas` com toda a trilha (chat, geofencing, checklist, cronômetro, justificativa do contratante).
- [ ] Admin tem ação "Resolver: pagar integral" que executa captura padrão e libera Pix.
- [ ] Histórico do turno registra a disputa, a resolução, o admin que decidiu.

## Fora de escopo (explicitamente)

- Resoluções `paga_parcial` e `sem_pagamento` (PDR-006) — vira EPIC-007 da WAVE-2026-02.
- Captura parcial / estorno parcial via Pagar.me — vira EPIC-007.
- UI rica de mediação (chat dedicado entre admin e ambos os lados) — fora do MVP.
- Anexos / evidências do contratante na justificativa — texto livre é suficiente.
- Recurso do profissional contra resolução do admin — vira épico futuro.
- Detecção de padrões de abuso (contratante que abre disputas com frequência) — fora do MVP.
- Comunicação automatizada admin↔partes durante mediação — fora do MVP (admin contata por canais externos quando necessário).

## Referências da especificação

- `docs/especificacao/domain/disputa.md` — atributos, fluxo, resoluções (resoluções parciais marcadas como fora do MVP).
- `docs/especificacao/domain/turno.md` — estado `em_disputa` na máquina de estados.
- `docs/especificacao/domain/pagamento.md` — pré-autorização permanece bloqueada durante disputa.
- `docs/especificacao/flows/disputa.md` — fluxo (a escrever).
- `docs/especificacao/flows/mediacao-de-disputa.md` — fluxo do admin (a escrever).
- `docs/especificacao/non-functional.md` — SLA público de 30 min para resolução.
- `docs/project-state/decisions/pdr/PDR-006-disputa-checkout-via-admin.md` — base do épico.
- `docs/project-state/decisions/pdr/PDR-003-duas-interfaces-webapp-e-backoffice.md` — disputa entra no backoffice mínimo.

## Dependências

- **Bloqueia**: nada na WAVE-2026-01. Habilita disputa completa em EPIC-007 (WAVE-2026-02).
- **Bloqueado por**: EPIC-003 (precisa de check-out funcionando para haver recusa).
- **Decisões arquiteturais necessárias**:
  - Modelo de dados de disputa (justificativa, evidências, resolução, audit trail).
  - Captura padrão Pagar.me via comando do admin (não pelo fluxo normal de check-out).
  - Notificação ao profissional na abertura e na resolução.

## Estórias

> A decompor via Fluxo B quando o épico entrar em sprint.

## Validação final

Critérios em `validation/checklist.md`. Relatório do validador em `validation/report.md`.

**Definição de épico concluído**: contratante consegue abrir disputa; admin resolve "paga integral"; Pix sandbox sai; trilha de auditoria completa; relatório do validador `approved`. **Fechamento desta onda** ocorre com o relatório positivo deste épico.

## Histórico

- 2026-05-26 — criado por PO durante planejamento da WAVE-2026-01.
