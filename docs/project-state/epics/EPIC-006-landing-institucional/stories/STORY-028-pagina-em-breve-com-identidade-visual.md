---
story_id: STORY-028
slug: pagina-em-breve-com-identidade-visual
title: Página "Em breve" institucional com identidade visual da landing
epic_id: EPIC-006
sprint_id: SPRINT-2026-W24-LANDING
type: implementation
target_role: programador
requires_design: true
design_screen_id: SCREEN-STORY-028-em-breve
status: in_progress
owner_agent: claude-opus-4-8-programador-2026-05-28
created_at: 2026-05-28
updated_at: 2026-05-28
estimated_session_size: S
---

# STORY-028 — Página "Em breve" institucional

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Ela contém tudo o que você precisa. Se algo estiver ambíguo, registre a dúvida na seção "Notas do agente" no final e pause em vez de adivinhar.

## Contexto (por que esta estória existe)

O epic.md do EPIC-006 fixa: o apex `turni.com.br/` e `www.turni.com.br` servem uma página "Em breve" enquanto o comercial não autoriza exposição pública da landing completa. Esta página é o **primeiro artefato novo** do épico (todo o resto da landing é AS IS importado do protótipo). Precisa:

1. Carregar **rápido** (Performance Lighthouse ≥ 90 em mobile 3G) — é a única coisa que a maioria dos visitantes vai ver.
2. **Respeitar a identidade visual da landing** — cores, tipografia, mark TURN**I.** — para que o visitante que volta após o go-public sinta continuidade.
3. **Não vazar a existência** do path secreto ou da landing — sem links, sem hint no HTML, sem comentários.
4. **Não capturar nada** — sem formulário, sem analytics, sem cookies. Página puramente institucional ("estamos chegando").
5. **Ser indexável** pelo Google — é o que o mundo deve encontrar para `site:turni.com.br`.

A página é construída por **engenharia** (epic.md, PDR-015 STORY-027) reaproveitando os tokens visuais que já vivem em `docs/prototipo/index.html` (CSS variables, fonts, logo SVG/inline). O **Designer** entrega um screen spec leve definindo layout final (provavelmente uma única tela — logo centralizado, mensagem, fundo). Marketing/comercial podem pedir ajuste de copy via PR depois — mas a primeira versão sai com copy mínima default validada pelo PO.

- Épico: `docs/project-state/epics/EPIC-006-landing-institucional/epic.md`
- Documentos canônicos a ler ANTES de codificar:
  - `epic.md` do EPIC-006 (seções "Resultado esperado" e "Entregável visível" — especialmente o que a "Em breve" deve **não** ter)
  - `docs/project-state/decisions/adr/ADR-012-landing-gate-em-breve-path-secreto.md` (decisão de mecânica do gate — define se "Em breve" mora em `apps/landing/public/index.html` ou em site separado)
  - `docs/prototipo/index.html` (fonte dos tokens visuais — extrair CSS variables `--logo-green`, `--black`, `--text`, fontes `Bebas Neue`, `Inter`, logo TURN**I.**)
  - `docs/project-state/design/system/tokens.md` (DDR-001 — Design System)
  - `docs/project-state/design/screens/SCREEN-STORY-028-em-breve.md` (a ser criado pelo Designer — ver nota abaixo)
  - `docs/skills/programador/SKILL.md`

## O quê (objetivo desta estória)

Entregar a página "Em breve" como artefato estático em `apps/landing/public/index.html` (ou no path equivalente que ADR-012 definir), com:

1. **HTML mínimo** — single-file (HTML + CSS inline ou em `<style>` no `<head>`; zero JS desnecessário; se ADR-012 não exigir, sem `manifest.json` nem `sw.js`).
2. **Layout**: logo TURN**I.** centralizado (vertical e horizontalmente), mensagem curta abaixo ("Em breve." ou copy aprovada pelo PO — ver §3), fundo na cor `--black` ou `--bg-cream` (decisão do Designer).
3. **Copy default**: "Em breve." (ou variante aprovada). Sem CTAs, sem link, sem botão. Footer mínimo com `© Turni · ${ano}` (opcional, decisão do Designer).
4. **Tokens visuais herdados** da landing AS IS: variáveis CSS `--logo-green: #00A868`, `--black: #000000`, `--bg-cream: #FAFAF7`, `--text: #0F1B2D`; fontes `Bebas Neue` (logo) e `Inter` (corpo) carregadas com `display=swap` e `preconnect` (mesmo padrão da landing — performance mobile).
5. **Meta tags institucionais**:
   - `<title>Turni</title>`
   - `<meta name="description" content="Turni — em breve.">` (ou copy aprovada)
   - `<meta name="theme-color" content="#00A868">`
   - **Sem** `noindex` aqui — esta página é indexável (epic.md).
   - Open Graph mínimo (`og:title`, `og:description`, `og:type=website`) para preview de compartilhamento decente.
6. **Acessibilidade WCAG AA**: contraste do texto ≥ 4.5:1; logo com `aria-label="Turni"`; navegação por teclado funciona (mesmo sem links interativos, foco visível se houver footer com link).
7. **Sem rastreamento**: sem GTM, sem Hotjar, sem pixel, sem cookies — declarado em `apps/landing/README.md` (STORY-030) e respeitado aqui.
8. **Performance**: Lighthouse Performance ≥ 90 em mobile 3G simulado (deve ser trivial dada a simplicidade — se não estiver, há algo errado).

## Por quê (valor para o usuário)

Direto: o visitante que digita `turni.com.br` no navegador vê uma página institucional bonita, em vez de erro DNS, página em branco, ou (pior) landing completa que o comercial ainda não liberou. Indireto: protege a narrativa de lançamento que o comercial está orquestrando; estabelece o tom visual antes mesmo da landing aparecer; sinaliza ao Google que `turni.com.br` é um site legítimo (não parking).

## Critérios de aceite

- [ ] **CA-1:** Arquivo `apps/landing/public/index.html` existe (ou no path equivalente decidido por ADR-012), self-contained, validado pelo W3C HTML validator (zero erros, warnings aceitáveis).
- [ ] **CA-2:** Renderiza visualmente conforme `SCREEN-STORY-028-em-breve.md`: logo TURN**I.** centralizado, mensagem aprovada pelo PO, fundo conforme decisão do Designer, tipografia `Bebas Neue` no logo e `Inter` no corpo.
- [ ] **CA-3:** Tokens CSS herdados da landing AS IS (`--logo-green`, `--black`, `--bg-cream`, `--text`) presentes; mudança de palette futura na landing reflete na "Em breve" sem refactor.
- [ ] **CA-4:** **Sem** referência a `<path-secreto>` no HTML servido (verificável com `grep -i '<path-secreto>' index.html` — zero matches). Nenhum link interno. Nenhum comentário HTML revelando estrutura.
- [ ] **CA-5:** **Sem** rastreamento: zero scripts de analytics, zero pixels, zero cookies setados, zero requisições para terceiros além das fontes do Google Fonts. Verificável com DevTools → Network e DevTools → Application → Cookies.
- [ ] **CA-6:** Meta tags institucionais presentes: `title`, `description`, `theme-color`, Open Graph mínimo. **Sem** `<meta name="robots" content="noindex">` (página é indexável).
- [ ] **CA-7:** Acessibilidade: Lighthouse Accessibility ≥ 95; contraste WCAG AA verificado nos elementos de texto; logo com `aria-label`; navegação por teclado funciona.
- [ ] **CA-8:** Performance: Lighthouse Performance ≥ 90 em mobile 3G simulado. Bundle total < 50KB (HTML + CSS inline + fontes — fontes preconnect/preload).
- [ ] **CA-9:** Tema funciona em claro/escuro respeitando `prefers-color-scheme` (decisão Designer: a página "Em breve" pode ter um único tema dark — coerente com o hero da landing AS IS que é preto — ou seguir DDR-001 dual; alinhar no sync).
- [ ] **CA-10:** Sync registrado em "Notas do agente": Designer entregou `SCREEN-STORY-028-em-breve.md` em `status: ready` antes da primeira linha de código; copy default aprovada pelo PO (Alexandro) antes do merge.

## Fora de escopo

- Routing/firebase.json/gate — STORY-031.
- Robots.txt e 404.html — STORY-030.
- Conteúdo da landing AS IS — STORY-030.
- Formulário de captura ("avisem-me quando lançar") — fora do EPIC-006 (epic.md marca em "fora de escopo").
- Analytics / GTM / pixel — fora do EPIC-006.
- Internacionalização — fora do EPIC-006.
- Animações sofisticadas, vídeo de background, partículas — fora; página é minimalista por construção.

## Padrões de qualidade exigidos

Esta estória segue `docs/skills/po/references/quality-standards.md`:

- **Acessibilidade (§5):** WCAG 2.1 AA mínimo. Lighthouse Accessibility ≥ 95.
- **Performance:** orçamento mobile 3G (alinhado com o que a landing AS IS já persegue — preconnect, display=swap, fontes críticas).
- **Privacidade:** sem coleta, sem cookies, sem rastreamento. Declarado e verificável.
- **Segurança:** CSP básica configurada no firebase.json (STORY-031); HTML não precisa de `<script>` arbitrário.
- **Verificação visual:** screenshot anexado na "Notas do agente" para PO conferir antes do merge.

## Dependências

- **Bloqueada por:** STORY-026 (ADR-012 decide onde mora o `index.html` — site único ou separado). Designer precisa de `SCREEN-STORY-028-em-breve.md` em `status: ready` antes da primeira linha de UI.
- **Bloqueia:** STORY-030 (scaffolding precisa do `index.html` da Em breve pronto para colocar na estrutura final), STORY-031 (firebase.json roteia para essa página no apex).
- **Pré-requisitos de ambiente:** nenhum (HTML estático, abrir em browser).

## Decisões já tomadas (não as reabra)

- **epic.md do EPIC-006** — "Em breve" é minimalista, sem CTAs, sem formulário, sem rastreamento; indexável; identidade visual herdada da landing AS IS.
- **DDR-001** — tokens do Design System (cores, tipografia).
- **PDR-013** — tema dual claro/escuro (decisão de aplicação na "Em breve" fica com o Designer).
- **PDR-015** — fronteira: engenharia é dona da Em breve; marketing pode pedir ajuste via PR.

## Liberdade técnica do agente

Você (programador) decide:
- Estrutura concreta do HTML (single-file vs. CSS externo — recomendação single-file dado tamanho).
- Se a fonte vem de Google Fonts ou self-hosted (Google Fonts é o padrão da landing AS IS — herdar).
- Como inline o logo (SVG inline vs. PNG vs. font-based como a landing AS IS faz — verificar e herdar).
- Mecanismo de centralização (flexbox vs. grid).
- Se inclui um footer minimalista (`© Turni · 2026`) ou não — decisão Designer.

Você (programador) NÃO decide:
- Adicionar formulário, CTA, link interno (epic.md proíbe).
- Adicionar rastreamento (PDR-015 implícito).
- Mudar copy sem aprovação do PO.
- Suprimir `<meta name="description">` ou Open Graph (necessário para indexação decente).

## Definição de Pronto (DoD)

- [ ] Todos os CAs (CA-1 a CA-10) passam.
- [ ] Lighthouse mobile rodado e screenshot anexado (Performance ≥ 90, Accessibility ≥ 95).
- [ ] Screenshot da página em mobile e desktop anexado para PO conferir.
- [ ] Sync Designer↔Programador registrado.
- [ ] `index.json` atualizado: status `in_review` ao abrir PR; `done` após merge.
- [ ] "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

Siga `docs/skills/programador/SKILL.md`. Resumo:

1. Frontmatter desta estória: `status: in_progress`, `owner_agent`, `updated_at`. Atualize `index.json`.
2. Confirme que `SCREEN-STORY-028-em-breve.md` existe em `docs/project-state/design/screens/` em `status: ready`. Se não, **PARE** e escale ao Designer.
3. Sync ≤15 min com Designer antes da primeira linha de UI.
4. Confirme copy default com PO (Alexandro) antes do merge.
5. Implemente, rode Lighthouse, capture screenshots, abra PR.
6. Ao mergear: `status: done`, "Notas" preenchidas, `index.json` atualizado.

## Notas do agente (preenchido durante/após execução)

### Entrada inicial
Lidos: esta estória inteira; `epic.md` do EPIC-006 (Resultado esperado + Entregável visível); `ADR-012` (accepted — fixa site único, página em `apps/landing/public/index.html`, sem rewrite genérico, HTML `no-cache`, `sw.js` removido); tokens AS IS em `docs/prototipo/index.html` (CSS vars + carregamento de fontes + markup/CSS do mark TURNI.); `docs/skills/programador/SKILL.md`.

Entendimento consolidado: entregar uma página estática single-file, minimalista, dark, com o mark TURNI. centralizado e copy "Em breve.", indexável, sem CTA/form/link/rastreamento/cookies, herdando os tokens visuais da landing. Performance e acessibilidade são triviais por construção; o que precisa de cuidado é (a) não vazar o path secreto, (b) herdar o mark fielmente (incl. fallback do ponto vazado), (c) meta tags institucionais corretas sem `noindex`.

Bloqueio de entrada (resolvido): `SCREEN-STORY-028-em-breve.md` não existia (`requires_design: true`, protocolo passo 2 exige `status: ready` antes da 1ª linha de UI / CA-10). Escalado ao Designer, que entregou o spec em `status: ready` antes de qualquer código.

### Sync Designer↔Programador
Spec `SCREEN-STORY-028-em-breve.md` entregue em `status: ready` (owner: claude-opus-4-8-designer-2026-05-28). Pontos alinhados (§11 do spec) e seguidos na implementação:
1. **Tema dark único** (`--black #000000`), sem `prefers-color-scheme` dual — continuidade com o hero preto da landing AS IS; CA-9 aceita.
2. **Footer incluído** `© Turni · 2026`, ano estático no HTML, **sem JS** (CA-5).
3. **Mark font-based** TURN`I``.` herdado da landing: `TURN` branco, `.di` (I) verde sólido, `.de` (ponto) verde vazado via `-webkit-text-stroke`, com fallback verde sólido; `role="img"`+`aria-label="Turni"` no `<h1>`, spans `aria-hidden`.
4. **Copy default "Em breve."** — proposta do Designer, **aprovada pelo PO Alexandro em 2026-05-28** (CA-10) após revisão visual da página servida localmente. Troca de copy não afeta layout.
5. **Escala do mark** via `clamp(72px,12vw,120px)`; copy via `clamp(18px,2.4vw,24px)`.
6. **Cor do footer** na faixa AA ≥4.5:1 — escolhi `#8A8A82` (~6.2:1, margem confortável sobre `--text-3` que é limítrofe).

### Decisões tomadas
- Single-file HTML+CSS inline (recomendado pela estória dado o tamanho). Resultado: 3.4 KB de HTML.
- Tokens declarados como CSS variables no `<style>` (`--black`, `--logo-green`, `--message`, `--footer`) — satisfaz CA-3 (palette futura reflete sem refactor).
- Stroke do ponto = `3px` (faixa 72–120px do mark); fallback do ponto = verde sólido fora do `@supports (-webkit-text-stroke)`.
- Fontes via Google Fonts (herdado da landing): `preconnect` (googleapis + gstatic) + `preload` do woff2 crítico do Bebas (mesma URL do protótipo, linha 19) + `display=swap` na URL `css2`.
- Marcador de gate (epic.md): `<body data-screen="em-breve">` + `<title>Turni</title>` — neutros, **sem** ecoar path secreto (CA-4).
- IDs estáveis para E2E/validação (STORY-033): `em-breve-logo`, `em-breve-message`, `em-breve-footer`.

### Descobertas
- CSS do mark no protótipo confirma o spec: `.di{color:var(--logo-green)}`, `.de{-webkit-text-stroke:1.5px var(--logo-green);color:transparent}` (linhas 202/204; nav-logo 175/176; turni-intro 398/399 com stroke 4px). Herdado com stroke proporcional ao tamanho maior.
- `.firebaserc`/`firebase.json` da landing, robots.txt, 404.html e o scaffolding `_lp/` são de STORY-030/031 — **fora desta estória**. Aqui só entra `apps/landing/public/index.html`.

### Bloqueios encontrados
- Screen spec ausente na entrada (ver "Entrada inicial") — resolvido via escalonamento ao Designer; nenhuma linha de UI escrita antes do spec ficar `ready`.

### Resultado final / evidência
- **Verificações locais (grep):** bundle 3.4 KB; zero `<script>`/analytics/cookies/`new Date()` (CA-5); zero `<a>`/`<button>`/`<form>` ou link interno (CA-4); únicas requisições externas = Google Fonts (CA-5); sem `robots`/`noindex` (CA-6); meta `title`/`description`/`theme-color`/Open Graph presentes (CA-6).
- **Render real (Playwright/Chromium, fontes carregadas):** mobile 390×844 e desktop 1280×800 conferem com o spec — mark centralizado com `I` verde sólido e ponto verde vazado, "Em breve." branca, footer discreto no rodapé. Tema dark único.
- **Lighthouse mobile (2026-05-29, throttling simulado, contra URL local `python -m http.server`):** Performance **99**, Accessibility **100**, Best Practices 96, SEO 100. `color-contrast` PASS (CA-7 — WCAG AA), `heading-order` PASS, FCP/LCP 2.7 s, CLS 0.004, TBT 0 ms. Os achados `uses-text-compression` e `render-blocking-resources` são artefatos do servidor local sem gzip — o Firebase Hosting aplica brotli/gzip e só melhora o número; `errors-in-console` = 404 de `favicon.ico` do servidor local. Screenshot do Chrome real (Lighthouse) confere com o spec.
- **Correção de acessibilidade (2026-05-29):** removido `role="img"` do `<h1>` (uso de ARIA inválido apontado por `aria-allowed-role`; também tirava o `<h1>` da árvore de headings). Mantido `aria-label="Turni"` — o leitor de tela continua anunciando "Turni", agora como heading nível 1, e o ARIA fica válido. Sem mudança visual nem de copy (PO já aprovou a copy). Resultado: a11y 99→100, `aria-allowed-role` n/a, `heading-order` PASS.
- **Lighthouse na URL de homolog:** pendente — gated em STORY-031 (URL servida pelo Firebase). Decisão do PO (2026-05-29): 028 permanece `in_progress`; a reconfirmação na homolog é **não-bloqueante** e será absorvida pela validação da STORY-033. Os números locais (Perf 99 / A11y 100) já satisfazem CA-7/CA-8 com margem; a homolog só tende a igualar ou superar.
- **URL de homolog:** (após STORY-031 estar verde)

### Pendências para fechar
- [x] **Aprovação da copy default "Em breve." pelo PO (Alexandro)** — aprovada em 2026-05-28 (CA-10).
- [x] **Lighthouse mobile (Performance ≥ 90 / Accessibility ≥ 95)** — rodado em 2026-05-29 contra URL local (Perf 99 / A11y 100). Reconfirmação na URL de homolog é não-bloqueante (gated em STORY-031, absorvida pela STORY-033) — decisão do PO.
- [ ] Validação `curl` do gate no apex — gated em STORY-031/033 (pertence ao gate, não à página).
- [ ] Commit (workflow Turni: direto na main, stageando **só** `apps/landing/public/index.html`, `SCREEN-STORY-028-em-breve.md`, esta estória e a entrada do `index.json` — há outros agentes na worktree).

### Links de evidência
(commit a preencher após aprovação da copy)
