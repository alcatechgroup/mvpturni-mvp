---
id: SCREEN-STORY-061-pin-checkin
story: STORY-061-pin-checkin-geracao-geofencing
epic: EPIC-003-aceite-pin-e-pix
status: ready                # draft | ready | in_implementation | shipped | superseded
created_at: 2026-06-05
updated_at: 2026-06-05
owner_designer: claude-opus-4-8
related_ddrs: [DDR-001, DDR-002]
ds_components_used: [surface.card, badge.status, button.primary, banner, section.group-header, timeline.event]
exceptions_to_ds: [pin.display (PIN gigante em mono — 1º uso; candidato a promoção quando STORY-064 reusar no check-out), button.text (ação de baixa ênfase "Cancelar PIN" — 1º uso; roadmap do DS já previa button.secondary)]
viewports: [mobile, desktop]
prototype_path: SCREEN-STORY-061-pin-checkin/index.html
prototype_last_validated_at: 2026-06-05  # aprovado por Alexandro em chat (sem ajustes)
---

# Spec de tela — SCREEN-STORY-061 — Geração do PIN de check-in + geofencing

> Referência: estória `STORY-061`. CAs e contexto vêm de lá — **não duplico**.
> Esta entrega tem **duas superfícies**: (a) a **área de ações do detalhe do turno**
> (SCREEN-060 deixou a moldura pronta — primeiro botão real chega aqui) e (b) a
> **tela do PIN** (view dedicada de tela cheia, efêmera). Só o **profissional** vê
> qualquer uma das duas (CA-8); o contratante segue com o placeholder da 060 até a
> STORY-062 trazer a validação.
> Geofencing é **alerta-e-registra** (PDR-008): a captura de localização **nunca
> bloqueia** a geração — negada/timeout/erro seguem adiante e viram registro honesto.
> Locale pt-BR 24h (DDR-002). Princípios que dirigiram: **#1** (uma tarefa por tela —
> a tela do PIN tem literalmente um número), **#2** (profissional usa em pé, no balcão,
> com pressa), **#5** (PIN ≥64pt, contraste AAA, dígito a dígito no leitor de tela),
> **#7** (janela fechada, geo negada e erro são estados desenhados, não acidentes).

---

## Tema e perfil

Tudo nesta entrega é **tema do profissional** (acento `#2D5F3F`, DDR-001) — contratante
não tem superfície nova. Badge de estado continua semântico (SCREEN-059 §4.1).

---

## 1. Objetivo da tela

**Área de ações:** "cheguei ao local → gero o PIN" em um toque.
**Tela do PIN:** o contratante consegue ler o número do outro lado do balcão — nada
mais compete com isso.

---

## 2. Fluxo

### Entrada

- **Área de ações:** dentro do detalhe `/turnos/{id}` (SCREEN-060), papel profissional,
  turno `confirmado` (janela aberta ou não) ou `aguardando_checkin`.
- **Tela do PIN:** **somente** após resposta de geração bem-sucedida (push de view).
  **Não é endereçável por URL** — o PIN é efêmero (CA-4): refresh ou deep-link caem no
  detalhe em `aguardando_checkin` (§4.7), de onde o profissional gera um novo PIN.

### Ações possíveis

- **Gerar PIN de check-in** (`button.primary`, área de ações, `confirmado` + janela
  aberta): dispara captura de geolocalização (botão em loading "Confirmando sua
  localização…") → POST → tela do PIN. Geo negada/timeout **não interrompe** o fluxo.
- **Gerar novo PIN** (área de ações, `aguardando_checkin`): mesmo fluxo; o PIN
  anterior deixa de valer (CA-5 — idempotente).
- **Não chegou ainda? Cancelar PIN** (`button.text`, na tela do PIN **e** na área de
  ações em `aguardando_checkin`): volta o turno para `confirmado`; UI volta ao detalhe
  com o botão de gerar novamente visível.
- **Voltar** (AppBar da tela do PIN): retorna ao detalhe em `aguardando_checkin` —
  o PIN não é re-exibível (microcopy avisa antes: §5).

### Saída

- Sucesso da geração → tela do PIN.
- Cancelamento (sucesso) → detalhe em `confirmado` (badge e botão são o feedback).
- Erro recuperável (geração ou cancelamento) → banner com retry, estado não muda.
- Validação pelo contratante (STORY-062) → fora de escopo aqui; a tela do PIN ganhará
  detecção da transição para `ativo` na 062/063 (ver §10).

---

## 3. Layout

### 3.1. Área de ações no detalhe — mobile (≥360px)

Substitui o placeholder da 060 quando papel = profissional e estado permite.
Card `surface.card`, mesmo slot do layout da 060 (§3 de lá — nada muda de posição).

`confirmado`, janela aberta:

```
|  +------------------------------------+  |
|  | Chegou ao local?                   |  |  título (15px w700)
|  | Gere o PIN de check-in e mostre ao |  |  apoio (13.5px text.muted)
|  | contratante para confirmar sua     |  |
|  | chegada.                           |  |
|  | [    Gerar PIN de check-in     ]   |  |  button.primary, largura total, ≥48dp
|  +------------------------------------+  |
```

`confirmado`, antes da janela (botão desabilitado — CA-1):

```
|  | Ainda não dá para fazer o check-in |  |
|  | O PIN pode ser gerado a partir das |  |
|  | 17:30 (30 min antes do início).    |  |
|  | [    Gerar PIN de check-in     ]   |  |  disabled (opacidade 38%)
```

`confirmado`, depois da janela:

```
|  | O período de check-in encerrou     |  |
|  | O PIN podia ser gerado até as      |  |
|  | 20:00. Fale com o contratante se   |  |
|  | você está no local.                |  |
|  | [    Gerar PIN de check-in     ]   |  |  disabled
```

`aguardando_checkin` (pós-refresh / volta da tela do PIN — §4.7):

```
|  | Aguardando validação do contratante|  |
|  | Perdeu o PIN de vista? Gere um     |  |
|  | novo — o anterior deixa de valer.  |  |
|  | [       Gerar novo PIN         ]   |  |  button.primary
|  |  Não chegou ainda? Cancelar PIN    |  |  button.text (alvo ≥48dp)
```

### 3.2. Tela do PIN — mobile (≥360px)

Tela cheia, coluna única centrada verticalmente. O PIN é o herói; todo o resto é
secundário e pequeno.

```
+------------------------------------------+
| ←  PIN de check-in                       |  AppBar (voltar + título)
+------------------------------------------+
|                                          |
|   Garçom · Bar do Zé                     |  contexto (13px text.muted, 1 linha)
|                                          |
|   Mostre este PIN ao contratante         |  instrução (16px, text.strong)
|   para validar a chegada                 |
|                                          |
|              4 7 0 2                     |  pin.display: JetBrains Mono,
|                                          |  72px w600, letter-spacing largo,
|                                          |  text.strong sobre surface.page (15.7:1 AAA)
|   ✓ Localização confirmada — você        |  nota de geofencing (§4.5)
|     está no local.                       |
|                                          |
|   Se sair desta tela, será preciso       |  aviso de efemeridade (13px muted)
|   gerar um novo PIN.                     |
|                                          |
|   Não chegou ainda? Cancelar PIN         |  button.text, centrado, ≥48dp
|                                          |
+------------------------------------------+
```

- Dígitos com espaçamento generoso (`letter-spacing` ≈ 0.18em) — legibilidade a
  distância de balcão; **não** quebra linha.
- Sem brilho/animação no PIN (Princípio #3 — sério, não festivo). Entrada da tela com
  `motion.slow` padrão.

### 3.3. Desktop (≥1024px)

- **Área de ações:** idêntica, dentro da coluna esquerda da 060 (sem mudança de grid).
- **Tela do PIN:** mesmo conteúdo centrado em card `surface.card` max ~560px, PIN a
  96px (tem espaço; o caso de uso real é mobile, desktop é paridade). Marca `TURNI.`
  no topo como na 060.

```
+------------------------------------------------------------------+
|                            TURNI.                                |
|  ← PIN de check-in                                               |
|            +----------------------------------+                  |
|            |  Garçom · Bar do Zé              |                  |
|            |  Mostre este PIN ao contratante  |                  |
|            |  para validar a chegada          |                  |
|            |            4 7 0 2               |                  |
|            |  ✓ Localização confirmada — …    |                  |
|            |  Se sair desta tela, será        |                  |
|            |  preciso gerar um novo PIN.      |                  |
|            |  Não chegou ainda? Cancelar PIN  |                  |
|            +----------------------------------+                  |
+------------------------------------------------------------------+
```

### Tablet

Sem comportamento próprio — segue a regra da 060 (colapso do grid do detalhe);
a tela do PIN é coluna única em qualquer viewport.

---

## 4. Estados

### 4.1. Detalhe — `confirmado`, janela aberta

Botão habilitado (§3.1). A **única** chamada primária da tela do detalhe passa a ser
esta (a 060 não tinha nenhuma — segue valendo no máximo 1 por tela).

### 4.2. Detalhe — `confirmado`, antes da janela (CA-1)

Botão **desabilitado** + microcopy com o horário de abertura calculado
(`data_inicio − 30min`, default da janela — valor vem do backend/config, a UI só
formata). Não esconder o botão: affordance de que a ação existe e *quando* destrava.

### 4.3. Detalhe — `confirmado`, depois da janela (CA-1)

Botão desabilitado + microcopy com o horário de encerramento (`data_inicio + 2h`) e
próximo passo humano ("fale com o contratante"). O fluxo de `no_show` não é daqui.

### 4.4. Capturando localização + gerando (CA-2)

- Clique → botão entra em **loading** (spinner inline no lugar do label →
  "Confirmando sua localização…"), toque bloqueado, demais elementos inalterados.
- O prompt de permissão é do navegador — a tela não desenha prompt próprio.
- **Timeout de captura ~10s**: vencido, segue com `geo: null, razao: 'timeout'`
  (PDR-008 — nunca bloqueia). Negada → segue na hora com `razao: 'permissao_negada'`.
- Captura concluída (com ou sem geo) → POST. Sucesso → tela do PIN (§4.5).
  O loading cobre captura + request como **um gesto só** — o usuário não distingue
  fases.

### 4.5. Tela do PIN (sucesso) — variantes da nota de geofencing

Três variantes da nota abaixo do PIN (CA-2/CA-6 — registro honesto do que o
contratante vai ver):

| Resultado | Nota (ícone + texto) | Estilo |
|---|---|---|
| `geofencing_ok: true` | ✓ Localização confirmada — você está no local. | texto `success` ink (`#2D7A4F`), 14px |
| `ok: false` com distância | ⚠ Você está a cerca de {X} m do estabelecimento. O contratante verá esse aviso ao validar. | fundo `warning.soft`, texto `accent.ink` mostarda `#6E4E12` |
| sem geo (negada/timeout/erro) | ⚠ Sua localização não pôde ser confirmada ({razão}). O contratante verá esse aviso ao validar. | idem warning |

Razões em linguagem humana: `permissao_negada` → "permissão negada";
`timeout` → "tempo esgotado"; `erro_browser` → "erro do navegador".
Distância formatada: `< 1000 m` → "230 m"; `≥ 1000` → "1,2 km".

### 4.6. Erro na geração (rede/servidor)

Botão sai do loading e volta ao normal; `banner` de erro acima da área de ações
(padrão 047/059/060): "Não foi possível gerar o PIN. Verifique sua conexão.
[Tentar de novo]" — retry refaz o gesto completo (nova captura de geo; coordenada
velha não é reaproveitada). Estado do turno não mudou: botão segue habilitado.

### 4.7. Detalhe — `aguardando_checkin` (pós-refresh / volta)

Badge "● Aguardando check-in" (warning soft — SCREEN-059 §4.1). Área de ações vira
o bloco do §3.1: título + apoio + **Gerar novo PIN** (primário) + **Cancelar PIN**
(texto). Gerar novo repete §4.4→§4.5. **Contratante** neste estado segue vendo o
placeholder da 060 ("Nenhuma ação disponível no momento") — a 062 ocupa esse slot.

### 4.8. Cancelamento do PIN (CA-5)

- Na tela do PIN ou na área de ações: toque em "Não chegou ainda? Cancelar PIN" →
  botão de texto em loading (spinner inline) → sucesso → detalhe em `confirmado`
  (§4.1/4.2 conforme janela). Sem dialog de confirmação: ação reversível em um toque
  (gera de novo) — confirmação seria atrito sem proteção real.
- Erro: banner "Não foi possível cancelar o PIN. [Tentar de novo]" no contexto em que
  o toque ocorreu; estado não muda.

### 4.9. Sem permissão (RBAC — CA-8)

Contratante e admin **nunca veem** botão de gerar (o payload do detalhe já resolve
por papel); tentativa direta de API recebe 403 — sem superfície de UI para isso.
Profissional de **outro** turno cai no "Turno não encontrado" da 060 §4.5 (fail-secure).

### 4.10. Timeline — eventos desta estória (CA-7)

A 060 deixou `checkin_solicitado` com descrição vazia ("061 anexa nota de
geofencing"). Esta spec preenche — e adiciona o evento de cancelamento:

| Evento | Título | Descrição (ambos os papéis) |
|---|---|---|
| `checkin_solicitado` + geo ok | PIN de check-in gerado | Localização confirmada (a {X} m do estabelecimento). |
| `checkin_solicitado` + fora do raio | PIN de check-in gerado | Fora do raio do estabelecimento (a {X} m). |
| `checkin_solicitado` sem geo | PIN de check-in gerado | Localização não capturada ({razão}). |
| `checkin_cancelado` | PIN de check-in cancelado | Cancelado pelo profissional antes da validação. |

> **Nota ao PO/Programador:** `checkin_cancelado` é premissa desta spec — a transição
> `aguardando_checkin → confirmado` pelo profissional precisa de evento na trilha
> (ADR-015 registra transições). Se o nome do evento for outro, o mapa segue válido.

### Loading / vazio / parcial do detalhe

Inalterados — SCREEN-060 §4.2/4.6 (o skeleton da 060 já cobre o slot de ações).

---

## 5. Microcopy completo

Textos marcados (CA) são fixados pela estória — não alterar sem PO.

| Lugar | Texto |
|---|---|
| CTA gerar (CA-1) | Gerar PIN de check-in |
| CTA gerar novo | Gerar novo PIN |
| CTA gerar — loading | Confirmando sua localização… |
| Ações — título (janela aberta) | Chegou ao local? |
| Ações — apoio (janela aberta) | Gere o PIN de check-in e mostre ao contratante para confirmar sua chegada. |
| Ações — título (antes da janela) | Ainda não dá para fazer o check-in |
| Ações — apoio (antes da janela) | O PIN pode ser gerado a partir das {HH:mm} ({N} min antes do início). |
| Ações — título (depois da janela) | O período de check-in encerrou |
| Ações — apoio (depois da janela) | O PIN podia ser gerado até as {HH:mm}. Fale com o contratante se você está no local. |
| Ações — título (`aguardando_checkin`) | Aguardando validação do contratante |
| Ações — apoio (`aguardando_checkin`) | Perdeu o PIN de vista? Gere um novo — o anterior deixa de valer. |
| Cancelar (CA-5; tela do PIN e ações) | Não chegou ainda? Cancelar PIN |
| Tela do PIN — título (AppBar) | PIN de check-in |
| Tela do PIN — contexto | {Função} · {Estabelecimento} |
| Tela do PIN — instrução (CA-5) | Mostre este PIN ao contratante para validar a chegada |
| Nota geo — ok | ✓ Localização confirmada — você está no local. |
| Nota geo — fora do raio | ⚠ Você está a cerca de {X} do estabelecimento. O contratante verá esse aviso ao validar. |
| Nota geo — sem captura | ⚠ Sua localização não pôde ser confirmada ({razão}). O contratante verá esse aviso ao validar. |
| Razões | permissão negada · tempo esgotado · erro do navegador |
| Aviso de efemeridade | Se sair desta tela, será preciso gerar um novo PIN. |
| Erro ao gerar (banner) | Não foi possível gerar o PIN. Verifique sua conexão. |
| Erro ao cancelar (banner) | Não foi possível cancelar o PIN. |
| Retry | Tentar de novo |
| Badge `aguardando_checkin` | ● Aguardando check-in (SCREEN-059 §4.1) |
| Timeline | tabela §4.10 |

Horários 24h pt-BR (DDR-002): "17:30", nunca "5:30 PM". Distâncias "230 m" / "1,2 km".

---

## 6. Acessibilidade (notas específicas)

- **PIN**: `Semantics(label: 'PIN de check-in: 4, 7, 0, 2')` — dígito a dígito,
  nunca "quatro mil setecentos e dois". Visual `excludeSemantics` por baixo.
- **Contraste AAA no PIN (CA-5):** `text.strong #0F1B2D` / `surface.page #F7F4EC` =
  15.7:1 — passa AAA com folga (tokens §6.1). 72px ≫ texto grande.
- **Foco inicial da tela do PIN:** no título/instrução (não no Cancelar — evitar
  cancelamento acidental por duplo-toque de leitor de tela).
- **Nota de geofencing:** `Semantics(liveRegion: true)` — anunciada ao aparecer;
  warning nunca só por cor (ícone + texto, tokens §4).
- **Botão em loading:** anuncia "Confirmando sua localização" (`tooltip`/label
  atualizado); toque bloqueado mas foco preservado.
- **Botão desabilitado (janela):** a microcopy explicativa fica **fora** do botão
  (texto adjacente sempre legível por leitor — disabled some do foco em alguns
  leitores; a explicação não pode morar só nele).
- **Cancelar (button.text):** alvo ≥48dp apesar de visual leve.
- Alvos ≥48dp; foco visível (anel `accent`); `prefers-reduced-motion` respeitado.

---

## 7. Identificadores estáveis sugeridos para teste

| Elemento | Identificador lógico sugerido |
|---|---|
| Botão gerar PIN (área de ações) | `turno-pin-gerar-btn` |
| Botão gerar novo PIN | `turno-pin-regen-btn` |
| Microcopy da janela (antes/depois) | `turno-pin-janela-msg` |
| Cancelar PIN (área de ações) | `turno-pin-cancelar-btn` |
| Banner de erro (gerar/cancelar) | `turno-pin-erro-banner` |
| Retry do banner | `turno-pin-retry-btn` |
| Tela do PIN (raiz) | `pin-checkin-screen` |
| Código do PIN | `pin-checkin-codigo` |
| Instrução | `pin-checkin-instrucao` |
| Nota de geofencing | `pin-checkin-geo-nota` |
| Aviso de efemeridade | `pin-checkin-efemero-msg` |
| Cancelar PIN (tela do PIN) | `pin-checkin-cancelar-btn` |
| Voltar (AppBar tela do PIN) | `pin-checkin-voltar` |

> E2E (CA-9) ancora os 3 caminhos de geo em `pin-checkin-geo-nota` (texto distinto
> por variante) + `pin-checkin-codigo` (sempre presente — geo nunca bloqueia).

---

## 8. Exceções ao Design System

| O que diverge | Por quê | Vira DDR? |
|---|---|---|
| `pin.display` — número gigante em JetBrains Mono (72px mobile / 96px desktop, letter-spacing 0.18em, `text.strong`) | O DS já reservou a mono para "dados monoespaçados (PIN…)" (tokens §5.1) mas não há componente. É o coração do produto e **reaparece idêntico na STORY-064** (check-out) e como referência visual do input da 062. | **Candidato** — promover quando a 064 reusar. |
| `button.text` — ação de baixa ênfase ("Não chegou ainda? Cancelar PIN"); Flutter `TextButton` | `link.text` do DS é navegação, não ação; `button.secondary` está no roadmap e este é o 1º caso real. Visual: label `accent.ink`, sem borda, ≥48dp. | **Candidato** — promover como `button.text`/`button.secondary` no 2º uso. |
| `timeline.event` — **2º uso** (eventos `checkin_solicitado`/`checkin_cancelado`) | A 060 marcou promoção quando a 061 reusasse — reuso confirmado; promover no `components.md` na implementação. | Não — promoção já prevista. |

Nenhuma cor nova; warning/success vêm dos tokens semânticos auditados (§4/§6 do tokens.md).

---

## 9. Protótipo HTML fiel (validação humana)

- **Localização:** `SCREEN-STORY-061-pin-checkin/index.html`.
- **Cobertura:** seletor de **viewport** (mobile/desktop), **papel** (profissional /
  contratante — contratante prova o RBAC: área de ações segue placeholder da 060) e
  **estado**: `janela-aberta`, `antes-janela`, `depois-janela`, `aguardando-checkin`,
  `erro-geracao`, e a tela do PIN nas 3 variantes de geo (`pin-ok`, `pin-fora-raio`,
  `pin-sem-geo`). Seletor extra de **resultado da geolocalização** (concedida / fora
  do raio / negada / timeout) controla o que o clique em "Gerar PIN" simula —
  caminho feliz percorrível ponta a ponta: detalhe → loading (~1,2s simulado) →
  tela do PIN → cancelar → detalhe.
- **Fidelidade:** tokens reais (tema profissional), JetBrains Mono local/fallback
  mono do sistema; microcopy = §5 palavra por palavra; identificadores §7 como
  `data-testid`; horários 24h pt-BR.
- **Restrições:** HTML/CSS/JS vanilla, sem rede, mock inline, comentário "protótipo
  de validação".

### Checklist antes de marcar spec `ready`

- [x] Protótipo abre sem erro; todos os estados acessíveis nos dois viewports.
- [x] Caminho feliz ponta a ponta (gerar → PIN → cancelar → gerar de novo).
- [x] Microcopy bate palavra por palavra com a §5.
- [x] Identificadores da §7 presentes.
- [x] Tokens reais; PIN em mono ≥64pt (72px mobile / 96px desktop).
- [x] Protótipo apresentado ao humano e sinal de validação capturado (inclui a
      premissa do evento `checkin_cancelado` na trilha — §4.10).

---

## 10. Dependências e premissas

- **Endpoints (contrato — estória CA-2/CA-3/CA-5):**
  - `POST /api/turnos/{uuid}/gerar-pin-checkin` com
    `{ pin_solicitado: true, lat?, lng?, accuracy_m?, geo: null?, razao? }` →
    `200 { pin: '4702', geofencing_check_in: { ok, distancia_metros, capturado_em, razao? } }`.
    Única resposta com PIN em plaintext (CA-4). 422 fora da janela; 403 RBAC; 409 (?)
    estado inválido — formato fino é do Programador; a UI trata tudo ≠ 2xx como §4.6.
  - Cancelamento (`aguardando_checkin → confirmado`): endpoint a critério do
    Programador (ex.: `POST /api/turnos/{uuid}/cancelar-pin-checkin`); UI trata erro
    como §4.8.
  - Os horários da janela (abertura/encerramento) precisam chegar ao front
    (campos no payload do detalhe ou derivados de `data_inicio` + config exposta) —
    a UI **não** hardcoda 30min/2h.
- **Janela configurável via env** (CA-1) — default −30min/+2h; microcopy formata o
  que vier.
- **Captura de geo**: Geolocation API do navegador (ADR-017-b), timeout ~10s
  (decisão fina do Programador; UX assume "um gesto só" §4.4).
- **Tela do PIN não endereçável** — refresh cai no detalhe `aguardando_checkin`
  (§4.7). A detecção em tempo real da validação pelo contratante (tela do PIN →
  `ativo`) chega com STORY-062/063 (polling ADR-017-a); até lá a tela do PIN é
  estática após a geração.
- **Contratante em `aguardando_checkin`**: mantém placeholder da 060 até a 062.
- Spec **não depende** de DDR pendente.

---

## 11. Histórico de mudanças

| Data | Mudança | Quem | Motivo |
|---|---|---|---|
| 2026-06-05 | criação (spec completo + protótipo v1) | claude-opus-4-8 (designer) | STORY-061; spec + protótipo entregues juntos para validação humana |
| 2026-06-05 | validação humana — aprovado sem ajustes | Alexandro | inclui nota honesta de geofencing na tela do PIN, cancelamento sem dialog e premissa `checkin_cancelado` (§4.10); `status: ready` |
