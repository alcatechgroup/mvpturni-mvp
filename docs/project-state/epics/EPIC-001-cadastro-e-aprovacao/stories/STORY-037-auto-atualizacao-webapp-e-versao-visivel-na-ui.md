---
story_id: STORY-037
slug: auto-atualizacao-webapp-e-versao-visivel-na-ui
title: Auto-atualização do WebApp Flutter (consumidor do version.json) + versão visível na UI
epic_id: EPIC-001
sprint_id: SPRINT-2026-W25
type: implementation
target_role: programador
requires_design: true
design_screen_id: null
status: in_progress
owner_agent: programador-claude
created_at: 2026-05-30
updated_at: 2026-05-30
estimated_session_size: M
produces_idr: IDR-017
---

# STORY-037 — Auto-atualização do WebApp Flutter (consumidor do `version.json`) + versão visível na UI

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Ela contém tudo o que você precisa. Se algo estiver ambíguo, registre a dúvida na seção "Notas do agente" no final e pause em vez de adivinhar.

## Contexto (por que esta estória existe)

A homologação pelo celular está **impossível hoje**: ao acessar `https://app.homolog.turni.com.br` pelo browser do mobile, o bundle Flutter Web e o service worker padrão do Flutter ficam pinados no dispositivo e **nunca trocam de versão** sem o usuário fazer hard-reload manual (que muitos browsers mobile escondem). Toda nova release publicada via CI/CD fica invisível para quem já abriu o app uma vez — o que mata o ciclo "publicar em homolog → testar pelo celular" que sustenta o EPIC-001 e adiante.

A diretriz arquitetural **já existe** e foi aprovada pelo PO em 2026-05-27:

> **ADR-001 §Plano de verificação — "Auto-atualização do WebApp"** (linhas 130-133):
> - `index.html` e o service worker servidos com `Cache-Control: no-cache` (sempre revalidam); demais assets com hash de conteúdo, imutáveis.
> - Endpoint `version.json` (git sha / build id) publicado no deploy; **o app compara a versão rodando com a do servidor ao abrir e ao retornar de background; havendo nova, exibe aviso não-bloqueante "Nova versão disponível — atualizar" que dispara `skipWaiting` + reload.**
> - **Gate de versão mínima** pela API (`426 Upgrade Required`) nos fluxos críticos (PIN/pagamento).
> - "Detalhe fino pode virar um ADR Frontend/PWA dedicado; a diretriz fica registrada aqui."

A infra do **lado servidor** já está pronta há sprints: `IDR-002` + `STORY-007` (`done`) publicam `/version.json` nas três interfaces com `Cache-Control: no-cache`. O `firebase.json` da webapp já tem o header correto (`apps/webapp/web/firebase.json` configurado em STORY-008). **O que falta** é o **lado cliente** no Flutter Web — polling, comparação, banner "Nova versão disponível" + `skipWaiting` + reload — e a **versão visível na UI** (que hoje aparece só na `/info`/welcome estático e não é vista por quem está logado).

O risco está formalmente registrado em `STORY-001` §Riscos (linha 159): *"Médio: disciplina de auto-atualização do WebApp para evitar 'versão velha' — padrão definido, **precisa ser implementado fielmente**."* Esta estória paga essa dívida.

A estória é **M**: o `version.json` já existe, o `_appVersion = String.fromEnvironment('APP_VERSION')` já está disponível (IDR-002), o service worker é o padrão do Flutter build (STORY-008 CA-12). A novidade é (a) um pequeno serviço Dart de polling + comparação + chamada de `skipWaiting()` via `js_interop`, (b) um banner reutilizável discreto (snackbar/MaterialBanner), (c) três pontos de exibição da versão na UI (login, cadastro, área logada). Nada toca backend, fila, banco ou auth.

- Épico: `docs/project-state/epics/EPIC-001-cadastro-e-aprovacao/epic.md`
- Documentos canônicos a ler ANTES de codificar:
  - `docs/project-state/decisions/adr/ADR-001-stack-principal.md` (§Plano de verificação — "Auto-atualização do WebApp", linhas 130-133 — **fonte de verdade da diretriz**)
  - `docs/project-state/decisions/idr/IDR-002-versioning-e-exposicao-versao-runtime.md` (formato do `version.json`, header `Cache-Control: no-cache`, `--dart-define=APP_VERSION`)
  - `docs/project-state/epics/EPIC-000-foundation/stories/STORY-007-pipeline-cicd-deploy-automatico-homologacao.md` (CA-7b/c/d — stamping no artefato + arquivo estático já vivo)
  - `docs/project-state/epics/EPIC-000-foundation/stories/STORY-008-hello-world-webapp.md` (CA-11/12 — manifest + service worker padrão do Flutter já plugados)
  - `docs/project-state/decisions/ddr/DDR-001-fundacao-do-design-system.md` (tokens, contraste AA, padrão de banner/snackbar)
  - `docs/especificacao/non-functional.md` (RNF "PWA instalável", compatibilidade mobile)
  - `docs/project-state/decisions/adr/ADR-007-auth-base-e-roteamento.md` (§F5 — "esquema escolhido precisa sobreviver ao service worker e à auto-atualização": não invalidar sessão Sanctum no reload)
  - `firebase.json` (raiz do repo — headers de `/index.html`, `/version.json`, `/flutter_service_worker.js`)
  - `apps/webapp/web/index.html`, `apps/webapp/web/version.json` (geração do arquivo em build pelo pipeline)
  - `apps/webapp/lib/main.dart`, `apps/webapp/lib/router.dart`, `apps/webapp/lib/features/welcome/welcome_screen.dart` (consumo já existente de `APP_VERSION`)
  - `apps/webapp/lib/features/auth/login_screen.dart`, `apps/webapp/lib/features/cadastro/pre_cadastro_profissional_screen.dart`, `apps/webapp/lib/features/cadastro/pre_cadastro_contratante_screen.dart`, `apps/webapp/lib/features/app/app_shell_screen.dart` (3 pontos de exibição da versão)
  - `docs/skills/programador/SKILL.md`, `docs/skills/po/references/quality-standards.md`

## O quê (objetivo desta estória)

Entregar, no **WebApp Flutter** (`apps/webapp`):

### 1. Serviço de auto-atualização (`lib/core/app_update/`)

Novo módulo isolado e testável:

- **`AppVersion`** (value object): wrapper sobre `String` da tag (`vX.Y.Z-rc.N` ou `dev`); operador `==` por valor; método `isDifferentFrom(AppVersion other)`.
- **`AppVersionService`**:
  - `Future<AppVersion> fetchServerVersion()` — faz `GET /version.json` (path relativo, mesma origin) com `Cache-Control: no-cache` no header da request **e** `?t=<epochMs>` como cache-buster defensivo, timeout 5s, retorna `AppVersion` ou propaga falha; ignora erros silenciosamente (não-bloqueante).
  - `AppVersion currentVersion` — lê `String.fromEnvironment('APP_VERSION', defaultValue: 'dev')`.
- **`AppUpdateController`** (ChangeNotifier ou pequeno Bloc — decisão do agente):
  - Estado: `{updateAvailable: bool, serverVersion: AppVersion?}`.
  - Roda **polling a cada 5 min** com `Timer.periodic` enquanto a página está visível (cancelado quando hidden).
  - Roda **uma verificação imediata** em: (i) bootstrap do app, (ii) retorno do tab para foreground (escuta `document.visibilityState === 'visible'` via `package:web` ou `dart:js_interop`), (iii) sucesso de login (hook explícito).
  - Quando `serverVersion != currentVersion` E `currentVersion != 'dev'`: liga `updateAvailable = true`. Em `dev` (sem dart-define) a checagem é desabilitada — evita ruído em desenvolvimento local.
- **`ServiceWorkerBridge`** (interop fina com `dart:js_interop` / `package:web`):
  - `Future<void> activateNewVersionAndReload()` — envia `{type: 'SKIP_WAITING'}` para o SW em waiting (se houver), aguarda `controllerchange` por até 2 s, e dispara `window.location.reload()`. Fallback (se não houver SW waiting ou navegador sem suporte): `reload()` direto.

### 2. Banner "Nova versão disponível"

- Componente **`UpdateBanner`** (Flutter widget) em `lib/core/app_update/widgets/update_banner.dart`, **não-bloqueante**, ancorado no topo das telas (via `Overlay` ou um `Scaffold` wrapper colocado no `MaterialApp.builder`).
- Texto: **"Nova versão disponível"** (corpo curto) + botão primário **"Atualizar agora"** + botão texto **"Depois"**.
- "Atualizar agora" → `ServiceWorkerBridge.activateNewVersionAndReload()`.
- "Depois" → fecha o banner; reabre na próxima checagem se ainda houver versão nova (não persiste "ignorar para sempre" — a política de ADR-001 é "atualizar para a última publicada").
- Aplica tokens do Design System (DDR-001): cor de fundo `surfaceRaised`, accent para CTA primário, contraste WCAG AA verificado, ícone `Icons.system_update_alt` (lucide-like), ARIA/Semantics `role: status` (não modal).
- Aparece em **todas as telas** (autenticadas e não-autenticadas) — registrar uma única vez no `MaterialApp.builder` do `main.dart` para que injete o `Overlay` no topo de qualquer rota.

### 3. Versão visível na UI (3 pontos)

A versão exibida é `currentVersion` (não a do servidor) — é a versão **que está rodando agora** no dispositivo. Quando `updateAvailable=true`, o banner é a sinalização; o rodapé apenas mostra a corrente.

Formato visual: **"Turni · v0.1.0-rc.24"** (microcopy fixa, em `body-xs` ou equivalente, `textMuted`, opacidade adequada para "discreto"). Em `dev` (sem `--dart-define`): **"Turni · dev"**.

Pontos de exibição:

- **Tela de login** (`login_screen.dart`) — rodapé, abaixo do formulário, centralizado, com no mínimo `TurniSpacing.lg` de respiro acima.
- **Tela de pré-cadastro profissional** (`pre_cadastro_profissional_screen.dart`) — mesmo padrão: rodapé discreto após o último elemento, dentro do `SingleChildScrollView`.
- **Tela de pré-cadastro contratante** (`pre_cadastro_contratante_screen.dart`) — mesmo padrão.
- **Área logada** (`app_shell_screen.dart`) — **rodapé do menu** (quando o app shell tiver menu lateral ou inferior; enquanto a estrutura for o placeholder atual, vai no rodapé do `Column` da tela, abaixo do botão "Sair", com a mesma estética discreta). Quando o menu real vier em estórias futuras (área logada do EPIC-002+), esta exibição **migra para o rodapé do menu** — o widget `AppVersionLabel` reutilizável já entregue por esta estória torna a migração trivial.
- **NÃO** exibir na `/info` (que já mostra a versão hoje — STORY-008) — mantém o comportamento atual lá.

### 4. Headers servidos pelo Firebase Hosting

Garantir, no `firebase.json` raiz (já configurado para `/index.html` e `/version.json` — confirmar) que **`/flutter_service_worker.js`** também seja servido com `Cache-Control: no-cache, no-store, must-revalidate` — o SW é a outra metade da causa-raiz citada em ADR-001 §"HTML novo apontando para bundle velho / SW servindo `main.dart.js` em cache". Adicionar o header se não estiver presente nos dois targets (`homolog` e `prod`).

### 5. IDR-017 — "Auto-atualização do WebApp: polling + SKIP_WAITING + banner"

Registrar em `docs/project-state/decisions/idr/IDR-017-auto-atualizacao-webapp-polling-skipwaiting-banner.md`, `accepted`:

- Referencia ADR-001 §"Auto-atualização do WebApp" e IDR-002.
- Decisões operacionais que NÃO sobem para ADR dedicada (o ADR Frontend/PWA dedicado mencionado em ADR-001 fica para quando o gate `426 Upgrade Required` da API for implementado em EPIC-003 — Pix/PIN):
  - Janela de polling = 5 min (com triggers extras em visibilitychange + login). Justificativa: balanceia frescor de release (release típica fica visível em < 5 min) vs. ruído de requests (288 GETs/dia/usuário; payload 30 bytes; `no-cache` mas leve).
  - Cache-buster `?t=<epochMs>` defensivo além do header `no-cache` — alguns proxies/CDNs ainda colapsam GETs idênticos.
  - "Depois" não persiste — política da ADR-001 é "atualizar para a última publicada"; persistir "ignorar" abriria janela de versão indefinidamente velha.
  - `dev` desabilita a checagem (evita ruído local).
  - Gate de versão mínima (`426`) **fora desta estória** — fica para o ADR Frontend/PWA dedicado quando entrar PIN/pagamento (EPIC-003).
- Sinais de revisão: se o banner for percebido como intrusivo em homolog (PO/teste de mobile), reduzir frequência ou trocar por badge silencioso no rodapé com versão clicável → "Atualizar". Não fazer ainda.

## Por quê (valor para o usuário)

**Direto:** destrava a homologação pelo celular — qualquer mudança publicada em homolog (`v0.1.0-rc.N+1`) passa a aparecer ao usuário em ≤ 5 min sem hard-reload manual, permitindo que o PO valide o funil do EPIC-001 pelo celular como o método primário (não só desktop). Hoje o PO precisa abrir o DevTools mobile ou desinstalar/recadastrar PWA para ver mudanças — uso real impraticável.

**Indireto:** paga a dívida estrutural registrada em STORY-001 §Riscos (linha 159) sem inventar nada — implementa fielmente o que ADR-001 já decidiu. Prepara o terreno para o gate `426 Upgrade Required` que EPIC-003 (Pix/PIN) precisará. Versão visível na UI dá ao operador (Alexandro + testadores) o reflexo de "qual versão estou vendo?" sem abrir DevTools nem inspecionar `/version.json` no curl — diagnóstico de campo em 1 segundo.

## Critérios de aceite

### Auto-atualização

- [ ] **CA-1 (polling + comparação):** `AppVersionService.fetchServerVersion()` faz GET de `/version.json` com header `Cache-Control: no-cache` e query `?t=<epochMs>`, parseia `{"version":"..."}`, retorna `AppVersion` em ≤ 5 s; em qualquer erro (rede, 4xx/5xx, JSON inválido), captura silenciosamente e não muda estado (não-bloqueante). Coberto por teste unitário com `MockClient`.
- [ ] **CA-2 (triggers de verificação):** `AppUpdateController` dispara `fetchServerVersion()` em (i) bootstrap do app, (ii) `document.visibilityState === 'visible'`, (iii) hook explícito chamado pelo sucesso de login, (iv) timer periódico de 5 min enquanto a aba está visível (cancelado em hidden). Coberto por teste unitário.
- [ ] **CA-3 (estado `updateAvailable`):** `updateAvailable=true` se e somente se `serverVersion != currentVersion` **E** `currentVersion != 'dev'`. Teste unitário cobre os 4 cenários: same/different × dev/release.
- [ ] **CA-4 (banner discreto):** `UpdateBanner` aparece **no topo** de qualquer rota (login, cadastro, área logada, welcome, etc.) via `MaterialApp.builder` quando `updateAvailable=true`; texto **"Nova versão disponível"**; CTA primário **"Atualizar agora"**; CTA secundário **"Depois"**; tokens DDR-001 aplicados; contraste AA verificado em modo claro e escuro; `Semantics(role: status)` para leitor de tela; **não bloqueia** interação com o conteúdo abaixo.
- [ ] **CA-5 (`skipWaiting` + reload):** clique em "Atualizar agora" chama `ServiceWorkerBridge.activateNewVersionAndReload()` que (i) envia `{type:'SKIP_WAITING'}` para `navigator.serviceWorker.controller?.postMessage` se houver SW em waiting, (ii) aguarda `controllerchange` por até 2 s, (iii) dispara `window.location.reload()`; fallback de reload direto se não houver SW. Coberto por teste integrado em browser real (Chrome headless via Playwright/integration_test).
- [ ] **CA-6 (sessão sobrevive ao reload — ADR-007 §F5):** após `activateNewVersionAndReload()`, a sessão Sanctum permanece válida (cookie same-site `app.homolog.turni.com.br`) — usuário não cai no login. Verificado em E2E (login → forçar `updateAvailable=true` via mock → clicar "Atualizar" → ver tela logada de novo, não /login).
- [ ] **CA-7 (clique "Depois"):** fecha o banner; próxima checagem reabre se ainda houver versão nova; **não persiste** estado de "ignorar" em `localStorage` nem em memória além do ciclo de polling.

### Versão visível na UI

- [ ] **CA-8 (login):** rodapé da `login_screen` mostra "Turni · {version}" centralizado, `body-xs`, `textMuted`, discreto, com no mínimo `TurniSpacing.lg` de respiro acima. Key E2E: `Key('app-version-label-login')`.
- [ ] **CA-9 (cadastro profissional):** rodapé da `pre_cadastro_profissional_screen` mostra o mesmo padrão. Key E2E: `Key('app-version-label-cadastro-profissional')`.
- [ ] **CA-10 (cadastro contratante):** idem em `pre_cadastro_contratante_screen`. Key E2E: `Key('app-version-label-cadastro-contratante')`.
- [ ] **CA-11 (área logada):** rodapé do menu/shell em `app_shell_screen` mostra o mesmo padrão; quando o menu real vier em estória futura, basta mover o `AppVersionLabel` para o rodapé do componente de menu. Key E2E: `Key('app-version-label-app-shell')`.
- [ ] **CA-12 (não-quebra):** `/info` (welcome estático de STORY-008) continua mostrando a versão **como já mostrava** — esta estória não altera aquele ponto.

### Headers (Firebase Hosting)

- [ ] **CA-13 (SW no-cache):** `firebase.json` (targets `homolog` **e** `prod`) serve `/flutter_service_worker.js` com `Cache-Control: no-cache, no-store, must-revalidate`. `/index.html` e `/version.json` permanecem como já estão (no-cache). Verificado em homolog após deploy: `curl -I https://app.homolog.turni.com.br/flutter_service_worker.js` retorna o header esperado.

### IDR-017

- [ ] **CA-14 (IDR-017 accepted):** `decisions/idr/IDR-017-auto-atualizacao-webapp-polling-skipwaiting-banner.md` registrado, referenciando ADR-001 §"Auto-atualização do WebApp" e IDR-002, com as 5 decisões operacionais listadas (janela 5 min, cache-buster, "Depois" não persiste, dev desabilita, gate 426 fora de escopo).

### Testes

- [ ] **CA-15 (cobertura unitária):** cobertura ≥ 80% no código novo (`lib/core/app_update/`); módulos com lógica pura (`AppVersion`, `AppVersionService` parseando JSON, `AppUpdateController` comparando versões) ≥ 95%.
- [ ] **CA-16 (E2E real):** Playwright em browser real (homolog ou local com servidor estático) cobre o caminho feliz: bootstrap → polling vê versão diferente (servida por mock/Firebase) → banner aparece → clique "Atualizar agora" → reload → app sobe com nova versão; verificar via `data-testid`/Key.

### Smoke em homolog pós-deploy

- [ ] **CA-17 (smoke mobile):** após release `vX.Y.Z-rc.M` aplicada em homolog, **acessar `https://app.homolog.turni.com.br` por um celular** (PO valida); abrir o app, deixar uma aba aberta; publicar uma release `rc.M+1`; voltar ao celular: em ≤ 5 min (ou ao voltar do background) o banner "Nova versão disponível" aparece; clicar "Atualizar agora" carrega o `rc.M+1` sem hard-reload manual. PO assina o smoke em chat ou no DoD.

## Fora de escopo

- **Gate de versão mínima `426 Upgrade Required` pela API** — ADR-001 §plano de verificação prevê para fluxos críticos (PIN/pagamento). Fica para EPIC-003 (Pix/PIN) e para o ADR Frontend/PWA dedicado mencionado em ADR-001.
- **ADR Frontend/PWA dedicado.** ADR-001 prevê como evolução possível; esta estória só registra IDR-017 com as decisões operacionais. Quando o `426` entrar, o conjunto sobe para ADR.
- **Mudar o service worker padrão do Flutter por Workbox/custom.** STORY-008 CA-12 fixou o SW padrão como suficiente para MVP. Esta estória só comunica `SKIP_WAITING` com ele; não troca a estratégia.
- **Migrar versão exibida para a do servidor.** A label mostra a versão **rodando** (currentVersion). Mostrar a do servidor confundiria — quem dá o sinal de "tem nova" é o banner.
- **Persistir "ignorar versão X"** — política ADR-001 é "atualizar para a última".
- **Refatoração do design do app shell ou do menu real da área logada** — STORY-037 entrega o widget reutilizável `AppVersionLabel` e o usa no rodapé do `app_shell_screen` atual (placeholder). A migração para o rodapé do menu real vem com a estória do menu real.
- **Backoffice (admin).** Mesma diretriz se aplica (admin também tem `/version.json` por IDR-002), mas o admin é Livewire (server-rendered) — fluxo de cache diferente, sem service worker Flutter. Estória própria se/quando necessário.
- **Versão visível na landing (`apps/landing`).** Site institucional, sem `version.json` (ADR-012). Fora.

## Padrões de qualidade exigidos

`quality-standards.md`. Em particular:

- **Cobertura ≥ 80%** no código novo; ≥ 95% nas peças puras (comparação de versão, parse de JSON).
- **E2E em browser real** (seção 1.2): caminho feliz do banner + reload em Chrome via Playwright (ou integration_test sob `flutter test integration_test`).
- **Acessibilidade WCAG 2.1 AA** (seção 5): contraste verificado em tema claro/escuro; `Semantics(role: status)` no banner; foco do CTA "Atualizar agora" acessível por teclado.
- **Observabilidade** (seção 3): logs do console (informativos, severity `info`) em (i) detecção de versão nova (`appUpdate.detected`, com `serverVersion` e `currentVersion`), (ii) usuário clica "Atualizar" (`appUpdate.userAccepted`), (iii) `skipWaiting` enviado (`appUpdate.skipWaiting`). Mantém o padrão "diagnóstico em 1 segundo".
- **Sem código não testado em produção** (seção 1.4).
- **Identidade visual** aplica DDR-001 (não cria padrão novo paralelo): banner usa cores e spacing do DS, label de versão usa `body-xs` + `textMuted`.
- **Reversibilidade** (princípio #7): o módulo `lib/core/app_update/` é isolado; remover o widget do `MaterialApp.builder` desativa o banner sem efeitos colaterais; a label de versão é um único widget reutilizável que se remove de cada tela em segundos.

## Dependências

- **Bloqueada por:** nenhuma. Toda a infra (version.json publicado, dart-define, manifest, SW padrão, header no-cache) já está viva em homolog desde STORY-007/008.
- **Bloqueia:** **smoke mobile do EPIC-001** (STORY-021/023/024/025 ficam testáveis pelo celular com fluxo natural — sem isso, o PO continua dependente de desktop ou de hard-reload manual no mobile, o que descaracteriza a validação).
- **Pré-requisitos:** STORY-007 (pipeline + `version.json` no ar), STORY-008 (manifest + SW padrão plugados), ADR-001 (diretriz arquitetural), IDR-002 (formato de `version.json`), DDR-001 (tokens de DS).

## Decisões já tomadas (não as reabra)

- **ADR-001** — auto-atualização do WebApp via comparação de `version.json` + `skipWaiting` + reload; banner não-bloqueante; `no-cache` em HTML+SW.
- **IDR-002** — `/version.json` é arquivo estático com `{"version":"vX.Y.Z-rc.N"}`, `Cache-Control: no-cache`.
- **STORY-008 CA-11/12** — service worker padrão do Flutter build é suficiente para MVP.
- **ADR-007 §F5** — esquema de auth precisa sobreviver ao SW e à auto-atualização (Sanctum SPA same-origin cobre).
- **DDR-001** — fundação do Design System (tokens, contraste AA).

## Liberdade técnica do agente

Você decide:

- Estado: `ChangeNotifier` simples, `ValueNotifier`, ou Bloc/Riverpod se já houver convenção no app (verificar `lib/features/auth/auth_service.dart` para o padrão atual). Recomendação: o mais leve que combine com o que já existe — esta estória não é hora de introduzir gerenciador de estado novo.
- Local exato do `UpdateBanner` no overlay: `MaterialApp.builder` injetando um `Stack` ou `Banner` próprio. Recomendação: `MaterialApp.builder` com `Stack` controlado pelo `AppUpdateController` (escutado via `ListenableBuilder`).
- Como escutar `visibilitychange`: `package:web` (canônico Flutter 3.10+) ou `dart:js_interop` direto. Recomendação: `package:web`.
- Cache-buster: `?t=<epochMs>` (recomendado pela IDR-017) ou `?v=<currentVersion>`. Recomendação: epochMs — força resposta nova mesmo se a tag local for igual à do servidor por algum motivo de race.
- Janela de polling exata dentro de 5 min (3–7 min) — recomendação: 5 min.
- Onde commitar o `AppVersionLabel` reutilizável: `lib/ds/components/app_version_label.dart` (parte do DS) ou `lib/core/app_update/widgets/app_version_label.dart` (parte do módulo). Recomendação: `lib/ds/components/` — é exibição visual reaproveitável, não lógica de update.

Você NÃO decide:

- Mudar o formato do `version.json` (IDR-002).
- Trocar o service worker padrão do Flutter por outro (STORY-008 CA-12).
- Persistir "ignorar versão" (ADR-001 + IDR-017 §"Depois" não persiste).
- Habilitar a checagem em `dev` (IDR-017 §dev desabilita).
- Implementar o gate `426 Upgrade Required` aqui (fora de escopo — EPIC-003).
- Mudar onde a versão aparece (especificado pelo PO: login, 2 cadastros, área logada/rodapé do menu — e mantém `/info` como está).
- Trocar o microcopy do banner sem aprovação do PO ("Nova versão disponível" / "Atualizar agora" / "Depois").

## Definição de Pronto (DoD)

- [ ] CA-1 a CA-17 passam com evidência.
- [ ] IDR-017 `accepted` com OK do PO em chat.
- [ ] `firebase.json` atualizado (header SW) e revisado.
- [ ] Cobertura ≥ 80% no código novo (≥ 95% nas peças puras); suíte verde local e no CI.
- [ ] E2E Playwright (ou integration_test) verde local; smoke CA-17 em homolog assinado pelo PO.
- [ ] `index.json` atualizado (STORY-037 `done`; IDR-017 `accepted`).
- [ ] STORY-021/023/024/025 ganham nota informativa "testável pelo celular sem hard-reload" no fechamento, se aplicável.
- [ ] "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Carregue `docs/skills/programador/SKILL.md`. **Sequência sugerida:**

1. Redigir IDR-017 (`proposed`) com as 5 decisões operacionais.
2. Construir `lib/core/app_update/` (AppVersion, AppVersionService, AppUpdateController, ServiceWorkerBridge) com testes unitários.
3. Construir `UpdateBanner` + injetá-lo no `MaterialApp.builder` do `main.dart`.
4. Construir `AppVersionLabel` (em `lib/ds/components/`) e plugar em login, 2 cadastros, app_shell.
5. Atualizar `firebase.json` (header SW no-cache nos 2 targets).
6. Cobertura local verde; integration_test/Playwright verde.
7. Pedir release `rc.N`; smoke mobile com o PO (CA-17).
8. IDR-017 `accepted` com OK do PO.
9. Atualizar `index.json` (status `done`, IDR-017 `accepted`); marcar `done`.

## Notas do agente (preenchido durante/após execução)

### Entrada inicial

**Documentos lidos:** estória inteira; ADR-001 §"Auto-atualização do WebApp" (linhas 130-133); IDR-002 (formato `version.json`, header no-cache, dart-define); STORY-007/008 (referência); DDR-001 via `tokens.dart`/`theme.dart`; ADR-007 §F5 (sessão sobrevive ao reload); `firebase.json`; código existente do `webapp` (`main.dart`, `router.dart`, `auth_service.dart`, `login_screen.dart`, os 2 `pre_cadastro_*_screen.dart`, `app_shell_screen.dart`, `welcome_screen.dart`, `tokens.dart`, `theme.dart`); specs de E2E existentes (`tests/e2e/*.spec.ts`, `playwright.config.ts`).

**Entendimento consolidado (minhas palavras):** o servidor já publica `/version.json` com `{"version":"vX.Y.Z-rc.N"}` e header `no-cache` (IDR-002/STORY-007). Falta o lado cliente Flutter: um serviço que faz polling do `version.json` (a cada 5 min + em bootstrap, em volta de foreground, em login) e compara com a versão rodando (`String.fromEnvironment('APP_VERSION', defaultValue: 'dev')`); quando diferente E não-`dev`, mostra banner não-bloqueante no topo de qualquer rota ("Nova versão disponível" / "Atualizar agora" / "Depois"). "Atualizar agora" manda `SKIP_WAITING` ao SW e dá reload. Também: label discreta "Turni · {versão}" no rodapé de login, 2 cadastros e app_shell; header `no-cache` para `/flutter_service_worker.js` no `firebase.json`; IDR-017; e a sessão Sanctum precisa sobreviver ao reload (cookie same-origin já garante — nada a fazer no auth).

**Dúvidas:** nenhuma bloqueante. O microcopy e os pontos de exibição estão fixados pelo PO; as liberdades técnicas estão explícitas na estória.

**Plano (5 bullets):**
1. IDR-017 `proposed` com as 5 decisões operacionais.
2. Módulo `lib/core/app_update/` isolado e testável: `AppVersion` (VO puro), `AppVersionService` (http + MockClient), `AppUpdateController` (ChangeNotifier, lógica pura + triggers), e interop web (`ServiceWorkerBridge` + `VisibilityWatcher`) atrás de **conditional import** (`dart.library.js_interop`) com stub no-op para a VM — assim os testes unitários rodam em VM sem `package:web`.
3. `UpdateBanner` no `MaterialApp.builder` (Stack/Overlay no topo) escutando o controller via `ListenableBuilder`; tokens DDR-001; `Semantics`.
4. `AppVersionLabel` em `lib/ds/components/` + plug nas 4 telas com Keys E2E.
5. `firebase.json` (header SW nos 2 targets) + suíte verde (`flutter test` + `flutter analyze`) + spec Playwright + roteiro manual.

**Testes que pretendo escrever:**
- `AppVersion`: igualdade por valor, `isDifferentFrom`, `isDev` (dev/vazio).
- `AppVersionService`: parse OK; erro de rede; 4xx/5xx; JSON inválido; timeout; header `no-cache` + query `?t=` presentes (via MockClient capturando a request).
- `AppUpdateController`: 4 cenários da CA-3 (same/different × dev/release); trigger de bootstrap/visibility/login; timer periódico (fakeAsync); "Depois" fecha e reabre na próxima checagem; erro silencioso não muda estado.
- `UpdateBanner`: aparece só quando `showBanner`; textos/CTAs; "Atualizar agora" chama o bridge; "Depois" chama `dismiss`; Semantics.
- `AppVersionLabel`: formato "Turni · v..."; "Turni · dev" no default; Keys presentes nas 4 telas.

### Decisões tomadas

- **Estado:** `AppUpdateController extends ChangeNotifier` (o mais leve que combina com o app — `AuthService` já é `ChangeNotifier`). Sem Bloc/Riverpod novo.
- **Interop web atrás de conditional import** (`dart.library.js_interop`): `ServiceWorkerBridge` e `VisibilityWatcher` têm um `*_stub.dart` no-op (VM) e um `*_web.dart` real (`package:web` + `dart:js_interop`). Isso mantém o módulo 100% testável em VM sem `package:web`. Registrado como convenção no IDR-017.
- **`web: ^1.1.0` declarado no pubspec** (já vinha transitivo do Flutter SDK) para satisfazer `depend_on_referenced_packages`. `fake_async` promovido a dev_dependency direta (controle determinístico de `Timer.periodic`).
- **`UpdateBannerHost` no `MaterialApp.builder`** com `Stack` + `Positioned(top)` + `SafeArea` + `ListenableBuilder` — banner no topo de qualquer rota, não-bloqueante (conteúdo abaixo segue interativo).
- **`AppVersionLabel` em `lib/ds/components/`** (exibição reaproveitável, recomendação da estória).
- **Singleton `appUpdate`** (`lib/core/app_update/app_update.dart`), coerente com `AuthService`, para o hook de login (`login_screen` chama `appUpdate.onLoginSuccess()` no `LoginSuccess`).
- **Cache-buster `?t=<epochMs>`** + header `Cache-Control: no-cache` na request (IDR-017).

### Descobertas

- **O service worker padrão do Flutter ativa-se ao receber a STRING `'skipWaiting'`, não o objeto `{type:'SKIP_WAITING'}`** que a estória cita. Para funcionar de fato com o SW de STORY-008, o `ServiceWorkerBridge` web envia **as duas** mensagens à instância em `waiting` (a string aciona o SW do Flutter; o objeto é ignorado por ele, mas fica robusto caso o SW mude). Sem a string, o `SKIP_WAITING` não teria efeito.
- **Ordem dos headers no `firebase.json` importa (last-wins).** `/flutter_service_worker.js` casa também com o glob `**/*.@(js|css|wasm)` (immutable). Para o `no-cache` vencer, o bloco específico precisa vir **depois** do glob (confirmado pelo padrão já documentado no target landing deste mesmo `firebase.json`).
- **`dev` desabilita a checagem (IDR-017)** → em build local (`APP_VERSION=dev`) o banner nunca aparece por design. Logo, o E2E do banner (CA-16) só roda contra um build com tag real (homolog ou `--dart-define=APP_VERSION`). O spec Playwright faz `test.skip` automático quando `/version.json` retorna `dev`.
- O `build web` com `--dart-define=APP_VERSION` compila os arquivos `*_web.dart` (validação que os testes em VM não dão) e o **Wasm dry run** também passou.

### Bloqueios encontrados

- Nenhum bloqueio técnico. Pendências de fechamento que **não são minhas** (PO/deploy): aceite do PO no IDR-017 (CA-14), execução do E2E Playwright contra um build com tag real (CA-16) e o smoke mobile assinado pelo PO (CA-17). Ver "Resultado final".

### IDRs criados

- IDR-017 — Auto-atualização do WebApp: polling + SKIP_WAITING + banner — **`proposed`** (aguarda OK do PO em chat para virar `accepted` — CA-14).

### Cobertura final

- **Novo código (linhas executáveis em VM): 100% (133/133).** Peças puras todas a 100%: `AppVersion`, `AppVersionService`, `AppUpdateController`, `UpdateBanner`, `AppVersionLabel`. Stubs de plataforma também a 100%.
- Os arquivos browser-only (`service_worker_bridge_web.dart`, `visibility_watcher_web.dart`) não entram na cobertura de VM (não são compilados lá) — cobertos pelo E2E em browser (CA-16) e validados pelo `flutter build web`.
- Suíte completa do webapp: **97 testes verdes**. `flutter analyze`: 0 issues no código novo (2 `info` pré-existentes em validators de cadastro, não tocados, tolerados pelo CI `--no-fatal-infos`). `dart format` limpo em `lib/`.

### Resultado final / evidência

**Implementado e verificado localmente (CAs cobertos por testes):**

- CA-1/CA-2/CA-3/CA-7 — `test/app_update/app_version_service_test.dart` + `app_update_controller_test.dart` (incl. fakeAsync para o timer de 5 min; triggers bootstrap/visibility/login; "Depois" não persiste).
- CA-4/CA-5 (lado Dart) — `test/app_update/update_banner_test.dart` (banner no topo, microcopy fixo, CTAs, Semantics liveRegion, "Atualizar agora" chama o bridge, "Depois" esconde, conteúdo abaixo permanece).
- CA-8/CA-9/CA-10/CA-11 — assertions de Key nas suítes de `login`, `pre_cadastro_profissional`, `pre_cadastro_contratante` e novo `app_shell_screen_test.dart`.
- CA-12 — `/info` (welcome estático) não foi tocada; label de versão não foi adicionada lá.
- CA-13 — `firebase.json`: `/flutter_service_worker.js` com `no-cache, no-store, must-revalidate` nos targets `homolog` **e** `prod`.
- CA-15 — cobertura ≥ 95% nas peças puras (100%) e ≥ 80% no novo código (100%).

**Deploy em homolog — release `v0.1.0-rc.29` (2026-05-31, run Release #26699079761 `success`):**

- **CA-13 verificado LIVE:** `curl -sI https://app.homolog.turni.com.br/flutter_service_worker.js` → `cache-control: no-cache, no-store, must-revalidate` ✅. `version.json` → `{"version":"v0.1.0-rc.29"}` ✅. `index.html` → no-cache ✅.
- **CA-8 + CA-16 verificados em browser real (Playwright/Chromium contra homolog):** `BASE_URL=https://app.homolog.turni.com.br npx playwright test app-update` → **3 passed**. Cobre: (1) rodapé do login mostra "Turni · v0.1.0-rc.29"; (2) versão nova (mock) → banner "Nova versão disponível" → "Atualizar agora" recarrega; (3) "Depois" fecha o banner.

**CA-17 — smoke mobile VALIDADO (2026-05-31):** o PO (Alexandro) confirmou "FUNCIONOU" no celular — com a aba no `rc.31`, publicado o `rc.32`, o banner apareceu e "Atualizar agora" carregou o `rc.32` **sem limpeza manual**. Necessário o fix do `rc.31` (ver emenda do IDR-017): a primeira tentativa (rc.29→rc.30) falhava porque `main.dart.js`/`flutter_bootstrap.js` eram `immutable` e o `skipWaiting`/`controllerchange` é instável no iOS/WKWebView. Migração: aparelhos presos em versão ≤ rc.30 precisam de **uma** limpeza única para chegar ao rc.31; daí em diante atualiza sozinho.

**Pendente (gate do PO — Alexandro):**

- **CA-14** — IDR-017 (`proposed`, já com a emenda do workaround) → `accepted` após OK do PO nas decisões operacionais + emenda.
