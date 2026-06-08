---
story_id: STORY-077
slug: app-shell-adaptativo
title: "App shell adaptativo (rail/drawer desktop ↔ navegação inferior mobile) + destinos por papel"
epic_id: EPIC-012
sprint_id: SPRINT-2026-W29
type: implementation
target_role: programador
requires_design: true
design_screen_id: SCREEN-STORY-077-app-shell
status: done
owner_agent: claude-opus-4-8
created_at: 2026-06-08
updated_at: 2026-06-08
estimated_session_size: L
produces_idr: null
---

# STORY-077 — App shell adaptativo + destinos por papel

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Designer trabalha em paralelo (DDR-003 + SCREEN-STORY-077). Se algo estiver ambíguo, registre em "Notas do agente" e pause.

## Contexto (por que esta estória existe)

Esta é a estória central do EPIC-012: implementar em Flutter o **shell de navegação global** decidido pelo Designer em DDR-003 (STORY-076). É o esqueleto que todas as telas vão habitar.

- Épico: `epics/EPIC-012-shell-navegacao-e-ux/epic.md`
- Spec/protótipo: `design/screens/SCREEN-STORY-077-app-shell/` (DDR-003 + protótipo navegável — leia antes de codificar).
- Decisão de design: DDR-003 (padrão de navegação).

## O quê (objetivo desta estória)

Implementar um shell adaptativo no WebApp que apresenta **navegação inferior no mobile** e **rail/drawer lateral no desktop**, com os **destinos por papel** definidos no DDR-003, estado ativo refletindo a rota atual, e cor de chrome por perfil (DDR-001). O shell envolve as telas via roteamento; nesta estória ele pode hospedar placeholders/telas existentes mínimas — a migração completa é a STORY-078.

## Por quê (valor para o usuário)

Dá ao Contratante (desktop) um menu lateral com visão do todo e ao Profissional (mobile) uma navegação inferior persistente — a base de "ver o caminho" em vez de "saber a rota".

## Critérios de aceite

- [ ] **CA-1:** Existe um widget de shell que, conforme o breakpoint (DDR-001 §5.6), renderiza navegação inferior (mobile ≥360px) ou rail/drawer lateral (desktop, alinhado a `bp.large` 1200) — exatamente como o DDR-003 especifica.
- [ ] **CA-2:** O shell mostra os **destinos do papel autenticado** (Profissional × Contratante) conforme DDR-003; RBAC garante que nenhum destino do outro papel aparece (ADR-007), com fail-secure.
- [ ] **CA-3:** O **estado ativo** do item de navegação reflete a rota atual; navegar por um destino troca a tela e atualiza o ativo; o roteamento mantém o shell persistente (não recria a cada navegação).
- [ ] **CA-4:** Cor de **chrome** do shell segue o perfil (mostarda contratante / verde-sage profissional) nos dois temas (DDR-001).
- [ ] **CA-5:** Responsividade verificada nos breakpoints: o shell colapsa/expande sem "mobile esticado" nem "desktop encolhido"; alvos de toque ≥48dp.
- [ ] **CA-6:** Acessibilidade: navegação por teclado (tab order + foco visível) e label acessível nos ícones de navegação.
- [ ] **CA-7:** Cobertura ≥ 80% no código novo; **E2E** (integration_test, Chrome headless — IDR-010/011) cobre navegação por papel em mobile e desktop (pelo menos: entrar como cada papel, ver destinos corretos, navegar entre 2 destinos, ativo correto).
- [ ] **CA-8:** Deploy em homologação verificado; o shell é visível para os dois papéis.

## Fora de escopo

- Migrar todas as telas existentes para dentro do shell e ajustar seus cabeçalhos — é a STORY-078 (esta entrega o shell + roteamento + no mínimo as telas iniciais de cada papel plugadas).
- Estados vazios/erro/loading — STORY-079.
- Auditoria a11y ampla das telas internas — STORY-080 (esta cobre a11y do próprio shell).

## Padrões de qualidade exigidos

Segue `docs/skills/po/references/quality-standards.md`. ≥80% no código novo; E2E em `integration_test`; locale pt-BR + 24h (DDR-002); AA no shell.

## Dependências

- **Bloqueada por:** STORY-076 (DDR-003 + protótipo aprovado).
- **Bloqueia:** STORY-078 (migração depende do shell existir).
- **Pré-requisitos:** homologação operante; SCREEN-STORY-077 `ready`.

## Decisões já tomadas (não as reabra)

- DDR-003 (padrão de navegação — esta estória implementa), DDR-001/DDR-002.
- ADR-001 (Flutter), ADR-007 (RBAC por papel), ADR-018 (UUID — rotas com `{uuid}` como String).
- IDR-010/011 (modelo E2E integration_test), IDR-020/025 (PWA instalável + restauração de sessão — não regredir).

## Liberdade técnica do agente

Decide: estrutura do código do shell, escolha entre `NavigationSuiteScaffold`/`AdaptiveScaffold`/composição manual **dentro** do que DDR-003 especifica, integração com a solução de roteamento já em uso no WebApp, design dos testes.

NÃO decide: o padrão de navegação (DDR-003), os destinos por papel, critérios de aceite.

**Gatilho de quebra (L):** se o shell + roteamento + plugar as telas iniciais não couber em uma sessão, separe em (a) shell + roteamento + navegação por papel e (b) integração das telas iniciais — escale ao PO **antes** de inflar a sessão (padrão W28).

Se faltar ADR de roteamento, **pare e registre** — escale para Arquiteto.

## Definição de Pronto (DoD)

- [ ] CAs passam; testes unitários + E2E verdes; cobertura atingida.
- [ ] Pipeline CI verde; deploy homologação verificado (PO confirma visualmente nos 2 papéis e 2 tamanhos).
- [ ] IDR registrado se houve decisão de baixo nível com impacto futuro (ex.: padrão de roteamento aninhado).
- [ ] `index.json` atualizado: status = `done`. "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Designer revisa o PR contra o spec em browser real (mobile + desktop).

## Notas do agente (preenchido durante/após execução)

### Documentos lidos (2026-06-08)
- Estória inteira (CA-1..8, fora de escopo, decisões já tomadas, DoD, gatilho de quebra L).
- DDR-003 (shell adaptativo bar→rail→drawer pintado por perfil; inventário de destinos; widget por breakpoint; keys lógicas sugeridas; notas ao Programador → `StatefulShellRoute.indexedStack`).
- epic.md EPIC-012; DDR-001 §2.2 (chrome por perfil) e §5.6 (breakpoints); protótipo `design/screens/SCREEN-STORY-077-app-shell/index.html` (fonte de verdade visual).
- Código atual: `router.dart` (rotas planas + funnel guard), `main.dart` (MaterialApp.router, dual-theme só profissional), `ds/tokens.dart` + `ds/theme.dart`, `features/app/app_shell_screen.dart` (placeholder), `auth_service.dart` (sessão/role singleton), `notificacoes_sino.dart`, harness `integration_test/` (same-origin, IDR-021).

### Entendimento consolidado (minhas palavras)
Entregar um shell de navegação global adaptativo no WebApp Flutter: `NavigationBar` (compact 0–599) → `NavigationRail` (medium 600–839 / expanded 840–1199) → `NavigationDrawer` (large ≥1200), pintado pelo **chrome do perfil** (prof `#1B2E1F` / contr `#3D2A0E`) nos dois temas, com 3 destinos por papel (Vagas/Turnos/Perfil), estado ativo refletindo a rota, sino+tema como ações utilitárias e "Nova vaga" como ação (FAB/rail/drawer) só do contratante. Roteamento via `StatefulShellRoute.indexedStack` (1 branch por destino), preservando estado por aba; drill-downs empilham dentro do branch. Telas reais já existentes plugadas (feed/minhas vagas/turnos); Perfil é tela nova mínima (identidade+tema+Sair). Limpeza de AppBar/chrome das telas internas é STORY-078.

### Decisão de escopo (PO, 2026-06-08)
- Aprovado fazer a **estória inteira numa sessão, com as telas reais plugadas** (não placeholders). Telas existentes mantêm suas AppBars atuais; a limpeza de cabeçalho é STORY-078. Gatilho de quebra L não acionado.

### Plano (3–5 bullets)
1. Tokens de chrome por perfil em `tokens.dart` (DDR-001 §2.2) + breakpoints/destinos.
2. Widget `AppShell` adaptativo (`NavigationSuiteScaffold`) + `PerfilScreen` mínima.
3. Reescrever `router.dart` com `StatefulShellRoute.indexedStack` (branches Vagas/Turnos/Perfil), preservando funnel guard, deep-links e rotas públicas.
4. Chrome por perfil (shell lê papel da sessão) nos dois temas + toggle de tema.
5. Testes de widget (4 categorias) + E2E (2 papéis × 2 tamanhos) + suíte verde + lint + deploy homolog.

### Mapeamento CA → testes (planejado, TDD)
- **CA-1** (forma por breakpoint): widget test `app_shell_test.dart` — compact→NavigationBar, medium/expanded→NavigationRail, large→NavigationDrawer (variando MediaQuery).
- **CA-2** (destinos por papel + RBAC fail-secure): `destinos_test.dart` — prof vê Vagas/Turnos/Perfil; contr idem com títulos próprios; papel desconhecido → lista vazia; nenhum destino do outro papel.
- **CA-3** (ativo reflete rota + shell persistente): E2E navegar entre destinos e checar `aria-current`/indicador; widget test do índice ativo por rota.
- **CA-4** (chrome por perfil nos 2 temas): widget test cor do chrome = chrome do papel em light e dark.
- **CA-5** (responsividade + toque ≥48dp): widget test alvos ≥48dp; sem overflow nos breakpoints.
- **CA-6** (a11y: teclado + label): widget test Semantics/label nos destinos e no sino; foco.
- **CA-7** (E2E por papel mobile+desktop): `integration_test/app_shell/navegacao_test.dart`.
- **CA-8** (deploy homolog): verificação manual pós-merge.

### Dúvidas
- Nenhuma bloqueante. DDR-003 fixa padrão, destinos e keys. Se a config do `StatefulShellRoute` exigir decisão de baixo nível não óbvia, registro IDR (previsto no DDR-003 §notas).

### Decisões tomadas (locais)
- **Roteamento:** `StatefulShellRoute.indexedStack` com 3 branches; rota canônica `/turnos` role-dispatch como `initialLocation` do branch Turnos (paths por papel preservados in-branch). Registrado em **IDR-029**.
- **Widget adaptativo:** composição manual (`NavigationBar` + `NavigationRail` nativos + sidebar custom) em vez de `NavigationSuiteScaffold` — as 3 formas têm chrome materialmente diferente (marca/usuário/ação/Sair). IDR-029.
- **Escopo do shell nesta estória:** só a superfície de navegação; telas internas mantêm `AppBar`/sino (migração = STORY-078). Evita `AppBar` dupla.
- **FAB "Nova vaga" mobile adiado p/ STORY-078** — `MinhasVagasScreen` já tem FAB próprio; dois se sobreporiam. Ação "Nova vaga" entra já no rail/sidebar (sem conflito).
- **CA-4 = chrome do shell por perfil** (não reescrita do ThemeData global): `ShellChrome.forRole` pinta a superfície de navegação; conteúdo segue o tema profissional vigente. Coerente com os CAs.
- **Tema reativo:** `ThemeModeController` (singleton persistido) alimenta `MaterialApp.themeMode`; alternância no Perfil (DDR-003). `main.dart` faz `load()` no boot.
- **Camadas testáveis:** `AppShellView` (apresentacional, sem router) + `AppShell` (glue com `StatefulNavigationShell`).

### Descobertas
- O `IndexedStack` do `StatefulShellRoute` carrega branches sob demanda (lazy) por padrão — só o branch ativo monta; isso mantém o E2E determinístico (telas com rede só montam quando visitadas).
- `MinhasVagasScreen` já possui FAB (conflito com FAB global → ver decisão acima).
- `patterns.md` já recebeu o padrão de navegação na STORY-076 (Designer) — não tocado aqui.
- **GOTCHA da Scaffold aninhada → SnackBar (regressão achada no gate E2E):** como o shell envolve cada tela numa `Scaffold` (para a barra/rail) e as telas internas TAMBÉM são `Scaffold`, um `ScaffoldMessenger.of(context).showSnackBar` da tela interna subia para o mensageiro RAIZ e renderizava no **rodapé da janela**, cobrindo a `bottomNavigationBar` de ação da tela (o botão "Retirar" do detalhe da vaga virava intocável). Quebrava a suíte E2E `candidatura` (que passava no pré-shell). **Fix:** o shell envolve o conteúdo num `ScaffoldMessenger` próprio (`AppShellView` → `ScaffoldMessenger(child: child)`), escopando os SnackBars das telas internas. Diagnóstico provado por bisseção em worktree no commit pré-shell + instrumentação do tap (SnackBar visível sobre a ação no momento do toque). **Para a STORY-078:** ao migrar as telas para fora da Scaffold própria (usar o header/ação do shell), reavaliar se este mensageiro ainda é necessário.

### Bloqueios encontrados
- Nenhum.

### IDRs criados
- **IDR-029** — Shell com `StatefulShellRoute.indexedStack` + composição adaptativa manual.

### Mapeamento CA → teste (final)
- **CA-1** (forma por breakpoint): `test/features/app/shell/app_shell_view_test.dart` — compact→`NavigationBar`, 600/700→rail recolhida, 1000→rail estendida, 1199/1200 borda, 1300→sidebar.
- **CA-2** (destinos por papel + RBAC): `shell_destinations_test.dart` (prof/contr/desconhecido/nulo, sem vazamento, Nova vaga só contratante) + `app_shell_view_test.dart` (destinos na bottom bar; fail-secure sem crash) + E2E (Nova vaga presente p/ contratante, ausente p/ profissional).
- **CA-3** (ativo reflete rota + shell persistente): `app_shell_view_test.dart` (selectedIndex + callback) + E2E `app_shell/navegacao_test.dart` (goBranch, ativo após navegar, shell persiste).
- **CA-4** (chrome por perfil nos 2 temas): `shell_chrome_test.dart` (invariante ao tema, fail-secure) + `app_shell_view_test.dart` (bottom bar prof/contr — inclusive escuro; sidebar contratante).
- **CA-5** (toque ≥48dp): `app_shell_view_test.dart` (altura da NavigationBar ≥48; itens da sidebar `minHeight: 48`).
- **CA-6** (a11y label + teclado): `app_shell_view_test.dart` (Semantics/label nos destinos da sidebar, Sair presente) + ícones nativos da bar/rail com label.
- **CA-7** (E2E por papel mobile+desktop): `integration_test/app_shell/navegacao_test.dart` (2 cenários).
- Perfil/tema: `test/features/app/perfil_screen_test.dart` + `test/core/theme_mode_controller_test.dart`.

### Cobertura final (código novo)
- `shell_chrome.dart` 100% · `shell_destinations.dart` 100% · `theme_mode_controller.dart` 100%
- `app_shell_view.dart` ~87% (≥80) · `perfil_screen.dart` ~92%
- `app_shell.dart` (glue do `StatefulNavigationShell`) — exercitado pelo E2E (router real), não por widget test.
- Suíte completa de widget/unit: **641 testes verdes**.

### E2E (integration_test, Chrome headless same-origin — IDR-021)
- **`app_shell/navegacao_test.dart` (CA-7): PASSA** em todos os runs do gate — profissional·mobile (bottom bar, Vagas↔Perfil↔Vagas, ativo correto) e contratante·desktop (sidebar, Nova vaga, Vagas→Perfil→Turnos).
- **Regressão achada e corrigida no gate:** a suíte `candidatura` (alheia, passava no pré-shell) quebrou só com o shell — SnackBar da tela interna cobrindo o botão "Retirar" (Scaffold aninhada). Provado por bisseção em worktree no commit pré-shell `c3c9b9d` + instrumentação do tap. Fix: `ScaffoldMessenger` próprio do conteúdo no `AppShellView` + teste de regressão de widget. Após o fix, candidatura volta a passar no gate.
- **Flake pré-existente (NÃO regressão do shell):** a suíte `turnos/checkout` (`ciclo completo… cronômetro… Pix`) falha/pendura de forma errática. **Provado pré-existente:** rodada isolada em banco limpo, ela **pendura ~8–9 min sem resultado tanto no meu código quanto no commit pré-shell `c3c9b9d`** (comportamento idêntico). É a dívida de deflake do domínio cronômetro/Pix — pertence à **STORY-082**, não a esta estória. Registrado para o PO.

### Links de evidência
- Commits na `main` (workflow do projeto, sem PR): série `*(STORY-077)` — tokens/ShellChrome/ShellDestination, AppShellView, PerfilScreen+ThemeModeController, roteamento StatefulShellRoute, E2E+IDR-029, e o fix do SnackBar (`fix(STORY-077): escopa SnackBar do conteúdo…`).
- Deploy homolog (CA-8): **`v0.1.0-rc.88`** no ar em `app.homolog.turni.com.br` (release.yml run 27160690444, todos os jobs verdes incl. "Migrar + seed (homolog)" e smoke pós-deploy). `/health` confirma a versão. **PO aprovou visualmente em 2026-06-08** (2 papéis × 2 tamanhos) → estória `done`.
