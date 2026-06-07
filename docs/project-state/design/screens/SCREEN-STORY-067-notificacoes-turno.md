---
id: SCREEN-STORY-067-notificacoes-turno
story: STORY-067-notificacoes-eventos-turno
epic: EPIC-003-aceite-pin-e-pix
status: shipped              # draft | ready | in_implementation | shipped | superseded
created_at: 2026-06-06
updated_at: 2026-06-06
owner_designer: claude-opus-4-8
related_ddrs: [DDR-001, DDR-002]
ds_components_used: [notification.bell, notification.panel, notification.tile, empty.state, error.state, skeleton]
exceptions_to_ds: []          # nenhuma — 2º uso confirma os candidatos da SCREEN-053 §8 (bell/panel/tile)
viewports: [mobile, desktop]
prototype_path: SCREEN-STORY-067-notificacoes-turno/index.html
prototype_last_validated_at: 2026-06-06   # texto-seed v1 + protótipo aprovados por Alexandro em chat (gate CA-5)
extends: SCREEN-STORY-053-notificacoes
---

# Spec de tela — SCREEN-STORY-067 — Notificações dos eventos do turno (8 tipos novos no centro da 053)

> Referência: estória `STORY-067`. CAs e contexto vêm de lá — **não duplico**.
> A estória nasceu `requires_design: false`; Alexandro pediu o fluxo designer→programador
> (2026-06-06, mesmo precedente da STORY-065). O spec é **um adendo leve de propósito**:
> **nenhuma superfície nova** — sino, painel, tile, estados e identificadores são os da
> `SCREEN-STORY-053` (shipped), que já previa este reuso ("EPIC-003: aceite/turno também
> notificam", §8). O que este spec entrega é o que a 053 entregou para os 5 tipos de
> candidatura, agora para os **8 tipos do turno**: microcopy in-app (título + resumo),
> ícone por tipo, destino de navegação e o **texto-seed v1 dos 8 e-mails** (gate CA-5 —
> validação do PO em chat). Princípios: **#1** (um destino por item, sem ramificação),
> **#3** (dinheiro e cancelamento comunicados com sobriedade), **#4** (reuso total —
> zero componente novo; o 2º uso **promove** `notification.bell/panel/tile` de candidatos
> a padrão consolidado do DS), **#5/#7** herdados da 053 sem mudança.

---

## 1. O que muda (e o que não muda)

| Superfície | Mudança |
|---|---|
| Sino + badge (AppBar das homes) | **Nenhuma.** Contagem passa a incluir os tipos novos naturalmente (mesma query). |
| Painel lateral (endDrawer) | **Nenhuma** estrutura nova. Lista cronológica única — eventos de turno e de candidatura se misturam por `criada_em DESC` (decisão consciente: sem abas/filtros, Princípio #1). |
| `notification.tile` | **8 tipos novos** de conteúdo (ícone + título + resumo + destino) — §2. Anatomia, estados lido/não-lido, acessibilidade e identificadores idênticos à 053 (§3/§6/§7 de lá). |
| Estado vazio do painel | **1 linha de microcopy ajustada** — §4. |
| E-mail | 8 templates novos (texto-seed v1 — §5), mesmo layout/renderer da 053/021. |

O sino aparece hoje nas duas homes (feed do profissional, minhas vagas do contratante).
As telas de turno (`/profissional/turnos`, `/contratante/turnos`, `/turnos/{id}`) **não
ganham sino nesta estória** — o caminho de chegada continua sendo home → sino → painel →
destino. (Estender o sino a outros AppBars é follow-up de DS, não desta estória.)

---

## 2. Os 8 tipos — ícone, microcopy in-app e destino

Convenção herdada da 053 (§5 de lá): **título = `h1` do e-mail; resumo = 1ª linha do 1º
parágrafo do e-mail** — uma fonte de verdade, dois canais. Variáveis `{...}` vêm do
`payload jsonb` da notificação, **pré-renderizadas no servidor** (datas via `DataHora`
pt-BR 24h — DDR-002/IDR-026; valores monetários já formatados `1.234,56`).

**Destino único:** todos os 8 tipos navegam para o **detalhe do turno** `/turnos/{turno_id}`
(rota interna; `turno_id` vem do payload). O detalhe (SCREEN-060) já mostra estado, timeline,
PIN, cronômetro, valor e Pix — é sempre o lugar certo. Um item, um toque, um destino (#1).

| Tipo | Destinatário | Ícone (Material) | Título | Resumo (1ª linha do e-mail) |
|---|---|---|---|---|
| `turno_confirmado` | profissional | `event_available` | Turno confirmado | Seu turno de {vaga_funcao} no {estabelecimento_nome} em {turno_data_inicio} está confirmado. |
| `checkin_solicitado` | contratante | `login` | Check-in aguardando validação | {profissional_nome} gerou o PIN de check-in do turno de {vaga_funcao}. Valide para iniciar. |
| `turno_ativo` | profissional | `play_circle_outline` | Turno em andamento | Check-in validado. Seu turno de {vaga_funcao} está em andamento. |
| `checkout_solicitado` | contratante | `logout` | Check-out aguardando validação | {profissional_nome} gerou o PIN de check-out do turno de {vaga_funcao}. Valide para encerrar. |
| `turno_finalizado` | profissional | `task_alt` | Turno finalizado | Turno de {vaga_funcao} encerrado. O pagamento de R$ {valor} está em processamento. |
| `pix_enviado` | profissional | `pix` | Pix enviado | O Pix de R$ {valor} do turno de {vaga_funcao} foi enviado. |
| `turno_cancelado` | o outro lado | `event_busy` | Turno cancelado | O turno de {vaga_funcao} de {turno_data_inicio} foi cancelado {cancelado_por}. |
| `no_show_pro` | ambos os lados | `person_off` | Turno encerrado — check-in não realizado | O turno de {vaga_funcao} de {turno_data_inicio} foi encerrado: o check-in não aconteceu no prazo. |

Notas de design:

- **`checkin_solicitado`/`checkout_solicitado` são as duas únicas com verbo de ação no
  resumo** ("Valide para iniciar/encerrar") — são as únicas em que o destinatário tem uma
  tarefa pendente; as demais são informativas. O tom segue sóbrio (sem urgência artificial).
- **`turno_cancelado`**: `{cancelado_por}` é pré-renderizado no servidor como "pelo
  contratante" ou "pelo profissional" — o tile **não** carrega o motivo (quando existir,
  ele está na timeline do detalhe, SCREEN-066). Motivo no e-mail: §5.
- **`no_show_pro`**: mesma copy neutra para os dois lados (um template, duas notificações).
  "Não comparecimento" foi evitado no resumo — "o check-in não aconteceu no prazo" descreve
  o fato sem adjetivar o profissional (o estado `no_show_pro` técnico fica na timeline).
- **`pix_enviado`** fecha o ciclo com discrição (#3): sem 🎉, sem "Parabéns". O valor e o
  fato. (Paridade com a linha "✓ Pix enviado em HH:MM" da SCREEN-065.)
- Ícones: neutros (`text.muted` sobre círculo `surface.sunken`), como na 053 — o ícone
  identifica a natureza, nunca vira semáforo. `pix` é o glifo oficial do Material para Pix.

### Payload mínimo por tipo (contrato para o Programador)

Comum a todos: `turno_id`, `vaga_funcao`, `estabelecimento_nome`, `turno_data_inicio`,
`link_turno` (URL absoluta p/ e-mail; o app navega por rota interna).

| Tipo | Adicionais |
|---|---|
| `turno_confirmado` | `valor` |
| `checkin_solicitado` | `profissional_nome` |
| `turno_ativo` | — |
| `checkout_solicitado` | `profissional_nome` |
| `turno_finalizado` | `valor` |
| `pix_enviado` | `valor` |
| `turno_cancelado` | `cancelado_por`, `motivo_texto` (sempre não-vazio — §5) |
| `no_show_pro` | `no_show_prazo` (ex.: "2 horas") |

---

## 3. Layout

**Sem mudança** em relação à SCREEN-053 §3 (mobile full-width ≤400dp; desktop coluna 400dp
sobre scrim). Exemplo do painel do **profissional** com os tipos novos misturados aos da 053:

```
+------------------------------------------+
| Notificações          Marcar todas lidas |
+------------------------------------------+
| •(₽) Pix enviado                          |   não-lido (ponto + accent.soft)
|      O Pix de R$ 200,00 do turno de      |
|      Garçom foi enviado.                 |
|      há 2 min                            |
+------------------------------------------+
| •(✓) Turno finalizado                     |
|      Turno de Garçom encerrado. O        |
|      pagamento de R$ 200,00 está em      |
|      processamento.                      |
|      há 18 min                           |
+------------------------------------------+
|  (▶) Turno em andamento                   |   lido (surface plano)
|      Check-in validado. Seu turno de     |
|      Garçom está em andamento.           |
|      ontem · 18:04                       |
+------------------------------------------+
|  (✎) Vaga alterada — confirme             |   tipos da 053 convivem na mesma lista
|      ...                                 |
+------------------------------------------+
```

---

## 4. Estados

Todos herdados da SCREEN-053 §4 (badge, lista, loading, vazio, tudo-lido, erro, parcial,
offline) — **sem redesenho**. Uma única mudança de microcopy:

- **Vazio — corpo** (053 §4.4): de "Quando algo acontecer com suas vagas ou candidaturas,
  avisamos aqui." para **"Quando algo acontecer com suas vagas, candidaturas ou turnos,
  avisamos aqui."** (o centro agora cobre o ciclo do turno).

---

## 5. Texto-seed v1 dos 8 e-mails (gate CA-5 — validação do PO em chat)

Formato do corpo editável (renderer da 053): front-matter `preheader/h1/cta_label/cta_url/
aviso`, separador `---`, parágrafos. **Assunto** é canônico em código
(`NotificacaoTipo::assuntoEmail()`), interpolando `{snake_case}` do payload. Saudação
("Olá, {nome}.") e rodapé são fixos do layout — fora do corpo editável.

Regra do renderer que moldou a copy: **placeholder sem valor no payload = e-mail não sai**
— por isso `turno_cancelado` usa `{motivo_texto}` sempre não-vazio (pré-renderizado como
`Motivo informado: "…"` ou `Nenhum motivo foi informado.`), nunca um `{motivo}` opcional.

### 5.1 `turno_confirmado_email` — assunto: `Turno confirmado — {vaga_funcao} em {turno_data_inicio}`

```
preheader: Seu turno de {vaga_funcao} em {turno_data_inicio} está confirmado.
h1: Turno confirmado
cta_label: Ver turno
cta_url: {link_turno}
aviso:
---
Seu turno de {vaga_funcao} no {estabelecimento_nome} em {turno_data_inicio} está confirmado.

Você recebe R$ {valor} pelo turno. No horário de início, gere o PIN de check-in na tela do turno e informe os 4 dígitos ao contratante.
```

### 5.2 `checkin_solicitado_email` — assunto: `Check-in aguardando sua validação — {vaga_funcao}`

```
preheader: {profissional_nome} gerou o PIN de check-in do turno de {vaga_funcao}.
h1: Check-in aguardando validação
cta_label: Validar check-in
cta_url: {link_turno}
aviso:
---
{profissional_nome} gerou o PIN de check-in do turno de {vaga_funcao}. Valide para iniciar.

Peça os 4 dígitos ao profissional e digite na tela do turno. O turno só começa a contar depois da sua validação.
```

### 5.3 `turno_ativo_email` — assunto: `Check-in validado — seu turno está em andamento`

```
preheader: Check-in validado. Seu turno de {vaga_funcao} está em andamento.
h1: Turno em andamento
cta_label: Acompanhar turno
cta_url: {link_turno}
aviso:
---
Check-in validado. Seu turno de {vaga_funcao} está em andamento.

O cronômetro do turno está rodando para você e para o contratante. Ao terminar, gere o PIN de check-out na mesma tela.
```

### 5.4 `checkout_solicitado_email` — assunto: `Check-out aguardando sua validação — {vaga_funcao}`

```
preheader: {profissional_nome} gerou o PIN de check-out do turno de {vaga_funcao}.
h1: Check-out aguardando validação
cta_label: Validar check-out
cta_url: {link_turno}
aviso:
---
{profissional_nome} gerou o PIN de check-out do turno de {vaga_funcao}. Valide para encerrar.

Peça os 4 dígitos ao profissional e digite na tela do turno. A validação encerra o turno e libera o pagamento.
```

### 5.5 `turno_finalizado_email` — assunto: `Turno finalizado — pagamento em processamento`

```
preheader: Turno de {vaga_funcao} encerrado. Pagamento em processamento.
h1: Turno finalizado
cta_label: Ver turno
cta_url: {link_turno}
aviso:
---
Turno de {vaga_funcao} encerrado. O pagamento de R$ {valor} está em processamento.

Você recebe por Pix — normalmente em até 15 minutos. Avisamos por aqui quando o Pix for enviado.
```

### 5.6 `pix_enviado_email` — assunto: `Pix enviado — R$ {valor} do turno de {vaga_funcao}`

```
preheader: O Pix de R$ {valor} do turno de {vaga_funcao} foi enviado.
h1: Pix enviado
cta_label: Ver turno
cta_url: {link_turno}
aviso:
---
O Pix de R$ {valor} do turno de {vaga_funcao} foi enviado.

O valor cai na conta vinculada à sua chave Pix. Se não aparecer em algumas horas, fale com a gente: contato@turni.com.br.
```

### 5.7 `turno_cancelado_email` — assunto: `Turno de {vaga_funcao} cancelado`

```
preheader: O turno de {vaga_funcao} de {turno_data_inicio} foi cancelado {cancelado_por}.
h1: Turno cancelado
cta_label: Ver turno
cta_url: {link_turno}
aviso:
---
O turno de {vaga_funcao} de {turno_data_inicio} foi cancelado {cancelado_por}.

{motivo_texto}
Nenhum valor foi cobrado: a reserva no meio de pagamento foi liberada.
```

### 5.8 `no_show_pro_email` — assunto: `Turno encerrado — check-in não realizado`

```
preheader: O turno de {vaga_funcao} de {turno_data_inicio} foi encerrado: o check-in não aconteceu no prazo.
h1: Turno encerrado — check-in não realizado
cta_label: Ver turno
cta_url: {link_turno}
aviso:
---
O turno de {vaga_funcao} de {turno_data_inicio} foi encerrado: o check-in não aconteceu no prazo.

O encerramento foi automático ({no_show_prazo} após o horário de início, sem check-in validado). Nenhum valor foi cobrado: a reserva no meio de pagamento foi liberada.
```

> Vocabulário: `glossary.md` ("Turno", "Profissional", "Contratante", "check-in/check-out",
> "PIN"). Datas pt-BR 24h (DDR-002). Tom: direto, sem emoji, sem urgência artificial (#3).
> A promessa "Pix em até 15 minutos" (5.5) é a promessa pública do produto — em homolog o
> banner global da STORY-075 já contextualiza que o pagamento é simulado.

---

## 6. Acessibilidade

Herdada integralmente da SCREEN-053 §6 — o tile anuncia `'{título}. {resumo}. {tempo}.
[Não lida.]'`; ícone decorativo (`ExcludeSemantics`); alvos ≥56dp. Nada novo a auditar
além do contraste, que não muda (mesmos tokens).

---

## 7. Identificadores estáveis

Os da SCREEN-053 §7, sem adição — `notificacao-item-{id}`, `notificacoes-sino-btn`,
`notificacoes-badge`, etc. O E2E da CA-7 ancora nos mesmos `Key('...')`.

---

## 8. Exceções ao Design System

Nenhuma. Ao contrário: este é o **2º uso** de `notification.bell` / `notification.panel` /
`notification.tile` — condição que a 053 §8 definiu para **promovê-los de candidatos a
componentes consolidados do DS**. Follow-up de DS (fora desta estória): registrar a
promoção em `design/system/components.md`.

---

## 9. Protótipo HTML fiel (validação humana)

- **Localização:** `SCREEN-STORY-067-notificacoes-turno/index.html`.
- **Cobertura:** seletor de **papel** (profissional × contratante — listas específicas com
  os tipos que cada lado recebe) e de **viewport** (mobile/desktop). Os tipos novos
  convivem com itens da 053 na mesma lista cronológica (fidelidade ao comportamento real).
  Estados loading/vazio/erro/tudo-lido **não são re-prototipados** (inalterados desde a
  053, validados em 2026-06-03) — exceto o **vazio**, incluído por ter microcopy nova (§4).
- **Fidelidade:** tokens reais do DS, microcopy §2/§4 palavra por palavra, datas pt-BR 24h,
  `data-testid` da §7 da 053.

### Checklist antes de marcar spec `ready`

- [ ] §2 cobre os 8 tipos (ícone + título + resumo + destino + payload mínimo).
- [ ] §5 com os 8 texto-seeds completos (assunto + front-matter + corpo).
- [ ] Protótipo com os 8 tiles nos 2 papéis + vazio novo.
- [ ] Protótipo apresentado ao humano; **texto-seed validado pelo PO em chat (gate CA-5)**.

---

## 10. Dependências e premissas

- **Contrato:** mesmos endpoints da 053 (`GET /api/notificacoes`, `POST .../marcar-lida`,
  `POST .../marcar-todas-lidas`). Cada item dos tipos novos carrega `turno_id` no `payload`
  (a tabela não ganha coluna nova — premissa da estória, ADR-018).
- **Destino interno:** `/turnos/{turno_id}` para os 8 tipos (rota existente, SCREEN-060).
  E-mail usa `{link_turno}` absoluto (`LinksWebApp`).
- **Sem polling/push** — inalterado (053 §10).
- **Idempotência** (`{tipo}:{turno_id}` e variante PIN) é contrato do Programador (CA-3) —
  invisível ao design, citada só porque re-geração de PIN **re-notifica** o contratante
  (decisão de produto da estória; o tile novo aparece como item novo, sem deduplicar na UI).

---

## 11. Histórico de mudanças

| Data | Mudança | Quem | Motivo |
|---|---|---|---|
| 2026-06-06 | criação (adendo à SCREEN-053: 8 tipos de tile, destino único `/turnos/{id}`, microcopy vazio ajustada, texto-seed v1 dos 8 e-mails) | claude-opus-4-8 (designer) | STORY-067 destravada (8 eventos emitidos pelas 058..066); Alexandro pediu fluxo designer→programador |
| 2026-06-06 | validação humana — texto-seed v1 + protótipo aprovados em chat (gate CA-5); `status: ready` | Alexandro (PO) | "Aprovado — implementar", sem ajustes |
