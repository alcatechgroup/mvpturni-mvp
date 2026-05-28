---
id: SCREEN-STORY-028-em-breve
story: STORY-028-pagina-em-breve-com-identidade-visual
epic: EPIC-006-landing-institucional
status: ready
created_at: 2026-05-28
updated_at: 2026-05-28
owner_designer: claude-opus-4-8-designer-2026-05-28
related_ddrs: [DDR-001]
ds_components_used: [brand.logo]
exceptions_to_ds: [brand.green sobre fundo preto — uso de identidade (logomarca grande), não interação, conforme tokens.md §2.1; página institucional estática fora do app Flutter — não usa ThemeData/ColorScheme, herda tokens CSS da landing AS IS conforme ADR-012/PDR-015]
viewports: [mobile, desktop]
---

# Spec de tela — SCREEN-STORY-028 — Página "Em breve" institucional

> Referência: estória `STORY-028-pagina-em-breve-com-identidade-visual` (EPIC-006). CAs e contexto vêm de lá — **não duplico**.
> Decisões de mecânica do gate: `ADR-012` (site único, `apps/landing/public/index.html`, sem rewrite genérico). Fronteira de responsabilidade: `PDR-015`.
> Fundação visual: `DDR-001` (`tokens.md`) + tokens AS IS extraídos de `docs/prototipo/index.html`.
> Princípios que guiaram: #1 (simplicidade radical — a tela faz **uma** coisa: comunicar "estamos chegando" com a marca), #3 (tom profissional do domínio — sóbrio, sem festividade), #5 (acessibilidade WCAG AA — contraste verificado), #4 (herda tokens AS IS, não inventa identidade nova).

> **Nota de papel.** Esta NÃO é uma tela Flutter do produto — é um artefato HTML estático institucional, propriedade de engenharia (ADR-012 §1, PDR-015). Por isso o spec descreve tokens em **CSS variables herdadas da landing AS IS** (não em `ThemeData`/`ColorScheme`). O Programador implementa em HTML+CSS single-file (estória §"Liberdade técnica"). Mantenho o vocabulário do DS onde aplicável (espaçamento, tipografia) para coerência.

---

## 1. Objetivo da tela

Comunicar a quem digita `turni.com.br` que **o Turni está chegando**, exibindo a marca TURN**I.** com a identidade visual da landing, sem revelar mais nada — sem CTA, sem formulário, sem links de saída, sem hint do path secreto. É a primeira impressão pública da marca enquanto o comercial não libera a landing completa.

Uma frase: **"a marca, centralizada, sobre fundo preto, dizendo 'Em breve.'"**

---

## 2. Decisão de tema e fundo (decisão do Designer — CA-9)

**Escolha: tema único DARK — fundo `--black` `#000000`, texto claro.**

**Justificativa:**

1. **Continuidade com a landing AS IS.** O `<body>` e o `.hero` da landing (`docs/prototipo/index.html`, linhas 49 e 58) são `background: var(--black)` com `color:#fff`. O visitante que volta após o go-public — quando a "Em breve" der lugar à landing — encontra **o mesmo plano de fundo preto e a mesma marca no mesmo lugar**. Zero quebra de percepção. Esse é o argumento decisivo: a "Em breve" é o "frame 0" da landing, não uma tela separada.
2. **A marca brilha no preto.** O mark TURN**I.** foi desenhado pela landing para viver sobre preto — o `I` verde `#00A868` e o ponto com stroke verde têm contraste e presença máximos sobre `#000`. Sobre o cream `#FAFAF7` o verde perde impacto e o ponto outline quase some.
3. **Performance trivial garantida (CA-8).** Tema único = um só conjunto de regras CSS, sem media query de cor, sem segundo conjunto de tokens. Menor bundle, menor superfície de erro. A página é por construção < 50KB.
4. **Contraste AA folgado (CA-7).** Texto branco/quase-branco sobre `#000` atinge razões muito acima de 4.5:1 (ver §6) — o tema dark é o mais seguro para o piso WCAG.

**Por que NÃO dual via `prefers-color-scheme`:** a estória (CA-9) **aceita explicitamente tema dark único**. Dual aqui só adiciona complexidade e um segundo conjunto de tokens para uma página de uma linha de copy, sem ganho de experiência — visitante institucional não tem expectativa de toggle numa splash. Princípio #1 (simplicidade) decide. DDR-001 (dual theme) governa o **produto Flutter**, não esta página institucional estática; PDR-013 permite ao Designer decidir a aplicação na "Em breve" — aplico tema único dark.

> Consequência registrada: `<meta name="theme-color" content="#00A868">` (exigido pela estória CA-6) é o **verde da marca**, não o preto do fundo — é o token de identidade do Turni para a UI do navegador (barra de endereço em mobile), coerente com a landing AS IS (linha 8 do protótipo usa o mesmo valor).

---

## 3. Decisão de footer (decisão do Designer)

**Escolha: INCLUIR footer minimalista — `© Turni · 2026`.**

**Justificativa:** um copyright discreto reforça que o site é **legítimo e mantido** (não parking domain / não "site quebrado") — exatamente o sinal institucional que a estória e o epic.md querem dar ao Google e ao visitante. Custo visual é mínimo (uma linha, `caption`, cor de baixo contraste no rodapé) e não viola nenhuma restrição: **não é link, não é CTA, não vaza nada**. É texto puro.

- O ano é **estático no HTML** (`2026`) — **não** usar JavaScript (`new Date()`) para gerá-lo. Motivo: a estória pede zero JS desnecessário (§"O quê" item 1) e CA-5 quer zero scripts; o ganho de "ano automático" não paga o débito. Quando virar 2027, o marketing/engenharia troca a string num PR de uma linha (a página é descartada no go-public de qualquer forma).
- Formato exato: `© Turni · 2026` (símbolo de copyright + nome + separador "·" igual ao usado na landing, ex. `WORKFORCE PLATFORM · HOSPITALITY`).

---

## 4. Como renderizar o mark TURN**I.** (herança fiel da landing AS IS)

**O logo é FONT-BASED (Bebas Neue), não SVG e não imagem.** Extraído de `docs/prototipo/index.html`:

Markup AS IS (linha 2492 — `.nav-logo`; linha 2544 — `.turni-intro`):

```html
TURN<span class="di">I</span><span class="de">.</span>
```

Composição em três partes — **herde exatamente assim**:

| Parte | Texto | Tratamento na landing AS IS | Token |
|---|---|---|---|
| Corpo | `TURN` | Branco sólido | `#FFFFFF` (sobre fundo preto) |
| `.di` | `I` | **Verde sólido** | `color: var(--logo-green)` = `#00A868` |
| `.de` | `.` | **Ponto vazado (outline)** — preenchimento transparente + contorno verde | `-webkit-text-stroke: <largura>px var(--logo-green); color: transparent` |

**Tipografia do mark:** `font-family: 'Bebas Neue', sans-serif`. Bebas Neue é caixa-alta por natureza; o texto fica em maiúsculas. Na landing, o tamanho varia por contexto (`.nav-logo` 32px; `.turni-intro` é o gigante centralizado da intro). Para a "Em breve", ver tamanhos em §5.

**O ponto `.` (a parte `.de`) é a assinatura da marca** — não o omita. Na landing o stroke do ponto escala com o tamanho do mark:
- `.nav-logo .de` → `-webkit-text-stroke: 1.5px` (mark a 32px)
- `.turni-intro .de` → `-webkit-text-stroke: 4px` (mark gigante)

Para a "Em breve" (mark grande, ver §5), use stroke proporcional — **recomendação: 3–4px** para um mark na faixa de 72–120px, calibrando visualmente para que o contorno do ponto fique nítido sem encher (o Programador ajusta no olho contra o tamanho final). Inclua fallback sem `-webkit-text-stroke`: navegadores sem suporte devem mostrar o ponto **verde sólido** (`color: var(--logo-green)`) em vez de transparente invisível — ver §6 (acessibilidade/degradação).

**Acessibilidade do mark (CA-7):** o mark é composto por `<span>`s e pode ser lido letra a letra ou de forma estranha por leitor de tela. Envolva o logo num container com `aria-label="Turni"` e `role="img"`, com os spans internos marcados `aria-hidden="true"` — o leitor anuncia "Turni", não "T-U-R-N-I-ponto". É o `<h1>` semântico da página (único heading).

**Fonte (CA-8 / performance):** Bebas Neue via Google Fonts, mesmo padrão da landing AS IS:
- `<link rel="preconnect" href="https://fonts.googleapis.com" crossorigin>` e `https://fonts.gstatic.com`.
- `preload` do woff2 crítico do Bebas Neue (a landing já faz isso — linha 19 do protótipo).
- `display=swap` na declaração `@font-face` / URL do Google Fonts.
- Inter (corpo — copy e footer) também via Google Fonts com `display=swap`. Inter pode carregar sem `preload` (não é crítica acima da dobra na mesma medida que o mark; mas a copy aparece junto — o Programador decide se vale preload, sem ultrapassar o orçamento de 50KB).

---

## 5. Layout

Logo centralizado **vertical e horizontalmente**; copy curta logo abaixo; footer fixo discreto no rodapé. Coluna única, centrada, idêntica em mobile e desktop — muda apenas a **escala** do mark e o respiro. Não há "área de conteúdo" além de marca + copy + footer.

### Mobile (≥360px)

```
+------------------------------------------+
|                                          |
|                                          |
|              (flex center)               |
|                                          |
|                                          |
|              TURN[I][.]                   |  ← mark, Bebas Neue ~72px
|                                          |     I verde sólido · ponto verde outline
|                                          |
|              Em breve.                    |  ← copy, Inter, ~18–20px, branco-suave
|                                          |
|                                          |
|                                          |
|                                          |
|              © Turni · 2026               |  ← footer, Inter caption, baixo contraste
+------------------------------------------+
```

- Fundo: `--black` `#000000`, ocupando 100% da viewport (`min-height: 100vh`/`100dvh`).
- Container de conteúdo (mark + copy) centrado por flexbox: eixo vertical e horizontal centralizados; o footer fica ancorado ao rodapé (layout: coluna com o bloco marca+copy no centro e o footer empurrado para baixo — ex. `justify-content: center` no wrapper + footer posicionado/`margin-top:auto`).
- Padding lateral mínimo `space.md` (16px) para não encostar nas bordas em telas estreitas.
- Mark: **~72px** em mobile (Bebas Neue é estreita e alta; 72px lê grande mas cabe em 360px com folga). `letter-spacing` leve (~1–2px) como na landing.
- Espaço mark → copy: `space.md` a `space.lg` (16–24px).
- Copy "Em breve.": `body`/`subtitle` (~18–20px), `text` claro (ver §6), peso 400.
- Footer: `caption` (~13px), Inter, cor de baixo contraste (≥4.5:1 ainda — ver §6), `padding-bottom: space.lg` (24px).

### Desktop (≥1024px)

```
+------------------------------------------------------------+
|                                                            |
|                                                            |
|                                                            |
|                       (flex center)                        |
|                                                            |
|                       TURN[I][.]                            |  ← mark, Bebas Neue ~120px
|                                                            |
|                       Em breve.                             |  ← copy, ~22–24px
|                                                            |
|                                                            |
|                                                            |
|                       © Turni · 2026                        |  ← footer ao rodapé
+------------------------------------------------------------+
```

- Mesma estrutura — **não é "mobile esticado"**: o espaço extra vira respiro vertical generoso (`space.3xl` em volta do bloco central) e o mark **escala para ~96–120px** para ocupar a tela com presença, como a `turni-intro` gigante da landing faz na intro.
- Largura do conteúdo não precisa de `max-width` rígido (é só uma linha curta centrada), mas o bloco permanece centralizado horizontalmente; não espalhar para as laterais.
- Copy: ~22–24px no desktop.
- Footer permanece discreto no rodapé, centralizado.

### Tablet (768px)

Não há mudança de comportamento relevante — interpola a escala do mark entre mobile e desktop (≈96px). Recomendação ao Programador: usar `clamp()` no `font-size` do mark (ex. `clamp(72px, 12vw, 120px)`) para transição fluida sem breakpoints rígidos, e `clamp()` análogo na copy. Isso cobre mobile→tablet→desktop num só valor e mantém o bundle mínimo. (Omitido como layout separado — só a escala muda.)

---

## 6. Estados

> A página é **estática, sem dados, sem interação, sem rede dinâmica**. Os estados clássicos (loading de dados, vazio, erro de API, sem permissão, parcial) **não se aplicam** — é HTML servido direto pelo Firebase Hosting (ADR-012 §1). Os únicos "estados" relevantes são os de **carregamento de fonte** e **degradação graciosa**. Registro-os para o Programador não tratar como esquecimento (Princípio #7 — todos os estados aplicáveis):

### 6.1. Caminho feliz (renderizado)
Fundo preto, mark TURN**I.** centralizado, "Em breve." abaixo, footer no rodapé. É o §5.

### 6.2. Fontes ainda carregando (FOUT)
- `display=swap`: o texto aparece imediatamente na fonte de fallback e troca para Bebas Neue/Inter ao carregar. Aceitável e desejável (texto nunca invisível — evita FOIT, melhora LCP).
- Fallback do mark: `'Bebas Neue', sans-serif` — enquanto Bebas não chega, "TURNI." aparece em sans-serif do sistema, com o `I` verde e o ponto verde já corretos (as cores são CSS, independem da fonte). Continuidade visual preservada.

### 6.3. Sem suporte a `-webkit-text-stroke` (degradação do ponto)
Em navegadores sem `-webkit-text-stroke`, `color: transparent` deixaria o ponto **invisível** (perderia a assinatura da marca). Mitigação: definir `color: var(--logo-green)` como base no `.de` e o stroke como progressive enhancement — sem suporte ao stroke, o ponto aparece **verde sólido** (ainda lê como marca). Nunca deixar o ponto sumir.

### 6.4. Erro de servidor / página não encontrada
Fora do escopo desta tela — 404 institucional é STORY-030/ADR-012 §3. Esta tela é só o `200` do apex.

---

## 7. Microcopy completo

| Lugar | Texto |
|---|---|
| Mark (logo) | `TURNI.` — leitor de tela anuncia **"Turni"** (via `aria-label`) |
| Copy principal | **Em breve.** |
| Footer | © Turni · 2026 |
| `<title>` | Turni |
| `<meta name="description">` | Turni — em breve. |
| `og:title` | Turni |
| `og:description` | Turni — em breve. |

**Copy default proposta: "Em breve."** (com ponto final, ecoando o ponto da marca TURN**I.**).

> **Pendência de aprovação (CA-10):** a copy default "Em breve." é **proposta do Designer** e está sujeita à validação do **PO Alexandro antes do merge** (não antes da entrega deste spec). O Programador deve confirmar a copy com o Alexandro no passo 4 do protocolo da estória. Se o PO/marketing trocar a copy (ex. "Aguarde.", "Estamos chegando."), é troca de uma string — não afeta layout nem tokens. Manter sempre **curta** (1–3 palavras) para preservar a hierarquia (o mark é o herói; a copy é legenda).

Vocabulário: o termo "Turni" é da marca (glossário do PO). Sem jargão. Tom institucional sóbrio (Princípio #3 — sem "Ops!", sem festividade).

---

## 8. Acessibilidade (notas específicas — CA-7, Lighthouse ≥ 95)

- **Estrutura semântica:** a página tem um `<h1>` único = o logo (envolvido como `role="img"` + `aria-label="Turni"`, spans internos `aria-hidden="true"`). A copy "Em breve." pode ser um `<p>`. O footer um `<footer>` ou `<small>`.
- **`lang="pt-BR"`** no `<html>` (a copy é português; leitor de tela usa a pronúncia certa).
- **Foco / teclado:** não há elementos interativos (sem links, sem botões, sem campos — CA-4/epic.md). Logo, não há trap de foco nem ordem de tab a definir; Tab não encontra alvos e o navegador não mostra anel de foco em lugar nenhum — comportamento correto. Se um futuro PR adicionar um link no footer, ele precisará de foco visível (anel) — **mas neste spec não há link**.
- **Mark NÃO depende só de cor:** o `I` verde e o ponto verde são identidade, não portadores de informação acionável — o significado ("Turni") vem do `aria-label`, não da cor. WCAG 1.4.1 (uso de cor) satisfeito.
- **Contraste verificado (WCAG AA — tema dark único, fundo `--black` `#000000`):**

| Par | Razão | AA normal (4.5:1) | AA grande (3:1) |
|---|---:|:---:|:---:|
| Copy "Em breve." `#FFFFFF` / `#000000` | 21:1 | ✅ | ✅ |
| Copy "Em breve." `#E8E5DD` (border-cream claro, se preferir suavizar) / `#000000` | ~17.9:1 | ✅ | ✅ |
| Footer `© Turni · 2026` `#6F7C72` (`--text-3`) / `#000000` | ~4.6:1 | ✅ (limítrofe) | ✅ |
| Footer alternativo `#8A8A82` / `#000000` | ~6.2:1 | ✅ | ✅ |
| Mark corpo `TURN` `#FFFFFF` / `#000000` | 21:1 | ✅ | ✅ |
| Mark `I` `#00A868` / `#000000` | ~6.4:1 | ✅ | ✅ (é texto grande de qualquer forma) |
| `theme-color` `#00A868` (chrome do browser, não conteúdo) | n/a | — | — |

  - **Recomendação de copy:** branco puro `#FFFFFF` (21:1) ou um branco-suave levemente quebrado para reduzir glare sobre preto absoluto. Se suavizar, **não** descer abaixo de `#E8E5DD` (`--border` da landing, ~17.9:1) — folga enorme.
  - **Footer:** `--text-3` `#6F7C72` dá ~4.6:1 sobre preto — passa AA normal por pouco. Para margem confortável, recomendo um cinza um pouco mais claro (~`#8A8A82`, ~6.2:1). O Programador escolhe dentro da faixa ≥4.5:1. **Não** usar `--text` `#0F1B2D` no footer (é texto escuro — sumiria no preto; esse token é para fundo claro).
- **`prefers-reduced-motion`:** a página **não tem animações** (sem intro animada, sem fade — Princípio #6, e epic.md proíbe animações sofisticadas). Nada a desabilitar. Não reproduzir a animação `turni-intro` da landing — aqui o mark é estático.
- **Zoom / reflow:** com `clamp()` e layout flex centrado, a página reflui sem scroll horizontal até 400% de zoom (WCAG 1.4.10).

---

## 9. Identificadores estáveis sugeridos para teste

Página estática (não Flutter) — os "identificadores" aqui servem para o E2E/validação (STORY-033) e para o `grep` de não-leak (CA-4). Sugestões como atributos/seletores estáveis:

| Elemento | Identificador lógico sugerido |
|---|---|
| Raiz da página | `screen-em-breve` (ex. `<body data-screen="em-breve">` ou `id` no wrapper) |
| Mark/logo | `em-breve-logo` (com `aria-label="Turni"`) |
| Copy principal | `em-breve-message` |
| Footer | `em-breve-footer` |

> **Marcador único para verificação do gate (epic.md / métrica primária).** O epic.md e a validação verificam que `curl https://turni.com.br/` retorna a "Em breve" por um **marcador único no HTML**. O `<title>Turni</title>` serve, mas recomendo também um marcador inequívoco — ex. a própria copy "Em breve." no corpo, ou um comentário/atributo neutro `data-screen="em-breve"`. **Atenção (CA-4):** esse marcador **não pode** conter, sugerir ou ecoar o `<path-secreto>` — nada de comentários revelando estrutura. Marcador neutro apenas.

---

## 10. Exceções ao Design System

| O que diverge | Por quê | Vira DDR? |
|---|---|---|
| Página não usa `ThemeData`/`ColorScheme` nem widgets Flutter | É artefato HTML estático institucional, propriedade de engenharia (ADR-012 §1, PDR-015), fora do app Flutter. Herda tokens CSS AS IS da landing. | Não — é da natureza do artefato, fixada por ADR-012/PDR-015. |
| Tema único dark (não dual `prefers-color-scheme` do DDR-001) | CA-9 aceita dark único; continuidade com o hero preto da landing AS IS; simplicidade (#1). PDR-013 delega a decisão de aplicação na "Em breve" ao Designer. | Não — decisão local desta tela, autorizada pela estória. |
| `brand.green` `#00A868` em área de marca grande sobre preto | tokens.md §2.1 reserva `brand.green` à logomarca — é exatamente o uso aqui (não é texto/CTA/ícone genérico). Conforme, não exceção real. | Não. |
| Bebas Neue na página | tokens.md §5.1 reserva Bebas Neue à logomarca — uso conforme (só o mark usa Bebas; copy e footer usam Inter). | Não. |
| `text.subtle`/cor de footer sobre preto | tokens.md define neutros sobre superfícies claras/escuras do produto; aqui o fundo é `--black` puro da landing (não `surface.page` dark do produto). Contraste verificado em §8. | Não — uso institucional, verificado AA. |

---

## 11. Dependências e premissas

- **ADR-012** — site único, página em `apps/landing/public/index.html`, sem rewrite genérico; HTML `no-cache` (push de copy aparece em ≤5 min); `sw.js` removido. A "Em breve" é o `200` do apex.
- **PDR-015** — engenharia é dona da "Em breve"; marketing pode pedir ajuste de copy via PR depois. A copy default sai validada pelo PO no merge.
- **Tokens AS IS** (de `docs/prototipo/index.html`): `--black:#000000`, `--bg-cream:#FAFAF7`, `--logo-green:#00A868`, `--text:#0F1B2D`, `--text-2:#42504A`, `--text-3:#6F7C72`, `--border:#E8E5DD`. Declarar como CSS variables no `<style>` para que CA-3 (mudança de palette futura reflete sem refactor) seja satisfeito. **Usados nesta tela:** `--black` (fundo), `--logo-green` (mark `I` + ponto + `theme-color`), branco/`--border` (copy), `--text-3` ou cinza derivado (footer).
- **Fontes:** Bebas Neue (mark) + Inter (copy/footer) via Google Fonts com `preconnect` + `preload` do Bebas crítico + `display=swap` — mesmo padrão da landing (linhas 15–21 do protótipo).
- **Restrições NÃO reabertas (epic.md/estória):** sem CTA, sem formulário, sem links de saída, sem botão, sem analytics/cookies/pixel, sem referência ao path secreto, sem `noindex` (página é indexável), sem vídeo/partículas/animações sofisticadas.
- **Meta tags (CA-6):** `<title>Turni</title>`, `<meta name="description" content="Turni — em breve.">`, `<meta name="theme-color" content="#00A868">`, Open Graph mínimo (`og:title`, `og:description`, `og:type=website`). **Sem** `robots noindex`.

### Sync Designer↔Programador (≤15 min) — pontos a alinhar antes da primeira linha de UI

1. **Tema dark único** confirmado (§2) — não implementar dual `prefers-color-scheme`.
2. **Footer incluído** `© Turni · 2026`, ano estático no HTML, sem JS (§3).
3. **Mark font-based** TURN`I``.` herdado da landing AS IS: corpo branco, `I` verde sólido, ponto verde outline (`-webkit-text-stroke`) com fallback verde sólido; `aria-label="Turni"` no container, spans `aria-hidden` (§4).
4. **Copy default "Em breve."** — Programador confirma com PO Alexandro antes do merge (CA-10); troca de copy não afeta layout.
5. **Escala do mark** via `clamp(72px, 12vw, 120px)` (mobile→desktop num valor só) — sugestão, Programador calibra (§5).
6. **Cor do footer** dentro da faixa AA ≥4.5:1 sobre preto (`--text-3` ~4.6:1 é limítrofe; recomendo ~`#8A8A82` ~6.2:1) (§8).

---

## 12. Histórico de mudanças

| Data | Mudança | Quem | Motivo |
|---|---|---|---|
| 2026-05-28 | Criação em `ready` | designer (claude-opus-4-8) | Spec completo da página "Em breve" (STORY-028): tema dark único, footer incluído, mark font-based herdado da landing AS IS, copy default "Em breve." proposta (PO valida no merge). Programador estava bloqueado aguardando `status: ready`. |
