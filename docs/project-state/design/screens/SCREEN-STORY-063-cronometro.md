---
id: SCREEN-STORY-063-cronometro
story: STORY-063-cronometro-bilateral-tempo-real
epic: EPIC-003-aceite-pin-e-pix
status: shipped              # draft | ready | in_implementation | shipped | superseded
created_at: 2026-06-05
updated_at: 2026-06-05
owner_designer: claude-opus-4-8
related_ddrs: [DDR-001, DDR-002]
ds_components_used: [surface.card, badge.status, banner, button.text]
exceptions_to_ds: [cronometro.display (display de tempo vivo em mono tabular gigante — 1º uso; parente visual do pin.display da 061/input.pin da 062: a família "número grande em mono" vira candidata a grupo no DS)]
viewports: [mobile, desktop]
prototype_path: SCREEN-STORY-063-cronometro/index.html
prototype_last_validated_at: 2026-06-05  # aprovado por Alexandro em chat (sem ajustes)
---

# Spec de tela — SCREEN-STORY-063 — Cronômetro bilateral vivo

> Referência: estória `STORY-063`. CAs e contexto vêm de lá — **não duplico**.
> Esta entrega é **um componente** no detalhe do turno (`/turnos/{id}`, SCREEN-060),
> visível para **os dois papéis** quando o estado é `ativo` (rodando) ou
> `aguardando_checkout` (congelado — CA-5). Mecanismo fixado por **ADR-017**: âncora
> de timestamp + tick local 1s + polling ~5s — o servidor é a única fonte de verdade
> do tempo (CA-4); a UI **nunca** conta tempo por conta própria. Locale pt-BR 24h
> (DDR-002). Princípios que dirigiram: **#1** (em `ativo` a pergunta do usuário é
> "quanto tempo já foi?" — o tempo é a resposta, em destaque máximo), **#3** (vivo
> sem festa: número grande, zero confete), **#6** (tick local = zero latência
> percebida; reconexão não congela o display), **#7** (sincronizando, reconectando,
> congelado e erro são estados desenhados).

---

## Tema e papel

Mesmo componente para os dois lados — muda só o **tema do papel** (DDR-001:
profissional verde-sage `#2D5F3F`, contratante mostarda `#9A6E25`, dot de "vivo" no
acento). O número em si fica em `text.strong` nos dois temas: o tempo é informação
neutra, não identidade. Badge "● Em andamento" do header é o da SCREEN-059 §4.1
(componente registrado — nada muda).

---

## 1. Objetivo do componente

Responder, num olhar e **idêntico nos dois lados**: **"há quanto tempo este turno
está rodando?"** — mais o contexto fixo (início previsto, duração prevista) que evita
a disputa de percepção antes do check-out ("achei que era menos tempo").

---

## 2. Fluxo

### Entrada

- Detalhe `/turnos/{id}` (SCREEN-060), qualquer papel, turno `ativo` →
  o **card do cronômetro** entra **logo abaixo do header** (acima do card de valor):
  em `ativo` o tempo é a informação mais quente da tela. A área de ações continua
  com o placeholder da 060 (o botão de check-out é a STORY-064).
- Turno `aguardando_checkout` (STORY-064 cria a transição) → mesmo card, **congelado**
  (§4.4). O componente já nasce pronto para esse estado.
- Ao montar, o componente busca a âncora (`GET /turnos/{id}/cronometro` — ADR-017),
  passa a ticar **localmente** a cada 1s e reconcilia por polling (~5s, janela
  configurável pelo servidor).

### Ações possíveis

- **Nenhuma ação primária** — o cronômetro é leitura pura. Única interação: o retry
  do estado de erro da primeira sincronização (§4.5).

### Saída

- Polling detecta estado fora de {`ativo`, `aguardando_checkout`} (ex.: `finalizado`,
  064+) → o componente pede à tela o **reload da verdade** (mesmo padrão da 061/062:
  o servidor manda; badge/timeline/ações se reorganizam).
- Navegação normal da 060 — o componente cancela timers ao sair (sem polling fantasma).

---

## 3. Layout

### 3.1. Card do cronômetro — mobile (≥360px), turno `ativo`

Entre o header e o card de valor (coluna do turno da 060 — nada mais muda de posição):

```
|  +------------------------------------+  |
|  | ● TURNO EM ANDAMENTO               |  |  título 13px w700 uppercase muted;
|  |                                    |  |  dot no acento do papel, pulso sutil
|  |            02:35:41                |  |  cronometro.display: JetBrains Mono
|  |                                    |  |  40px w600 tabular, centrado, strong
|  | Início previsto: 18:00             |  |  apoio 13.5px text.muted, centrado
|  | Duração prevista: 5h               |  |
|  +------------------------------------+  |
```

- **Display**: JetBrains Mono (mesma família do `pin.display`), **tabular figures**
  (o número não "treme" a cada segundo), 40px mobile / 48px desktop, `text.strong`.
- **Formato** (CA-2): `HH:MM:SS` quando a **duração prevista** (`data_fim −
  data_inicio`) é ≥ 1h; `MM:SS` para turnos curtos. Se o decorrido **cruzar 1h**,
  promove para `HH:MM:SS` e não regride (nunca exibir "75:30").
- **Apoio** (CA-2, microcopy fixa): "Início previsto: {HH:MM}" e "Duração prevista:
  {Xh}" — hora local 24h (DDR-002); duração no formato do `TurniDateTime.formatDuracao`
  ("5h", "5h30", "45min"). Duas linhas no mobile; uma linha com separador "·" quando
  couber (desktop).

### 3.2. Desktop (≥1024px)

Mesma posição dentro da coluna esquerda da 060 (sem mudança de grid). Display a 48px.
Nenhum comportamento exclusivo de viewport.

### Tablet

Sem comportamento próprio — segue o colapso do grid da 060.

---

## 4. Estados

### 4.1. Sincronizando (primeira âncora ainda não chegou)

Card presente com display `--:--:--` (ou `--:--` em turno curto) e as linhas de apoio
já preenchidas (vêm do payload do detalhe, que já chegou). Sem spinner — a latência
típica é sub-segundo e o placeholder mono mantém a silhueta estável (#6).

### 4.2. Rodando (`ativo`, sincronizado)

Display ticando a cada 1s (tick **local** — sem rede por tique; ADR-017). Dot do
título com pulso sutil (escala/opacidade, ciclo ~2s, desligado em
`prefers-reduced-motion` — o tick dos segundos já comunica "vivo").

### 4.3. Reconectando (CA-6 — sem reconciliação > 30s)

Falha de polling por < 30s: **silêncio absoluto** — o tick local segue (a âncora não
muda) e o próximo ciclo reconcilia. A partir de 30s sem sucesso, entra uma linha
discreta de aviso **abaixo do apoio**, dentro do card:

```
|  | ⟳ Reconectando… O tempo continua    |  |  13.5px, warning.ink, ícone + texto
|  |   valendo.                          |  |  (nunca só cor)
```

O display **não congela nem esmaece** — servidor é a fonte de verdade e a âncora
local continua válida; congelar mentiria mais que ticar. Quando um polling volta a
ter sucesso, a linha some e o offset se corrige (um ajuste ≤ 1s pode ser perceptível
no display — aceito, é a verdade chegando).

### 4.4. Aguardando check-out (CA-5 — estado `aguardando_checkout`)

Polling deixa de rodar (o estado não é mais `ativo`); display **congelado** na
duração final; título e apoio trocam:

```
|  +------------------------------------+  |
|  | AGUARDANDO CHECK-OUT               |  |  título sem dot (não está mais "vivo")
|  |                                    |  |
|  |            05:02:13                |  |  congelado (encerrado_em − iniciado_em)
|  |                                    |  |
|  | Aguardando check-out — duração     |  |  microcopy fixa do CA-5
|  | final: 05:02:13                    |  |
|  +------------------------------------+  |
```

A duração final vem do servidor (`encerrado_em`); enquanto a 064 não expõe o
timestamp da transição, o display congela no último valor reconciliado (premissa
§10). Badge do header segue a SCREEN-059 (estado `aguardando_checkout`).

### 4.5. Erro na primeira sincronização

A âncora nunca chegou (rede caiu antes do primeiro fetch): no lugar do display,
banner inline no card — "Não foi possível carregar o cronômetro. Verifique sua
conexão. [Tentar de novo]" (padrão de erro recuperável da 047/059/060). O retry
refaz a sincronização. O resto da tela (060) segue intacto — o cronômetro nunca
quebra o detalhe.

### 4.6. RBAC e demais estados

- O card só existe em `ativo` e `aguardando_checkout` — nos demais estados a 060/061/062
  mandam (nenhuma regressão).
- Terceiros nem chegam aqui (detalhe é fail-secure — SCREEN-060 §4.5). O endpoint do
  cronômetro responde 404 para não-partes (ADR-017); se acontecer no meio da sessão
  (turno trocou de dono — impossível hoje), o componente se esconde.
- Aba em background: polling pausa (`visibilitychange` — ADR-017); ao voltar, primeiro
  ciclo reconcilia e o display salta para a verdade (correto por construção).

### 4.7. Timeline — eventos desta estória

Nenhum evento novo: o cronômetro não cria fatos de domínio (o `checkin_validado` da
062 já marca o início; o check-out é a 064). A timeline da 060 segue inalterada.

---

## 5. Microcopy completo

Textos marcados (CA) são fixados pela estória — não alterar sem PO.

| Lugar | Texto |
|---|---|
| Título (rodando) | Turno em andamento |
| Display sincronizando | --:--:-- (ou --:-- em turno curto) |
| Apoio — início (CA-2) | Início previsto: {HH:MM} |
| Apoio — duração (CA-2) | Duração prevista: {Xh} |
| Reconectando (CA-6) | Reconectando… O tempo continua valendo. |
| Título (congelado) | Aguardando check-out |
| Linha congelado (CA-5) | Aguardando check-out — duração final: {HH:MM:SS} |
| Erro 1ª sincronização | Não foi possível carregar o cronômetro. Verifique sua conexão. |
| Retry | Tentar de novo |

Horas locais 24h pt-BR (DDR-002). Duração prevista "5h" / "5h30" / "45min"
(`TurniDateTime.formatDuracao`). Tempo decorrido `HH:MM:SS` / `MM:SS` (§3.1).

---

## 6. Acessibilidade (notas específicas)

- **Display**: `liveRegion: false` **obrigatório** — anunciar a cada segundo é
  tortura de leitor de tela. Nó `Semantics` único: "Tempo decorrido: {H} horas, {M}
  minutos" (label estável, sem segundos); o número visual tica, a semântica atualiza
  por minuto.
- **Linha "Reconectando…"**: `Semantics(liveRegion: true)` — anunciada ao aparecer
  (uma vez), ícone + texto, nunca só cor.
- **Transição para congelado (§4.4)**: a linha do CA-5 é `liveRegion: true` —
  o usuário de leitor fica sabendo que o turno parou de contar.
- **Dot pulsante**: decorativo (`excludeSemantics`); pulso desligado em
  `prefers-reduced-motion` (o tick textual permanece).
- **Erro/retry**: `liveRegion: true`; retry por teclado, foco visível, alvo ≥48dp.
- **Contraste**: display `text.strong` sobre `surface` (≥ 12:1 ✅); apoio `text.muted`
  auditado AA; warning.ink sobre surface ✅ (tokens §6).

---

## 7. Identificadores estáveis sugeridos para teste

| Elemento | Identificador lógico sugerido |
|---|---|
| Card do cronômetro | `cronometro-card` |
| Display do tempo | `cronometro-display` |
| Linha de apoio (início/duração prevista) | `cronometro-previsto` |
| Linha "Reconectando…" | `cronometro-reconectando` |
| Linha congelado (CA-5) | `cronometro-aguardando-checkout` |
| Erro da 1ª sincronização | `cronometro-erro` |
| Retry | `cronometro-retry-btn` |

> E2E (CA-3) ancora: `cronometro-display` nos **dois papéis** sobre o **mesmo turno**
> `ativo`, comparando o valor exibido com a âncora do servidor (tolerância que prova
> a sincronia ≤ 2s por transitividade). CA-5/CA-6 ancoram nas linhas dedicadas.

---

## 8. Exceções ao Design System

| O que diverge | Por quê | Vira DDR? |
|---|---|---|
| `cronometro.display` — tempo vivo em JetBrains Mono 40px (48px desktop), tabular figures, centrado | O DS não tem display de dado vivo; é o coração do CA-2. 3º membro da família "número grande em mono" (pin.display 061, input.pin 062) — a família merece registro de grupo no `components.md` nesta implementação (1 padrão, 3 usos). | Não — registro de componente no DS (promoção da família mono), sem decisão transversal nova. |

Nenhuma cor nova; dot/pulso usam o acento do papel e warning vem dos tokens
semânticos auditados.

---

## 9. Protótipo HTML fiel (validação humana)

- **Localização:** `SCREEN-STORY-063-cronometro/index.html`.
- **Cobertura:** seletor de **papel** (profissional/contratante), **viewport**
  (mobile/desktop) e **estado**: `rodando` (tick real de 1s no mock), `turno-curto`
  (formato MM:SS), `sincronizando`, `reconectando` (entra após simulação de queda),
  `aguardando-checkout` (congelado, CA-5), `erro-sync` (com retry). Modo extra
  **"bilateral"** (desktop): dois frames lado a lado — profissional e contratante —
  ticando ancorados no mesmo `iniciado_em`, demonstrando a sincronia ≤ 2s que o CA-3
  exige (os dois mostram o mesmo número, sempre).
- **Fidelidade:** tokens reais dos dois temas; microcopy = §5 palavra por palavra;
  identificadores §7 como `data-testid`; tick de verdade via `setInterval` local
  (espelha o mecanismo da ADR-017: âncora fixa + derivação).
- **Restrições:** HTML/CSS/JS vanilla, sem rede, mock inline, comentário "protótipo
  de validação".

### Checklist antes de marcar spec `ready`

- [x] Protótipo abre sem erro; todos os estados acessíveis nos dois papéis e viewports.
- [x] Cronômetro tica de verdade no mock; modo bilateral mostra os dois lados idênticos.
- [x] Microcopy bate palavra por palavra com a §5.
- [x] Identificadores da §7 presentes.
- [x] Tokens reais; display mono tabular ≥40px.
- [x] Protótipo apresentado ao humano e sinal de validação capturado (inclui as
      premissas §10 — posição do card, formato MM:SS/HH:MM:SS, comportamento de
      reconexão sem congelar).

---

## 10. Dependências e premissas

- **Endpoint (ADR-017 — já existe da PoC da STORY-057):**
  `GET /api/turnos/{uuid}/cronometro` → `{ estado, iniciado_em, encerrado_em?,
  servidor_agora }`, RBAC bilateral (404 para terceiros). A 063 acrescenta ao payload
  a **janela de polling** (`polling_segundos`, config do servidor — CA-1
  "configurável") — premissa, formato fino é do Programador.
- **Início/duração prevista** vêm do payload do detalhe (`data_inicio`/`data_fim` —
  060), não do endpoint do cronômetro.
- **`encerrado_em` em `aguardando_checkout`** (§4.4): o modelo carimba `check_out_at`
  só na transição → `finalizado` (ADR-015). Premissa para a **STORY-064**: ao criar a
  transição `ativo → aguardando_checkout`, expor o instante da solicitação no payload
  do cronômetro (derivável do evento `checkout_solicitado` do audit log) para a
  duração final congelar **idêntica nos dois lados**. Até lá, o componente congela no
  último valor reconciliado (estado inalcançável em produção antes da 064).
- **Reconexão** (CA-6): backoff e contagem dos 30s são do Programador; o spec fixa
  só o comportamento visível (silêncio < 30s; linha discreta ≥ 30s; display nunca
  congela em `ativo`).
- Spec **não depende** de DDR pendente.

---

## 11. Histórico de mudanças

| Data | Mudança | Quem | Motivo |
|---|---|---|---|
| 2026-06-05 | criação (spec completo + protótipo v1) | claude-opus-4-8 (designer) | STORY-063; spec + protótipo entregues juntos para validação humana |
| 2026-06-05 | validação humana — aprovado sem ajustes | Alexandro | inclui posição do card (abaixo do header), formato MM:SS/HH:MM:SS, reconexão sem congelar o display; PO também aprovou amostragem de ~60s (≥10 amostras) no E2E do CA-3 em vez de 5min literais; `status: ready` |
| 2026-06-05 | implementação | claude-opus-4-8 (programador) | `status: in_implementation` |
| 2026-06-05 | implementado + PO aprovou em homolog | claude-opus-4-8 / Alexandro | STORY-063 entregue (núcleo 100% / card 94,2% / controller 100%, webapp 490 testes, E2E bilateral ≥12 amostras ≤2s, carga 50 turnos, rc.75) e aprovada em chat após verificação em 2 navegadores; `mono.display` registrado no DS; `status: shipped` |
