---
id: SCREEN-STORY-049-detalhe-vaga
story: STORY-049-detalhe-vaga-breakdown-match
epic: EPIC-002-vaga-feed-e-candidatura
status: shipped              # draft | ready | in_implementation | shipped | superseded
created_at: 2026-06-02
updated_at: 2026-06-02
owner_designer: claude-opus-4-8
related_ddrs: [DDR-001, DDR-002]
ds_components_used: [brand.logo, surface.card, link.text, banner, badge.status, match.scorebar, match.scorechip, gate.banner]
exceptions_to_ds: [match.breakdownrow (linha do breakdown explicável — ícone + barra + label + X/Y + prosa; 4 instâncias por tela; reusa match.scorebar — §8), match.scoretotal (total agregado XX/100 em destaque com barra grande — §8)]
viewports: [mobile, desktop]
prototype_path: SCREEN-STORY-049-detalhe-vaga/index.html
prototype_last_validated_at: 2026-06-02   # validado no app real + aprovado por Alexandro em chat
---

# Spec de tela — SCREEN-STORY-049 — Detalhe da vaga + breakdown do match

> Referência: estória `STORY-049`. CAs e contexto vêm de lá — **não duplico**.
> Fundação visual: `DDR-001` + `docs/project-state/design/system/`. Locale/horário: `DDR-002` (pt-BR, 24h).
> Algoritmo/score/breakdown: `ADR-014` + `docs/especificacao/domain/match.md` (componentes 40/20/30/10,
> breakdown explicável, estados ok/partial/miss). Shape do payload: `MatchScore::toArray()` (STORY-045).
> Modelo/visibilidade: `ADR-013` + `docs/especificacao/domain/vaga.md`.
> Tela mãe: `SCREEN-STORY-048` (feed) — o card abre **esta** tela (`/vaga/{id}`). Reusa `match.scorebar`,
> `match.scorechip`, `gate.banner`, o padrão de card e a formatação pt-BR/24h.
> Tela irmã futura: `STORY-051` (painel do contratante) reusa **a mesma** `match.breakdownrow`.
> Princípios que guiaram: **#1** simplicidade (um cabeçalho + um bloco "por quê" de 4 linhas + uma ação),
> **#2** mobile-first (o profissional decide candidatar-se em pé, no celular), **#3** tom profissional
> (breakdown explica, não gameia), **#5** WCAG AA (cada componente = ícone + barra + número + prosa; cor
> nunca é o único canal), **#6** performance percebida (skeleton da tela, sem spinner branco), **#7** todos
> os estados (loading, erro, sem permissão, vaga inexistente, já candidatou, gate de avaliação).

Esta é a tela que **materializa o princípio central do Match: "o cálculo é aberto"**. No feed (STORY-048) a
vaga é um número (`97`); aqui o profissional vê **por quê** está em 97 ou em 45 — item a item, em prosa que
ele entende. Sem esta tela, o ranqueamento é uma caixa preta e o profissional não confia nem aprende a subir.
É também a casa do botão **"Candidatar-se"** (a candidatura em si é STORY-050).

---

## Tema e perfil

- Usuário **autenticado** como **profissional** → tema do papel (DDR-001): acento **verde-sage**
  (`#2D5F3F` claro / `#5FA37C` escuro). Mesmo tema do feed — continuidade visual mãe→filha.
- **Estados do breakdown (DDR-001 — cor + ícone + número, nunca só matiz):**
  - `ok` (pontuou cheio, `pontos == pontos_max`) → **success** (`#2D7A4F` claro / `#4FA374` escuro), ícone
    **✓** (`check`).
  - `partial` (pontuou parcial, `0 < pontos < pontos_max`) → **warning** (`#9A6E25` claro / `#D4A95C`
    escuro), ícone **◐** (`adjust` / meio-preenchido).
  - `miss` (zerou, `pontos == 0`) → **neutro-mudo** (`text.muted`), ícone **✕** (`close`).
  - **Decisão de design (registrada aqui, não é DDR):** `miss` usa **cinza-mudo, não vermelho**. DDR-001
    reserva vermelho para **erro/destrutivo**; um componente que zerou **não é erro** — é só ausência de
    pontos. Pintar de vermelho alarmaria sem motivo e violaria a regra de contexto da DDR-001. O ✕ cinza
    comunica "não somou aqui" sem dramatizar. A diferenciação não depende da cor (ícone + `0/40` + prosa).
- **Barra de cada componente** (`match.breakdownrow` reusa `match.scorebar`): preenchimento na **cor do
  estado** (success/warning/mudo), trilho `surface.muted`. Largura proporcional a `pontos/pontos_max`.
- **Total agregado** (`match.scoretotal`): barra grande + número `XX/100` em `text.strong`, preenchimento no
  **acento do perfil** (verde) — é o "selo" da vaga, espelha o `match.scorechip` do card no feed.
- **Gate PDR-005** (turno por avaliar): mesma `gate.banner` `warning` (soft) do feed — não é erro, é pendência
  acionável. Aqui aparece **acima do CTA**, explicando por que o botão está desabilitado.
- Marca `TURNI.` conduz no topo do desktop (igual feed). **Tema dual** (PDR-013) auditado AA.

---

## 1. Objetivo da tela

Tornar o score de match **defensável e didático**: o profissional abre a vaga, vê tudo dela num cabeçalho
enxuto e, logo abaixo, o bloco **"Por que estou vendo esta vaga"** — as 4 dimensões do match, cada uma com
ícone de estado, barra proporcional, `X/Y` pontos e uma frase curta em português. Fecha com o **total
`XX/100`** e o caminho de ação (**Candidatar-se** ou o estado **"Você já se candidatou"**). Um cabeçalho;
quatro linhas de breakdown; um total; uma ação. Nada além disso (progressive disclosure — princípio #1).

---

## 2. Fluxo

### Entrada

- **Ponto de entrada principal:** toque no **card do feed** (`/feed`, SCREEN-048) → navega para `/vaga/{id}`.
  O botão "Candidatar-se" do card também leva aqui (a candidatura mora nesta tela / STORY-050).
- **Deep-link:** `/vaga/{id}` é navegável direto (URL). Carrega via `GET /api/vagas/{id}/detalhe`.
- **Pré-condições:** sessão ativa (`status = ativo`), papel = `profissional`. Funnel guard (STORY-016)
  garante sessão; a tela trata o RBAC no fetch.
- **RBAC (CA-7):** `contratante` autenticado → backend responde **403** → estado **Sem permissão** (§4.6).
  Profissional **não-`ativo`** → 403/redireciono para completar cadastro (o funnel guard já intercepta antes).

### Ações possíveis na tela

- **Voltar** — AppBar com seta de retorno → volta ao feed mantendo o filtro/scroll anterior (`context.pop()`
  quando há pilha; senão `go('/feed')`).
- **Candidatar-se** — CTA primário fixo no rodapé. Habilitado quando `pode_candidatar == true` **e**
  `ja_candidatou == false`. Clique chama o endpoint da STORY-050 — **até 050 estar done, é placeholder**:
  log + `SnackBar` "Candidatura chega na próxima etapa." (mesma estratégia de placeholder de 047/048).
- **Retirar candidatura** — quando `ja_candidatou == true` e a candidatura está `pendente`: link discreto
  "Retirar candidatura" abaixo do badge (chama endpoint STORY-050; placeholder até lá).
- **Tentar de novo** — no estado de erro de rede (§4.5), re-busca o detalhe.

### Saída

- **Voltar:** retorna ao feed.
- **Após candidatar (STORY-050):** o CTA vira o badge "Você já se candidatou" in-place (otimismo visual);
  toast de confirmação. (Comportamento final é de 050; aqui o slot já existe.)
- **Vaga sumiu/fechou entre o feed e o detalhe:** estado **Vaga indisponível** (§4.7) com volta ao feed.

---

## 3. Layout

### Mobile (≥360px)

`Scaffold` com `AppBar` (seta voltar + título "Detalhe da vaga"). Corpo rolável: **cabeçalho da vaga**
(função em destaque + score chip; estabelecimento; data/hora; valor; distância), divisor, **bloco do
breakdown** (título "Por que estou vendo esta vaga" + 4 `breakdownrow` + total agregado). CTA **"Candidatar-se"**
fixo no rodapé (`bottomNavigationBar`/`SafeArea` — sempre visível, não exige rolar até o fim).

```
+------------------------------------------+
| ←  Detalhe da vaga                        |  AppBar (voltar + título)
+------------------------------------------+
|  Garçom                        ⬢ 97       |  função (título) + score chip
|  Bar do Zé · São Paulo                    |  estabelecimento curto · cidade
|  Sex, 12/06 · 18:00–23:00                 |  data/hora 24h pt-BR (DDR-002)
|  R$ 150,00 · turno · a 3 km               |  valor · distância
|  ----------------------------------------  |  divisor
|  Por que estou vendo esta vaga            |  título do bloco
|                                           |
|  ✓ Função          ━━━━━━━━━ 40/40        |  breakdownrow (ok, success)
|     Sua função primária bate              |    prosa curta
|  ✓ Distância       ━━━━━━━━━ 20/20        |  breakdownrow (ok)
|     Dentro do seu raio de 8km             |
|  ◐ Histórico       ━━━━━━━░░ 27/30        |  breakdownrow (partial, warning)
|     Sua média 4.9★ em 127 turnos          |
|  ✓ Nível na trilha ━━━━━━━━━ 10/10        |  breakdownrow (ok)
|     Elite na trilha                       |
|  ----------------------------------------  |
|  Match total       ━━━━━━━━━ 97/100       |  match.scoretotal (acento, destaque)
+------------------------------------------+
| [           Candidatar-se            ]    |  CTA fixo (button.primary, verde)
+------------------------------------------+
```

- Componentes do DS: `surface.card` (cabeçalho), `badge.status` (selo "Alto match" quando total ≥80, no
  cabeçalho ao lado do chip), `gate.banner` (quando gate ativo), `match.scorechip`; + novos:
  `match.breakdownrow`, `match.scoretotal` (§8).
- **Ordem dos componentes é fixa** (Função → Distância → Histórico → Nível) — segue a tabela de
  `domain/match.md` (a estória proíbe reordenar). A UI **não** ordena por pontos.
- Alvos de toque ≥48dp: seta voltar, CTA, link "Retirar candidatura".

### Desktop (≥1024px)

Conteúdo centralizado, largura máxima ~720px (tela de leitura, não dashboard — princípio #1/#2). Marca
`TURNI.` no topo. Cabeçalho e breakdown empilhados (não há segunda coluna a inventar — a tela é uma coluna de
leitura). CTA **não** vira rodapé fixo no desktop: fica ao fim do conteúdo, largura do bloco, com hover/focus
visíveis. Sem nav lateral neste épico.

```
+------------------------------------------------------------------+
|                            TURNI.                                |
|   ←  Detalhe da vaga                                             |
|   +----------------------------------------------------------+  |
|   |  Garçom                                       ⬢ 97  Alto✓ |  |
|   |  Bar do Zé · São Paulo                                   |  |
|   |  Sex, 12/06 · 18:00–23:00 · R$ 150,00 · turno · a 3 km   |  |
|   +----------------------------------------------------------+  |
|   Por que estou vendo esta vaga                                 |
|   ✓ Função           ━━━━━━━━━━━━━━━━━ 40/40                     |
|      Sua função primária bate                                   |
|   ✓ Distância        ━━━━━━━━━━━━━━━━━ 20/20                     |
|      Dentro do seu raio de 8km                                  |
|   ◐ Histórico        ━━━━━━━━━━━━━░░░░ 27/30                     |
|      Sua média 4.9★ em 127 turnos                               |
|   ✓ Nível na trilha  ━━━━━━━━━━━━━━━━━ 10/10                     |
|      Elite na trilha                                            |
|   ────────────────────────────────────────────                 |
|   Match total        ━━━━━━━━━━━━━━━━━ 97/100                    |
|                                                                 |
|   [                  Candidatar-se                   ]          |
+------------------------------------------------------------------+
```

- Diferença vs. mobile: largura travada ~720px, selo "Alto match" ao lado do chip no cabeçalho (cabe na
  linha), data/valor/distância podem caber numa linha só, CTA não-fixo. Hover/focus em CTA e links.

### Tablet (≥600/768px)

Herda o desktop com a mesma coluna única ~720px centralizada. Não há master-detail aqui (a tela já é o
"detail" do feed). CTA segue o comportamento do desktop (ao fim do conteúdo) acima de ~600px; abaixo disso,
rodapé fixo como no mobile. `LayoutBuilder` decide pelo breakpoint.

---

## 4. Estados

> Toda spec entrega **todos** os estados aplicáveis (Princípio #7).

### 4.1. Caminho feliz (breakdown completo)

Cabeçalho + 4 `breakdownrow` na ordem canônica + total. Estados de cada linha derivados do `estado` do
payload (`ok`/`partial`/`miss`) — a UI **não recalcula**, confia no back (CA-3 já é garantido no backend).
CTA "Candidatar-se" habilitado. Selo "Alto match" no cabeçalho quando `total ≥ 80`. Microcopy na §5.

### 4.2. Loading (primeiro fetch)

Enquanto `GET /api/vagas/{id}/detalhe` não responde, **skeleton da tela** (cabeçalho fantasma + 4 linhas
fantasma + barra do total) — não spinner em tela branca (princípio #6). O CTA do rodapé aparece desabilitado
em estado neutro durante o load.

```
+------------------------------------------+
| ←  Detalhe da vaga                        |
+------------------------------------------+
|  ░░░░░░░░░░░░              ░░░            |
|  ░░░░░░░░░░░░░░░░                        |
|  ░░░░░░░░       ░░░░                     |
|  ----------------------------------------  |
|  ░░░░░  ░░░░░░░━━━━━━━░░░  ░░░           |
|  ░░░░░  ░░░░░░░━━━━━━━░░░  ░░░           |
|  ░░░░░  ░░░░░░░━━━━━━━░░░  ░░░           |
|  ░░░░░  ░░░░░░░━━━━━━━░░░  ░░░           |
+------------------------------------------+
| [ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ ]    |
+------------------------------------------+
```

### 4.3. Já candidatou (CA-6)

`ja_candidatou == true`: o CTA **não** aparece como botão de ação. No lugar, um **badge** "Você já se
candidatou" (`success`, soft) com a data/hora da candidatura. Se a candidatura está **`pendente`**, abaixo do
badge surge o link discreto **"Retirar candidatura"** (STORY-050; placeholder até lá). O breakdown continua
visível normalmente (o profissional ainda quer entender o porquê).

```
+------------------------------------------+
| ✓ Você já se candidatou                  |  badge success (soft)
|   em 02/06 às 14:20                       |
|   Retirar candidatura                     |  link (só se pendente)
+------------------------------------------+
```

### 4.4. Bloqueado por gate / motivo (CA-5)

`pode_candidatar == false` e `ja_candidatou == false`: o CTA fica **desabilitado** e, **acima dele**, uma
`gate.banner` (`warning`, soft) com o `motivo_bloqueio` em prosa. O breakdown permanece visível. Motivos
possíveis (texto vem do backend, a UI só exibe):

- **Avaliação pendente (PDR-005, único implementado no MVP):** "Avalie seu último turno para se candidatar."
- **Conflito de horário (STORY-050+):** "Você já tem um turno neste horário." *(slot pronto; lógica em 050.)*
- **Habitualidade (STORY-050+):** "Habitualidade — você já tem 2 alocações nesta semana neste local."
  *(slot pronto; lógica em 050.)*

```
+------------------------------------------+
| ⚠ Avalie seu último turno para se        |  gate.banner (warning, soft)
|   candidatar.                             |
+------------------------------------------+
| [        Candidatar-se (desab.)       ]   |  CTA disabled + tooltip = motivo
+------------------------------------------+
```

> Tooltip do botão desabilitado = o mesmo `motivo_bloqueio`. Botão habilitado **só** quando
> `pode_candidatar && !ja_candidatou` (CA-5).

### 4.5. Erro — rede / 5xx no fetch

Falha de `GET /api/vagas/{id}/detalhe` por rede/5xx → estado de erro centrado com **retry**, sem cabeçalho
falso. Espelha o `feed-erro-banner` (consistência com 048).

```
+------------------------------------------+
|              ⚠                           |
|  Não foi possível carregar a vaga.       |
|  Verifique sua conexão.                   |
|        [ Tentar de novo ]                 |
+------------------------------------------+
```

### 4.6. Sem permissão (contratante — CA-7)

Contratante autenticado em `/vaga/{id}` → backend **403** → tela curta + saída. Espelha o
`feed-sem-permissao` de 048 (mesma copy/forma).

```
+------------------------------------------+
|              🔒                          |
|  Esta área é do profissional             |
|  O detalhe de vagas é de quem pega turnos.|
|  Sua conta é de contratante.             |
|        [ Voltar ao início ]              |
+------------------------------------------+
```

### 4.7. Vaga indisponível (404 / fechou / cancelou)

`GET` retorna **404** (vaga inexistente, ou não mais visível para este profissional — fechou/cancelou/saiu do
raio entre o feed e o toque). Estado dedicado, com volta ao feed. **Não** é erro de rede — é "essa vaga não
está mais disponível".

```
+------------------------------------------+
|              ⃠                           |
|  Esta vaga não está mais disponível      |
|  Ela pode ter sido preenchida ou         |
|  encerrada. Veja outras no seu feed.     |
|        [ Voltar ao feed ]                 |
+------------------------------------------+
```

### 4.8. Parcial / degradado

- `distancia_km` nulo (geo indisponível) → cabeçalho **omite** a distância (mostra valor) e a `breakdownrow`
  de Distância mostra `0/20` com estado `miss` e prosa "Localização indisponível" (vinda do back). Nunca
  quebra.
- `estabelecimento` ausente/nulo → cabeçalho mostra só a cidade; se ambos nulos, omite a linha. Defensivo.
- `score.breakdown` com componente ausente → não esperado (back garante os 4); defensivamente a linha
  faltante é omitida sem quebrar o parse, e o total usa `score.total`.

---

## 5. Microcopy completo

| Lugar | Texto |
|---|---|
| AppBar — título | Detalhe da vaga |
| Cabeçalho — função | {nome da função} |
| Cabeçalho — estabelecimento · cidade | {estabelecimento} · {cidade} |
| Cabeçalho — data/hora (exemplo) | Sex, 12/06 · 18:00–23:00 |
| Cabeçalho — valor | R$ {valor} · turno |
| Cabeçalho — valor + distância | R$ {valor} · turno · a {dist} km |
| Cabeçalho — selo alto match (≥80) | Alto match |
| Bloco breakdown — título | Por que estou vendo esta vaga |
| Linha — label Função | Função |
| Linha — label Distância | Distância |
| Linha — label Histórico | Histórico |
| Linha — label Nível | Nível na trilha |
| Linha — valor pontos | {pontos}/{pontos_max} |
| Linha — descrição | {descricao do back, ex.: "Sua função primária bate"} |
| Total — label | Match total |
| Total — número | {total}/100 |
| CTA candidatar | Candidatar-se |
| CTA candidatar — placeholder (até STORY-050) | Candidatura chega na próxima etapa. |
| Tooltip CTA desabilitado | {motivo_bloqueio} |
| Já candidatou — badge | Você já se candidatou |
| Já candidatou — data | em {dd/mm} às {HH:mm} |
| Já candidatou — retirar (se pendente) | Retirar candidatura |
| Gate/bloqueio — avaliação (PDR-005) | Avalie seu último turno para se candidatar. |
| Gate/bloqueio — conflito horário (050+) | Você já tem um turno neste horário. |
| Gate/bloqueio — habitualidade (050+) | Habitualidade — você já tem 2 alocações nesta semana neste local. |
| Erro de fetch (título) | Não foi possível carregar a vaga. |
| Erro de fetch (corpo) | Verifique sua conexão. |
| Erro de fetch (retry) | Tentar de novo |
| Sem permissão (título) | Esta área é do profissional |
| Sem permissão (corpo) | O detalhe de vagas é de quem pega turnos. Sua conta é de contratante. |
| Sem permissão (CTA) | Voltar ao início |
| Vaga indisponível (título) | Esta vaga não está mais disponível |
| Vaga indisponível (corpo) | Ela pode ter sido preenchida ou encerrada. Veja outras no seu feed. |
| Vaga indisponível (CTA) | Voltar ao feed |

As **descrições das linhas** (`descricao`) vêm prontas do backend (`MatchCalculator` — STORY-045): a UI as
exibe verbatim, não as compõe. Datas/horas pt-BR 24h (DDR-002). Distância: inteiro de km ("a 3 km");
`< 1 km` → "a menos de 1 km". Vocabulário: `glossary.md`. Tom: direto, sem "Ops!"/emoji no corpo.

---

## 6. Acessibilidade (notas específicas)

- **Breakdown nunca só por cor (crítico):** cada `breakdownrow` anuncia **ícone com label + número + prosa**.
  A barra tem `Semantics(label: '{Label}: {pontos} de {pontos_max} pontos · {descricao}')`. Exemplo:
  "Função: 40 de 40 pontos · Sua função primária bate" (CA-8). O ícone de estado tem `Semantics(label:)`:
  ✓ "atende", ◐ "atende parcialmente", ✕ "não atende".
- **Total agregado:** `Semantics(label: 'Match total {total} de 100')` + número visível.
- **Contraste:** success `#2D7A4F` / warning `#9A6E25` / mudo `text.muted` sobre `surface` — todos AA
  (tokens DDR-001 auditados). Barras: preenchimento sobre trilho `surface.muted` ≥ 3:1 (UI). Escuro idem.
- **Foco inicial** ao abrir: o cabeçalho (função). **Ordem de foco:** voltar → cabeçalho → linhas do
  breakdown (em ordem) → total → CTA (ou badge "já candidatou" → "retirar").
- **CTA desabilitado:** `Semantics(enabled: false, label: 'Candidatar-se. {motivo_bloqueio}')` + `Tooltip`.
  O motivo é lido, não só visual.
- **Gate banner / erro:** `Semantics(liveRegion: true)` para anúncio assíncrono.
- **`MergeSemantics`** no cabeçalho (função + score + selo) para anúncio coeso.
- **Alvos de toque ≥48dp:** seta voltar, CTA, "Retirar candidatura". Skeleton com `excludeSemantics`.

---

## 7. Identificadores estáveis sugeridos para teste

| Elemento | Identificador lógico sugerido |
|---|---|
| Tela (raiz) | `vaga-detalhe-screen` |
| Cabeçalho (container) | `vaga-detalhe-cabecalho` |
| Função (título) | `vaga-detalhe-funcao` |
| Score chip (número) | `vaga-detalhe-score-chip` |
| Selo "Alto match" | `vaga-detalhe-alto-match` |
| Linha de distância | `vaga-detalhe-distancia` |
| Bloco do breakdown | `vaga-detalhe-breakdown` |
| Linha do breakdown (por componente) | `vaga-detalhe-breakdown-{componente}` (funcao/distancia/historico/nivel) |
| Barra da linha | `vaga-detalhe-breakdown-{componente}-bar` |
| Ícone de estado da linha | `vaga-detalhe-breakdown-{componente}-icone` |
| Total agregado | `vaga-detalhe-total` |
| Barra do total | `vaga-detalhe-total-bar` |
| CTA candidatar | `vaga-detalhe-candidatar-btn` |
| Badge "já candidatou" | `vaga-detalhe-ja-candidatou` |
| Link "retirar candidatura" | `vaga-detalhe-retirar-btn` |
| Banner de gate/bloqueio | `vaga-detalhe-gate-banner` |
| Estado erro | `vaga-detalhe-erro` |
| Retry | `vaga-detalhe-retry-btn` |
| Estado sem permissão | `vaga-detalhe-sem-permissao` |
| Estado vaga indisponível | `vaga-detalhe-indisponivel` |
| Skeleton (loading) | `vaga-detalhe-skeleton` |

> Nomes lógicos — o Programador aplica como `Key('...')`. O E2E (CA-10) usa `feed-card-{id}` (mãe) →
> `vaga-detalhe-breakdown-funcao` … `-nivel` para conferir os 4 componentes, e `vaga-detalhe-total`.

---

## 8. Exceções ao Design System

| O que diverge | Por quê | Vira DDR? |
|---|---|---|
| `match.breakdownrow` — linha do breakdown: ícone de estado (✓/◐/✕) + label + `match.scorebar` (na cor do estado) + `{pontos}/{pontos_max}` + descrição em prosa abaixo. 4 instâncias por tela. | É o **coração visual** desta estória ("cálculo aberto"). Reusa `match.scorebar` (de 048) com a cor variando por estado. **Reaparece idêntico em STORY-051** (painel do contratante). Material: `Row` + `Icon` + barra + `Text`. | **Sim — forte candidato.** Promover `match.scorebar` + `match.breakdownrow` ao DS quando STORY-051 reusar (3º uso da barra confirma durabilidade). |
| `match.scoretotal` — total agregado: barra grande no acento do perfil + `{total}/100` em destaque. | Fecha o breakdown com o número-herói. Variação de `match.scorebar` (mais alta, acento de perfil, não de estado). | Candidato a registrar junto de `match.scorebar` no DS. |
| `match.scorechip` (reuso de 048) | Já materializado em 048; aqui reaparece no cabeçalho. **2º uso confirma durabilidade.** | **Promover ao DS agora** junto da família `match.*`. |
| `gate.banner` (reuso de 048) | Já materializado em 048 (feed). Aqui é o **3º** contexto (publicar 046, feed 048, detalhe 049). | **Promover a `banner.warning` no DS** — uso recorrente confirmado. |
| `badge.status` (reuso — selo "Alto match" + badge "Você já se candidatou") | 048 já usou para "Alto match". Aqui reaparece + ganha a variante `success` "já candidatou". | Promover ao DS (já previsto em 047/048). |

Nenhuma exceção viola token de cor/contraste — todas usam tokens auditados AA (perfil + semânticos). A
decisão `miss = cinza-mudo` (não vermelho) está justificada em §Tema e respeita a regra de contexto DDR-001.

---

## 9. Protótipo HTML fiel (validação humana)

- **Localização:** `SCREEN-STORY-049-detalhe-vaga/index.html` (mesma pasta deste spec).
- **Cobertura:** seletor de viewport (mobile/desktop) + seletor de estado (`?state=`): `completo` (caminho
  feliz, 97/100 com 1 partial), `parcial-baixo` (score baixo, mix ok/partial/miss + distância miss),
  `loading` (skeleton), `ja-candidatou` (badge + retirar), `gate` (avaliação pendente — banner + CTA
  desabilitado), `erro` (fetch), `sem-permissao` (contratante), `indisponivel` (404).
- **Fidelidade:** tokens reais do tema profissional (verde) + semânticos (success/warning/mudo); microcopy =
  §5 palavra por palavra; identificadores da §7 como `data-testid`. Datas/horas pt-BR 24h. Barras com largura
  proporcional aos pontos; ícone de estado por linha. Ordem fixa Função→Distância→Histórico→Nível.
- **Restrições:** HTML/CSS/JS vanilla, sem rede, abre clicando. Mock inline. Comentário no topo: "protótipo
  de validação, não código de produção".

### Checklist antes de marcar spec `ready`

- [x] `SCREEN-STORY-049-detalhe-vaga/index.html` abre sem erro.
- [x] Todos os estados da §4 acessíveis pelo protótipo.
- [x] Viewports mobile e desktop navegáveis.
- [x] Microcopy bate palavra por palavra com a §5.
- [x] Identificadores da §7 presentes no HTML.
- [x] Breakdown nos 3 estados (ok/partial/miss) visível em pelo menos um estado.
- [x] Tokens reais do DS aplicados.
- [x] Protótipo apresentado ao humano e sinal de validação capturado.

---

## 10. Dependências e premissas

- **Endpoint (contrato — estória CA-1):**
  - `GET /api/vagas/{id}/detalhe` (autenticado) → shape unificado:
    `{ id, funcao, estabelecimento, cidade, data_inicio, data_fim, valor, distancia_km,
    score_breakdown: { total, componentes, breakdown: { funcao, distancia, historico, nivel } },
    pode_candidatar: bool, ja_candidatou: bool, candidatura: { estado, criada_em } | null,
    motivo_bloqueio: string|null }`.
  - `score_breakdown` é exatamente `MatchScore::toArray()` (STORY-045) — cada item do `breakdown` tem
    `pontos`, `pontos_max`, `estado` (`ok`/`partial`/`miss`), `descricao`. A UI **não recalcula** estado nem
    total.
  - RBAC: **403** para contratante; **404** para vaga inexistente ou não-visível ao profissional.
  - `motivo_bloqueio` ≠ null **somente** quando `pode_candidatar == false` (tooltip + banner).
- **Permissões:** papel `profissional` + `status = ativo`. Contratante → 403 / §4.6.
- **Gate PDR-005 (`pode_candidatar`):** mesmo stub-honesto de 048 (`AvaliacoesPendentesProfissional`) — sem
  turnos finalizados, `pode_candidatar = true` e `motivo_bloqueio = null`. A UI do gate (§4.4) é exercitada em
  teste com `pode_candidatar = false` + motivo mockado. Conflito de horário e habitualidade são **slots**
  prontos no contrato (`motivo_bloqueio`), com lógica em STORY-050.
- **Coexistência STORY-050:** "Candidatar-se" e "Retirar candidatura" são **placeholders** (log + toast) até
  050 entrar — mesma estratégia dos placeholders de 047/048. O slot visual e os identificadores já existem.
- **Sem DDR pendente bloqueante** — spec opera dentro de DDR-001/DDR-002. As exceções §8 (`match.breakdownrow`,
  `match.scoretotal`) são aditivas; a família `match.*` + `gate.banner` + `badge.status` já têm 2º/3º uso →
  **promover ao DS na implementação** (registrar em `components.md`).

---

## 11. Histórico de mudanças

| Data | Mudança | Quem | Motivo |
|---|---|---|---|
| 2026-06-02 | criação (spec completo + protótipo v1) | claude-opus-4-8 (designer) | story bem especificada; spec + protótipo entregues para validação humana, em paralelo ao início da implementação |
| 2026-06-02 | validação humana no app real — aprovado; `status: shipped` | Alexandro | tela renderizada após `flutter build web`; spec + implementação aprovados em chat |
