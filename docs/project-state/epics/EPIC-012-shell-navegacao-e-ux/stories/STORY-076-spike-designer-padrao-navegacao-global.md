---
story_id: STORY-076
slug: spike-designer-padrao-navegacao-global
title: "Spike Designer — padrão de navegação global do WebApp (DDR-003) + protótipo navegável"
epic_id: EPIC-012
sprint_id: SPRINT-2026-W29
type: spike
target_role: designer
requires_design: true
design_screen_id: SCREEN-STORY-077-app-shell
status: done
owner_agent: claude-opus-4-8
created_at: 2026-06-08
updated_at: 2026-06-08
estimated_session_size: M
produces_ddr: DDR-003
---

# STORY-076 — Spike Designer: padrão de navegação global do WebApp (DDR-003)

> **Para o agente que vai executar:** carregue a skill `designer`. Leia esta estória por inteiro antes de começar. Se algo estiver ambíguo, registre em "Notas do agente" e pause em vez de adivinhar.

## Contexto (por que esta estória existe)

O WebApp foi construído tela a tela, sem shell de navegação global (ver nota da STORY-059 e `patterns.md`). Antes de implementar o shell, o **padrão de navegação** precisa ser uma decisão de design durável e registrada — ele afeta toda a aplicação e é caro de reverter. A própria skill do Designer cita este caso como exemplo canônico de DDR.

- Épico: `epics/EPIC-012-shell-navegacao-e-ux/epic.md`
- PDR: `decisions/pdr/PDR-018-sprint-ux-ui-shell-de-navegacao-antes-do-epic-004.md`
- Documentos a ler ANTES: `design/system/tokens.md` (§5.6 breakpoints; esquema de cor por perfil/chrome), `design/system/patterns.md`, `design/system/README.md`, DDR-001, DDR-002, `docs/prototipo/app.html` (sidebar pintada por perfil), `docs/especificacao/screens/README.md` (inventário de telas por papel), ADR-007 (RBAC por papel).

## O quê (objetivo desta estória)

Decidir e registrar em **DDR-003** o padrão de navegação global do WebApp — qual widget de navegação por breakpoint, quais **destinos por papel** (Profissional × Contratante), como o shell colapsa entre mobile/tablet/desktop, estado ativo, cor de chrome por perfil — e entregar um **protótipo HTML navegável** (`design/screens/SCREEN-STORY-077-app-shell/index.html`) que demonstre o shell nos dois tamanhos e nos dois papéis.

## Por quê (valor para o usuário)

Sem um padrão de navegação coerente, Contratante (desktop) e Profissional (mobile) navegam "sabendo a rota" em vez de "vendo o caminho". O DDR fixa a estrutura que todas as telas — atuais e futuras (EPIC-004 em diante) — herdam, evitando que cada nova tela reinvente a navegação.

## Critérios de aceite

- [x] **CA-1:** DDR-003 criado em `decisions/ddr/DDR-003-shell-de-navegacao-global.md` no formato dos DDRs vigentes, com widget por breakpoint ancorado no DDR-001 §5.6, opções consideradas e justificativa; `accepted` após aprovação humana (2026-06-08, Alexandro).
- [x] **CA-2:** Inventário de destinos por papel definido (Profissional = Vagas/Turnos/Perfil; Contratante = Vagas/Turnos/Perfil), derivado das telas entregues, sem inventar tela. Notificações = sino; "Nova vaga" = ação.
- [x] **CA-3:** Comportamento responsivo definido: `NavigationBar` (mobile) → `NavigationRail` (medium/expanded) → `NavigationDrawer` (≥1200), ambos os papéis nos dois extremos.
- [x] **CA-4:** Estado ativo (indicador `accent.soft` + acento de tema escuro), chrome por perfil nos dois temas (DDR-001) e alvos ≥48dp definidos.
- [x] **CA-5:** Protótipo HTML navegável entregue em `design/screens/SCREEN-STORY-077-app-shell/index.html` — viewports mobile/tablet/desktop selecionáveis, dois papéis, destinos clicáveis, vanilla sem build.
- [x] **CA-6:** Protótipo apresentado ao humano (aberto no navegador local — `mcp__cowork__present_files` indisponível no Claude Code CLI) e "vai" capturado em 2026-06-08 **antes** da STORY-077.
- [x] **CA-7:** `patterns.md` recebeu `pattern.navigation` (referência ao DDR-003 + sketch), substituindo o ponteiro nomeado.

## Fora de escopo

- Implementar o shell em Flutter (é a STORY-077).
- Redesenhar telas individuais (é STORY-078/079/080).
- Backoffice admin (fora do épico).
- Nova paleta / fundação visual nova (DDR-001 é mantido).

## Padrões de qualidade exigidos

Segue `docs/skills/po/references/quality-standards.md` no que se aplica a spike de design. Spike **não** entrega código de produção, mas entrega DDR + protótipo HTML navegável como artefatos verificáveis. Acessibilidade AA é critério de design desde o protótipo (contraste do chrome por perfil nos dois temas já validado em DDR-001 — reuse).

## Dependências

- **Bloqueada por:** nenhuma.
- **Bloqueia:** STORY-077, STORY-078 (a implementação do shell depende deste DDR).
- **Pré-requisitos:** nenhum além do ambiente de design.

## Decisões já tomadas (não as reabra)

- ADR-001 (Flutter — mesmo codebase web/mobile) → `decisions/adr/ADR-001-stack-principal.md`.
- ADR-007 (RBAC por papel profissional/contratante/admin) → o shell mostra só os destinos do papel autenticado.
- DDR-001 (fundação do DS, breakpoints, chrome por perfil) e DDR-002 (pt-BR, 24h).
- PDR-003 (duas interfaces; Contratante desktop-first, mas WebApp responsivo) e PDR-018 (este épico, navegação como DDR).

## Liberdade técnica do agente (Designer)

Você decide: o widget de navegação (NavigationBar/NavigationRail/NavigationDrawer/NavigationSuiteScaffold), a lista final de destinos por papel dentro do inventário existente, o comportamento exato em cada breakpoint, microcopy dos rótulos de navegação.

Você NÃO decide: stack/roteamento de baixo nível (Arquiteto/Programador), critérios de aceite (PO), criar telas/funcionalidades novas (PO).

Se perceber que o shell exige decisão de **roteamento arquitetural** não coberta por ADR vigente, **pare e registre** em "Notas do agente" — escale para spike de Arquiteto.

## Definição de Pronto (DoD)

- [x] DDR-003 escrito; `status: accepted` após aprovação do humano (2026-06-08).
- [x] Protótipo HTML navegável entregue e aprovado pelo humano antes de a STORY-077 começar.
- [x] `patterns.md` atualizado (`pattern.navigation`).
- [x] `index.json` atualizado (entrada em `decisions.ddr[]` e `design.screens[]` conforme schema vigente — sem alterar o schema).
- [x] "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md` e o fluxo de colaboração Designer↔Programador da skill `designer`. Apresente o protótipo via `mcp__cowork__present_files` antes de marcar `ready` o spec.

## Notas do agente (preenchido durante/após execução)

### Decisões tomadas
- **Padrão:** shell adaptativo único (`NavigationSuiteScaffold`) — `NavigationBar` (mobile, 0–599) → `NavigationRail` (tablet, 600–1199) → `NavigationDrawer` (desktop, ≥1200), ancorado nos breakpoints do DDR-001 §5.6.
- **Chrome por perfil em todos os breakpoints** (DDR-001 §2.2): Profissional `#1B2E1F`, Contratante `#3D2A0E` — a sidebar/bar/rail escura pintada por papel é a assinatura do produto, válida nos dois temas.
- **Destinos (3 por papel), derivados das telas entregues, sem inventar tela:** Profissional = Vagas · Turnos · Perfil; Contratante = Vagas · Turnos · Perfil.
- **Notificações = sino** (ação utilitária na barra superior, com badge), **não** destino — espelha o `notificacoes_sino` já entregue e é padrão M3 correto.
- **"Nova vaga" = FAB/ação** do Contratante, **não** destino (espelha o `.fab-vaga` do protótipo).
- **Estado ativo:** indicador `accent.soft` + rótulo no acento de tema escuro do perfil (`#5FA37C` / `#D4A95C`); foco visível; alvos ≥48dp; todo destino com rótulo textual.

### Descobertas
- **O WebApp entregou apenas ~2 destinos de trabalho reais por papel hoje** (Profissional: feed + turnos; Contratante: minhas vagas + turnos). O `screens/README.md` lista um inventário maior (Dashboard, Candidaturas, Financeiro, Empresa, Escala, Equipe, Atendimento, Feedbacks) **ainda não construído** — fora de escopo do épico. O shell foi desenhado para **crescer** acrescentando item à lista, sem redesenho.
- **"Perfil" é a única superfície nova** introduzida pelo padrão — minimizada a **consolidar chrome que já existe** (identidade do usuário, alternância de tema, Sair). Não é feature nova. **Sinalizado ao PO no "vai"** (decisão de produto sobre enriquecer o Perfil fica para EPIC-004+).
- Verificado no `apps/webapp/lib/router.dart`: rotas reais hoje = `/feed`, `/vaga/:id`, `/profissional/turnos`, `/contratante/vagas`, `/contratante/vagas/nova`, `/contratante/vagas/:id/{editar,candidatos}`, `/{profissional,contratante}/turnos`, `/turnos/:id`. Drill-downs (detalhe/candidatos/editar) **não** viram destino — empilham no destino ativo.

### Bloqueios encontrados
- Nenhum bloqueio de **decisão arquitetural** (PDR-018 §Sinais de revisão): o shell usa `NavigationSuiteScaffold` + `StatefulShellRoute` do go_router, que já é a stack vigente (ADR-001). **Não exige spike de Arquiteto.** Flag deixada ao Programador na STORY-077: registrar **IDR** se a configuração do `StatefulShellRoute.indexedStack` (preservar estado por aba + drill-down dentro do branch) trouxer decisão de baixo nível não óbvia.
- A skill prevê apresentar via `mcp__cowork__present_files`; o ambiente atual (Claude Code CLI) não tem esse MCP. Protótipo apresentado abrindo no navegador local; "vai" capturado na sessão.

### DDR criado
- DDR-003 — Shell de navegação global do WebApp — `decisions/ddr/DDR-003-shell-de-navegacao-global.md` (`status: proposed`, aguardando aprovação humana para `accepted`).

### Links de evidência
- Protótipo: `design/screens/SCREEN-STORY-077-app-shell/index.html`
- DDR: `decisions/ddr/DDR-003-shell-de-navegacao-global.md`
- Padrão no DS: `design/system/patterns.md` (`pattern.navigation`)
