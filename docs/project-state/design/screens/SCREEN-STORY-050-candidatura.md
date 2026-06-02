---
id: SCREEN-STORY-050-candidatura
story: STORY-050-candidatura-um-toque-com-gates
epic: EPIC-002-vaga-feed-e-candidatura
status: shipped              # draft | ready | in_implementation | shipped | superseded
created_at: 2026-06-02
updated_at: 2026-06-02
owner_designer: claude-opus-4-8
related_ddrs: [DDR-001, DDR-002]
ds_components_used: [surface.card, button.primary, button.text, badge.status, gate.banner, sheet.confirm, link.text]
exceptions_to_ds: [sheet.confirm (bottom-sheet/dialog de confirmação de ação — §8; primeiro uso de confirmação modal no app), block.modal (modal de bloqueio por gate — reusa sheet.confirm sem ação de confirmar; lista o conflito quando houver — §8)]
viewports: [mobile, desktop]
prototype_path: SCREEN-STORY-050-candidatura/index.html
prototype_last_validated_at: 2026-06-02   # validado no app real local + aprovado por Alexandro em chat
---

# Spec de tela — SCREEN-STORY-050 — Candidatura em 1 toque + gates

> Referência: estória `STORY-050`. CAs e contexto vêm de lá — **não duplico**.
> Tela mãe: `SCREEN-STORY-049` (detalhe da vaga). Esta spec **não cria tela nova**: ela
> especifica a **ação** "Candidatar-se" (o que estava como placeholder em 049) — o modal de
> confirmação, o feedback de sucesso, os modais de bloqueio dos 3 gates, e a retirada
> voluntária. Todo o resto da tela de detalhe (cabeçalho, breakdown, total, estados de
> loading/erro/sem-permissão/indisponível) é de `SCREEN-STORY-049` e **permanece igual**.
> Fundação visual: `DDR-001` + `docs/project-state/design/system/`. Locale/horário: `DDR-002`
> (pt-BR, 24h). Gates e mensagens: `STORY-050` CA-1..CA-5 + `domain/candidatura.md`
> (Pré-condições, Conflito de horário) + `business-rules.md` (Habitualidade PDR-002) + PDR-005.
> Tela irmã futura: `STORY-053` notifica o contratante quando a candidatura é criada.
> Princípios que guiaram: **#1** simplicidade (1 toque + 1 confirmação, sem formulário),
> **#3** tom profissional (o bloqueio explica e oferece saída, não pune), **#5** WCAG AA
> (foco preso no modal, anúncio do desfecho, alvo ≥48dp), **#7** todos os estados (confirmar,
> enviando, sucesso, cada um dos 3 gates + vaga fechada + já candidatou, retirar).

Esta spec materializa **o ato central da experiência do profissional**: depois de entender o
match (049), ele toca **Candidatar-se**, confirma, e — se nenhum dos 3 gates dispara — está
candidatado. Quando um gate dispara, o profissional recebe um **bloqueio claro, em prosa, com
uma saída** (avaliar o turno, ver o conflito, entender a habitualidade) — nunca um código de
erro nem JSON cru (CA-9). A confirmação evita candidatura acidental (o "1 toque" é deliberado,
não impulsivo); o sucesso é otimista e instantâneo (o badge troca in-place).

---

## Tema e perfil

- Usuário **autenticado** como **profissional** → tema do papel (DDR-001): acento
  **verde-sage** (`#2D5F3F` claro / `#5FA37C` escuro). Mesmo tema de 048/049 — continuidade.
- **Modal de confirmação (`sheet.confirm`):** superfície `surface` elevada, título forte,
  resumo da vaga em `text.muted`, dois botões — **Confirmar candidatura** (primário, acento do
  perfil) e **Cancelar** (texto, sem peso). Mobile: **bottom-sheet** (sobe do rodapé, alvo do
  polegar — princípio #2). Desktop: **dialog** centrado, largura ~440px.
- **Modais de bloqueio (`block.modal`):** mesma superfície do `sheet.confirm`, mas com cabeçalho
  **`warning`** (ícone ⚠ + título do gate) e **uma única ação** ("Entendi" / a saída do gate).
  Nunca vermelho: um gate **não é erro do usuário** — é uma regra do marketplace (espelha a
  decisão "miss = cinza-mudo, não vermelho" de 049 §Tema). Vermelho fica reservado a erro real
  (rede/5xx — §4.8). O `conflito_horario` mostra o **card do conflito** com link clicável.
- **Estado "enviando":** o botão **Confirmar candidatura** mostra spinner inline e desabilita
  (evita duplo-envio — também coberto pela idempotência do back, CA-6). O resto do modal fica
  inerte.
- **Sucesso:** o modal fecha, um **toast/SnackBar** confirma ("Candidatura enviada!") e o CTA
  do rodapé vira o **badge "Você já se candidatou"** (success soft) in-place — sem recarregar a
  tela (otimismo visual; o estado já existe em 049 §4.3).
- **Retirar candidatura:** link discreto (de 049) → `sheet.confirm` de retirada (título
  "Retirar candidatura?", ação destrutiva discreta) → sucesso volta o CTA a "Candidatar-se".
- **Tema dual** (PDR-013) auditado AA. Marca `TURNI.` no topo do desktop (herdada de 049).

---

## 1. Objetivo da tela

Transformar a intenção ("quero esta vaga") em candidatura **com 1 confirmação** e devolver, em
todos os caminhos, um desfecho legível: **enviada** (badge + toast), **bloqueada por um gate**
(modal em prosa com a saída), **vaga fechou no caminho** ou **já candidatou** (idempotência).
E permitir **desfazer** enquanto pendente. Sem formulário, sem mensagem livre, sem código de
erro vazando (CA-9). Um toque; uma confirmação; um desfecho claro.

---

## 2. Fluxo

### Entrada

- **Ponto de entrada único:** botão **Candidatar-se** no rodapé do detalhe (`/vaga/{id}`,
  SCREEN-049). Habilitado quando `pode_candidatar == true && ja_candidatou == false`.
- O gate **PDR-005 já resolvido no GET** (049): se `pode_candidatar == false`, o botão já está
  desabilitado com `gate.banner` + tooltip — **o profissional nem chega a tocar**. Os modais de
  bloqueio desta spec cobrem os gates que **só o POST sabe** (conflito de horário, habitualidade,
  vaga fechou entre o GET e o toque, corrida de já-candidatou) — CA-2..CA-6.
- **Pré-condições:** sessão ativa, papel `profissional` (RBAC já garantido por 049).

### Ações possíveis

1. **Candidatar-se** → abre o `sheet.confirm` (não dispara o POST ainda — princípio #1, evita
   candidatura acidental).
2. **Confirmar candidatura** (dentro do modal) → `POST /api/vagas/{id}/candidaturas`.
   - **201** → fecha o modal, toast de sucesso, CTA vira badge "Você já se candidatou".
   - **422** (gate) → o modal de confirmação **vira** o modal de bloqueio correspondente ao
     `erro` (mesma superfície, troca de conteúdo) — CA-9.
   - **409** (`ja_candidatou`) → fecha o modal, badge "Você já se candidatou" (já está
     candidatado — corrida; trata como sucesso silencioso). CA-6.
   - **rede/5xx** → mantém o modal, mostra erro inline com **Tentar de novo** (§4.8).
3. **Cancelar** (no `sheet.confirm`) → fecha sem efeito.
4. **Entendi / saída do gate** (no `block.modal`) → fecha; em `conflito_horario` há o **link**
   para a vaga conflitante (navega para `/vaga/{conflito.vaga_id}`); em `gate_avaliacao` o
   modal **não** navega no MVP (não há tela de avaliação ainda — EPIC-003), só explica e fecha.
5. **Retirar candidatura** (link, quando `ja_candidatou && pendente`) → `sheet.confirm` de
   retirada → `DELETE /api/candidaturas/{id}`. **200** → CTA volta a "Candidatar-se"; **409**
   → toast "Esta candidatura não pode mais ser retirada." (mudou de estado).

### Saída

- **Candidatou:** permanece na tela de detalhe com o badge; pode **Voltar** ao feed.
- **Bloqueado:** permanece na tela; o breakdown e o cabeçalho seguem visíveis.
- **Conflito → link:** navega para a vaga conflitante (`/vaga/{id}`), recursivamente uma tela
  de detalhe normal.

```
[ detalhe /vaga/{id} ] ──tap "Candidatar-se"──► [ sheet.confirm ]
        ▲                                              │
        │                              ┌───── Cancelar ┘
        │                              │
        │                       Confirmar candidatura → POST
        │                              │
        │      ┌──────────────┬────────┼─────────────┬──────────────┐
        │     201            422 gate  409 já-cand.   rede/5xx
        │      │              │        │              │
        │  badge +        block.modal  badge        erro inline
        │  toast          (por gate)   silencioso   + Tentar de novo
        │      │              │
        └──────┘   conflito → link → /vaga/{conflito.vaga_id}
```

---

## 3. Layout

A tela de fundo é **SCREEN-049 sem alteração**. Esta spec descreve as **camadas modais** que
sobem sobre ela.

### Modal de confirmação — mobile (bottom-sheet)

```
+------------------------------------------+
|  (detalhe da vaga ao fundo, esmaecido)   |
|                                          |
| ╭──────────────────────────────────────╮ |
| │  ▬▬▬  (grip)                          │ |  sheet.confirm (sobe do rodapé)
| │  Confirmar candidatura                │ |  título forte
| │  Garçom · Bar do Zé                    │ |  resumo (função · estabelecimento)
| │  Sex, 12/06 · 18:00–23:00 · R$ 150,00  │ |  data/hora 24h + valor (DDR-002)
| │                                        │ |
| │  [      Confirmar candidatura       ]  │ |  button.primary (acento)
| │  [           Cancelar              ]   │ |  button.text
| ╰──────────────────────────────────────╯ |
+------------------------------------------+
```

### Modal de confirmação — desktop (dialog centrado)

Mesma estrutura, `dialog` ~440px centrado com overlay escuro; sem grip. Botões lado a lado
(Confirmar à direita, Cancelar à esquerda) ou empilhados — empilhados para manter alvo largo.

### Modal de bloqueio — conflito de horário (com card do conflito)

```
+------------------------------------------+
| ╭──────────────────────────────────────╮ |
| │  ⚠  Conflito de horário               │ |  cabeçalho warning
| │  Você já tem um compromisso neste      │ |  prosa (mensagem do back)
| │  horário.                              │ |
| │  ┌──────────────────────────────────┐  │ |
| │  │ Garçom · Hotel Aurora            │  │ |  card do conflito (clicável)
| │  │ Sex, 12/06 · 17:00–22:00         │  │ |  → /vaga/{conflito.vaga_id}
| │  │ Ver vaga em conflito         ›   │  │ |
| │  └──────────────────────────────────┘  │ |
| │  [             Entendi             ]   │ |  button.text (fecha)
| ╰──────────────────────────────────────╯ |
+------------------------------------------+
```

### Modal de bloqueio — avaliação / habitualidade / vaga fechada (sem card)

```
+------------------------------------------+
| ╭──────────────────────────────────────╮ |
| │  ⚠  {título do gate}                  │ |
| │  {mensagem do back, em prosa}          │ |
| │  [             Entendi             ]   │ |
| ╰──────────────────────────────────────╯ |
+------------------------------------------+
```

- Componentes do DS: `sheet.confirm` (confirmação + retirada), `block.modal` (bloqueio),
  `button.primary`, `button.text`, `badge.status` (sucesso — reuso de 049), `gate.banner`
  (reuso — mas aqui dentro do `block.modal`). Alvos ≥48dp em todos os botões e no card do
  conflito. Overlay: `scrim` 50% (claro) / 60% (escuro).

---

## 4. Estados

> Toda spec entrega **todos** os estados aplicáveis (Princípio #7).

### 4.1. Confirmar (modal aberto, ocioso)

`sheet.confirm` com resumo da vaga + **Confirmar candidatura** habilitado + **Cancelar**. Foco
inicial no título; ordem de foco: título → Confirmar → Cancelar. `Esc`/tap no scrim = Cancelar.

### 4.2. Enviando (POST em voo)

**Confirmar candidatura** mostra spinner inline e fica desabilitado; **Cancelar** desabilita;
scrim não fecha. Evita duplo-envio (reforço de UX; a idempotência server-side é a garantia
dura — CA-6). Sem timeout artificial; o desfecho vem do back.

### 4.3. Sucesso (201)

Modal fecha. **Toast**: "Candidatura enviada!". O CTA do rodapé vira **badge "Você já se
candidatou"** com a data/hora (049 §4.3) — in-place, sem reload. `Semantics(liveRegion)` anuncia
o sucesso.

### 4.4. Bloqueio — gate de avaliação (`gate_avaliacao`, CA-2)

> Caminho raro nesta tela: o GET (049) **já** desabilita o botão quando o gate de avaliação
> está ativo. Só chega aqui se o estado mudou entre o GET e o POST. Mesmo assim o modal existe.

`block.modal` warning, título **"Avalie seu último turno"**, mensagem do back
("Avalie seu último turno para se candidatar."), ação **Entendi**. No MVP **não** navega para a
tela de avaliação (não existe ainda — EPIC-003); `detalhe.turno_id` vem no payload como slot
para o futuro deep-link.

### 4.5. Bloqueio — conflito de horário (`conflito_horario`, CA-3)

`block.modal` warning, título **"Conflito de horário"**, mensagem do back + **card do conflito**
clicável (função · estabelecimento · data/hora 24h) que navega para `/vaga/{conflito.vaga_id}`.
`detalhe.conflito_com` traz `{ tipo, id, vaga_id, data_inicio, data_fim }` (+ função/estab. para
o card). Ação secundária **Entendi** fecha sem navegar.

### 4.6. Bloqueio — habitualidade (`habitualidade_bloqueio`, CA-4)

`block.modal` warning, título **"Limite semanal neste local"**, mensagem do back
("Você já tem 2 turnos nesta semana neste estabelecimento."), ação **Entendi**. **Só PF** chega
aqui (bloqueio duro). MEI/PJ **não é bloqueado** — a candidatura é criada normalmente (201) e o
alerta vai no payload para o painel do contratante (STORY-051), **sem modal** para o
profissional.

### 4.7. Bloqueio — vaga fechada / já candidatou (`vaga_fechada` / `ja_candidatou`, CA-5/CA-6)

- **`vaga_fechada`** (422): a vaga fechou/cancelou/passou entre o GET e o toque. `block.modal`
  título **"Vaga indisponível"**, mensagem do back, ação **Voltar ao feed** (navega `/feed`).
- **`ja_candidatou`** (409): corrida (candidatou em outra aba/dispositivo). **Sem modal** —
  fecha e mostra o badge "Você já se candidatou" (trata como sucesso). Idempotência (CA-6).

### 4.8. Erro de rede / 5xx no POST

Mantém o modal de confirmação aberto; mostra **erro inline** discreto abaixo dos botões
("Não foi possível enviar. Verifique sua conexão.") + **Tentar de novo** (re-dispara o POST).
Este é o **único** uso de cor de erro (vermelho) nesta spec — falha técnica real, não gate.

### 4.9. Retirar candidatura (CA-8)

Link "Retirar candidatura" (049, só quando `pendente`) → `sheet.confirm` de retirada:
título **"Retirar candidatura?"**, corpo "Você pode se candidatar de novo enquanto a vaga
estiver aberta.", ação **Retirar** (texto, tom discreto) + **Cancelar**. **200** → toast
"Candidatura retirada." + CTA volta a "Candidatar-se". **409** → toast "Esta candidatura não
pode mais ser retirada." (mudou de estado — ex.: foi aprovada).

---

## 5. Microcopy completo

| Lugar | Texto |
|---|---|
| Confirmar — título | Confirmar candidatura |
| Confirmar — resumo (função · estab.) | {função} · {estabelecimento} |
| Confirmar — data/hora · valor | {Dia, dd/mm · HH:mm–HH:mm} · R$ {valor} |
| Confirmar — ação primária | Confirmar candidatura |
| Confirmar — ação secundária | Cancelar |
| Enviando — botão (a11y) | Enviando candidatura |
| Sucesso — toast | Candidatura enviada! |
| Já candidatou — badge (reuso 049) | Você já se candidatou |
| Gate avaliação — título | Avalie seu último turno |
| Gate avaliação — corpo (back) | Avalie seu último turno para se candidatar. |
| Gate avaliação — ação | Entendi |
| Conflito — título | Conflito de horário |
| Conflito — corpo (back) | Você já tem um compromisso neste horário. |
| Conflito — card (função · estab.) | {função} · {estabelecimento} |
| Conflito — card data/hora | {Dia, dd/mm · HH:mm–HH:mm} |
| Conflito — card CTA | Ver vaga em conflito |
| Conflito — ação | Entendi |
| Habitualidade — título | Limite semanal neste local |
| Habitualidade — corpo (back) | Você já tem 2 turnos nesta semana neste estabelecimento. |
| Habitualidade — ação | Entendi |
| Vaga fechada — título | Vaga indisponível |
| Vaga fechada — corpo (back) | Esta vaga não está mais aberta para candidaturas. |
| Vaga fechada — ação | Voltar ao feed |
| Erro POST — corpo | Não foi possível enviar. Verifique sua conexão. |
| Erro POST — ação | Tentar de novo |
| Retirar — título | Retirar candidatura? |
| Retirar — corpo | Você pode se candidatar de novo enquanto a vaga estiver aberta. |
| Retirar — ação primária | Retirar |
| Retirar — ação secundária | Cancelar |
| Retirar — sucesso (toast) | Candidatura retirada. |
| Retirar — conflito (toast) | Esta candidatura não pode mais ser retirada. |

As **mensagens dos gates** (`mensagem`) vêm **prontas do backend** (CA-1): a UI as exibe
verbatim no corpo do `block.modal` — não as compõe nem as traduz. Os **títulos** dos modais são
da UI (mapeados pelo código de `erro`), porque dão contexto curto acima da prosa do back. Datas
e horas pt-BR 24h (DDR-002). Tom: direto, sem "Ops!"/emoji no corpo. Vocabulário: `glossary.md`.

---

## 6. Acessibilidade (notas específicas)

- **Foco preso no modal (crítico):** ao abrir, o foco vai para o título; `Tab` circula só
  dentro do modal (focus trap). `Esc` = ação secundária (Cancelar/Entendi). Ao fechar, o foco
  volta ao botão que abriu (Candidatar-se / Retirar).
- **Anúncio do desfecho:** o `block.modal` e o toast usam `Semantics(liveRegion: true)` — o
  bloqueio e o sucesso são **lidos**, não só vistos. O título do modal tem `header` semântico.
- **Botão "enviando":** `Semantics(enabled: false, label: 'Enviando candidatura')` durante o
  voo; o spinner é `ExcludeSemantics`.
- **Card do conflito:** alvo único clicável com `Semantics(button: true, label: '{função} em
  {estabelecimento}, {data/hora}. Ver vaga em conflito.')`. ≥48dp.
- **Scrim:** tap fecha (= Cancelar/Entendi); `Semantics` não anuncia o fundo (modal barrier).
- **Contraste:** warning `#9A6E25` / `#D4A95C` e acento do perfil sobre `surface` — AA (tokens
  DDR-001). Erro (vermelho) só em §4.8, AA. Alvos ≥48dp em todos os botões.
- **Sem foco perdido:** o modal monta com `autofocus` no título e desmonta devolvendo o foco.

---

## 7. Identificadores estáveis sugeridos para teste

| Elemento | Identificador lógico sugerido |
|---|---|
| Modal de confirmação (raiz) | `candidatura-confirmar-sheet` |
| Confirmar — resumo da vaga | `candidatura-confirmar-resumo` |
| Confirmar — botão primário | `candidatura-confirmar-btn` |
| Confirmar — botão cancelar | `candidatura-cancelar-btn` |
| Confirmar — erro inline (rede) | `candidatura-confirmar-erro` |
| Confirmar — tentar de novo | `candidatura-retry-btn` |
| Modal de bloqueio (raiz) | `candidatura-bloqueio-modal` |
| Bloqueio — por gate (qualifica) | `candidatura-bloqueio-{erro}` (gate_avaliacao/conflito_horario/habitualidade_bloqueio/vaga_fechada) |
| Bloqueio — título | `candidatura-bloqueio-titulo` |
| Bloqueio — mensagem | `candidatura-bloqueio-mensagem` |
| Bloqueio — ação (Entendi/saída) | `candidatura-bloqueio-acao-btn` |
| Conflito — card clicável | `candidatura-conflito-card` |
| Modal de retirada (raiz) | `candidatura-retirar-sheet` |
| Retirar — confirmar | `candidatura-retirar-confirmar-btn` |
| Retirar — cancelar | `candidatura-retirar-cancelar-btn` |
| Badge "já candidatou" (reuso 049) | `vaga-detalhe-ja-candidatou` |
| CTA candidatar (reuso 049) | `vaga-detalhe-candidatar-btn` |
| Link retirar (reuso 049) | `vaga-detalhe-retirar-btn` |

> Nomes lógicos — o Programador aplica como `Key('...')`. O E2E (CA-11) usa
> `vaga-detalhe-candidatar-btn` → `candidatura-confirmar-btn` (sucesso) e, no cenário de
> conflito, `candidatura-bloqueio-conflito_horario` + `candidatura-conflito-card`.

---

## 8. Exceções ao Design System

| O que diverge | Por quê | Vira DDR? |
|---|---|---|
| `sheet.confirm` — bottom-sheet (mobile) / dialog (desktop) de confirmação de ação: título + resumo + ação primária + cancelar. **Primeiro modal de confirmação do app.** | A candidatura precisa de 1 confirmação deliberada (princípio #1, evita ato acidental) sem virar formulário. Reusada pela retirada e candidata a reuso em qualquer ação irreversível futura (aprovar candidato em STORY-051, cancelar turno em EPIC-003). Material: `showModalBottomSheet` / `AlertDialog` com `LayoutBuilder`. | **Sim — forte candidato.** Promover ao DS quando STORY-051 reusar (2º uso confirma durabilidade). |
| `block.modal` — modal de bloqueio por regra de negócio: cabeçalho `warning` + prosa do back + ação única (e card de conflito quando houver). Reusa `sheet.confirm` sem a ação de confirmar. | É o padrão de "o sistema te impede e te explica por quê, com saída" — coração dos 3 gates. Reaparece em qualquer gate futuro (override de habitualidade no aceite, EPIC-003). | Candidato a registrar junto de `sheet.confirm`. |
| `badge.status` success "Você já se candidatou" (reuso 049) | Materializado em 049; aqui é acionado de verdade pelo 201. | Já previsto — promover com a família. |
| `gate.banner` warning (reuso 048/049) — agora também **dentro** do `block.modal` | 4º contexto do banner warning. | **Promover a `banner.warning` no DS** (uso recorrente confirmado em 046/048/049/050). |

Nenhuma exceção viola token de cor/contraste — warning/acento/erro são tokens auditados AA. A
decisão "gate = warning, não erro (vermelho)" segue a regra de contexto DDR-001 e espelha 049.

---

## 9. Protótipo HTML fiel (validação humana)

- **Localização:** `SCREEN-STORY-050-candidatura/index.html` (mesma pasta deste spec).
- **Cobertura:** seletor de viewport (mobile/desktop) + seletor de estado (`?state=`):
  `confirmar` (modal ocioso), `enviando` (spinner no botão), `sucesso` (badge + toast),
  `gate-avaliacao`, `conflito` (modal + card do conflito clicável), `habitualidade`,
  `vaga-fechada`, `erro` (rede no POST + tentar de novo), `retirar` (sheet de retirada).
- **Fidelidade:** tokens reais do tema profissional (verde) + warning/erro semânticos; microcopy
  = §5 palavra por palavra; identificadores da §7 como `data-testid`. Datas/horas pt-BR 24h. O
  detalhe da vaga (049) aparece esmaecido ao fundo de cada modal.
- **Restrições:** HTML/CSS/JS vanilla, sem rede, abre clicando. Mock inline. Comentário no topo:
  "protótipo de validação, não código de produção".

### Checklist antes de marcar spec `ready`

- [x] Spec cobre confirmar + enviando + sucesso + 4 modais de gate + vaga-fechada/já-candidatou + erro + retirar.
- [x] Microcopy §5 completo (títulos da UI + corpo do back marcado como "vem do back").
- [x] Identificadores §7 cobrem os 3 modais + reuso dos de 049.
- [x] Exceções §8 justificadas (sheet.confirm + block.modal — promoção planejada).
- [ ] Protótipo HTML criado e todos os estados acessíveis (a validar no app + chat).
- [ ] Protótipo apresentado ao humano e sinal de validação capturado.

---

## 10. Dependências e premissas

- **Endpoints (contrato — estória CA-1, CA-8):**
  - `POST /api/vagas/{id}/candidaturas` (autenticado profissional):
    - **201** → `{ id, estado: 'pendente', score_no_momento, candidatou_em }`.
    - **422** → `{ erro, mensagem, detalhe? }`, `erro ∈ { gate_avaliacao, conflito_horario,
      habitualidade_bloqueio, vaga_fechada }`. `detalhe.turno_id` (avaliação),
      `detalhe.conflito_com { tipo, id, vaga_id, data_inicio, data_fim }` (conflito),
      `detalhe.alerta` (habitualidade MEI/PJ — não bloqueia).
    - **409** → `{ erro: 'ja_candidatou', mensagem, ... }` (idempotência — CA-6).
  - `DELETE /api/candidaturas/{id}` (autenticado dono): **200** → `{ estado: 'retirada' }`;
    **409** → estado não-retirável.
- **`mensagem` vem pronta do back** (a UI exibe verbatim); **título** do modal é da UI por
  `erro`. **Para o card do conflito** a UI precisa de função + estabelecimento + datas no
  `detalhe.conflito_com` — se o back só mandar ids, o card cai para "Ver vaga em conflito" sem o
  resumo (fail-soft) e o link ainda funciona via `vaga_id`.
- **Coexistência com 049:** esta spec **substitui os placeholders** de 049 (toast "chega na
  próxima etapa") pela ação real. O CTA, o badge e o link "Retirar" já existem com seus
  identificadores; esta spec só liga o comportamento.
- **Habitualidade MEI/PJ não tem UI de bloqueio:** é 201 normal (sem modal); o alerta é dado do
  contratante (STORY-051). O override do contratante é EPIC-003 — fora desta tela.
- **Sem DDR pendente bloqueante** — opera dentro de DDR-001/DDR-002. As exceções §8
  (`sheet.confirm`, `block.modal`) são aditivas e candidatas a promoção quando STORY-051 reusar.

---

## 11. Histórico de mudanças

| Data | Mudança | Quem | Motivo |
|---|---|---|---|
| 2026-06-02 | criação (spec completo: confirmação + 3 gates + retirada) | claude-opus-4-8 (designer) | story bem especificada; spec entregue para guiar a implementação da ação de candidatura sobre a tela 049 |
