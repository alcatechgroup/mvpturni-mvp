# Tokens — Design System Turni

> Versão 0.2 — fundação inicial. Decidida em **DDR-001** (`docs/project-state/decisions/ddr/DDR-001-fundacao-do-design-system.md`).
> Última atualização: 2026-05-27.
>
> Tokens são as fundações. **Não use valor cru** em spec ou código — use token. O Programador mapeia tokens para `ThemeData` + `ColorScheme` + `TextTheme` no Flutter (ADR-001). Qualquer alteração de fundação (paleta, tipografia, regra de acento, tema) exige **DDR**.

**Fonte de verdade:** o **PWA** `docs/prototipo/app.html` (a landing `index.html` é de marketing e sobe como está — não é referência de DS). O `app.html` já implementa **dois temas** (claro `:root` e escuro `[data-theme="dark"]`, com detecção de `prefers-color-scheme` e toggle persistido) e **esquema de cor por perfil** (profissional/contratante/admin). Esta fundação formaliza isso e fecha **WCAG 2.1 AA**.

---

## 1. Modelo de tema e perfil

Duas dimensões ortogonais geram a cor de cada tela:

1. **Tema (brightness):** `light` (padrão do produto) e `dark` (suportado). Seleção por `prefers-color-scheme` + toggle do usuário, persistido — igual ao protótipo.
2. **Perfil (esquema de cor):** cada papel tem **seu próprio esquema de acento**:

| Perfil | Domínio | Hue | Semente Flutter |
|---|---|---|---|
| `profissional` (contratado) | quem pega o turno | verde-sage | `Color(0xFF2D5F3F)` |
| `contratante` | quem publica a vaga | mostarda | `Color(0xFFB8842F)` |
| `admin` | backoffice Turni | azul-navy | `Color(0xFF2A4D8F)` |

**Mapeamento Flutter (o de-para limpo):** cada combinação perfil × tema é um `ColorScheme.fromSeed(seedColor: <semente do perfil>, brightness: <light|dark>)`. São **3 sementes × 2 brilhos = 6 `ColorScheme`**. Sobre cada um, fixe `surface`/`background` com os neutros das tabelas §3 (o seed sozinho não produz o off-white quente nem o verde-quase-preto). Os papéis-chave do `ColorScheme` (`primary`, `onPrimary`, `primaryContainer`) são pinados nos valores verificados em §2/§6.

- **Pré-login (welcome, login, cadastro inicial):** não há perfil → usa o **esquema neutro/padrão = `profissional` (verde)**, igual ao login do protótipo. A marca conduz; o verde é o acento interativo.
- O **tema escuro hoje está fora do MVP em `non-functional.md`** — há tensão a reconciliar com o PO (ver DDR-001 §"Critérios para revisitar" e nota de escalonamento). Esta fundação **define** ambos os temas para não retrabalhar quando o dark entrar; o que o MVP **liga** é decisão do PO.

---

## 2. Cor — marca e acentos de perfil

### 2.1. Marca (independente de tema/perfil)

| Token | Hex | Uso |
|---|---|---|
| `brand.green` | `#00A868` | **Apenas** a logomarca "TURN**I**." e elementos de marca grandes. **Não** é cor de texto, CTA nem ícone genérico. |

> Branco sobre `#00A868` = **3.1:1** → reprova AA texto normal. `brand.green` é **identidade**, não interação. A interação usa o acento do perfil (§2.2). Esta separação marca↔interação é o coração do DDR-001.

### 2.2. Acentos por perfil (o condutor de interação de cada papel)

Cada perfil tem, em cada tema: `accent` (CTA, ativo, foco, link), `on-accent` (texto/ícone sobre o acento), `accent.soft` (container/tint), `accent.hover`, e a cor de **chrome** (sidebar, sempre escura nos dois temas — assinatura do protótipo).

#### Tema claro

| Perfil | `accent` | `on-accent` | `accent.soft` | `accent.hover` | `accent.ink` (texto sobre claro) | chrome (sidebar) |
|---|---|---|---|---|---|---|
| profissional | `#2D5F3F` | `#FFFFFF` | `#E5F0E8` | `#3A7050` | `#2D5F3F` | `#1B2E1F` |
| contratante | `#9A6E25` | `#FFFFFF` | `#FBEED1` | `#B8842F` | `#6E4E12` | `#3D2A0E` |
| admin | `#2A4D8F` | `#FFFFFF` | `#E4EAF6` | `#21407A` | `#2A4D8F` | `#15233B` |

> Contratante no claro: o mostarda vibrante `#B8842F` é **chrome/realce grande** (sidebar, tint, hover); para **fundo de botão com texto branco** use `accent` `#9A6E25` (4.5:1); para **texto/link** sobre fundo claro use `accent.ink` `#6E4E12` (7.6:1).

#### Tema escuro

| Perfil | `accent` | `on-accent` | `accent.soft` | `accent.hover` | chrome (sidebar) |
|---|---|---|---|---|---|
| profissional | `#5FA37C` | `#0F1411` | `rgba(95,163,124,.14)` | `#6CB089` | `#1B2E1F` |
| contratante | `#D4A95C` | `#0F1411` | `rgba(212,169,92,.14)` | `#E5B968` | `#3D2A0E` |
| admin | `#5B8DEF` | `#0E1626` | `rgba(91,141,239,.16)` | `#74A0F2` | `#15233B` |

> No escuro, o acento é claro e o `on-accent` é quase-preto (`#0F1411`) — padrão Material para dark. O mesmo acento serve de texto sobre superfície escura (todos ≥4.5:1, §6.2).

---

## 3. Cor — neutros (por tema)

Off-white quente no claro; verde-quase-preto no escuro (não cinza-azulado genérico). Valores do `app.html`.

### 3.1. Tema claro

| Token | Hex | Flutter | Uso |
|---|---|---|---|
| `surface.page` | `#F7F4EC` | `background` | Fundo da página / `Scaffold`. |
| `surface` | `#FFFFFF` | `surface` | Cards, sheets, inputs. |
| `surface.sunken` | `#F0EDE3` | `surfaceContainerLow` | Áreas recuadas, badges neutros. |
| `surface.muted` | `#E8E5DB` | `surfaceContainer` | Skeleton, divisor cheio, disabled. |
| `border.subtle` | `#E0DDD3` | `outlineVariant` | Borda de card/input, divisores. |
| `border.strong` | `#C8C5BB` | `outline` | Borda de ênfase, separador. |
| `text.strong` | `#0F1B2D` | `onSurface` | Texto primário, títulos. |
| `text.muted` | `#42504A` | `onSurfaceVariant` | Secundário, helper, **piso de texto pequeno essencial**. |
| `text.subtle` | `#6F7C72` | (custom) | **Apenas texto grande / UI** (ver §6.1). |

### 3.2. Tema escuro

| Token | Hex | Flutter | Uso |
|---|---|---|---|
| `surface.page` | `#0F1411` | `background` | Fundo da página / `Scaffold`. |
| `surface` | `#1A2018` | `surface` | Cards, sheets, inputs. |
| `surface.sunken` | `#232A24` | `surfaceContainerLow` | Áreas recuadas. |
| `surface.muted` | `#2C342E` | `surfaceContainer` | Skeleton, disabled. |
| `border.subtle` | `#2A322D` | `outlineVariant` | Borda de card/input, divisores. |
| `border.strong` | `#3A4338` | `outline` | Borda de ênfase. |
| `text.strong` | `#ECEDE5` | `onSurface` | Texto primário, títulos. |
| `text.muted` | `#A8B2A8` | `onSurfaceVariant` | Secundário, helper, piso de texto pequeno. |
| `text.subtle` | `#8B9590` | (custom) | Secundário fraco (passa AA normal no escuro, §6.2). |

> **Tint de superfície por perfil (opcional):** o protótipo tinge o fundo principal com um gradiente sutil do hue do perfil (mais visível no escuro). É decoração de baixa intensidade — **nunca** reduz o contraste do texto, que sempre lê contra os neutros acima. Use com parcimônia (Princípio #6: flat por design).

---

## 4. Cor — semânticas (por tema)

Feedback transitório (sucesso/atenção/erro/info). **Regra de ouro:** cor de feedback nunca é o único canal — sempre ícone + texto. Padrão preferido (ambos os temas): **tom `*.soft` de fundo + texto neutro alto-contraste + ícone na cor semântica** (a cor entra como ícone/borda ≥3:1, não como cor de texto). O sólido (+ texto contrastante) é para botões/banners.

| Papel | Claro sólido | Claro `*.soft` | Escuro sólido | Escuro `*.soft` |
|---|---|---|---|---|
| `success` | `#2D7A4F` (on=branco) | `#E2F0E5` | `#5FA37C` (on=`#0F1411`) | `rgba(95,163,124,.14)` |
| `warning` | `#9A6E25` (on=branco) | `#FBEED1` | `#D4A95C` (on=`#0F1411`) | `rgba(212,169,92,.14)` |
| `error` | `#B83A3A` (on=branco) | `#FBE2E2` | `#D85A5A` (on=`#0F1411`) | `rgba(216,90,90,.14)` |
| `info` | `#4A6FA5` (on=branco) | `#E0E9F5` | `#6A8FCC` (on=`#0F1411`) | `rgba(106,143,204,.14)` |

> **Sobreposição de hue assumida:** `contratante` ≈ `warning` (mostarda) e `admin` ≈ `info` (azul). São tokens **distintos** com **regra de contexto**: cor de **perfil** = identidade/chrome persistente (sidebar, acento de CTA daquele papel); cor **semântica** = feedback **transitório**. Nunca um banner de atenção mostarda numa tela de contratante "vira" identidade — atenção é sempre `warning`, com ícone + texto. O `admin` usa um **azul-navy** (`#2A4D8F`) deliberadamente mais profundo/saturado que o `info` (`#4A6FA5`), e `info` é semântica de baixa frequência — a chance de confusão é pequena. **`error` (vermelho) não é mais cor de perfil**: o vermelho fica reservado a erro/ação destrutiva, sem competir com a identidade de nenhum papel (ver DDR-001 — revisão admin vermelho → azul).

---

## 5. Tipografia, espaçamento, raio, elevação, motion, breakpoints

(Independentes de tema/perfil.)

### 5.1. Tipografia

- **Texto:** **Inter** (`'Inter', -apple-system, sans-serif`). Em Flutter: `TextTheme` com Inter.
- **Marca:** **Bebas Neue** — **exclusiva da logomarca**. Nunca em UI.
- **Mono (restrita):** **JetBrains Mono** — overline/eyebrow e dados monoespaçados (PIN, versão).
- **Peso:** `w400`/`w500`; `w600` em título. Hierarquia sai de **tamanho e cor**, não de bold.

| Token | `TextTheme` (M3) | Tamanho | Line-height | Weight | Uso |
|---|---|---:|---:|---:|---|
| `display` | `displaySmall` | 36 | 40 | 500 | Marca/herói. |
| `headline` | `headlineMedium` | 28 | 34 | 500 | Título de tela. |
| `title` | `titleLarge` | 22 | 28 | 600 | Título de card/seção. |
| `subtitle` | `titleMedium` | 16 | 22 | 500 | Subtítulo. |
| `body` | `bodyLarge` | 16 | 24 | 400 | Corpo padrão. |
| `body-sm` | `bodyMedium` | 14 | 20 | 400 | **Piso de texto essencial em mobile.** |
| `label` | `labelLarge` | 14 | 16 | 500 | Botão, rótulo de campo. |
| `caption` | `bodySmall` | 13 | 16 | 400 | Auxiliar em desktop / secundário. |
| `overline` | `labelSmall` | 11–12 | 16 | 500 | Eyebrow em mono — **exceção, §5.1.1**. |

**5.1.1. Mínimos (`non-functional.md`):** texto essencial ≥ 14px mobile / 13px desktop. `caption` (13) só em desktop ou conteúdo secundário. `overline` 11–12px permitido **só** para rótulos que duplicam informação adjacente; cor `text.muted` (nunca `text.subtle`).

### 5.2. Espaçamento — grade 8pt com meio-passo 4pt

| Token | dp | Uso |
|---|---:|---|
| `space.xs` | 4 | Gap ícone↔label, padding de chip. |
| `space.sm` | 8 | Gap entre itens próximos. |
| `space.md` | 16 | Padding padrão de card/tela. |
| `space.lg` | 24 | Separação entre blocos, padding de botão. |
| `space.xl` | 32 | Separação entre seções. |
| `space.2xl` | 48 | Respiro de hero. |
| `space.3xl` | 64 | Margem vertical generosa em desktop. |

### 5.3. Raio

| Token | dp | Uso |
|---|---:|---|
| `radius.sm` | 8 | Chips, badges, inputs densos. |
| `radius.md` | 12 | Botões, `TextFormField`. |
| `radius.lg` | 16 | `Card`, `Dialog`. |
| `radius.xl` | 24 | `BottomSheet` modal, container herói. |
| `radius.full` | 999 | Avatar, dot, FAB, pílula de CTA. |

### 5.4. Elevação (Material 3)

| Token | Nível | Sombra (claro) | Sombra (escuro) | Uso |
|---|---:|---|---|---|
| `elev.0` | 0 | — | — | Fundo, áreas planas. |
| `elev.1` | 1 | `0 1px 2px rgba(15,27,45,.04)` | `0 1px 2px rgba(0,0,0,.2)` | Card, `AppBar`. |
| `elev.2` | 2 | `…, 0 4px 12px rgba(15,27,45,.04)` | `…, 0 4px 12px rgba(0,0,0,.15)` | Sheet, snackbar. |
| `elev.3` | 3 | `…, 0 8px 24px rgba(15,27,45,.06)` | `…, 0 8px 24px rgba(0,0,0,.2)` | Dialog, drawer. |

### 5.5. Motion

| Token | Duração | Curva | Uso |
|---|---:|---|---|
| `motion.fast` | 100ms | `easeOut` | Feedback imediato. |
| `motion.base` | 200ms | `easeInOut` | Mudança de estado inline. |
| `motion.slow` | 300ms | `easeInOutCubic` | Transição entre telas. |

> Acima de 300ms → erro de design (exceto onboarding deliberado). Respeite `prefers-reduced-motion` (`MediaQuery.disableAnimations`).

### 5.6. Breakpoints (Material 3)

| Token | Min-width (dp) | Apelido | Layout Flutter |
|---|---:|---|---|
| `bp.compact` | 0 | mobile (base) | Coluna única, `NavigationBar`. |
| `bp.medium` | 600 | tablet vertical | `NavigationRail`. |
| `bp.expanded` | 840 | tablet horiz. / web pequena | Rail estendida, 2 colunas. |
| `bp.large` | 1200 | web/desktop | `NavigationDrawer`/rail, 2–3 colunas. |
| `bp.extraLarge` | 1600 | desktop largo | **Limitar largura útil.** |

### 5.7. Toque e acessibilidade (pisos)

- **Alvo de toque ≥ 48×48 dp** em mobile.
- **Contraste AA:** 4.5:1 texto normal; 3:1 texto grande (≥24px ou ≥18.66px bold) e UI/ícone.
- **Foco sempre visível** — anel `accent` do perfil (default Material; não remova sem substituto).

---

## 6. Tabela de contraste (evidência WCAG 2.1 AA)

Razões pela fórmula WCAG 2.1 (luminância relativa sRGB). **AA normal = 4.5:1; AA grande/UI = 3:1.** Pares abaixo são os **sancionados**; fora desta lista, verifique antes de usar.

### 6.1. Tema claro

| Par | Razão | AA normal | AA grande |
|---|---:|:---:|:---:|
| `text.strong` `#0F1B2D` / `surface.page` `#F7F4EC` | 15.7:1 | ✅ | ✅ |
| `text.strong` `#0F1B2D` / `surface` `#FFFFFF` | 17.3:1 | ✅ | ✅ |
| `text.muted` `#42504A` / `surface.page` | 7.7:1 | ✅ | ✅ |
| `text.subtle` `#6F7C72` / `surface.page` | 3.98:1 | ❌ | ✅ |
| `text.subtle` `#6F7C72` / `surface` | 4.37:1 | ❌ | ✅ |
| profissional `on-accent` `#FFF` / `accent` `#2D5F3F` | 7.4:1 | ✅ | ✅ |
| profissional `accent.ink` `#2D5F3F` / `surface` | 7.4:1 | ✅ | ✅ |
| contratante `on-accent` `#FFF` / `accent` `#9A6E25` | 4.5:1 | ✅ | ✅ |
| contratante `accent.ink` `#6E4E12` / `surface` | 7.6:1 | ✅ | ✅ |
| contratante chrome `#B8842F` / `surface` (UI grande) | 3.2:1 | ❌ | ✅ |
| admin `on-accent` `#FFF` / `accent` `#2A4D8F` | 8.2:1 | ✅ | ✅ |
| admin `accent.ink` `#2A4D8F` / `surface` | 8.2:1 | ✅ | ✅ |
| `#FFF` / `success` `#2D7A4F` | 5.2:1 | ✅ | ✅ |
| `#FFF` / `error` `#B83A3A` | 5.7:1 | ✅ | ✅ |
| `#FFF` / `info` `#4A6FA5` | 5.1:1 | ✅ | ✅ |
| `#FFF` / `brand.green` `#00A868` | 3.1:1 | ❌ | ✅ |

### 6.2. Tema escuro

| Par | Razão | AA normal | AA grande |
|---|---:|:---:|:---:|
| `text.strong` `#ECEDE5` / `surface.page` `#0F1411` | 15.8:1 | ✅ | ✅ |
| `text.strong` `#ECEDE5` / `surface` `#1A2018` | 14.1:1 | ✅ | ✅ |
| `text.muted` `#A8B2A8` / `surface.page` | 8.5:1 | ✅ | ✅ |
| `text.muted` `#A8B2A8` / `surface` | 7.6:1 | ✅ | ✅ |
| `text.subtle` `#8B9590` / `surface` | 5.4:1 | ✅ | ✅ |
| profissional `on-accent` `#0F1411` / `accent` `#5FA37C` | 6.1:1 | ✅ | ✅ |
| profissional `accent` `#5FA37C` / `surface` (texto) | 5.6:1 | ✅ | ✅ |
| contratante `on-accent` `#0F1411` / `accent` `#D4A95C` | 8.3:1 | ✅ | ✅ |
| contratante `accent` `#D4A95C` / `surface` (texto) | 7.6:1 | ✅ | ✅ |
| admin `on-accent` `#0E1626` / `accent` `#5B8DEF` | 5.8:1 | ✅ | ✅ |
| admin `accent` `#5B8DEF` / `surface` (texto) | 5.2:1 | ✅ | ✅ |

### 6.3. Restrições derivadas

- **`text.subtle` no claro** (`#6F7C72`) → reprova texto normal; use só em texto grande/UI. Para texto pequeno essencial use `text.muted`. (No escuro, `text.subtle #8B9590` passa AA normal — restrição é só do claro.)
- **`brand.green`** → branco só passa grande/UI; uso = logomarca.
- **Contratante claro:** `#B8842F` é chrome/grande; texto branco sobre ele reprova — use `accent` `#9A6E25` (botão) ou `accent.ink` `#6E4E12` (texto).
- **Acentos do tema escuro usam `on-accent` escuro** (`#0F1411`), não branco — padrão Material dark.
- Bordas neutras são **suplementares**: identificação de input/card vem de rótulo + preenchimento + foco (`accent`, ≥3:1), não só da borda.
