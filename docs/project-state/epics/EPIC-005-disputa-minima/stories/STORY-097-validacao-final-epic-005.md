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

- [x] **CA-1:** Fluxo completo exercitado e evidenciado (Blocos 1–5 do report): E2E de abertura (`disputa_test.dart`) + resolução (`disputas.spec.ts`) verdes; stage com turno `em_disputa` semeado (pré-auth `concluida`), notificação+banner cobertos, resolução → `finalizado` + captura/Pix + avaliação recíproca.
- [x] **CA-2:** Trilha verificada (Bloco 6): abertura (`turno.disputa_aberta`, justificativa/aberta_em/por) + resolução (`turno.disputa_resolvida`, resolucao/resolvida_em/por/nota); confirmado no stage (audit de abertura + justificativa).
- [x] **CA-3:** Suítes verdes (api 1118 / admin 153 / webapp 753); geral ≥80% (94,8 / 95,8 / 87,9); núcleo 100% na api e admin **exceto 2 controllers de disputa em 91,7%** (catch defensivo inalcançável — pass com ressalva, não fail); CI verde na main (run 27373316385).
- [x] **CA-4:** E2E de disputa (recusa + resolve) verdes; caminho feliz EPIC-003/004 (`web_test.dart` ciclo confirmado→finalizado, cronômetro, perfil/score) sem regressão.
- [x] **CA-5:** RBAC/fail-secure verificados: abertura só contratante dono (403 profissional/outro, 401 anônimo); resolução só admin (401 sem/errado segredo, 403 não-admin); idempotência financeira confirmada (2º clique → 422, captura uma só vez).
- [x] **CA-6:** Fora do MVP confirmado não-alcançável/exposto: `paga_parcial`/`sem_pagamento` (controller sem param `resolucao`), captura parcial (`capturarParcial` sem chamadores), penalidade automática (sem regra), estados `finalizado_ajustado`/`disputa_resolvida_sem_pagamento` sem `transitionTo`.
- [x] **CA-7:** `validation/report.md` produzido com veredito **approved**, evidências (runs/deploys/coberturas/queries) e observações não-bloqueantes acionáveis.

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

- [x] Checklist executado integralmente; `validation/report.md` escrito com veredito (approved) e evidências.
- [x] `index.json` atualizado: STORY-097 `done`; `validation_report` + `validation_verdict` do EPIC-005 referenciados.
- [x] PO notificado para decidir o fechamento do épico e da onda (no chat da sessão).
- [x] "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md` e a skill `validador`.

## Notas do agente (preenchido durante/após execução)

### Veredito
- **approved** — 2026-06-11. Relatório completo em `validation/report.md` (commit `27a9583`, branch `main`). 0 fail bloqueante, 0 fail não-bloqueante; 4 passes com ressalva + 3 observações registradas.

### Evidências
- **Suítes/cobertura:** api `make test-api` 1118 passed, geral 94,8%, núcleo 100% (exceto 2 controllers de disputa em 91,7% — catch defensivo inalcançável); admin 153 passed, geral 95,8%, núcleo disputa 100%; webapp `flutter test` 753 passed, geral lib 87,9%.
- **CI verde na main:** run `27373316385` (commit `27a9583`) success, 10 jobs (incl. Trivy api/admin + Commit lint). Trivy corrigido em `019b668`.
- **E2E:** webapp `make e2e-webapp` EXIT=0 (`disputa_test.dart` abertura + `web_test.dart` ciclo confirmado→finalizado/cronômetro/perfil = no-regression EPIC-003/004); admin `make e2e-admin` 15 passed (`disputas.spec.ts` (a) resolver + (b) nota vazia bloqueia).
- **Stage:** Deploy run `27372780215` verde; seed `db:seed` (exec `turni-migrate-stage-4tfzm`) criou o turno `em_disputa`; query de banco (exec `…-rfjgc`): `EM_DISPUTA_COUNT=2`, justificativa presente, `RESOLUCAO=NULL`, pré-auth `concluida`, audit de abertura=1; `/disputas` anônimo→302 `/login` (fail-secure); smoke visual logado chancelado pelo PO.
- **Escopo MVP:** `paga_parcial`/`sem_pagamento`/captura parcial/penalidade não alcançáveis nem expostos (controller sem param `resolucao`; `capturarParcial` sem chamadores; sem `transitionTo` para `finalizado_ajustado`/`disputa_resolvida_sem_pagamento`).

### Bloqueantes / pendências (se houver)
- **Nenhum bloqueante.** Observações não-bloqueantes (detalhe no report, seção "Limitações"): (1) flake pré-existente `GerarPinCheckoutTest` (EPIC-003, ~18% na suíte cheia, verde no CI, não tocado pelo EPIC-005); (2) 2 controllers de disputa em 91,7% (linhas 37/41 — catches defensivos inalcançáveis via HTTP); (3) flake de cold-start no Playwright do admin (passa no retry #1).
- **Decisão de fechamento do EPIC-005 e da WAVE-2026-01 é do PO** (esta estória não marca o épico como done).
