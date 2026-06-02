---
idr_id: IDR-020
slug: acao-instalar-app-pwa-fallback-ios
title: Ação "Instalar app" no WebApp Flutter — beforeinstallprompt + fallback iOS + identidade visual
status: accepted  # proposed | accepted | superseded
decided_at: 2026-05-31
decided_by: programador
approved_by: PO  # 2026-06-02 — aprovada em chat após smokes CA-19 (desktop/Android prompt nativo) + CA-20 (iOS) verdes em homolog rc.47
owner_agent: programador
related_story: STORY-042  # renomeada de STORY-039 em 2026-06-01 (colisão com EPIC-007)
related_adrs: [ADR-001]
related_idrs: [IDR-002, IDR-017]
supersedes: null
superseded_by: null
created_at: 2026-05-31
updated_at: 2026-06-02
---

# IDR-020 — Ação "Instalar app": prompt nativo Android/Chromium + instruções no iOS + identidade visual

> **O que é um IDR.** Registra a decisão de implementação **local** que outros agentes precisam
> conhecer. Aqui, fixa os parâmetros operacionais da feature "Instalar app na tela inicial"
> do WebApp e a identidade visual dos ícones que ela exige, deixando explícito o que **não**
> se toca para preservar a auto-atualização (IDR-017).

## Contexto

O RNF do MVP (`docs/especificacao/non-functional.md` linha 96) fixa: *"WebApp instalável como
PWA no Android e iOS (suporte parcial iOS)."* A infra do `manifest.json` + service worker já
existe desde STORY-008. O que falta é (a) uma ação visível para o usuário disparar o prompt
nativo de instalação no Android/Chromium, (b) um fallback para iOS, onde o WebKit não
implementa `beforeinstallprompt`, e (c) **substituir** os ícones padrão do Flutter (deixados
por `flutter create`) pela identidade da marca Turni.

A restrição crítica é não regredir o ciclo de auto-atualização documentado em IDR-017
(polling do `version.json`, `unregister()` + `caches.delete()` + `reload()`, entry chain
Flutter servido `no-cache`). Qualquer script novo no `index.html` que toque
`navigator.serviceWorker` ou `caches` é vetado.

## Decisão

> **Decidi entregar a ação "Instalar app" como um card discreto plugado nas mesmas 4 telas da
> `AppVersionLabel` (login, 2 cadastros, app shell). No Android/desktop Chromium, o card dispara
> o prompt nativo capturado de `beforeinstallprompt`. No iOS Safari/Chrome, o card abre um modal
> com instruções de 2 passos. A ação some quando o app está em `display-mode: standalone`. Os
> ícones do PWA são substituídos por uma identidade Turni própria (monograma "T" branco sobre
> fundo brandGreen), com SVG-fonte versionado. Nada disso toca o service worker, o Cache Storage,
> o `firebase.json` no entry chain Flutter ou o módulo `lib/core/app_update/`.**

As 9 decisões operacionais:

1. **Quando a ação aparece.** `showAction = ((isInstallable && !isStandalone) || (isIOS && !isStandalone)) && !_dismissed`. `isInstallable` vem de `beforeinstallprompt` ter disparado e sido guardado. `isStandalone` = `matchMedia('(display-mode: standalone)').matches OR navigator.standalone === true`. `isIOS` = user-agent test.
2. **Pontos de exibição.** 4 cards plugados em login, pré-cadastro profissional, pré-cadastro contratante, app shell — espelha a `AppVersionLabel` de STORY-037. Alternativa "overlay global no `MaterialApp.builder`" considerada e descartada (ver "Alternativas").
3. **Microcopy aprovada.** Card: `"Instalar app na tela inicial"` (corpo). CTA primário: `"Instalar"` (Android/Chromium) / `"Como instalar"` (iOS). Botão secundário: `"Agora não"`. Modal iOS: 2 passos — `"1. Toque no botão Compartilhar [ícone] na barra do navegador."` / `"2. Role e toque em Adicionar à Tela de Início."`; botão `"Entendi"` fecha.
4. **Política de dispensa.** Fechar o card o esconde no ciclo atual; trocar de rota e voltar reabre se `showAction` ainda for `true`. Não há "ignorar para sempre" (nem em `localStorage`, nem além do ciclo). Coerente com IDR-017.
5. **Standalone detection** — `matchMedia('(display-mode: standalone)').matches` (cross-platform) **OR** `window.navigator.standalone === true` (iOS-only). O OR garante cobertura em iOS Safari.
6. **Script pré-Flutter no `index.html`** — bloco inline no `<head>`, antes de `flutter_bootstrap.js`. Faz: detecção sync de `isIOS`/`isStandalone`; listener de `beforeinstallprompt` que faz `preventDefault()` e guarda o evento em `window.turniInstall.deferredPrompt`; listener de `appinstalled` que limpa o estado; `CustomEvent('turni:installable')` e `CustomEvent('turni:appinstalled')` para o Dart reagir; tudo dentro de `try/catch`. **Não toca** `navigator.serviceWorker`, **não toca** `caches`, **não toca** `fetch`.
7. **Módulo Dart `lib/core/install/`** — espelha o padrão de `lib/core/app_update/`: interface + factory com `conditional import`, stub no-op VM, impl web com `package:web` + `dart:js_interop`, controller `ChangeNotifier`, widgets `InstallActionCard` e `IosInstallInstructionsDialog`. Singleton análogo ao `appUpdate`.
8. **Identidade visual dos ícones.** Substituir os 4 PNGs do `web/icons/` por ícones com a marca Turni — monograma "T" branco sobre fundo `brandGreen #00A868` arredondado (squircle). Maskable respeita safe zone de 80% (motivo dentro de 80% do diâmetro; fundo cobre 100%). Tamanhos: 192, 512, maskable 192, maskable 512, apple-touch-icon 180×180 (novo), favicon 32×32. SVG-fonte versionado em `apps/webapp/web/icons/source/`. Pipeline `scripts/generate-icons.*` regenera PNGs a partir do SVG.
9. **Gate `firebase.json`.** Não tocar nos blocos do entry chain Flutter (`/index.html`, `/main.dart.js`, `/flutter.js`, `/flutter_bootstrap.js`, `/flutter_service_worker.js`) nem no glob `**/*.@(js|css|wasm)`. PNGs caem no default do Firebase Hosting; troca de ícone chega ao usuário no próximo ciclo de release via "Atualizar agora" do banner de auto-update. Sinal de revisão: se o smoke detectar que ícone novo não chega mesmo após "Atualizar agora", abrir sub-decisão para adicionar bloco específico `no-cache` para `/icons/**.png`. Não fazer preventivamente.

## Por quê

- **Card discreto em 4 telas** (vs. overlay global): o "Instalar app" não tem a urgência do "Nova versão disponível" — atualizar é segurança/funcionalidade; instalar é conveniência. Plugar no rodapé das mesmas telas onde a `AppVersionLabel` já mora dá ao usuário a opção sem invadir o conteúdo. Telas internas (welcome, fluxos transacionais futuros) não recebem o card — o usuário está em meio a uma tarefa, não é hora.
- **Microcopy "Instalar app na tela inicial"** — explícito sobre o que vai acontecer. Curto. Sem promessa exagerada ("Instale agora!"). O CTA iOS muda para "Como instalar" porque o clique abre instruções, não o prompt — a microcopy alinha com o que o usuário vai receber.
- **"Agora não" não persiste** — coerência direta com IDR-017. Persistir "ignorar" cria a janela ruim de "usuário viu uma vez, recusou, e nunca mais ofereceu" — para auto-update isso seria pior (versão velha indefinida), para instalação é só desperdício de uma feature útil que o usuário poderia querer mais tarde.
- **`isIOS` por user-agent** — sniffing é o método consagrado para PWAs. Não há feature detection limpa para "este browser é o WebKit do iOS" no contexto de instalação (`navigator.standalone` só vira `true` quando já está instalado, não serve para detecção prévia). Aceitamos a fragilidade do UA (rara: usuários em iOS Chrome continuam usando WebKit, o sniffing por iPad/iPhone/iPod funciona).
- **SVG-fonte versionado** — paga a dívida deixada por `flutter create`. Mudar a identidade no futuro vira "edite o SVG, regere PNGs" em vez de "perdemos o source".
- **Não tocar `firebase.json` no entry chain** — a emenda da IDR-017 foi sangue suado. Risco de regressão é desproporcional ao benefício de "ícone novo aparece 1 ciclo antes".

## Alternativas consideradas

- **Overlay global no `MaterialApp.builder` (como `UpdateBannerHost`).** Descartado: a ação de instalar não é urgente; overlay em todas as rotas (welcome, fluxos transacionais, futuro feed) seria ruído. Plugagem por tela mantém o card só onde faz sentido.
- **Adicionar `localStorage` para "lembrar que dispensou"** com TTL de N dias. Descartado: coerência com IDR-017 ("não persiste"). Se o sinal mostrar fadiga real (usuários reclamando do card recorrente), revisitar com dado, não por especulação.
- **Mostrar banner único na primeira sessão sem login.** Descartado: o overlay-na-primeira-vez é difícil de definir ("primeira" segundo o quê — `localStorage` traz IDR-017 dependency e ainda some ao limpar cache). Card persistente em 4 pontos é mais simples e mais honesto.
- **Forçar SW próprio (Workbox) para controlar instalação.** Descartado: STORY-008 CA-12 fixou SW padrão; IDR-017 endureceu o ciclo em cima dele. Trocar SW para uma feature pequena seria custo desproporcional.
- **Pular o fallback iOS e só ativar Android.** Descartado: o RNF cita explicitamente iOS com "suporte parcial"; instruções com 2 passos cumprem isso. iOS é majoritário em parte do público — ignorar não é opção.
- **Adicionar `Cache-Control: no-cache` para `/icons/**.png` no `firebase.json` agora.** Descartado preventivamente: troca de ícone é evento raro, ciclo de "Atualizar agora" (que limpa todo Cache Storage) já chega ao usuário com a nova identidade. Revisitar se o smoke contradisser.

## Consequências

### Para outros agentes
- O módulo `lib/core/install/` é a fonte única da feature "instalar app". Não criar outro mecanismo de detecção de instalabilidade; reusar o controller.
- O padrão de **conditional import + stub VM + interop web** registrado em IDR-017 (e usado em `lib/core/app_update/`) agora tem segunda instância (`lib/core/install/`). É o padrão do projeto para qualquer feature que toca `package:web`/`dart:js_interop`. Documentar nessa seção sempre que adicionar nova feature do tipo.
- Microcopy do card e do modal iOS é fixada por este IDR. Trocar exige nova decisão.
- A `AppVersionLabel` segue como rótulo discreto no rodapé; o `InstallActionCard` fica **acima** dela quando ambas estão visíveis (versão é informação; instalar é ação).
- Os ícones do PWA são source-of-truth nos SVGs em `web/icons/source/`. Qualquer mudança de identidade visual edita o SVG e regera os PNGs com o script da STORY-041.

### Para o projeto
- Nenhuma dependência transversal nova. `package:web` já está no `pubspec.yaml`.
- `index.html` ganha ~30 linhas de script inline — defensivo, sem deps externas.
- 6 PNGs novos/substituídos + 3 SVGs no repo (~poucos KB).
- O `ServiceWorkerBridge.activateNewVersionAndReload()` (IDR-017) limpa Cache Storage no reload, então a próxima atualização também carrega ícones novos do servidor.

### Trade-offs aceitos
- **iOS sem prompt programático.** Limitação WebKit; mitigada pelo modal de instruções. Não é regressão; é a realidade da plataforma (RNF reconhece como "suporte parcial").
- **Cache do ícone antigo em PWAs já instaladas.** iOS cacheia o `apple-touch-icon` por *muito* tempo (ciclo de vida da home screen). Após esta entrega, usuários que já tinham o app instalado continuam vendo o ícone antigo até desinstalar/reinstalar. Documentado na STORY-041. Aceitável: instalações novas — público maior em homolog — pegam o ícone novo direto.
- **Firefox desktop sem instalação.** Sem `beforeinstallprompt` no Firefox; o card não aparece para essa fatia. Não é regressão; é falta da feature.
- **Sniffing iOS por user-agent.** Aceito como state-of-the-art; revisitar se o UA Reduction do Chrome mexer com isso (não muda iOS Safari, mas pode mudar iOS Chrome).

## Como verificar

- **Não-regressão IDR-017:** após esta IDR entrar no ar, publicar release `rc.M+1` com aba aberta em `rc.M`; banner "Nova versão disponível" aparece em ≤ 5 min; "Atualizar agora" carrega `rc.M+1` sem hard-reload. Idêntico ao smoke CA-17 de STORY-037.
- **Android Chrome:** abrir o app, ver o card "Instalar app", clicar em "Instalar", aceitar o prompt nativo, ver o ícone Turni na home, abrir o app standalone.
- **iOS Safari:** abrir o app, ver o card com CTA "Como instalar", clicar, ver o modal com 2 passos, executar "Compartilhar → Adicionar à Tela de Início", ver o ícone Turni na home, abrir standalone.
- **Já instalado:** com o app em modo standalone, o card "Instalar app" não aparece em nenhuma das 4 telas.
- **Sinal de revisão:** se o card for percebido como insistente em homolog (PO/teste mobile), reduzir para 1 tela (login) ou inserir TTL leve de dispensa por sessão. Não fazer ainda.

## Tipo

- [x] **Convenção interna**: padrão de implementação local da feature "instalar app" (módulo + microcopy + ícones + interop web) — segunda instância da convenção registrada em IDR-017.
- [ ] **Padrão transversal**: lib/abordagem que vira default no projeto.
- [ ] **Workaround**: contornar limitação de plataforma.
- [ ] **Otimização**: mudança por motivo de performance, com medição.
- [ ] **Refatoração estrutural**: mudança que afeta vários módulos por qualidade.

---

## Histórico

- 2026-05-31 — criada como `proposed` pelo PO (sessão Cowork) como parte do rascunho do EPIC-008 / STORY-042 a partir do pedido de Alexandro: "ação para o webapp se instalar na tela inicial, fallback iOS, ícone simples, não quebrar update automático". A numeração saltou de IDR-017 → IDR-020 porque IDR-018 (`render-aceite-adesao-secao1-e-documento-hash`) e IDR-019 (`session-driver-cookie-na-api-cloud-run`) já estavam ocupadas.
- 2026-06-02 — `accepted` pelo PO em chat. STORY-042 implementada e validada em homolog (rc.46 → rc.47): card aparece no desktop/Android via prompt nativo e no iOS via "Como instalar"; smoke iOS (rc.46) revelou layout do card quebrado em tela estreita (texto char-por-linha) — corrigido em rc.47 (card empilhado, botões em `Wrap`) e revalidado no iPhone. Auto-update (IDR-017) sem regressão com o épico no ar. Decisões operacionais do IDR mantidas como entregues; nenhuma alteração de escopo no aceite.
