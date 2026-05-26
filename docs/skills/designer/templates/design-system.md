# Design System — Turni (esqueleto inicial)

> Este é o template para inicializar o Design System **vivo** em `docs/project-state/design/system/`. Os tokens reais saem do **protótipo** em `docs/prototipo/` (manifest, CSS, comportamento das telas) e da paleta Material 3 derivada dele. O DS é descrito em **tokens e comportamento** — não em código Dart — mas com a forma que mapeia direto para `ThemeData` + `ColorScheme.fromSeed` + `TextTheme` + `ShapeBorder` + Material elevation/motion, para que o Programador transforme em theme do Flutter sem tradução. Toda inclusão/alteração relevante de componente, token ou padrão passa por um **DDR** (Design Decision Record); mudança de fundação visual (paleta, tipografia, regra de acento) exige DDR **e** atualização coordenada com o PO.

A estrutura recomendada do DS são 4 arquivos sob `project-state/design/system/`:

```
project-state/design/system/
├── README.md              ← entrada (visão + como navegar)
├── tokens.md              ← fundações: cor, tipografia, espaçamento, raio, sombra, motion, breakpoints
├── components.md          ← biblioteca de componentes (mapeada para widgets Flutter sempre que possível)
├── patterns.md            ← padrões compostos (form, listagem, wizard, vazio, erro)
└── voice-and-tone.md      ← tom, microcopy, vocabulário
```

A seguir, esqueleto sugerido para cada arquivo.

---

## `README.md`

```markdown
# Design System Turni

Vocabulário visual e de interação compartilhado pelas telas do Turni (Flutter — Android, iOS, Web). Descreve **comportamento e visual em termos de tokens e estados**, com a forma que mapeia direto para `ThemeData` + `ColorScheme` + `TextTheme` do Flutter. Designer **não escreve Dart**; Programador **não inventa token**.

## Como usar

- Antes de desenhar uma tela nova, leia este DS — provavelmente o que você precisa já existe.
- Antes de criar componente novo, confirme que **o widget Material 3 (ou Cupertino quando justificado) não cobre**. Reaproveite Flutter primeiro.
- Componente novo entra por **DDR** primeiro (ver `docs/skills/designer/templates/ddr.md`), não direto.
- Spec de tela referencia componentes pelo id (`ds_components_used` no frontmatter do spec).

## Navegação

- `tokens.md` — fundações (cor, tipografia, espaçamento, raio, sombra, motion, breakpoints).
- `components.md` — biblioteca de componentes (com widget Flutter equivalente quando aplicável).
- `patterns.md` — padrões compostos recorrentes.
- `voice-and-tone.md` — tom de voz e vocabulário.

## Status

Versão: 0.1 — esqueleto inicial.
Última atualização: YYYY-MM-DD.
```

---

## `tokens.md`

```markdown
# Tokens

> Tokens são as fundações. Toda decisão visual sai daqui. **Não use valor cru** em spec — use token. O Programador mapeia tokens para `ThemeData` no Flutter.

## Cor (ponto de partida — do `manifest.json` do protótipo)

| Token | Valor de partida | Mapeamento Flutter sugerido | Uso |
|---|---|---|---|
| `brand.seed` | `#00A868` (verde do `theme_color`) | `seed` em `ColorScheme.fromSeed(seedColor: ...)` | Geração da paleta Material 3 |
| `surface.page` | `#F7F4EC` (off-white do `background_color`) | `ColorScheme.background` | Fundo da página/Scaffold |
| `surface.elevated` | `#FFFFFF` | `ColorScheme.surface` | Cards, sheets, dialogs |
| `primary` | derivado do seed | `ColorScheme.primary` | CTA primário, indicador ativo |
| `on-primary` | derivado do seed | `ColorScheme.onPrimary` | Texto/ícone sobre `primary` |
| `secondary` | derivado do seed | `ColorScheme.secondary` | Acento secundário (raríssimo) |
| `outline` | derivado do seed | `ColorScheme.outline` | Bordas de input, divisores |
| `error` | Material 3 default | `ColorScheme.error` | Erro, validação negativa, ação irreversível |
| `on-error` | Material 3 default | `ColorScheme.onError` | Texto sobre `error` |

**Regras de uso (regras de ouro do DS):**

- O verde `brand.seed` é o **único condutor de interação**. Reserve para **um** CTA primário por tela e indicadores de estado positivo (match confirmado, sucesso). Não use em decoração, ícones genéricos, nem em duas ações por tela.
- A paleta Material 3 inteira deriva do seed — não introduza cor adicional sem DDR.
- **Flat por design.** Sem gradientes. Sem segundo acento concorrente. Elevation Material em níveis baixos (0–2 padrão; 3 em casos especiais).
- Cor de feedback **nunca é o único canal** — sempre acompanha ícone + texto (acessibilidade e usuário não-técnico).

> Qualquer adição/alteração à paleta exige DDR.

## Tipografia

- **Família:** definir no DDR-001 do DS (sugestões: Inter / Roboto / Plus Jakarta Sans / System default do Flutter — `Theme.of(context).textTheme`). **Uma família única** para texto; mono opcional só para códigos/PIN se realmente precisar.
- **Regra de peso:** preferir `w400` (regular) e `w500` (medium). Evitar `w700+` em texto comum — contraste sai de tamanho e cor, não de bold. Headings podem usar `w600`.
- **Escala mapeada para `TextTheme` Material 3:**

| Token (DS) | Flutter `TextTheme` | Tamanho sugerido | Weight |
|---|---|---:|---:|
| `display` | `displaySmall` | 36sp | 400 |
| `headline` | `headlineMedium` | 28sp | 500 |
| `title` | `titleLarge` | 22sp | 500 |
| `subtitle` | `titleMedium` | 16sp | 500 |
| `body` | `bodyLarge` | 16sp | 400 |
| `body-sm` | `bodyMedium` | 14sp | 400 |
| `label` | `labelLarge` | 14sp | 500 |
| `caption` | `bodySmall` | 12sp | 400 |

> O usuário não-técnico precisa **ler sem esforço**. Não desça body abaixo de 14sp em produção. Web pode subir para 17–18sp em corpo de texto.

## Espaçamento (em `dp`/`logical px` do Flutter)

| Token | Valor |
|---|---:|
| `xs` | 4 |
| `sm` | 8 |
| `md` | 16 |
| `lg` | 24 |
| `xl` | 32 |
| `2xl` | 48 |
| `3xl` | 64 |

Use múltiplos de 4. `EdgeInsets.all(16)` ≡ `space.md`.

## Raio (`ShapeBorder` / `BorderRadius`)

| Token | Valor | Uso |
|---|---:|---|
| `radius.sm` | 8 | Chips, badges, `Chip`, `InputDecoration` densa |
| `radius.md` | 12 | Botões (`FilledButton`, `OutlinedButton`), inputs (`TextFormField`), `BottomSheet` superior |
| `radius.lg` | 16 | `Card`, `Dialog`, `Sheet` |
| `radius.xl` | 24 | `BottomSheet` modais grandes, hero containers |
| `radius.full` | 9999 | Avatares, dots de status, FAB |

## Elevação (Material 3 — `ThemeData.elevation`)

Use níveis baixos. Material 3 já desenha sombra suave nesses níveis.

| Token | Nível Material | Uso |
|---|---:|---|
| `elev.0` | 0 | Background da página, área "plana" |
| `elev.1` | 1 | Card padrão, AppBar |
| `elev.2` | 2 | Sheet modal, snackbar |
| `elev.3` | 3 | Dialog, drawer aberto |

Acima de `elev.3` → erro de design (sinal de hierarquia confusa).

## Motion (durações + curvas Flutter)

| Token | Duração | Curva (`Curves`) | Uso |
|---|---:|---|---|
| `motion.fast` | 100ms | `Curves.easeOut` | Feedback imediato (press, hover web) |
| `motion.base` | 200ms | `Curves.easeInOut` | Mudanças de estado, abrir/fechar inline |
| `motion.slow` | 300ms | `Curves.easeInOutCubic` | Transição entre telas, drawers |

> Transições têm propósito (orientar atenção), nunca decoração. Acima de 300ms → erro de design (exceto onboarding deliberado).

## Breakpoints (alinhados com Material 3 + uso Flutter)

| Token | Min-width (`dp`) | Apelido | Uso típico no Flutter |
|---|---|---|---|
| `bp.compact` | 0 | mobile (base — mobile-first) | `NavigationBar` inferior, layout em coluna única |
| `bp.medium` | 600 | tablet vertical | `NavigationRail` lateral, master-detail leve |
| `bp.expanded` | 840 | tablet horizontal / web pequena | `NavigationRail` extendida, 2 colunas |
| `bp.large` | 1200 | web/desktop | `NavigationDrawer` ou rail extendida, 2–3 colunas |
| `bp.extraLarge` | 1600 | desktop largo | Limitar largura útil — não estique conteúdo |

Use `LayoutBuilder` / `MediaQuery.sizeOf(context)` ou `AdaptiveScaffold` para alternar entre eles.

## Toque e acessibilidade (pisos)

- **Alvo mínimo de toque: 48×48 dp** (Material). Itens densos em web podem ser menores, mas em mobile **nunca**.
- Contraste WCAG AA: 4.5:1 para texto normal, 3:1 para texto grande/ícone.
- Foco visível **sempre** (`FocusableActionDetector` / `Focus` default do Material já entrega).
```

---

## `components.md`

```markdown
# Componentes

> Cada componente do DS mapeia, sempre que possível, para um **widget Flutter Material 3** existente. Componente custom só existe quando o Flutter realmente não cobre — e entra por DDR.

## Como ler

- **id** é o que o spec de tela referencia em `ds_components_used`.
- **Widget Flutter equivalente** é a referência de implementação (Programador segue, exceto se ADR disser outra coisa).
- **Estados** cobrem `default`, `hover` (web), `focus`, `pressed`, `disabled`, `loading`, `error` quando aplicáveis.
- **Não usar quando** é tão importante quanto **usar quando** — restringe.

---

### `button.primary`

**Descrição:** ação principal de uma tela ou bloco. Existe **no máximo uma por contexto**.

**Widget Flutter:** `FilledButton` (Material 3). Para CTA muito alto-impacto em mobile (ex: "Aceitar match"), `FilledButton.icon` com ícone à esquerda.

**Anatomia:** label (obrigatório, verbo no infinitivo curto), ícone opcional à esquerda, padding interno horizontal `space.lg`, altura ≥48 em mobile, raio `radius.md`, cor `primary`, texto `label` em `on-primary`.

**Estados:**

| Estado | Comportamento |
|---|---|
| default | `primary` + `on-primary` |
| hover (web) | overlay 8% sobre `primary` |
| focus | indicador de foco Material default |
| pressed | overlay 12% sobre `primary` |
| disabled | opacidade 38%, `MouseCursor.basic` |
| loading | `CircularProgressIndicator` inline no lugar do label; toque bloqueado |

**Usar quando:** ação principal e única do contexto (tela, sheet, dialog).

**Não usar quando:** ação destrutiva (`button.danger`); ação secundária (`button.secondary`).

```
+-------------------------------+
|   Aceitar match               |
+-------------------------------+
```

---

### `button.secondary`

**Widget Flutter:** `OutlinedButton` ou `TextButton`. (Descrever brevemente.)

---

### `input.text`

**Widget Flutter:** `TextFormField` com `InputDecoration` (Material 3, outlined).

**Anatomia:** label flutuante (obrigatório), input, `helperText` opcional abaixo, `errorText` quando aplicável.

**Estados:** default / focus / disabled / error / readonly.

**Acessibilidade:** label sempre associado (default do `TextFormField`), erro associado e anunciado por leitor de tela, foco visível obrigatório.

**Microcopy para não-técnico:** label diz **o que é**, placeholder dá **exemplo concreto** ("Ex.: João da Silva"), helper explica **por que pedimos** se necessário ("Para o contratante saber quem pegou o turno").

---

### `card.vaga`

**Widget Flutter:** `Card` com `ListTile` ou conteúdo custom interno.

(mesmo formato — descrever)

---

### `empty-state`

**Anatomia:** ícone Material leve (não ilustração elaborada), título curto em `title`, instrução em `body` em linguagem simples, CTA primário (`FilledButton`).

**Regra:** estado vazio **sempre** instrui o próximo passo, em linguagem que o não-técnico entende. "Sem dados" sozinho é proibido. **Bom:** "Nenhuma vaga por aqui ainda. Publique a primeira."

---

### `snackbar` (toast)

**Widget Flutter:** `SnackBar` exibida via `ScaffoldMessenger`.

(descrever variantes success/warning/danger/info)

---

> **Lista inicial mínima a cobrir até EPIC-001:** `button.primary` (`FilledButton`), `button.secondary` (`OutlinedButton`), `button.danger`, `button.text` (`TextButton`), `input.text` (`TextFormField`), `input.select` (`DropdownMenu`), `input.checkbox`, `input.radio`, `input.switch`, `chip` (`FilterChip`/`InputChip`), `segmented` (`SegmentedButton`), `card.vaga`, `card.turno`, `list.tile` (`ListTile`), `empty-state`, `snackbar`, `bottom-sheet` (`showModalBottomSheet`), `dialog` (`AlertDialog`/`Dialog`), `nav.bar` (`NavigationBar` mobile) + `nav.rail` (`NavigationRail` tablet/web), `app.bar` (`AppBar`/`SliverAppBar`), `stepper` (`Stepper`), `skeleton` (`Shimmer` / Material `placeholder`), `badge` (`Badge`).
```

---

## `patterns.md`

```markdown
# Padrões compostos

> Combinações recorrentes de widgets/componentes para resolver problemas frequentes. Cada padrão evita reinventar a roda e baixa a carga cognitiva do usuário não-técnico.

## `pattern.form`

Composição: campos verticalmente empilhados (`Column` + `Form`), label flutuante, mensagem de erro associada, CTA primário no rodapé.

**Regras:**

- Form longo (>5 campos) é candidato a `pattern.wizard` (`Stepper` do Flutter).
- Validação inline no `validator` do `TextFormField`, disparada no blur (`onEditingComplete`) — não a cada keystroke.
- Mensagem de erro nunca é só cor — sempre texto associado e legível.
- Linguagem do erro **explica o que fazer**: "Use um e-mail com `@` e domínio." > "E-mail inválido".

(sketch inline)

## `pattern.wizard`

Composição: `Stepper` Flutter (horizontal em web, vertical em mobile), navegação anterior/próximo, possibilidade de salvar rascunho.

**Regras:**

- Use para fluxos com >5 campos ou decisão em estágios — quebra reduz carga cognitiva.
- Mostre progresso ("Passo 2 de 4") e o que **ainda falta**.
- Permita voltar sem perder dado preenchido.

(sketch inline)

## `pattern.listing`

Composição: filtros (`BottomSheet` em mobile, `Drawer` lateral em tablet/web), lista (`ListView.builder` com paginação infinita) ou cards, estado vazio, ordenação.

**Regras:**

- Tabela com >5 colunas vira lista de cards no mobile — não scroll horizontal.
- Sempre tem estado vazio próprio.
- Filtros mantêm-se entre navegações (URL/route params em web, restore em mobile).

(sketch inline)

## `pattern.empty`

Composição: `empty-state` padronizado com CTA contextual.

## `pattern.error`

Composição: erro recuperável (`SnackBar` com action "Tentar de novo") vs erro de tela (página dedicada com instrução clara + caminho de saída).
```

---

## `voice-and-tone.md`

```markdown
# Voice & Tone

> Como o Turni fala com o usuário. Detalhe pleno em `docs/skills/designer/references/tone-and-voice.md` — este arquivo é o **resumo aplicável** no dia-a-dia.

## Tom

- **Direto, simples, respeitoso.** O usuário típico é profissional de hospitalidade ou gestor de operações — **não-técnico**. Fale como um colega prestativo, não como sistema.
- **Sem entusiasmo performático.** "Tudo certo." > "Uhuu! Foi! 🎉"
- **Sem culpar o usuário.** "Não encontramos esse CPF." > "CPF inválido — verifique."
- **Sem jargão técnico em microcopy.** "Não conseguimos salvar agora. Tente novamente em alguns minutos." > "Erro 500 — falha no servidor."
- **Frase curta vence frase elegante.** Usuário lendo no celular em pé não terá paciência para parágrafo.

## Vocabulário

Use o `glossary.md` do PO. Termos do domínio Turni: `Vaga`, `Turno`, `Profissional`, `Contratante`, `Match`, `PIN`, `Pix`, `Estabelecimento`. **Não rebatize.**

## Padrões de microcopy

| Situação | Padrão | Exemplo |
|---|---|---|
| CTA primário | verbo no infinitivo curto | "Aceitar match" |
| CTA secundário | verbo no infinitivo, neutro | "Cancelar" |
| Confirmação destrutiva | nomeia o objeto | "Recusar este match?" |
| Sucesso | curto, sem emoji | "Match confirmado." |
| Erro recuperável | o que aconteceu + o que fazer | "Não foi possível confirmar. Tentar de novo." |
| Vazio | o que falta + como conseguir | "Você ainda não publicou vagas. Publicar a primeira." |
| Loading | preferir skeleton — sem texto | — |
| Placeholder | exemplo, não instrução | `Ex.: 11912345678` (telefone) |
```
