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
status: in_review
owner_agent: claude-opus-4-8
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

### Documentos lidos (2026-06-08)
- Estória inteira (CA-1..7, fora de escopo, decisões já tomadas, DoD).
- STORY-077 (shell entregue: `AppShell`/`AppShellView`/`ShellChrome`/`ShellDestination`, IDR-029, gotcha do ScaffoldMessenger aninhado nota 140 — reavaliar na migração).
- DDR-003 (§"Impacto em telas existentes": AppBar/ícones ad-hoc cedem à navegação global; **o sino migra para a barra superior do shell**; header desktop = título + sino + tema + user; compact AppBar = título + sino).
- DDR-001 (§5.6 breakpoints, §2.2 chrome por perfil), screens/README.md (inventário), `router.dart` (StatefulShellRoute), telas: feed, minhas_vagas, turnos_lista, turno_detalhe, perfil, notificacoes_sino/painel, turno_ativo_acao.

### Decisão de escopo (PO, 2026-06-08)
- **Centralizar o chrome no shell (DDR-003 pleno)** — escolhido por Alexandro via pergunta. O shell passa a ter a barra superior por breakpoint; as telas de destino perdem a AppBar; drill-downs mantêm AppBar própria (voltar + título).

### Entendimento consolidado (minhas palavras)
Mover o chrome de topo (título de seção, sino + painel, ação de turno ativo, tema no desktop) das AppBars de cada tela para uma **barra superior do shell**, mostrada só nas **raízes de destino** (Vagas/Turnos/Perfil) e oculta nos **drill-downs** (que mantêm a própria AppBar com voltar). Remover os atalhos ad-hoc que o shell substitui (ícone `event_note` "Meus turnos/Turnos" no feed e no minhas-vagas; botão voltar→home da lista de turnos). Reconciliar o caminho duplicado de "Nova vaga": no desktop o shell já a oferece (rail/sidebar) → o FAB "Publicar vaga" do minhas-vagas fica **só no compact**. Deep-links preservados (já abrem dentro do branch — STORY-077); RBAC inalterado (destinos por papel já fail-secure).

### Decisão técnica (arquitetura)
- **Barra superior dona do shell, dirigida pela rota.** O `builder` do `StatefulShellRoute` re-roda no push dentro do branch e `state.uri.path` reflete a sub-rota (provado por probe descartável). Logo: o router passa `location` ao `AppShell`; este calcula `isDestinationRoot(location)` (conjunto de rotas-raiz) e o título via `destinationsFor(role)[currentIndex].title`. Quando raiz → `AppShellView` mostra a `AppBar` do shell (título + `TurnoAtivoAcao` + `NotificacoesSino` + tema no medium+); quando drill-down → sem AppBar do shell (a tela mostra a sua).
- **Barra escopada ao conteúdo:** em todos os breakpoints a AppBar fica num `Scaffold` de conteúdo (à direita do rail/sidebar no desktop, full-width no mobile), que hospeda `endDrawer: NotificacoesPainel` — assim `Scaffold.of(context).openEndDrawer()` do sino resolve nele. Mantido o `ScaffoldMessenger(child: child)` (fix da nota 140) escopando SnackBars das telas.
- **Título de seção = `ShellDestination.title`** (já varia por papel): Vagas→"Vagas"/"Minhas vagas", Turnos→"Meus turnos"/"Turnos", Perfil→"Perfil". (Feed deixa de exibir "Vagas para você" no topo — passa a "Vagas", coerente com o destino, CA-3.)

### Plano (TDD)
1. Helpers puros em `shell_destinations.dart`: `isDestinationRoot(location)` + `sectionTitleFor(role, index)` — testes red primeiro.
2. `AppShellView` ganha `appBarTitle` (nullable) + AppBar escopada ao conteúdo (sino/turno-ativo/tema) + `endDrawer`. Testes de widget (raiz mostra/【drill-down esconde】, sino, tema medium+, ≥48dp, a11y).
3. `AppShell` calcula título/raiz a partir de `location`+`currentIndex`+role; `router.dart` passa `state.uri.path`.
4. Telas perdem chrome: feed (remove AppBar/endDrawer/meus-turnos/logout/turno-ativo), minhas_vagas (idem + FAB só compact), turnos_lista (remove AppBar/leading/sino), perfil (remove AppBar/sino). Atualiza os testes de widget dessas telas.
5. E2E `app_shell/navegacao_test.dart`: cada papel alcança 100% dos destinos do estado inicial; abre 1 deep-link e vê destino certo ativo + AppBar do shell ausente no drill-down. Verifica ad-hoc removido.
6. Suíte completa verde + lint + deploy homolog (CA-7, PO confirma "nenhuma órfã").

### Mapeamento CA → testes (planejado)
- **CA-1** (sem órfã): E2E navegação por papel alcança Vagas/Turnos/Perfil sem digitar rota.
- **CA-2** (ad-hoc removido/reconciliado): widget — ausência de `feed-meus-turnos-btn`/`minhas-vagas-turnos-btn`/leading-voltar; FAB Nova vaga só compact (sem duplicar no desktop).
- **CA-3** (título de seção): widget `app_shell_view_test` (AppBar do shell com título por papel/destino; oculta no drill-down) + `shell_destinations_test` (`sectionTitleFor`).
- **CA-4** (deep-link): E2E abre `/contratante/turnos/{uuid}`/`/vaga/{id}` e vê destino certo ativo, sem AppBar do shell (tela própria).
- **CA-5** (RBAC): `shell_destinations_test` (já cobre fail-secure) + E2E cruzado herdado.
- **CA-6** (cobertura + E2E): suíte + E2E por papel.

### Decisões tomadas
- (ver "Decisão técnica" acima)

### Descobertas
- O `builder` do `StatefulShellRoute` re-roda no push in-branch e `state.uri` traz a sub-rota completa (probe). Habilita a barra dirigida pela rota sem listener manual.
- **CAUSA RAIZ de uma maratona no gate E2E (não era o código da estória):** `app_shell/navegacao_test.dart` não chamava `IntegrationTestWidgetsFlutterBinding.ensureInitialized()`. Rodando STANDALONE (`--target=app_shell_test.dart`), o `flutter drive` cai no binding automatizado (FakeAsync) → o HTTP real do login nunca completa ("rota não mudou para /"). Só passava embutido no `web_test.dart` porque `auth_test.main()` roda antes e inicializa o binding. Todos os demais testes de integração já chamam `ensureInitialized` no seu `main()`. **Os arquivos de `integration_test/turnos/*` têm o mesmo gap latente** (rodam só via `web_test.dart`) — relevante p/ STORY-082/validador se quiserem rodá-los isolados.
- **Headless funciona (corrigido o diagnóstico):** o gate roda **headless/invisível** normalmente (`make e2e-webapp-pinned`, default `E2E_HEADLESS=1`) — provado: navegação 2/2 verdes em headless. O "Timed out receiving message from renderer" que eu via no headless era **consequência do bug do binding** (sob FakeAsync o app travava → renderer sem responder → chromedriver estourava), não um defeito do headless do Chrome 148. `E2E_HEADLESS=0` (visível) é só p/ debug.
- **Outros fixes de toolchain (Flutter 3.44 web):** (a) `enterText` na web não preenche de forma confiável (#100393) → `login_helper` usa tap+`testTextInput.enterText`+verificação; (b) o foco via `enterText` dispara "Build scheduled during frame" (ink_well/semântica) → `pump_app` fixa `FocusManager.highlightStrategy = alwaysTouch`. O **app em si carrega normal** no Chrome (login renderiza); o problema era todo de harness/binding/toolchain, comprovado por bisseção (código pré-078 falhava idêntico).
- O Chrome instalado se auto-atualiza e quebra o gate (drift). Novo alvo de Makefile `e2e-webapp-pinned` baixa Chrome-for-Testing + chromedriver de versão cravada (`CFT_VERSION`, default `148.0.7778.168`) e usa `--chrome-binary` — independente do Chrome da máquina (`make e2e-webapp-pinned`, `E2E_HEADLESS=0` abre na tela, `E2E_TARGET=`, `E2E_USE_PROXY=0`).

### Bloqueios encontrados
- Nenhum bloqueio de produto/arquitetura. A longa investigação do gate E2E foi 100% toolchain/binding (acima), resolvida.

### Cobertura final
- **Unitários/widget: 623 verdes** (suíte completa, Flutter 3.44.1). Código novo do shell: `shell_destinations.dart` 100% (incl. `isDestinationRoot`/`sectionTitleFor`), `app_shell_view.dart` ~98%, `app_shell.dart` 58% (resto = callbacks logout/nova-vaga exercitados por E2E), `perfil_screen.dart` ~91%.
- **E2E:** `app_shell/navegacao_test.dart` (CA-1/CA-2/CA-3/CA-4/CA-6) — **2/2 cenários verdes** (profissional·mobile + contratante·desktop) via `make e2e-webapp-pinned E2E_TARGET=integration_test/app_shell_test.dart E2E_HEADLESS=0`.

### Links de evidência
- Commits na `main` (workflow sem PR): série `*(STORY-078)` — helpers, barra do shell, migração das telas, E2E + fix raiz do binding, Makefile do Chrome pinado.
- Gate E2E navegação verde local (2/2). **Pendente p/ `done`:** rodar o gate completo + deploy homolog + PO confirmar "nenhuma órfã" (CA-7).
