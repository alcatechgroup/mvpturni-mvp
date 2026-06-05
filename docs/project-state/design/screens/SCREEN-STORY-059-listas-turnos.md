---
id: SCREEN-STORY-059-listas-turnos
story: STORY-059-listas-meus-turnos-vagas-confirmadas
epic: EPIC-003-aceite-pin-e-pix
status: in_implementation    # draft | ready | in_implementation | shipped | superseded
created_at: 2026-06-05
updated_at: 2026-06-05
owner_designer: claude-opus-4-8
related_ddrs: [DDR-001, DDR-002]
ds_components_used: [brand.logo, surface.card, badge.status, banner, button.primary, skeleton.card]
exceptions_to_ds: [section.group-header (cabeçalho de seção com contador — 1º uso; candidato a promoção quando STORY-060/066 reusarem)]
viewports: [mobile, desktop]
prototype_path: SCREEN-STORY-059-listas-turnos/index.html
prototype_last_validated_at: 2026-06-05  # aprovado por Alexandro em chat (título contratante → "Turnos"; em_disputa como seção própria)
---

# Spec de tela — SCREEN-STORY-059 — "Meus turnos" (profissional) + "Turnos" (contratante)

> Referência: estória `STORY-059`. CAs e contexto vêm de lá — **não duplico**.
> **Duas telas espelhadas**, mesma anatomia, tema por papel (DDR-001): `/profissional/turnos`
> (acento verde-sage) e `/contratante/turnos` (acento mostarda). Reuso direto do padrão de lista
> da `SCREEN-STORY-047` (card + estados + banner/skeleton) — **sem filtros** (fora de escopo da
> estória): a organização é por **seções de estado** do `domain/turno.md`.
> Locale/horário: DDR-002 (pt-BR, 24h). Valores: PDR-004 + `domain/pagamento.md` §visibilidade
> (profissional vê o que recebe; contratante vê o total que paga).
> Princípios que guiaram: **#1** simplicidade (zero ação na tela — é porta de entrada e overview),
> **#2** mobile-first, **#3** tom profissional, **#5** WCAG AA (estado nunca só por cor),
> **#6** skeleton em vez de spinner, **#7** todos os estados (loading, vazio, erro, sem permissão).

A partir da STORY-058 existem turnos `confirmado`. Esta tela é a **porta de entrada** de cada papel
para os próprios turnos: o profissional vê o que vai trabalhar (e o que já trabalhou); o contratante
vê o que tem contratado nas vagas dele. Nenhuma ação aqui — tocar/agir no turno é STORY-060+.

---

## Tema e perfil

- `/profissional/turnos` — tema **profissional** (DDR-001): acento `#2D5F3F` (`on-accent` branco
  7.4:1 ✅), `accent.ink` `#2D5F3F` para link/texto de acento.
- `/contratante/turnos` — tema **contratante**: acento `#9A6E25` (4.5:1 ✅), `accent.ink` `#6E4E12`.
- **Selo de estado usa cor semântica, não de perfil** (mesma regra da 047): success/warning/error/
  neutro. Cor nunca é o único canal — rótulo + ícone + borda sempre (tokens.md §4).
- Marca `TURNI.` (`brand.green #00A868`) no topo desktop. Tema dual claro/escuro (PDR-013) via
  tokens já auditados.

---

## 1. Objetivo da tela

Responder em um olhar: **"quais turnos eu tenho e em que pé cada um está?"** — agrupado pelos
estados do domínio, do mais próximo da ação (confirmado/em andamento) ao histórico (finalizado/
encerrado). É overview puro: zero decisão, zero formulário, zero ação destrutiva.

---

## 2. Fluxo

### Entrada (porta de entrada — a razão da estória)

- **Profissional:** novo ícone-ação na AppBar do feed (`/feed`), à esquerda do sino de
  notificações — ícone `event_note` (agenda), tooltip "Meus turnos" → navega `/profissional/turnos`.
- **Contratante:** idem na AppBar de Minhas vagas (`/contratante/vagas`) — tooltip
  "Turnos" → navega `/contratante/turnos`.
- **URL direta / deep-link:** as duas rotas são endereçáveis e sobrevivem a reload (Flutter web,
  go_router). Funnel guard (STORY-016) garante sessão ativa.
- **Snackbar de sucesso da 058** ("turno confirmado…") futuramente aponta para cá — fora de escopo
  agora (não há ação no snackbar da 058 hoje; nada muda lá).

### Ações possíveis na tela

- **Voltar** (AppBar leading) → home do papel (`/feed` ou `/contratante/vagas`).
- **Sino de notificações** (AppBar) — componente existente, sem mudança.
- **Estado vazio:** CTA que leva à ação que gera turnos — profissional: "Ver vagas disponíveis"
  → `/feed`; contratante: "Ver minhas vagas" → `/contratante/vagas`.
- **Card: nenhuma ação.** Sem chevron, sem hover de clique, cursor default — não dar falsa
  affordance enquanto o detalhe (STORY-060) não existe. Quando a 060 chegar, o card vira navegável
  (decisão já antecipada aqui para a 060 não redesenhar o card).

### Saída

- Voltar para a home do papel. Erro de fetch tem retry inline (sem sair da tela).

---

## 3. Layout

### Mobile (≥360px)

AppBar com voltar + título + sino. Conteúdo: lista vertical única com **seções por estado**
(cabeçalho de seção + cards). Seção sem turnos **não aparece** (sem header órfão).

```
+------------------------------------------+
| ←  Meus turnos                       🔔  |  AppBar (voltar + título + sino)
+------------------------------------------+
| CONFIRMADOS (2)                          |  section.group-header (overline + contador)
|  +------------------------------------+  |
|  | Garçom            ● Confirmado     |  |  função + selo de estado (badge.status)
|  | Bar do Zé                          |  |  estabelecimento (prof.) / profissional (contr.)
|  | Sex, 12/06 · 18:00–23:00           |  |  data/hora 24h pt-BR (DDR-002)
|  | R$ 200,00                          |  |  valor que recebe (prof.) / total (contr.)
|  +------------------------------------+  |
|  +------------------------------------+  |
|  | Cozinheira        ● Confirmado     |  |
|  | Hotel Aurora                       |  |
|  | Dom, 14/06 · 08:00–16:00           |  |
|  | R$ 240,00                          |  |
|  +------------------------------------+  |
| EM ANDAMENTO (1)                         |
|  +------------------------------------+  |
|  | Recepcionista     ▶ Em andamento   |  |  selo success preenchido (vivo agora)
|  | Pousada Mar Alto                   |  |
|  | Qui, 05/06 · 14:00–22:00           |  |
|  | R$ 160,00                          |  |
|  +------------------------------------+  |
| FINALIZADOS (1)                          |
|  +------------------------------------+  |
|  | Bartender         ✓ Finalizado     |  |  selo neutro
|  | Bar do Zé                          |  |
|  | Sáb, 31/05 · 20:00–02:00           |  |
|  | R$ 220,00                          |  |
|  +------------------------------------+  |
+------------------------------------------+
```

- Componentes DS: `surface.card`, `badge.status` (estendido com novas variantes §8), `banner`,
  skeleton da 047; novo: `section.group-header` (§8).
- Card **sem** borda inferior de ações (não há ações) — anatomia mais curta que o card da 047.
- Sem FAB — não há ação primária de criação aqui.

### Desktop (≥1024px)

Conteúdo centralizado, max ~960px. Marca no topo. Título + sino na linha de cabeçalho. Seções
em coluna única com cards em **grade de 2 colunas** dentro de cada seção (mesma regra da 047 —
`LayoutBuilder` decide 1 ou 2 pela largura).

```
+------------------------------------------------------------------+
|                            TURNI.                                |
|  ← Meus turnos                                              🔔   |
|                                                                  |
|  CONFIRMADOS (2)                                                 |
|  +---------------------------+  +---------------------------+    |
|  | Garçom      ● Confirmado  |  | Cozinheira  ● Confirmado  |    |
|  | Bar do Zé                 |  | Hotel Aurora              |    |
|  | Sex, 12/06 · 18:00–23:00  |  | Dom, 14/06 · 08:00–16:00  |    |
|  | R$ 200,00                 |  | R$ 240,00                 |    |
|  +---------------------------+  +---------------------------+    |
|  EM ANDAMENTO (1)                                                |
|  +---------------------------+                                   |
|  | Recepcionista ▶ Em andam. |                                   |
|  +---------------------------+                                   |
+------------------------------------------------------------------+
```

### Tablet (768px)

Colapsa para 1 coluna quando não couberem 2 de ~440px + gap (idêntico à 047).

### Espelho do contratante (`/contratante/turnos`)

Mesma anatomia; diferenças:

- Título: **"Turnos"** (decisão do PO em chat, 2026-06-05 — a estória nomeava "Vagas confirmadas",
  mas a tela lista turnos em todos os estados; "Turnos" é o termo preciso do glossário).
- Acento mostarda em AppBar/foco/CTA do vazio.
- Linha 2 do card: **nome do profissional** (em vez do estabelecimento — o estabelecimento é o
  dele próprio, informação redundante; o que ele quer saber é *quem vem*).
- Linha de valor: **total a pagar** — `R$ 230,00 · total` (PDR-004: contratante vê valor+taxa
  consolidados; o breakdown detalhado fica no detalhe/aceite — já visto no D1 da 058).

---

## 4. Estados

### 4.1. Caminho feliz (lista preenchida)

Seções na **ordem fixa do ciclo de vida** (CA-1), seção vazia omitida:

| # | Seção (header) | Estados do domínio | Ordenação interna |
|---|---|---|---|
| 1 | Confirmados | `confirmado` | `data_inicio` ↑ (próximo primeiro) |
| 2 | Aguardando check-in | `aguardando_checkin` | `data_inicio` ↑ |
| 3 | Em andamento | `ativo` | `data_inicio` ↑ |
| 4 | Aguardando check-out | `aguardando_checkout` | `data_inicio` ↑ |
| 5 | Em disputa | `em_disputa` | `data_fim` ↓ (recente primeiro) |
| 6 | Finalizados | `finalizado`, `finalizado_ajustado` | `data_fim` ↓ |
| 7 | Encerrados | `cancelado_pro`, `cancelado_emp`, `no_show_pro`, `disputa_resolvida_sem_pagamento` | `data_fim` ↓ |

> **Nota ao PO:** o CA-1 enumera 6 grupos e não cita `em_disputa`. O estado existe em
> `domain/turno.md` e um turno em disputa **não pode ficar invisível** para as partes — o spec o
> inclui como seção própria (posição 5, entre check-out e finalizados, onde ele nasce no ciclo).
> Validar na aprovação do protótipo.

Selos de estado (`badge.status`, rótulo + ícone + borda — nunca só cor):

| Estado | Selo | Cor semântica |
|---|---|---|
| `confirmado` | ● Confirmado | success soft |
| `aguardando_checkin` | ⧖ Aguardando check-in | warning soft |
| `ativo` | ▶ Em andamento | success **preenchido** (vivo agora) |
| `aguardando_checkout` | ⧖ Aguardando check-out | warning soft |
| `em_disputa` | ⚠ Em disputa | error soft |
| `finalizado` | ✓ Finalizado | neutro |
| `finalizado_ajustado` | ✓ Finalizado com ajuste | neutro |
| `cancelado_pro` / `cancelado_emp` | ⊘ Cancelado | error esmaecido |
| `no_show_pro` | ⊘ Não realizado | error esmaecido |
| `disputa_resolvida_sem_pagamento` | ⊘ Encerrado sem pagamento | error esmaecido |

### 4.2. Loading (primeiro fetch e refresh)

Skeleton de 1 header de seção + 2–3 cards (mesmo shimmer da 047). Nunca spinner em tela vazia.

### 4.3. Vazio (CA-6 — microcopy do PO)

Sem nenhum turno em nenhum estado. Sem headers de seção. Ícone leve + título + instrução + CTA
que leva à origem dos turnos.

```
+------------------------------------------+
|                 📅                       |
|        Ainda não há turnos               |
|  Quando o contratante aceitar sua        |
|  candidatura, o turno aparece aqui.      |
|                                          |
|      [ Ver vagas disponíveis ]           |  button.primary (acento do papel)
+------------------------------------------+
```

Espelho contratante: "Quando você aceitar uma candidatura, o turno aparece aqui." +
CTA "Ver minhas vagas".

### 4.4. Erro — rede / servidor no fetch

`banner` de erro no topo com retry (idêntico ao padrão 047 §4.5).

```
| ⚠ Não foi possível carregar seus turnos.  |
|   Verifique sua conexão.  [Tentar de novo]|
```

### 4.5. Sem permissão (CA-5 — papel cruzado, fail-secure)

Backend responde **403**; o front também guarda a rota. Mesmo padrão da 047 §4.6:

- Contratante em `/profissional/turnos`:
  "**Esta área é do profissional** / Meus turnos mostra os turnos de quem trabalha.
  Sua conta é de contratante. [Voltar ao início]"
- Profissional em `/contratante/turnos`:
  "**Esta área é do contratante** / Acompanhar os turnos das vagas é uma ação de quem contrata.
  Sua conta é de profissional. [Voltar ao início]"

"Voltar ao início" → `/` (o funnel guard resolve a home do papel).

### 4.6. Parcial / degradado

Campo derivado ausente (ex.: nome do profissional ainda não disponível): o card renderiza sem a
linha, nunca quebra. Grupo desconhecido (estado novo no back antes do front): cai em "Encerrados"
**nunca some** — e loga em console (sinal para o Programador, não para o usuário).

---

## 5. Microcopy completo

| Lugar | Texto |
|---|---|
| Título — profissional | Meus turnos |
| Título — contratante | Turnos |
| Tooltip ícone AppBar (feed) | Meus turnos |
| Tooltip ícone AppBar (minhas vagas) | Turnos |
| Header seção 1 | Confirmados |
| Header seção 2 | Aguardando check-in |
| Header seção 3 | Em andamento |
| Header seção 4 | Aguardando check-out |
| Header seção 5 | Em disputa |
| Header seção 6 | Finalizados |
| Header seção 7 | Encerrados |
| Contador do header | ({N}) — ex.: "Confirmados (2)" |
| Selos | ver tabela §4.1 |
| Card — data/hora (exemplo) | Sex, 12/06 · 18:00–23:00 |
| Card — valor (profissional) | R$ {valor} |
| Card — valor (contratante) | R$ {total} · total |
| Vazio — título (ambos) | Ainda não há turnos |
| Vazio — instrução (profissional) | Quando o contratante aceitar sua candidatura, o turno aparece aqui. |
| Vazio — instrução (contratante) | Quando você aceitar uma candidatura, o turno aparece aqui. |
| Vazio — CTA (profissional) | Ver vagas disponíveis |
| Vazio — CTA (contratante) | Ver minhas vagas |
| Erro de fetch (banner) | Não foi possível carregar seus turnos. Verifique sua conexão. |
| Retry | Tentar de novo |
| Sem permissão (prof. em área de contr.) | Esta área é do contratante / Acompanhar os turnos das vagas é uma ação de quem contrata. Sua conta é de profissional. / Voltar ao início |
| Sem permissão (contr. em área de prof.) | Esta área é do profissional / Meus turnos mostra os turnos de quem trabalha. Sua conta é de contratante. / Voltar ao início |

Datas/horas pt-BR 24h (DDR-002): dia abreviado + `dd/mm`, hora `HH:mm`, intervalo com en-dash.
Vocabulário do glossário (Turno, Vaga, Profissional, Contratante). Tom direto, sem "Ops!".

---

## 6. Acessibilidade (notas específicas)

- **Headers de seção** são headings semânticos (`Semantics(header: true)`) — leitor de tela navega
  por seção. Contador anunciado por extenso: `Semantics(label: 'Confirmados, 2 turnos')`.
- **Selo de estado**: rótulo textual + ícone + borda ≥3:1 — cor nunca é canal único. O selo
  `ativo` preenchido tem `on-accent` auditado (success `#2D7A4F` + branco = AA ✅).
- **Card**: `MergeSemantics` agrupando função + quem/onde + data + valor + estado — anunciado
  como um item coeso. Sem `button`/`onTap` semântico (não há ação — não anunciar como clicável).
- **Ícone AppBar de entrada**: `IconButton` com `tooltip` ("Meus turnos"/"Turnos") e
  alvo ≥48dp.
- **Banner de erro / retry**: `liveRegion: true`; retry navegável por teclado, foco visível.
- **Ordem de foco**: voltar → título → sino → (cards em ordem de seção) → CTA do vazio quando for
  o caso.
- **Contraste**: tokens já auditados AA (tokens.md §6) — nenhuma combinação nova de cor.

---

## 7. Identificadores estáveis sugeridos para teste

| Elemento | Identificador lógico sugerido |
|---|---|
| Tela profissional (raiz) | `meus-turnos-screen` |
| Tela contratante (raiz) | `contratante-turnos-screen` |
| Ícone de entrada na AppBar do feed | `feed-meus-turnos-btn` |
| Ícone de entrada na AppBar de minhas vagas | `minhas-vagas-turnos-btn` |
| Lista (scroll raiz) | `turnos-lista` |
| Header de seção (por slug) | `turnos-grupo-{slug}` (confirmado, aguardando-checkin, ativo, aguardando-checkout, em-disputa, finalizado, encerrado) |
| Card de turno (por uuid) | `turno-card-{id}` |
| Selo de estado do card | `turno-card-{id}-estado` |
| Valor do card | `turno-card-{id}-valor` |
| Skeleton (loading) | `turnos-skeleton` |
| Estado vazio | `turnos-vazio` |
| CTA do vazio | `turnos-vazio-cta` |
| Banner de erro | `turnos-erro-banner` |
| Retry | `turnos-retry-btn` |
| Sem permissão (card) | `turnos-sem-permissao` |

> `{id}` é UUIDv7 string (ADR-018). O E2E (CA-7) ancora em `turno-card-{id}` + `-estado` e nos
> dois `*-screen`.

---

## 8. Exceções ao Design System

| O que diverge | Por quê | Vira DDR? |
|---|---|---|
| `section.group-header` — cabeçalho de seção (overline caps + contador) para lista agrupada | DS não tem padrão de lista seccionada; é o coração desta tela. Material: `Text` overline + `Semantics(header)`. Reaparece em STORY-060 (timeline) e STORY-066. | **Candidato** — promover quando reusar. |
| `badge.status` — novas variantes (warning ⧖, success preenchido ▶, error-soft ⚠, esmaecido ⊘) | O selo da 047 (`aberta/fechada/cancelada`) ganha as variantes de estado de Turno. Mesma anatomia, novas cores semânticas já auditadas. | Não cria DDR — **estende** o componente existente; registrar em `components.md`. |

Nenhuma cor nova: todas as variantes usam tokens semânticos auditados AA.

---

## 9. Protótipo HTML fiel (validação humana)

- **Localização:** `SCREEN-STORY-059-listas-turnos/index.html`.
- **Cobertura:** seletor de **papel** (Profissional/Contratante — troca tema + título + conteúdo
  do card + microcopy), **viewport** (mobile/desktop) e **estado**: `lista` (todos os 7 grupos
  populados), `lista-curta` (só confirmados — caso típico pós-058), `loading`, `vazio`, `erro`,
  `sem-permissao`.
- **Fidelidade:** tokens reais dos dois temas; microcopy = §5 palavra por palavra; identificadores
  da §7 como `data-testid`; datas pt-BR 24h.
- **Restrições:** HTML/CSS/JS vanilla, sem rede, mock inline, comentário "protótipo de validação".

### Checklist antes de marcar spec `ready`

- [ ] Protótipo abre sem erro; todos os estados acessíveis nos dois papéis e dois viewports.
- [ ] Microcopy bate palavra por palavra com a §5.
- [ ] Identificadores da §7 presentes.
- [ ] Tokens reais dos temas profissional e contratante.
- [x] Protótipo apresentado ao humano e sinal de validação capturado (inclui a Nota ao PO da §4.1
      sobre `em_disputa` — mantido como seção própria — e o título do contratante → "Turnos").

---

## 10. Dependências e premissas

- **Endpoints (contrato — estória CA-1/CA-2/CA-5):**
  - `GET /api/profissional/turnos` → turnos do profissional autenticado, **agrupados por estado**
    no servidor (a ordenação interna por grupo é do CA-1 — servidor entrega ordenado; o front não
    reordena). Cada item: `id` (uuid), `funcao`, `data_inicio`, `data_fim`, `valor`, `estado`,
    `estabelecimento { nome }`.
  - `GET /api/contratante/turnos` → espelho para as vagas do contratante: item com
    `total_contratante` (em vez de só `valor`) e `profissional { nome }` (em vez de
    estabelecimento).
  - RBAC fail-secure: 403 para papel errado nas duas rotas (CA-5); front guarda a rota e mostra §4.5.
- **Sem paginação** neste S (volume pós-058 é baixo); quando o histórico crescer, a seção
  "Finalizados/Encerrados" pagina — fica para estória futura (anotar no índice de débitos se o PO
  quiser).
- **Entrada nas homes:** o ícone na AppBar do feed e de Minhas vagas faz parte desta entrega
  (sem ele a tela não tem porta de entrada — objetivo da estória).
- **Card preparado para a 060:** quando o detalhe existir, o card inteiro vira alvo de toque
  (≥48dp por construção) — sem mudança de anatomia.

---

## 11. Histórico de mudanças

| Data | Mudança | Quem | Motivo |
|---|---|---|---|
| 2026-06-05 | criação (spec completo + protótipo v1) | claude-opus-4-8 (designer) | STORY-059; spec + protótipo entregues juntos para validação humana |
| 2026-06-05 | validação humana — aprovado com ajustes | Alexandro | em_disputa mantido como seção própria; título do contratante "Vagas confirmadas" → "Turnos"; `status: ready` |
