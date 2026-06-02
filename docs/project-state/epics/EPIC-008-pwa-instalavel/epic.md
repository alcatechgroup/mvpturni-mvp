---
epic_id: EPIC-008
slug: pwa-instalavel
title: WebApp instalável na tela inicial (PWA) — ação de instalar + fallback iOS + identidade visual
wave: WAVE-2026-01
status: done  # 2026-06-02 — STORY-041 + STORY-042 done; PWA instalável validada em homolog; IDR-020 accepted
owner_role: po
created_at: 2026-05-31
updated_at: 2026-06-02  # épico concluído — ambas as estórias fechadas
sprint_id: SPRINT-2026-W27
target_completion: 2026-06-30  # estimativa orientativa — sem sprint alvo
---

# EPIC-008 — WebApp instalável na tela inicial (PWA)

## Por que existimos (problema do usuário)

O WebApp Turni roda hoje em `app.homolog.turni.com.br`, é uma PWA tecnicamente correta (`manifest.json`, service worker do Flutter e HTTPS — STORY-008 CA-11/12 + STORY-037 endureceu o ciclo de cache) e o RNF do MVP já fixa o objetivo: *"WebApp instalável como PWA no Android e iOS (suporte parcial iOS)"* (`docs/especificacao/non-functional.md` linha 96). Apesar disso, **o usuário hoje não tem como instalar o app na tela inicial sem saber o caminho**: o banner nativo do Chrome aparece e desaparece silenciosamente; o iOS Safari não dispara prompt nenhum — quem não conhece o gesto "Compartilhar → Adicionar à Tela de Início" não instala.

Esse é o primeiro problema. O segundo é mais incômodo: **os ícones do PWA hoje são o logo padrão do Flutter** (`web/icons/Icon-{192,512}.png` deixados pelo `flutter create` em STORY-008). Quem instala o app na home vê um quadrado azul-claro com o logo do framework — não a marca Turni. Para um produto que vai ser instalado pelo profissional como ferramenta de trabalho, isso reduz confiança e identidade.

Este épico entrega ao usuário (profissional e contratante) a forma natural de instalar: uma ação visível no app — botão/cartão **"Instalar app"** — que dispara o prompt nativo no Android/desktop Chromium, e, no iOS, abre **instruções com 2 passos**. E entrega a identidade visual: ícones com a marca Turni nos tamanhos exigidos pelo manifest, pelo apple-touch-icon e pelo favicon.

Nada disso pode quebrar o que **já funciona**: o ciclo de auto-atualização (STORY-037 / IDR-017) — polling do `version.json`, banner "Nova versão disponível", `unregister()` do service worker + limpeza de Cache Storage no clique de "Atualizar agora". A emenda da IDR-017 documentou que o entry chain do Flutter (`index.html`, `main.dart.js`, `flutter_bootstrap.js`, `flutter_service_worker.js`) precisa ser servido `no-cache` para a estratégia funcionar no iOS — qualquer header novo deste épico que toque o entry chain ou o service worker é **vetado**.

## Resultado esperado (outcome)

Ao fim deste épico, em `app.homolog.turni.com.br`:

- **Android (Chrome / Edge / Samsung Internet) e desktop Chromium**: ao abrir o WebApp e cumprir os critérios de instalabilidade (HTTPS, manifest válido, SW ativo — todos já em vigor), uma ação visível **"Instalar app"** aparece em ponto fixo da UI. Clicando, o usuário vê o **prompt nativo** do navegador (`beforeinstallprompt` → `prompt()`); aceitando, o app entra na home e abre como app standalone (sem barra do browser). Após instalado, a ação some.
- **iOS Safari (iPhone/iPad) e iOS Chrome**: como o WebKit do iOS não suporta `beforeinstallprompt`, a mesma ação **"Instalar app"** abre um **modal de instruções** com 2 passos ("1. Toque em Compartilhar [ícone]; 2. Role e toque em 'Adicionar à Tela de Início'"). O modal explica que é um passo único. Após instalado (display-mode standalone detectado), a ação some.
- **Já instalado / display-mode standalone**: a ação não aparece (em nenhuma plataforma).
- **Identidade visual**: o ícone do app na home (Android e iOS), no favicon e na splash de instalação usa a marca Turni — não o logo do Flutter. Tamanhos cobertos: 192, 512, maskable 192, maskable 512, apple-touch-icon 180, favicon 32. Paleta DDR-001 (`brandGreen #00A868`; superfície clara `#F7F4EC`).

A auto-atualização continua funcionando exatamente como hoje: 0 regressão em CA-1..CA-17 da STORY-037, incl. smoke mobile em homolog.

## Métrica de sucesso (como saberemos que funcionou)

- **Primária — instalabilidade percebida pelo usuário:** smoke manual em homolog (PO + 1 testador externo se disponível) atesta que (a) em Android Chrome, abrindo o WebApp logado, a ação "Instalar app" aparece e ao clicar instala como PWA com ícone Turni; (b) em iOS Safari, abrindo o WebApp logado, a ação aparece e ao clicar mostra instruções claras que permitem instalar de fato. Atestado em chat.
- **Secundária — identidade visual:** após instalar, o ícone na home do dispositivo é o ícone da marca Turni (não Flutter), em Android e iOS. Verificado por captura de tela anexada ao relatório de validação.
- **Não-regressão (gate):** smoke CA-17 da STORY-037 (publicar `rc.M+1` com a aba aberta no `rc.M` e ver o banner "Nova versão disponível" em ≤ 5 min, depois "Atualizar agora" carregando a nova versão sem hard-reload) continua passando em homolog **após** este épico. Sem isso, o épico não fecha.
- **Comportamental:** a ação "Instalar app" não aparece em modo standalone (já instalado) e não aparece em browsers que não suportem instalação (Firefox desktop, sem fallback). Coberto por teste unitário do controller (a ser entregue na STORY-042).
- **Decisões registradas:** IDR-020 (estratégia de instalação + fallback iOS + ícones) em `status: accepted`.

## Entregável visível no fim do épico

- [ ] Ação "Instalar app" visível em pontos definidos por IDR-020 (proposta: login, pré-cadastro profissional, pré-cadastro contratante, app shell — mesmos pontos da `AppVersionLabel` de STORY-037).
- [ ] No clique em Android/desktop Chromium: prompt nativo do navegador é disparado e, ao aceitar, o app é instalado.
- [ ] No clique em iOS Safari/Chrome: modal de instruções aparece com 2 passos; modal é fechável; tem `Semantics` de leitor de tela apropriado.
- [ ] Ação desaparece quando o app está em modo standalone (já instalado) — em todas as plataformas.
- [ ] Ícones do PWA substituídos pela identidade Turni nos 6 alvos: `Icon-192.png`, `Icon-512.png`, `Icon-maskable-192.png`, `Icon-maskable-512.png`, `apple-touch-icon.png` (180×180, **novo**), `favicon.png` (32×32, substituindo o atual de 16×16). Arquivos-fonte SVG versionados em `apps/webapp/web/icons/source/`.
- [ ] `index.html` ganha o pequeno script pré-Flutter que captura `beforeinstallprompt`, detecta iOS Safari e detecta `display-mode: standalone`, expondo um objeto consumido pelo Dart via `dart:js_interop`. O script é defensivo (try/catch silencioso) e **não toca service worker, Cache Storage nem fetch**.
- [ ] `manifest.json`: `start_url`, `display`, `theme_color`, `background_color`, `icons[]` continuam exatamente como hoje. Campos auxiliares opcionais (ex.: `categories`) ficam a critério do programador na STORY-041, com justificativa.
- [ ] IDR-020 registrada e aceita pelo PO após smokes.
- [ ] Suíte unitária do WebApp continua ≥ 80% (sem regressão); novo módulo de instalação (a ser criado pela STORY-042) ≥ 95% nas peças puras (controller, parser de estado de plataforma).
- [ ] Smoke CA-17 da STORY-037 passa em homolog **após** este épico (gate).

## Fora de escopo (explicitamente)

- **Notificações push** (Web Push / FCM / APNs). Próxima onda — está rascunhada em `roadmap/next-wave.md`. Instalar é pré-requisito do push, mas o push em si não entra aqui.
- **`start_url` específico do install** (deep link de "primeira abertura"). Continua `"/"`.
- **Splash screen customizada por iOS** (apple-touch-startup-image em N tamanhos). Fica para depois — entrega o apple-touch-icon agora; splash em iOS é um caminho próprio com N variantes, fora do orçamento desta onda.
- **Trocar a estratégia de service worker do Flutter** (Workbox/custom). STORY-008 CA-12 fixou o SW padrão como suficiente; STORY-037 manteve. Este épico **não toca o SW**.
- **Mudar microcopy do banner de auto-atualização** ("Nova versão disponível" / "Atualizar agora" / "Depois"). Microcopy do prompt de instalação é decidida em IDR-020, separada.
- **Estratégia A/B de quando mostrar o prompt** (engagement-driven). Mostra sempre que (a) instalável E (b) não em standalone E (c) usuário não dispensou neste ciclo — política simples, alinhada com STORY-037 ("Depois" não persiste).
- **Tornar o backoffice (admin) instalável.** Admin é Livewire, fora do escopo; sem objetivo de instalação na home.
- **Tornar a landing (`apps/landing`) instalável.** Site institucional, sem manifest; fora do escopo.

## Referências da especificação

- `docs/especificacao/non-functional.md` §"Compatibilidade" — RNF "PWA instalável como PWA no Android e iOS (suporte parcial iOS)" (linha 96).
- `apps/webapp/web/manifest.json` — manifest já existente, com `display: standalone`, `theme_color: #00A868`, `background_color: #F7F4EC`, ícones.
- `apps/webapp/web/index.html` — `<head>` já tem `apple-mobile-web-app-capable`, `apple-mobile-web-app-title`, `apple-touch-icon` e `theme-color`. Ponto de extensão para o script pré-Flutter da STORY-042.
- `docs/project-state/decisions/idr/IDR-017-auto-atualizacao-webapp-polling-skipwaiting-banner.md` — auto-update vigente, **invariante** para este épico.
- `docs/project-state/epics/EPIC-001-cadastro-e-aprovacao/stories/STORY-037-auto-atualizacao-webapp-e-versao-visivel-na-ui.md` — padrão de "módulo Dart com conditional import + interop web + widget no `MaterialApp.builder`". É o template a seguir.
- `docs/project-state/decisions/ddr/DDR-001-fundacao-do-design-system.md` — tokens (`brandGreen`, `accentLight/Dark`, `surfaceLight/Dark`), spacing, raios. Identidade visual do ícone usa `brandGreen` sobre superfície clara.
- `firebase.json` — headers de hosting (homolog + prod). **Invariante** quanto aos blocos do entry chain Flutter (`/index.html`, `/version.json`, `/main.dart.js`, `/flutter.js`, `/flutter_bootstrap.js`, `/flutter_service_worker.js`) e do glob `**/*.@(js|css|wasm)`.
- `apps/webapp/lib/core/app_update/` — padrão de implementação a replicar (`service_worker_bridge_*.dart` é o exemplo canônico do `conditional import`).
- `apps/webapp/lib/ds/tokens.dart`, `lib/ds/components/app_version_label.dart` — padrão visual a seguir; ponto de plugagem candidato na UI.

## Dependências

- **Bloqueia**: nada do EPIC-001 atual; nada do gate Pix/PIN (EPIC-003). Bloqueia funcionalidades futuras que dependam de PWA instalado (push notifications em WAVE-2026-02+).
- **Bloqueado por**: aprovação do PO no escopo deste épico e na IDR-020 (proposta na STORY-042).
- **Pré-requisitos de ambiente já satisfeitos**:
  - Manifest válido em `/manifest.json` (STORY-008 CA-11).
  - Service worker padrão do Flutter ativo em `/flutter_service_worker.js` (STORY-008 CA-12 + STORY-037).
  - HTTPS (Firebase Hosting).
  - `version.json` com `Cache-Control: no-cache` (IDR-002).
  - Entry chain do Flutter com `Cache-Control: no-cache` (IDR-017 emenda).

## Decisões transversais necessárias

- **IDR-020** — "Ação de instalar app no WebApp Flutter — `beforeinstallprompt` no Android/Chromium + instruções no iOS + identidade visual dos ícones." Cobre: gatilho da ação, pontos de exibição na UI, política de dispensa (não persiste — alinhado IDR-017), critério de "já instalado" (display-mode standalone + navigator.standalone iOS), microcopy do CTA e do modal iOS, formato e tamanhos dos ícones, arquivos-fonte versionados. **Proposta** pela STORY-042.

## Estórias

Esboço (detalhe em cada `stories/STORY-*.md`):

- **STORY-041 — Identidade visual: ícones do PWA com a marca Turni** (S, programador + designer leve). Substitui os 4 PNGs do `web/icons/` por ícones com a marca Turni; adiciona `apple-touch-icon.png` 180×180 e atualiza `favicon.png`; versiona o SVG-fonte; atualiza `index.html` quanto ao link do apple-touch-icon; **não toca** `firebase.json`, service worker ou auto-update. Validação: visual em Android home e iOS home.
- **STORY-042 — Ação "Instalar app" com prompt nativo + fallback iOS** (M, programador). Cria o módulo de instalação seguindo o padrão de `lib/core/app_update/` (conditional import + stub VM + impl web); adiciona o script pré-Flutter em `index.html` que captura `beforeinstallprompt` e expõe a ponte JS para o Dart; cria o card "Instalar app" plugado nos pontos definidos por IDR-020; implementa o modal `IosInstallInstructions` com 2 passos. Política de dispensa não-persistente. Testes unitários ≥ 95% nas peças puras; E2E em Chromium real (Playwright/integration_test) cobrindo o caminho "ação visível → clique → prompt disparado (com mock de evento)". Smoke iOS validado em chat. Produz IDR-020.

## Critérios de validação do épico (validation/report.md)

Quando o validador (após DoD das duas estórias) for emitir o `validation/report.md`, ele verifica:

1. Estado dos ícones: `Icon-{192,512}.png`, `Icon-maskable-{192,512}.png`, `apple-touch-icon.png`, `favicon.png` presentes em `apps/webapp/web/` e em `apps/webapp/build/web/` após `make webapp-build`; nenhum é o ícone padrão do Flutter (verificar hash != hash do bundled flutter icon).
2. `index.html` referencia `apple-touch-icon` corretamente e o script de instalação é defensivo (try/catch, sem deps externos).
3. `manifest.json` `icons[]` continua válido (todos os arquivos referenciados existem e abrem como PNG).
4. O módulo de instalação (path definido pela STORY-042) segue o mesmo padrão de `lib/core/app_update/` (conditional import; stub no-op para VM; interop web isolado em `*_web.dart`). 0 import direto de `package:web` ou `dart:js_interop` fora de `*_web.dart`.
5. `flutter analyze` 0 issues no código novo; cobertura ≥ 95% em controller/detector/parser; suíte ≥ 80% no total.
6. **Não-regressão STORY-037**: roda local `make e2e-webapp` ou suíte equivalente; em homolog após release, roda smoke CA-17 (publicar `rc.M+1` com aba aberta em `rc.M`, ver banner "Nova versão disponível" em ≤ 5 min, "Atualizar agora" carrega). Sem isso, o épico **não fecha**.
7. Smoke mobile do EPIC-008: em Android Chrome, ação "Instalar app" → prompt nativo → instalar → ícone Turni na home → abrir app standalone. Em iOS Safari, ação → modal de instruções → seguir passos → ícone Turni na home → abrir standalone. Assinado em chat pelo PO.
8. IDR-020 em `status: accepted` com OK do PO em chat.
9. `firebase.json` **não alterou** as regras do entry chain Flutter nem do glob `**/*.@(js|css|wasm)`. Diff visível em PR.

## Riscos conhecidos

- **iOS sem prompt programático.** WebKit ignora `beforeinstallprompt`. Mitigação: fallback é um modal de instruções claras com `Semantics` — é o estado da arte na plataforma. O RNF (`non-functional.md` linha 96) explicitamente diz "suporte parcial iOS". Não é regressão; é a realidade da plataforma.
- **`beforeinstallprompt` dispara antes do Flutter estar pronto.** O script no `index.html` precisa rodar **antes** do `flutter_bootstrap.js` para conseguir `event.preventDefault()` e guardar o `BeforeInstallPromptEvent`. Mitigação: o script é inline e roda no `<head>` antes do `<script src="flutter_bootstrap.js" async>`.
- **Quebrar auto-update por adicionar headers errados no `firebase.json`.** Mitigação: o épico **proíbe** mexer nos blocos do entry chain Flutter. Estratégia recomendada: deixar os ícones cair no default do Firebase Hosting e revalidar via `version.json` cycle (a próxima "Atualizar agora" limpa caches e re-baixa tudo).
- **Cache do ícone antigo em PWAs já instaladas.** Após trocar `apple-touch-icon`, dispositivos iOS que já instalaram a PWA continuam vendo o ícone antigo (iOS cacheia agressivamente o icon na home). É comportamento da plataforma; não há fix sem desinstalar/reinstalar. Documentar no smoke da STORY-041.
- **Browsers sem suporte (Firefox desktop).** Sem `beforeinstallprompt` e sem instruções específicas. Mitigação: ação simplesmente não aparece. Não é regressão.
- **Colisão com `UpdateBanner` (STORY-037).** O banner de auto-atualização vive no topo da tela; a ação de instalar vive em ponto definido por IDR-020. Risco: se IDR-020 escolher overlay/topo, conflita. Mitigação: IDR-020 já recomenda card no rodapé das telas onde já mora a `AppVersionLabel`.

## Histórico

- 2026-05-31 — épico criado em rascunho pelo PO (sessão Cowork) a partir do pedido de Alexandro: "ação para o webapp se instalar na tela inicial, fallback iOS, ícone simples, não quebrar o update automático".
- 2026-06-01 — renomeação preventiva das duas stories: **STORY-038 → STORY-041** (ícones) e **STORY-039 → STORY-042** (ação de instalar). Motivo: colisão de IDs com EPIC-007 STORY-038 (`integration_test`) e STORY-039 (Patrol), criadas em 2026-05-31 sem registro no `index.json` (mesma classe de drift que levou ao rename de STORY-034/035/036 → STORY-038/039/040 do EPIC-007 na abertura da SPRINT-2026-W26). Frontmatters atualizados com `renamed_from`; referências cruzadas em IDR-020 e neste epic.md propagadas. Reforço da convenção: verificar `index.json` antes de escolher número de story.
