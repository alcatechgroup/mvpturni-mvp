---
story_id: STORY-079
slug: estados-vazios-erro-carregamento
title: "Padronizar estados vazios, de erro e de carregamento (skeleton) nas telas do WebApp"
epic_id: EPIC-012
sprint_id: SPRINT-2026-W29
type: implementation
target_role: programador
requires_design: true
design_screen_id: SCREEN-STORY-079-estados-padrao
status: ready
owner_agent: null
created_at: 2026-06-08
updated_at: 2026-06-08
estimated_session_size: M
produces_idr: null
---

# STORY-079 — Estados vazios, de erro e de carregamento padronizados

> **Para o agente que vai executar:** leia esta estória por inteiro. Designer entrega o spec dos 3 estados em paralelo.

## Contexto (por que esta estória existe)

As telas da WAVE-2026-01 tratam estado vazio, erro e carregamento de forma **ad-hoc** — cada uma à sua maneira. O `patterns.md` já nomeia `pattern.empty` e `pattern.error` como padrões previstos mas ainda não catalogados. Para um público não-técnico, esses estados são onde a confiança se ganha ou se perde.

- Épico: `epics/EPIC-012-shell-navegacao-e-ux/epic.md`
- Padrões: `design/system/patterns.md` (`pattern.empty`, `pattern.error`), `design/system/components.md`, tokens.

## O quê (objetivo desta estória)

Padronizar, via componentes do Design System, os três estados nas telas do WebApp: **vazio** (instrução + próximo passo + CTA contextual), **erro** (recuperável: mensagem + "tentar de novo"; não-recuperável: saída clara), **carregamento** (skeleton/placeholder consistente em vez de spinner solto).

## Por quê (valor para o usuário)

Estado vazio que instrui o próximo passo, erro que oferece saída e carregamento que comunica progresso reduzem a carga cognitiva e a sensação de "travou" — exatamente o que pesa para o usuário não-técnico.

## Critérios de aceite

- [ ] **CA-1:** Existe um componente de **estado vazio** reutilizável (DS) com instrução + próximo passo + CTA contextual; aplicado a todas as listas do WebApp (feed, vagas, candidatos, turnos, notificações). Microcopy em pt-BR.
- [ ] **CA-2:** Existe um padrão de **erro recuperável** (mensagem + "tentar de novo" que re-dispara a ação) e de **erro não-recuperável** (saída clara para um destino do shell); aplicado às telas que fazem fetch.
- [ ] **CA-3:** Existe um padrão de **carregamento** (skeleton/placeholder) consistente, aplicado às telas com fetch perceptível.
- [ ] **CA-4:** Os três padrões entram no `patterns.md` (e componentes no `components.md`) — deixam de ser "ponteiro nomeado".
- [ ] **CA-5:** Nenhuma regra de negócio nova é introduzida — só apresentação de estado. Erro nunca é só cor (ícone + texto — regra herdada dos tokens).
- [ ] **CA-6:** Cobertura ≥ 80% no código novo; E2E/widget test cobre pelo menos: lista vazia mostra o estado certo; erro de fetch mostra "tentar de novo" e o retry re-dispara; carregamento mostra skeleton.
- [ ] **CA-7:** Deploy homologação verificado.

## Fora de escopo

- Shell (077/078). Auditoria a11y ampla (080), embora os novos componentes já nasçam AA.
- Mudança de copy de domínio que exija decisão de produto (escalar ao PO se aparecer).

## Padrões de qualidade exigidos

`docs/skills/po/references/quality-standards.md`. ≥80%; widget/E2E test; pt-BR (DDR-002); AA nos novos componentes.

## Dependências

- **Bloqueada por:** STORY-077 (recomendado — os estados vivem dentro das telas do shell); pode iniciar em paralelo a STORY-078 desde que coordene as telas tocadas.
- **Bloqueia:** STORY-081 (validação).

## Decisões já tomadas (não as reabra)

- DDR-001/002, ADR-007, regra dos tokens "erro nunca é só cor; estado vazio sempre instrui o próximo passo".

## Liberdade técnica do agente

Decide: estrutura dos componentes de estado, como injetá-los nas telas, design dos testes.

NÃO decide: copy de domínio que exija decisão de produto, CAs.

## Definição de Pronto (DoD)

- [ ] CAs passam; testes verdes; cobertura atingida.
- [ ] `patterns.md` + `components.md` atualizados.
- [ ] Pipeline verde; deploy homolog verificado (PO confirma visualmente).
- [ ] `index.json` atualizado: status = `done`. "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

`docs/skills/po/references/agent-task-format.md`. Designer revisa o PR.

## Notas do agente (preenchido durante/após execução)

### Decisões tomadas
- 

### Descobertas
- 

### Bloqueios encontrados
- 

### Cobertura final
- Unitários:  / E2E: 

### Links de evidência
- PR / Pipeline / Deploy homolog: 
