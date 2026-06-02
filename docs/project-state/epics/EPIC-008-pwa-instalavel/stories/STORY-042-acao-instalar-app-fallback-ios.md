---
story_id: STORY-042
slug: acao-instalar-app-fallback-ios
title: Ação "Instalar app" no WebApp Flutter — beforeinstallprompt no Android/Chromium + fallback iOS
epic_id: EPIC-008
sprint_id: SPRINT-2026-W27
type: implementation
target_role: programador
requires_design: true  # designer revisa o card "Instalar app" e o modal iOS contra DDR-001
design_screen_id: null
status: done  # 2026-06-02 — PO aprovou em chat após smokes em homolog (rc.47); IDR-020 accepted
owner_agent: programador
created_at: 2026-05-31
updated_at: 2026-06-02  # done — card validado no iPhone (rc.47) + Android/desktop via prompt nativo
estimated_session_size: M
produces_idr: IDR-020
renamed_from: STORY-039  # 2026-06-01 — colisão com EPIC-007 STORY-039 (Patrol)
---

# STORY-042 — Ação "Instalar app" com prompt nativo Android/Chromium + fallback iOS

> **Para o agente que vai executar:** esta estória é o coração do EPIC-008. Tem que coexistir sem regredir 1 vírgula com a auto-atualização (STORY-037 / IDR-017). Tudo que envolve `service worker`, `Cache Storage`, `firebase.json` no entry chain Flutter e `flutter_service_worker.js` está **fora de escopo** — esta story só **adiciona** comportamento; não substitui nem refatora o que já existe. Leia inteira antes de codificar.

## Contexto (por que esta estória existe)

O RNF do MVP (`docs/especificacao/non-functional.md` linha 96) diz: *"WebApp instalável como PWA no Android e iOS (suporte parcial iOS)."* Hoje o WebApp **é** uma PWA tecnicamente correta — STORY-008 plugou manifest e SW; STORY-037 endureceu o ciclo de cache (entry chain `no-cache`) — mas o usuário **não tem visibilidade** de que pode instalá-lo. No Android Chrome, o navegador dispara `beforeinstallprompt` em segundo plano e mostra um banner discreto que poucos clicam (ou esconde de vez se foi descartado uma vez). No iOS Safari, não dispara prompt nenhum: o usuário precisa saber o gesto "Compartilhar → Adicionar à Tela de Início", que é invisível para quem nunca instalou uma PWA.

Esta story entrega: (a) uma **ação "Instalar app"** visível no app, plugada em pontos definidos por IDR-020 (recomendação: mesmos pontos da `AppVersionLabel` — login, 2 cadastros, app shell); (b) ao clicar em **Android/desktop Chromium**, dispara o **prompt nativo** do navegador (`event.prompt()` no `BeforeInstallPromptEvent` que foi capturado e guardado); (c) ao clicar em **iOS Safari/Chrome**, abre um **modal de instruções** com 2 passos; (d) **esconde a ação** quando o app está em modo standalone (já instalado) ou quando a plataforma não suporta instalação alguma (Firefox desktop, por exemplo).

A STORY-041 (paralela neste épico) entrega os **ícones Turni**. STORY-042 não depende dos ícones para passar — depende **logicamente** para a experiência visual de "instalou e viu a marca", mas o código é ortogonal.

A peça que toca o navegador (capturar `beforeinstallprompt`, detectar iOS Safari, detectar `display-mode: standalone`) precisa rodar **antes** do Flutter inicializar — `beforeinstallprompt` dispara cedo no ciclo da página e precisa de `preventDefault()` para guardar a referência. Por isso o script é inline no `<head>` do `index.html`, **antes** do `<script src="flutter_bootstrap.js" async>`. O Dart consome via `dart:js_interop` (`package:web`) — mesmo padrão do `ServiceWorkerBridge` em `lib/core/app_update/` (STORY-037). Importante: o script **não pode** registrar service worker próprio, **não pode** tocar `caches`, **não pode** interceptar `fetch` — para não brigar com o SW padrão do Flutter nem com o `unregister()`/`caches.delete()` que o `ServiceWorkerBridge.activateNewVersionAndReload()` faz.

- Épico: `docs/project-state/epics/EPIC-008-pwa-instalavel/epic.md`
- Documentos canônicos a ler ANTES de codificar:
  - `docs/project-state/decisions/idr/IDR-017-auto-atualizacao-webapp-polling-skipwaiting-banner.md` (+ emenda) — **invariante** a preservar.
  - `docs/project-state/epics/EPIC-001-cadastro-e-aprovacao/stories/STORY-037-auto-atualizacao-webapp-e-versao-visivel-na-ui.md` — padrão de implementação a replicar (módulo isolado + conditional import + interop web atrás de stub).
  - `apps/webapp/lib/core/app_update/` — referência viva do padrão: `service_worker_bridge.dart` (interface + factory), `service_worker_bridge_stub.dart` (no-op VM), `service_worker_bridge_web.dart` (real, `package:web`). Replicar a estrutura.
  - `apps/webapp/lib/main.dart` — onde plugar a inicialização da feature de instalação ao lado de `appUpdate.start()`.
  - `apps/webapp/lib/core/app_update/widgets/update_banner.dart` — referência de estilo de banner (DDR-001 tokens, `Semantics`).
  - `apps/webapp/lib/ds/components/app_version_label.dart` — referência dos pontos de plugagem candidatos (login, 2 cadastros, app shell).
  - `apps/webapp/web/index.html` — onde adicionar o `<script>` pré-Flutter.
  - `apps/webapp/web/manifest.json` — referência (não vai mudar nesta story).
  - `docs/project-state/decisions/ddr/DDR-001-fundacao-do-design-system.md` — tokens, contraste AA.

## O quê (objetivo desta estória)

### 1. Script pré-Flutter em `web/index.html`

Bloco `<script>` inline no `<head>`, antes de `<script src="flutter_bootstrap.js" async>`:

- Cria um objeto JS global (nome final definido em IDR-020 — recomendação: `window.turniInstall`) com flags: `canPrompt`, `deferredPrompt`, `isStandalone`, `isIOS`, `isInstallable`.
- Detecção sync (imediata):
  - `isStandalone`: `window.matchMedia('(display-mode: standalone)').matches || window.navigator.standalone === true`.
  - `isIOS`: `/iPad|iPhone|iPod/.test(navigator.userAgent) && !window.MSStream`.
- Listener `beforeinstallprompt`: `e.preventDefault(); deferredPrompt = e; isInstallable = true;` (mais um `CustomEvent` para o Dart escutar).
- Listener `appinstalled`: limpa o estado + `CustomEvent`.
- Função `promptNative()` que chama `deferredPrompt.prompt()`, espera `userChoice`, retorna `'accepted' | 'dismissed' | 'unavailable'`, e zera o `deferredPrompt` (single-use por especificação).
- Tudo dentro de `try/catch` silencioso. **Não toca** `navigator.serviceWorker`, **não toca** `caches`, **não toca** `fetch`.

### 2. Módulo Dart (path final definido em IDR-020 — recomendação: `lib/core/install/`)

Replicando o padrão de `lib/core/app_update/`:

- **Interface + factory com conditional import** (`dart.library.js_interop`).
- **Stub no-op para VM** (testes unitários rodam sem `package:web`).
- **Implementação web** com `package:web` + `dart:js_interop`, lendo do objeto JS global e escutando os `CustomEvent`s via `addEventListener`.

- **Controller (`ChangeNotifier`)** com estado:
  - `bool get showAction` = `(isInstallable && !isStandalone) || (isIOS && !isStandalone)`, menos `_dismissed` no ciclo.
  - `bool get isIOS` (vem do bridge).
  - `Future<void> requestInstall()`:
    - Se `isIOS`: emite `_showIosInstructions=true` (o widget abre o modal).
    - Senão: chama `bridge.promptNative()`. Em `accepted` ou `dismissed`, marca local como dispensado (o navegador não dispara `beforeinstallprompt` de novo na mesma sessão).
  - `void dismiss()` — fecha a ação neste ciclo (**não persiste**; reabre se trocar de rota ou se o JS emitir `installable` de novo). Coerente com IDR-017 "não persistir".
  - `void dismissIosInstructions()` — fecha o modal.
  - Escuta o `bridge.installableChanges` (ou equivalente) e emite `notifyListeners()`.
- **Singleton** análogo a `appUpdate`.
- **Widget `InstallActionCard`** — card discreto com microcopy definida em IDR-020 (recomendação: "Instalar app na tela inicial" + CTA "Instalar" (Android/Chromium) / "Como instalar" (iOS)). Tokens DDR-001. `Semantics(button:true)`.
- **Widget `IosInstallInstructionsDialog`** — modal com 2 passos textuais + ícones Material (`Icons.ios_share` e `Icons.add_to_home_screen`). Botão "Entendi" fecha. `Semantics` apropriado.

### 3. Pontos de plugagem na UI

Definidos em IDR-020. **Recomendação:** 4 pontos espelhando a `AppVersionLabel`:

- `apps/webapp/lib/features/auth/login_screen.dart` — abaixo da `AppVersionLabel`, com `Key('install-action-login')`.
- `apps/webapp/lib/features/cadastro/pre_cadastro_profissional_screen.dart` — idem, `Key('install-action-cadastro-profissional')`.
- `apps/webapp/lib/features/cadastro/pre_cadastro_contratante_screen.dart` — idem, `Key('install-action-cadastro-contratante')`.
- `apps/webapp/lib/features/app/app_shell_screen.dart` — rodapé, `Key('install-action-app-shell')`.

Padrão sugerido: `ListenableBuilder(listenable: installController, builder: ... if(showAction) return InstallActionCard(...) else return SizedBox.shrink();)`.

**Alternativa:** card único no `MaterialApp.builder` (como faz o `UpdateBannerHost`). IDR-020 escolhe e justifica.

### 4. `main.dart`

- Adicionar a inicialização do controller ao lado de `appUpdate.start()`. Se for `ChangeNotifier` simples, chamar o `start()` análogo.

### 5. IDR-020

Em `docs/project-state/decisions/idr/IDR-020-acao-instalar-app-pwa-fallback-ios.md`, `status: proposed` na entrega; sobe para `accepted` com OK do PO. Cobre:

- **Quando a ação aparece** — `showAction` formal.
- **Pontos de exibição** — recomendação 4 pontos; agente pode propor card único + justificar.
- **Microcopy aprovada** — card "Instalar app na tela inicial" + CTAs; modal iOS com os 2 passos + "Entendi".
- **Política de dispensa** — não persiste; coerente com IDR-017.
- **Standalone detection** — `matchMedia('(display-mode: standalone)') OR navigator.standalone`.
- **iOS sniff por user-agent** — aceito como state-of-the-art; alternativas descartadas.
- **Identidade visual dos ícones** — 192, 512, maskable 192/512 com safe zone de 80%, apple-touch-icon 180×180, favicon 32×32. SVG-fonte versionado em `web/icons/source/`. **Esta IDR é compartilhada com STORY-041.**
- **Não-toca** — service worker, Cache Storage, `firebase.json` entry chain. IDR-017 manda.
- **Trade-offs aceitos** — iOS sem prompt programático; Firefox desktop sem instalação; cache do ícone antigo em PWAs já instaladas até desinstalar/reinstalar.

### 6. Headers no `firebase.json`

- **Não tocar** nos blocos do entry chain Flutter nem no glob `**/*.@(js|css|wasm)`. PNGs caem no default do Firebase Hosting. Revalidar via `version.json` cycle (IDR-002 / STORY-037) garante que troca de identidade visual chega com a próxima release.
- Se o smoke detectar que ícone novo não chega no aparelho mesmo após "Atualizar agora", o agente abre uma sub-decisão (não nesta story): adicionar bloco específico para `/icons/**.png` com `no-cache`. **Não fazer preventivamente.**

## Por quê (valor para o usuário)

- **Profissional**: instalar o app na home transforma o WebApp em ferramenta de trabalho de 1 toque, sem tela do browser, com ícone reconhecível. Reduz fricção para abrir o app em contexto real (na rua, com pressa). É também o pré-requisito para push notifications (próxima onda) — sem instalar, push em iOS não funciona.
- **Contratante**: idem. Plus, instalar reduz a confusão de "qual aba era?" no navegador desktop.
- **Time**: estabelece o padrão (módulo Dart isolado + interop web atrás de stub + widget reaproveitável) para futuras integrações com APIs de plataforma (push, geolocalização, câmera). É a segunda integração desse tipo no projeto após `app_update/`.

## Critérios de aceite

### Script pré-Flutter (index.html)

- [ ] **CA-1:** `web/index.html` tem o `<script>` inline no `<head>`, **antes** de `flutter_bootstrap.js`. Define o objeto global (nome em IDR-020). Registra `beforeinstallprompt` e `appinstalled`. Define `promptNative()`. Tudo em `try/catch`. Não chama `navigator.serviceWorker`, não chama `caches`, não chama `fetch`. Verificado via diff e leitura por outro agente.
- [ ] **CA-2:** Em Chromium (Android ou desktop), abrir a página com DevTools → Application → Manifest → "Add to home screen" como simulação de `beforeinstallprompt` → o objeto global reflete `isInstallable=true` e `deferredPrompt !== null`. Cobertura manual aceita se a engine de Playwright não disparar `beforeinstallprompt` natural (comum em CI).

### Módulo Dart

- [ ] **CA-3:** Estrutura do módulo espelha `lib/core/app_update/`: interface + factory + stub VM + impl web + controller + 2 widgets. Conditional import com `dart.library.js_interop`. Stub VM no-op funcional (testes unitários rodam sem `package:web`).
- [ ] **CA-4:** `flutter analyze` 0 issues no código novo. `dart format` limpo. Nenhum import direto de `package:web` ou `dart:js_interop` fora de `*_web.dart`.

### Controller e estado

- [ ] **CA-5 (showAction):** `showAction` é `true` se e somente se `(isInstallable && !isStandalone) || (isIOS && !isStandalone)`, menos `_dismissed`. Testes unitários cobrem os 6 cenários: (a) Android instalável e não standalone → true; (b) Android standalone → false; (c) iOS Safari não standalone → true; (d) iOS standalone → false; (e) navegador sem `beforeinstallprompt` e não iOS → false; (f) dispensado neste ciclo → false.
- [ ] **CA-6 (dispensa não persiste):** `dismiss()` esconde a ação no ciclo atual; trocar de rota e voltar mostra a ação de novo se ainda houver instalabilidade. Coberto por teste unitário.
- [ ] **CA-7 (iOS abre modal):** `requestInstall()` em `isIOS=true` muda o estado para `showIosInstructions=true`. `dismissIosInstructions()` zera. Coberto por teste unitário.
- [ ] **CA-8 (Chromium chama bridge):** `requestInstall()` em `isIOS=false && isInstallable=true` chama `bridge.promptNative()` exatamente 1 vez. Coberto por teste unitário com bridge falso.
- [ ] **CA-9 (cobertura ≥ 95% nas peças puras):** controller, stub e parser de plataforma ≥ 95%.

### UI

- [ ] **CA-10 (pontos plugados conforme IDR-020):** o `InstallActionCard` aparece nos pontos definidos com as Keys (`install-action-*`). Os widget tests dessas telas asseguram que o card aparece quando `showAction=true` (injetar controller falso) e some quando `false`.
- [ ] **CA-11 (modal iOS):** clicar no card em modo iOS abre o `Dialog` com os 2 passos textuais; "Entendi" fecha o modal. Coberto por widget test.
- [ ] **CA-12 (a11y):** o card tem `Semantics(button: true)`; o modal tem texto com `Semantics(label: ...)` adequado; `flutter test` cobre `find.bySemanticsLabel`. Contraste AA verificado em tema claro e escuro.
- [ ] **CA-13 (DDR-001):** o card e o modal usam exclusivamente tokens de `lib/ds/tokens.dart`. Nenhum hard-coded color/spacing.

### Integração com auto-update (não-regressão)

- [ ] **CA-14:** o `<script>` do `index.html` **não** registra service worker, não chama `caches.*`, não intercepta `fetch`. Verificado via leitura do diff.
- [ ] **CA-15:** `UpdateBannerHost` (STORY-037) continua funcionando — banner aparece quando `appUpdate.showBanner=true`, esconde quando não. O `InstallActionCard` **não** rouba foco/Z-order do banner (decisão de IDR-020).
- [ ] **CA-16:** suíte completa `flutter test` continua verde, cobertura ≥ 80%; nada em `lib/core/app_update/` precisou ser tocado.
- [ ] **CA-17:** suíte E2E (Playwright) continua verde. Adicionar 1 cenário: "card 'Instalar app' aparece no login quando o objeto global indica `isInstallable=true`" (injetado via `page.addInitScript` ou equivalente).
- [ ] **CA-18 (smoke não-regressão CA-17 STORY-037):** publicar `rc.M+1` com aba aberta em `rc.M`, banner "Nova versão disponível" aparece em ≤ 5 min, "Atualizar agora" carrega — **com este épico no ar**. Assinado pelo PO em chat. Sem isso, o épico não fecha.

### Smoke mobile (objetivo do épico)

- [ ] **CA-19 (Android Chrome — caminho feliz):** com release publicada, abrir `app.homolog.turni.com.br` no Chrome Android, ver o card "Instalar app". Clicar em "Instalar" abre o prompt nativo. Aceitar → app é instalado, ícone Turni na home (depende da STORY-041), ao abrir o app é standalone (sem barra do browser). Captura de tela em chat.
- [ ] **CA-20 (iOS Safari — caminho feliz com instruções):** abrir no Safari iOS, ver o card "Instalar app" com CTA "Como instalar". Clicar abre o modal com 2 passos. Seguir os passos no Safari (Compartilhar → Adicionar à Tela de Início) → app instalado, ícone Turni na home, abre standalone. Captura de tela em chat.
- [ ] **CA-21 (já instalado some):** abrir o app em modo standalone (após instalar) — o card "Instalar app" **não aparece** em nenhum dos pontos de plugagem. Verificado em smoke e em widget test.

### IDR-020

- [ ] **CA-22:** `IDR-020-acao-instalar-app-pwa-fallback-ios.md` em `decisions/idr/`, `status: proposed` na entrega, com todas as decisões operacionais.
- [ ] **CA-23:** PO aprova IDR-020 em chat após smokes CA-19/CA-20 verdes; status sobe para `accepted`.

## Fora de escopo

- **Push notifications** — instalar é pré-requisito, push fica para WAVE-2026-02+.
- **A/B test de quando mostrar o card** — política simples; A/B fica para depois.
- **Custom install UX por persona** (profissional vs contratante) — mesmo card e mesma microcopy.
- **Onboarding pós-instalação** ("Bem-vindo ao app!") — fora; o app já tem login/funnel próprio.
- **Service worker próprio** — fora; o do Flutter basta.
- **Deep linking pós-instalação** (`start_url` específico) — fora; `start_url: "/"` continua.

## Padrões de qualidade exigidos

`docs/skills/po/references/quality-standards.md`:

- **Cobertura ≥ 80%** no total; ≥ 95% nas peças puras (controller, parser de estado de plataforma).
- **E2E em browser real** (§1.2): Chromium via Playwright cobre o caminho "card visível + clique → bridge.promptNative chamado" (com mock do evento). Smoke iOS é manual (limitação da plataforma).
- **Acessibilidade WCAG 2.1 AA** (§5): contraste verificado em claro e escuro; `Semantics(button:true)` no card; modal com foco gerenciado.
- **Observabilidade** (§3): logs `debug` em (i) `install.detected` (quando `beforeinstallprompt` dispara), (ii) `install.requested` (clique no CTA), (iii) `install.choice` (`accepted`/`dismissed`/`unavailable`), (iv) `install.iosInstructionsOpened`. Em prod, `debugPrint` que vai pro DevTools só.
- **Sem código não testado em produção** (§1.4).
- **Reversibilidade** (princípio #7): remover o widget de 1 tela não quebra outras; remover a inicialização desliga a feature; o script do `index.html` é idempotente.

## Dependências

- **Bloqueada por:** aprovação do PO no escopo do EPIC-008 + esqueleto da IDR-020 (cobre microcopy aprovada, pontos de exibição, identidade visual).
- **Bloqueia:** smoke visual final do épico (CA-19/CA-20 dependem da STORY-041 para ver o ícone Turni na home — mas o código desta story funciona com qualquer ícone).
- **Pré-requisitos:** STORY-008 (manifest + SW vivos), STORY-037 (auto-update vivo — referência de padrão), `app.homolog.turni.com.br` em HTTPS.

## Decisões já tomadas (não as reabra)

- **IDR-017** — ciclo de auto-atualização atual (polling, banner, `unregister()` + `caches.delete()` + `reload()`). Esta story **não toca** nada disso.
- **STORY-008 CA-12** — SW padrão do Flutter é suficiente.
- **DDR-001** — tokens, contraste AA.
- **Dispensa não persiste** — política coerente com IDR-017.
- **iOS via instruções** — única alternativa real (WebKit não implementa `beforeinstallprompt`).
- **Identidade visual em STORY-041** — esta story não gera ícones.

## Liberdade técnica do agente

Você decide:

- Estado: `ChangeNotifier` (recomendado, coerente com `AppUpdateController` e `AuthService`) ou `ValueNotifier`/Bloc se já houver convenção.
- Card único no `MaterialApp.builder` (overlay) **ou** N plugagens por tela. Recomendação: por tela (rastreável e localmente desativável). Se escolher overlay, justifique em IDR-020.
- Exato design visual do card e do modal (dentro dos tokens DDR-001).
- Microcopy do modal iOS (dentro da intenção): se chegar a uma versão mais clara, trocar. Aprovar com o PO em chat antes do merge.
- Conversão visual no modal: ícones Material (sem novas deps) ou ilustração SVG inline. Recomendação: Material.

Você NÃO decide:

- Mexer em `lib/core/app_update/`. Vetado.
- Mexer em `firebase.json` entry chain. Vetado.
- Registrar service worker próprio. Vetado.
- Persistir dispensa em `localStorage`. Vetado (IDR-017 fixou).
- Adicionar instalação automática (sem clique do usuário). Vetado (UX e política do Chrome).
- Trocar `start_url`, `display`, `theme_color`, `background_color` do manifest. Vetado.

## Definição de Pronto (DoD)

- [ ] CA-1 a CA-23 atendidos com evidência.
- [ ] IDR-020 `accepted` com OK do PO em chat após smokes verdes.
- [ ] Cobertura ≥ 80% (≥ 95% em peças puras); `flutter analyze` 0 issues; `dart format` limpo.
- [ ] E2E Chromium verde (cenário do card visível); smoke Android (CA-19) e smoke iOS (CA-20) assinados pelo PO em chat.
- [ ] CA-18 (não-regressão STORY-037) assinado em chat.
- [ ] PR mergeado; pré-push verde.
- [ ] `index.json` atualizado (`STORY-042 status: done`, `IDR-020 status: accepted`).
- [ ] "Notas do agente" preenchidas.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Carregue `docs/skills/programador/SKILL.md`. Sequência sugerida:

1. Redigir IDR-020 (`proposed`) com todas as decisões operacionais (microcopy, pontos, política de dispensa, identidade visual referenciada, alternativa overlay-vs-card).
2. Construir o `<script>` do `index.html` (inline, defensivo, sem tocar SW). Validar manualmente em Chromium local que o objeto global vira `isInstallable=true` ao simular "Add to home screen" no DevTools.
3. Construir o módulo Dart (interface, stub, web, controller) com testes unitários (≥ 95% nas peças puras).
4. Construir `InstallActionCard` e `IosInstallInstructionsDialog`, com widget tests.
5. Plugar nos pontos definidos por IDR-020, com Keys.
6. Adicionar a inicialização em `main.dart`.
7. Adicionar 1 cenário E2E Playwright (card visível com `addInitScript`).
8. Roda local: `flutter test`, `flutter analyze`, `make e2e-webapp`. Verdes.
9. Solicitar release; smokes CA-19 (Android) e CA-20 (iOS); CA-18 (não-regressão STORY-037).
10. IDR-020 `accepted`. Atualizar `index.json`. Marcar `done`.

## Notas do agente (preenchido durante/após execução)

### Entrada inicial
- **Documentos lidos:** STORY-042 inteira; IDR-020 (já `proposed`, completo — fixa microcopy, 4 pontos, política de dispensa, standalone detection, identidade visual STORY-041); IDR-017 (invariante a preservar); módulo vivo `lib/core/app_update/` (interface+factory+stub+web+controller+widget) como padrão a replicar; `app_update_controller_test.dart` / `update_banner_test.dart` / `platform_stub_test.dart` como estilo de teste; `index.html`; `tokens.dart` (DDR-001); 4 telas de plugagem (login, pré-cadastro prof/contratante, app_shell — `AppVersionLabel` como vizinho); E2E `app-update.spec.ts` (Playwright + `activateSemantics`).
- **Entendimento consolidado:** adicionar feature "Instalar app" sem regredir IDR-017. Peça JS pré-Flutter no `index.html` captura `beforeinstallprompt` (preventDefault + guarda), detecta iOS/standalone, expõe `window.turniInstall` + `CustomEvent`s; **não toca** SW/caches/fetch. Módulo Dart `lib/core/install/` espelha `app_update/`: interface+factory (conditional import), stub VM, impl web (`package:web`), controller `ChangeNotifier`, singleton. Card discreto + modal iOS nas 4 telas com Keys `install-action-*`.
- **Decisão de design da dispensa (resolve tensão CA-5 × CA-6):** `_dismissed` mora no controller (entra em `showAction`, satisfaz CA-5 cenário f). A reabertura "ao trocar de rota" é feita por um wrapper `InstallActionSlot` (StatefulWidget) plugado em cada tela: no `initState` chama `controller.resetDismiss()`. O slot fica **sempre** montado (renderiza card-ou-shrink via `ListenableBuilder`), evitando o deadlock de "card some → initState não roda mais". Dispensar na mesma tela mantém escondido (sem remount); navegar e voltar remonta o slot → reabre. CA-6 testado no controller via `dismiss()` + `resetDismiss()`.
- **Plano (TDD):** (1) testes RED controller+stub; (2) módulo Dart; (3) widgets card/modal/slot + widget tests; (4) script `index.html`; (5) plugar 4 telas + `main.dart`; (6) E2E Playwright (`addInitScript`) + suíte completa + notas.
- **Testes que pretendo escrever:** controller — showAction 6 cenários (CA-5), dispensa não persiste (CA-6), iOS abre/fecha modal (CA-7), Chromium chama bridge 1× e marca dispensado em accepted/dismissed (CA-8), promptNative unavailable não dispensa (borda); stub no-op (CA-9); widgets — card mostra microcopy/Semantics/aparece-some por showAction (CA-10/CA-12/CA-13), modal 2 passos + Entendi fecha (CA-11); E2E — card visível no login com `turniInstall.isInstallable=true` injetado (CA-17).

### Decisões tomadas
- Dispensa no controller + `resetDismiss()` no `initState` do `InstallActionSlot` (ver entrada inicial) — reconcilia CA-5 e CA-6 sem `localStorage` (veta IDR-017).
- E2E do card vai para Playwright (web-platform: depende de `window.turniInstall` + semantics), não para `integration_test` — mesma natureza do `app-update.spec.ts`. Roda em build dev (instalabilidade independe de versão `dev`, diferente do auto-update).

### Descobertas
- IDR-020 já estava **completo e `proposed`** (escrito pelo PO na abertura do épico) — fixou microcopy, 4 pontos, política de dispensa, standalone detection, identidade visual. Não precisei redigir do zero (protocolo passo 1 já entregue).
- A `AppVersionLabel` já existia nos 4 pontos exatos de plugagem — bastou inserir o `InstallActionSlot` logo acima de cada uma e reduzir o espaçamento entre eles (de `lg` para `sm`).
- **Tensão CA-5 × CA-6** (dispensa no controller que entra em `showAction` vs. reabrir ao trocar de rota): resolvida com o `InstallActionSlot` sempre montado chamando `resetDismiss()` no `initState`. O slot renderiza card-ou-shrink, então nunca desmonta por estar escondido (evita o deadlock de "card some → initState não roda mais"). Ver "Decisões tomadas".
- O E2E do card **roda em build dev** (instalabilidade independe da versão, ao contrário do auto-update que é inerte em `dev`). Para disparar instalabilidade no Chromium headless (que não emite `beforeinstallprompt` sozinho) injeto um evento sintético via `page.evaluate` que exercita o listener real do `index.html` + o bridge Dart.
- `find.bySemanticsLabel` exige `Semantics(container: true)` + `ExcludeSemantics` no filho `Text` para formar um nó único com o label (senão o label do Semantics e o do Text não casam → 0 nós).

### Bloqueios encontrados
- Nenhum bloqueio técnico. Pendência operacional: smokes mobile reais (CA-19 Android / CA-20 iOS) e não-regressão auto-update com o épico no ar (CA-18) dependem de release em homolog + assinatura do PO em chat — fora do alcance do agente.

### Bug encontrado no smoke iOS (rc.46 → rc.47)
- No iPhone real (rc.46), o card **apareceu** com `isIOS=true` e CTA "Como instalar" (detecção OK), mas o **layout quebrou**: o texto "Instalar app na tela inicial" ficou espremido 1 caractere por linha. Causa: o `Row` original colocava `[Icon, Expanded(texto), TextButton, FilledButton]` lado a lado; numa largura de iPhone os dois botões consumiam o espaço e o `Expanded` do texto virava uma faixa de ~24px. No desktop (largo) não aparecia.
- **Fix (rc.47):** card reestruturado para `Column` — `Row[Icon, texto]` full-width em cima; botões num `Wrap(alignment: end)` embaixo (quebram para a linha de baixo em telas muito estreitas, sem overflow). Teste de regressão `em tela estreita (iPhone) o texto não é espremido` (largura útil do texto > 150px em viewport de 360px).
- **Validado em homolog (rc.47, UA iPhone):** `isIOS=true`, `isStandalone=false`; o texto renderiza em **246×20px (uma linha)** — captura confirma "Instalar app na tela inicial" + "Agora não" + "Como instalar" empilhados corretamente.

### Mapa CA → teste (gate de teste #2)
- **CA-1 / CA-14** — leitura do diff `web/index.html`: script em `try/catch`, sem `serviceWorker`/`caches`/`fetch` (grep confirmou só o comentário menciona).
- **CA-2** — manual (Chromium): cobertura via E2E `install-action.spec.ts` (beforeinstallprompt sintético → `turniInstall.isInstallable===true`).
- **CA-3 / CA-4** — estrutura espelha `app_update/`; `flutter analyze lib/core/install` limpo; sem import de `package:web`/`dart:js_interop` fora de `*_web.dart`.
- **CA-5** — `install_controller_test.dart` grupo "showAction (CA-5)": 6 cenários (a–f).
- **CA-6** — grupo "dispensa não persiste": `dismiss`+`resetDismiss` reabre; não reabre se instalabilidade sumiu; novo evento `installable` reabre; idempotência de `dismiss`.
- **CA-7** — grupo "iOS abre/fecha modal": `requestInstall` liga `showIosInstructions`, `dismissIosInstructions` desliga, iOS não chama prompt.
- **CA-8** — grupo "Chromium chama bridge": prompt 1×, `accepted`/`dismissed` dispensa, `unavailable` não dispensa (borda), não abre modal.
- **CA-9** — `install_platform_stub_test.dart` (stub no-op) + cobertura: controller 41/42 (97,6%), stub 8/8 (100%), card/slot/dialog 100%.
- **CA-10** — `install_widgets_test.dart` (slot aparece/some) + `login_screen_test.dart` (ponto `install-action-login` presente).
- **CA-11** — `install_widgets_test.dart`: clique no card iOS abre `ios-install-dialog`, "Entendi" fecha.
- **CA-12** — `install_widgets_test.dart`: `find.bySemanticsLabel('Instalar app na tela inicial')` com `ensureSemantics`.
- **CA-13** — card e modal usam só tokens `TurniColors/Spacing/Radius` (sem cores/spacings crus — leitura do diff).
- **CA-15 / CA-18** — não-regressão auto-update: `app_update/` intocado; smoke gating Playwright verde (console limpo); CA-18 (release + banner) pendente de PO.
- **CA-16** — `flutter test` completo: 152 verdes.
- **CA-17** — `install-action.spec.ts` verde (`make e2e-webapp-install`).
- **CA-21** — `install_widgets_test.dart`: standalone instalável → card some.

### IDRs criados
- IDR-020 — já `proposed` na abertura do épico (não alterado nesta entrega; sobe para `accepted` após smokes CA-19/CA-20 + OK do PO).

### Cobertura final
- `lib/core/install/`: controller 97,6% (41/42), stub 100%, `install_action_card` 100%, `install_action_slot` 100%, `ios_install_instructions_dialog` 100%. Peças puras ≥ 95% (CA-9 ✅). Suíte total do WebApp: 152 testes verdes.
- `flutter analyze lib/core/install test/install`: 0 issues. `dart format`: limpo. (Os 2 `info` de `curly_braces` nas telas de cadastro são pré-existentes, em linhas de validação não tocadas.)

### Links de evidência
- Commits `test/feat(STORY-042)` na `main` (TDD: red → green por CA).
- E2E local: `make e2e-webapp-install` (1 passed), `make e2e-webapp-smoke` (4 passed/1 skip), `make e2e-webapp-integration` (All tests passed — não-regressão dos fluxos logados/cadastro).
- **Release `v0.1.0-rc.46` em homolog** (workflow Release ✓, smoke pós-deploy ✓: /health 3 interfaces, /version.json bate, upload >1MB). `https://app.homolog.turni.com.br/version.json` → `v0.1.0-rc.46`; `index.html` serve o script `turniInstall`.
- **Smokes Playwright contra homolog (rc.46, EPIC-008 no ar):**
  - `install-action.spec.ts` ✓ — card "Instalar app na tela inicial" aparece no login quando `beforeinstallprompt` é capturado (CA-17; caminho automatizável do CA-19).
  - `app-update.spec.ts` ✓ (3/3) — versão visível no rodapé, banner "Nova versão disponível" + "Atualizar agora" recarrega, "Depois" fecha → **auto-update intacto com a feature no ar** (CA-15; núcleo automatizável do CA-18).
  - `webapp-hello-world.spec.ts` ✓ (4/4, 1 skip) — boot sem erros de console críticos: o script pré-Flutter não quebra a inicialização (CA-15).
- **Pendente (requer aparelho físico + assinatura do PO em chat):**
  - **CA-19** — Android Chrome real: card → "Instalar" → prompt nativo → aceitar → ícone Turni na home → abre standalone.
  - **CA-20** — iOS Safari real: card "Como instalar" → modal 2 passos → Compartilhar → Adicionar à Tela de Início → ícone na home → standalone.
  - **CA-18 (completo)** — abrir aba em rc.45, observar banner em ≤ 5 min após rc.46 (validação temporal em aba real).
  - Com CA-19/CA-20 verdes: IDR-020 → `accepted` e STORY-042 → `done`.
