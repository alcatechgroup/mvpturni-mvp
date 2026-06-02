---
id: SCREEN-STORY-047-minhas-vagas
story: STORY-047-lista-minhas-vagas-contratante-cancelar
epic: EPIC-002-vaga-feed-e-candidatura
status: ready                # draft | ready | in_implementation | shipped | superseded
created_at: 2026-06-02
updated_at: 2026-06-02
owner_designer: claude-opus-4-8
related_ddrs: [DDR-001, DDR-002]
ds_components_used: [brand.logo, button.primary, surface.card, link.text, banner]
exceptions_to_ds: [badge.status (selo de estado da vaga com cor semântica), filter.choicechip (filtro de estado single-select), button.danger (ação destrutiva — cancelar), dialog.confirm (confirmação de cancelamento) — descritos na §8; badge.status e filter.choicechip são fortes candidatos a DDR (reaparecem no feed STORY-048 e no painel STORY-051)]
viewports: [mobile, desktop]
prototype_path: SCREEN-STORY-047-minhas-vagas/index.html
prototype_last_validated_at: 2026-06-02  # aprovado por Alexandro em chat
---

# Spec de tela — SCREEN-STORY-047 — Minhas vagas (contratante) + cancelar

> Referência: estória `STORY-047`. CAs e contexto vêm de lá — **não duplico**.
> Fundação visual: `DDR-001` + `docs/project-state/design/system/`. Locale/horário: `DDR-002` (pt-BR, 24h).
> Modelo/estados: `ADR-013` + `docs/especificacao/domain/vaga.md` (estados `aberta`/`fechada`/`cancelada`, transição `aberta → cancelada`).
> Tela irmã: `SCREEN-STORY-046` (Publicar vaga) — esta vira a **home real do contratante** e hospeda o CTA "Publicar vaga" (a home mínima de 046 era andaime até aqui).
> Princípios que guiaram: **#1** simplicidade (uma lista, um filtro padrão, uma ação por card),
> **#2** mobile-first (contratante confere o que está em campo pelo celular), **#3** tom profissional
> (gestão de operação, sem festa), **#5** WCAG AA, **#6** performance percebida (skeleton de cards,
> cancelamento otimista), **#7** todos os estados (loading, vazio-primeira-vez, vazio-por-filtro,
> erro de rede, sem permissão, diálogo de cancelamento, cancelamento em andamento/sucesso/erro).

Segunda tela do contratante autenticado e sua **home**: depois de publicar (STORY-046), ele precisa
ver o que tem em campo e poder **cancelar** uma vaga `aberta` antes de receber aceite. A tela lista as
próprias vagas, agrupadas por estado, com filtro padrão "Ativas", e oferece o cancelamento com
confirmação clara que informa **quantos candidatos serão notificados**.

---

## Tema e perfil

- Usuário **autenticado** como **contratante** → tema do papel (DDR-001): acento **mostarda**.
  - **Claro:** acento `#9A6E25` (`on-accent` branco = 4.5:1 ✅); texto-link/ícone de acento e foco em
    `accent.ink` `#6E4E12` (7.6:1 ✅).
  - **Escuro:** `accent` `#D4A95C` (`on-accent` `#0F1411` = 8.3:1 ✅).
- **Ação destrutiva (cancelar)** usa **`error`** `#B83A3A` (vermelho), nunca o mostarda — o vermelho
  é reservado a destrutivo/erro e não compete com a identidade do papel (tokens.md §6, regra de hue).
- **Selo de estado** usa cor **semântica**, não de perfil: `aberta` = `success` (verde), `fechada` =
  neutro/`text.muted`, `cancelada` = `error` esmaecido. Cor nunca é o único canal — sempre rótulo +
  ícone/borda (tokens.md §4 regra de ouro).
- Marca `TURNI.` (`brand.green #00A868`) conduz no topo. **Tema dual** (PDR-013): tokens claro/escuro
  auditados AA.

---

## 1. Objetivo da tela

Dar ao contratante uma visão rápida das **próprias vagas** em campo e a capacidade de **cancelar** uma
vaga `aberta` antes do aceite. Uma lista filtrável; uma ação primária por card (cancelar, quando cabe);
um caminho claro para os candidatos (quando STORY-051 existir).

---

## 2. Fluxo

### Entrada

- **Ponto de entrada principal:** é a **home do contratante ativo**. A rota `/` do contratante passa a
  redirecionar/renderizar `/contratante/vagas`. (A home mínima de STORY-046 — saudação + CTA — é
  substituída por esta lista.)
- **Também chega aqui:** após **publicar** uma vaga (STORY-046 CA-7) — navega para `/contratante/vagas`
  com toast "Vaga publicada…" e a vaga recém-criada aparece no topo do filtro "Ativas". (Isso aposenta
  o `MinhasVagasPlaceholderScreen`.)
- **Pré-condições:** sessão ativa (`status = ativo`), papel = `contratante`. Funnel guard (STORY-016)
  garante sessão ativa em `/`.
- **RBAC (CA-1):** `profissional` autenticado que navegue para `/contratante/vagas` **não** vê a lista
  — vê o estado **Sem permissão** (§4.6) no front; o backend responde **403** a `GET /api/vagas/minhas`.

### Ações possíveis na tela

- **Ação primária da tela:** **Publicar vaga** — FAB (mobile) / botão no topo (desktop) → `/contratante/vagas/nova` (STORY-046).
- **Filtrar:** alternar entre "Ativas" (default), "Abertas", "Fechadas", "Canceladas", "Todas". Filtro
  persiste **na sessão** via query param `?filtro=<slug>` (deep-linkável, sobrevive a reload; não vai ao DB).
- **Por card:**
  - **Cancelar vaga** — só em card `aberta`. Abre diálogo de confirmação (§4.7) → `DELETE /api/vagas/{id}`.
  - **Ver candidatos** — link só em `aberta` com `candidatos_pendentes > 0` **ou** em `fechada`. Vai para
    `/contratante/vagas/{id}/candidatos` (STORY-051; placeholder se 051 não estiver no merge — CA-6).
  - **Tocar no card** (corpo) — quando STORY-051 estiver done, abre o painel de candidatos; até lá, sem ação
    (o link "Ver candidatos" é o único caminho, para não dar falsa affordance).

### Saída

- **Após cancelar (sucesso):** permanece na tela; o card transita visualmente para `cancelada` (selo muda,
  botão "Cancelar" some) com toast de confirmação. Se o filtro ativo não inclui `cancelada` (ex.: "Abertas"),
  o card sai da lista com micro-animação e o toast confirma.
- **Após Publicar vaga (CTA):** navega para `/contratante/vagas/nova`.
- **Após erro recuperável** (rede no fetch ou no cancelamento): mensagem + retry, sem perder o contexto.

---

## 3. Layout

### Mobile (≥360px)

AppBar com título "Minhas vagas". Abaixo, fila de **chips de filtro** rolável horizontalmente (o filtro
ativo em destaque). Lista vertical de **cards de vaga** (`ListView`), um por linha. **FAB** "Publicar
vaga" fixo no canto inferior direito (acento mostarda, ícone +).

```
+------------------------------------------+
| Minhas vagas                             |  AppBar (título)
+------------------------------------------+
| (Ativas) Abertas Fechadas Canceladas …   |  filtros (ChoiceChip, rolável →)
+------------------------------------------+
|  +------------------------------------+  |
|  | Garçom            ● Aberta         |  |  card: função (título) + selo estado
|  | Sex, 12/06 · 18:00–23:00           |  |  data/hora 24h pt-BR (DDR-002)
|  | R$ 150,00 · turno      [ 1/3 ]     |  |  valor · selo posições preenchidas/total
|  | 2 candidatos aguardando            |  |  contador de pendentes (quando >0)
|  | Ver candidatos        Cancelar vaga|  |  link.text  ·  button.danger (texto)
|  +------------------------------------+  |
|  +------------------------------------+  |
|  | Cozinheira        ✓ Fechada        |  |
|  | Qua, 10/06 · 08:00–16:00           |  |
|  | R$ 180,00 · turno      [ 2/2 ]     |  |
|  | Ver candidatos                     |  |  (fechada: sem cancelar; pode ver candidatos)
|  +------------------------------------+  |
|                                          |
|                              ( + )       |  FAB "Publicar vaga"
+------------------------------------------+
```

- Componentes do DS: `surface.card`, `link.text`, `banner`; + novos: `badge.status`, `filter.choicechip`,
  `button.danger`, `dialog.confirm` (§8).
- Selo de estado no canto superior direito do card. Selo "preenchidas/total" alinhado à linha do valor.
- Alvos de toque ≥48dp: chips de filtro, FAB, "Cancelar vaga", "Ver candidatos".
- FAB não cobre o último card: a lista tem padding inferior ≥ 80px.

### Desktop (≥1024px)

Conteúdo centralizado, largura máxima ~960px (não esticar — princípio #2). Cabeçalho com título à
esquerda e **botão "Publicar vaga"** (não FAB) à direita. Filtros em linha. Cards em **grade de 2 colunas**
(`Wrap`/`GridView`) para usar o espaço sem inflar o card individual. Sem nav lateral neste épico.

```
+------------------------------------------------------------------+
|                            TURNI.                                |
|  Minhas vagas                              [ + Publicar vaga ]   |
|  (Ativas) Abertas Fechadas Canceladas Todas                      |
|                                                                  |
|  +---------------------------+  +---------------------------+    |
|  | Garçom        ● Aberta    |  | Cozinheira   ✓ Fechada    |    |
|  | Sex, 12/06 · 18:00–23:00  |  | Qua, 10/06 · 08:00–16:00  |    |
|  | R$ 150,00 · turno [ 1/3 ] |  | R$ 180,00 · turno [ 2/2 ] |    |
|  | 2 candidatos aguardando   |  |                           |    |
|  | Ver candidatos   Cancelar |  | Ver candidatos            |    |
|  +---------------------------+  +---------------------------+    |
+------------------------------------------------------------------+
```

- Diferença vs. mobile: 2 colunas, CTA no topo (não FAB), hover/focus visíveis. Cancelar abre o mesmo
  diálogo. Largura do card ~440px; gap `space.md`.

### Tablet (768px)

Herda o desktop com **1 coluna** de cards (largura plena ~640px) quando a janela não comporta duas
colunas de ~440px + gap. Sem comportamento próprio além do colapso de colunas — `LayoutBuilder` decide
1 ou 2 colunas pela largura disponível.

---

## 4. Estados

> Toda spec entrega **todos** os estados aplicáveis (Princípio #7).

### 4.1. Caminho feliz (lista preenchida)

Cards do filtro ativo renderizados. Filtro padrão **"Ativas"** = `aberta` + `fechada` com `data_inicio`
nos últimos 7 dias (CA-3). Ordenação sugerida: `data_inicio` ascendente dentro do grupo (próximos turnos
primeiro); vagas `aberta` antes de `fechada` quando misturadas. Microcopy completo na §5.

### 4.2. Loading (primeiro fetch e refresh)

Enquanto `GET /api/vagas/minhas` não responde, **skeleton de 2–3 cards** (não spinner em tela vazia). Os
chips de filtro já aparecem (não dependem do fetch).

```
+------------------------------------------+
| Minhas vagas                             |
+------------------------------------------+
| (Ativas) Abertas Fechadas …              |
+------------------------------------------+
|  +------------------------------------+  |
|  | ░░░░░░░░░░          ░░░░░          |  |
|  | ░░░░░░░░░░░░░░░░                   |  |
|  | ░░░░░░░░       ░░░░                |  |
|  +------------------------------------+  |
|  +------------------------------------+  |
|  | ░░░░░░░░░░          ░░░░░          |  |
|  +------------------------------------+  |
+------------------------------------------+
```

### 4.3. Vazio — primeira vez (sem nenhuma vaga — CA-7)

Contratante nunca publicou. Estado vazio amigável com instrução curta + CTA primário que destrava a ação.

```
+------------------------------------------+
| Minhas vagas                             |
+------------------------------------------+
|                 📋                       |
|     Você ainda não publicou vagas        |
|  Publique uma vaga para começar a        |
|  receber candidaturas de profissionais.  |
|                                          |
|        [   Publicar vaga   ]             |  button.primary
+------------------------------------------+
```

> Sem chips de filtro neste estado (não há o que filtrar). O CTA aqui é o `button.primary` central
> (não o FAB) — a tela inteira convida à primeira publicação.

### 4.4. Vazio — por filtro (tem vagas, filtro atual sem resultado)

Distinto do 4.3: o contratante **tem** vagas, mas o filtro selecionado não retorna nenhuma (ex.: filtro
"Canceladas" sem cancelamentos). Chips permanecem visíveis; mensagem instrui a trocar de filtro. **Não**
mostra o CTA grande de primeira publicação (o FAB continua disponível).

```
+------------------------------------------+
| (Ativas) Abertas Fechadas (Canceladas) … |
+------------------------------------------+
|                                          |
|   Nenhuma vaga cancelada.                |
|   Troque o filtro para ver outras.       |
|                                          |
+------------------------------------------+
```

> Microcopy do filtro pluraliza por estado ("Nenhuma vaga aberta.", "Nenhuma vaga fechada.",
> "Nenhuma vaga cancelada.", "Nenhuma vaga ativa."). Para "Todas" sem resultado, recai no 4.3.

### 4.5. Erro — rede / servidor no fetch

Falha de `GET /api/vagas/minhas` por rede ou 5xx → `banner` no topo da área de conteúdo com **retry**
visível. Os chips de filtro continuam (mas inertes até recarregar).

```
+------------------------------------------+
| ⚠ Não foi possível carregar suas vagas.  |
|   Verifique sua conexão.   [Tentar de novo]|
+------------------------------------------+
```

### 4.6. Sem permissão (CA-1 — profissional)

Profissional autenticado em `/contratante/vagas` não vê a lista. Tela curta + saída. (Reusa o padrão de
SCREEN-046 §4.5 — mesma copy/estrutura.)

```
+------------------------------------------+
|              🔒                          |
|  Esta área é do contratante               |
|  Gerir vagas é uma ação de quem contrata. |
|  Sua conta é de profissional.             |
|        [ Voltar ao início ]              |
+------------------------------------------+
```

> Backend responde **403** a `GET /api/vagas/minhas` e a `DELETE /api/vagas/{id}` para papel ≠ contratante.
> O front também impede a navegação (guard de rota).

### 4.7. Diálogo de cancelamento (CA-4)

Toque em **"Cancelar vaga"** (card `aberta`) abre um `dialog.confirm` (AlertDialog Material). O corpo
informa **quantos candidatos pendentes serão notificados** (X real, vindo do card / re-confirmado pela
resposta). Ação de confirmação é **destrutiva** (`button.danger`, vermelho). Ação de fuga ("Manter vaga")
é a default segura.

```
+--------------------------------------+
|  Cancelar esta vaga?                 |
|                                      |
|  Garçom · Sex, 12/06 · 18:00         |
|  2 candidatos serão notificados      |  ← X real; pluraliza
|  do cancelamento. Esta ação não      |
|  pode ser desfeita.                  |
|                                      |
|       [ Manter vaga ]  [ Cancelar    |
|                          vaga ]      |  ← danger
+--------------------------------------+
```

- **Pluralização do aviso:** `0` → "Nenhum candidato será notificado." ; `1` → "1 candidato será
  notificado do cancelamento." ; `N` → "{N} candidatos serão notificados do cancelamento."
- "Esta ação não pode ser desfeita." sempre presente (cancelamento é terminal — domain/vaga.md).

**4.7b. Cancelando (em andamento).** Após confirmar: botão "Cancelar vaga" do diálogo entra em **loading**
(spinner inline), ambas as ações bloqueadas (sem duplo clique). O diálogo fecha só no resultado.

**4.7c. Cancelamento — sucesso.** Diálogo fecha; **toast** "Vaga cancelada." e o card reflete `cancelada`
(selo vermelho-esmaecido, botão "Cancelar" some, "Ver candidatos" some se era só por pendentes). Se o
filtro ativo exclui `cancelada`, o card sai da lista.

**4.7d. Cancelamento — erro.** Falha de rede/5xx ou **409** (transição inválida — ex.: a vaga fechou entre
o carregamento e o clique): diálogo fecha (ou mantém) e mostra **banner/toast de erro** específico; o card
**não** muda de estado. Para 409, a mensagem orienta a recarregar.

| Erro no cancelamento | Mensagem |
|---|---|
| Rede / 5xx | Não foi possível cancelar agora. Tente de novo. |
| 409 (estado mudou — ex.: já fechada) | Esta vaga não pode mais ser cancelada. Atualize a lista. |
| 403 (não é dono / não-contratante) | Você não tem permissão para cancelar esta vaga. |

### 4.8. Parcial / degradado

`GET /api/vagas/minhas` retorna a lista, mas um campo derivado (ex.: `candidatos_pendentes`) vem ausente:
o card renderiza sem o contador (oculta a linha "N candidatos aguardando"), nunca quebra. Não bloqueia a
ação de cancelar (o diálogo então usa "candidatos" sem número se desconhecido — mas o esperado é o back
sempre enviar o contador).

---

## 5. Microcopy completo

| Lugar | Texto |
|---|---|
| Título da tela / AppBar | Minhas vagas |
| CTA primário (FAB / topo / vazio) | Publicar vaga |
| Filtro — Ativas (default) | Ativas |
| Filtro — Abertas | Abertas |
| Filtro — Fechadas | Fechadas |
| Filtro — Canceladas | Canceladas |
| Filtro — Todas | Todas |
| Selo estado — aberta | Aberta |
| Selo estado — fechada | Fechada |
| Selo estado — cancelada | Cancelada |
| Card — linha data/hora (exemplo) | Sex, 12/06 · 18:00–23:00 |
| Card — valor | R$ {valor} · turno |
| Card — posições (selo) | {preenchidas}/{total} |
| Card — candidatos pendentes (plural) | {N} candidatos aguardando |
| Card — candidatos pendentes (singular) | 1 candidato aguardando |
| Card — link candidatos | Ver candidatos |
| Card — ação cancelar | Cancelar vaga |
| Vazio 1ª vez (título) | Você ainda não publicou vagas |
| Vazio 1ª vez (instrução) | Publique uma vaga para começar a receber candidaturas de profissionais. |
| Vazio 1ª vez (CTA) | Publicar vaga |
| Vazio por filtro — ativas | Nenhuma vaga ativa. Troque o filtro para ver outras. |
| Vazio por filtro — abertas | Nenhuma vaga aberta. Troque o filtro para ver outras. |
| Vazio por filtro — fechadas | Nenhuma vaga fechada. Troque o filtro para ver outras. |
| Vazio por filtro — canceladas | Nenhuma vaga cancelada. Troque o filtro para ver outras. |
| Erro de fetch (banner) | Não foi possível carregar suas vagas. Verifique sua conexão. |
| Retry fetch | Tentar de novo |
| Sem permissão (título) | Esta área é do contratante |
| Sem permissão (corpo) | Gerir vagas é uma ação de quem contrata. Sua conta é de profissional. |
| Sem permissão (CTA) | Voltar ao início |
| Diálogo cancelar (título) | Cancelar esta vaga? |
| Diálogo cancelar (resumo da vaga) | {função} · {dia, dd/mm} · {hh:mm} |
| Diálogo cancelar (aviso, 0) | Nenhum candidato será notificado. Esta ação não pode ser desfeita. |
| Diálogo cancelar (aviso, 1) | 1 candidato será notificado do cancelamento. Esta ação não pode ser desfeita. |
| Diálogo cancelar (aviso, N) | {N} candidatos serão notificados do cancelamento. Esta ação não pode ser desfeita. |
| Diálogo cancelar (manter) | Manter vaga |
| Diálogo cancelar (confirmar — danger) | Cancelar vaga |
| Toast cancelamento sucesso | Vaga cancelada. |
| Erro cancelamento (rede/5xx) | Não foi possível cancelar agora. Tente de novo. |
| Erro cancelamento (409) | Esta vaga não pode mais ser cancelada. Atualize a lista. |
| Erro cancelamento (403) | Você não tem permissão para cancelar esta vaga. |
| Toast publicação (carry-over de STORY-046) | Vaga publicada — começou a aparecer para profissionais. |

Vocabulário: `docs/skills/po/references/glossary.md` (Vaga, Turno, Profissional, Contratante, Candidatura).
Datas/horas em pt-BR, 24h (DDR-002): dia abreviado + `dd/mm`, hora `HH:mm`, intervalo com en-dash.
Tom: `references/tone-and-voice.md` — direto, sem "Ops!"/emoji no corpo (ícones só sinalização leve).

---

## 6. Acessibilidade (notas específicas)

- **Foco inicial** ao abrir: primeiro card da lista (ou o CTA central no estado vazio).
- **Ordem de foco:** chips de filtro (em ordem) → para cada card: corpo → "Ver candidatos" → "Cancelar
  vaga" → próximo card → FAB "Publicar vaga" por último.
- **Selo de estado** não depende só de cor (regra de ouro tokens §4): tem **rótulo textual** ("Aberta")
  + **ícone** (●/✓/⊘) + borda ≥3:1. Leitor de tela anuncia o rótulo.
- **Selo "preenchidas/total"** com `Semantics(label: '1 de 3 posições preenchidas')` — não só "1/3".
- **Card como um todo:** `Semantics` agrupando função + estado + data, para o leitor anunciar o card de
  forma coesa antes das ações (`MergeSemantics` no cabeçalho do card).
- **Diálogo de cancelamento:** AlertDialog do Material (foco preso no diálogo, `Esc`/scrim fecha = "Manter
  vaga"). Foco inicial em **"Manter vaga"** (ação segura), não no destrutivo. Título associado por
  `Semantics`. O aviso de "{N} candidatos" é lido na abertura.
- **Botão destrutivo** "Cancelar vaga" (danger): contraste `error` `#B83A3A` on-white = 5.7:1 ✅; foco
  visível; `Semantics(label: 'Cancelar vaga')`.
- **Toast/banner** como `Semantics(liveRegion: true)` para anúncio assíncrono (sucesso/erro do cancelamento
  e do fetch).
- **Chips de filtro:** `ChoiceChip` com `selected` semântico (leitor anuncia "selecionado"); navegáveis por
  teclado (seta/Tab).
- **Contraste:** selos `success`/`error`/neutro auditados AA (tokens §6); acento mostarda do FAB
  `#9A6E25` on-white = 4.5:1 ✅.
- **Alvos de toque ≥48dp:** chips, FAB, "Cancelar vaga", "Ver candidatos", ações do diálogo. ✅

---

## 7. Identificadores estáveis sugeridos para teste

| Elemento | Identificador lógico sugerido |
|---|---|
| Tela (raiz) | `minhas-vagas-screen` |
| Lista de cards | `minhas-vagas-lista` |
| Card de vaga (por id) | `vaga-card-{id}` |
| Selo de estado do card | `vaga-card-{id}-estado` |
| Selo posições preenchidas/total | `vaga-card-{id}-posicoes` |
| Contador de candidatos pendentes | `vaga-card-{id}-pendentes` |
| Link "Ver candidatos" | `vaga-card-{id}-ver-candidatos` |
| Botão "Cancelar vaga" (no card) | `vaga-card-{id}-cancelar-btn` |
| Chips de filtro (por slug) | `minhas-vagas-filtro-{slug}` (ativas/abertas/fechadas/canceladas/todas) |
| CTA Publicar (FAB / topo / vazio) | `minhas-vagas-publicar-btn` |
| Estado vazio (1ª vez) | `minhas-vagas-vazio` |
| Estado vazio (por filtro) | `minhas-vagas-vazio-filtro` |
| Banner de erro do fetch | `minhas-vagas-erro-banner` |
| Retry do fetch | `minhas-vagas-retry-btn` |
| Sem permissão (card) | `minhas-vagas-sem-permissao` |
| Diálogo de cancelamento | `vaga-cancelar-dialog` |
| Diálogo — confirmar (danger) | `vaga-cancelar-confirmar-btn` |
| Diálogo — manter vaga | `vaga-cancelar-manter-btn` |
| Toast cancelamento sucesso | `vaga-cancelada-toast` |
| Skeleton (loading) | `minhas-vagas-skeleton` |

> Nomes lógicos — o Programador aplica como `Key('...')`/`ValueKey('...')`. O E2E (CA-8) usa
> `vaga-card-{id}-cancelar-btn` → `vaga-cancelar-confirmar-btn` e verifica o selo `vaga-card-{id}-estado`.

---

## 8. Exceções ao Design System

| O que diverge | Por quê | Vira DDR? |
|---|---|---|
| `badge.status` — selo de estado da vaga com cor semântica (`aberta`=success, `fechada`=neutro, `cancelada`=error-esmaecido), rótulo + ícone + borda | DS v0.1 não tem selo de estado. Estado-com-cor é exigido pela CA-2 e reaparece no feed (STORY-048) e no painel de candidatos (STORY-051). Material: `Chip`/`Container` com `shape` arredondado. | **Sim — forte candidato.** Promove a `badge.status` no DS quando STORY-048/051 reusarem. |
| `filter.choicechip` — filtro de estado single-select (chips roláveis, default "Ativas") | DS não tem componente de filtro. Reusa `ChoiceChip` nativo do Material 3 (acessível, single-select). Reaparece no feed do profissional (STORY-048, filtros de função/cidade). | **Sim — candidato.** Promove a `filter.choicechip` no DS se STORY-048 reusar. |
| `button.danger` — ação destrutiva vermelha (confirmar cancelamento) | DS (DDR-001 §Roadmap) já previa `button.danger` para EPIC-001+; esta é a **primeira materialização**. Usa `error` `#B83A3A` (não o acento de perfil). Material: `FilledButton` com `ColorScheme.error`. | Não cria DDR novo — **realiza** o `button.danger` já previsto no roadmap do DS; registrar no `components.md`. |
| `dialog.confirm` — diálogo de confirmação destrutiva (AlertDialog) | DS não formaliza diálogo ainda. Material `AlertDialog` com ação segura default + ação destrutiva. Padrão recorrente (qualquer ação irreversível). | Candidato a `dialog.confirm` no DS; registrar quando reaparecer. |

Nenhuma exceção viola token de cor/contraste — todas usam tokens auditados AA (perfil contratante + semânticos).

---

## 9. Protótipo HTML fiel (validação humana)

- **Localização:** `SCREEN-STORY-047-minhas-vagas/index.html` (mesma pasta deste spec).
- **Cobertura:** seletor de viewport (mobile/desktop) + seletor de estado (chips no topo / `?state=`):
  `lista` (caminho feliz, filtro Ativas), `loading` (skeleton), `vazio` (1ª vez), `vazio-filtro`,
  `erro` (fetch), `sem-permissao`, `dialog` (confirmação de cancelamento), `cancelando` (loading do
  diálogo), `cancelado` (toast + card cancelada). Chips de filtro funcionais entre estados de lista.
- **Fidelidade:** tokens reais do tema contratante (mostarda) + semânticos; microcopy = §5 palavra por
  palavra; identificadores da §7 aplicados como `data-testid`. Datas/horas pt-BR 24h.
- **Restrições:** HTML/CSS/JS vanilla, sem rede, abre clicando. Mock inline. Comentário no topo:
  "protótipo de validação, não código de produção".

### Checklist antes de marcar spec `ready`

- [ ] `SCREEN-STORY-047-minhas-vagas/index.html` abre sem erro.
- [ ] Todos os estados da §4 acessíveis pelo protótipo.
- [ ] Viewports mobile e desktop navegáveis.
- [ ] Microcopy bate palavra por palavra com a §5.
- [ ] Identificadores da §7 presentes no HTML.
- [ ] Caminho feliz percorrível (lista → cancelar → confirma → card cancelada/toast).
- [ ] Tokens reais do DS aplicados.
- [ ] Protótipo apresentado ao humano e sinal de validação capturado.

---

## 10. Dependências e premissas

- **Endpoints (contrato — não duplico; estória CA-1/CA-4/CA-5):**
  - `GET /api/vagas/minhas` → lista das vagas do contratante autenticado. Cada item deve trazer o
    necessário ao card: `id`, `funcao` (nome), `data_inicio`, `data_fim`, `valor`, `posicoes`,
    `posicoes_preenchidas`, `estado`, `candidatos_pendentes` (contador). RBAC: 403 para profissional.
    Filtro é **client-side sobre a lista** (a estória não pede paginação; "liberdade técnica" deixa
    paginação para depois) — o filtro "Ativas" (`aberta` + `fechada` < 7d) é aplicado no front.
  - `DELETE /api/vagas/{id}` → cancela (soft, via transição `aberta → cancelada`; não DELETE físico).
    Valida RBAC (dono), valida transição (409 se não `aberta`), registra audit `vaga.cancelada`, dispara
    evento `VagaCancelada` (consumido por STORY-053 para notificar pendentes). Já existe `Vaga::transitionTo`
    guardando a transição (apps/api/app/Models/Vaga.php) — o endpoint orquestra audit + evento.
- **Permissões:** papel `contratante` + `status = ativo`. Profissional → 403 / estado §4.6.
- **Premissa de back:** `candidatos_pendentes` por vaga vem do back. Candidaturas existem a partir de
  STORY-049/050; até lá o contador pode ser `0` (e o aviso do diálogo usa "Nenhum candidato será
  notificado.") — a UI é exercitada em teste com `candidatos_pendentes > 0`.
- **Coexistência STORY-051:** "Ver candidatos" aponta para `/contratante/vagas/{id}/candidatos`. Se 051
  não estiver no merge, é placeholder (CA-6) — mesma estratégia do placeholder de STORY-046.
- **Sem DDR pendente bloqueante** — spec opera dentro de DDR-001/DDR-002; as exceções §8 são aditivas
  ao DS (registrar em `components.md` na implementação) e candidatas a DDR quando reaparecerem.

---

## 11. Histórico de mudanças

| Data | Mudança | Quem | Motivo |
|---|---|---|---|
| 2026-06-02 | criação (spec completo + protótipo v1) | claude-opus-4-8 (designer) | story bem especificada; spec + protótipo entregues juntos para validação humana |
| 2026-06-02 | validação humana — aprovado | Alexandro | protótipo/spec aprovados em chat (Aprovado — implementar); `status: ready` |
