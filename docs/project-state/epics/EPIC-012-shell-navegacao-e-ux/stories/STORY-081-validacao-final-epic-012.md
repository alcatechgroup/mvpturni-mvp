---
story_id: STORY-081
slug: validacao-final-epic-012
title: "Validação final do EPIC-012 — shell de navegação e pente fino de UX"
epic_id: EPIC-012
sprint_id: SPRINT-2026-W29
type: validation
target_role: validador
requires_design: false
design_screen_id: null
status: ready
owner_agent: null
created_at: 2026-06-08
updated_at: 2026-06-08
estimated_session_size: M
---

# STORY-081 — Validação final do EPIC-012

> **Para o agente que vai executar:** carregue a skill `validador`. Execute o checklist em `validation/checklist.md` em ordem, registre `pass | fail | n/a` com evidência, e produza `validation/report.md` com veredito. **Não conserte nada** — registre e devolva ao PO.

## Contexto (por que esta estória existe)

É a última estória do EPIC-012. Verifica de forma independente que o shell de navegação está vivo e coerente nos dois papéis e nos dois tamanhos, que nenhuma tela ficou órfã, que os estados vazios/erro/carregamento foram padronizados e que a acessibilidade AA está verde.

- Épico: `epics/EPIC-012-shell-navegacao-e-ux/epic.md`
- Checklist: `epics/EPIC-012-shell-navegacao-e-ux/validation/checklist.md`

## O quê (objetivo desta estória)

Executar o checklist de validação do EPIC-012 em homologação e emitir veredito (`approved` / `approved_with_pending` / `rejected`) com evidência.

## Por quê (valor para o usuário)

Garante que a melhoria de navegação e UX é real e demonstrável — não só código mergeado — antes de o PO fechar o épico e abrir o EPIC-004.

## Critérios de aceite

- [ ] **CA-1:** Todos os itens do `checklist.md` executados com status e evidência (link/screenshot/log).
- [ ] **CA-2:** Verificação visual em **browser real**, nos dois tamanhos (mobile ≥360px e desktop ≥1280px) e nos dois temas.
- [ ] **CA-3:** Métricas do épico verificadas: 100% das telas autenticadas alcançáveis pelo shell sem digitar rota; gate de a11y AA verde; responsividade correta nos breakpoints.
- [ ] **CA-4:** `validation/report.md` produzido com veredito e lista de fails (se houver), classificados bloqueante/não-bloqueante.

## Fora de escopo

- Consertar qualquer coisa (papel do Programador, sob decisão do PO).
- Sugerir próximas estórias (o validador se atém a evidência + veredito — aprendizado W23/W25/W27).

## Padrões de qualidade exigidos

`docs/skills/po/references/quality-standards.md`. O validador roda a suíte, confere cobertura e E2E, e valida em homologação.

## Dependências

- **Bloqueada por:** STORY-077, STORY-078, STORY-079, STORY-080 (todas `done`).
- **Bloqueia:** fechamento do EPIC-012.

## Decisões já tomadas (não as reabra)

- Todas as DDR/ADR/PDR vigentes, incluindo DDR-003 (navegação) e PDR-018.

## Definição de Pronto (DoD)

- [ ] Checklist completo; `report.md` com veredito.
- [ ] `index.json` atualizado: status = `done` (da estória) e `validation_report` do épico preenchido.
- [ ] "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

`docs/skills/po/references/agent-task-format.md` + skill `validador`.

## Notas do agente (preenchido durante/após execução)

> Validação executada em 2026-06-09 (validador, sessão claude-opus-4-8). Relatório completo: `validation/report.md`.

### Veredito
- **APPROVED com pendências (`approved_with_pending`).** 25 pass, 4 pass com ressalva, 4 fails (0 bloqueantes, 4 não-bloqueantes), 0 n/a.
- A entrega central do épico (shell coerente/responsivo, nenhuma tela órfã, estados vazio/erro/carregamento padronizados) está demonstrável e verificada. Nenhum fail bloqueante.
- `index.json` atualizado: `validation_report` do EPIC-012 preenchido; status do épico **não alterado** (decisão do PO).

### Evidências
- Suíte completa `flutter test --coverage` (commit `d513632`): **660 verdes, 0 falha/skip**; gate a11y `test/a11y/` 28 verdes.
- Gate E2E de navegação re-rodado nesta validação (`make e2e-webapp-pinned`, Chrome pinado, same-origin): **"All tests passed."** — profissional·mobile + contratante·desktop (RBAC, ativo, deep-link, ad-hoc removido).
- Cobertura do código novo do épico: **95,4%** (349/366 linhas, via `coverage/lcov.info`).
- CI verde na HEAD (run 27207979133, 10 jobs `success`); deploy `v0.1.0-rc.91` (release run 27206992591) no ar e saudável (`/health.json`=rc.91).
- Browser real (Playwright/Chromium) em homolog rc.91, mobile 390×844 + desktop 1280×800 → `validation/evidence/homolog-*.png`.
- DDR-003 `accepted`; `patterns.md`/`components.md` com os padrões de navegação e de estado.

### Fails (se houver) — todos NÃO-bloqueantes
- **F-NB-1 (Bloco 4.1)**: contraste AA com gate em 6 de ~11 superfícies + amostragem manual não realizada (restante adiado pelo dono 2026-06-09).
- **F-NB-2 (Bloco 4.2)**: navegação por teclado não verificada/sem gate (CA-2 da STORY-080 descopado do MVP pelo dono 2026-06-09).
- **F-NB-3 (Bloco 7.3)**: `SCREEN-STORY-077-app-shell` está `ready`, o checklist pede `shipped`.
- **F-NB-4 (Bloco 7.4)**: `IDR-029` existe em disco mas não está indexado em `index.json`.
- Ressalvas: rail desktop a 44dp (WCAG 2.1 AA aceita; Material recomenda 48); cobertura não é emitida pelo CI (verificada localmente); `patterns.md` cita `NavigationSuiteScaffold` mas a impl. é composição manual (IDR-029).
- Limitação: shell **logado** em homolog não dirigido por automação (Flutter CanvasKit, sem DOM) — navegação logada coberta pelo gate E2E local + confirmação manual do dono registrada nas estórias.
