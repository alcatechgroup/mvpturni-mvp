# Design System Turni

Vocabulário visual e de interação compartilhado pelas telas do Turni (Flutter — Android, iOS, Web — ADR-001). Descreve **comportamento e visual em termos de tokens e estados**, com a forma que mapeia direto para `ThemeData` + `ColorScheme` + `TextTheme` do Flutter. Designer **não escreve Dart**; Programador **não inventa token**.

A fundação foi decidida em **DDR-001 — Fundação do Design System** (`docs/project-state/decisions/ddr/DDR-001-fundacao-do-design-system.md`). Referência de identidade: **apenas o PWA `docs/prototipo/app.html`** + `manifest.json`. A landing `index.html` é de marketing e não é referência do DS do produto.

**Dois eixos geram a cor de cada tela:** **tema** (claro padrão / escuro suportado) × **perfil** (profissional, contratante, admin — cada um com seu esquema de acento). Em Flutter, cada combinação é um `ColorScheme.fromSeed(seed_do_perfil, brightness)`. Pré-login usa o esquema neutro = profissional. Detalhe em `tokens.md §1`.

## Como usar

- Antes de desenhar uma tela nova, leia este DS — provavelmente o que você precisa já existe.
- Antes de criar componente novo, confirme que **o widget Material 3 (ou Cupertino quando justificado) não cobre**. Reaproveite Flutter primeiro.
- Componente novo entra por **DDR** primeiro, não direto.
- Spec de tela referencia componentes pelo id (`ds_components_used` no frontmatter do spec).

## Navegação

- [`tokens.md`](tokens.md) — fundações: cor, tipografia, espaçamento, raio, sombra, motion, breakpoints + tabela de contraste AA.
- [`components.md`](components.md) — biblioteca de componentes (com widget Flutter equivalente).
- [`patterns.md`](patterns.md) — padrões compostos recorrentes.
- [`voice-and-tone.md`](voice-and-tone.md) — tom de voz e vocabulário.
- [`preview.html`](preview.html) — **preview visual não-normativo** dos esquemas tema × perfil (abrir no navegador; toggle de tema no topo). Fonte de verdade continua sendo `tokens.md`.
- [`preview-backoffice.html`](preview-backoffice.html) — **preview desktop do Backoffice** (perfil admin, desktop-first, claro/escuro). Não-normativo.

## Status

Versão: **0.2** — fundação inicial (DDR-001 `accepted` em 2026-05-27; dual-theme + esquema por perfil, admin azul-navy).
Última atualização: 2026-05-27.
