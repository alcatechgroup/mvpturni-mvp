---
story_id: STORY-097
slug: validacao-final-epic-005
title: Validação final do EPIC-005 — disputa mínima e fechamento da WAVE-2026-01
epic_id: EPIC-005
sprint_id: SPRINT-2026-W31
type: validation
target_role: validador
requires_design: false
status: blocked
owner_agent: null
created_at: 2026-06-10
updated_at: 2026-06-10
estimated_session_size: M
---

# STORY-097 — Validação final do EPIC-005

> **Para o agente que vai executar:** você carrega a skill `validador`. Execute o checklist em `epics/EPIC-005-disputa-minima/validation/checklist.md`, rode a bateria de validação e produza `validation/report.md` com veredito. **Não marque o épico como done** — isso é do PO, após ler seu relatório. Esta é a **última estória da WAVE-2026-01**: o veredito positivo fecha a onda.

## Contexto (por que esta estória existe)

O EPIC-005 entrega o caminho de exceção do check-out (disputa mínima) e fecha a WAVE-2026-01. Antes de declarar o épico — e a onda — concluídos, é preciso uma validação independente: o ciclo de disputa funciona ponta a ponta em homologação, a trilha de auditoria é completa, o pagamento sai na resolução e nada do caminho feliz regrediu.

- Épico: `epics/EPIC-005-disputa-minima/epic.md`
- Checklist: `epics/EPIC-005-disputa-minima/validation/checklist.md`
- Referências do validador: `docs/skills/validador/SKILL.md`, `references/verdict-criteria.md`, `references/reporting-craft.md`

## O quê (objetivo desta estória)

Executar a validação final do EPIC-005 e emitir `validation/report.md` com veredito (`approved` | `approved_with_pending` | `rejected`), evidências e qualquer bloqueante identificado.

## Por quê (valor para o usuário)

Garante que o caminho de exceção é defensável de verdade — não apenas "compila" — antes de fechar a onda que valida a promessa central do Turni.

## Critérios de aceite

- [ ] **CA-1:** Em homologação, o fluxo completo é exercitado e evidenciado: contratante recusa check-out com justificativa → turno `em_disputa` (pré-autorização mantida) → profissional notificado (in-app + e-mail) e com banner → admin vê na fila → resolve "pagar integral" → captura + Pix (fake) → turno `finalizado` → apto à avaliação recíproca.
- [ ] **CA-2:** Trilha de auditoria verificada: 100% das disputas registram `justificativa_contratante`, `aberta_em`/`aberta_por`, `resolucao`, `resolvida_em`/`resolvida_por` e `nota_admin` (quando informada).
- [ ] **CA-3:** Suítes verdes (api + webapp + admin) com as coberturas exigidas (≥ 80% geral, ≥ 98% no núcleo de disputa/pagamento); pipeline CI **verde na main** (lição F-B-1 da W30: CI vermelho, mesmo cosmético, é bloqueante).
- [ ] **CA-4:** E2E cobrindo o fluxo de disputa (contratante recusa, admin resolve) verdes; nenhum E2E vigente do caminho feliz (EPIC-003/004) regrediu.
- [ ] **CA-5:** RBAC e fail-secure verificados: só contratante abre, só admin resolve; sem vazamento entre papéis/contratantes; idempotência financeira (sem captura/Pix em dobro) confirmada.
- [ ] **CA-6:** Itens fora do MVP confirmados como **não** implementados/expostos: `paga_parcial`, `sem_pagamento`, captura/estorno parcial, penalidade automática.
- [ ] **CA-7:** `validation/report.md` produzido com veredito, evidências (links de runs/deploys), e — se `rejected`/`approved_with_pending` — os bloqueantes/pendências listados de forma acionável.

## Fora de escopo

- Corrigir bugs encontrados (isso vira estória de correção, decidida pelo PO).
- Marcar o épico/onda como `done` (é do PO após ler o relatório).

## Padrões de qualidade exigidos

Segue `quality-standards.md` e os critérios de veredito do validador. Validação é independente: não confie no relato das estórias, **execute e evidencie**.

## Dependências

- **Bloqueada por:** STORY-092, STORY-093, STORY-094, STORY-095, STORY-096 (todas `done`)
- **Bloqueia:** fechamento do EPIC-005 e da WAVE-2026-01
- **Pré-requisitos de ambiente:** homologação operante com seeds de disputa.

## Decisões já tomadas (não as reabra)

- Todo o épico e suas ADR-020/DDR-005; PDR-006/PDR-017; critérios de veredito do validador.

## Definição de Pronto (DoD)

- [ ] Checklist executado integralmente; `validation/report.md` escrito com veredito e evidências.
- [ ] `index.json` atualizado: STORY-097 `done`; `validation_report` do EPIC-005 referenciado com o veredito.
- [ ] PO notificado para decidir o fechamento do épico e da onda.
- [ ] "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md` e a skill `validador`.

## Notas do agente (preenchido durante/após execução)

### Veredito
- <approved | approved_with_pending | rejected> — <data>

### Evidências
- <links de runs, deploys, screenshots>

### Bloqueantes / pendências (se houver)
- <item acionável>
