# Acessibilidade — piso obrigatório

Acessibilidade no Turni **não é modo separado**. É a única forma de desenhar. Este documento descreve o **piso obrigatório** — o que toda tela atende, sem exceção — e dá heurísticas práticas para o Designer aplicar e verificar.

Para o produto, vale o **WCAG 2.1 nível AA** como referência. Você não precisa decorar a especificação inteira — precisa internalizar os pontos abaixo.

## Por que importa para o Turni

A persona inclui profissionais e contratantes de qualquer idade — incluindo pessoas com baixa visão, dificuldade motora, fadiga ocular ao fim do dia. Acessibilidade não é "para deficientes" — é para todos os contextos reais de uso (incluindo seu, num celular ao sol, com uma mão segurando o café).

Acessibilidade insuficiente não é trade-off — é bug.

## Os 7 pontos do piso

### 1. Contraste

| Tipo de texto | Contraste mínimo |
|---|---|
| Texto normal (<18pt regular ou <14pt bold) | **4.5:1** |
| Texto grande (≥18pt regular ou ≥14pt bold) | **3:1** |
| Ícone significativo, borda de componente interativo | **3:1** |
| Texto decorativo, logo, desabilitado | (isento, mas evite ofender) |

**Como verificar:** ferramenta de contraste do browser, plugin (axe DevTools, Stark) ou WebAIM Contrast Checker. Toda combinação **cor de texto / cor de fundo** usada em token passa por verificação.

**Sinais de erro:**
- Texto cinza claro (`#C0C0C0`) sobre branco — falha.
- Placeholder cinza claro como fonte primária de informação — falha (placeholder ≠ label).
- Cor primária sobre cor de marca saturada — verificar caso a caso.

### 2. Foco sempre visível

- Todo elemento interativo (`FilledButton`, `OutlinedButton`, `TextButton`, `TextFormField`, `Checkbox`, `Switch`, `RadioListTile`, `InkWell` custom, item de menu) tem **indicador de foco visível** quando recebe foco.
- Material 3 do Flutter já entrega o indicador por padrão. Você **não desliga** isso por estética.
- Em Flutter Web, foco aparece quando o usuário usa teclado; em mobile, aparece com switch control / focus assistivo.

**Sinal de erro:** "removi o overlay de foco do `InkWell` porque ficou feio." → falhou.

### 3. Navegação por teclado completa (Flutter Web)

- **Tab** percorre todos os interativos na ordem visual (top→bottom, left→right em LTR). Flutter Web faz isso por padrão para widgets Material; widget custom precisa de `Focus`/`FocusableActionDetector`.
- **Shift+Tab** percorre para trás.
- **Enter / Space** ativam botões.
- **Setas** navegam dentro de listas (`ListView` aceita scroll por teclado), menus (`DropdownMenu`), `SegmentedButton`, `RadioListTile` em grupo.
- **Esc** fecha `Dialog` / `BottomSheet` modal / `Drawer`. Flutter já faz isso para os widgets padrão.
- **Foco-trap em `Dialog`/`BottomSheet`** vem por padrão; widget custom precisa de `FocusScope`.
- **Skip link** ("Pular para conteúdo principal") em telas com navegação extensa em Flutter Web — sugira o nome lógico no spec.

**Como verificar:** rode em Flutter Web, desplugue o mouse. Consegue fazer a tarefa? Se não, falhou.

### 4. Semântica via widgets Material + `Semantics`

Você desenha — Programador implementa. Mas você sugere no spec:

- Botão de ação = `FilledButton` / `OutlinedButton` / `TextButton` / `IconButton` (já semânticos). Nunca `GestureDetector` cru para botão visual.
- Link de navegação (Flutter Web) = `InkWell` envolvendo um `Text`, com roteamento via `go_router` ou equivalente; em widget custom, envolver em `Semantics(link: true, ...)` ou usar `Link` widget do Flutter Web.
- Label de campo = `TextFormField` com `decoration.labelText` (já associa label ao input).
- Cabeçalho de seção = `Text` envolvido em `Semantics(header: true, ...)` para que leitores de tela anunciem como título.
- Lista = `ListView` / `ListView.builder` (já tem semântica de lista).
- Tabela tabular = `DataTable` / `PaginatedDataTable` (já anuncia cabeçalho/linhas).

No Flutter Web, esses widgets exportam ARIA correto automaticamente. Em mobile, viram nós da árvore de acessibilidade nativa (TalkBack/VoiceOver).

Semântica correta = leitor de tela funciona, busca do browser funciona, comportamento padrão (atalhos, foco) funciona.

### 5. Erros não são só cor

- Borda vermelha sozinha **não basta** — daltonismo é comum.
- Mensagem de erro **textual** vinculada ao campo via `TextFormField.validator` retornando `errorText` (Material 3 já anuncia para leitor de tela).
- Ícone de erro com `Semantics(label: '...')` quando não acompanhar texto visível.
- Resumo de erros no topo do form (form longo) com foco que pula para cada campo com erro.

**Sinal de erro:** "campo fica vermelho quando dá erro" — sem `errorText`, daltônico não sabe.

### 6. Ícone sozinho como ação tem label

- `IconButton` com **`tooltip:`** descritivo (Flutter já transforma em label de acessibilidade para leitor de tela; em web vira `aria-label`).
- Em mobile, considerar **label visível** (texto curto abaixo do ícone) para clareza — ajuda usuário não-técnico mesmo que enxergue bem.
- Tooltip **não substitui** label semântico — Flutter já cuida, mas se você usar `GestureDetector` custom em vez de `IconButton`, **envolva em `Semantics(label: 'Verbo + objeto', button: true)`**.

**Convenção sugerida ao Programador:** `tooltip` / `Semantics.label` com verbo + objeto: `tooltip: 'Recusar match'`.

### 7. Alvo de toque adequado

- Mínimo **48×48 dp** em mobile (Material 3 default; WCAG aceita ≥44).
- Alvos próximos ≥ 8dp de distância para evitar toque errado.
- Em Flutter, `MaterialTapTargetSize.padded` (default) garante o piso de 48 em widgets Material.
- Botões de ação primária visualmente maiores que secundários.

**Sinal de erro:** `IconButton` com `iconSize: 16` sem padding → área de toque insuficiente.

## Heurísticas extras (boas práticas além do piso)

- **Live regions** — `Semantics(liveRegion: true, ...)` envolvendo `SnackBar`/banner que muda dinamicamente. Em Flutter Web vira `aria-live="polite"`.
- **`Dialog` / `BottomSheet` modais** já trazem semântica correta (foco-trap, anúncio como dialog). Não desligar.
- **Form com agrupamento** — use `Semantics(container: true, label: 'Endereço')` envolvendo `Column` de campos relacionados.
- **Imagem decorativa** — `ExcludeSemantics` em `Image` decorativa, ou `excludeFromSemantics: true`.
- **Imagem com conteúdo** — `Image(semanticLabel: '...')`.
- **Animação respeitando `MediaQuery.disableAnimations`** — usuário que pediu menos movimento recebe menos. Sugira no spec que animações importantes consultem isso.

## Como o Designer verifica (antes do merge)

Checklist rápido na revisão do que o Programador implementou:

- [ ] Contraste de cada combinação cor texto/fundo verificado (ex: Material Theme Builder + ferramenta de contraste).
- [ ] Tab percorre na ordem visual em Flutter Web; foco visível em todo elemento.
- [ ] Mouse desconectado em Flutter Web: consegue completar a tarefa principal só com teclado?
- [ ] `IconButton` tem `tooltip`? Widget custom com gesto tem `Semantics(label:)`?
- [ ] Erros de form têm `errorText` associado ao campo?
- [ ] Alvos de toque ≥ 48dp em mobile?
- [ ] `Dialog`/`BottomSheet` modal fecha com Esc (web) e volta foco ao gatilho?
- [ ] `Semantics(liveRegion:)` onde aplicável (SnackBar, banner dinâmico)?
- [ ] Esquema de cor não é o único canal de informação (sempre tem ícone + texto)?
- [ ] Funciona com TalkBack (Android) e VoiceOver (iOS) lendo a tela em ordem coerente?

Se algum ❌, é bloqueio do PR.

## Ferramentas úteis

- **Material Theme Builder** + **WebAIM Contrast Checker** — verificação de contraste do `ColorScheme` antes mesmo de virar tema do Flutter.
- **Flutter DevTools — aba "Widget Inspector" + "Accessibility"** — mostra a árvore de semântica que o Flutter está expondo.
- **Flutter Web rodando + axe DevTools / Lighthouse** — confere ARIA gerado pelo Flutter no DOM. Bom para piso, não para tudo.
- **TalkBack (Android)** e **VoiceOver (iOS)** — teste real ocasional, principalmente em fluxos críticos (cadastro, match, Pix). Vale ouro.
- **Teclado sozinho em Flutter Web** — o teste mais simples e mais revelador.
- **Modo "Acessibilidade > Tamanho de fonte: maior" no SO** — verifique se a tela respira com fonte aumentada (Flutter respeita `textScaleFactor` por default).

## O que NÃO é desculpa

- "É só primeira versão" — acessibilidade básica é cara de adicionar depois.
- "Ninguém vai usar com leitor de tela" — você não sabe.
- "Designer aprovou visualmente" — visualmente ≠ acessivelmente.
- "Componente da lib não suporta" — Programador pode escalar; lib que impede acessibilidade básica é decisão errada de ADR (escala para Arquiteto).
- "Vai retardar a entrega" — bug de acessibilidade é bug. Não entra em produção.

## Quando dúvida, o piso vence

Acessibilidade entra no Princípio #5 (`design-principles.md`). O **piso WCAG 2.1 AA é intransponível** — vence qualquer outro princípio em conflito. Conflito aparente com simplicidade ou tom geralmente se resolve com mais cuidado de design, não com remoção de acessibilidade. Refinamentos acima do piso (boas práticas extras) entram na hierarquia normal de conflito.
