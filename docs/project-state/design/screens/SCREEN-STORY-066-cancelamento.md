---
id: SCREEN-STORY-066-cancelamento
story: STORY-066-cancelamento-no-show-liberacao-preauth
epic: EPIC-003-aceite-pin-e-pix
status: shipped              # draft | ready | in_implementation | shipped | superseded
created_at: 2026-06-06
updated_at: 2026-06-06
owner_designer: claude-opus-4-8
related_ddrs: [DDR-001, DDR-002]
ds_components_used: [surface.card, badge.status, timeline.event, dialog.confirm, button.text, snackbar, banner, sidebar.admin, panel, data-table, chip, btn.outline, dialog-confirm, toast]
exceptions_to_ds: [button.text em ink error (variante destrutiva de baixa ênfase — 1º uso; candidata a promoção quando EPIC-005/disputa reusar), backoffice desktop-first (PDR-003 — exceção registrada na SCREEN-019)]
viewports: [mobile, desktop]
prototype_path: SCREEN-STORY-066-cancelamento/index.html
prototype_last_validated_at: 2026-06-06  # aprovado por Alexandro em chat (sem ajustes; motivo visível aos 2 lados + rename da fila confirmados)
---

# Spec de tela — SCREEN-STORY-066 — Cancelar turno + estados terminais + fila de falhas generalizada

> Referência: estória `STORY-066`. CAs e contexto vêm de lá — **não duplico**.
> Decisão do PO em chat (2026-06-06): **X do no-show = 2 horas** após o início previsto.
> Nenhuma tela nova: o cancelamento mora no **detalhe do turno** (SCREEN-060 — a "casa do
> turno"), os estados terminais já têm badge (SCREEN-059 §4.1) e timeline (SCREEN-060 §4.1),
> e a falha de liberação entra na **mesma fila da SCREEN-065** (CA-4). Princípios que
> dirigiram: **#1** (cancelar é exceção — baixa ênfase, nunca compete com a ação primária),
> **#3** (cancelamento é sério, sem drama nem culpa no microcopy), **#4** (reuso total:
> `dialog.confirm` no 3º uso, badges e timeline já especificados), **#7** (erro de rede,
> corrida de estado 422, falha de liberação e fila do admin são estados desenhados).

---

## Superfícies (duas, em plataformas diferentes)

| Superfície | Plataforma | O que muda |
|---|---|---|
| **A. Detalhe do turno** (`/turnos/{id}`, ambos os papéis, `confirmado`) | WebApp Flutter, mobile-first | Ação "Cancelar turno" (baixa ênfase, destrutiva) + `dialog.confirm` com motivo opcional; terminais ganham os eventos novos na timeline |
| **B. Fila de falhas** (`/pix-falhas`) | Backoffice Laravel/Livewire, desktop-first (PDR-003) | Fila da SCREEN-065 **generalizada**: casos "Liberação falhou" entram na mesma fila; rótulos viram "Falhas de pagamento" |

---

## A. WebApp — cancelar turno no detalhe

### A.1. Objetivo

Quem não vai poder cumprir o turno (qualquer lado) cancela **em dois toques conscientes**
— gatilho discreto + confirmação com consequência explícita — e sai com a verdade na tela:
badge terminal, timeline contando o que houve, reserva de pagamento liberada.

### A.2. Fluxo

#### Entrada

- Detalhe `/turnos/{id}` (SCREEN-060), papel profissional **ou** contratante, estado
  **`confirmado`** apenas (`domain/turno.md` — PDR-007: cancelamento só antes do check-in;
  em `aguardando_checkin` o gatilho **não aparece**).

#### Ações possíveis

- **Cancelar turno** (`button.text` destrutivo, padrão "pergunta? ação" das 061/062):
  abre o `dialog.confirm` (§A.4). Posição: **abaixo da área de ações, acima do
  histórico** (mobile) — perto das ações, mas fora do card primário: cancelar nunca
  compete com "Gerar PIN de check-in" (Princípio #1).
  - Profissional: `Não vai poder comparecer? Cancelar turno`
  - Contratante: `Não precisa mais deste turno? Cancelar turno`
- **No dialog:** confirmar (destrutiva), voltar (sem efeito), motivo opcional ≤280.

#### Saída

- **Sucesso:** dialog fecha → tela recarrega a verdade → badge `⊘ Cancelado`, área de
  ações oculta (terminal — 060 §4.1), timeline com `cancelado` + `pagamento_liberado`,
  snackbar discreto "Turno cancelado." Sem celebração, sem culpa.
- **Erro recuperável (rede):** erro inline no dialog; não fecha; estado não muda.
- **Corrida de estado (422):** o turno mudou debaixo do usuário (ex.: o outro lado
  cancelou antes, ou o profissional fez check-in). Erro inline "Este turno não pode mais
  ser cancelado." + ao fechar o dialog a tela **recarrega** (a verdade nova é o remédio).

### A.3. Layout — mobile (≥360px)

Mesmo layout da SCREEN-060; o que entra é o gatilho (estado `confirmado`, ambos os papéis):

```
|  +------------------------------------+  |
|  | Chegou ao local?                   |  |  área de ações (061 — profissional;
|  | [    Gerar PIN de check-in     ]   |  |  contratante vê o placeholder da 060)
|  +------------------------------------+  |
|                                          |
|     Não vai poder comparecer?            |  button.text destrutivo (ink error),
|     Cancelar turno                       |  centrado, alvo ≥48dp
|                                          |
| HISTÓRICO                                |
|  ●  Pagamento reservado                  |
|  ...                                     |
```

Estado terminal (`cancelado_pro` — visão do contratante, por ex.):

```
|  +------------------------------------+  |
|  | ⊘ Cancelado                        |  |  badge.status error esmaecido (059 §4.1)
|  | Garçom                             |  |
|  | Pedro Alves                        |  |
|  | Restaurante Vela                   |  |
|  | Dom, 08/06 · 11:00–17:00           |  |
|  +------------------------------------+  |
|  (card de valor — inalterado)            |
|  📄 Ver aceite eletrônico              › |
|  (sem área de ações — terminal)          |
| HISTÓRICO                                |
|  ●  Reserva de pagamento liberada        |
|  │  R$ 230,00 liberados no seu meio      |
|  │  de pagamento.                        |
|  │  Qui, 04/06 · 09:18                   |
|  ●  Turno cancelado                      |
|  │  Cancelado pelo profissional.         |
|  │  "Tive um imprevisto de saúde."       |
|  │  Qui, 04/06 · 09:18                   |
|  ●  Pagamento reservado ...              |
```

`no_show_pro` é igual ao cancelado, trocando badge (`⊘ Não realizado`) e eventos
(§A.5). **Desktop (≥1024px):** grid 2 colunas da 060 inalterado; o gatilho fica na
coluna esquerda, após a área de ações.

### A.4. Dialog de confirmação — `dialog.confirm` (3º uso, componente definitivo)

```
+------------------------------------------+
| Cancelar este turno?                     |
|                                          |
| A reserva do pagamento será liberada e   |
| o contratante será avisado. Essa ação    |
| não pode ser desfeita.                   |
|                                          |
| Motivo (opcional)                        |
| ┌──────────────────────────────────────┐ |
| │ Ex.: tive um imprevisto e não        │ |
| │ poderei comparecer                   │ |
| └──────────────────────────────────────┘ |
|                                          |
|              [ Voltar ] [ Cancelar turno]|
+------------------------------------------+
```

- Anatomia idêntica às 062/064: título-pergunta, corpo com a consequência (CA-1), campo
  opcional ≤280, ações à direita (Voltar à esquerda da destrutiva), destrutiva =
  `FilledButton` em `error` sólido (branco 5.7:1 ✅).
- Corpo por papel: profissional vê "...o **contratante** será avisado"; contratante vê
  "...o **profissional** será avisado".
- **Loading:** spinner inline na destrutiva; Voltar/ESC/scrim bloqueados durante a chamada.
- **Erro:** inline no rodapé (`liveRegion`), dialog NÃO fecha (padrão `dialog.confirm`).
- Foco inicial em **Voltar** (nunca na destrutiva); ESC e toque fora fecham sem efeito.

### A.5. Timeline — eventos novos (estende o mapa da SCREEN-060 §4.1)

| Evento (audit log) | Título | Descrição (profissional) | Descrição (contratante) |
|---|---|---|---|
| `cancelado` (lado pro) | Turno cancelado | Você cancelou este turno. | Cancelado pelo profissional. |
| `cancelado` (lado emp) | Turno cancelado | Cancelado pelo contratante. | Você cancelou este turno. |
| `no_show_pro` | Turno não realizado | O check-in não aconteceu em até 2 horas após o início previsto. | idem |
| `pagamento_liberado` | Reserva de pagamento liberada | O contratante não foi cobrado. | R$ 230,00 liberados no seu meio de pagamento. |

- **Motivo do cancelamento** (quando informado) aparece como linha extra do evento
  `cancelado`, entre aspas, em `text.muted` itálico — **visível para os dois lados**
  (quem cancela é avisado disso no placeholder? Não — o corpo do dialog já diz que o
  outro lado "será avisado"; o motivo faz parte do aviso).
  > **Nota ao PO (validação):** confirmar que o motivo é visível ao outro lado. A
  > alternativa (motivo só para admin) esvazia o valor do campo para quem lê a timeline.
- A descrição de `no_show_pro` da 060 ("O check-in não aconteceu até o limite.") fica
  **mais específica** com o X decidido (2h) — mudança consciente registrada em §11.
- **Falha da liberação NÃO aparece na timeline do usuário** (espelho da decisão da 065
  §A.4): `pagamento.liberacao_falhou` é operacional — vai para audit log + fila do admin
  (superfície B). O usuário vê o turno cancelado normalmente; sem `pagamento_liberado`
  até a operação resolver. Sem ansiedade sem próximo passo (Princípio #1).

### A.6. Estados (superfície A)

| Estado | O que mostra |
|---|---|
| `confirmado`, qualquer papel | Gatilho "…? Cancelar turno" visível (§A.3). Convive com o card de PIN do profissional (janela aberta, fechada ou encerrada — cancelável enquanto `confirmado`). |
| `aguardando_checkin` e demais não-terminais | **Sem gatilho** (PDR-007). Nada muda em relação às 060–064. |
| Dialog aberto | §A.4. |
| Dialog em loading | Destrutiva com spinner; demais controles bloqueados. |
| Dialog com erro de rede | "Não foi possível cancelar. Tente de novo." inline; não fecha. |
| Dialog com 422 (corrida) | "Este turno não pode mais ser cancelado." inline; ao fechar, a tela recarrega. |
| `cancelado_pro` / `cancelado_emp` | Badge `⊘ Cancelado`; sem área de ações; timeline com `cancelado` (+ motivo) e `pagamento_liberado`; snackbar "Turno cancelado." quando a transição acabou de acontecer nesta sessão. |
| `no_show_pro` | Badge `⊘ Não realizado`; sem área de ações; timeline com `no_show_pro` e `pagamento_liberado`. Nenhuma ação do usuário leva a este estado — ele é encontrado, não provocado. |
| Liberação falhou | UI do usuário **idêntica** ao cancelado normal, sem o evento `pagamento_liberado` (§A.5). Tratamento é operacional (superfície B). |
| Loading / erro / 404 / 403 | Inalterados (SCREEN-060 §4.2–4.5). |

### A.7. Acessibilidade (superfície A)

- Gatilho é `button.text` com alvo ≥48dp apesar do visual leve; ink `error` `#B83A3A`
  sobre `page` passa AA (mesmo par do banner de erro); o rótulo completo ("Não vai poder
  comparecer? Cancelar turno") é o nome acessível — descreve a ação, não "clique aqui".
- Dialog: focus trap; foco inicial em Voltar; `barrierDismissible` fora do loading;
  textarea com label explícito ("Motivo, opcional"); erro inline `liveRegion: true`.
- Snackbar de sucesso anunciado uma vez (`liveRegion`).
- Motivo na timeline entra no nó `Semantics` do evento ("Turno cancelado, cancelado pelo
  profissional, motivo: …, quinta, quatro de junho, nove e dezoito").

---

## B. Backoffice — fila de falhas generalizada (CA-4)

### B.1. O que muda em relação à SCREEN-065

A fila é a mesma (**rota `/pix-falhas`, shell, tabela, dialog de resolução, contador,
estados e testids preservados**) — só o **conteúdo** generaliza: casos de **liberação de
pré-autorização com falha** entram ao lado dos casos de Pix. Custo mínimo, alerta no
mesmo lugar onde a operação já olha (CA-4: "mesma fila da STORY-065").

| Item | SCREEN-065 (só Pix) | Agora (generalizada) |
|---|---|---|
| Sidebar | Pix com falha | **Falhas de pagamento** |
| Título | Pix com falha | **Falhas de pagamento** |
| Subtítulo | {n} transferência(s) aguardando tratamento manual | **{n} caso(s) aguardando tratamento manual** |
| Badge por linha | Pix falhou — tratamento manual | Pix falhou — tratamento manual **ou** **Liberação falhou — tratamento manual** |
| Coluna "Chave Pix" | chave + copiar | Pix: inalterado · Liberação: **—** (não se aplica; o admin trata no gateway) |
| Coluna "Valor" | valor do Pix (R$ do profissional) | Pix: inalterado · Liberação: **total reservado** (R$ do contratante) |
| Vazio (pendentes) | Nenhum Pix com falha / "Falhas de transferência…" | **Nenhuma falha de pagamento** / "Falhas de transferência e de liberação aparecem aqui assim que o gateway reportar. Por enquanto, tudo certo." |

> **Nota ao PO (validação):** o rename "Pix com falha" → "Falhas de pagamento" mexe em
> microcopy shipped da 065 (sidebar/título/vazio). Rota e identificadores de teste ficam;
> Playwright não quebra. Alternativa rejeitada: fila separada (CA-4 manda usar a mesma;
> duas filas = dois lugares para a operação vigiar).

### B.2. Linha de caso "Liberação falhou" (anatomia)

```
| ■ Liberação falhou — tratamento manual                                  |
| Garçom · Restaurante Vela     R$ 276,00   —    release_failed —   Qui  [Resolver]|
|   Pedro Alves                                  pré-autorização    04/06          |
|                                                não encontrada     09:18          |
```

- Badge: chip `error-soft` + dot `error` (mesma anatomia do Pix; só o texto muda).
- Dialog de resolução: **idêntico** ao da 065 (`Marcar como resolvido manualmente?` +
  nota obrigatória) — o resumo do caso mostra `{função} · {estabelecimento} — R$ {total}`
  e a 2ª linha `{profissional} · liberação de pré-autorização`.
- Demais estados (loading, vazio, erro, race, resolvidos, paginação, tema claro/escuro,
  mobile degradado): **SCREEN-065 §B.5, inalterados**.

---

## 5. Microcopy completo

Textos novos desta tela (o resto herda das SCREEN-060/065 sem mudança):

### Superfície A — WebApp

| Lugar | Texto |
|---|---|
| Gatilho (profissional) | Não vai poder comparecer? Cancelar turno |
| Gatilho (contratante) | Não precisa mais deste turno? Cancelar turno |
| Dialog — título | Cancelar este turno? |
| Dialog — corpo (profissional) | A reserva do pagamento será liberada e o contratante será avisado. Essa ação não pode ser desfeita. |
| Dialog — corpo (contratante) | A reserva do pagamento será liberada e o profissional será avisado. Essa ação não pode ser desfeita. |
| Dialog — label do motivo | Motivo (opcional) |
| Dialog — placeholder (profissional) | Ex.: tive um imprevisto e não poderei comparecer |
| Dialog — placeholder (contratante) | Ex.: o evento foi cancelado |
| Dialog — voltar | Voltar |
| Dialog — confirmar (destrutiva) | Cancelar turno |
| Dialog — erro de rede | Não foi possível cancelar. Tente de novo. |
| Dialog — erro 422 (corrida) | Este turno não pode mais ser cancelado. |
| Snackbar — sucesso | Turno cancelado. |
| Timeline — eventos novos | tabela §A.5 |

### Superfície B — Backoffice (deltas sobre a 065)

| Lugar | Texto |
|---|---|
| Sidebar — item | Falhas de pagamento |
| Título da tela | Falhas de pagamento |
| Subtítulo (pendentes > 0) | {n} caso(s) aguardando tratamento manual |
| Subtítulo (zerada) | Nenhum caso aguardando tratamento |
| Badge — liberação | Liberação falhou — tratamento manual |
| Chave Pix (caso de liberação) | — |
| Resumo no dialog (linha 2, liberação) | {profissional} · liberação de pré-autorização |
| Vazio pendentes — título | Nenhuma falha de pagamento |
| Vazio pendentes — instrução | Falhas de transferência e de liberação aparecem aqui assim que o gateway reportar. Por enquanto, tudo certo. |

Horários 24h pt-BR (DDR-002). Valores `R$ 1.234,56`. Vocabulário do glossário.

---

## 7. Identificadores estáveis sugeridos para teste

### Superfície A — `Key()` Flutter (widget/integration tests)

| Elemento | Identificador lógico |
|---|---|
| Gatilho de cancelar | `turno-detalhe-cancelar-btn` |
| Dialog | `cancelar-dialog` |
| Textarea do motivo | `cancelar-dialog-motivo` |
| Confirmar (destrutiva) | `cancelar-dialog-confirmar` |
| Voltar | `cancelar-dialog-voltar` |
| Erro inline | `cancelar-dialog-erro` |
| Snackbar de sucesso | `turno-cancelado-snackbar` |

(O E2E do CA-8 ancora em `turno-detalhe-cancelar-btn` → `cancelar-dialog-confirmar` →
`turno-detalhe-estado` nos 2 papéis; badges/timeline reusam os ids da SCREEN-060 §7.)

### Superfície B — `data-testid` (Playwright/Pest)

Todos os da SCREEN-065 §7 **preservados** (`pixfalhas-*`). O tipo do caso é legível no
texto do badge existente (`pixfalhas-item-{turnoId}-badge`).

---

## 8. Exceções ao Design System

| O que diverge | Por quê | Vira DDR? |
|---|---|---|
| `button.text` em ink `error` (variante destrutiva de baixa ênfase) | O DS tem `button.text` em accent (ação leve) e destrutiva sólida só dentro de `dialog.confirm`. O gatilho de cancelar precisa ser acionável mas nunca competir com a ação primária — texto leve em `error` ink é o meio-termo. Flutter: `TextButton` com `foregroundColor: error`. Reaparece na disputa (EPIC-005). | **Candidato** — promover como variante de `button.text` no 2º uso. |
| Backoffice desktop-first | PDR-003 — exceção já registrada na SCREEN-019 §8. | Não. |

Nenhum componente novo de verdade: `dialog.confirm` é o 3º uso (definitivo), badges e
timeline já registrados, fila reusa SCREEN-065 por inteiro.

---

## 9. Protótipo HTML fiel (validação humana)

- **Localização:** `SCREEN-STORY-066-cancelamento/index.html`.
- **Cobertura:** seletor de **superfície** (WebApp / Backoffice).
  - WebApp: papéis profissional/contratante × viewports mobile/desktop × estados
    `confirmado` (gatilho visível; profissional convive com card de PIN da 061),
    `cancelado-pro`, `cancelado-emp`, `no-show`. Dialog **funcional**: motivo opcional,
    confirmação simula a chamada (~1s de loading) e cai no estado terminal com snackbar;
    chips "simular erro de rede" e "simular 422" armam o próximo confirmar.
  - Backoffice: fila generalizada com 1 caso Pix + 1 caso Liberação (pendentes),
    resolvidos, vazio; dialog de resolução funcional (herdado da 065); tema claro/escuro.
- **Fidelidade:** tokens reais (DDR-001); microcopy = §5 palavra por palavra;
  identificadores §7 como `data-testid`; 24h pt-BR (DDR-002).
- **Restrições:** HTML/CSS/JS vanilla, sem rede, mock inline, comentário "protótipo de
  validação".

### Checklist antes de marcar spec `ready`

- [x] Protótipo abre sem erro; todos os estados acessíveis nas duas superfícies
      (verificado em Chrome headless: confirmado/cancelado-pro/cancelado-emp/no-show/bo).
- [x] Fluxo de cancelamento ponta a ponta (gatilho → dialog → motivo → loading → terminal + snackbar).
- [x] Microcopy bate palavra por palavra com a §5.
- [x] Identificadores da §7 presentes.
- [x] Tokens reais dos perfis (verde-sage / mostarda / admin navy).
- [x] Protótipo apresentado ao humano e sinal de validação capturado (2026-06-06, em chat
      — as 2 notas ao PO aprovadas: motivo visível ao outro lado §A.5; rename da fila §B.1).

---

## 10. Dependências e premissas

- **Endpoint (contrato — estória CA-2):** `POST /api/turnos/{id}/cancelar` com
  `{ motivo?: string }`; 422 quando estado ≠ `confirmado`; RBAC decide `cancelado_pro` vs
  `cancelado_emp`. Resposta de sucesso pode devolver o turno atualizado (poupa um GET) —
  formato fino é do Programador.
- **Payload do detalhe:** eventos `cancelado` (com `lado` e `motivo?`) e
  `pagamento_liberado` (com valor para o contratante) entram na timeline já filtrada por
  papel no servidor (mesma defesa em profundidade da 060 §10).
- **Cron de no-show é invisível ao usuário** — nenhuma superfície própria; seus efeitos
  aparecem como estado terminal + timeline. X = 2h (decisão do PO 2026-06-06).
- **Fila do admin:** casos de liberação entram na mesma tabela operacional da 065
  (estrutura é do Programador); razão/código vêm do payload do gateway.
- **Notificações ao outro lado são STORY-067** (evento `TurnoCancelado` é só emitido aqui).
- Spec **não depende** de DDR pendente.

---

## 11. Histórico de mudanças

| Data | Mudança | Quem | Motivo |
|---|---|---|---|
| 2026-06-06 | criação (spec completo + protótipo v1) | claude-opus-4-8 (designer) | STORY-066; inclui generalização consciente da fila da 065 (§B.1) e copy mais específica do `no_show_pro` na timeline (060 §4.1 dizia "até o limite"; agora "em até 2 horas após o início previsto" — X decidido pelo PO em chat) |
| 2026-06-06 | validação humana — aprovado sem ajustes | Alexandro | confirmou motivo visível aos 2 lados (§A.5) e rename "Pix com falha" → "Falhas de pagamento" (§B.1); X do no-show = 2h; `status: ready` |
| 2026-06-06 | implementação + 1 ajuste consciente | claude-opus-4-8 (programador) | timeline do `cancelado` fala na VOZ de quem lê ("Você cancelou este turno." para o lado que cancelou) — refinamento sobre a tabela §A.5 (que só previa "Cancelado pelo {lado}"), coerente com tone-and-voice; copy do no-show usa `limite_horas` do payload (X dinâmico, não hardcoded); `status: in_implementation` |
| 2026-06-06 | implementado + PO aprovou em homolog | claude-opus-4-8 / Alexandro | STORY-066 entregue (api 959 / admin 118+Playwright 14 / webapp 533; E2E cancelamento 2 lados + no-show com cron real; rc.79) e aprovada em chat após teste manual; `status: shipped` |
