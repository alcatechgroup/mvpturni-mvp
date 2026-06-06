---
id: SCREEN-STORY-064-pin-checkout
story: STORY-064-pin-checkout-validacao-transita-finalizado
epic: EPIC-003-aceite-pin-e-pix
status: shipped              # draft | ready | in_implementation | shipped | superseded
created_at: 2026-06-05
updated_at: 2026-06-06
owner_designer: claude-opus-4-8
related_ddrs: [DDR-001, DDR-002]
ds_components_used: [surface.card, badge.status, button.primary, button.text, banner, timeline.event, mono.display]
exceptions_to_ds: [dialog.confirm (2º uso — recusa de check-out, espelho da recusa da 062; promover no components.md nesta implementação, conforme previsto)]
viewports: [mobile, desktop]
prototype_path: SCREEN-STORY-064-pin-checkout/index.html
prototype_last_validated_at: 2026-06-05  # aprovado por Alexandro em chat (sem ajustes)
---

# Spec de tela — SCREEN-STORY-064 — PIN de check-out: geração, validação e `finalizado`

> Referência: estória `STORY-064`. CAs e contexto vêm de lá — **não duplico**.
> Esta entrega é o **espelho de check-out da dupla 061/062** — mesmas superfícies,
> mesmo vocabulário visual, diferenças mínimas e intencionais:
> (a) estado de origem é `ativo` (não `confirmado`); (b) **sem janela horária** (CA-1 —
> turno pode estender); (c) geofencing **capturado em silêncio, sem aviso destacado**
> (estória: saída não é tão crítica quanto entrada); (d) recusa/expiração voltam para
> `ativo` — **nunca `em_disputa`** (EPIC-005, fora de escopo); (e) o **cronômetro da
> 063** ganha os comportamentos congelado (`aguardando_checkout`) e final (`finalizado`)
> que a própria 063 deixou como premissa (§10 de lá).
> Locale pt-BR 24h (DDR-002). Princípios que dirigiram: **#1** (cada lado tem UMA
> tarefa: mostrar o PIN / digitar o PIN), **#3** (fim de turno fecha com discrição —
> zero confete), **#4** (reuso total: `mono.display`, `button.text`, `dialog.confirm`,
> banners — nenhum componente novo), **#7** (PIN errado, expirado, recusa, cancelamento
> e erro de rede são estados desenhados).

---

## Tema e papéis

Dupla bilateral: lado do **profissional** (geração — tema verde-sage `#2D5F3F`) e lado
do **contratante** (validação — tema mostarda `#9A6E25`), DDR-001. Badges semânticos
da SCREEN-059 §4.1: `⧖ Aguardando check-out` (warning soft) e `✓ Finalizado` (neutro).

---

## 1. Objetivo da tela

**Profissional:** "terminei o trabalho → gero o PIN" em um toque — e o contratante lê
o número do outro lado do balcão.
**Contratante:** digita os 4 dígitos e encerra o turno em um gesto — o cronômetro para
e o valor final fica registrado para os dois.

---

## 2. Fluxo

### Entrada

- **Lado do profissional:** detalhe `/turnos/{id}` (SCREEN-060), papel profissional,
  turno `ativo` → a área de ações (placeholder desde a 063) ganha o bloco de geração.
  O card do cronômetro (063) continua acima, ticando.
- **Tela do PIN de check-out:** somente após geração bem-sucedida (push de view).
  **Não endereçável por URL** — PIN efêmero (mesma disciplina da 061): refresh ou
  deep-link caem no detalhe em `aguardando_checkout` (§4.4).
- **Lado do contratante:** detalhe `/turnos/{id}`, papel contratante, turno
  `aguardando_checkout` → área de ações ganha o bloco de validação (espelho da 062).

### Ações possíveis

- **Gerar PIN de check-out** (`button.primary`, profissional em `ativo`): captura de
  geolocalização **silenciosa** (PDR-008; sem microcopy de localização — §4.2) → POST →
  tela do PIN. Sempre habilitado em `ativo` (CA-1 — sem janela).
- **Gerar novo PIN** (profissional em `aguardando_checkout`): mesmo fluxo; o anterior
  deixa de valer (idempotente, espelho 061).
- **Ainda não terminou? Cancelar PIN** (`button.text`, tela do PIN **e** área de ações
  em `aguardando_checkout`): volta o turno para `ativo` — o cronômetro **retoma** e o
  display salta para a duração real (o tempo nunca parou de valer; §4.9).
- **Validar check-out** (`button.primary`, contratante): POST com o PIN → sucesso
  transita para `finalizado`; cronômetro congela na duração final (CA-6).
- **Turno ainda não terminou? Recusar check-out** (`button.text`, contratante): abre
  `dialog.confirm` com motivo opcional (CA-5) → confirma → turno volta para `ativo`.
- **Voltar** (AppBar da tela do PIN): retorna ao detalhe em `aguardando_checkout` —
  PIN não re-exibível (aviso de efemeridade, §5).

### Saída

- Geração → tela do PIN. Cancelamento → detalhe em `ativo` (cronômetro retoma).
- Validação → detalhe em `finalizado` (badge + cronômetro final + timeline + snackbar).
- Recusa confirmada / PIN expirado por tentativas → detalhe em `ativo`.
- Erro recuperável → banner com retry; estado não muda.

---

## 3. Layout

### 3.1. Área de ações do profissional — mobile (≥360px)

Mesmo slot da 060/061. O card do cronômetro (063) fica acima, inalterado.

`ativo` (CA-1 — sempre habilitado):

```
|  +------------------------------------+  |
|  | Terminou o turno?                  |  |  título (15px w700)
|  | Gere o PIN de check-out e mostre   |  |  apoio (13.5px text.muted)
|  | ao contratante para confirmar o    |  |
|  | fim do turno.                      |  |
|  | [   Gerar PIN de check-out     ]   |  |  button.primary, largura total, ≥48dp
|  +------------------------------------+  |
```

`aguardando_checkout` (pós-refresh / volta da tela do PIN):

```
|  | Aguardando validação do contratante|  |
|  | Perdeu o PIN de vista? Gere um     |  |
|  | novo — o anterior deixa de valer.  |  |
|  | [       Gerar novo PIN         ]   |  |  button.primary
|  |  Ainda não terminou? Cancelar PIN  |  |  button.text (alvo ≥48dp)
```

### 3.2. Tela do PIN de check-out — mobile (≥360px)

Idêntica à tela do PIN da 061 (`mono.display`, variante `pin.display`), com duas
diferenças: microcopy de check-out e **sem nota de geofencing** (captura silenciosa —
o registro vai para a timeline, CA-7; nada compete com o número).

```
+------------------------------------------+
| ←  PIN de check-out                      |  AppBar (voltar + título)
+------------------------------------------+
|   Garçom · Bar do Zé                     |  contexto (13px text.muted)
|                                          |
|   Mostre este PIN ao contratante         |  instrução (16px text.strong)
|   para validar o fim do turno            |
|                                          |
|              8 3 4 1                     |  pin.display: JetBrains Mono,
|                                          |  72px w600, letter-spacing 0.18em
|   Se sair desta tela, será preciso       |  aviso de efemeridade (13px muted)
|   gerar um novo PIN.                     |
|                                          |
|   Ainda não terminou? Cancelar PIN       |  button.text, centrado, ≥48dp
+------------------------------------------+
```

### 3.3. Área de ações do contratante — mobile (≥360px)

Espelho exato da 062 §3.1, **sem card de aviso de geofencing** (estória: sem aviso
destacado na validação; o snapshot vai só para timeline/audit — CA-7):

```
|  +------------------------------------+  |
|  | Turno concluído?                   |  |  título (15px w700)
|  | Peça o PIN de 4 dígitos que        |  |  apoio (13.5px text.muted)
|  | aparece no celular do profissional |  |
|  | e digite abaixo.                   |  |
|  |            ┌─────────┐             |  |  input.pin (mono.display): 28px,
|  |            │  8 3 4 1 │            |  |  letter-spacing 0.35em, numérico
|  |            └─────────┘             |  |
|  | [      Validar check-out      ]    |  |  button.primary, largura total
|  |  Turno ainda não terminou?         |  |  button.text (alvo ≥48dp)
|  |  Recusar check-out                 |  |
|  +------------------------------------+  |
```

O card do cronômetro (acima, 063) está **congelado** em `aguardando_checkout` (§4.10).

### 3.4. Dialog de recusa (CA-5) — `dialog.confirm` (2º uso)

Mesma anatomia da 062 §3.2 (título + corpo + motivo opcional + Voltar/destrutiva):

```
+------------------------------------------+
| Recusar check-out?                       |
|                                          |
| O PIN atual deixa de valer e o turno     |
| volta para "Ativo" — o tempo continua    |
| contando. O profissional poderá gerar    |
| um novo PIN.                             |
|                                          |
| Motivo (opcional)                        |
| ┌──────────────────────────────────────┐ |
| │ Ex.: o turno ainda não terminou      │ |
| └──────────────────────────────────────┘ |
|              [ Voltar ] [ Recusar       ]|
|                         [  check-out   ] |
+------------------------------------------+
```

### 3.5. Desktop (≥1024px)

Tudo idêntico à 061/062: área de ações na coluna esquerda da 060 (sem mudança de
grid); tela do PIN centrada em card max ~560px com PIN a 96px e marca `TURNI.`;
input do PIN a 32px; dialog central max ~480px. **Tablet:** sem comportamento próprio
(colapso do grid da 060).

---

## 4. Estados

### 4.1. Profissional — `ativo`

Bloco de geração (§3.1), botão **sempre habilitado** (CA-1 — sem janela; turno pode
estender). Continua sendo a única chamada primária da tela.

### 4.2. Gerando (loading — CA-2)

Clique → botão em loading (spinner inline → **"Gerando PIN…"**), toque bloqueado.
A captura de geolocalização acontece **dentro** desse gesto, em silêncio: concedida →
coordenadas vão no POST; negada/timeout (~10s)/erro → segue com `geo: null` + razão
(PDR-008 — nunca bloqueia). **Diferença consciente da 061:** o loading não diz
"Confirmando sua localização…" — a estória rebaixou o geofencing de check-out; a
microcopy não promete o que a UI não destaca. Sucesso → tela do PIN (§4.3).

### 4.3. Tela do PIN (sucesso)

§3.2. **Sem nota de geofencing** — diferença intencional da 061: o resultado da
captura vai para a timeline (§4.12) e o contratante não vê aviso destacado; uma nota
aqui criaria expectativa de simetria que não existe. O PIN aparece em plaintext
**uma única vez** (CA-2 — mesma disciplina da 061).

### 4.4. Profissional — `aguardando_checkout` (pós-refresh / volta)

Badge "⧖ Aguardando check-out" (SCREEN-059 §4.1). Área de ações vira o bloco do §3.1
(variante `aguardando_checkout`): **Gerar novo PIN** (primário) + **Cancelar PIN**
(texto). Cronômetro congelado acima (§4.10).

### 4.5. Erro na geração (rede/servidor)

Espelho da 061 §4.6: botão volta ao normal; `banner` de erro acima da área de ações —
"Não foi possível gerar o PIN. Verifique sua conexão. [Tentar de novo]". Retry refaz
o gesto completo (nova captura de geo). Estado não muda.

### 4.6. Cancelamento do PIN (profissional)

Espelho da 061 §4.8 — na tela do PIN ou na área de ações: "Ainda não terminou?
Cancelar PIN" → loading inline → sucesso → detalhe em `ativo`: cronômetro **retoma o
tick** e o display **salta para a duração real** (âncora `iniciado_em` inalterada —
ADR-017; o tempo congelado era só exibição, o turno nunca parou de valer). Sem dialog
de confirmação (ação do dono do PIN, reversível em um toque). Erro: banner "Não foi
possível cancelar o PIN. [Tentar de novo]".

### 4.7. Contratante — `aguardando_checkout`

Bloco de validação (§3.3). Botão "Validar check-out" desabilitado (opacidade 38%) até
4 dígitos. **Sem aviso de geofencing** (diferença intencional da 062 — estória).

### 4.8. Validação: PIN errado, expirado, rate limit, rede (CA-4)

Espelho exato da 062 §4.3–4.7 com vocabulário de check-out:

- **Validando:** botão em loading ("Validando…"), campo e recusa bloqueados.
- **PIN errado (422):** erro associado ao campo — "PIN inválido. Confira com o
  profissional." Valor mantido **selecionado**. Sem contagem exposta.
- **3ª errada (CA-4):** backend invalida o PIN e devolve o turno para **`ativo`**
  (estado de origem — espelho da 062, que devolvia a `confirmado`). Banner warning:
  "PIN expirado por excesso de tentativas. Peça ao profissional para gerar um novo."
  Área de ações do contratante volta ao placeholder; cronômetro **retoma** (§4.6).
  Profissional, do lado dele, vê §4.1 ("Gerar PIN de check-out") ao reabrir.
- **Rate limit (429):** banner "Muitas tentativas em pouco tempo. Aguarde um minuto e
  tente de novo."
- **Erro de rede:** banner "Não foi possível validar o check-out. Verifique sua
  conexão. [Tentar de novo]" — retry reenvia o mesmo PIN.

### 4.9. Recusa (CA-5)

Espelho da 062 §4.9: gatilho → `dialog.confirm` (§3.4) → confirmar (loading) → turno
volta para `ativo`; dialog fecha; placeholder + cronômetro retoma + timeline
"Check-out recusado". Motivo: textarea opcional ≤280 caracteres → **audit log apenas**
(`turno.checkout_recusado` — CA-5; mesmo princípio da 062: texto livre de um lado não
vaza para o outro sem revisão). **Não existe caminho para `em_disputa`** — nem
microcopy que o sugira (EPIC-005). Erro inline no dialog: "Não foi possível recusar.
Tente de novo."

### 4.10. Cronômetro — `aguardando_checkout` (CA-6, integração com a 063)

O card da 063 congela (063 §4.4), agora com a duração **idêntica nos dois lados**: a
064 expõe o instante da solicitação (`encerrado_em` provisório) no payload do
cronômetro — premissa da 063 §10 cumprida aqui. Microcopy do CA-6 desta estória:

```
|  | AGUARDANDO CHECK-OUT               |  |  título sem dot
|  |            05:02:13                |  |  congelado
|  | Aguardando validação — duração:    |  |  linha fixa do CA-6
|  | 05:02:13                           |  |
```

> **Conflito de microcopy a resolver com o PO:** a 063 shipou esta linha como
> "Aguardando check-out — duração final: {HH:MM:SS}" (CA-5 de lá); o CA-6 da 064 fixa
> "Aguardando validação — duração: {HH:MM:SS}". **Resolvido na validação humana
> (2026-06-05): Alexandro aprovou adotar o CA-6 da 064** (mais preciso: o que está
> pendente é a validação, não o check-out — e "duração final" mentia, pois recusa/
> cancelamento fazem o tempo retomar). A troca é mudança consciente registrada no
> histórico da SCREEN-063 na implementação.

### 4.11. Cronômetro — `finalizado` (CA-6, estado novo do card)

A 063 escondia o card fora de {`ativo`, `aguardando_checkout`}; a 064 **estende** o
card ao `finalizado` — a duração final é a informação mais consultada de um turno
encerrado (e a STORY-065 pendura o Pix nela):

```
|  +------------------------------------+  |
|  | TURNO FINALIZADO                   |  |  título sem dot
|  |            05:04:27                |  |  duração final: check_out_at − iniciado_em
|  | Turno finalizado — duração:        |  |  linha fixa do CA-6
|  | 05:04:27                           |  |
|  +------------------------------------+  |
```

Badge "✓ Finalizado" (neutro — SCREEN-059). Polling morto (estado terminal). Área de
ações: **nenhuma** — estado terminal segue a regra da 060 §4.1 ("não prometer ação onde
nunca haverá"; ajuste consciente sobre o protótipo v1, que mostrava o placeholder —
Pix/recibo chegam com a 065+). Feedback imediato de quem validou: **snackbar**
"Check-out validado — turno finalizado." (discreto, Princípio #3).

### 4.12. Timeline — eventos desta estória (CA-7)

| Evento | Título | Descrição (ambos os papéis) |
|---|---|---|
| `checkout_solicitado` + geo ok | PIN de check-out gerado | Localização confirmada (a {X} m do estabelecimento). |
| `checkout_solicitado` fora do raio | PIN de check-out gerado | Fora do raio do estabelecimento (a {X} m). |
| `checkout_solicitado` sem geo | PIN de check-out gerado | Localização não capturada ({razão}). |
| `checkout_validado` | Check-out validado | Turno finalizado. |
| `checkout_recusado` | Check-out recusado | Recusado pelo contratante. |
| `checkout_cancelado` | PIN de check-out cancelado | Cancelado pelo profissional antes da validação. |
| `checkout_pin_expirado` | PIN de check-out expirado | Expirado por excesso de tentativas de validação. |

> **Nota ao PO/Programador (premissas, espelho 061/062):** (a) os 4 eventos novos
> entram na whitelist da timeline; (b) `checkout_cancelado` e `checkout_pin_expirado`
> seguem o precedente já aprovado nas 061/062; (c) motivo da recusa fica no audit log
> (admin), não na timeline das partes; (d) o geofencing aparece **só** na descrição do
> evento — é o único lugar onde o check-out o expõe (CA-7: "sem aviso destacado").

### 4.13. RBAC e demais estados

- Profissional × contratante: cada um vê só o seu bloco (payload por papel, espelho
  061/062); terceiros caem no fail-secure da 060 §4.5; API responde 403.
- Estado mudou em outra aba (POST chega com turno já `finalizado`/`ativo`): 422 de
  estado → UI **recarrega silenciosamente** a verdade (padrão 061/062).
- Loading/vazio/parcial do detalhe: inalterados (SCREEN-060 §4.2/4.6).

---

## 5. Microcopy completo

Textos marcados (CA) são fixados pela estória — não alterar sem PO.

| Lugar | Texto |
|---|---|
| Ações prof. — título (`ativo`) | Terminou o turno? |
| Ações prof. — apoio (`ativo`) | Gere o PIN de check-out e mostre ao contratante para confirmar o fim do turno. |
| CTA gerar (CA-1) | Gerar PIN de check-out |
| CTA gerar — loading | Gerando PIN… |
| Ações prof. — título (`aguardando_checkout`) | Aguardando validação do contratante |
| Ações prof. — apoio (`aguardando_checkout`) | Perdeu o PIN de vista? Gere um novo — o anterior deixa de valer. |
| CTA gerar novo | Gerar novo PIN |
| Cancelar (tela do PIN e ações) | Ainda não terminou? Cancelar PIN |
| Tela do PIN — título (AppBar) | PIN de check-out |
| Tela do PIN — contexto | {Função} · {Estabelecimento} |
| Tela do PIN — instrução (CA-2) | Mostre este PIN ao contratante para validar o fim do turno |
| Aviso de efemeridade | Se sair desta tela, será preciso gerar um novo PIN. |
| Erro ao gerar (banner) | Não foi possível gerar o PIN. Verifique sua conexão. |
| Erro ao cancelar (banner) | Não foi possível cancelar o PIN. |
| Ações contr. — título | Turno concluído? |
| Ações contr. — apoio | Peça o PIN de 4 dígitos que aparece no celular do profissional e digite abaixo. |
| Campo do PIN — label acessível | PIN de check-out, 4 dígitos |
| CTA validar (CA-3) | Validar check-out |
| CTA validar — loading | Validando… |
| Erro PIN inválido (CA-4) | PIN inválido. Confira com o profissional. |
| Banner PIN expirado (CA-4) | PIN expirado por excesso de tentativas. Peça ao profissional para gerar um novo. |
| Banner rate limit | Muitas tentativas em pouco tempo. Aguarde um minuto e tente de novo. |
| Banner erro de rede | Não foi possível validar o check-out. Verifique sua conexão. |
| Retry | Tentar de novo |
| Recusar (gatilho — CA-5) | Turno ainda não terminou? Recusar check-out |
| Dialog — título | Recusar check-out? |
| Dialog — corpo | O PIN atual deixa de valer e o turno volta para "Ativo" — o tempo continua contando. O profissional poderá gerar um novo PIN. |
| Dialog — label do motivo | Motivo (opcional) |
| Dialog — placeholder do motivo | Ex.: o turno ainda não terminou |
| Dialog — confirmar | Recusar check-out |
| Dialog — voltar | Voltar |
| Dialog — erro | Não foi possível recusar. Tente de novo. |
| Snackbar de sucesso | Check-out validado — turno finalizado. |
| Cronômetro — título (`aguardando_checkout`) | Aguardando check-out |
| Cronômetro — linha (`aguardando_checkout`, CA-6) | Aguardando validação — duração: {HH:MM:SS} |
| Cronômetro — título (`finalizado`) | Turno finalizado |
| Cronômetro — linha (`finalizado`, CA-6) | Turno finalizado — duração: {HH:MM:SS} |
| Badge `aguardando_checkout` | ⧖ Aguardando check-out (SCREEN-059 §4.1) |
| Badge `finalizado` | ✓ Finalizado (SCREEN-059 §4.1) |
| Timeline | tabela §4.12 |

Horários 24h pt-BR (DDR-002). Tempo `HH:MM:SS`/`MM:SS` conforme 063 §3.1.

---

## 6. Acessibilidade (notas específicas)

Herda integralmente as notas da 061 (tela do PIN: `Semantics` dígito a dígito,
contraste AAA 15.7:1, foco inicial fora do Cancelar) e da 062 (campo: label acessível,
`errorText` vinculado, teclado numérico; dialog: focus trap, foco no corpo, destrutivo
em `error` sólido 5.7:1; banners `liveRegion: true`). Específicos da 064:

- **Cronômetro congelado → finalizado:** as linhas do CA-6 são `liveRegion: true` —
  o usuário de leitor sabe que o tempo parou / o turno encerrou (já previsto na 063 §6).
- **Retomada do cronômetro (recusa/cancelamento/expiração):** o salto do display não é
  anunciado por segundo (semântica da 063 atualiza por minuto — sem mudança).
- Alvos ≥48dp; foco visível (anel `accent`); `prefers-reduced-motion` respeitado.

---

## 7. Identificadores estáveis sugeridos para teste

| Elemento | Identificador lógico sugerido |
|---|---|
| Botão gerar PIN de check-out | `turno-checkout-gerar-btn` |
| Botão gerar novo PIN | `turno-checkout-regen-btn` |
| Cancelar PIN (área de ações) | `turno-checkout-cancelar-btn` |
| Banner de erro (gerar/cancelar) | `turno-checkout-erro-banner` |
| Retry do banner (profissional) | `turno-checkout-retry-btn` |
| Tela do PIN (raiz) | `pin-checkout-screen` |
| Código do PIN | `pin-checkout-codigo` |
| Instrução | `pin-checkout-instrucao` |
| Aviso de efemeridade | `pin-checkout-efemero-msg` |
| Cancelar PIN (tela do PIN) | `pin-checkout-cancelar-btn` |
| Voltar (AppBar tela do PIN) | `pin-checkout-voltar` |
| Bloco de validação (card raiz) | `validar-checkout-area` |
| Campo do PIN | `validar-checkout-pin-input` |
| Botão validar | `validar-checkout-btn` |
| Erro inline do campo | `validar-checkout-pin-erro` |
| Banner (expirado/rate limit/rede) | `validar-checkout-banner` |
| Retry do banner (contratante) | `validar-checkout-retry-btn` |
| Gatilho da recusa | `recusar-checkout-btn` |
| Dialog de recusa | `recusar-checkout-dialog` |
| Textarea do motivo | `recusar-checkout-motivo-input` |
| Confirmar recusa | `recusar-checkout-confirmar-btn` |
| Voltar (dialog) | `recusar-checkout-voltar-btn` |
| Erro do dialog | `recusar-checkout-erro` |
| Snackbar de sucesso | `validar-checkout-sucesso` |
| Linha do cronômetro congelado (CA-6) | `cronometro-aguardando-checkout` *(já existe — 063)* |
| Linha do cronômetro finalizado (CA-6) | `cronometro-finalizado` |

> E2E (CA-8) ancora o ciclo completo: `turno-checkout-gerar-btn` → `pin-checkout-codigo`
> → `validar-checkout-btn` → badge `finalizado` + `cronometro-finalizado`. Recusa e
> expiração ancoram em `recusar-checkout-confirmar-btn`/`validar-checkout-banner` +
> retomada do `cronometro-display`.

---

## 8. Exceções ao Design System

| O que diverge | Por quê | Vira DDR? |
|---|---|---|
| `dialog.confirm` — **2º uso** (recusa de check-out; 1º foi a recusa de check-in da 062) | A 062 marcou promoção no 2º uso — confirmado: **promover no `components.md` nesta implementação** (anatomia: título + corpo + campo opcional + Voltar/destrutiva em `error`). | Não — promoção já prevista. |

`pin.display`, `input.pin` e `cronometro.display` já são variantes do `mono.display`
registrado (3º uso na 063) — a 064 só **reusa**, como a 061 previu ("promover quando a
STORY-064 reusar no check-out" — cumprido). Nenhuma cor nova; nenhum componente novo.

---

## 9. Protótipo HTML fiel (validação humana)

- **Localização:** `SCREEN-STORY-064-pin-checkout/index.html`.
- **Cobertura:** seletor de **viewport** (mobile/desktop), **papel** (profissional /
  contratante) e **estado**: `ativo` (cronômetro ticando + botão de gerar),
  `pin-checkout` (tela do PIN), `aguardando-checkout` (os dois lados: regen/cancelar ×
  validação), `pin-errado`, `expirado`, `rate-limit`, `erro-rede`, `recusa-dialog`,
  `finalizado`. Fluxo **interativo de verdade**: gerar → tela do PIN → digitar o PIN
  certo (8341) do lado do contratante → `finalizado` com cronômetro congelado + badge +
  timeline + snackbar; PIN errado 3× → expirado e volta a `ativo` com cronômetro
  retomando (o salto do display é visível — comportamento honesto do §4.6); recusa via
  dialog → `ativo`. Cronômetro tica de verdade no mock (mesmo mecanismo da 063).
- **Fidelidade:** tokens reais dos dois temas (DDR-001); JetBrains Mono com fallback;
  microcopy = §5 palavra por palavra; identificadores §7 como `data-testid`;
  horários 24h pt-BR.
- **Restrições:** HTML/CSS/JS vanilla, sem rede, mock inline, comentário "protótipo
  de validação".

### Checklist antes de marcar spec `ready`

- [x] Protótipo abre sem erro; todos os estados acessíveis nos dois papéis e viewports.
- [x] Ciclo completo ponta a ponta (gerar → PIN → validar → finalizado) + recusa +
      expiração com retomada do cronômetro.
- [x] Microcopy bate palavra por palavra com a §5.
- [x] Identificadores da §7 presentes.
- [x] Tokens reais; PIN em mono ≥64pt; cronômetro tabular ≥40px.
- [x] Protótipo apresentado ao humano e sinal de validação capturado (inclui o
      conflito de microcopy do §4.10 e as premissas do §4.12/§10).

---

## 10. Dependências e premissas

- **Endpoints (contrato — estória CA-2/CA-3/CA-5; formato fino é do Programador):**
  - `POST /api/turnos/{uuid}/gerar-pin-checkout` — espelho do gerar da 061
    (payload de geo idêntico) → `200 { pin, geofencing_check_out? }`. Única resposta
    com PIN em plaintext. Sem validação de janela (CA-1). 403 RBAC; 422 estado.
  - `POST /api/turnos/{uuid}/validar-checkout` com `{ pin }` (CA-3) →
    `200 { estado: 'finalizado' }`; 422 `pin_invalido` / `pin_expirado` (turno já
    voltou a `ativo`) / `estado_invalido` (recarrega silencioso); 429; 403.
  - **Recusa** (`{ motivo? }`) e **cancelamento**: endpoints a critério do Programador
    (espelhos da 062/061); ambos devolvem o turno a `ativo`.
- **Cronômetro (premissa da 063 §10, cumprida aqui):** em `aguardando_checkout` o
  payload do cronômetro expõe o instante da solicitação (derivável do
  `checkout_solicitado`) para a duração congelar idêntica nos dois lados; em
  `finalizado`, expõe `check_out_at` final (CA-3). Retorno a `ativo` (recusa/
  cancelamento/expiração) limpa o campo e o tick local retoma da âncora.
- **Rate limit:** mesmo mecanismo da 062 (5/60s por turno via env — espelho CA-4).
- **Timeline:** whitelist ganha os 4 eventos do §4.12.
- **Evento `TurnoFinalizado`** (CA-3) é contrato de domínio para 065/067 — sem
  superfície de UI aqui além do estado final.
- **Conflito de microcopy CA-6 × 063** (§4.10) — resolvido: vale o CA-6 da 064.
- Spec **não depende** de DDR pendente.

---

## 11. Histórico de mudanças

| Data | Mudança | Quem | Motivo |
|---|---|---|---|
| 2026-06-05 | criação (spec completo + protótipo v1) | claude-opus-4-8 (designer) | STORY-064; spec + protótipo entregues juntos para validação humana |
| 2026-06-05 | validação humana — aprovado sem ajustes | Alexandro | inclui premissas §4.12/§10 (eventos novos na whitelist; motivo só no audit log; expiração devolve a `ativo`) e arbitragem do conflito de microcopy §4.10: **vale o CA-6 da 064** ("Aguardando validação — duração"), mudança consciente na SCREEN-063; `status: ready` |
| 2026-06-05 | implementação + 2 ajustes conscientes | claude-opus-4-8 (programador) | (a) `finalizado` SEM placeholder de ações (regra da 060 §4.1 vence o protótipo v1 — §4.11); (b) polling do cronômetro que detecta transição que a tela não viu (ex.: contratante em `ativo` quando o PIN de check-out nasce) dispara reload — o bloco de validação aparece sem refresh manual; `dialog.confirm` promovido no DS (2º uso); `status: in_implementation` |
| 2026-06-06 | implementado + PO aprovou em homolog | claude-opus-4-8 / Alexandro | STORY-064 entregue (API núcleo 100% / suíte 879 testes 93,6%, webapp 508 testes, E2E ciclo completo bilateral, rc.76) e aprovada em chat após roteiro manual em 2 janelas; `status: shipped` |
