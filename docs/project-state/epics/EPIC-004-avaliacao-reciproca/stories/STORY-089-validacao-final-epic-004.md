---
story_id: STORY-089
slug: validacao-final-epic-004
title: "Validação final do EPIC-004 — avaliação recíproca e fechamento do ciclo"
epic_id: EPIC-004
sprint_id: SPRINT-2026-W30
type: validation
target_role: validador
requires_design: false
design_screen_id: null
status: ready
owner_agent: null
created_at: 2026-06-09
updated_at: 2026-06-09
estimated_session_size: M
produces_idr: null
---

# STORY-089 — Validação final do EPIC-004

> **Para o agente que vai executar:** carregue a skill `validador`. Execute o checklist em `validation/checklist.md` em ordem, registre `pass | fail | n/a` com evidência, e produza `validation/report.md` com veredito. **Não conserte nada** — registre e devolva ao PO.

## Contexto (por que esta estória existe)

É a última estória do EPIC-004. Verifica de forma independente que o ciclo fecha: turno `finalizado` → avaliação recíproca obrigatória → XP/score/nível atualizam → gate bloqueante ativo, tudo demonstrável em homologação.

- Épico: `epics/EPIC-004-avaliacao-reciproca/epic.md`
- Checklist: `epics/EPIC-004-avaliacao-reciproca/validation/checklist.md` (o PO escreve antes desta estória iniciar).

## O quê (objetivo desta estória)

Executar o checklist de validação do EPIC-004 em homologação e emitir veredito (`approved` / `approved_with_pending` / `rejected`) com evidência verificável.

## Por quê (valor para o usuário)

Garante que o fechamento do ciclo é real e demonstrável — não só código mergeado — antes de o PO fechar o épico e a onda evoluir o algoritmo de match.

## Critérios de aceite

- [ ] **CA-1:** Todos os itens do `checklist.md` executados com status e evidência (link/screenshot/log).
- [ ] **CA-2:** Verificação do ciclo ponta a ponta em homologação: turno finalizado → avaliação dupla → XP/score/nível atualizados → gate bloqueia próxima ação sem avaliação.
- [ ] **CA-3:** Métricas do épico verificadas: gate funciona (bloqueio com mensagem clara); subida de nível ≤1s; score recíproco atualizado no perfil.
- [ ] **CA-4:** `validation/report.md` produzido com veredito e lista de fails (se houver), classificados bloqueante/não-bloqueante.

## Fora de escopo

- Consertar qualquer coisa (papel do Programador, sob decisão do PO).
- Sugerir próximas estórias (o validador se atém a evidência + veredito).

## Padrões de qualidade exigidos

`docs/skills/po/references/quality-standards.md`. O validador roda a suíte, confere cobertura/E2E e valida em homologação.

## Dependências

- **Bloqueada por:** STORY-085, STORY-086, STORY-087, STORY-088 (todas `done`).
- **Bloqueia:** fechamento do EPIC-004.

## Decisões já tomadas (não as reabra)

- Todas as DDR/ADR/PDR vigentes, incluindo ADR-019 e DDR-004; MVP cuts do `epic.md`.

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
