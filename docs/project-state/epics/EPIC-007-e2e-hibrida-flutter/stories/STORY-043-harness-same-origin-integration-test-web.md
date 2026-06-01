---
story_id: STORY-043
slug: harness-same-origin-integration-test-web
title: Harness same-origin para integration_test no Web — cobrir a área logada e migrar os fluxos flaky restantes
epic_id: EPIC-007
sprint_id: SPRINT-2026-W26
type: enablement
target_role: programador
requires_design: false
status: in_review
owner_agent: claude-opus-4-8-programador-2026-06-01
created_at: 2026-06-01
updated_at: 2026-06-01
estimated_session_size: L
produces_idr: IDR-021 (ou extensão da IDR-010 — agente decide)
---

# STORY-043 — Harness same-origin para integration_test no Web (área logada)

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. O caminho técnico já foi **provado por spike** (2026-06-01) — a receita está em "Notas do agente" abaixo. Sua tarefa é **produtizar** essa receita no Makefile e **migrar** os fluxos flaky restantes para `integration_test`. Se algo divergir do spike, registre em "Notas do agente" e pause em vez de adivinhar.

## Contexto (por que esta estória existe)

A STORY-038 migrou os 7 cenários de login/RBAC/funnel para `integration_test` e tornou o gate determinístico. Mas ela cobriu **só** fluxos cujo desfecho vem da **resposta do login** (CA-6/7/8) — porque sob `flutter drive` o app é servido numa porta efêmera do dev-server do Flutter, **origem diferente da API**, e o cookie de sessão Sanctum **não trafega cross-origin**. Por isso os specs de UI que fazem **chamadas autenticadas pós-login** (welcome → `POST /api/usuarios/me/welcome-visto`) e os de **pré-cadastro** (que montam telas com fetch/foto) **ficaram em Playwright**, num target **não-gating** (`make e2e-webapp-playwright-legacy`), ainda **flaky** (truque de semantics da IDR-006 §b).

Para matar o flake na raiz (objetivo do EPIC-007) e preparar a STORY-022+ — que terá muitos fluxos na **área logada** — `integration_test` precisa rodar **same-origin** com a API sob `flutter drive`, de modo que o cookie autenticado funcione exatamente como em produção (que já é same-origin — IDR-014).

**Isto já foi provado.** O spike de 2026-06-01 (registrado nas Notas) demonstrou o **Caminho 1 (reverse-proxy + `--web-launch-url`)**: o fluxo autenticado de welcome passou same-origin (exit 0, e persistiu `welcome_visto=true` no backend), enquanto a mesma execução cross-origin falhou exatamente no passo autenticado. **Sem mudar código de produção, sem CORS, sem `withCredentials`, sem mock.** Esta estória transforma esse spike em harness de gate e migra os fluxos.

- Épico: `epics/EPIC-007-e2e-hibrida-flutter/epic.md`
- Documentos canônicos a ler ANTES de codificar:
  - **STORY-038** (`stories/STORY-038-adotar-integration-test-no-webapp.md`) — em especial as "Notas do agente": helpers, agregador no Web, correção de sintaxe da IDR-010, e o spike do Caminho 1 (receita).
  - `docs/project-state/decisions/idr/IDR-010-...md` (modelo híbrido + correção de comando) e `IDR-011-...md` (padrão de teste Flutter).
  - `IDR-006-...md` §a (path strategy) e `IDR-014-...md` (dev same-origin proxy + endpoint /me) — o harness **espelha** o same-origin de produção.
  - `IDR-009-...md` (image_picker: Web → Playwright, nativo → Patrol).
  - `apps/webapp/integration_test/` (scaffolding da STORY-038), `apps/webapp/tests/e2e/{welcome,pre-cadastro,pre-cadastro-contratante,app-update}.spec.ts` (os specs a migrar/decidir).
  - `apps/webapp/router.php` (proxy same-origin de dev de referência) e `Makefile` targets `e2e-webapp*`.
  - `apps/api/config/sanctum.php` (`stateful` domains).

## O quê (objetivo desta estória)

Produtizar o harness same-origin no `make e2e-webapp-integration` (proxy reverso + `--web-launch-url`) e **migrar para `integration_test` os fluxos de UI hoje flaky em Playwright** — welcome (área logada) e as validações de pré-cadastro — removendo-os do target legado e deixando `tests/e2e/` reduzido ao smoke HTTP.

## Por quê (valor para o time)

Fecha o flake na raiz (métrica primária do EPIC-007: 0 flake) **também para a área logada**, e entrega o padrão que a STORY-022+ (cadastro completo, agenda, perfil — todos autenticados) vai herdar. Sem o harness, cada story autenticada futura cairia de novo no Playwright/semantics flaky ou inventaria seu próprio contorno.

## Critérios de aceite

### Harness same-origin

- [x] **CA-1:** `make e2e-webapp-integration` monta o harness same-origin: sobe chromedriver + um **proxy reverso** (script versionado no repo, sem dependências externas pesadas) + o dev-server do `flutter drive`, e usa **`--web-launch-url`** para o browser abrir o **proxy**. O `--dart-define=API_BASE_URL` cross-origin da STORY-038 é **removido** (passa a same-origin). Sobe e **derruba** tudo de forma limpa (trap), idempotente, sai !=0 no 1º fail.
- [x] **CA-2:** O proxy roteia `/api` e `/sanctum` → API real e o restante → dev-server do Flutter, numa **origem única**. A origem é **stateful no Sanctum** sem mudar produção: usar uma porta já presente em `SANCTUM_STATEFUL_DOMAINS` (o spike usou `localhost:3000`) **ou** adicioná-la ao env de **dev** (documentado). **Sem CORS, sem `withCredentials`, sem mock, sem alterar `AuthService`/config de produção.**
- [x] **CA-3:** Existe um teste que prova a montagem: um cenário `integration_test` **autenticado** passa via o harness (welcome — CA-4) e **falharia** cross-origin (registrar o contraste em Notas/IDR como evidência, como no spike).

### Migração dos fluxos flaky

- [x] **CA-4:** Fluxo de **welcome** migrado para `integration_test/auth/welcome_test.dart`: login do profissional **liberado** → `/welcome` → "Vamos lá" (`POST /api/usuarios/me/welcome-visto` **autenticado**) → `/completar-cadastro`; **e** o cenário "2º login pula o welcome" (welcome já visto → cai direto em `/completar-cadastro`). Passa via harness. `tests/e2e/welcome.spec.ts` **removido**.
- [x] **CA-5:** Isolamento de dados garantido: fluxos que **mutam estado** (welcome_visto) re-semeiam por run **ou** usam usuário descartável, de modo que as 5 execuções consecutivas do gate sejam determinísticas (sem "2º run pega usuário já welcomado" — gotcha registrado no spike).
- [x] **CA-6:** **pré-cadastro** (profissional PF/MEI + contratante): cenários de **validação/texto/navegação** migrados para `integration_test` (determinísticos, sem semantics). O **happy-path com upload de foto** **permanece desativado** (`test.fixme`) — file picker é Patrol/IDR-009 (STORY-039), **fora de escopo** migrar aqui. `tests/e2e/pre-cadastro.spec.ts` e `pre-cadastro-contratante.spec.ts` removidos **se** não sobrar nenhum cenário ativo neles; senão, reduzidos ao que ficar (documentar).
- [x] **CA-7:** Decisão sobre **`app-update.spec.ts`** registrada e aplicada: por ser comportamento **web-platform** (service worker, polling de `/version.json`, `page.route` mock, `skipWaiting`+reload), **permanece em Playwright como smoke** (não migra para `integration_test`). Mover para a suíte de smoke do gate **ou** mantê-lo num target próprio — agente decide e documenta; o que **não** pode é continuar flaky no caminho do gate.

### Gate e limpeza

- [x] **CA-8:** `tests/e2e/` reduzido ao **smoke HTTP** (`webapp-hello-world.spec.ts` + o que a decisão de CA-7 mantiver). `make e2e-webapp-playwright-legacy` **removido** (ou reduzido ao resíduo de smoke, sem specs flaky de interação).
- [x] **CA-9:** `make e2e-webapp` (build → integration **incluindo os fluxos autenticados migrados** → smoke) roda **5x consecutivos verde, 0 flake**. Wall-time documentado e comparado ao baseline da STORY-038 (~49s); se subir, justificar.

### Decisão e documentação

- [x] **CA-10:** Harness registrado em **IDR** (`status: proposed`): extensão da IDR-010 **ou** IDR nova (ex.: IDR-021 — "Harness same-origin para integration_test Web"). Documenta a receita (proxy + `--web-launch-url` + origem stateful), **por que same-origin** (espelha produção/IDR-014, evita tocar produção), e o contraste cross-origin (evidência do spike).
- [x] **CA-11:** `apps/webapp/README.md` §"Testes E2E" atualizado: o harness same-origin substitui o caveat do `--dart-define` cross-origin; como rodar/debugar 1 cenário autenticado.

## Fora de escopo

- **image_picker / upload de foto** — file picker do browser é Playwright/Patrol (IDR-009); cobertura nativa fica para STORY-039 (Patrol). O happy-path de cadastro com foto continua `test.fixme`.
- **Gate mobile (Android/iOS)** — STORY-040. (No nativo não há restrição same-origin do browser, mas depende da auth nativa do app — fora daqui.)
- **Suíte em CI** — gate continua local (IDR-004).
- **Backoffice** — continua em Playwright (server-rendered).
- **Mudar `AuthService`/CORS/`withCredentials` de produção** — o harness **evita** isso de propósito (same-origin como produção).
- **Resolver o débito de cobertura pré-existente (74% < 80%)** — sinalizado na STORY-038; é ação separada do PO, não desta story.

## Padrões de qualidade exigidos

Segue `docs/skills/po/references/quality-standards.md` e **IDR-011** (Keys, helpers, API real, naming, determinismo). E2E em browser real continua obrigatório (§1.2) — `integration_test -d chrome` headless atende. Sem regressão de cobertura unitária. Determinismo: sem `Future.delayed`; usar `pumpAndSettle`/`pumpUntilFound`/`awaitRouteChange` (helpers da STORY-038).

## Dependências

- **Bloqueada por:** STORY-038 (scaffolding `integration_test`, helpers, agregador no Web, gate). STORY-038 está `in_review`.
- **Bloqueia:** indiretamente a qualidade de teste da STORY-022+ (área logada nasce neste padrão). Não bloqueia STORY-039/040 formalmente.
- **Pré-requisitos de ambiente:** docker-compose no ar (`make up`) + seed (`make _e2e-seed`); chromedriver com MAJOR == Chrome local (ver README da STORY-038); `node` no host (proxy).

## Decisões já tomadas (não as reabra)

- **IDR-014** — dev é same-origin (proxy `/api`+`/sanctum`); o harness **espelha** isso. Não introduzir CORS/credenciais em produção.
- **IDR-010/011** — modelo híbrido + padrão de teste; correção de sintaxe (comando Web é `flutter drive`, não `flutter test`).
- **IDR-009** — image_picker no Web é Playwright; nativo é Patrol. Não mockar o file picker.
- **Spike 2026-06-01** — Caminho 1 (proxy + `--web-launch-url`) é o caminho; Caminho 2 (`withCredentials`+CORS+Sanctum) é fallback só se o Caminho 1 travar.

## Liberdade técnica do agente

Você decide: linguagem/forma do proxy (node puro do spike, ou caddy/nginx se preferir — desde que versionado e sem dívida), porta/origem stateful (desde que sem tocar produção), organização dos testes migrados (pasta `auth/` vs `funnel/`), se o harness vira um script `scripts/` chamado pelo Makefile ou recipe inline, e se o IDR é extensão da 010 ou novo. **Não** decide: tocar produção (`AuthService`/CORS), mockar API/file picker, mudar política de gate (IDR-004), migrar o file picker.

Se o Caminho 1 falhar de forma irrecuperável, **pare e escale ao PO** antes de partir para o Caminho 2 (toca produção/IDR-014).

## Definição de Pronto (DoD)

- [x] CA-1 a CA-11 atendidos.
- [x] `make e2e-webapp` verde 5x consecutivos (incl. fluxos autenticados); evidência em Notas.
- [x] Cobertura unitária não regredida.
- [x] IDR do harness em `proposed` aguardando PO; README atualizado.
- [x] `tests/e2e/` reduzido ao smoke; `e2e-webapp-playwright-legacy` removido/reduzido.
- [x] `index.json` atualizado; "Notas do agente" preenchidas (CA→teste, wall-time, contraste cross-origin).

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Ao iniciar: `status: in_progress`, `owner_agent`, `index.json`. TDD onde aplicável (a migração tem comportamento de referência nos specs Playwright). Commits pequenos: harness no Makefile → welcome → pré-cadastro → app-update/limpeza → IDR/README. **Se o L estourar, quebre** (43a: harness + welcome; 43b: pré-cadastro + app-update + limpeza) — regra 6 da W26.

## Notas do agente (preenchido durante/após execução)

### Receita PROVADA no spike (2026-06-01) — ponto de partida, não reinvente

**Proxy reverso** (node puro, sem deps) numa origem **já stateful** (`localhost:3000` está no default de `SANCTUM_STATEFUL_DOMAINS`):
- `/api/*` e `/sanctum/*` → API real (`localhost:8001`)
- resto → dev-server do `flutter drive` (`localhost:7357`)
- passthrough de `upgrade` (WebSocket) para o dwds (`:7357`), e relay de `Set-Cookie` (preservar array).

**Comando que passou** (fluxo autenticado de welcome, exit 0):
```bash
chromedriver --port=4444 &
node proxy.js &                      # :3000 → app:7357 / api:8001
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/<...>_test.dart \
  -d web-server --browser-name=chrome --headless \
  --web-hostname=localhost --web-port=7357 \
  --web-launch-url=http://localhost:3000      # SEM --dart-define: same-origin via proxy
```

**Por que funciona:** app e API aparecem na **mesma origem** (`:3000`) para o browser → cookie Sanctum (`SameSite=Lax`) é guardado e reenviado sozinho; **nem CORS é acionado** (same-origin). A flag-chave é `--web-launch-url` (desacopla a URL do browser do servidor do Flutter). Origem `:3000` já é stateful no Sanctum → **zero mudança de produção**.

**Evidência do contraste:**
- Same-origin (proxy): login → `/welcome` → "Vamos lá" (POST autenticado) → `/completar-cadastro` → **All tests passed**; backend persistiu `welcome_visto=true`.
- Cross-origin (`--dart-define=API_BASE_URL=:8001`, sem proxy): login → `/welcome` ✅, mas "Vamos lá" (autenticado, sem cookie) **falha** → trava em `/welcome`.

**Gotchas observados no spike:**
- O fluxo welcome **muta o seed** (`welcome_visto`) → re-semear por run ou usuário descartável (CA-5), senão o 2º run pega usuário já welcomado.
- Esperar a tela montar antes de tocar (`pumpUntilFound(find.byKey(Key('btn-vamos-la')))`) — `awaitRouteChange('/welcome')` retorna antes do botão renderizar.
- O proxy do spike (≈40 linhas, node puro) está em `/tmp/turni-spike-proxy.js` da sessão de origem — recriável a partir da descrição acima; versione em `scripts/` ou equivalente.

### Plano inicial (registrado antes de codar — 2026-06-01)

**Documentos lidos:** esta estória inteira; STORY-038 (todas as Notas — receita do spike, helpers, agregador,
gotchas); IDR-010 (header + correção de sintaxe `flutter drive`), IDR-014 (proxy same-origin de dev + endpoint
`/me`), template de IDR; `Makefile` (targets `e2e-webapp*`, `_e2e-seed`); `apps/webapp/router.php` (proxy de
referência de dev → `api:8000`); `apps/api/config/sanctum.php` (`localhost:3000` JÁ é stateful no default);
`integration_test/` inteiro (agregador `auth_test.dart`, helpers `pump_app`/`login_helper`/`route_helper`,
cenários migrados); specs a migrar (`welcome`, `pre-cadastro`, `pre-cadastro-contratante`, `app-update`);
`lib/features/funnel/welcome_screen.dart` (keys `btn-vamos-la`, `welcome-headline`, `screen-welcome`);
`lib/features/cadastro/pre_cadastro_*` + `shared/cadastro_widgets.dart` (keys `input-*`, `btn-submit-cadastro`,
`link-entrar`, `screen-cadastro-*`); `lib/features/auth/auth_service.dart` (`_apiBase` default same-origin;
`markWelcomeSeen` → POST autenticado); `lib/router.dart` (funnel guard + rotas); `AdminUserSeeder.php`
(`bemvindo.profissional@turni.local` com `welcome_seen_at=null`, reset por `updateOrCreate` a cada `_e2e-seed`).

**Entendimento consolidado:** o spike provou o Caminho 1 (proxy reverso same-origin + `--web-launch-url`). Minha
tarefa é **produtizar** no Makefile (proxy versionado em `scripts/`) e **migrar** welcome + validações de
pré-cadastro para `integration_test` (rodando same-origin, cookie Sanctum trafega como em produção/IDR-014).
O `--dart-define=API_BASE_URL` cross-origin da STORY-038 sai — o app passa a default same-origin (`_apiBase=''`),
servido pelo proxy `:3000`. `localhost:3000` já é stateful no Sanctum → zero mudança de produção. app-update fica
em smoke Playwright (web-platform: service worker/version.json/page.route — não migra). Happy-path com foto
continua `test.fixme` (Patrol/IDR-009, STORY-039).

**Dúvidas:** nenhuma bloqueante. Caminho técnico já provado por spike; sigo a receita.

**Plano (commits pequenos — regra 6 da W26: 43a = harness+welcome; 43b = pré-cadastro+app-update+limpeza):**
1. Harness: `scripts/e2e-webapp-proxy.js` (node puro) + reescrever `make e2e-webapp-integration` (chromedriver +
   proxy + `flutter drive --web-launch-url=http://localhost:3000`, sem `--dart-define`). (CA-1, CA-2)
2. Welcome: `integration_test/auth/welcome_test.dart` (red→green via harness) + agregador + remover
   `welcome.spec.ts`. Contraste cross-origin documentado (CA-3, CA-4, CA-5).
3. Pré-cadastro: cenários de validação/navegação em `integration_test/cadastro/` + reduzir/remover specs (CA-6).
4. app-update → smoke; limpar `tests/e2e/` e `e2e-webapp-playwright-legacy` (CA-7, CA-8).
5. IDR-021 (proposed) + README §Testes E2E (CA-10, CA-11).
6. 5x `make e2e-webapp` verde + wall-time; cobertura; finalizar Notas; `in_review` (CA-9, DoD).

**Mapeamento CA → teste (planejado):**
- CA-3/CA-4 → `integration_test/auth/welcome_test.dart` :: "profissional liberado segue por Vamos lá → /completar-cadastro"
  (POST autenticado same-origin; falharia cross-origin — contraste no spike).
- CA-4 (2º login) → `welcome_test.dart` :: "2º login com welcome_visto pula /welcome → /completar-cadastro".
- CA-5 → garantido por `_e2e-seed` (reset `welcome_seen_at=null` via `updateOrCreate` a cada run do gate).
- CA-6 → `integration_test/cadastro/pre_cadastro_profissional_test.dart` :: "tela pública carrega", "campo
  obrigatório", "link Entrar → /login"; `pre_cadastro_contratante_test.dart` :: idem para contratante.
- CA-7 → `tests/e2e/app-update.spec.ts` permanece (smoke Playwright, target próprio não-flaky).
- CA-8 → `tests/e2e/` = `webapp-hello-world.spec.ts` + `app-update.spec.ts`; `e2e-webapp-playwright-legacy` removido.

### Decisões tomadas
- **Proxy em Node puro versionado em `scripts/e2e-webapp-proxy.js`** (~90 linhas, sem deps), chamado pelo
  Makefile. Roteia `/api`+`/sanctum` → API (`:8001`) e o resto → dev-server do `flutter drive` (`:7357`),
  numa origem única `localhost:3000` (já stateful no Sanctum). Espelha o `router.php` de dev, mas no host
  (o dev-server do drive roda no host, não no container). Tem log de request opcional (`E2E_PROXY_DEBUG=1`,
  desligado por default) — foi essencial para diagnosticar o blocker abaixo; mantido gated por ser barato e útil.
- **Entrypoints de drive:** `auth_test.dart` (auth, inclui welcome) e `cadastro_test.dart` (pré-cadastro) como
  agregadores de feature para dev; `web_test.dart` (topo) compõe os dois e é o **alvo único do gate** — uma só
  invocação de `flutter drive` (compila/abre browser 1x) para manter o wall-time baixo (CA-9).
- **welcome em `auth/welcome_test.dart`** (2 cenários: segue por "Vamos lá" → /completar-cadastro; 2º login pula
  welcome), rodando por ÚLTIMO no agregador por mutar `welcome_visto`. **CA-5** garantido pelo `_e2e-seed`
  (`updateOrCreate` reseta `welcome_seen_at=null` a cada run) — re-semeia por run, sem usuário descartável.
- **app-update fica em Playwright, target próprio NÃO-gating** `make e2e-webapp-app-update` (CA-7): é
  comportamento web-platform (service worker, `/version.json`, `page.route`, `skipWaiting`+reload) e o banner só
  dispara contra build com tag real (IDR-017). Não entra no gate → gate determinístico.
- **`e2e-webapp-playwright-legacy` removido** (CA-8): welcome/pré-cadastro migraram; restou só app-update (target
  próprio) + smoke `webapp-hello-world`.
- **IDR nova (IDR-021)** em vez de estender a IDR-010 — o harness same-origin é decisão substancial e auto-contida
  que a STORY-022+ vai herdar; merece registro próprio (a IDR-010 continua sendo o modelo híbrido).

### Descobertas
- **🔑 BLOCKER REAL (não capturado pelo spike): binding IPv6 vs IPv4.** Com `--web-hostname=localhost`, o
  dev-server do `flutter drive` no macOS bindava em `::1` (IPv6 localhost) **apenas**. O proxy Node conectava em
  `127.0.0.1` (IPv4) → **ECONNREFUSED** em todo request → o browser recebia 502 no `GET /`, o bundle JS nunca
  carregava, o app não bootava e o `flutter drive` **pendurava ~11 min** (timeout default do `pumpAndSettle`)
  sem reportar. Diagnóstico: log de request no proxy mostrou só `GET /` repetido (sem `.js`); `curl localhost:7357`
  funcionava mas `curl 127.0.0.1:7357` dava `exit 7`. **Fix:** `--web-hostname=127.0.0.1` (bind IPv4) + proxy
  conecta em `127.0.0.1`. Após isso: bundle completo carrega via `:3000` e **"All tests passed"**. (O spike
  provavelmente rodou onde `localhost` resolvia/bindava IPv4, mascarando isso.)
- **`--web-launch-url` É honrado** no caminho `-d web-server --browser-name=chrome` (o browser do WebDriver abre a
  URL do proxy). O canal de resultados browser↔runner é via WebDriver/chromedriver (`:4444`, direto ao Chrome),
  independente do proxy — por isso o proxy só precisa servir app + API, não o canal de debug.
- O `data:,` nos args do Chrome é só a URL de lançamento do chromedriver; a navegação real (para `:3000`) é via
  comando WebDriver e não aparece em `ps` — descartar `ps` como evidência de navegação.

### Bloqueios encontrados
- **Resolvido (sem escalar):** o hang de ~11 min era o binding IPv6/IPv4 acima — não uma falha do Caminho 1.
  Caminho 1 (proxy + `--web-launch-url`) **funciona**; não foi preciso recorrer ao Caminho 2 nem escalar ao PO.
- **Off-screen tap (resolvido):** o 1º gate full pegou o `btn-submit-cadastro` do contratante fora do viewport
  (SingleChildScrollView) → tap não registrava → validação não exibia → `find.text` 0. Fix: `tester.ensureVisible`
  antes do tap (em ambos os pré-cadastros). Rodada isolada de `cadastro_test.dart` → "All tests passed".

### Mapeamento CA → teste (final)

| CA | Como é provado |
|---|---|
| CA-1 | `make e2e-webapp-integration` sobe chromedriver + `scripts/e2e-webapp-proxy.js` + `flutter drive --web-launch-url`, sem `--dart-define`; `trap` derruba tudo; sai !=0 no 1º fail. |
| CA-2 | Proxy roteia `/api`+`/sanctum` → `:8001`, resto → dev-server `:7357`, origem única `localhost:3000` (stateful no default do Sanctum). Sem CORS/withCredentials/mock/alteração de produção. |
| CA-3 | `auth/welcome_test.dart` (cenário autenticado) passa via harness; o contraste cross-origin (trava em /welcome) está registrado no spike + IDR-021. |
| CA-4 | `integration_test/auth/welcome_test.dart` :: "segue por Vamos lá → /completar-cadastro" (POST autenticado welcome-visto) **e** "2º login pula /welcome → /completar-cadastro". `welcome.spec.ts` removido. |
| CA-5 | `make _e2e-seed` faz `updateOrCreate(welcome_seen_at=null)` em `bemvindo.profissional@turni.local` a cada run → re-semeia por run; 5x determinístico. |
| CA-6 | `integration_test/cadastro/pre_cadastro_profissional_test.dart` e `pre_cadastro_contratante_test.dart` :: "tela pública carrega", "submeter vazio → erros obrigatórios", "link Entrar → /login". Happy-path c/ foto segue `test.fixme` nos specs Playwright (reduzidos). |
| CA-7 | `app-update.spec.ts` permanece em Playwright, target próprio NÃO-gating `make e2e-webapp-app-update` (web-platform; banner só com tag real — IDR-017). |
| CA-8 | `tests/e2e/` = `webapp-hello-world.spec.ts` (smoke) + `app-update.spec.ts` (não-gating) + `pre-cadastro*.spec.ts` reduzidos a `test.fixme`. `e2e-webapp-playwright-legacy` removido. |
| CA-9 | 5x `make e2e-webapp` — ver "Resultado do gate" abaixo. |
| CA-10 | IDR-021 `proposed` (`decisions/idr/IDR-021-...md`) + indexada. |
| CA-11 | `apps/webapp/README.md` §"Testes E2E" reescrita (harness same-origin, comandos, debug 1 cenário). |

### Resultado do gate (CA-9)
- **5x `make e2e-webapp`: PASS · PASS · PASS · PASS · PASS** (zero flake). Cada run: integration "All tests
  passed" + smoke "4 passed (~8.7s)".
- **Wall-time por run:** 57s, 56s, 56s, 57s, 56s (média **~56,4s**). Baseline STORY-038 ~49s → **+~7s (+15%)**,
  abaixo do teto de 30%. Justificado: o gate agora roda também o welcome (fluxo autenticado same-origin, com
  login + POST welcome-visto) e 6 cenários de pré-cadastro, num único `flutter drive` (agregador `web_test.dart`).
- **Cobertura unitária:** `flutter test --coverage` → **74,0% (1150/1555)**, **idêntica** ao baseline da
  STORY-038 → **não regrediu** (esta story não adiciona lógica de produção; só testes + harness + Makefile +
  proxy + docs). 97/97 widget tests verdes. O gap para 80% é débito pré-existente, **fora de escopo** (ação
  separada do PO, conforme a própria story).
