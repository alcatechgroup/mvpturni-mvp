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
status: done
owner_agent: programador
created_at: 2026-06-08
updated_at: 2026-06-09
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

- [x] **CA-1:** Existe um componente de **estado vazio** reutilizável (DS) com instrução + próximo passo + CTA contextual; aplicado a todas as listas do WebApp (feed, vagas, candidatos, turnos, notificações). Microcopy em pt-BR. → `TurniEmptyState`.
- [x] **CA-2:** Existe um padrão de **erro recuperável** (mensagem + "tentar de novo" que re-dispara a ação) e de **erro não-recuperável** (saída clara para um destino do shell); aplicado às telas que fazem fetch. → `TurniRetryState` + `TurniEmptyState` com CTA de saída.
- [x] **CA-3:** Existe um padrão de **carregamento** (skeleton/placeholder) consistente, aplicado às telas com fetch perceptível. → `TurniSkeletonList`/`Card`/`Box`.
- [x] **CA-4:** Os três padrões entram no `patterns.md` (e componentes no `components.md`) — deixam de ser "ponteiro nomeado".
- [x] **CA-5:** Nenhuma regra de negócio nova é introduzida — só apresentação de estado. Erro nunca é só cor (ícone + texto — regra herdada dos tokens).
- [x] **CA-6:** Cobertura ≥ 80% no código novo; E2E/widget test cobre pelo menos: lista vazia mostra o estado certo; erro de fetch mostra "tentar de novo" e o retry re-dispara; carregamento mostra skeleton. → 100% (60/60) em `state_views.dart`; `test/ds/state_views_test.dart`.
- [x] **CA-7:** Deploy homologação verificado. → rc.90, run `27202808294` verde + smoke; `version.json`=rc.90. (Confirmação visual do PO pendente — gate humano.)

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
- **Extração dos 3 estados para o DS** em `apps/webapp/lib/ds/components/state_views.dart`:
  `TurniEmptyState` (vazio: ícone + título + mensagem que instrui + CTA opcional),
  `TurniRetryState` (erro recuperável: ícone + texto + "Tentar de novo" que re-dispara a
  carga) e `TurniSkeletonList`/`TurniSkeletonCard`/`TurniSkeletonBox` (carregamento).
- **Erro não-recuperável** = `TurniEmptyState` com ícone de bloqueio + CTA de saída para um
  destino do shell (RBAC cruzado, vaga inexistente) — mesmo arranjo do vazio, muda
  ícone/copy/ação. Não criei um 4º componente.
- **Padronizei o erro de tela cheia como CENTRALIZADO** (ícone + título + apoio + retry),
  unificando os dois estilos que existiam no código (banner-no-topo do feed/turnos/vagas
  vs. centralizado das notificações). Copy unificada: título "Não foi possível carregar X."
  + apoio "Verifique sua conexão.".
- **Preservei as `Key` por tela** (`feed-vazio`, `turnos-erro-banner`, `*-retry-btn`,
  `*-skeleton`, …): os componentes não fixam Key, a tela passa a sua. Por isso a suíte de
  widget/E2E existente seguiu verde sem reescrever seletores.
- **Skeleton estático** (sem shimmer/animação) — consistência nos dois temas e zero timer
  nos testes; "placeholder consistente" satisfeito sem animação.
- **Escopo do refactor:** as 5 listas da CA-1 (feed, minhas vagas, candidatos, turnos,
  notificações). O **erro inline mid-flow** (gerar PIN, validar check-in/out, cronômetro)
  ficou como micro-padrão de **banner** local — distinto do estado de tela inteira — e está
  documentado assim em `patterns.md`; não foi unificado (não inflar; W28).

### Descobertas
- **Possível bug de copy (escalar ao PO):** o estado vazio do painel de candidatos diz
  *"Vamos avisar assim que chegar o primeiro. Member Start: em até 2h."* — "Member Start:"
  parece resíduo/placeholder. **Preservei verbatim** (mudar copy de domínio é decisão de
  produto, fora de escopo). Sugiro corrigir numa estória de microcopy (STORY-080).

### Bloqueios encontrados
- **Spec de design (`SCREEN-STORY-079-estados-padrao`) não existe.** Como as regras já
  estavam fixadas (tokens DDR-001: "vazio instrui o próximo passo", "erro nunca é só cor")
  e o feed já era a referência madura do padrão, segui o padrão de-facto e o promovi a DS.
  Designer revisa o PR/diff.

### Cobertura final
- Unitários: `test/ds/state_views_test.dart` (10 casos) — **100% de linhas** em
  `state_views.dart` (60/60). Suíte completa do WebApp: **632 testes verdes**. As telas
  migradas mantêm seus widget tests de vazio/erro/skeleton (CA-6).
- E2E: cobertos pelos integration_test existentes das telas (não regrediram).

### Links de evidência
- Commit: `a3a0d64` (feat STORY-079) na `main`.
- Deploy homolog: tag `v0.1.0-rc.90` → release run `27202808294` **verde** (migrate+seed,
  api, admin, WebApp/Firebase e **smoke pós-deploy** todos `success`; a 1ª execução falhou
  só no `setup-gcloud` do job de migração — flake transitório de infra, re-run verde).
  `https://app.homolog.turni.com.br/version.json` → `v0.1.0-rc.90`.
- **Confirmação visual do PO:** pendente (gate humano da DoD) — eyeball dos estados
  vazio/erro/skeleton no app de homolog.
