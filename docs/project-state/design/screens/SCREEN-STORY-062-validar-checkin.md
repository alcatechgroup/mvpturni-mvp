---
id: SCREEN-STORY-062-validar-checkin
story: STORY-062-validacao-pin-checkin-transita-ativo
epic: EPIC-003-aceite-pin-e-pix
status: in_implementation    # draft | ready | in_implementation | shipped | superseded
created_at: 2026-06-05
updated_at: 2026-06-05
owner_designer: claude-opus-4-8
related_ddrs: [DDR-001, DDR-002]
ds_components_used: [surface.card, badge.status, button.primary, banner, timeline.event]
exceptions_to_ds: [input.pin (campo de 4 dígitos em mono grande — 1º uso; espelha o pin.display da 061), dialog.confirm (confirmação destrutiva com motivo opcional — 1º uso; roadmap do DS já previa `dialog`), button.text (3º uso — "Recusar check-in"; promover no DS nesta implementação)]
viewports: [mobile, desktop]
prototype_path: SCREEN-STORY-062-validar-checkin/index.html
prototype_last_validated_at: 2026-06-05  # aprovado por Alexandro em chat (sem ajustes)
---

# Spec de tela — SCREEN-STORY-062 — Validação do PIN de check-in pelo contratante

> Referência: estória `STORY-062`. CAs e contexto vêm de lá — **não duplico**.
> Esta entrega é **uma superfície só**: a **área de ações do detalhe do turno**
> (`/turnos/{id}`, SCREEN-060) quando o usuário é o **contratante** e o estado é
> `aguardando_checkin` — o slot que a 061 deixou explícito ("contratante segue com o
> placeholder até a 062"). O profissional não ganha superfície nova (a dele é a 061).
> Geofencing é **alerta-e-registra** (PDR-008): o aviso **nunca bloqueia** a validação.
> Locale pt-BR 24h (DDR-002). Princípios que dirigiram: **#1** (uma tarefa: digitar 4
> dígitos e validar — a recusa é secundária e atrás de confirmação), **#3** (aviso de
> geofencing sério e factual, sem alarme), **#5** (erro associado ao campo, aviso nunca
> só por cor, teclado numérico), **#7** (PIN errado, PIN expirado, rate limit, recusa e
> erro de rede são estados desenhados).

---

## Tema e perfil

Tudo nesta entrega é **tema do contratante** (acento `#9A6E25`, texto `accent.ink`
`#6E4E12` — DDR-001). O card de aviso usa tokens **semânticos** `warning` (que no Turni
compartilham o hue mostarda — regra de contexto dos tokens §4: atenção é sempre
`warning` com ícone + texto, nunca identidade). Badge de estado segue semântico
(SCREEN-059 §4.1).

---

## 1. Objetivo da tela

O contratante, com o profissional na frente dele, **digita os 4 dígitos que o
profissional mostra e confirma a chegada em um gesto**. Se a localização registrada
não bate, ele fica sabendo **antes** de digitar — e decide com essa informação.

---

## 2. Fluxo

### Entrada

- Detalhe `/turnos/{id}` (SCREEN-060), papel **contratante**, turno
  `aguardando_checkin`. Chega pela lista (`/contratante/turnos`), por URL direta ou
  pela notificação in-app (STORY-067 — fora de escopo aqui; o link aponta para cá).
- A área de ações (slot da 060) troca o placeholder pelo **bloco de validação**.

### Ações possíveis

- **Validar check-in** (`button.primary`): POST com o PIN digitado → sucesso transita
  para `ativo`; a tela recarrega a verdade do servidor (badge "● Ativo", timeline com
  "Check-in validado", área de ações volta ao placeholder até a 063 trazer o
  cronômetro).
- **Recusar check-in** (`button.text`, baixa ênfase): abre **dialog de confirmação**
  com motivo opcional (CA-6). Confirmado → turno volta para `confirmado`, PIN deixa de
  valer; a tela recarrega (placeholder + timeline com "Check-in recusado").
- **Digitar o PIN**: campo de 4 dígitos, teclado numérico, botão desabilitado até
  haver 4 dígitos.

### Saída

- Sucesso → mesma tela em `ativo` (snackbar discreto de confirmação).
- Recusa confirmada → mesma tela em `confirmado`.
- PIN expirado por tentativas (CA-3) → mesma tela em `confirmado` (banner explica).
- Erro recuperável (rede/rate limit) → banner/erro inline, estado não muda.

---

## 3. Layout

### 3.1. Área de ações — mobile (≥360px)

Mesmo slot do layout da 060 (§3 de lá — nada muda de posição). De cima para baixo:
**aviso de geofencing (só quando `ok: false`) → card de validação**.

`aguardando_checkin`, geofencing **ok** (sem aviso):

```
|  +------------------------------------+  |
|  | Profissional chegou?               |  |  título (15px w700)
|  | Peça o PIN de 4 dígitos que        |  |  apoio (13.5px text.muted)
|  | aparece no celular do profissional |  |
|  | e digite abaixo.                   |  |
|  |                                    |  |
|  |            ┌─────────┐             |  |  input.pin: JetBrains Mono 28px,
|  |            │  4 7 0 2 │            |  |  letter-spacing 0.35em, centrado,
|  |            └─────────┘             |  |  teclado numérico, maxLength 4
|  |                                    |  |
|  | [      Validar check-in       ]    |  |  button.primary, largura total, ≥48dp
|  |                                    |  |
|  |  Profissional não está no local?   |  |  button.text (alvo ≥48dp)
|  |  Recusar check-in                  |  |
|  +------------------------------------+  |
```

`aguardando_checkin`, geofencing **false** (CA-5 — aviso **antes** do input):

```
|  +------------------------------------+  |
|  | ⚠ O profissional está a cerca de   |  |  card warning.soft #FBEED1,
|  |   350 m do estabelecimento.        |  |  texto accent.ink #6E4E12 (7:1+),
|  |   Confirme com ele antes de        |  |  ícone warning, borda warning @40%
|  |   validar — você pode validar      |  |
|  |   mesmo assim.                     |  |
|  +------------------------------------+  |
|  +------------------------------------+  |
|  | Profissional chegou?               |  |  (card de validação idêntico ao
|  | …                                  |  |   de cima — o aviso não muda nada
|  +------------------------------------+  |   no fluxo: PDR-008 não bloqueia)
```

Variante sem captura (negada/timeout/indisponível): mesmo card, texto
"⚠ Localização do profissional não disponível ({razão}). Confirme com ele antes de
validar — você pode validar mesmo assim."

### 3.2. Dialog de recusa (CA-6)

**Mobile:** dialog central (não sheet — decisão pontual e curta, não documento).
**Desktop:** dialog central max ~480px.

```
+------------------------------------------+
| Recusar check-in?                        |  título (titleMedium)
|                                          |
| O PIN atual deixa de valer e o turno     |  corpo (14px text.muted)
| volta para "Confirmado". O profissional  |
| poderá gerar um novo PIN.                |
|                                          |
| Motivo (opcional)                        |  label
| ┌──────────────────────────────────────┐ |  textarea 3 linhas
| │ Ex.: o profissional ainda não chegou │ |  (placeholder)
| └──────────────────────────────────────┘ |
|                                          |
|              [ Voltar ] [ Recusar       ]|  Voltar = button.text;
|                         [  check-in    ] |  Recusar = sólido `error` (destrutivo)
+------------------------------------------+
```

### 3.3. Desktop (≥1024px)

Idêntico, dentro da coluna esquerda da 060 (sem mudança de grid). Input do PIN a 32px.
Dialog de recusa central. Nenhum comportamento exclusivo de viewport.

### Tablet

Sem comportamento próprio — segue o colapso do grid da 060.

---

## 4. Estados

### 4.1. `aguardando_checkin` + geofencing ok

Bloco de validação (§3.1) **sem** aviso. Botão "Validar check-in" **desabilitado**
(opacidade 38%) enquanto o campo não tiver 4 dígitos — affordance de que falta digitar,
sem mensagem de erro prematura.

### 4.2. `aguardando_checkin` + geofencing false (CA-5)

Card de aviso destacado **acima** do input, cor de atenção do DS (`warning.soft` +
ícone + borda — nunca só cor). Duas variantes:

| Registro | Texto do aviso |
|---|---|
| `ok: false` com distância | ⚠ O profissional está a cerca de {X} do estabelecimento. Confirme com ele antes de validar — você pode validar mesmo assim. |
| sem captura (`razao`) | ⚠ Localização do profissional não disponível ({razão}). Confirme com ele antes de validar — você pode validar mesmo assim. |

Razões em linguagem humana (mesmo conjunto da 061/057): `permissao_negada` →
"permissão negada"; `timeout` → "tempo esgotado"; demais → "indisponível".
Distância: `< 1000` → "350 m"; `≥ 1000` → "1,2 km" (reuso de `geofencing_copy`).
O aviso **não bloqueia nem adiciona passo** (PDR-008): o fluxo de validação é idêntico.

### 4.3. Validando (loading)

Botão em loading (spinner inline no lugar do label → "Validando…"), campo e recusa
bloqueados durante o request. Gesto único — sem skeleton (a tela já está carregada).

### 4.4. PIN errado (422 — CA-2)

Erro **associado ao campo** (`errorText`, não banner global): **"PIN inválido. Confira
com o profissional."** Campo mantém o valor **selecionado** (um toque de tecla
sobrescreve — o caso comum é re-digitar). Sem contagem de tentativas exposta (CA-2).
Botão volta ao normal.

### 4.5. PIN expirado por excesso de tentativas (CA-3)

No 3º erro o backend invalida o PIN e devolve o turno para `confirmado`. A UI mostra
**banner warning** acima da área de ações — **"PIN expirado por excesso de tentativas.
Peça ao profissional para gerar um novo."** — e recarrega a verdade: badge volta a
"● Confirmado", área de ações vira o **placeholder** da 060 (contratante não tem ação
em `confirmado`). O banner persiste até navegação/refresh (é a única pista do que
houve). Profissional, do lado dele, reabre o detalhe e vê a 061 §4.1 ("Gerar PIN") —
nenhuma superfície nova.

### 4.6. Rate limit (429 — CA-2)

Banner de erro: **"Muitas tentativas em pouco tempo. Aguarde um minuto e tente de
novo."** Campo preservado; botão volta ao normal. Sem retry automático.

### 4.7. Erro de rede/servidor na validação

Banner de erro (padrão 047/059/060/061): "Não foi possível validar o check-in.
Verifique sua conexão. [Tentar de novo]" — retry reenvia o **mesmo PIN digitado**.
Estado não muda.

### 4.8. Sucesso → `ativo` (CA-1)

Recarrega a verdade do servidor: badge "● Ativo" (success preenchido — "vivo agora"),
timeline ganha "Check-in validado / Turno iniciado.", área de ações volta ao
placeholder (o cronômetro é a 063). Feedback imediato: **snackbar discreto**
"Check-in validado — turno iniciado." (sucesso celebra com discrição — Princípio #3).

### 4.9. Recusa (CA-6)

- Toque em "Recusar check-in" → **dialog de confirmação** (§3.2). Recusa é destrutiva
  para o fluxo do profissional (PIN morre) — por isso confirmação, ao contrário do
  cancelamento da 061 (que era do próprio dono do PIN).
- Confirmar → botão do dialog em loading → sucesso → dialog fecha, tela recarrega em
  `confirmado` (placeholder + timeline "Check-in recusado").
- Erro no dialog: texto de erro inline no rodapé do dialog ("Não foi possível recusar.
  Tente de novo.") — dialog não fecha, estado não muda.
- "Voltar" / ESC / toque fora → fecha sem efeito.
- Motivo: textarea opcional, máx. 280 caracteres, vai para o audit log (CA-6).

### 4.10. RBAC e demais estados

- **Profissional** em `aguardando_checkin`: continua vendo a área da **061** (gerar
  novo PIN / cancelar) — nada muda para ele.
- **Contratante** em qualquer outro estado: placeholder da 060 (ou superfícies das
  estórias futuras). O bloco de validação só existe em `aguardando_checkin`.
- Terceiros: API responde 403; a UI nem chega a renderizar (detalhe já é fail-secure
  — SCREEN-060 §4.5).
- Estado mudou em outra aba (turno já `ativo`/`confirmado` quando o POST chega):
  servidor responde 422 de estado; a UI **recarrega silenciosamente** a verdade (mesmo
  padrão da 061 — o servidor é a fonte de verdade).

### 4.11. Timeline — eventos desta estória (CA-7)

| Evento | Título | Descrição (ambos os papéis) |
|---|---|---|
| `checkin_validado` | Check-in validado | Turno iniciado. *(já mapeado na 060)* |
| `checkin_recusado` | Check-in recusado | Recusado pelo contratante. |
| `checkin_pin_expirado` | PIN de check-in expirado | Expirado por excesso de tentativas de validação. |

> **Nota ao PO/Programador (premissas):** (a) `checkin_recusado` e
> `checkin_pin_expirado` precisam entrar na whitelist da timeline — a recusa e a
> expiração são transições de estado e o profissional precisa entender pela trilha por
> que voltou a `confirmado` (ADR-015 registra transições). (b) O **motivo** da recusa
> fica no audit log (trilha completa do admin), **não** na timeline das partes —
> evita expor texto livre de um lado para o outro sem revisão; se o PO quiser
> mostrá-lo ao profissional, é decisão de produto à parte. (c) Se os nomes dos eventos
> forem outros, o mapa segue válido.

### Loading / vazio / parcial do detalhe

Inalterados — SCREEN-060 §4.2/4.6 (o skeleton da 060 já cobre o slot de ações).

---

## 5. Microcopy completo

Textos marcados (CA) são fixados pela estória — não alterar sem PO.

| Lugar | Texto |
|---|---|
| Ações — título | Profissional chegou? |
| Ações — apoio | Peça o PIN de 4 dígitos que aparece no celular do profissional e digite abaixo. |
| Campo do PIN — label acessível | PIN de check-in, 4 dígitos |
| CTA validar | Validar check-in |
| CTA validar — loading | Validando… |
| Erro PIN inválido (CA-2) | PIN inválido. Confira com o profissional. |
| Banner PIN expirado (CA-3) | PIN expirado por excesso de tentativas. Peça ao profissional para gerar um novo. |
| Banner rate limit | Muitas tentativas em pouco tempo. Aguarde um minuto e tente de novo. |
| Banner erro de rede | Não foi possível validar o check-in. Verifique sua conexão. |
| Retry | Tentar de novo |
| Aviso geo — fora do raio (CA-5) | ⚠ O profissional está a cerca de {X} do estabelecimento. Confirme com ele antes de validar — você pode validar mesmo assim. |
| Aviso geo — sem captura (CA-5) | ⚠ Localização do profissional não disponível ({razão}). Confirme com ele antes de validar — você pode validar mesmo assim. |
| Razões | permissão negada · tempo esgotado · indisponível |
| Recusar (gatilho) | Profissional não está no local? Recusar check-in |
| Dialog — título | Recusar check-in? |
| Dialog — corpo | O PIN atual deixa de valer e o turno volta para "Confirmado". O profissional poderá gerar um novo PIN. |
| Dialog — label do motivo | Motivo (opcional) |
| Dialog — placeholder do motivo | Ex.: o profissional ainda não chegou ao estabelecimento |
| Dialog — confirmar | Recusar check-in |
| Dialog — voltar | Voltar |
| Dialog — erro | Não foi possível recusar. Tente de novo. |
| Snackbar de sucesso | Check-in validado — turno iniciado. |
| Badge `ativo` | ● Ativo (SCREEN-059 §4.1) |
| Timeline | tabela §4.11 |

Horários 24h pt-BR (DDR-002). Distâncias "350 m" / "1,2 km" (reuso `geofencing_copy`).

---

## 6. Acessibilidade (notas específicas)

- **Campo do PIN:** `Semantics(label: 'PIN de check-in, 4 dígitos')`;
  `keyboardType: number` + filtro só-dígitos; `maxLength: 4` sem contador visual;
  autocomplete/correção desligados. Visual mono grande não vaza para o leitor.
- **Erro do campo (CA-2):** via `errorText` do `TextFormField` — anunciado pelo leitor
  e vinculado ao campo, não toast solto.
- **Card de aviso de geofencing:** `Semantics(liveRegion: false)` — está presente
  desde o load (não é dinâmico); ícone + texto + borda, nunca só cor (tokens §4).
  Contraste `accent.ink #6E4E12` / `warning.soft #FBEED1` ≥ 7:1 ✅.
- **Banners dinâmicos (expirado/rate limit/rede):** `Semantics(liveRegion: true)` —
  anunciados ao aparecer.
- **Dialog de recusa:** focus trap; foco inicial no **corpo/título** (não no botão
  destrutivo — evita confirmação acidental); ESC e toque fora fecham; botões ≥48dp;
  "Recusar check-in" em `error` sólido (branco 5.7:1 ✅).
- **Botão desabilitado (sem 4 dígitos):** o apoio do card já explica o que falta —
  fora do botão, sempre legível por leitor.
- Alvos ≥48dp; foco visível (anel `accent`); `prefers-reduced-motion` respeitado.

---

## 7. Identificadores estáveis sugeridos para teste

| Elemento | Identificador lógico sugerido |
|---|---|
| Bloco de validação (card raiz) | `validar-checkin-area` |
| Card de aviso de geofencing | `validar-checkin-geo-aviso` |
| Campo do PIN | `validar-checkin-pin-input` |
| Botão validar | `validar-checkin-btn` |
| Erro inline do campo | `validar-checkin-pin-erro` |
| Banner (expirado/rate limit/rede) | `validar-checkin-banner` |
| Retry do banner | `validar-checkin-retry-btn` |
| Gatilho da recusa | `recusar-checkin-btn` |
| Dialog de recusa | `recusar-checkin-dialog` |
| Textarea do motivo | `recusar-checkin-motivo-input` |
| Confirmar recusa | `recusar-checkin-confirmar-btn` |
| Voltar (dialog) | `recusar-checkin-voltar-btn` |
| Erro do dialog | `recusar-checkin-erro` |
| Snackbar de sucesso | `validar-checkin-sucesso` |

> E2E (CA-8) ancora: PIN correto (`validar-checkin-btn` → badge `ativo`), 3 errados
> (`validar-checkin-pin-erro` ×2 → `validar-checkin-banner` expirado), recusa
> (`recusar-checkin-confirmar-btn` → placeholder) e geofencing false
> (`validar-checkin-geo-aviso` presente e validação segue possível).

---

## 8. Exceções ao Design System

| O que diverge | Por quê | Vira DDR? |
|---|---|---|
| `input.pin` — campo de 4 dígitos em JetBrains Mono 28px (32px desktop), letter-spacing 0.35em, centrado | O DS tem `input.text` só no roadmap; este campo é o **espelho de entrada** do `pin.display` da 061 (mesma família visual: o contratante digita o que o profissional mostra). 1º uso; reaparece **idêntico na STORY-064** (check-out). | **Candidato** — promover junto com `pin.display` quando a 064 reusar. |
| `dialog.confirm` — confirmação destrutiva (título + corpo + campo opcional + ações Voltar/destrutiva em `error`) | Roadmap do DS já previa `dialog`; o `dialog.document` da 060 é leitura, este é decisão. 1º uso real de confirmação; reaparece em cancelamento de turno (STORY-066) e disputa (EPIC-005). | **Candidato** — promover no 2º uso. |
| `button.text` — **3º uso** ("Profissional não está no local? Recusar check-in"; mesmos da 061: "Cancelar PIN" ×2) | A 061 marcou promoção no 2º uso — confirmado e passado; **promover no `components.md` nesta implementação** (padrão "pergunta? ação" de baixa ênfase). | Não — promoção já prevista. |

Nenhuma cor nova; warning/error vêm dos tokens semânticos auditados (§4/§6 do tokens.md).

---

## 9. Protótipo HTML fiel (validação humana)

- **Localização:** `SCREEN-STORY-062-validar-checkin/index.html`.
- **Cobertura:** seletor de **viewport** (mobile/desktop), **papel** (contratante /
  profissional — profissional prova que o lado dele segue a 061) e **cenário de
  geofencing** (ok / fora do raio / sem captura). O fluxo é **interativo de verdade**:
  digitar o PIN certo (4702) valida → estado `ativo` com badge + timeline + snackbar;
  PIN errado mostra o erro inline; 3 erros → banner de expirado + volta a `confirmado`;
  "Recusar check-in" abre o dialog com motivo → confirma → `confirmado` com timeline.
  Atalhos por estado (`?state=`): `aguardando-ok`, `aguardando-fora-raio`,
  `aguardando-sem-geo`, `pin-errado`, `expirado`, `rate-limit`, `erro-rede`,
  `recusa-dialog`, `ativo`.
- **Fidelidade:** tokens reais (tema contratante + semânticos), JetBrains Mono com
  fallback mono do sistema; microcopy = §5 palavra por palavra; identificadores §7
  como `data-testid`; horários 24h pt-BR.
- **Restrições:** HTML/CSS/JS vanilla, sem rede, mock inline, comentário "protótipo
  de validação".

### Checklist antes de marcar spec `ready`

- [x] Protótipo abre sem erro; todos os estados acessíveis nos dois viewports.
- [x] Caminho feliz ponta a ponta (digitar 4702 → validar → ativo) + caminho de erro
      (3 errados → expirado) + recusa (dialog → confirmado).
- [x] Microcopy bate palavra por palavra com a §5.
- [x] Identificadores da §7 presentes.
- [x] Tokens reais; input em mono ≥28px.
- [x] Protótipo apresentado ao humano e sinal de validação capturado (inclui as
      premissas §4.11 — eventos `checkin_recusado`/`checkin_pin_expirado` na timeline
      e motivo só na trilha do admin).

---

## 10. Dependências e premissas

- **Endpoints (contrato — estória CA-1/CA-6):**
  - `POST /api/turnos/{uuid}/validar-checkin` com `{ pin: "1234" }` →
    `200 { estado: 'ativo' }`; **422** PIN errado (`motivo: 'pin_invalido'`);
    **422** expirado no 3º erro (`motivo: 'pin_expirado'` — turno já voltou a
    `confirmado` no servidor); **429** rate limit; **403** RBAC (só contratante do
    turno); 422 de estado (`motivo: 'estado_invalido'`) → UI recarrega silenciosa.
    Formato fino é do Programador; a UI distingue `pin_invalido` (inline §4.4) ×
    `pin_expirado` (banner §4.5) × resto.
  - **Recusa**: endpoint a critério do Programador (ex.:
    `POST /api/turnos/{uuid}/recusar-checkin` com `{ motivo?: string }`); UI trata
    erro como §4.9.
- **Geofencing no payload do contratante:** em `aguardando_checkin` o detalhe precisa
  expor o snapshot (`ok`, `distancia_metros`, `razao`) para o card §4.2 — campo
  top-level ou derivado do evento `checkin_solicitado` mais recente da timeline (que
  já o carrega); decisão do Programador, a UI tolera os dois.
- **Rate limit**: 5/60s por turno, configurável via env (CA-2) — número não aparece
  na UI; o banner §4.6 é genérico de propósito.
- **Timeline**: whitelist ganha `checkin_recusado` e `checkin_pin_expirado` (§4.11 —
  premissa).
- **Evento `TurnoIniciado`** (CA-1) é contrato de domínio para 063/067 — sem
  superfície de UI aqui.
- Spec **não depende** de DDR pendente.

---

## 11. Histórico de mudanças

| Data | Mudança | Quem | Motivo |
|---|---|---|---|
| 2026-06-05 | criação (spec completo + protótipo v1) | claude-opus-4-8 (designer) | STORY-062; spec + protótipo entregues juntos para validação humana |
| 2026-06-05 | validação humana — aprovado sem ajustes | Alexandro | inclui premissas §4.11 (eventos `checkin_recusado`/`checkin_pin_expirado` na timeline; motivo da recusa só na trilha do admin); `status: ready` |
| 2026-06-05 | implementação | claude-opus-4-8 (programador) | premissas confirmadas: geofencing exposto top-level no payload do contratante em `aguardando_checkin`; eventos na whitelist da timeline; `button.text` promovido no DS (3º uso); `status: in_implementation` |
