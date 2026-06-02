---
id: SCREEN-STORY-051-painel-candidatos
story: STORY-051-painel-candidatos-contratante
epic: EPIC-002-vaga-feed-e-candidatura
status: ready                # draft | ready | in_implementation | shipped | superseded
created_at: 2026-06-02
updated_at: 2026-06-02
owner_designer: claude-opus-4-8
related_ddrs: [DDR-001, DDR-002]
ds_components_used: [brand.logo, surface.card, avatar, badge.status, badge.nivel, match.scorechip, match.scorebar, match.breakdownrow, gate.banner, button.primary, button.text]
exceptions_to_ds: [avatar (foto circular do profissional com fallback de iniciais — §8; 1º uso no app), badge.nivel (selo do nível na trilha Iniciante/Confiável/Destaque/Elite — §8), habitualidade.badge (selo laranja de alerta de habitualidade no card — reusa banner.warning em formato pill — §8)]
viewports: [mobile, desktop]
prototype_path: SCREEN-STORY-051-painel-candidatos/index.html
prototype_last_validated_at: null   # a validar no app real + chat (humano)
---

# Spec de tela — SCREEN-STORY-051 — Painel de candidatos do contratante

> Referência: estória `STORY-051`. CAs e contexto vêm de lá — **não duplico**.
> Lado **espelho** de `SCREEN-STORY-049` (detalhe do profissional): mesma `match.breakdownrow`,
> mesma transparência (o contratante vê o **mesmo** breakdown que o profissional viu — simetria
> de `domain/match.md` §Visibilidade). Aqui o sujeito é o **contratante** revisando **quem se
> candidatou** à sua vaga, ranqueado por score.
> Tela mãe: `SCREEN-STORY-047` ("Minhas vagas") — o link "Ver candidatos" do card abre **esta**
> tela (`/contratante/vagas/{id}/candidatos`). Esta spec **substitui** o placeholder que 047
> deixou na rota.
> Fundação visual: `DDR-001` + `docs/project-state/design/system/`. Locale/horário: `DDR-002`
> (pt-BR, 24h). Algoritmo/score/breakdown: `ADR-014` + `domain/match.md`. Snapshot: o
> `score_no_momento` + `score_breakdown` são os **persistidos no instante da candidatura**
> (STORY-050) — a UI **não recalcula** (CA-2/CA-4).
> Tema do papel: **contratante** (acento mostarda DDR-001), espelhando "Minhas vagas" (047).
> Princípios que guiaram: **#1** simplicidade (uma lista ranqueada + breakdown sob demanda),
> **#2** mobile-first (o gestor abre no celular pra ver quem chegou), **#3** tom profissional
> (ranking explicado, não gameado), **#5** WCAG AA (score = chip + barra + número + prosa, nunca
> só cor), **#6** performance percebida (skeleton, sem spinner branco), **#7** todos os estados
> (loading, vazio com SLA, erro, sem permissão, lista, breakdown expandido, alerta de
> habitualidade, ações desabilitadas com tooltip do EPIC-003).

Esta tela **fecha o ciclo do EPIC-002 do lado do contratante**: ele publicou (046), viu a vaga
em "Minhas vagas" (047), e agora **vê quem se candidatou** — ranqueado por match, com o porquê
clicável. Aprovar **não** vira turno aqui (é EPIC-003); a tela **prepara** — mostra quem tem, com
qual score, e deixa o "Aceitar" como promessa visível (botão desabilitado, com a razão honesta).

---

## Tema e perfil

- Usuário **autenticado** como **contratante dono da vaga** → tema do papel (DDR-001): acento
  **mostarda** (`#9A6E25` claro / `#D4A95C` escuro; tinta de link/texto `#6E4E12` claro). Mesmo
  tema de "Minhas vagas" (047) — continuidade mãe→filha.
- **Score do candidato (`match.scorechip` + `match.scorebar`):** o chip ⬢ e a barra grande do
  card usam o **acento do contratante** (mostarda) — é o "selo" de ranking do candidato, espelho
  do chip que o profissional vê no feed/detalhe, mas no tema de quem contrata.
- **Breakdown expandido (`match.breakdownrow`):** **idêntico** a 049 — ícone de estado
  (✓ success / ◐ warning / ✕ mudo) + barra na cor do estado + `X/Y` + prosa. O estado de cada
  componente vem do `score_breakdown` **persistido** (CA-4) — a UI confia, não recalcula. A cor
  de estado do breakdown é **semântica** (success/warn/mudo), independente do acento do papel —
  o breakdown é "verdade do match", não chrome do contratante.
- **Alerta de habitualidade (`habitualidade.badge`):** pill **warning** (laranja-mostarda
  `#9A6E25`/`#D4A95C` soft) com ícone ⚠ no card do candidato MEI/PJ na 3ª alocação (CA-5). Não é
  erro (não vermelho) — é uma sinalização para a decisão futura do contratante (override no
  aceite, EPIC-003). Coexiste com o acento mostarda do papel: distingue-se por ser pill soft com
  ícone + texto explícito (cor nunca é o único canal — princípio #5).
- **Nível (`badge.nivel`):** selo neutro com o rótulo da trilha (Iniciante/Confiável/Destaque/
  Elite). Informativo, sóbrio — `surface.muted` + texto forte, sem competir com o score.
- **Ações desabilitadas (`button.primary` disabled + `button.text` disabled):** "Aceitar
  candidatura" e "Remover candidato" ficam **desabilitados** com tooltip honesto — a tela não
  finge o que ainda não existe (EPIC-003). Cinza-mudo, não destrutivo.
- Marca `TURNI.` no topo do desktop. **Tema dual** (PDR-013) auditado AA.

---

## 1. Objetivo da tela

Dar ao contratante uma **lista ranqueada e legível** dos candidatos da sua vaga: quem é (avatar,
nome, função, nível), **qual o match** (score 0–100 com barra) e **por quê** (breakdown clicável,
o mesmo do profissional). Ordem fixa por score (CA-2). Sem aceite ainda (EPIC-003) — a tela
**prepara** a decisão, não a executa. Uma lista; um score por candidato; um breakdown sob
demanda; ações futuras anunciadas com honestidade. Nada além disso (progressive disclosure — #1).

---

## 2. Fluxo

### Entrada

- **Ponto de entrada principal:** link **"Ver candidatos"** no card de "Minhas vagas" (047,
  `vaga-card-{id}-ver-candidatos`) → navega para `/contratante/vagas/{id}/candidatos`.
- **Deep-link:** a rota é navegável direto (URL). Carrega via
  `GET /api/vagas/{id}/candidatos`.
- **Pré-condições:** sessão ativa (`status = ativo`), papel = `contratante`, **dono da vaga**.
- **RBAC (CA-1):** contratante **não-dono** → backend **403** → estado **Sem permissão** (§4.5).
  **Profissional** autenticado → **403** → mesmo estado. Vaga inexistente → **404** (§4.6).

### Ações possíveis na tela

- **Voltar** — AppBar com seta → volta a "Minhas vagas" (`context.pop()` quando há pilha; senão
  `go('/contratante/vagas')`).
- **Ver breakdown / Ocultar breakdown** — por candidato, expande/colapsa as 4 linhas do
  breakdown in-place (CA-4). Estado local do card; vários podem ficar abertos.
- **Aceitar candidatura** (por card) — **desabilitado** com tooltip "Disponível no EPIC-003 —
  Aceite, PIN e Pix" (CA-6). Proposital.
- **Remover candidato** (por card) — **desabilitado** com tooltip "Disponível no EPIC-003"
  (recusa é Lacuna do MVP — CA-6).
- **Tentar de novo** — no estado de erro de rede (§4.4), re-busca a lista.

### Saída

- **Voltar:** retorna a "Minhas vagas".
- Não há navegação adiante nesta estória (o aceite — que abriria o turno — é EPIC-003).

```
[ Minhas vagas /contratante/vagas ] ──tap "Ver candidatos"──► [ painel /…/candidatos ]
        ▲                                                              │
        └───────────────────── seta Voltar ────────────────────────────┘

  no painel:  tap "Ver breakdown"  → expande 4 breakdownrow in-place (toggle)
              "Aceitar"/"Remover"  → desabilitados (tooltip EPIC-003)
```

---

## 3. Layout

### Mobile (≥360px)

`Scaffold` com `AppBar` (seta voltar + título "Candidatos"). Abaixo do AppBar, uma **faixa de
contexto da vaga** (função · data/hora · "N candidatos") para o contratante saber de qual vaga é.
Corpo: **lista rolável de cards de candidato** (`ListView`), um por candidatura, na ordem
ranqueada (CA-2). Cada card:

```
+------------------------------------------+
| ←  Candidatos                             |  AppBar (voltar + título)
+------------------------------------------+
|  Garçom · Sex, 12/06 · 18:00–23:00        |  faixa de contexto da vaga
|  3 candidatos                             |  contagem (total)
+------------------------------------------+
| ┌──────────────────────────────────────┐ |
| │ (JS)  Júlia Santos          ⬢ 92      │ |  avatar + nome + score chip
| │       Garçom · Elite                  │ |  função primária · nível
| │       ━━━━━━━━━━━━━━━━━░░  92/100      │ |  match.scorebar (acento) + número
| │       Candidatou Sex, 12/06 · 14:20    │ |  data/hora pt-BR 24h (DDR-002)
| │       ▸ Ver breakdown                 │ |  toggle (collapsed)
| │  ───────────────────────────────────  │ |
| │  [ Aceitar candidatura ] (desab.)     │ |  button.primary disabled + tooltip
| │  Remover candidato (desab.)           │ |  button.text disabled + tooltip
| └──────────────────────────────────────┘ |
| ┌──────────────────────────────────────┐ |
| │ (BC)  Bruno Costa           ⬢ 88   ⚠  │ |  + habitualidade.badge (alerta)
| │       Cozinheiro · Destaque           │ |
| │       ━━━━━━━━━━━━━━━━░░░  88/100      │ |
| │       ⚠ Habitualidade — 3ª alocação    │ |  badge laranja (CA-5)
| │         na semana                     │ |
| │       ▾ Ocultar breakdown             │ |  toggle (expanded)
| │       ✓ Função     ━━━━━━━━━ 40/40     │ |  match.breakdownrow (reuso 049)
| │          Função primária bate          │ |
| │       ◐ Distância  ━━━━━━━░░ 14/20     │ |
| │          A 6 km do estabelecimento     │ |
| │       ◐ Histórico  ━━━━━━━░░ 26/30     │ |
| │          Média 4,7★ em 64 turnos       │ |
| │       ✓ Nível      ━━━━━━━━━ 6/10      │ |
| │          Destaque na trilha            │ |
| │  ───────────────────────────────────  │ |
| │  [ Aceitar candidatura ] (desab.)     │ |
| │  Remover candidato (desab.)           │ |
| └──────────────────────────────────────┘ |
+------------------------------------------+
```

- Componentes do DS: `surface.card` (card do candidato), `avatar` (foto/iniciais — §8),
  `badge.nivel` (§8), `match.scorechip` + `match.scorebar` (reuso 048/049 no acento do
  contratante), `match.breakdownrow` (reuso **idêntico** de 049), `habitualidade.badge` (§8),
  `button.primary`/`button.text` (desabilitados).
- **Ordem dos cards é fixa** (`score_no_momento DESC, plano_boost DESC, candidatou_em ASC` —
  CA-2). A UI **não** reordena no cliente (vem ordenado do back).
- **Ordem das linhas do breakdown é fixa** (Função → Distância → Histórico → Nível) — `domain/
  match.md`, igual 049.
- Alvos de toque ≥48dp: seta voltar, toggle "Ver breakdown", e — quando habilitados em EPIC-003
  — os botões de ação.

### Desktop (≥1024px)

Conteúdo centralizado, largura máxima ~720px (lista de leitura, não dashboard — #1/#2). Marca
`TURNI.` no topo. Mesma lista de cards em coluna única (o card já é largo o suficiente; não há
master-detail a inventar nesta estória). Hover/focus visíveis no toggle e nos botões.

```
+------------------------------------------------------------------+
|                            TURNI.                                |
|   ←  Candidatos                                                 |
|   Garçom · Sex, 12/06 · 18:00–23:00 · 3 candidatos              |
|   +----------------------------------------------------------+  |
|   | (JS) Júlia Santos                              ⬢ 92      |  |
|   |      Garçom · Elite                                      |  |
|   |      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━░░░  92/100             |  |
|   |      Candidatou Sex, 12/06 · 14:20                       |  |
|   |      ▸ Ver breakdown                                     |  |
|   |  ──────────────────────────────────────────────────     |  |
|   |  [ Aceitar candidatura ] (desab.)   Remover (desab.)     |  |
|   +----------------------------------------------------------+  |
|   ( … demais candidatos … )                                     |
+------------------------------------------------------------------+
```

- Diferença vs. mobile: largura travada ~720px, marca no topo, botões de ação podem caber lado a
  lado, hover/focus. Sem nav lateral neste épico.

### Tablet (≥600/768px)

Herda o desktop (coluna única ~720px centralizada). `LayoutBuilder` decide pelo breakpoint.

---

## 4. Estados

> Toda spec entrega **todos** os estados aplicáveis (Princípio #7).

### 4.1. Caminho feliz (lista ranqueada)

Faixa de contexto + N cards na ordem do back (CA-2). Cada card: avatar, nome, função primária,
nível, score (chip + barra + número), data/hora da candidatura (DDR-002), toggle de breakdown
colapsado, ações desabilitadas. Microcopy na §5.

### 4.2. Loading (primeiro fetch)

Enquanto `GET /api/vagas/{id}/candidatos` não responde, **skeleton da lista** (faixa fantasma + 3
cards fantasma com avatar/linhas/barra) — não spinner em tela branca (princípio #6).

```
+------------------------------------------+
| ←  Candidatos                             |
+------------------------------------------+
|  ░░░░░░░░░░░░░░░░░░                       |
+------------------------------------------+
| ┌──────────────────────────────────────┐ |
| │ (○)  ░░░░░░░░░░          ░░░           │ |
| │      ░░░░░░░░░░░░                      │ |
| │      ░░░░░░━━━━━━━━━░░░  ░░░           │ |
| └──────────────────────────────────────┘ |
|  ( × 3 )                                  |
+------------------------------------------+
```

### 4.3. Vazio — ainda sem candidatos (CA-7)

Vaga `aberta` sem nenhuma candidatura. Estado dedicado, **otimista**, com o **SLA prometido**:

```
+------------------------------------------+
|              👥                          |
|  Ainda sem candidatos                     |
|  Vamos avisar assim que chegar o          |
|  primeiro. Member Start: em até 2h.       |  (≤ 1h para Enterprise)
+------------------------------------------+
```

- A linha do SLA é derivada do plano do contratante (`business-rules.md`): **≤ 2h** (Member
  Start) / **≤ 1h** (Enterprise). No MVP o plano é `member_start` por padrão (cadastro) — a UI
  exibe "em até 2h"; quando o back enviar o plano, a UI ajusta o número (slot pronto).

### 4.4. Erro — rede / 5xx no fetch

Falha de `GET …/candidatos` por rede/5xx → erro centrado com **retry**, sem lista falsa. Espelha
o `minhas-vagas-erro-banner` (consistência com 047).

```
+------------------------------------------+
|              ⚠                           |
|  Não foi possível carregar os candidatos. |
|  Verifique sua conexão.                   |
|        [ Tentar de novo ]                 |
+------------------------------------------+
```

### 4.5. Sem permissão (profissional / contratante não-dono — CA-1)

Profissional autenticado **ou** contratante que não é dono da vaga → backend **403** → tela curta
+ saída. Espelha o `minhas-vagas-sem-permissao` (047).

```
+------------------------------------------+
|              🔒                          |
|  Esta área é do contratante dono          |
|  Só quem publicou a vaga vê seus          |
|  candidatos.                              |
|        [ Voltar ao início ]              |
+------------------------------------------+
```

### 4.6. Vaga inexistente (404)

`GET` retorna **404** (vaga não existe). Estado dedicado, com volta a "Minhas vagas".

```
+------------------------------------------+
|              ⃠                           |
|  Vaga não encontrada                      |
|  Ela pode ter sido removida. Veja suas    |
|  vagas.                                   |
|        [ Voltar às minhas vagas ]         |
+------------------------------------------+
```

### 4.7. Breakdown expandido (CA-4)

Toggle "Ver breakdown" → as 4 `match.breakdownrow` aparecem in-place (Função → Distância →
Histórico → Nível), com ícone de estado + barra na cor do estado + `X/Y` + prosa — **idêntico** a
049, lendo o `score_breakdown` **persistido** (CA-4). Toggle vira "Ocultar breakdown". Estado por
card (independentes). Se o `score_breakdown` persistido for nulo (candidatura legada — nenhuma no
MVP), o toggle some e o card mostra só o score numérico (fail-soft).

### 4.8. Alerta de habitualidade (CA-5)

Candidato **MEI/PJ na 3ª alocação na semana** (`alerta_habitualidade == true`): `habitualidade.
badge` laranja no card — "⚠ Habitualidade — 3ª alocação na semana" — com tooltip explicando que é
sinalização para o aceite (override no EPIC-003), **não** um bloqueio (o profissional MEI/PJ não
foi barrado; STORY-050 CA-4). O card segue normal em tudo o mais.

### 4.9. Ações futuras desabilitadas (CA-6)

"Aceitar candidatura" (`button.primary` disabled) e "Remover candidato" (`button.text` disabled)
em **todo** card. Tooltip + `Semantics(enabled:false)` com a razão: "Disponível no EPIC-003 —
Aceite, PIN e Pix" / "Disponível no EPIC-003". Proposital — fecha o EPIC-002 sem invadir o 003.

---

## 5. Microcopy completo

| Lugar | Texto |
|---|---|
| AppBar — título | Candidatos |
| Faixa de contexto — vaga | {função} · {Dia, dd/mm · HH:mm–HH:mm} |
| Faixa de contexto — contagem (0) | Nenhum candidato ainda |
| Faixa de contexto — contagem (1) | 1 candidato |
| Faixa de contexto — contagem (N) | {N} candidatos |
| Card — nome | {nome do profissional} |
| Card — função · nível | {função primária} · {nível} |
| Card — score (número) | {score}/100 |
| Card — data da candidatura | Candidatou {Dia, dd/mm · HH:mm} |
| Card — toggle (fechado) | Ver breakdown |
| Card — toggle (aberto) | Ocultar breakdown |
| Breakdown — label Função | Função |
| Breakdown — label Distância | Distância |
| Breakdown — label Histórico | Histórico |
| Breakdown — label Nível | Nível na trilha |
| Breakdown — valor pontos | {pontos}/{pontos_max} |
| Breakdown — descrição | {descricao do back — verbatim} |
| Habitualidade — badge | Habitualidade — 3ª alocação na semana |
| Habitualidade — tooltip | Profissional MEI/PJ acima do limite semanal neste local. Sinalização para o aceite; não bloqueia. |
| Aceitar — botão | Aceitar candidatura |
| Aceitar — tooltip (desab.) | Disponível no EPIC-003 — Aceite, PIN e Pix |
| Remover — botão | Remover candidato |
| Remover — tooltip (desab.) | Disponível no EPIC-003 |
| Vazio — título | Ainda sem candidatos |
| Vazio — corpo (Member Start) | Vamos avisar assim que chegar o primeiro. Member Start: em até 2h. |
| Vazio — corpo (Enterprise) | Vamos avisar assim que chegar o primeiro. Enterprise: em até 1h. |
| Erro de fetch (título) | Não foi possível carregar os candidatos. |
| Erro de fetch (corpo) | Verifique sua conexão. |
| Erro de fetch (retry) | Tentar de novo |
| Sem permissão (título) | Esta área é do contratante dono |
| Sem permissão (corpo) | Só quem publicou a vaga vê seus candidatos. |
| Sem permissão (CTA) | Voltar ao início |
| Vaga não encontrada (título) | Vaga não encontrada |
| Vaga não encontrada (corpo) | Ela pode ter sido removida. Veja suas vagas. |
| Vaga não encontrada (CTA) | Voltar às minhas vagas |

As **descrições das linhas** (`descricao`) e o `score_breakdown` vêm **persistidos** do backend
(snapshot da candidatura — CA-4): a UI as exibe verbatim, não compõe nem recalcula. Datas/horas
pt-BR 24h (DDR-002). Nível: rótulo da trilha (Iniciante/Confiável/Destaque/Elite). Vocabulário:
`glossary.md`. Tom: direto, sem "Ops!"/emoji no corpo (o 👥/🔒/⃠ dos estados são ilustração de
estado, não emoji de copy).

---

## 6. Acessibilidade (notas específicas)

- **Avatar:** quando há foto, `Semantics(label: 'Foto de {nome}')`; sem foto, o fallback de
  iniciais é decorativo (`ExcludeSemantics`) e o nome já está no card como texto.
- **Score do card:** `MergeSemantics` no bloco nome+score → "Júlia Santos, match 92 de 100". A
  barra é `ExcludeSemantics` (o número já fala). Nunca só cor (princípio #5).
- **Breakdown (reuso 049):** cada `match.breakdownrow` anuncia **ícone com label + número +
  prosa** — "Função: atende · 40 de 40 pontos · Função primária bate". Mantido idêntico a 049.
- **Toggle "Ver breakdown":** `Semantics(button: true, expanded: <bool>, label: 'Ver breakdown de
  {nome}')` — o leitor de tela sabe que expande e o estado atual.
- **Habitualidade:** `Semantics(label: 'Alerta de habitualidade: terceira alocação na semana.')`
  no badge; não depende de cor (ícone ⚠ + texto).
- **Botões desabilitados:** `Semantics(enabled: false, label: '{ação}. Disponível no EPIC-003')`
  + `Tooltip` — a razão é lida, não só vista.
- **Erro / vazio:** `Semantics(liveRegion: true)` para anúncio assíncrono do desfecho do fetch.
- **Contraste:** acento mostarda `#9A6E25`/`#D4A95C`, success/warn/mudo do breakdown, texto
  forte/mudo — todos AA (tokens DDR-001). Barras: preenchimento sobre trilho `borderSubtle` ≥3:1.
- **Ordem de foco:** voltar → faixa de contexto → para cada card: nome → score → toggle →
  (breakdown, se aberto) → aceitar → remover.
- **Alvos de toque ≥48dp:** seta voltar, toggle, botões de ação.

---

## 7. Identificadores estáveis sugeridos para teste

| Elemento | Identificador lógico sugerido |
|---|---|
| Tela (raiz) | `painel-candidatos-screen` |
| Faixa de contexto da vaga | `painel-candidatos-contexto` |
| Lista (container) | `painel-candidatos-lista` |
| Card do candidato (por candidatura) | `candidato-card-{id}` (id = candidatura) |
| Card — avatar | `candidato-card-{id}-avatar` |
| Card — nome | `candidato-card-{id}-nome` |
| Card — função · nível | `candidato-card-{id}-funcao-nivel` |
| Card — selo de nível | `candidato-card-{id}-nivel` |
| Card — score chip | `candidato-card-{id}-score-chip` |
| Card — barra de score | `candidato-card-{id}-score-bar` |
| Card — data da candidatura | `candidato-card-{id}-data` |
| Card — toggle breakdown | `candidato-card-{id}-breakdown-toggle` |
| Card — bloco do breakdown (quando aberto) | `candidato-card-{id}-breakdown` |
| Card — linha do breakdown (por componente) | `candidato-card-{id}-breakdown-{componente}` (funcao/distancia/historico/nivel) |
| Card — badge de habitualidade | `candidato-card-{id}-habitualidade` |
| Card — botão aceitar (desab.) | `candidato-card-{id}-aceitar-btn` |
| Card — botão remover (desab.) | `candidato-card-{id}-remover-btn` |
| Estado vazio | `painel-candidatos-vazio` |
| Estado erro | `painel-candidatos-erro` |
| Retry | `painel-candidatos-retry-btn` |
| Estado sem permissão | `painel-candidatos-sem-permissao` |
| Estado vaga não encontrada | `painel-candidatos-nao-encontrada` |
| Skeleton (loading) | `painel-candidatos-skeleton` |

> Nomes lógicos — o Programador aplica como `Key('...')`. O E2E (CA-10) navega de
> `vaga-card-{id}-ver-candidatos` (047) → `painel-candidatos-lista`, confere a ordem dos 3
> `candidato-card-{id}` e abre `candidato-card-{id}-breakdown-toggle` para ver as 4
> `candidato-card-{id}-breakdown-{componente}`.

---

## 8. Exceções ao Design System

| O que diverge | Por quê | Vira DDR? |
|---|---|---|
| `avatar` — foto circular do profissional (40–48dp) com **fallback de iniciais** sobre cor sólida quando não há foto. **1º uso de avatar no app.** | O painel precisa identificar pessoas (não vagas). Material: `CircleAvatar` com `backgroundImage`/`child`. Reaparece em qualquer tela que liste pessoas (aceite EPIC-003, perfil). | **Sim — candidato.** Promover a `avatar` no DS quando EPIC-003 reusar (2º uso confirma). |
| `badge.nivel` — selo neutro do nível na trilha (Iniciante/Confiável/Destaque/Elite): `surface.muted` + texto forte. | Mostra o nível sem competir com o score (que é o herói). Variante sóbria de `badge.status`. | Registrar junto da família `badge.*`. |
| `habitualidade.badge` — pill **warning** (⚠ + texto) no card. Reusa o token/forma de `banner.warning` em formato pill. | É o 5º contexto do warning (publicar 046, feed 048, detalhe 049, candidatura 050, painel 051). Sinaliza sem alarmar (não vermelho). | **Promover `banner.warning` ao DS** (uso recorrente sobejamente confirmado) e registrar a variante pill. |
| `match.breakdownrow` + `match.scorebar` + `match.scorechip` (reuso **idêntico** de 049/048) — agora no tema do contratante | É o **3º uso** da barra/breakdown (feed 048 → detalhe 049 → painel 051). A estória previu este reuso (049 §8). | **Promover a família `match.*` ao DS agora** — durabilidade confirmada pelo 3º uso, exatamente como 049 antecipou. |
| `button.primary`/`button.text` em estado **disabled com tooltip de razão** (ações do EPIC-003) | Padrão "promessa honesta": a ação existe visualmente, desabilitada, com a razão. Espelha o CTA desabilitado de 049 (gate). | Já coberto pelo padrão de 049; sem novo registro. |

Nenhuma exceção viola token de cor/contraste — avatar, badges e barras usam tokens auditados AA.
A decisão "habitualidade = warning, não erro (vermelho)" segue a regra de contexto DDR-001 e
espelha a decisão `miss = cinza-mudo` de 049 e `gate = warning` de 050.

---

## 9. Protótipo HTML fiel (validação humana)

- **Localização:** `SCREEN-STORY-051-painel-candidatos/index.html` (mesma pasta deste spec).
- **Cobertura:** seletor de viewport (mobile/desktop) + seletor de estado (`?state=`): `lista`
  (3 candidatos ranqueados, 1 com breakdown aberto), `lista-habitualidade` (candidato MEI/PJ com
  badge laranja), `loading` (skeleton), `vazio` (SLA Member Start), `erro` (fetch),
  `sem-permissao`, `nao-encontrada` (404).
- **Fidelidade:** tokens reais do tema **contratante** (mostarda) + semânticos (success/warn/mudo)
  no breakdown; microcopy = §5 palavra por palavra; identificadores da §7 como `data-testid`.
  Datas/horas pt-BR 24h. Barras com largura proporcional ao score; ícone de estado por linha do
  breakdown. Ordem dos cards por score; ordem do breakdown fixa.
- **Restrições:** HTML/CSS/JS vanilla, sem rede, abre clicando. Mock inline. Comentário no topo:
  "protótipo de validação, não código de produção".

### Checklist antes de marcar spec `ready`

- [x] Spec cobre lista + loading + vazio(SLA) + erro + sem-permissão + 404 + breakdown expandido + habitualidade + ações desabilitadas.
- [x] Microcopy §5 completo (rótulos da UI + corpo/descrições marcados como "vem do back").
- [x] Identificadores §7 cobrem card, breakdown, badges, ações + os estados.
- [x] Exceções §8 justificadas (avatar, badge.nivel, habitualidade.badge, promoção match.*).
- [ ] Protótipo HTML criado e todos os estados acessíveis (a validar no app + chat).
- [ ] Protótipo apresentado ao humano e sinal de validação capturado.

---

## 10. Dependências e premissas

- **Endpoint (contrato — estória CA-1):**
  - `GET /api/vagas/{id}/candidatos` (autenticado contratante dono) →
    `{ candidatos: [ { id, profissional: { id, nome, foto_url, funcao_primaria, nivel,
    score_historico, plano }, score_no_momento, score_breakdown, candidatou_em,
    alerta_habitualidade } ], total }`.
  - `score_breakdown` é exatamente `MatchScore::toArray()` **persistido** no instante da
    candidatura (STORY-050 + a migração desta estória) — a UI **não recalcula** (CA-2/CA-4).
  - Ordenação **vem do back**: `score_no_momento DESC, plano_boost DESC, candidatou_em ASC`
    (CA-2). `plano_boost` é stub (ADR-014 Decisão 3 — sem plano do profissional modelado, todos
    empatam em 0). A UI **não** reordena.
  - RBAC: **403** para contratante não-dono **e** para profissional; **404** para vaga
    inexistente (CA-1).
- **`plano` do profissional não está modelado** (não há coluna em `profissional_profiles`) → vem
  **null**; o badge "Turni Ads"/"Turnificado" (CA-3) é **stub** (slot pronto, sem render no MVP).
  Documentado em STORY-045 CA-5.
- **`foto_url`** é best-effort: quando o profissional tem `foto_path`, o back devolve a URL; senão
  `null` e o avatar cai para **iniciais** (fail-soft — §4/§8).
- **SLA do vazio (CA-7):** ≤ 2h (Member Start) / ≤ 1h (Enterprise) — `business-rules.md`. No MVP o
  plano do contratante é `member_start`; a UI mostra "em até 2h" e ajusta quando o back enviar o
  plano (slot pronto).
- **Coexistência com 047:** esta spec **substitui** o placeholder da rota
  `/contratante/vagas/{id}/candidatos` que a STORY-047 deixou. O link "Ver candidatos" já existe
  com seu identificador.
- **Aceite/remoção são EPIC-003:** botões desabilitados de propósito (CA-6). Sem DDR pendente
  bloqueante — opera dentro de DDR-001/DDR-002. As exceções §8 (`avatar`, `badge.nivel`,
  `habitualidade.badge`) são aditivas e candidatas a promoção quando EPIC-003 reusar.

---

## 11. Histórico de mudanças

| Data | Mudança | Quem | Motivo |
|---|---|---|---|
| 2026-06-02 | criação (spec completo: lista ranqueada + breakdown reusado + habitualidade + ações EPIC-003 desabilitadas) | claude-opus-4-8 (designer) | story bem especificada; spec entregue para guiar a implementação do painel de candidatos, espelho de 049 |
