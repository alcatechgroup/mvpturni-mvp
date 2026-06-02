---
id: SCREEN-STORY-048-feed-profissional
story: STORY-048-feed-profissional-com-match-e-filtros
epic: EPIC-002-vaga-feed-e-candidatura
status: shipped              # draft | ready | in_implementation | shipped | superseded
created_at: 2026-06-02
updated_at: 2026-06-02
owner_designer: claude-opus-4-8
related_ddrs: [DDR-001, DDR-002]
ds_components_used: [brand.logo, surface.card, link.text, banner, filter.choicechip, badge.status]
exceptions_to_ds: [match.scorebar (barra de score 0–100 + número, novo — §8), match.scorechip (selo de score no card), gate.banner (faixa de aviso do gate PDR-005 — §8)]
viewports: [mobile, desktop]
prototype_path: SCREEN-STORY-048-feed-profissional/index.html
prototype_last_validated_at: 2026-06-02  # aprovado por Alexandro em chat (app real + protótipo)
---

# Spec de tela — SCREEN-STORY-048 — Feed do profissional (match + filtros)

> Referência: estória `STORY-048`. CAs e contexto vêm de lá — **não duplico**.
> Fundação visual: `DDR-001` + `docs/project-state/design/system/`. Locale/horário: `DDR-002` (pt-BR, 24h).
> Algoritmo/score/eventos: `ADR-014` + `docs/especificacao/domain/match.md` (componentes 40/20/30/10, breakdown, visibilidade para o profissional).
> Modelo/visibilidade: `ADR-013` + `docs/especificacao/domain/vaga.md` (estado `aberta`, função primária/secundária, raio, data futura).
> Tela irmã: `SCREEN-STORY-047` (Minhas vagas do contratante) — reusa `filter.choicechip` e o **padrão de card de vaga**; esta vira a **home real do profissional** (substitui o `AppShellScreen` placeholder para `role=profissional`).
> Tela filha: `STORY-049` (detalhe da vaga com breakdown expandido) e `STORY-050` (candidatar-se) — o card abre o detalhe; o botão de candidatar nasce desabilitado/placeholder aqui.
> Princípios que guiaram: **#1** simplicidade (uma lista ranqueada, 4 filtros, um número de match por card), **#2** mobile-first (o profissional usa o celular em pé, entre turnos), **#3** tom profissional (sem festa, sem gamificação), **#5** WCAG AA (score nunca só por cor — número + barra + rótulo), **#6** performance percebida (skeleton de cards, sem spinner em tela branca — casa com o p95 ≤ 800ms da CA-6), **#7** todos os estados (loading, vazio-sem-vagas, vazio-por-filtro, erro de rede, sem permissão, gate de avaliação, cold start).

Primeira tela do **profissional aprovado** e sua **home**: depois do cadastro (EPIC-001), o profissional
precisa **ver vagas que se encaixam** — ordenadas por score de match, com o número visível em cada card,
filtros úteis e visibilidade já filtrada (função, raio, data futura). É onde o **Match IA** prometido na
landing vira experiência real. Sem feed, o cadastro entrega um usuário sem nada para fazer.

---

## Tema e perfil

- Usuário **autenticado** como **profissional** → tema do papel (DDR-001): acento **verde-sage**.
  - **Claro:** acento `#2D5F3F` (`on-accent` branco = 7.4:1 ✅); texto-link/ícone de acento e foco em
    `accent` `#2D5F3F` sobre `surface` (7.4:1 ✅).
  - **Escuro:** `accent` `#5FA37C` (`on-accent` `#0F1411` = 6.1:1 ✅; como texto sobre superfície = 5.6:1 ✅).
- **Score de match** é a informação-herói do card. A **barra** usa o acento do perfil (verde) como
  preenchimento; o **número** (`0–100`) acompanha sempre — **cor nunca é o único canal** (tokens §4 / §5.7).
  Faixa de qualidade é redundante (número + largura da barra + rótulo "match"), nunca só matiz.
- **Selo "Alto match"** (≥80) usa `success` (verde) com rótulo textual + ícone — distinto do acento de perfil
  por ser **feedback** sobre a vaga, não identidade. Cor + rótulo + ícone (regra de ouro tokens §4).
- **Gate PDR-005** (turno por avaliar): faixa de aviso `warning` (`*.soft` + texto neutro + ícone), nunca
  vermelho — não é erro, é uma pendência acionável.
- Marca `TURNI.` (`brand.green #00A868`) conduz no topo. **Tema dual** (PDR-013): tokens claro/escuro
  auditados AA.

---

## 1. Objetivo da tela

Dar ao profissional uma **lista ranqueada** das vagas que se encaixam nele, com o **score de match
visível em cada card** (número + barra), filtros que respondem sem recarregar a página, e um caminho
claro para o detalhe (STORY-049) e a candidatura (STORY-050). Uma lista; quatro filtros; um número de
match por card. A complexidade do breakdown fica para o detalhe (progressive disclosure — princípio #1).

---

## 2. Fluxo

### Entrada

- **Ponto de entrada principal:** é a **home do profissional ativo**. A rota `/` do profissional passa a
  renderizar `/feed` (substitui o `AppShellScreen` mínimo). Há também a rota explícita `/feed`.
- **Pré-condições:** sessão ativa (`status = ativo`), papel = `profissional`. Funnel guard (STORY-016)
  garante sessão ativa em `/`.
- **RBAC (Padrões de qualidade — contratante → 403):** `contratante` autenticado que navegue para `/feed`
  **não** vê a lista — vê o estado **Sem permissão** (§4.7) no front; o backend responde **403** a
  `GET /api/feed`.

### Ações possíveis na tela

- **Filtrar:** alternar entre **Todas** (default), **Minha função**, **Alto match**, **Candidatadas**.
  Troca de filtro **re-busca** (`GET /api/feed?filtro=…`) **sem reload de página** (CA-5) — a lista atualiza
  in-place com skeleton curto. Filtro persiste na sessão via query param `?filtro=<slug>` (deep-linkável).
- **Tocar no card** (corpo) — abre o **detalhe da vaga** (`/vaga/{id}`, STORY-049; placeholder até 049
  entrar). É a affordance primária de cada card.
- **Candidatar-se** — botão no card. Quando o gate PDR-005 está ativo (turno por avaliar), o botão fica
  **desabilitado** com tooltip "Avalie seu último turno para se candidatar" (CA-8). A candidatura em si é
  STORY-050; aqui o botão leva ao detalhe/candidatura (placeholder até 050).
- **Rolar** — paginação (page-based, page size 20 — CA-10): ao chegar ao fim, carrega a próxima página
  (`?page=N+1`) se `has_next`. Skeleton no rodapé enquanto busca.

### Saída

- **Após trocar filtro:** permanece na tela; a lista re-renderiza com o resultado do novo filtro.
- **Após tocar num card:** navega para `/vaga/{id}` (STORY-049).
- **Após erro recuperável** (rede no fetch): banner + retry, sem perder o filtro atual.

---

## 3. Layout

### Mobile (≥360px)

AppBar com título "Vagas para você". Abaixo, fila de **chips de filtro** rolável horizontalmente (o filtro
ativo em destaque). Lista vertical de **cards de vaga** (`ListView.builder` — paginada/virtualizada,
princípio #6), um por linha. Sem FAB (o profissional não publica — ele consome).

```
+------------------------------------------+
| Vagas para você                          |  AppBar (título)
+------------------------------------------+
| (Todas) Minha função  Alto match  Cand…  |  filtros (ChoiceChip, rolável →)
+------------------------------------------+
|  +------------------------------------+  |
|  | Garçom                  ⬢ 97       |  |  card: função (título) + score chip (número)
|  | Sex, 12/06 · 18:00–23:00           |  |  data/hora 24h pt-BR (DDR-002)
|  | R$ 150,00 · turno · a 3 km         |  |  valor · distância
|  | match ━━━━━━━━━░ 97/100   Alto ✓   |  |  barra de score + selo "Alto match" (≥80)
|  | [        Candidatar-se          ]  |  |  button.primary (verde) — desabilita no gate
|  +------------------------------------+  |
|  +------------------------------------+  |
|  | Cozinheira              ⬢ 61       |  |
|  | Qua, 17/06 · 08:00–16:00           |  |
|  | R$ 180,00 · turno · a 7 km         |  |
|  | match ━━━━━━░░░░ 61/100            |  |  (sem selo — score < 80)
|  | [        Candidatar-se          ]  |  |
|  +------------------------------------+  |
|                ░░░ (carregando +) ░░░     |  skeleton de próxima página (has_next)
+------------------------------------------+
```

- Componentes do DS: `surface.card`, `link.text`, `banner`, `filter.choicechip`; + novos:
  `match.scorebar`, `match.scorechip`, `gate.banner` (§8). Reusa o **card de vaga** de SCREEN-047 (mesma
  densidade, raio `radius.md`, padding `space.md`).
- O **score chip** (número grande) fica no canto superior direito do card — espelha a posição do selo de
  estado em 047 (consistência espacial entre as telas de vaga).
- Alvos de toque ≥48dp: chips de filtro, corpo do card (abre detalhe), botão "Candidatar-se".
- Card inteiro é tocável (abre detalhe); o botão "Candidatar-se" é alvo separado dentro do card.

### Desktop (≥1024px)

Conteúdo centralizado, largura máxima ~960px (não esticar — princípio #2). Cabeçalho com título à esquerda.
Filtros em linha. Cards em **grade de 2 colunas** (`Wrap`/`LayoutBuilder`, ~440px/card) — mesmo colapso de
047. Sem nav lateral neste épico (chega no menu real, EPIC-002+).

```
+------------------------------------------------------------------+
|                            TURNI.                                |
|  Vagas para você                                                 |
|  (Todas) Minha função  Alto match  Candidatadas                  |
|                                                                  |
|  +---------------------------+  +---------------------------+    |
|  | Garçom          ⬢ 97      |  | Cozinheira      ⬢ 61      |    |
|  | Sex, 12/06 · 18:00–23:00  |  | Qua, 17/06 · 08:00–16:00  |    |
|  | R$ 150,00 · turno · a 3km |  | R$ 180,00 · turno · a 7km |    |
|  | match ━━━━━━━━━░ 97  Alto✓|  | match ━━━━━━░░░░ 61       |    |
|  | [     Candidatar-se     ] |  | [     Candidatar-se     ] |    |
|  +---------------------------+  +---------------------------+    |
+------------------------------------------------------------------+
```

- Diferença vs. mobile: 2 colunas, hover/focus visíveis nos cards e no botão. Largura do card ~440px;
  gap `space.md`. Paginação por scroll mantém-se (carrega ao aproximar do fim).

### Tablet (768px)

Herda o desktop com **1 coluna** de cards quando a janela não comporta duas de ~440px + gap.
`LayoutBuilder` decide 1 ou 2 colunas pela largura disponível (mesmo critério de 047: `>= 940` → 2 colunas).

---

## 4. Estados

> Toda spec entrega **todos** os estados aplicáveis (Princípio #7).

### 4.1. Caminho feliz (lista ranqueada)

Cards do filtro ativo renderizados **na ordem do endpoint** (CA-5: score DESC, boost DESC, data ASC — a UI
**não reordena**, confia no back). Filtro padrão **"Todas"**. Cada card mostra função, data/hora, valor,
distância, **número de match + barra**, e selo "Alto match" quando `score ≥ 80`. Microcopy na §5.

### 4.2. Loading (primeiro fetch e troca de filtro)

Enquanto `GET /api/feed` não responde, **skeleton de 3 cards** (não spinner em tela vazia — princípio #6).
Os chips de filtro já aparecem (não dependem do fetch). Na **troca de filtro**, a área de lista mostra o
skeleton curto enquanto re-busca (CA-5: sem reload, re-fetch).

```
+------------------------------------------+
| Vagas para você                          |
+------------------------------------------+
| (Todas) Minha função  Alto match  Cand…  |
+------------------------------------------+
|  +------------------------------------+  |
|  | ░░░░░░░░░░             ░░░          |  |
|  | ░░░░░░░░░░░░░░░░                   |  |
|  | ░░░░░░░░       ░░░░                |  |
|  | ░░░░░░━━━━━━━░░░                   |  |
|  +------------------------------------+  |
|  +------------------------------------+  |
|  | ░░░░░░░░░░             ░░░          |  |
|  +------------------------------------+  |
+------------------------------------------+
```

### 4.3. Vazio — sem vagas que se encaixam (filtro "Todas")

O profissional está ativo, mas **nenhuma vaga** atende função/raio/data agora. Estado vazio amigável,
profissional, **sem CTA de ação** (ele não publica — só aguarda surgir vaga). Explica o porquê em linguagem
simples.

```
+------------------------------------------+
| Vagas para você                          |
+------------------------------------------+
| (Todas) Minha função  Alto match  Cand…  |
+------------------------------------------+
|                 🔎                       |
|   Nenhuma vaga por aqui ainda            |
|   Assim que surgir uma vaga na sua       |
|   função e na sua região, ela aparece    |
|   aqui.                                  |
+------------------------------------------+
```

> Chips permanecem visíveis (o profissional pode trocar de filtro). Sem ilustração pesada — ícone leve +
> texto curto (tom profissional, princípio #3).

### 4.4. Vazio — por filtro (tem vagas em "Todas", filtro atual sem resultado)

Distinto do 4.3: existem vagas no feed, mas o filtro selecionado não retorna nenhuma. Mensagem específica
por filtro, com **atalho para "Todas"** (não um CTA de publicação). Chips permanecem.

```
+------------------------------------------+
| (Todas) Minha função (Alto match) Cand…  |
+------------------------------------------+
|                                          |
|   Nenhuma vaga com alto match agora.     |
|   [ Ver todas as vagas ]                 |
|                                          |
+------------------------------------------+
```

> Microcopy por filtro (§5). "Minha função" sem resultado e "Candidatadas" sem resultado têm copy própria.
> O atalho "Ver todas as vagas" só aparece quando o filtro ativo **não** é "Todas".

### 4.5. Cold start (profissional sem histórico — CA-9)

Profissional Iniciante, 0 turnos: o componente **Histórico = 0** e tipicamente **Nível = 0** (Iniciante).
O card **ainda renderiza** e a ordenação **ainda funciona** — o score apenas é menor (vem de Função +
Distância). Nenhum tratamento visual especial: o número e a barra refletem o score real (ex.: 60/100 = só
função + distância). **Não** há mensagem de "complete seu histórico" nesta tela (isso é jornada de
gamificação, fora do escopo). A barra com menos preenchimento é a única diferença visível.

### 4.6. Erro — rede / servidor no fetch

Falha de `GET /api/feed` por rede ou 5xx → `banner` no topo da área de conteúdo com **retry** visível. Os
chips de filtro continuam (mas inertes até recarregar).

```
+------------------------------------------+
| ⚠ Não foi possível carregar as vagas.    |
|   Verifique sua conexão.  [Tentar de novo]|
+------------------------------------------+
```

### 4.7. Sem permissão (contratante)

Contratante autenticado em `/feed` não vê a lista. Tela curta + saída. (Espelha o padrão de SCREEN-047
§4.6, invertendo o papel.)

```
+------------------------------------------+
|              🔒                          |
|  Esta área é do profissional             |
|  O feed de vagas é de quem pega turnos.  |
|  Sua conta é de contratante.             |
|        [ Voltar ao início ]              |
+------------------------------------------+
```

> Backend responde **403** a `GET /api/feed` para papel ≠ profissional. O front também impede a navegação
> (guard de rota / RBAC na tela).

### 4.8. Gate PDR-005 ativo (turno por avaliar — CA-8)

Profissional com turno finalizado **por avaliar**: o feed **aparece normalmente** (sem tela em branco — CA-8),
mas:

- Uma **faixa de aviso** (`gate.banner`, `warning`) no topo da lista: "Avalie seu último turno para voltar a
  se candidatar." (link/ação leva à avaliação quando o EPIC-003 existir; placeholder até lá).
- O botão **"Candidatar-se"** de cada card fica **desabilitado** com tooltip "Avalie seu último turno para
  se candidatar". O endpoint do feed **não** bloqueia — marca `pode_candidatar: false` em cada vaga.

```
+------------------------------------------+
| ⚠ Avalie seu último turno para voltar a  |  gate.banner (warning, soft)
|   se candidatar.                         |
+------------------------------------------+
|  +------------------------------------+  |
|  | Garçom                  ⬢ 97       |  |
|  | …                                  |  |
|  | [   Candidatar-se (desabilitado)  ]|  |  botão disabled + tooltip
|  +------------------------------------+  |
+------------------------------------------+
```

### 4.9. Parcial / degradado

`GET /api/feed` retorna a lista, mas um campo derivado vem ausente/nulo:
- `distancia_km` nulo (geo do profissional indisponível) → o card **omite** a linha de distância (mostra só
  valor) e a barra reflete o score real (componente distância = 0). Nunca quebra.
- `score` ausente → não esperado; defensivamente o card mostra `0/100` e barra vazia, sem quebrar o parse.

---

## 5. Microcopy completo

| Lugar | Texto |
|---|---|
| Título da tela / AppBar | Vagas para você |
| Filtro — Todas (default) | Todas |
| Filtro — Minha função | Minha função |
| Filtro — Alto match | Alto match |
| Filtro — Candidatadas | Candidatadas |
| Card — linha data/hora (exemplo) | Sex, 12/06 · 18:00–23:00 |
| Card — valor | R$ {valor} · turno |
| Card — valor + distância | R$ {valor} · turno · a {dist} km |
| Card — rótulo da barra de score | match |
| Card — número do score | {total}/100 |
| Card — selo alto match (≥80) | Alto match |
| Card — CTA candidatar | Candidatar-se |
| Card — tooltip candidatar (gate) | Avalie seu último turno para se candidatar |
| Gate banner | Avalie seu último turno para voltar a se candidatar. |
| Vazio sem vagas (título) | Nenhuma vaga por aqui ainda |
| Vazio sem vagas (corpo) | Assim que surgir uma vaga na sua função e na sua região, ela aparece aqui. |
| Vazio por filtro — minha função | Nenhuma vaga na sua função primária agora. |
| Vazio por filtro — alto match | Nenhuma vaga com alto match agora. |
| Vazio por filtro — candidatadas | Você ainda não se candidatou a nenhuma vaga. |
| Vazio por filtro — atalho | Ver todas as vagas |
| Erro de fetch (banner) | Não foi possível carregar as vagas. Verifique sua conexão. |
| Retry fetch | Tentar de novo |
| Sem permissão (título) | Esta área é do profissional |
| Sem permissão (corpo) | O feed de vagas é de quem pega turnos. Sua conta é de contratante. |
| Sem permissão (CTA) | Voltar ao início |

Vocabulário: `docs/skills/po/references/glossary.md` (Vaga, Turno, Profissional, Contratante, Candidatura,
Match). Datas/horas em pt-BR, 24h (DDR-002): dia abreviado + `dd/mm`, hora `HH:mm`, intervalo com en-dash.
Distância arredondada para inteiro de km ("a 3 km"); `< 1 km` → "a menos de 1 km". Tom:
`references/tone-and-voice.md` — direto, sem "Ops!"/emoji no corpo (ícones só sinalização leve).

---

## 6. Acessibilidade (notas específicas)

- **Score nunca só por cor (crítico):** cada card anuncia o match como **número + barra + rótulo**. A barra
  (`match.scorebar`) tem `Semantics(label: 'Match {total} de 100')` e valor; o número é texto visível
  (`{total}/100`). Faixa de qualidade ("Alto match") é **rótulo textual + ícone**, nunca só matiz.
- **Contraste:** barra preenchida com acento profissional `#2D5F3F` (claro) sobre trilho `surface.muted`
  `#E8E5DB` ≥ 3:1 (UI) ✅; número `{total}/100` em `text.strong`; selo "Alto match" `success` com rótulo
  (tokens §6). Escuro: acento `#5FA37C` sobre trilho escuro ✅.
- **Foco inicial** ao abrir: primeiro card da lista (ou o texto do estado vazio).
- **Ordem de foco:** chips de filtro (em ordem) → para cada card: corpo (abre detalhe) → "Candidatar-se" →
  próximo card. Banner de gate (quando presente) antes da lista.
- **Card como um todo:** `MergeSemantics` no cabeçalho (função + score) para o leitor anunciar de forma
  coesa antes das ações. `Semantics(button: true, label: 'Ver vaga de {função}, match {total}')` no corpo.
- **Botão "Candidatar-se" desabilitado (gate):** `Semantics(enabled: false, label: 'Candidatar-se. Avalie
  seu último turno para se candidatar')` + `Tooltip`. O motivo é lido, não só visual.
- **Chips de filtro:** `ChoiceChip` com `selected` semântico (leitor anuncia "selecionado"); navegáveis por
  teclado (seta/Tab). Alvo ≥48dp.
- **Banner/erro/gate** como `Semantics(liveRegion: true)` para anúncio assíncrono.
- **Distância** com `Semantics(label: 'a {dist} quilômetros de distância')` — não só "3 km".
- **Alvos de toque ≥48dp:** chips, corpo do card, "Candidatar-se". ✅
- **Skeleton** com `excludeSemantics` (não anuncia "carregando" repetidamente — o leitor recebe o liveRegion
  do estado quando pronto).

---

## 7. Identificadores estáveis sugeridos para teste

| Elemento | Identificador lógico sugerido |
|---|---|
| Tela (raiz) | `feed-screen` |
| Lista de cards | `feed-lista` |
| Card de vaga (por id) | `feed-card-{id}` |
| Score chip (número) do card | `feed-card-{id}-score` |
| Barra de score do card | `feed-card-{id}-score-bar` |
| Selo "Alto match" do card | `feed-card-{id}-alto-match` |
| Linha de distância do card | `feed-card-{id}-distancia` |
| Botão "Candidatar-se" do card | `feed-card-{id}-candidatar-btn` |
| Chips de filtro (por slug) | `feed-filtro-{slug}` (todas/minha_funcao/alto_match/candidatadas) |
| Estado vazio (sem vagas) | `feed-vazio` |
| Estado vazio (por filtro) | `feed-vazio-filtro` |
| Atalho "Ver todas as vagas" | `feed-vazio-filtro-todas-btn` |
| Banner de erro do fetch | `feed-erro-banner` |
| Retry do fetch | `feed-retry-btn` |
| Sem permissão (card) | `feed-sem-permissao` |
| Faixa de gate (PDR-005) | `feed-gate-banner` |
| Skeleton (loading) | `feed-skeleton` |
| Skeleton de próxima página | `feed-skeleton-proxima` |

> Nomes lógicos — o Programador aplica como `Key('...')`/`ValueKey('...')`. O E2E (CA-11) usa
> `feed-lista` + `feed-card-{id}-score` para conferir ≥3 cards ranqueados, e `feed-filtro-alto_match` para
> trocar o filtro e ver a lista atualizar.

---

## 8. Exceções ao Design System

| O que diverge | Por quê | Vira DDR? |
|---|---|---|
| `match.scorebar` — barra horizontal 0–100 (trilho `surface.muted` + preenchimento `accent` proporcional ao score) + número `{total}/100` ao lado. Acessível: `Semantics` com valor; cor nunca sozinha. | DS não tem barra de progresso/score. É o **coração visual** do EPIC-002 ("100% das vagas exibem score") e reaparece no detalhe (STORY-049, com 4 barras de breakdown) e no painel do contratante (STORY-051). Material: `LinearProgressIndicator` estilizado ou `Container` com `FractionallySizedBox`. | **Sim — forte candidato.** Promover a `match.scorebar` no DS quando STORY-049/051 reusarem (o breakdown de 049 são 4 instâncias da mesma barra). |
| `match.scorechip` — selo de número de match no canto do card (número grande + ícone hexágono ⬢). | Espelha a posição do selo de estado de 047 (consistência). Não é `badge.status` (aquele é texto de estado; este é número). | Candidato a registrar junto de `match.scorebar` no DS. |
| `gate.banner` — faixa de aviso `warning` (soft) no topo da lista quando o gate PDR-005 está ativo, com texto + ícone (não destrutivo). | DS tem `banner` genérico; esta é a **especialização "aviso acionável de pendência"** (≠ erro). Reusa tokens `warning`. Reaparece em qualquer tela que tenha gate (publicar vaga STORY-046 já usa o conceito no front). | Candidato a `banner.warning` no DS quando reaparecer formalmente. |
| `filter.choicechip` | **Já materializado em 047** (single-select, `ChoiceChip`). Aqui é **reuso** — confirma a previsão de 047 §8 de que reapareceria no feed. | **Promover a DDR/DS agora** — segundo uso confirma durabilidade (047 já marcou). Registrar em `components.md`. |
| `badge.status` (reuso parcial — selo "Alto match") | 047 §8 previu `badge.status` reaparecendo no feed. Aqui o uso é o selo "Alto match" (semântico `success`). | Mesmo encaminhamento de 047: promover a `badge.status` no DS. |

Nenhuma exceção viola token de cor/contraste — todas usam tokens auditados AA (perfil profissional + semânticos).

---

## 9. Protótipo HTML fiel (validação humana)

- **Localização:** `SCREEN-STORY-048-feed-profissional/index.html` (mesma pasta deste spec).
- **Cobertura:** seletor de viewport (mobile/desktop) + seletor de estado (chips no topo / `?state=`):
  `lista` (caminho feliz, ranqueada), `loading` (skeleton), `vazio` (sem vagas), `vazio-filtro` (alto match
  sem resultado), `cold-start` (profissional Iniciante, scores baixos), `erro` (fetch), `sem-permissao`
  (contratante), `gate` (PDR-005 — banner + botões desabilitados). Chips de filtro funcionais entre estados
  de lista.
- **Fidelidade:** tokens reais do tema profissional (verde) + semânticos; microcopy = §5 palavra por
  palavra; identificadores da §7 aplicados como `data-testid`. Datas/horas pt-BR 24h. Barra de score com
  largura proporcional ao número e selo "Alto match" quando ≥80.
- **Restrições:** HTML/CSS/JS vanilla, sem rede, abre clicando. Mock inline. Comentário no topo:
  "protótipo de validação, não código de produção".

### Checklist antes de marcar spec `ready`

- [x] `SCREEN-STORY-048-feed-profissional/index.html` abre sem erro.
- [x] Todos os estados da §4 acessíveis pelo protótipo.
- [x] Viewports mobile e desktop navegáveis.
- [x] Microcopy bate palavra por palavra com a §5.
- [x] Identificadores da §7 presentes no HTML.
- [x] Caminho feliz percorrível (lista ranqueada → trocar filtro → Alto match).
- [x] Tokens reais do DS aplicados.
- [x] Protótipo apresentado ao humano e sinal de validação capturado.

---

## 10. Dependências e premissas

- **Endpoint (contrato — não duplico; estória CA-1):**
  - `GET /api/feed?filtro=todas|minha_funcao|alto_match|candidatadas&page=N` → `{ vagas: [...], page,
    has_next }`. Cada vaga: `id`, `funcao` (nome), `data_inicio`, `data_fim`, `valor`, `distancia_km`
    (calculada, `null` se geo indisponível), `score: { total, componentes: { funcao, distancia, historico,
    nivel } }`, `ja_candidatou: bool`, `pode_candidatar: bool` (gate PDR-005 — CA-8). RBAC: 403 para
    contratante. Ordenação e cap (100) são do back (ADR-014/ADR-013) — a UI **não reordena**.
  - Score (`total` + `componentes`) vem do `MatchScore` (ADR-014, função pura já materializada em STORY-045).
    O **breakdown** completo (descrições por componente) é exibido só no **detalhe** (STORY-049) — o card usa
    `total` e, opcionalmente, os `componentes` para a barra. O card **não** mostra o breakdown textual.
- **Permissões:** papel `profissional` + `status = ativo`. Contratante → 403 / estado §4.7.
- **Premissa de back — geo do profissional:** ADR-014 marcou `lat/lng` do profissional como **pré-requisito
  desta estória** (camada de query). O back persiste geo do profissional e calcula `distancia_km`; quando o
  geo é indisponível, `distancia_km = null` e o card omite a distância (§4.9) — a vaga **ainda aparece** (não
  filtra por raio sem geo), pois esconder o feed inteiro por falta de coordenada seria pior para o usuário.
- **Gate PDR-005 (`pode_candidatar`):** stub-honesto no back (espelha `AvaliacoesPendentesContratante` de
  046) — sem turnos finalizados, `pode_candidatar = true`. A UI do gate (§4.8) é exercitada em teste com
  `pode_candidatar = false` mockado.
- **Coexistência STORY-049/050:** o corpo do card aponta para `/vaga/{id}` (detalhe) e "Candidatar-se" para
  o fluxo de candidatura. Se 049/050 não estiverem no merge, são **placeholders** (mesma estratégia do
  placeholder de "Ver candidatos" em 047).
- **Sem DDR pendente bloqueante** — spec opera dentro de DDR-001/DDR-002. As exceções §8 (`match.scorebar`,
  `match.scorechip`, `gate.banner`) são aditivas ao DS (registrar em `components.md` na implementação) e
  candidatas a DDR quando STORY-049/051 reusarem. `filter.choicechip`/`badge.status` já têm segundo uso →
  promover no DS.

---

## 11. Histórico de mudanças

| Data | Mudança | Quem | Motivo |
|---|---|---|---|
| 2026-06-02 | criação (spec completo + protótipo v1) | claude-opus-4-8 (designer) | story bem especificada; spec + protótipo entregues juntos para validação humana |
| 2026-06-02 | validação humana — aprovado; `status: shipped` | Alexandro | protótipo + app real (`/feed` logado como profissional.teste) aprovados em chat |
