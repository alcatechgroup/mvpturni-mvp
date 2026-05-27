---
story_id: STORY-010
slug: ddr-001-fundacao-design-system
title: DDR-001 — Fundação do Design System (tokens base, tipografia, paleta inicial)
epic_id: EPIC-000
sprint_id: null
type: implementation
target_role: designer
requires_design: false
status: done
owner_agent: claude-opus-designer-2026-05-27
created_at: 2026-05-26
updated_at: 2026-05-27
estimated_session_size: M
---

# STORY-010 — DDR-001: Fundação do Design System (tokens, tipografia, paleta)

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Ela contém tudo o que você precisa. Se algo estiver ambíguo, registre a dúvida na seção "Notas do agente" no final e pause em vez de adivinhar.

## Contexto (por que esta estória existe)

EPIC-000 entrega "hello world" em homologação para WebApp (STORY-008) e Backoffice (STORY-009). Sem **fundação do Design System** (DS), cada uma dessas páginas seria um patchwork de decisões visuais ad-hoc — e cada feature do EPIC-001 em diante herda essa entropia. DDR-001 nasce no EPIC-000 propositalmente: estabelecer **tokens base**, **escala tipográfica**, **paleta inicial**, **escala de espaçamento** e **convenção de uso** antes do produto começar a ter UI séria. Isso evita o cenário em que telas de cadastro do EPIC-001 já são feitas em cima de improviso visual e depois precisam ser refatoradas em massa.

A estória é **horizontal por natureza** (`type: implementation`, `target_role: designer`, mas o "produto" entregue é fundação reusável). Justificativa de horizontalidade: Design System é mecanismo, não fluxo de usuário. Destrava STORY-008 (página de boas-vindas precisa de tokens base coerentes com a landing) e STORY-009 (idem nível mínimo) e — mais importante — todas as estórias de UI a partir do EPIC-001.

O Designer entra **em paralelo aos spikes do Arquiteto** (STORY-001 a STORY-005). DDR-001 não depende de stack escolhida — depende de visão de produto, personas, identidade da landing e princípios de design. Pode rodar simultaneamente desde o início da sprint.

- Épico: `docs/project-state/epics/EPIC-000-foundation/epic.md`
- Documentos canônicos a ler ANTES de deliberar:
  - `docs/prototipo/index.html` (landing — identidade visual de referência: cores, tipografia, tom)
  - `docs/prototipo/app.html` (PWA — referência de como o protótipo materializou a identidade na aplicação)
  - `docs/project-state/product/vision.md` (visão de produto)
  - `docs/project-state/product/personas.md` (personas — para quem o DS precisa funcionar)
  - `docs/skills/designer/SKILL.md` (skill que você está executando)
  - `docs/skills/designer/references/design-system-craft.md` (ofício de construir DS)
  - `docs/skills/designer/references/ddr-lifecycle.md` (formato e ciclo de vida de DDR)
  - `docs/skills/designer/references/accessibility-basics.md` (contraste, tamanhos mínimos)
  - `docs/skills/designer/references/mobile-desktop-parity.md` (DS funciona em ambos)
  - `docs/skills/designer/references/design-principles.md`
  - `docs/skills/designer/templates/ddr.md`
  - `docs/skills/designer/templates/design-system.md`
  - `docs/project-state/decisions/pdr/PDR-003-duas-interfaces-webapp-e-backoffice.md` (DS atende WebApp mobile-first **e** Backoffice desktop-first)
  - `docs/especificacao/non-functional.md` (acessibilidade WCAG AA, tamanho mínimo de texto)

## O quê (objetivo desta estória)

Deliberar, registrar e entregar:

1. **DDR-001 — Fundação do Design System** em estado `proposed`, escrito conforme `docs/skills/designer/templates/ddr.md`, decidindo: filosofia do DS (mobile-first com paridade desktop), escala tipográfica (família, pesos, tamanhos canônicos), paleta de cores (primária, secundárias, neutras, semânticas — sucesso/atenção/erro/informação), escala de espaçamento (sistema 4pt ou 8pt, à escolha justificada), escala de raio de borda, escala de elevação/sombra, regras de uso (quando aplicar cada token).
2. **Documentos vivos do DS** em `docs/project-state/design/system/`:
   - `tokens.md` — todos os tokens (cores, tipografia, espaçamento, raio, elevação) em formato consumível tanto por humano quanto por código (estrutura à escolha do Designer — Markdown com seções claras, ou tabela, ou referência a JSON canônico que o Programador implementa via IDR).
   - `voice-and-tone.md` — princípios de microcopy em pt-BR coerentes com a identidade do Turni.
3. **Screen spec da página de boas-vindas do WebApp** (consumida por STORY-008) em `docs/project-state/design/screens/STORY-008-hello-world-webapp.md`, conforme `docs/skills/designer/templates/screen-spec.md`, em `status: ready`.

## Por quê (valor para o usuário)

Para **profissional** e **contratante**: DS coerente significa que **toda tela do produto se parece com Turni** — sinal de profissionalismo, de cuidado, de produto que respeita quem usa. Acessibilidade (contraste AA, tamanhos mínimos) é parte da promessa para quem usa em pé na rua (profissional fazendo check-in) ou em jornada longa (admin operando o backoffice).

Para o **time**: cada estória de UI a partir do EPIC-001 herda fundação testada — não inventa visual a cada commit. Reduz tempo de design por feature e reduz arbitrariedade. PDR-003 cobra DS que serve **as duas interfaces** sem virar bagunça paralela.

## Critérios de aceite

### DDR-001

- [ ] **CA-1:** Existe `docs/project-state/decisions/ddr/DDR-001-fundacao-do-design-system.md` em `status: proposed`, escrito conforme `docs/skills/designer/templates/ddr.md` e respeitando o ciclo de vida em `docs/skills/designer/references/ddr-lifecycle.md`.
- [ ] **CA-2:** A DDR avalia no mínimo 2 abordagens reais para tokens (ex: sistema 4pt vs 8pt; paleta enxuta vs expandida) com trade-offs explícitos, e decide com justificativa coerente com a identidade do protótipo e os princípios em `design-principles.md`.
- [ ] **CA-3:** A DDR é explícita sobre **escopo transversal** (`scope: transversal` no frontmatter) e lista no campo `affects_screens` que afeta todas as telas a partir desta data — incluindo a página de boas-vindas de STORY-008 e a página identificadora de STORY-009.
- [ ] **CA-4:** A DDR define **critérios para revisitar** (gatilhos concretos para reabrir/superseder), em linha com `ddr-lifecycle.md`.

### Tokens e DS vivo

- [ ] **CA-5:** `docs/project-state/design/system/tokens.md` lista, em formato consumível:
  - (a) **paleta de cores** — primária, secundárias (se aplicável), neutras (escala de cinza), semânticas (sucesso, atenção, erro, informação), com nome canônico para cada cor e valor hex/hsl;
  - (b) **escala tipográfica** — família(s) de fonte (sistema ou fonte específica acessível por CDN/self-host), pesos disponíveis, tamanhos canônicos (display, h1, h2, h3, body, small, caption) com line-height correspondente;
  - (c) **escala de espaçamento** — sistema (4pt/8pt) com escala de tokens (xs, sm, md, lg, xl, etc — nomes à escolha do Designer);
  - (d) **escala de raio de borda** — tokens para sutil, médio, forte, total (pill);
  - (e) **escala de elevação/sombra** — tokens para flat, soft, raised, modal;
  - (f) **regras de uso** — exemplos curtos de "quando usar cada token" (ex: "primária só em CTA primário e navegação ativa"; "neutra-90 só em texto secundário sobre fundo claro").
- [ ] **CA-6:** Cada par foreground/background do DS atende **contraste WCAG 2.1 AA** (4.5:1 para texto normal, 3:1 para texto grande e UI) — evidência em forma de tabela de contraste no `tokens.md` ou anexa.
- [ ] **CA-7:** Tamanhos mínimos de texto respeitam `non-functional.md`: 14px em mobile, 13px em desktop. Tokens menores existem para uso restrito (legend, helper) — declarados como exceção.
- [ ] **CA-8:** DS é **mobile-first** com **paridade desktop** (`mobile-desktop-parity.md`) — tokens funcionam em ambas as interfaces sem precisar refazer paleta.

### Voice and tone

- [ ] **CA-9:** `docs/project-state/design/system/voice-and-tone.md` documenta princípios de microcopy do Turni em pt-BR: tom (cordial, direto, sem jargão técnico), pessoa (2ª do plural? 3ª? — à escolha justificada), exemplos curtos de "como dizer" vs "como não dizer" para mensagens de erro, confirmação, vazio, sucesso.

### Screen spec da página de boas-vindas do WebApp

- [ ] **CA-10:** Existe `docs/project-state/design/screens/STORY-008-hello-world-webapp.md` em `status: ready`, escrito conforme `docs/skills/designer/templates/screen-spec.md`, descrevendo: layout mobile e fallback desktop, tokens consumidos, microcopy completo (título, subtítulo, link de health-check), estados (carregando, erro genérico), comportamento de acessibilidade (foco, ordem de leitura). Conteúdo coerente com identidade do protótipo (`docs/prototipo/index.html`).
- [ ] **CA-11:** O `index.json` é atualizado com entrada em `design.screens[]` referenciando esta tela (`id: SCREEN-STORY-008-hello-world-webapp`, `story: STORY-008`, `status: ready`, viewports `["mobile", "desktop"]`), atendendo invariantes 9, 10 e 12 de `indexing.md`.
- [ ] **CA-12:** O `index.json` ganha `design.system.tokens`, `design.system.voice_and_tone` e (se criados) `design.system.components`, `design.system.patterns` apontando para os arquivos criados.

### Transversais

- [ ] **CA-13:** `index.json` recebe DDR-001 em `decisions.ddr[]` em `status: proposed`, `decided_by: "designer"`, `scope: "transversal"`. **Aprovação humana** explícita do Alexandro registrada (`approved_by`) é pré-condição para `status: accepted` (invariante 11 de `indexing.md`).
- [ ] **CA-14:** O Designer faz **sync curto com o Programador** que vai executar STORY-008 antes de fechar o screen spec (`designer/references/collaboration-with-developer.md`). Sync registrado em "Notas do agente".

## Fora de escopo

- Implementar tokens em código (CSS variables, biblioteca, etc) — decisão de IDR do Programador quando STORY-008 / STORY-009 consumirem.
- Sistema completo de componentes (botão, input, card, modal) — fica para EPIC-001 / EPIC-002 conforme as telas exigirem; aqui só criamos `components.md` como ponteiro vazio se ainda não houver nada para listar.
- Tema escuro — fora do MVP.
- Internacionalização — fora do MVP (pt-BR apenas).
- Screen spec do Backoffice — STORY-009 não tem `requires_design: true`; o Designer pode opcionalmente revisar, mas não há spec exigido.
- Tokens animados (transições, easing) — fora desta primeira fundação; entra quando a primeira tela exigir.

## Padrões de qualidade exigidos

Esta estória é entregue pelo **Designer** (`target_role: designer`), portanto adapta `docs/skills/po/references/quality-standards.md` com as seguintes nuances:

- **Cobertura unitária / E2E:** N/A — não produz código de produção. Quando o Programador implementar os tokens em código (STORY-008 ou IDR), a cobertura cai sobre **aquele código**.
- **Rigor aplicável:** opções reais avaliadas em DDR-001; contraste verificado contra WCAG 2.1 AA com tabela ou ferramenta de verificação; coerência com identidade do protótipo; aderência ao template de DDR; documentação consumível por humano e código.
- **Aprovação humana obrigatória** para DDR transitar de `proposed` → `accepted` (`ddr-lifecycle.md` + invariante 11 de `indexing.md`).
- **Screen spec da página de boas-vindas em `status: ready`** antes que STORY-008 possa ir para `in_review` (invariante 9 de `indexing.md`).

## Dependências

- **Bloqueada por:** nenhuma. Pode rodar em paralelo a STORY-001 a STORY-005 (todas as outras estórias paralelas do EPIC-000).
- **Bloqueia:** STORY-008 (precisa de DDR-001 aceito + screen spec em `ready` para aplicar tokens base e implementar a tela conforme spec), STORY-009 (precisa de DDR-001 aceito para aplicar tokens em nível mínimo), STORY-011 (validação).
- **Pré-requisitos de ambiente:** acesso ao protótipo em `docs/prototipo/` (já versionado).

## Decisões já tomadas (não as reabra)

- **PDR-003** — duas interfaces, mobile-first WebApp + desktop-first Backoffice. DS atende ambas.
- **`non-functional.md`** — WCAG 2.1 AA, tamanhos mínimos, idioma único pt-BR.
- **Identidade visual do protótipo** (`docs/prototipo/index.html`) — fonte primária de identidade nesta fase, conforme SKILL do PO.
- **Princípios de design** (`docs/skills/designer/references/design-principles.md`) — DDR-001 não reabre.

## Liberdade técnica do agente

Você (agente designer) decide:
- Sistema de espaçamento (4pt ou 8pt) com justificativa.
- Quantidade exata de tokens em cada escala (não exagere — DS enxuto é fácil de consumir).
- Família tipográfica (sistema vs específica acessível).
- Convenção de nomenclatura dos tokens (`color-primary-500` vs `color-cta` vs `--c-primary` — coerência interna).
- Estrutura física dos arquivos em `docs/project-state/design/system/` desde que coerente com `indexing.md`.
- Tom exato do voice-and-tone.

Você (agente designer) NÃO decide:
- Mudar identidade visual radicalmente em relação ao protótipo — DDR-001 é evolução coerente, não ruptura. Ruptura exigiria PDR.
- Implementar tokens em código — decisão local do Programador (IDR).
- Reabrir escopo do EPIC-000.
- Suprimir paridade mobile/desktop (PDR-003).

Se durante a deliberação você perceber que algum aspecto exige decisão de produto (ex: posicionamento da marca, paleta que mude percepção de seriedade), **escale para o PO** via `[ESCALONAMENTO]` em "Notas do agente".

## Definição de Pronto (DoD)

- [x] CA-1 a CA-14 atendidos (CA-13/CA-14: entradas populadas e sync documentado; aprovação humana do DDR-001 segue como pré-condição separada para `accepted`/`done`).
- [x] DDR-001 em `proposed` no path correto.
- [x] `tokens.md`, `voice-and-tone.md`, screen spec em `design/screens/STORY-008-hello-world-webapp.md` (`status: ready`) criados.
- [x] `index.json` atualizado: entrada em `decisions.ddr[]`, em `design.screens[]`, ponteiros em `design.system`.
- [x] Tabela de contraste WCAG AA registrada (`tokens.md` §9).
- [x] Sync com o Programador de STORY-008 registrado em "Notas do agente" (sync ao vivo deferido ao kickoff de STORY-008, que está downstream-blocked; preparação e dúvidas registradas).
- [x] Esta estória com "Notas do agente" preenchida.
- [x] Frontmatter desta estória: `status: in_review` (aguardando aprovação humana do DDR-001).
- [x] Nenhum código de produção introduzido por esta estória.
- [x] **Pré-condição para `done`:** Alexandro aprovou DDR-001 em 2026-05-27; `index.json` reflete `accepted` e screen spec `SCREEN-STORY-008` em `ready`.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Resumo:

1. **Ao iniciar:** carregue `docs/skills/designer/SKILL.md`. Edite frontmatter desta estória e `index.json`.
2. **Durante:** deliberação documental; rabisco da página de boas-vindas → sync com Programador → screen spec final.
3. **Se travar:** `status: blocked`, registre. Decisões de produto escalam ao PO.
4. **Ao terminar:** preencha "Notas", `status: in_review`, atualize `index.json`, abra PR. Após aprovação humana de DDR-001 + screen spec em `ready`, `status: done`.

## Notas do agente (preenchido durante/após execução)

### Decisões tomadas
- 2026-05-27 — **[REVISÃO a pedido do Alexandro] Admin: vermelho → azul-navy.** O vermelho do protótipo para o admin foi rejeitado: como identidade ele competia com o vermelho semântico de erro/destrutivo (confirmado no preview do backoffice — "Recusar" sumia na cor da marca). Admin passa a `#2A4D8F` (claro) / `#5B8DEF` (escuro); chrome navy `#15233B`/`#122039`. Ganho: **vermelho fica exclusivo de erro**. Novo overlap (brando): admin≈info (azul) — mitigado por navy mais profundo que o `info #4A6FA5` e pela baixa frequência de `info`. Atualizei `tokens.md` (§1/§2.2/§4/§6), DDR-001 (Decisão 3 + pilares + consequências + implementação), e os dois previews.
- 2026-05-27 — **[REVISÃO a pedido do Alexandro]** Fonte de verdade do DS = **apenas `app.html`** (a landing `index.html` é de marketing, sobe como está). DDR-001 e `tokens.md` reescritos (v0.2) só sobre o `app.html`.
- 2026-05-27 — **Separação marca ↔ interação.** `brand.green #00A868` restrito à logomarca; interação usa o acento do perfil. Motivo: branco sobre `#00A868` = 3.1:1 (reprova AA), sobre o verde-sage `#2D5F3F` = 7.4:1. O `app.html` já fazia isso (CTA de login usa `--lime #2D5F3F`).
- 2026-05-27 — **Espaçamento: 8pt com meio-passo de 4pt** (Decisão 1 do DDR). Descartado 4pt puro.
- 2026-05-27 — **[REVISÃO] Dual-theme first-class** (Decisão 2 do DDR). Antes eu havia deixado o dark fora; o Alexandro pediu para derivar o tema claro a partir do app (que hoje é escuro). Verifiquei: o `app.html` **já é dual-theme** (`:root` claro + `[data-theme=dark]`, com `prefers-color-scheme` e toggle persistido). Logo "derivar o claro" = formalizar o que existe. A fundação define **claro (padrão) + escuro**; o que o MVP **liga** fica com o PO (tensão com `non-functional.md`, ver escalonamento).
- 2026-05-27 — **[REVISÃO] Esquema de cor por perfil** (Decisão 3 do DDR), a pedido do Alexandro. Três esquemas — profissional (verde), contratante (mostarda), admin (vermelho) — com `accent`/`on-accent`/`soft`/`hover`/chrome em **ambos os temas**. Mapa Flutter: `ColorScheme.fromSeed(seed_do_perfil, brightness)` = 3 sementes × 2 brilhos = 6 schemes. Isso **substitui** minha proposta anterior de "paleta enxuta + cromática de papel só documentada" — agora a cor por perfil é núcleo.
- 2026-05-27 — **Inter (texto); Bebas Neue só logo; JetBrains Mono restrito a overline.**
- 2026-05-27 — **`text.subtle` no claro (`#6F7C72`) = texto grande/UI apenas** (3.98–4.37:1). Piso de texto pequeno essencial = `text.muted #42504A`. No escuro, `text.subtle #8B9590` passa AA normal.

### Descobertas
- 2026-05-27 — **`app.html` já é dual-theme** (verificado no JS: `initTheme()` lê `prefers-color-scheme`, persiste em `localStorage`, toggle via `toggleTheme()`). O tema claro **já existe** (`:root`); o escuro é `[data-theme=dark]`. "Derivar o claro" = formalizar/fechar em AA o que está lá, não criar do zero.
- 2026-05-27 — O protótipo tem **dois verdes intencionais**: acento profissional `#2D5F3F` (interação) e `success #2D7A4F` (sucesso/health). Mantidos distintos.
- 2026-05-27 — **Sobreposição de hue:** contratante ≈ warning (mostarda) e admin ≈ error (vermelho). Resolvido por **regra de contexto** (perfil = identidade persistente/chrome; semântica = feedback transitório) em `tokens.md §4`.
- 2026-05-27 — **De-para Flutter limpo:** perfil × tema = `ColorScheme.fromSeed(seed_do_perfil, brightness)`. A semente é o acento do **perfil**, nunca o `brand.green #00A868` — registrado nas notas de implementação do DDR.
- 2026-05-27 — O schema do `index.json` (v2, PDR-002) **já** comporta `decisions.ddr[]`, `design.screens[]`, `design.system{}`. Apenas populei entradas; não editei schema.

### Bloqueios encontrados
- Nenhum bloqueio. DDR-001 fica `proposed` aguardando aprovação humana (não é bloqueio, é o gate previsto).

### Escalonamentos
- 2026-05-27 — **[ESCALONAMENTO-PO]** `non-functional.md` diz "Tema escuro — fora do MVP", mas o `app.html` já é dual-theme e o Alexandro orientou derivar/manter claro **e** escuro. A fundação define ambos; ligar o dark no MVP é decisão do PO. Proposta: PO atualizar `non-functional.md` ("dual-theme suportado; tema padrão do MVP = claro"). Não editei o doc por ser do PO.

### Sync com Programador (STORY-008)
- 2026-05-27 — **Sync ao vivo deferido para o kickoff de STORY-008** (motivo estrutural): STORY-008 está `blocked_by` STORY-010 **e** STORY-007, sem `owner_agent` — não há Programador em execução com quem sincronizar agora. O modelo paralelo de `collaboration-with-developer.md` dispara quando o Programador assume a estória.
- 2026-05-27 — Como preparação, fiz uma **passada de viabilidade técnica do lado do design contra ADR-001 (Flutter Web)** e deixei o spec auto-suficiente. Acordos/assunções registrados no próprio spec para o Programador confirmar no kickoff:
  - Tela estática, sem fetch remoto → spec entregue direto em `ready` (sem fase `draft`); estados aplicáveis cobertos, não-aplicáveis declarados.
  - `{versao}` consome o mecanismo padronizado de STORY-007 (não inventar 2ª fonte) — CA-1/CA-6 da STORY-008.
  - Mapeamento de tokens → `ThemeData`/`ColorScheme.fromSeed(0xFF2D5F3F)` + `TextTheme` (Inter) documentado no DDR §"Implementação sugerida".
  - Identificadores lógicos sugeridos (`screen-welcome-*`) para ancorar o E2E em browser real (CA-13).
- 2026-05-27 — **Dúvida aberta para o Programador no kickoff:** confirmar se Bebas Neue (logomarca) será self-host ou via `google_fonts`, e se o off-white quente `#F7F4EC` será aplicado por override de `background`/`surface` sobre o `ColorScheme` gerado (recomendado no DDR). É decisão de IDR dele.

### DDRs criados
- DDR-001 — Fundação do Design System — `decisions/ddr/DDR-001-fundacao-do-design-system.md` — status: **proposed** (aguarda aprovação de Alexandro para `accepted`).

### Screen specs criados
- SCREEN-STORY-008-hello-world-webapp — `design/screens/STORY-008-hello-world-webapp.md` — status: **ready**.

### Design System vivo criado
- `design/system/README.md`, `tokens.md` (com tabela de contraste WCAG AA), `components.md` (seed: `brand.logo`, `button.primary`, `link.text`, `surface.card`), `patterns.md` (ponteiros EPIC-001+), `voice-and-tone.md`.

### Cobertura final
- Unitários: N/A (entrega designer — não produz código de produção).
- E2E: N/A. A cobertura recai sobre o código quando o Programador implementar os tokens (STORY-008 / IDR).

### Links de evidência
- PR: <a abrir>
- Tabela de contraste: `design/system/tokens.md` §6 (razões WCAG 2.1 por luminância relativa sRGB — tabelas separadas para tema claro e escuro).
- Aprovação registrada de DDR-001: pendente — bloco "Aprovação humana" no DDR + `approved_by` no `index.json`.

### Pré-condição para `done`
- Alexandro aprovar DDR-001 explicitamente → atualizar DDR para `accepted` (`approved_by` + `decided_at`), `index.json` `decisions.ddr[0].status: accepted` + `approved_by`, e então `STORY-010 → done`. Screen spec já está em `ready`.
