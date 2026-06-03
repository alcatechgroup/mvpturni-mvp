---
id: SCREEN-STORY-053-notificacoes
story: STORY-053-notificacoes-candidatura-in-app-email
epic: EPIC-002-vaga-feed-e-candidatura
status: ready                # draft | ready | in_implementation | shipped | superseded
created_at: 2026-06-03
updated_at: 2026-06-03
owner_designer: claude-opus-4-8
related_ddrs: [DDR-001, DDR-002]
ds_components_used: [brand.logo, surface.card, button.text, notification.bell, notification.panel, notification.tile, empty.state, error.state, skeleton]
exceptions_to_ds: [notification.bell (sino com badge de contagem nas actions do AppBar — 1º uso no app; §8), notification.panel (painel lateral via endDrawer, 360–400dp à direita — §8), notification.tile (item de notificação: ícone por tipo + ponto de não-lida + título + resumo + tempo — §8)]
viewports: [mobile, desktop]
prototype_path: SCREEN-STORY-053-notificacoes/index.html
prototype_last_validated_at: 2026-06-03   # protótipo aprovado por Alexandro em chat
---

# Spec de tela — SCREEN-STORY-053 — Notificações in-app (sino + painel lateral)

> Referência: estória `STORY-053`. CAs e contexto vêm de lá — **não duplico**.
> Esta spec cobre **só a parte in-app** (CA-8): o **sino com badge** no AppBar das duas homes
> (`SCREEN-STORY-048` feed do profissional, `SCREEN-STORY-047` minhas vagas do contratante) e o
> **painel lateral** com a lista de notificações. A parte de **e-mail** (5 templates transacionais)
> herda o visual de `SCREEN-STORY-021` (e-mails transacionais) e a copy do PO (texto-seed v1 na
> própria STORY-053) — **não redesenho e-mail aqui**.
> Fundação visual: `DDR-001` + `docs/project-state/design/system/`. Locale/horário: `DDR-002`
> (pt-BR, 24h, nunca AM/PM). Formatação de data/hora: `IDR-026` (`TurniDateTime`).
> Tema do papel (DDR-001): o sino e o painel **herdam o acento de quem está logado** — verde-sage
> para o **profissional** (feed), mostarda para o **contratante** (minhas vagas). O mesmo widget
> serve os dois; o acento vem do tema do papel, não é fixo.
> Princípios que guiaram: **#1** simplicidade (uma lista cronológica, sem abas nem filtros),
> **#2** mobile-first (o painel nasce ocupando a tela no celular e vira coluna lateral no desktop),
> **#3** tom profissional (resumo sóbrio, sem "Você tem novidades! 🎉"), **#5** WCAG AA (não-lida =
> ponto + peso + rótulo, nunca só cor), **#6** performance percebida (badge otimista, skeleton no
> primeiro fetch, marcar-lida sem esperar o round-trip), **#7** todos os estados (lista, vazio,
> loading, erro, tudo-lido, offline).

Esta tela é a **última peça do EPIC-002 do lado da chegada**: o contratante publicou (046), o
profissional achou e se candidatou (048→049→050), o contratante editou/cancelou (052/047) — e agora
**cada um é avisado** sem precisar dar refresh. O sino é a porta; o painel é a caixa; o e-mail
(fora desta spec) garante quem está com o app fechado.

---

## Tema e perfil

- O sino e o painel **não têm tema próprio** — herdam o tema do papel logado (DDR-001):
  - **Profissional** (feed): acento **verde-sage** (`#2D5F3F` claro / `#5FA37C` escuro).
  - **Contratante** (minhas vagas): acento **mostarda** (`#9A6E25` claro / `#D4A95C` escuro; tinta
    de texto/link `#6E4E12` claro).
- **Badge de contagem** no sino: usa **`error`** (vermelho `#B83A3A`/`#D85A5A`) — convenção
  universal de "pendência não vista", **não** o acento do papel. É o único lugar onde o vermelho
  aparece sem ser destrutivo; é proposital e alinhado ao costume de notificação (o usuário não
  confunde com erro porque é numérico sobre um sino). Texto branco sobre `error` = 5.7:1 (AA).
- **Ponto de não-lida** no item: usa o **acento do papel** (verde/mostarda) — "isto é novo,
  pertence ao seu mundo". O fundo do item não-lido é `accent.soft` do papel; o item lido é
  `surface` plano.
- **Ícone por tipo** de notificação: neutro (`text.muted`) sobre `surface.sunken` circular —
  identifica a natureza (candidatura, edição, cancelamento) sem virar semáforo de cor.
- Marca `TURNI.` não aparece no painel (ele abre sobre a home, que já tem a marca no desktop).

---

## 1. Objetivo da tela

Dar a **qualquer usuário logado** um lugar único para ver **o que aconteceu com suas vagas e
candidaturas** — em ordem cronológica, com o não-lido em destaque — e **um toque** para ir ao lugar
relevante (painel de candidatos, detalhe da vaga, feed). Uma porta (sino), uma lista (painel), um
destino por item. Nada de abas, filtros, categorias ou central de preferências (fora de escopo).

---

## 2. Fluxo

### Entrada

- **Sino no AppBar** das duas homes (`feed-screen` do profissional, `minhas-vagas-screen` do
  contratante) — colocado nas `actions:` **antes** do botão "Sair" existente. Toque → abre o
  painel lateral (`Scaffold.openEndDrawer()`).
- **Pré-condições:** sessão ativa (`status = ativo`). O sino só existe nas telas autenticadas; não
  há sino em login/cadastro.
- **Carga:** ao montar a home, busca `GET /api/notificacoes?lidas=false` (contagem de não-lidas
  para o badge). Ao **abrir** o painel, busca a lista (últimas 50, lidas + não-lidas, `criada_em
  DESC` — contrato CA-7; o painel mostra o histórico recente, não só o não-lido).

### Ações possíveis

- **Abrir/fechar painel** — toque no sino abre; toque fora, gesto de arrastar ou seta de voltar
  fecha (comportamento padrão de `endDrawer`).
- **Tocar numa notificação** — navega para o destino interno do item (`ctaUrl` → rota do app),
  **marca como lida** (`POST /api/notificacoes/{id}/marcar-lida`, otimista) e **fecha o painel**.
- **Marcar todas como lidas** — botão de texto no cabeçalho do painel (`POST
  /api/notificacoes/marcar-todas-lidas`); some o badge, os pontos de não-lida e o próprio botão.
  Só aparece quando há ≥1 não-lida.
- **Tentar de novo** — no estado de erro do fetch da lista, re-busca.

### Saída — destino por tipo (CA-8)

| Tipo | Destino interno | Rota |
|---|---|---|
| `candidatura_recebida` | Painel de candidatos da vaga | `/contratante/vagas/{vaga_id}/candidatos` |
| `vaga_editada_material` | Detalhe da vaga (confirmar/retirar) | `/vaga/{vaga_id}` |
| `vaga_cancelada` | Feed de vagas | `/feed` |
| `vaga_editada_material_candidatura_mantida` | Painel de candidatos | `/contratante/vagas/{vaga_id}/candidatos` |
| `vaga_editada_material_candidatura_retirada` | Painel de candidatos | `/contratante/vagas/{vaga_id}/candidatos` |

> O destino interno é derivado do `tipo` + `vaga_id` do payload (a UI **não** usa a URL absoluta
> do e-mail — `link_painel`/`link_detalhe`/`link_feed` são para o e-mail; o app navega pela rota
> interna). Mapeamento centralizado no Programador.

```
[ home (feed | minhas vagas) ]  ──tap 🔔──►  [ painel lateral (endDrawer) ]
        ▲                                            │
        │                                   tap item │ marca lida + fecha
        │                                            ▼
        └──────────────  navega p/ destino do tipo ──┘
```

---

## 3. Layout

### Mobile (≥360px)

O **sino** é um `IconButton` (`Icons.notifications_outlined`) nas `actions:` do AppBar, **à
esquerda** do "Sair". Por cima dele, um `Badge` Material 3 com a contagem de não-lidas (some quando
0; "9+" acima de 9).

O **painel** abre como `endDrawer` ocupando **toda a largura** (até no máximo 400dp; em telas
estreitas, 100%) e **toda a altura**, deslizando da direita (`motion.slow`, 300ms). Cabeçalho fixo
("Notificações" + "Marcar todas como lidas" quando há não-lidas) e lista rolável de itens.

```
AppBar das homes:
+------------------------------------------+
| Vagas para você            🔔②    [Sair] |   sino + badge antes do "Sair"
+------------------------------------------+

Painel aberto (endDrawer, full-width mobile):
+------------------------------------------+
| Notificações          Marcar todas lidas |   cabeçalho (botão só se há não-lida)
+------------------------------------------+
| ┌──────────────────────────────────────┐ |
| │ •(👤) Nova candidatura recebida        │ |  item NÃO-LIDO (ponto + accent.soft)
| │       Júlia Santos se candidatou à    │ |  resumo (1ª linha do parágrafo)
| │       sua vaga de Garçom.             │ |
| │       há 8 min                        │ |  tempo relativo (IDR-026)
| └──────────────────────────────────────┘ |
| ┌──────────────────────────────────────┐ |
| │  (✎) Vaga alterada — confirme          │ |  item LIDO (sem ponto, surface plano)
| │      A vaga de Cozinheiro mudou.      │ |
| │      Confirme se ainda quer           │ |
| │      participar.                      │ |
| │      ontem · 19:42                    │ |  absoluto quando > 24h
| └──────────────────────────────────────┘ |
|  ( … até 50 itens, criada_em DESC … )     |
+------------------------------------------+
```

- Componentes do DS: `notification.bell` (§8), `notification.panel` (§8), `notification.tile`
  (§8), `button.text` (cabeçalho).
- Cada item: **ícone do tipo** (círculo `surface.sunken` 40dp + ícone `text.muted`), **título**
  (`subtitle`/`titleMedium`, `w600` quando não-lido / `w500` quando lido), **resumo** (`body-sm`,
  `text.muted`, 2 linhas máx. com reticências), **tempo** (`caption`, `text.subtle`). Item
  não-lido ganha **ponto do acento** (8dp) à esquerda do título + fundo `accent.soft`.
- Toda a área do item é tocável (alvo ≥56dp de altura, bem acima de 48dp).
- Sem "ações por item" (arquivar, deletar) — fora de escopo; o item é um link só.

### Desktop (≥1024px)

O sino fica no mesmo lugar (actions do AppBar, à esquerda do "Sair"). O painel abre como **coluna
lateral à direita** com **largura fixa 400dp** e altura total, sobre um scrim leve. Os itens ganham
o espaço extra na horizontal (resumo numa só linha quando cabe), mas a estrutura é a mesma — não é
"mobile esticado": o desktop só trava a largura e usa hover/focus visíveis nos itens.

```
+----------------------------------------------+------------------------+
|  TURNI.   Vagas para você          🔔②  Sair |  Notificações   Marcar |
|                                              +------------------------+
|  ( conteúdo da home, levemente escurecido    | •(👤) Nova candidatura  |
|    pelo scrim enquanto o painel está aberto )| Júlia Santos … Garçom  |
|                                              | há 8 min               |
|                                              +------------------------+
|                                              |  (✎) Vaga alterada …    |
|                                              | ontem · 19:42          |
+----------------------------------------------+------------------------+
```

- Diferença vs. mobile: painel travado em 400dp (não full-width), home visível atrás com scrim,
  hover/focus nos itens. Sem nav lateral nova — reusa `endDrawer`, que o Flutter ancora à direita.

### Tablet (≥600/768px)

Herda o desktop: `endDrawer` 400dp à direita sobre scrim. `LayoutBuilder` não precisa de ramo
próprio — o `endDrawer` já limita a largura; só o mobile estreito (<400dp) vai a 100%.

---

## 4. Estados

> Toda spec entrega **todos** os estados aplicáveis (Princípio #7).

### 4.1. Badge no sino — contagem de não-lidas

- **0 não-lidas:** sino sem badge (`Icons.notifications_outlined`).
- **1–9:** badge numérico (`error`, texto branco).
- **>9:** badge "9+".
- O badge é **otimista**: atualiza na hora ao marcar lida/abrir, sem esperar o servidor; reconcilia
  no próximo fetch. (Princípio #6.)
- A contagem vem de `GET /api/notificacoes?lidas=false` no mount da home; **não** há polling no MVP
  (push é onda 2 — fora de escopo). Re-busca quando a home recebe foco/refresh.

### 4.2. Caminho feliz — lista (lidas + não-lidas)

Painel aberto, cabeçalho + itens em `criada_em DESC`. Não-lidos no topo natural (mais recentes),
destacados com ponto + `accent.soft`; lidos em `surface` plano. Microcopy por tipo na §5.

### 4.3. Loading — primeiro fetch da lista

Ao abrir o painel pela primeira vez, enquanto `GET /api/notificacoes` não responde: **skeleton de
3 itens fantasma** (círculo + 2 linhas + linha curta), nunca spinner em painel branco (Princípio
#6). O cabeçalho "Notificações" já aparece.

```
+------------------------------------------+
| Notificações                              |
+------------------------------------------+
| (○)  ░░░░░░░░░░░░░░░░                      |
|      ░░░░░░░░░░░░░░░░░░░░░                 |
|      ░░░░░░                               |
|  ( × 3 )                                  |
+------------------------------------------+
```

### 4.4. Vazio — nenhuma notificação ainda

Usuário sem nenhuma notificação (nem lida nem não-lida). Estado dedicado, sóbrio e instrutivo —
**não** "Vazio." sozinho.

```
+------------------------------------------+
| Notificações                              |
+------------------------------------------+
|              🔔                          |
|  Nenhuma notificação ainda                |
|  Quando algo acontecer com suas vagas     |
|  ou candidaturas, avisamos aqui.          |
+------------------------------------------+
```

### 4.5. Tudo lido (há histórico, 0 não-lidas)

A lista aparece normal (itens lidos, `surface` plano, sem pontos), o badge no sino some e o botão
"Marcar todas como lidas" **não** aparece. É o estado natural depois que o usuário leu tudo — não é
um estado de erro nem vazio.

### 4.6. Erro — rede / 5xx no fetch da lista

Falha de `GET /api/notificacoes` por rede/5xx → erro centrado **dentro do painel** com retry, sem
lista falsa. O badge (que veio de outro fetch) permanece como estava.

```
+------------------------------------------+
| Notificações                              |
+------------------------------------------+
|              ⚠                           |
|  Não foi possível carregar suas           |
|  notificações.                            |
|  Verifique sua conexão.                   |
|        [ Tentar de novo ]                 |
+------------------------------------------+
```

### 4.7. Erro parcial — marcar-lida falhou

A marcação é **otimista** (some o ponto/decrementa o badge na hora). Se o `POST .../marcar-lida`
falhar, a navegação **já aconteceu** (o usuário foi ao destino) — então a reconciliação acontece no
próximo fetch (o item volta a aparecer como não-lido se o servidor não registrou). **Não** mostra
erro bloqueante por isso (seria ruído para uma ação secundária). "Marcar todas" que falhe reverte o
otimismo e mostra um `SnackBar` discreto: "Não foi possível marcar todas como lidas. Tente de novo."

### 4.8. Offline

Sem rede ao abrir: cai no estado de erro (§4.6) com retry. O badge mostra o último valor conhecido
(pode estar defasado) — aceitável no MVP (sem cache persistente; push é onda 2).

---

## 5. Microcopy completo

A copy in-app **reusa o `h1` e a 1ª linha do 1º parágrafo** de cada template de e-mail (STORY-053
§"texto-seed v1", convenção §99 da estória) — uma fonte de verdade, dois canais. Título curto;
resumo de até 2 linhas. Variáveis `{...}` vêm do `payload jsonb` da notificação.

| Lugar | Texto |
|---|---|
| Sino — tooltip | Notificações |
| Sino — badge (1–9) | {n} |
| Sino — badge (>9) | 9+ |
| Painel — título | Notificações |
| Painel — marcar todas | Marcar todas como lidas |
| **Item `candidatura_recebida` — título** | Nova candidatura recebida |
| **— resumo** | {profissional_nome} se candidatou à sua vaga de {vaga_funcao}. |
| **Item `vaga_editada_material` — título** | Vaga alterada — confirme |
| **— resumo** | A vaga de {vaga_funcao} mudou. Confirme se ainda quer participar. |
| **Item `vaga_cancelada` — título** | Vaga cancelada pelo contratante |
| **— resumo** | A vaga de {vaga_funcao} marcada para {vaga_data_inicio} foi cancelada. |
| **Item `..._candidatura_mantida` — título** | Candidato mantido após edição |
| **— resumo** | {profissional_nome} confirmou continuar na sua vaga de {vaga_funcao}. |
| **Item `..._candidatura_retirada` — título** | Candidato saiu da vaga após edição |
| **— resumo** | {profissional_nome} não confirmou as mudanças na vaga de {vaga_funcao}. |
| Item — tempo (< 1 min) | agora |
| Item — tempo (< 1 h) | há {n} min |
| Item — tempo (< 24 h) | há {n} h |
| Item — tempo (1 dia) | ontem · {HH:mm} |
| Item — tempo (> 1 dia) | {dd/mm · HH:mm} |
| Vazio — título | Nenhuma notificação ainda |
| Vazio — corpo | Quando algo acontecer com suas vagas ou candidaturas, avisamos aqui. |
| Erro (título) | Não foi possível carregar suas notificações. |
| Erro (corpo) | Verifique sua conexão. |
| Erro (retry) | Tentar de novo |
| Marcar-todas falhou (SnackBar) | Não foi possível marcar todas como lidas. Tente de novo. |

> Vocabulário: `glossary.md` ("Vaga", "Contratante", "candidatura", "função"). Datas/horas pt-BR
> 24h (DDR-002), formatadas por `TurniDateTime` (IDR-026). Tom: direto, sem emoji no corpo (o
> 🔔/⚠ dos estados é ilustração de estado, não copy). O título `vaga_editada_material` foi
> **encurtado** para "Vaga alterada — confirme" (o `h1` do e-mail, "Uma vaga em que você se
> candidatou foi editada", é longo demais para uma linha de lista) — a 1ª linha do parágrafo
> carrega o contexto completo.

---

## 6. Acessibilidade (notas específicas)

- **Sino:** `IconButton` com `tooltip: 'Notificações'`; quando há não-lidas, o `Semantics` anuncia
  a contagem — `Semantics(label: 'Notificações, {n} não lidas')`. O `Badge` Material já é lido,
  mas reforçamos no label para não depender de cor/posição.
- **Item não-lido:** o estado "não-lida" é anunciado por texto, não só pelo ponto/cor —
  `Semantics(label: '{título}. {resumo}. {tempo}. Não lida.')`. Item lido omite "Não lida".
- **Cada item é um botão** semântico (`Semantics(button: true)`), foco visível (anel `accent` do
  papel), navegável por teclado (Tab no web).
- **Ícone do tipo:** decorativo (`ExcludeSemantics`) — o título já diz a natureza.
- **Painel (`endDrawer`):** ao abrir, foco vai para o cabeçalho; `Esc`/scrim fecha; ordem de foco
  = cabeçalho → "marcar todas" → itens (de cima para baixo). Trap de foco padrão do `Drawer`.
- **Live region:** o desfecho do fetch (vazio/erro/lista) é anunciado (`Semantics(liveRegion:
  true)`); o badge que muda de contagem usa `liveRegion` discreto para leitor de tela.
- **Contraste:** badge `error` (branco/`#B83A3A` = 5.7:1 AA); ponto e fundo `accent.soft` do papel,
  título `text.strong`, resumo `text.muted` (7.7:1), tempo `text.subtle` **apenas** porque é texto
  pequeno **não-essencial e duplicado** pela ordem cronológica (atende a regra §6.3 do tokens — é
  metadado, não conteúdo crítico); ainda assim ≥ caption 13px no desktop. Em mobile, o tempo usa
  `text.muted` para passar AA normal (≥ `body-sm` 14? — usa `caption` 13 só no desktop; mobile
  mantém `text.muted`).
- **Alvos de toque ≥48dp:** sino, "marcar todas", cada item (≥56dp de altura).
- **`prefers-reduced-motion`:** o slide do painel respeita `MediaQuery.disableAnimations`
  (abre sem animação).

---

## 7. Identificadores estáveis sugeridos para teste

| Elemento | Identificador lógico sugerido |
|---|---|
| Sino (AppBar) | `notificacoes-sino-btn` |
| Badge de contagem | `notificacoes-badge` |
| Painel (endDrawer raiz) | `notificacoes-painel` |
| Cabeçalho — título | `notificacoes-painel-titulo` |
| Marcar todas como lidas | `notificacoes-marcar-todas-btn` |
| Lista (container) | `notificacoes-lista` |
| Item (por notificação) | `notificacao-item-{id}` |
| Item — ponto de não-lida | `notificacao-item-{id}-naolida` |
| Item — título | `notificacao-item-{id}-titulo` |
| Item — resumo | `notificacao-item-{id}-resumo` |
| Item — tempo | `notificacao-item-{id}-tempo` |
| Estado vazio | `notificacoes-vazio` |
| Estado erro | `notificacoes-erro` |
| Retry | `notificacoes-retry-btn` |
| Skeleton (loading) | `notificacoes-skeleton` |

> Nomes lógicos — o Programador aplica como `Key('...')`. O E2E (CA-12) abre
> `notificacoes-sino-btn`, confere `notificacao-item-{id}` no `notificacoes-lista`, toca e valida a
> navegação ao destino + o decremento do `notificacoes-badge`.

---

## 8. Exceções ao Design System

| O que diverge | Por quê | Vira DDR? |
|---|---|---|
| `notification.bell` — sino (`Icons.notifications_outlined`) com `Badge` M3 de contagem nas `actions:` do AppBar. **1º uso de badge de contagem no app.** | Padrão universal de central de notificações; Material já entrega `IconButton` + `Badge`. Reaparece em qualquer tela com AppBar persistente (EPIC-003+: aceite/turno também notificam). | **Sim — candidato.** Promover a `notification.bell` no DS quando EPIC-003 reusar (2º uso confirma o padrão "sino persistente no AppBar"). |
| `notification.panel` — painel lateral via **`endDrawer`** (400dp à direita no desktop/tablet, full-width no mobile) com cabeçalho fixo + lista. | "Painel lateral" da estória mapeia direto para `endDrawer` do Flutter — sem componente custom. É a 1ª central de notificação; o padrão (drawer à direita p/ contexto secundário) é durável. | **Sim — candidato.** Registrar o padrão "contexto secundário abre em `endDrawer` à direita" (≠ navegação primária, que é `NavigationBar`/`Rail`). |
| `notification.tile` — item: ícone-tipo circular + ponto de não-lida (acento) + título + resumo (2 linhas) + tempo. Fundo `accent.soft` quando não-lido. | Variante de `ListTile` com hierarquia própria (não é o card de candidato nem o de vaga). Recorre sempre que houver feed de eventos. | Registrar junto da família de listas quando EPIC-003 reusar. |
| Badge de contagem em **`error`** (vermelho), não no acento do papel | Convenção de notificação (pendência não vista). É o **único** uso não-destrutivo do vermelho — proposital, sancionado aqui pela regra de contexto DDR-001 (cor semântica transitória; numérico sobre sino não confunde com erro). | Documentar a exceção no DS (uso sancionado do `error` para contagem de notificação). |
| `empty.state` / `error.state` / `skeleton` reusados (feed 048, painel 051) — agora dentro do `endDrawer` | 4º+ uso dos estados padrão; só muda o container (painel em vez de tela cheia). | Já recorrentes; promover a família `state.*` ao DS (vazio/erro/skeleton) — durabilidade sobejamente confirmada. |

Nenhuma exceção viola token de cor/contraste — sino, painel, item, badge e estados usam tokens
auditados AA (DDR-001 §6). A decisão "badge = `error`, ponto de não-lida = acento do papel" segue a
regra de contexto do DDR-001 (semântica transitória vs. identidade do papel).

---

## 9. Protótipo HTML fiel (validação humana)

- **Localização:** `SCREEN-STORY-053-notificacoes/index.html` (mesma pasta deste spec).
- **Cobertura:** seletor de **viewport** (mobile/desktop), seletor de **papel** (profissional
  verde / contratante mostarda — o mesmo painel nos dois acentos) e seletor de **estado**
  (`?state=`): `lista` (mix de não-lidas + lidas, os 5 tipos), `loading` (skeleton), `vazio`,
  `tudo-lido`, `erro`. O badge no sino reflete a contagem de cada estado; um clique no sino
  abre/fecha o painel.
- **Fidelidade:** tokens reais do DS (acento por papel, `error` no badge, `accent.soft` no item
  não-lido, `surface.sunken` no ícone-tipo, tipografia Inter, raios, motion 300ms do slide);
  microcopy = §5 palavra por palavra (os 5 tipos com variáveis preenchidas por exemplo); datas/
  horas pt-BR 24h; identificadores da §7 como `data-testid`.
- **Restrições:** HTML/CSS/JS vanilla, sem rede, abre clicando. Mock inline. Comentário no topo:
  "protótipo de validação, não código de produção".

### Checklist antes de marcar spec `ready`

- [ ] Spec cobre badge (0/1–9/>9) + lista (5 tipos, lido/não-lido) + loading + vazio + tudo-lido + erro + parcial.
- [ ] Microcopy §5 completo (sino, painel, os 5 tipos, tempos relativos, estados).
- [ ] Identificadores §7 cobrem sino, badge, painel, itens, estados.
- [ ] Exceções §8 justificadas (bell, panel, tile, badge `error`, estados).
- [ ] Protótipo HTML criado, todos os estados + ambos os papéis + ambos os viewports acessíveis.
- [ ] Protótipo apresentado ao humano e sinal de validação capturado.

---

## 10. Dependências e premissas

- **Endpoints (contrato — estória CA-7):**
  - `GET /api/notificacoes?lidas=false` → contagem + itens não-lidos (para o badge).
  - `GET /api/notificacoes` → últimas 50 (lidas + não-lidas), `criada_em DESC`. Cada item:
    `{ id, tipo, vaga_id, candidatura_id, payload, lida_em, criada_em }`.
  - `POST /api/notificacoes/{id}/marcar-lida` → marca uma.
  - `POST /api/notificacoes/marcar-todas-lidas` → marca todas do usuário.
  - O `payload jsonb` carrega as variáveis da §5 (`profissional_nome`, `vaga_funcao`,
    `vaga_data_inicio`, etc.) — a UI interpola na hora; **não** recalcula nem reconsulta.
- **Destino interno por tipo:** derivado de `tipo` + `vaga_id` (tabela da §2). A UI **não** usa as
  URLs absolutas do e-mail.
- **Sem polling / sem push no MVP:** o badge atualiza no mount da home e ao abrir o painel; push
  nativo (FCM/APNs/Web Push) é **onda 2** (fora de escopo da estória). Aceitável: o e-mail cobre
  quem está com o app fechado.
- **Sem preferências de notificação:** receber tudo é o default (fora de escopo da estória).
- **Coexistência:** o sino é **aditivo** aos AppBars existentes de 048 (feed) e 047 (minhas vagas)
  — entra nas `actions:` antes do "Sair", sem mexer no resto da tela. As exceções §8 (`bell`,
  `panel`, `tile`) são aditivas e candidatas a promoção quando EPIC-003 reusar.
- **Tema dual** (PDR-013) auditado AA nos dois papéis.

---

## 11. Histórico de mudanças

| Data | Mudança | Quem | Motivo |
|---|---|---|---|
| 2026-06-03 | criação (spec completo: sino+badge nos dois AppBars, painel `endDrawer`, 5 tipos de item, estados lista/loading/vazio/tudo-lido/erro/parcial, microcopy reusando o texto-seed dos e-mails) | claude-opus-4-8 (designer) | STORY-053 destravada (texto-seed v1 aprovado pelo PO 2026-06-03); spec da parte in-app (CA-8) para guiar a implementação |
| 2026-06-03 | validação humana — protótipo aprovado; `status: ready` | Alexandro | protótipo HTML conferido no navegador (papel × viewport × estado); título encurtado "Vaga alterada — confirme", badge `error`, tempo relativo DDR-002 aprovados em chat |
