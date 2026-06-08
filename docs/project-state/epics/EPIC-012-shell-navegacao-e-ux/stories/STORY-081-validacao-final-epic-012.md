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

### Veredito
- 

### Evidências
- 

### Fails (se houver)
- 
