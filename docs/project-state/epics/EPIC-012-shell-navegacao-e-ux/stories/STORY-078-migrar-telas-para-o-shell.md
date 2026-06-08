---
story_id: STORY-078
slug: migrar-telas-para-o-shell
title: "Migrar as telas existentes do WebApp para o shell (nenhuma órfã) + contexto/título no desktop"
epic_id: EPIC-012
sprint_id: SPRINT-2026-W29
type: implementation
target_role: programador
requires_design: true
design_screen_id: SCREEN-STORY-077-app-shell
status: ready
owner_agent: null
created_at: 2026-06-08
updated_at: 2026-06-08
estimated_session_size: M
produces_idr: null
---

# STORY-078 — Migrar telas existentes para o shell

> **Para o agente que vai executar:** leia esta estória por inteiro. Depende do shell da STORY-077.

## Contexto (por que esta estória existe)

Com o shell vivo (STORY-077), todas as telas já entregues na WAVE-2026-01 precisam **habitar o shell** em vez de ter porta de entrada própria (ícone na AppBar, rota direta). Nenhuma tela pode ficar órfã — alcançável só por URL.

- Épico: `epics/EPIC-012-shell-navegacao-e-ux/epic.md`
- Inventário de telas: `docs/especificacao/screens/README.md` e `design/screens/` (telas das STORY-046..067).
- Spec do shell: `design/screens/SCREEN-STORY-077-app-shell/` (DDR-003).

## O quê (objetivo desta estória)

Plugar as telas existentes do WebApp (feed do profissional, minhas vagas, painel de candidatos, turnos, detalhe do turno, notificações, perfil, etc.) nos destinos do shell por papel; remover/aposentar as portas de entrada ad-hoc (ícones soltos na AppBar) que o shell agora substitui; dar a cada tela um **título/contexto** coerente no desktop (cabeçalho de seção).

## Por quê (valor para o usuário)

Fecha o ciclo do shell: o usuário alcança **tudo** pelo menu, sem decorar rotas. Elimina a navegação fragmentada que motivou o épico.

## Critérios de aceite

- [ ] **CA-1:** Todas as telas autenticadas listadas no inventário (`screens/README.md`) para cada papel são alcançáveis a partir do shell, **sem digitar rota**. Nenhuma tela órfã.
- [ ] **CA-2:** As portas de entrada ad-hoc substituídas pelo shell (ex.: ícone `event_note` de "Meus turnos" da STORY-059; atalhos soltos) são removidas ou reconciliadas com o shell — sem caminho duplicado/conflitante para o mesmo destino.
- [ ] **CA-3:** No desktop, cada tela mostra **título/contexto de seção** coerente com o destino ativo; no mobile, o título segue o padrão de AppBar do DDR-003.
- [ ] **CA-4:** Deep-links existentes (ex.: `/contratante/turnos/{uuid}`) continuam funcionando e abrem **dentro** do shell com o destino correto ativo (não quebram bookmarks/notificações que linkam telas).
- [ ] **CA-5:** RBAC preservado: cada papel só alcança suas telas; cruzados 403 fail-secure (regressão da W28 não pode quebrar).
- [ ] **CA-6:** Cobertura ≥ 80% no código novo/alterado; E2E cobre, para cada papel, alcançar 100% dos destinos a partir do estado inicial + abrir 1 deep-link e ver o destino certo ativo.
- [ ] **CA-7:** Deploy homologação verificado; PO percorre os dois papéis e confirma que nenhuma tela ficou órfã.

## Fora de escopo

- Estados vazios/erro/loading (STORY-079) e auditoria a11y ampla (STORY-080) — embora não se deva regredir o que já existe.
- Criar telas novas. Só migrar as existentes.

## Padrões de qualidade exigidos

`docs/skills/po/references/quality-standards.md`. ≥80%; E2E integration_test; pt-BR/24h.

## Dependências

- **Bloqueada por:** STORY-077 (shell).
- **Bloqueia:** STORY-081 (validação) só fecha com tudo plugado.
- **Pré-requisitos:** homologação operante.

## Decisões já tomadas (não as reabra)

- DDR-003 (navegação), DDR-001/002, ADR-007 (RBAC), ADR-018 (UUID em rotas), IDR-020/025 (PWA + restauração de sessão — não regredir).

## Liberdade técnica do agente

Decide: como reorganizar o roteamento para aninhar telas no shell, como tratar deep-links, refatorações locais de cabeçalho.

NÃO decide: quais telas existem (inventário), destinos por papel (DDR-003), CAs.

## Definição de Pronto (DoD)

- [ ] CAs passam; testes verdes; cobertura atingida.
- [ ] Pipeline verde; deploy homolog verificado (PO confirma "nenhuma órfã").
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
