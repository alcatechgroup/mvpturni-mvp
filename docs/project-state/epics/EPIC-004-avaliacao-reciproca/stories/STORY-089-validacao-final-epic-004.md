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
status: done
owner_agent: claude-opus-4-8-validador-2026-06-09
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

> Execução: validador (claude-opus-4-8), 2026-06-09. Relatório completo em `validation/report.md`.
> Nota de processo: o `validation/checklist.md` não existia ao iniciar (pré-condição ausente). O PO o escreveu antes desta execução (commit `3e25b14`); a validação seguiu o padrão "validador executa, não escreve o próprio checklist".

### Veredito
- **REJECTED** — 1 fail bloqueante (F-B-1). 14 blocos `pass`, 3 `pass com ressalva`, 1 `n/a` justificado, 0 fails não-bloqueantes.

### Evidências
- **Ciclo vivo em homolog (métrica primária)**: gate `pode_candidatar=False` (3 turnos `avaliacao_pendente=True`) → submissão profissional→contratante HTTP 201×3 → `pode_candidatar=True`. (report A.4)
- **Perfil + LGPD ao vivo**: profissional score=4.7/Iniciante/6 turnos, depoimentos nominais; contratante score=4.7, depoimentos anônimos (`autor_nome=None`). (report A.3)
- **Suítes**: api **1082 passed**, cobertura total 94.6%, núcleo `MotorReputacao`/`NivelProfissional` 100%; webapp "All tests passed!" (≈737). (report §10)
- **E2E browser real**: `perfil_test` (perfil+gate) "All tests passed." same-origin. (report A.5; A.6 = `turnos_test`/avaliar_turno)
- **Deploy**: rc.101 Release todos os jobs ✓ incl. "Smoke pós-deploy (homolog)"; produção gated. WebApp homolog = v0.1.0-rc.101. (report A.7)

### Fails (se houver)
- **F-B-1 (bloqueante)** — Pipeline **CI vermelho na `main`** desde o follow-up rc.101: violação de estilo Pint (`fully_qualified_strict_types`/`ordered_imports`) em `apps/api/tests/Feature/Turno/TurnosListaTest.php` (uso inline de `\App\Models\Avaliacao` nas linhas 194/217). Reproduzido localmente no HEAD `3e25b14`. Natureza cosmética (suíte verde, deploy verde via workflow Release separado), mas pela régua objetiva pipeline-vermelho-na-main é bloqueante. (report A.8)
