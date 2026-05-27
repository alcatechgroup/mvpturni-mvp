# Componentes

> Cada componente mapeia, sempre que possível, para um **widget Flutter Material 3** existente. Componente custom só existe quando o Flutter não cobre — e entra por DDR. O `id` é o que o spec de tela referencia em `ds_components_used`.

A versão 0.1 cobre **apenas** o necessário para o EPIC-000 (página de boas-vindas, STORY-008). A lista completa para EPIC-001 está em §Roadmap.

> **Cor dos componentes é resolvida por tema × perfil** (`tokens.md §1`). Onde abaixo se lê `primary`/`accent`/`on-accent`, vale o acento do **perfil ativo** (profissional/contratante/admin) no **tema ativo** (claro/escuro). Pré-login = esquema profissional. Componentes não fixam hex — consomem o `ColorScheme` resolvido.

---

## `brand.logo`

**Descrição:** logomarca "TURN**I**." — wordmark da marca. "TURN" + "N" em `text.strong` (ou branco sobre fundo escuro), "I" em `brand.green` `#00A868`, ponto final com contorno (`stroke`) verde.

**Flutter:** `RichText`/`Text.rich` com spans, ou `SvgPicture` quando houver asset. Fonte **Bebas Neue** (`brand.logo` é o único uso dela).

**Tamanhos:** `lg` 24–32px (header/nav), `display` ≥48px (hero/entrada).

**Acessibilidade:** envolver em `Semantics(label: 'Turni')` — o leitor de tela anuncia "Turni", não as letras soltas.

**Usar quando:** identificação de marca. **Não usar como:** título de conteúdo (use `headline`).

---

## `button.primary`

**Descrição:** ação principal de um contexto. **No máximo uma por tela.**

**Flutter:** `FilledButton` (M3); `FilledButton.icon` quando ícone à esquerda agrega.

**Anatomia:** label `label` (verbo no infinitivo + objeto) em `on-accent`; fundo `accent` (do perfil ativo); altura ≥48dp; padding horizontal `space.lg`; raio `radius.full` (pílula, padrão do protótipo).

| Estado | Comportamento |
|---|---|
| default | `accent` + `on-accent` |
| hover (web) | `accent.hover` |
| focus | anel de foco `accent` (default Material) |
| pressed | overlay 12% |
| disabled | opacidade 38% |
| loading | `CircularProgressIndicator` inline no lugar do label; toque bloqueado |

**Não usar quando:** ação secundária (`button.secondary`) ou destrutiva (`button.danger`, EPIC-001+).

---

## `link.text`

**Descrição:** navegação textual inline (ex.: link para `/health`). Sublinhado ou cor `accent.ink`, alvo de toque ≥48dp.

**Flutter:** `TextButton` com `TextStyle(color: accent.ink)`; ou `InkWell` + `Text.rich` para link inline em parágrafo.

**Anatomia:** texto `body`/`label` em `accent.ink` (texto-sobre-claro do perfil; no escuro, `accent`); ícone opcional à direita (ex.: seta externa) com `Semantics`/`tooltip`.

| Estado | Comportamento |
|---|---|
| default | texto `accent.ink` (claro) / `accent` (escuro) |
| hover (web) | sublinhado + `accent.hover` |
| focus | anel de foco visível |
| pressed | overlay sutil |

**Acessibilidade:** o texto do link descreve o destino ("Ver status do sistema"), não "clique aqui".

---

## `surface.card`

**Descrição:** container de conteúdo elevado sobre a página.

**Flutter:** `Card` (M3) ou `Container` com `surface` + `radius.lg` + `elev.1`.

**Anatomia:** fundo `surface`; raio `radius.lg`; elevação `elev.1`; padding interno `space.lg`.

---

## Roadmap (entram por DDR/uso a partir do EPIC-001)

`button.secondary` (`OutlinedButton`), `button.danger`, `input.text` (`TextFormField`), `input.select` (`DropdownMenu`), `input.checkbox`, `input.switch`, `chip` (`FilterChip`/`InputChip`), `segmented` (`SegmentedButton`), `card.vaga`, `card.turno`, `list.tile` (`ListTile`), `empty-state`, `snackbar`, `bottom-sheet`, `dialog`, `nav.bar` (`NavigationBar`) + `nav.rail` (`NavigationRail`), `app.bar`, `stepper`, `skeleton`, `badge`.
