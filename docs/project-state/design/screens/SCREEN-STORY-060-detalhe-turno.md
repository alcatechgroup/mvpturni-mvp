---
id: SCREEN-STORY-060-detalhe-turno
story: STORY-060-detalhe-turno-timeline-trilha-auditoria
epic: EPIC-003-aceite-pin-e-pix
status: ready                # draft | ready | in_implementation | shipped | superseded
created_at: 2026-06-05
updated_at: 2026-06-05
owner_designer: claude-opus-4-8
related_ddrs: [DDR-001, DDR-002]
ds_components_used: [brand.logo, surface.card, badge.status, banner, link.text, section.group-header, skeleton.card, button.primary]
exceptions_to_ds: [timeline.event (lista vertical de eventos com dot+linha — 1º uso; candidato a promoção quando STORY-061+ reusarem), dialog.document (modal somente-leitura de documento longo — 1º uso; roadmap do DS já previa `dialog`)]
viewports: [mobile, desktop]
prototype_path: SCREEN-STORY-060-detalhe-turno/index.html
prototype_last_validated_at: 2026-06-05  # aprovado por Alexandro em chat (sem ajustes)
---

# Spec de tela — SCREEN-STORY-060 — Detalhe do turno + timeline

> Referência: estória `STORY-060`. CAs e contexto vêm de lá — **não duplico**.
> **Uma rota compartilhada** `/turnos/{id}` (ADR-018: `{id}` é UUIDv7), tema resolvido pelo
> **papel do usuário logado** (DDR-001): profissional vê acento verde-sage, contratante mostarda.
> É a **casa do turno** — as estórias 061/062/063/064/066 vão preencher a área de ações; esta
> tela entrega a moldura: atributos, estado, valor (visibilidade por papel —
> `domain/pagamento.md` §"Visibilidade financeira"), timeline (audit log simplificado —
> `domain/compliance.md` §"Trilha de auditoria") e o aceite eletrônico em modal somente-leitura.
> Locale/horário: DDR-002 (pt-BR, 24h). Princípios: **#1** simplicidade (zero ação real ainda —
> a tela responde "em que pé está e o que aconteceu"), **#2** mobile-first (profissional usa na
> rua), **#5** WCAG AA (estado nunca só por cor), **#6** skeleton, **#7** todos os estados.

A lista da SCREEN-059 leva até aqui: o card do turno **vira navegável** (decisão já antecipada
na 059 §10 — sem mudança de anatomia, o card inteiro vira alvo de toque ≥48dp com ripple/hover).

---

## Tema e perfil

- Tema **pelo papel do usuário logado**, não pela rota: profissional acento `#2D5F3F`
  (`on-accent` branco 7.4:1 ✅), contratante `#9A6E25` (`accent.ink` `#6E4E12`).
- **Selo de estado usa cor semântica, não de perfil** (mesmas variantes da SCREEN-059 §4.1,
  já registradas em `components.md`).
- Marca `TURNI.` no topo desktop. Dual-theme claro/escuro (PDR-013) via tokens auditados.

---

## 1. Objetivo da tela

Responder em um olhar: **"em que pé está este turno, quanto vale e o que já aconteceu?"** —
e ser o lugar único onde as ações futuras (PIN, cronômetro, cancelamento) vão morar. Hoje a
tela é leitura pura + 1 link (aceite eletrônico).

---

## 2. Fluxo

### Entrada

- **Toque no card** das listas da 059 (`/profissional/turnos` e `/contratante/turnos`) →
  navega `/turnos/{id}`. O card ganha affordance de clique (ripple no toque, elevação no
  hover web, cursor pointer) — anatomia inalterada, sem chevron.
- **URL direta / deep-link:** rota endereçável, sobrevive a reload (go_router). Funnel guard
  (STORY-016) garante sessão; RBAC do backend garante posse (403 → §4.5).

### Ações possíveis na tela

- **Voltar** (AppBar leading) → lista de turnos do papel (`/profissional/turnos` ou
  `/contratante/turnos`). Fallback para a home do papel se a pilha estiver vazia (deep-link).
- **"Ver aceite eletrônico"** (`link.text` com ícone de documento) → abre modal
  somente-leitura com o `conteudo_renderizado` (§4.7). Única interação real da tela.
- **Área de ações:** placeholder (CA-4) — nenhuma ação concreta nesta estória (§3, §4.1).
- **Erro de fetch:** retry inline.

### Saída

- Voltar para a lista do papel. Modal do aceite fecha por botão, ESC (web) e toque fora.

---

## 3. Layout

### Mobile (≥360px)

AppBar com voltar + título. Conteúdo em coluna única, do mais quente ao mais frio:
**estado → o quê/quando/onde → valor → aceite → ações → histórico**.

```
+------------------------------------------+
| ←  Detalhe do turno                      |  AppBar (voltar + título)
+------------------------------------------+
|  +------------------------------------+  |
|  | ● Confirmado                       |  |  badge.status (mesmas variantes da 059)
|  | Garçom                             |  |  função (headline)
|  | Bar do Zé                          |  |  estabelecimento (prof.) / profissional (contr.)
|  | Sex, 12/06 · 18:00–23:00           |  |  data/hora 24h pt-BR (DDR-002)
|  +------------------------------------+  |
|  +------------------------------------+  |
|  | Você recebe                        |  |  card de valor — PROFISSIONAL
|  | R$ 200,00                          |  |  destaque (display)
|  | valor integral · taxa Turni        |  |  letra menor (text.muted)
|  | cobrada do contratante             |  |
|  +------------------------------------+  |
|  📄 Ver aceite eletrônico              › |  link.text (alvo ≥48dp)
|  +------------------------------------+  |
|  | Nenhuma ação disponível no momento |  |  área de ações (CA-4 — placeholder)
|  | As ações deste turno aparecem aqui |  |
|  | conforme ele avança.               |  |
|  +------------------------------------+  |
| HISTÓRICO                                |  section.group-header (2º uso — promovido)
|  ●  Pagamento reservado                  |  timeline.event (mais recente primeiro)
|  │  pelo contratante                     |
|  │  Qua, 03/06 · 15:47                   |
|  ●  Aceite eletrônico emitido            |
|  │  Qua, 03/06 · 15:47                   |
|  ●  Turno confirmado                     |
|     Candidatura aprovada.                |
|     Qua, 03/06 · 15:46                   |
+------------------------------------------+
```

Card de valor — **CONTRATANTE** (mesma posição, conteúdo diferente — CA-2 +
`domain/pagamento.md`):

```
|  +------------------------------------+  |
|  | Pagamento deste turno              |  |
|  | Valor do profissional   R$ 200,00  |  |
|  | Taxa Turni              R$  30,00  |  |
|  | ----------------------------------  |  |
|  | Total                   R$ 230,00  |  |  destaque (linha forte)
|  +------------------------------------+  |
```

- Header do contratante ganha **linha extra com o profissional** (quem vem) acima do
  estabelecimento — espelha a prioridade de informação da 059.
- Componentes DS: `surface.card`, `badge.status`, `link.text`, `section.group-header`,
  `banner`, skeleton; novos (exceções §8): `timeline.event`, `dialog.document`.
- Sem FAB, sem `button.primary` no caminho feliz — a área de ações é moldura vazia (CA-4);
  o primeiro botão grande chega na STORY-061.

### Desktop (≥1024px)

Conteúdo centralizado, max ~960px, **duas colunas**: à esquerda a coluna do turno (estado +
valor + aceite + ações), à direita o histórico — leitura simultânea "onde estou × como cheguei".

```
+------------------------------------------------------------------+
|                            TURNI.                                |
|  ← Detalhe do turno                                              |
|                                                                  |
|  +---------------------------+   HISTÓRICO                       |
|  | ● Confirmado              |   ●  Pagamento reservado          |
|  | Garçom                    |   │  Qua, 03/06 · 15:47           |
|  | Bar do Zé                 |   ●  Aceite eletrônico emitido    |
|  | Sex, 12/06 · 18:00–23:00  |   │  Qua, 03/06 · 15:47           |
|  +---------------------------+   ●  Turno confirmado             |
|  +---------------------------+      Candidatura aprovada.        |
|  | Você recebe               |      Qua, 03/06 · 15:46           |
|  | R$ 200,00                 |                                   |
|  | valor integral · taxa …   |                                   |
|  +---------------------------+                                   |
|  📄 Ver aceite eletrônico  ›                                     |
|  +---------------------------+                                   |
|  | Nenhuma ação disponível…  |                                   |
|  +---------------------------+                                   |
+------------------------------------------------------------------+
```

### Tablet (768px)

Colapsa para coluna única (ordem do mobile) quando as 2 colunas não couberem (~440px + gap
cada — mesma regra de `LayoutBuilder` da 047/059).

---

## 4. Estados

### 4.1. Caminho feliz (turno carregado)

- **Badge de estado:** exatamente as variantes da SCREEN-059 §4.1 (componente já registrado).
- **Área de ações (CA-4):** card neutro com texto quieto (sem botão). Visível em estados
  **não-terminais** (`confirmado`, `aguardando_checkin`, `ativo`, `aguardando_checkout`,
  `em_disputa`); **oculta** em terminais (`finalizado*`, `cancelado_*`, `no_show_pro`,
  `disputa_resolvida_sem_pagamento`) — não prometer ação onde nunca haverá.
  O container reserva o espaço do "botão grande, alta legibilidade" que a 061+ vai ocupar.
- **Timeline (CA-3):** ordem cronológica **descendente** (mais recente no topo). Cada evento:
  dot + linha vertical, título amigável (forte), descrição opcional (muted), timestamp
  `EEE, dd/MM · HH:mm` (24h pt-BR; ano explícito `dd/MM/yyyy` quando ≠ ano corrente).
  Evento de papel: descrição financeira **filtrada por papel** (tabela abaixo).
  Evento desconhecido (back na frente do front): renderiza com título genérico
  "Atualização do turno" + timestamp — **nunca quebra**, loga em console.

Mapa evento → microcopy (CA-3; coluna por papel quando difere):

| Evento (audit log) | Título | Descrição (profissional) | Descrição (contratante) |
|---|---|---|---|
| `turno_criado` | Turno confirmado | Candidatura aprovada. | Candidatura aprovada. |
| `aceite_eletronico_emitido` | Aceite eletrônico emitido | — | — |
| `pagamento_pre_autorizado` | Pagamento reservado | O contratante garantiu o pagamento deste turno. | R$ 230,00 reservados no seu meio de pagamento. |
| `checkin_solicitado` | PIN de check-in gerado | — (061 anexa nota de geofencing) | — (061 anexa nota de geofencing) |
| `checkin_validado` | Check-in validado | Turno iniciado. | Turno iniciado. |
| `checkout_solicitado` | PIN de check-out gerado | — | — |
| `checkout_validado` | Check-out validado | Turno encerrado. | Turno encerrado. |
| `pagamento_capturado` | Pagamento processado | — | R$ 230,00 cobrados do seu meio de pagamento. |
| `pix_enviado` | Pix enviado | R$ 200,00 enviados para você. | Pix enviado ao profissional. |
| `cancelado` | Turno cancelado | Cancelado pelo {profissional\|contratante}. | idem |
| `no_show_pro` | Turno não realizado | O check-in não aconteceu até o limite. | idem |

> **Nota ao PO:** os valores nas descrições seguem a visibilidade do papel
> (`domain/pagamento.md`): o profissional **nunca** vê `taxa_turni`/`total_contratante` na
> timeline; o contratante vê o total. O valor que o profissional recebe aparece só no
> `pix_enviado` (é o momento em que o dinheiro é dele).

### 4.2. Loading (primeiro fetch e refresh)

Skeleton com a silhueta da tela: 1 card header (3 barras) + 1 card valor (2 barras) + header
de seção + 3 eventos (dot + 2 barras). Shimmer da 047/059. Nunca spinner em tela vazia.

### 4.3. Erro — rede / servidor no fetch

`banner` de erro no topo com retry (padrão 047/059):

```
| ⚠ Não foi possível carregar o turno.      |
|   Verifique sua conexão.  [Tentar de novo]|
```

### 4.4. Turno não encontrado (404)

ID inexistente (link errado, turno apagado em seed). Estado central:

"**Turno não encontrado** / O link pode estar errado ou o turno não existe mais.
[Ir para meus turnos]" (CTA navega para a lista do papel; label por papel — §5).

### 4.5. Sem permissão (403 — RBAC cruzado, fail-secure)

Backend responde **403** (CA-1) quando o turno existe mas não é do usuário. A tela mostra o
**mesmo estado visual do 404** (§4.4) — não confirmar a existência de turno alheio é parte do
fail-secure. (Distinção 403×404 vive no log/API, não na UI.)

### 4.6. Parcial / degradado

- Timeline vazia ou indisponível (falha só no audit log): header + valor renderizam; no lugar
  do histórico, texto quieto "Histórico indisponível no momento." — a tela nunca quebra por
  causa da trilha.
- Campo derivado ausente (ex.: nome do profissional): linha omitida, nunca placeholder cru.

### 4.7. Modal do aceite eletrônico (CA-5)

- **Mobile:** sheet de tela cheia (slide-up). **Desktop:** dialog central max ~720px,
  altura max ~80vh, conteúdo rola.
- Anatomia: título "Aceite eletrônico" + subtítulo "Emitido em {EEE, dd/MM · HH:mm} ·
  somente leitura" + botão fechar (×, alvo ≥48dp) + corpo = `conteudo_renderizado` do
  AceiteEletronicoTurno (documento autocontido, imutável — ADR-010/ADR-015), tipografia de
  leitura (15–16px, line-height 1.6).
- **Estados próprios:** loading (skeleton de parágrafos), erro ("Não foi possível carregar o
  aceite. [Tentar de novo]"), conteúdo.
- Fecha por ×, ESC (web) e toque no scrim. Foco entra no modal ao abrir (focus trap) e volta
  ao link ao fechar.
- Zero ação além de ler e fechar — imutabilidade é o ponto.

---

## 5. Microcopy completo

| Lugar | Texto |
|---|---|
| Título da tela (AppBar, ambos) | Detalhe do turno |
| Selos de estado | tabela SCREEN-059 §4.1 (inalterada) |
| Card valor — título (profissional) | Você recebe |
| Card valor — destaque (profissional) | R$ {valor} |
| Card valor — nota (profissional) | valor integral · taxa Turni cobrada do contratante |
| Card valor — título (contratante) | Pagamento deste turno |
| Card valor — linha 1 (contratante) | Valor do profissional — R$ {valor} |
| Card valor — linha 2 (contratante) | Taxa Turni — R$ {taxa_turni} |
| Card valor — linha total (contratante) | Total — R$ {total_contratante} |
| Link do aceite | Ver aceite eletrônico |
| Modal aceite — título | Aceite eletrônico |
| Modal aceite — subtítulo | Emitido em {EEE, dd/MM · HH:mm} · somente leitura |
| Modal aceite — erro | Não foi possível carregar o aceite. |
| Modal aceite — fechar (a11y label) | Fechar |
| Área de ações — título | Nenhuma ação disponível no momento |
| Área de ações — apoio | As ações deste turno aparecem aqui conforme ele avança. |
| Header da timeline | Histórico |
| Eventos da timeline | tabela §4.1 |
| Evento desconhecido | Atualização do turno |
| Timeline indisponível (§4.6) | Histórico indisponível no momento. |
| Erro de fetch (banner) | Não foi possível carregar o turno. Verifique sua conexão. |
| Retry | Tentar de novo |
| Não encontrado — título (404/403) | Turno não encontrado |
| Não encontrado — texto | O link pode estar errado ou o turno não existe mais. |
| Não encontrado — CTA (profissional) | Ir para meus turnos |
| Não encontrado — CTA (contratante) | Ir para turnos |

Datas/horas pt-BR 24h (DDR-002): `Sex, 12/06 · 18:00–23:00` no header;
`Qua, 03/06 · 15:47` nos eventos (ano `dd/MM/yyyy` quando ≠ corrente). Valores `R$ 1.234,56`.
Vocabulário do glossário; tom direto, sem "Ops!".

---

## 6. Acessibilidade (notas específicas)

- **Header do turno**: `MergeSemantics` (estado + função + onde/quem + quando) — leitor
  anuncia o resumo coeso. Badge com rótulo textual (cor nunca canal único).
- **Card de valor (contratante)**: linhas como pares rótulo-valor legíveis em sequência;
  o total marcado como mais relevante na ordem de leitura (último, com rótulo "Total").
- **"Histórico"** é heading semântico (`Semantics(header: true)`).
- **Timeline**: cada evento é um nó `Semantics` único — "{título}, {descrição}, {data hora}".
  Dots/linhas são decorativos (`excludeSemantics`). Ordem de leitura = ordem visual
  (descendente).
- **Modal do aceite**: focus trap; `barrierDismissible`; botão fechar com
  `Semantics(label: 'Fechar')`; ao abrir, anuncia o título; corpo é texto navegável.
- **Link do aceite**: alvo ≥48dp, descreve o destino (não "clique aqui").
- **Banner de erro / retry**: `liveRegion: true`; retry por teclado, foco visível.
- **Contraste**: tokens auditados AA (tokens.md §6); nenhuma combinação nova.

---

## 7. Identificadores estáveis sugeridos para teste

| Elemento | Identificador lógico sugerido |
|---|---|
| Tela (raiz) | `turno-detalhe-screen` |
| Badge de estado | `turno-detalhe-estado` |
| Função (headline) | `turno-detalhe-funcao` |
| Linha quem/onde | `turno-detalhe-onde` |
| Linha data/hora | `turno-detalhe-quando` |
| Card de valor | `turno-detalhe-valor` |
| Total (contratante) | `turno-detalhe-valor-total` |
| Link do aceite | `turno-detalhe-aceite-btn` |
| Modal do aceite | `aceite-modal` |
| Conteúdo do modal | `aceite-modal-conteudo` |
| Fechar modal | `aceite-modal-fechar` |
| Área de ações (placeholder) | `turno-detalhe-acoes` |
| Header da timeline | `turno-detalhe-historico-header` |
| Lista da timeline | `turno-detalhe-timeline` |
| Evento (por uuid do audit log) | `timeline-evento-{id}` |
| Skeleton | `turno-detalhe-skeleton` |
| Banner de erro | `turno-detalhe-erro-banner` |
| Retry | `turno-detalhe-retry-btn` |
| Não encontrado (404/403) | `turno-nao-encontrado` |
| CTA do não encontrado | `turno-nao-encontrado-cta` |
| Card navegável da lista 059 | `turno-card-{id}` (existente — ganha `onTap`) |

> `{id}` é UUIDv7 string (ADR-018). O E2E (CA-6) ancora em `turno-card-{id}` (lista) →
> `turno-detalhe-screen` + `turno-detalhe-estado` para os 2 papéis.

---

## 8. Exceções ao Design System

| O que diverge | Por quê | Vira DDR? |
|---|---|---|
| `timeline.event` — evento de linha do tempo (dot + linha vertical + título/descrição/timestamp) | DS não tem timeline; é o coração do CA-3. Flutter: `Column` de linhas com `CustomPaint`/`Container` para dot+linha (sem lib externa). Reaparece em 061+ (eventos de PIN/geofencing) e no Backoffice (trilha completa, follow-up). | **Candidato** — promover quando 061+ reusar. |
| `dialog.document` — modal somente-leitura para documento longo (sheet cheio mobile / dialog desktop) | Roadmap do DS já previa `dialog`; 1º uso real. Flutter: `showDialog` / `showModalBottomSheet(isScrollControlled: true)`. Reaparece em STORY-061+ (?) e EPIC-005 (disputa). | **Candidato** — promover no 2º uso. |
| `section.group-header` — **2º uso** (header "Histórico") | A 059 marcou como candidato a promoção quando a 060 reusasse — reuso confirmado; promover no `components.md` na implementação. | Não — promoção já prevista; registrar em `components.md`. |

Nenhuma cor nova: tudo em tokens semânticos auditados AA.

---

## 9. Protótipo HTML fiel (validação humana)

- **Localização:** `SCREEN-STORY-060-detalhe-turno/index.html`.
- **Cobertura:** seletor de **papel** (Profissional/Contratante — troca tema + card de valor +
  descrições da timeline), **viewport** (mobile/desktop) e **estado**:
  `confirmado` (pós-058 — timeline com 3 eventos + área de ações), `ciclo-completo`
  (turno `finalizado` — timeline com todos os eventos do CA-3, sem área de ações),
  `cancelado` (timeline com cancelamento + liberação), `loading`, `erro`, `nao-encontrado`.
  Modal do aceite abre pelo link real (estado de conteúdo; loading/erro do modal
  especificados em §4.7) — atalho `?modal=1` para validação direta.
- **Fidelidade:** tokens reais dos dois temas; microcopy = §5 palavra por palavra;
  identificadores da §7 como `data-testid`; datas pt-BR 24h.
- **Restrições:** HTML/CSS/JS vanilla, sem rede, mock inline, comentário "protótipo de
  validação".

### Checklist antes de marcar spec `ready`

- [x] Protótipo abre sem erro; todos os estados acessíveis nos dois papéis e dois viewports.
- [x] Microcopy bate palavra por palavra com a §5.
- [x] Identificadores da §7 presentes.
- [x] Tokens reais dos temas profissional e contratante.
- [x] Protótipo apresentado ao humano e sinal de validação capturado (inclui a Nota ao PO
      da §4.1 sobre visibilidade financeira na timeline e a decisão §4.5 de 403 renderizar
      como "não encontrado").

---

## 10. Dependências e premissas

- **Endpoint (contrato — estória CA-1):** `GET /api/turnos/{id}` → turno + timeline + aceite,
  **já filtrados por papel no servidor** (o front não filtra valor — defesa em profundidade:
  o payload do profissional nem carrega `taxa_turni`/`total_contratante`):
  - Comum: `id`, `funcao`, `data_inicio`, `data_fim`, `estado`,
    `timeline[] { id, evento, descricao?, valor?, lado?, ocorrido_em }`,
    `aceite { emitido_em }` (conteúdo pode vir junto ou em
    `GET /api/turnos/{id}/aceite` — decisão do Programador; o modal tolera os dois).
  - Profissional: + `valor`, `estabelecimento { nome }`.
  - Contratante: + `valor`, `taxa_turni`, `total_contratante`, `profissional { nome }`,
    `estabelecimento { nome }`.
  - RBAC fail-secure: 403 cruzado (CA-1); front renderiza §4.5.
- **Card da 059 vira navegável** — parte desta entrega (sem isso a tela não tem porta de
  entrada). Anatomia do card inalterada (decisão da 059 §10).
- **Timeline renderiza o que o backend mandar**: hoje (pós-058) só existem
  `turno_criado`, `aceite_eletronico_emitido`, `pagamento_pre_autorizado`; o mapa §4.1 já
  cobre os eventos futuros para a 061+ não voltar aqui.
- **Sem cronômetro** (STORY-063) e **sem ações** (061/062/064/066) — a moldura está pronta
  para recebê-los (área de ações + slot acima da timeline).

---

## 11. Histórico de mudanças

| Data | Mudança | Quem | Motivo |
|---|---|---|---|
| 2026-06-05 | criação (spec completo + protótipo v1) | claude-opus-4-8 (designer) | STORY-060; spec + protótipo entregues juntos para validação humana |
| 2026-06-05 | validação humana — aprovado sem ajustes | Alexandro | inclui visibilidade financeira na timeline (§4.1), 403 como "não encontrado" (§4.5), placeholder de ações oculto em terminais; `status: ready` |
