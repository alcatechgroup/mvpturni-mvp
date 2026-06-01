---
story_id: STORY-041
slug: identidade-visual-icones-pwa-turni
title: Identidade visual — ícones do PWA com a marca Turni (substitui logo padrão do Flutter)
epic_id: EPIC-008
sprint_id: SPRINT-2026-W27
type: implementation
target_role: programador
requires_design: false  # designer só revisa a SVG-fonte; não há SCREEN dedicada
design_screen_id: null
status: ready  # impl local concluída 2026-06-01; vira `done` após CA-13/14/15 + sign-off do PO em homolog
owner_agent: programador
created_at: 2026-05-31
updated_at: 2026-06-01  # impl local dos ícones (assets+pipeline+index.html+manifest+README)
estimated_session_size: S
produces_idr: null  # IDR-020 (proposta pela STORY-042) cobre formato/tamanhos
renamed_from: STORY-038  # 2026-06-01 — colisão com EPIC-007 STORY-038 (integration_test)
---

# STORY-041 — Ícones do PWA com a marca Turni

> **Para o agente que vai executar:** leia esta estória inteira antes de começar. Pequena, mas sensível: ícones errados quebram a "cara" do app na home do dispositivo, e mudar `index.html` exige cuidado porque o auto-update do WebApp (STORY-037 / IDR-017) depende do entry chain servindo `no-cache`. Esta story **não** altera headers do `firebase.json` nem o service worker — só conteúdo de imagens e 1 atributo de `<link>`.

## Contexto (por que esta estória existe)

Os ícones de PWA hoje em `apps/webapp/web/icons/` são o **logo padrão do Flutter** — foram deixados pelo `flutter create` em STORY-008 CA-11 e nunca substituídos. Quem instala o app na tela inicial vê um quadrado azul com o "F" do Flutter. Para a marca Turni, isso é ruim: o profissional que vai usar o app como ferramenta de trabalho não reconhece a identidade do produto na home do celular, no app drawer ou na splash de instalação.

O `manifest.json` já está estruturalmente correto: declara os 4 ícones nas chaves esperadas (192, 512, maskable 192, maskable 512), com `theme_color: #00A868` (brandGreen do DDR-001) e `background_color: #F7F4EC` (surfacePageLight). Só falta o **conteúdo** dos PNGs ser a marca Turni, mais a adição do `apple-touch-icon` 180×180 que o iOS exige para mostrar um ícone bonito na home (sem isso, iOS gera um screenshot da primeira tela do app, que fica feio e variável).

O `favicon.png` atual é 16×16 — pequeno e sem versão retina. Aproveitamos para entregar um favicon decente em 32×32.

Esta story entrega os arquivos. A **ação de instalar** (botão + fluxo iOS) fica em STORY-042.

- Épico: `docs/project-state/epics/EPIC-008-pwa-instalavel/epic.md`
- Documentos canônicos a ler ANTES de codificar:
  - `apps/webapp/web/manifest.json` (referências atuais dos 4 ícones; **não vamos mudar paths**, só conteúdo).
  - `apps/webapp/web/index.html` (`<link rel="apple-touch-icon">` e `<link rel="icon">` — vamos atualizar para apontar para o novo apple-touch-icon de 180×180).
  - `docs/project-state/decisions/ddr/DDR-001-fundacao-do-design-system.md` (paleta — `brandGreen #00A868`, `surfacePageLight #F7F4EC`).
  - `docs/project-state/decisions/idr/IDR-017-auto-atualizacao-webapp-polling-skipwaiting-banner.md` + emenda — entender por que **não pode** mexer no `firebase.json` no entry chain.
  - `firebase.json` (homolog + prod) — **só leitura**; entender o glob `**/*.@(js|css|wasm)` e os blocos do entry chain Flutter (`no-cache`). Confirmar que PNGs caem no default e que isso é OK (troca de identidade é evento raro e o ciclo de "Atualizar agora" da STORY-037 limpa Cache Storage).
  - IDR-020 (proposta pela STORY-042) — define dimensões e safe zone do maskable (80% do diâmetro). Esta story consome o que IDR-020 fixar.

## O quê (objetivo desta estória)

Entregar, no diretório `apps/webapp/web/`:

### 1. Arquivos-fonte SVG versionados

- `apps/webapp/web/icons/source/icon.svg` — ícone "cheio" (sem safe zone). Composição mínima decidida em IDR-020 — recomendação para ela: monograma "T" branco sobre fundo `brandGreen #00A868` arredondado (squircle/superellipse aproximada por path SVG), com altura ~62% do canvas. O arquivo é o source-of-truth; os PNGs são gerados a partir dele.
- `apps/webapp/web/icons/source/icon-maskable.svg` — versão **maskable**: o "T" e o fundo são mantidos, mas o motivo ocupa apenas o **safe zone interno de 80%** do canvas (12.5% de respiro radial). O fundo `brandGreen` cobre 100% (o cropper da launcher do Android vai recortar bordas em formato circular/squircle sem comer o "T").
- `apps/webapp/web/icons/source/favicon.svg` — versão simplificada para tamanhos pequenos (16/32 px): "T" branco sobre fundo `brandGreen`, sem detalhes finos que somem em 16 px.

### 2. PNGs gerados a partir dos SVGs

- `apps/webapp/web/icons/Icon-192.png` (192×192, fundo `#00A868`, "T" branco; substitui o atual).
- `apps/webapp/web/icons/Icon-512.png` (512×512; substitui o atual).
- `apps/webapp/web/icons/Icon-maskable-192.png` (192×192, com safe zone de 80%; substitui).
- `apps/webapp/web/icons/Icon-maskable-512.png` (512×512, com safe zone de 80%; substitui).
- `apps/webapp/web/icons/apple-touch-icon.png` (180×180, **novo**) — mesmo desenho do `Icon-192` adaptado para 180 px. iOS Safari procura esse arquivo nominalmente quando o link `apple-touch-icon` não casa exatamente; manter a convenção.
- `apps/webapp/web/favicon.png` (32×32, **substitui o atual de 16×16**).

### 3. Atualizações em `web/index.html`

- `<link rel="apple-touch-icon" href="icons/Icon-192.png">` → trocar para `<link rel="apple-touch-icon" sizes="180x180" href="icons/apple-touch-icon.png">`.
- `<link rel="icon" type="image/png" href="favicon.png"/>` → manter; opcionalmente adicionar `sizes="32x32"`.
- **Não tocar** em mais nada do `<head>` ou do `<body>`. O `<script>` pré-Flutter da feature de instalação é responsabilidade da STORY-042 (esta story só toca os ícones).

### 4. `manifest.json` revisitado

- `start_url`, `display`, `theme_color`, `background_color`: **intocados**.
- `icons[]`: as 4 entradas continuam apontando para os mesmos paths (`icons/Icon-192.png` etc.). Apenas o conteúdo dos PNGs muda.
- Adições **opcionais** justificáveis: `"id": "/"` (estabilidade do app no Chrome), `"categories": ["business","productivity"]`. Se o agente julgar que adiciona valor, justificar no PR. Se não, deixar como está.
- **Não** adicionar `screenshots[]` agora (são variantes a manter; fora de escopo).

### 5. Pipeline de geração (reprodutibilidade)

- Criar `apps/webapp/scripts/generate-icons.sh` (ou `.mjs`/.py se o agente preferir) que gera os PNGs a partir dos SVGs em `web/icons/source/` usando ferramenta open-source (`librsvg`, `resvg-js`, `sharp`, `cairosvg` — escolha do agente). O script **não** é parte do build do app; é uma utility de manutenção. Documentar no `apps/webapp/README.md` em uma seção curta "Regenerar ícones".

## Por quê (valor para o usuário)

**Direto para profissional e contratante:** ao instalar o app na home, vê a marca Turni — não o logo do Flutter. Isso ajuda no reconhecimento imediato ("é o app de trabalho") e diferencia do conjunto de PWAs anônimas no drawer. Em contexto de uso real (profissional checando turnos antes de sair de casa, em pé na rua), 0,5 s a menos de fricção para abrir o app certo importa.

**Indireto para o time:** a fonte (SVGs versionados) torna mudanças futuras triviais. Hoje, se quiséssemos mudar o ícone, não havia source — só os PNGs que vieram do `flutter create`. Esta story paga essa dívida.

## Critérios de aceite

### Arquivos

- [ ] **CA-1 (SVG-fonte versionado):** existem `apps/webapp/web/icons/source/icon.svg`, `icon-maskable.svg`, `favicon.svg` no repo. Cada um é XML válido (`xmllint --noout` passa). Cada um abre em browser e exibe o desenho descrito (T branco sobre fundo brandGreen).
- [ ] **CA-2 (PNGs substituídos):** `Icon-192.png`, `Icon-512.png`, `Icon-maskable-192.png`, `Icon-maskable-512.png` substituídos. Hashes (sha256) diferem dos arquivos atuais (cuja origem é o `flutter create`). Dimensões verificadas com `file` ou `identify` — tudo bate com o nome do arquivo.
- [ ] **CA-3 (apple-touch-icon):** `apple-touch-icon.png` (180×180) criado em `apps/webapp/web/icons/`.
- [ ] **CA-4 (favicon):** `favicon.png` (32×32) substitui o atual (16×16). Visualmente legível em 16 px (o "T" continua identificável; sem detalhe fino que vire pixel-mush).

### index.html

- [ ] **CA-5:** `<link rel="apple-touch-icon">` aponta para `icons/apple-touch-icon.png` com `sizes="180x180"`. Demais `<link>` e `<meta>` do `<head>` permanecem como estão (em particular: `apple-mobile-web-app-capable`, `apple-mobile-web-app-title`, `theme-color`).
- [ ] **CA-6:** `<script src="flutter_bootstrap.js" async>` permanece intocado; nenhum outro `<script>` é adicionado nesta story (cabe à STORY-042).

### manifest.json

- [ ] **CA-7:** `start_url`, `display`, `theme_color`, `background_color` permanecem **exatamente** como estão hoje. `icons[]` aponta para os mesmos paths.
- [ ] **CA-8:** Quando o app sobe (`make webapp-build` + servidor estático local ou Firebase emulator), `/manifest.json`, `/icons/Icon-192.png`, `/icons/Icon-512.png`, `/icons/Icon-maskable-192.png`, `/icons/Icon-maskable-512.png` e `/icons/apple-touch-icon.png` são 200 com `Content-Type: image/png` (e `application/manifest+json` para o manifest).

### Pipeline de geração

- [ ] **CA-9:** `apps/webapp/scripts/generate-icons.*` existe, roda em ambiente local com o toolchain documentado, e regera todos os PNGs a partir dos SVGs. Documentado em `apps/webapp/README.md` com 1 comando.

### Não-regressão

- [ ] **CA-10:** `make e2e-webapp` (ou suíte equivalente local) continua verde — esta story só troca conteúdo de imagens e 1 atributo de `<link>`; testes de DOM/Flutter não dependem disso.
- [ ] **CA-11:** Suíte unitária do webapp (`flutter test`) continua verde, cobertura ≥ 80% (esta story não adiciona código Dart).
- [ ] **CA-12:** `firebase.json` **não foi alterado**. Diff no PR confirma.
- [ ] **CA-13:** Smoke CA-17 da STORY-037 continua passando em homolog após o deploy desta story — publicar release `rc.M+1` com aba aberta em `rc.M`, banner "Nova versão disponível" aparece em ≤ 5 min, "Atualizar agora" carrega o `rc.M+1` sem hard-reload. Validado em chat pelo PO antes do épico fechar.

### Smoke visual

- [ ] **CA-14:** Em Android Chrome, instalar a PWA (após STORY-042 estar no ar, ou via menu "Adicionar à Tela de Início" do Chrome) mostra o ícone Turni — não Flutter — na home e no drawer. Captura de tela anexada em chat.
- [ ] **CA-15:** Em iOS Safari, instalar a PWA via "Compartilhar → Adicionar à Tela de Início" mostra o ícone Turni na home. Captura de tela anexada em chat.

## Fora de escopo

- Adicionar splash image customizada para iOS (apple-touch-startup-image em N tamanhos) — fora; iOS gera splash do `background_color` + `apple-touch-icon` por default, aceitável para MVP.
- Variantes de ícone por tema (claro/escuro). PWA não tem suporte estável a isso ainda; deixar para depois.
- Mudar a paleta da marca. `brandGreen #00A868` está em DDR-001; esta story consome, não decide.
- Tocar `firebase.json`. Vetado.
- Refatorar `lib/ds/` para introduzir um widget "logo Turni" Flutter. Fora.

## Padrões de qualidade exigidos

`docs/skills/po/references/quality-standards.md`. Em particular:

- **Reversibilidade**: o SVG-fonte é o source-of-truth; reverter a identidade visual é regerar com SVGs anteriores.
- **Documentação**: pipeline de geração documentado no README do webapp.
- **Sem código não testado em produção**: esta story não adiciona código Dart; os testes existentes continuam sendo a barreira.

## Dependências

- **Bloqueada por:** **IDR-020 com a especificação dos ícones** (tamanhos, safe zone do maskable, posição do "T"). STORY-042 propõe IDR-020. Sequência sugerida: STORY-042 redige IDR-020 primeiro com a parte de ícones; STORY-041 consome em paralelo.
- **Bloqueia:** smoke visual da STORY-042 (ela depende dos ícones para validar o fluxo "instalou → ícone Turni na home").

## Decisões já tomadas (não as reabra)

- Paleta DDR-001 (`brandGreen #00A868`, `surfacePageLight #F7F4EC`).
- `manifest.json` `theme_color: #00A868`, `background_color: #F7F4EC`, `display: standalone`.
- Suporte parcial iOS é aceitável (RNF `non-functional.md` linha 96).
- Não tocar entry chain Flutter no `firebase.json` (IDR-017).

## Liberdade técnica do agente

Você decide:

- Ferramenta de geração SVG→PNG (`sharp`, `resvg-js`, `librsvg`, ImageMagick, `cairosvg` — o que estiver mais acessível no toolchain do webapp).
- Detalhes finos do "T" (proporção, terminação dos braços, kerning interno) desde que dentro do safe zone do maskable.
- Cor exata do branco do "T" (`#FFFFFF` puro ou `#FBF8F0` para casar com surfacePageLight — preferência por puro para máximo contraste).
- Como nomear ícones auxiliares se quiser entregar (`favicon-16x16.png`, `favicon-32x32.png` etc.). Manter os paths existentes no `manifest.json`.

Você NÃO decide:

- Mudar paths existentes do `manifest.json`. Eles são consumidos pelo manifest e por (futuros) caches de browsers — mudar paths cria 404s em PWAs já instaladas.
- Mexer no `firebase.json`. Vetado pelo épico.
- Mudar o `manifest.json` em `theme_color`, `background_color`, `display`, `start_url`. Vetado.
- Adicionar dependências Dart/Flutter (esta story é só assets).
- Mexer no `<script>` do Flutter no `index.html`.

## Definição de Pronto (DoD)

- [ ] CA-1 a CA-15 atendidos com evidência.
- [ ] PR mergeado; pré-push hook verde.
- [ ] Capturas de tela do ícone na home Android e iOS anexadas ao relatório da STORY (ou linkadas em chat).
- [ ] Smoke CA-13 (não-regressão STORY-037) atestado em chat pelo PO em homolog.
- [ ] `index.json` atualizado: `STORY-041 status: done`.
- [ ] README do WebApp tem 1 parágrafo "Regenerar ícones".

## Notas do agente (preenchido durante/após execução)

> **Status:** implementação local concluída em 2026-06-01 (assets + pipeline + index.html + manifest + README). Story permanece `ready` (não `done`) porque CA-13 (não-regressão STORY-037 em homolog), CA-14/CA-15 (smoke visual Android/iOS) e o sign-off do PO só fecham após deploy `rc.M+1` em homolog — ver "Pendências para fechar".

### Decisões tomadas
- **Ferramenta SVG→PNG: `sharp`** (libvips). O toolchain do host não tinha `rsvg-convert`/`cairosvg`/ImageMagick/Inkscape; só `node`/`npm`. `sharp` é a opção mais acessível num toolchain Node (o webapp já usa Playwright via npm) — adicionada como `devDependency` e exposta em `npm run icons`. Render com `density: 384` antes do `resize` para bordas limpas no favicon de 32 px.
- **Desenho do "T":** monograma em path único (cantos retos, bloco) — crisp em 16 px, sem detalhe fino que vire pixel-mush. Branco puro `#FFFFFF` (máximo contraste, conforme liberdade da story) sobre `brandGreen #00A868`.
- **Geometria (viewBox 512):** full `icon.svg` — bg squircle (rounded rect rx=114, ~22%), "T" de altura 312px (~61%). `icon-maskable.svg` — bg `#00A868` cobrindo 100% (sem cantos), "T" reduzido (x150–363, y128–384) inteiramente dentro do círculo de raio 205 (safe zone 80%): canto mais distante a ~166px do centro < 205px. `favicon.svg` — "T" mais encorpado (bar h=80, stem w=96) para legibilidade em 16 px.
- **`manifest.json`:** adicionados os opcionais `"id": "/"` (estabilidade da identidade do PWA no Chrome) e `"categories": ["business","productivity"]`. Campos vetados (`start_url`, `display`, `theme_color`, `background_color`) e os paths de `icons[]` **intocados** (CA-7).
- **`index.html`:** `apple-touch-icon` agora aponta para `icons/apple-touch-icon.png` com `sizes="180x180"`; `<link rel="icon">` ganhou `sizes="32x32"`. `flutter_bootstrap.js` e todo o resto do `<head>`/`<body>` intocados (CA-6).

### Descobertas
- Os PNGs antigos (datados 31 mai 12:29) já não eram o "F" azul do Flutter literal, mas placeholders — substituídos de qualquer forma; hashes mudaram (ver Evidência).
- `flutter build web` copia `web/icons/source/*.svg` para `build/web/icons/source/` — os SVGs-fonte ficam servidos publicamente (poucos KB, inofensivo). Não vetado pela story; deixei como está.
- O pre-push hook só roda `dart format` em `apps/webapp/lib/` (não em `test/`). `test/login_screen_test.dart` está desformatado **no HEAD** (pré-existente, fora desta story) — não bloqueia o push e não foi tocado.

### Bloqueios encontrados
- Nenhum bloqueio técnico. CA-13/14/15 dependem de deploy em homolog + dispositivos reais (Android/iOS) — fora do alcance de uma sessão local; ficam para o ciclo de release + validação do PO.

### Evidência
- **Hashes sha256 (antes → depois)** dos PNGs (CA-2):
  - `Icon-192.png`: `3dce9907…` → `dc05f1f8…`
  - `Icon-512.png`: `baccb205…` → `bb38e0b7…`
  - `Icon-maskable-192.png`: `d2c842e2…` → `36653cce…`
  - `Icon-maskable-512.png`: `6aee06cd…` → `29844969…`
  - `favicon.png` (16×16 → **32×32**): `7ab2525f…` → `e9313982…`
  - `apple-touch-icon.png` (180×180, **novo**): `4de0a1d7…`
- **Dimensões** verificadas com `file`: todas batem com o nome (CA-2/3/4).
- **CA-1:** `xmllint --noout` passa nos 3 SVGs-fonte.
- **CA-8:** `flutter build web` ok; servindo `build/web` localmente, `/manifest.json` e os 6 PNGs retornam `HTTP 200` com `Content-Type: image/png` (manifest `application/json` no server local; o mapeamento `application/manifest+json` é do Firebase Hosting e não muda nesta story — nome/path do manifest preservados).
- **CA-9:** `apps/webapp/scripts/generate-icons.mjs` regenera os 6 PNGs a partir dos SVGs (`npm run icons`); documentado no README ("Regenerar ícones").
- **CA-11:** `flutter test` — **121/121 passaram** (story não adiciona Dart; cobertura inalterada).
- **CA-12:** `firebase.json` **não** aparece no diff. Confirmado.
- **`flutter analyze`:** 2 `info` pré-existentes (`curly_braces_in_flow_control_structures` em `pre_cadastro_*_screen.dart`) — não tocados por esta story.

### Pendências para fechar (homolog + PO)
- [ ] CA-13 — após deploy `rc.M+1`, smoke de não-regressão da STORY-037 (banner "Nova versão disponível" ≤ 5 min, "Atualizar agora" sem hard-reload). PO atesta em chat.
- [ ] CA-14 — Android Chrome: instalar PWA mostra o ícone Turni na home/drawer. Captura anexada.
- [ ] CA-15 — iOS Safari: "Adicionar à Tela de Início" mostra o ícone Turni. Captura anexada.
- [ ] Flip `index.json` `STORY-041 status: done` após o sign-off acima.
