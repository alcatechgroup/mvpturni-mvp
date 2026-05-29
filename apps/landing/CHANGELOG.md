# Changelog — apps/landing

Histórico de importação e adaptações da landing institucional. Conteúdo da landing
AS IS (`public/_lp/`) é propriedade do marketing; este changelog registra apenas as
intervenções de **engenharia** (importação inicial e remediações).

## 2026-05-29 — Importação AS IS de `docs/prototipo/index.html` (STORY-030)

Importação da landing AS IS para a estrutura oficial do monorepo, com as **4 adaptações
mecânicas obrigatórias** do epic.md / ADR-012 — e **apenas** elas.

**Origem:** `docs/prototipo/index.html` (+ assets) → `apps/landing/public/_lp/`.

**Assets copiados verbatim:** `img/` (52 arquivos), `turnioficial_files/` (8 arquivos:
imagens, `fonts.css` com `@font-face` de `fonts.gstatic.com`, `lucide.js`). Diretórios
copiados inteiros para garantir paridade total com o protótipo (CA-3: zero 404).

**NÃO copiados** (são do protótipo do WebApp, não da landing):
- `app.html` (WebApp; fora de escopo — A2).
- `sw.js` (removido na importação por ADR-012 §5 — risco de cache-first servir versão
  antiga / HTML cacheado; o `index.html` da landing **não** registrava service worker,
  então a remoção é só a não-cópia do arquivo).
- `tour.css`, `tour.js` (onboarding do WebApp; não referenciados pelo `index.html` da landing).
- `manifest.json` (manifest PWA do WebApp: `start_url` e shortcuts apontam para `app.html`;
  a landing não é PWA — ADR-012 §5). Decisão do PO (Alexandro, 2026-05-29): dropar o
  arquivo e remover a `<link rel="manifest">` do `<head>`, dentro do escopo da A2
  (eliminar referências a `app.html`).

**Adaptações aplicadas ao `_lp/index.html`:**

- **A1 — Reescrita de CTAs:** 15 ocorrências de `href="app.html#/..."` →
  `href="__WEBAPP_URL__/#/..."` (placeholder build-time, ADR-012 §7; substituído por
  `https://app.homolog.turni.com.br` / `https://app.turni.com.br` no deploy — STORY-031).
  Linhas no arquivo original: 2497, 2498, 2604, 2623, 2920, 2966, 3192, 3212, 3232,
  3242, 3544, 3562, 3580, 3592, 3692.
- **A2 — Exclusão de referências a `app.html`:** `app.html` não copiado; `manifest.json`
  (que apontava para `app.html`) e sua `<link rel="manifest">` removidos. Verificado:
  `grep 'href="app.html'` → 0 matches.
- **A3 — `noindex`:** injetado `<meta name="robots" content="noindex,nofollow">` no
  `<head>`, logo após `<meta name="viewport">`. (Garantia real de não-indexação da
  landing — ADR-012 §2/§3.)
- **A4 — Headers de cache/segurança:** executada em `firebase.json` na STORY-031, não aqui.

**Diff vs. protótipo:** cirúrgico — apenas as adaptações acima. Único byte extra: um
`\n` final no EOF (o protótipo não terminava com newline), subproduto benigno do
processamento de texto; não altera conteúdo nem renderização.

**Artefatos institucionais criados (engenharia):**
- `public/robots.txt` — template com token `__LANDING_PATH__` (injetado no build).
- `public/404.html` — 404 institucional na identidade da landing, link para `/`, sem
  link para o path secreto.
- `README.md` — estrutura e fronteira (PDR-015 + CODEOWNERS).
- `CODEOWNERS` (raiz) — divisão de propriedade por path (ADR-012 §9, aliases PDR-015).

**Observação de segurança/LGPD (registro AS IS):** o HTML da landing carrega recursos
externos — Google Fonts (`fonts.gstatic.com` / `fonts.googleapis.com`) e um `dns-prefetch`
para `unpkg.com` (sem load efetivo). Nenhum analytics/pixel observado. Sem cookies setados
pelo HTML. A CSP concreta é calibrada em STORY-031.
