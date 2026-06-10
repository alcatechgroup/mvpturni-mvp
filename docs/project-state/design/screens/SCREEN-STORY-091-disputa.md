---
id: SCREEN-STORY-091-disputa
story: STORY-091-spike-designer-telas-recusa-banner-caso-disputa
epic: EPIC-005-disputa-minima
status: ready                # draft | ready | in_implementation | shipped | superseded
created_at: 2026-06-10
updated_at: 2026-06-10
owner_designer: claude-opus-4-8
related_ddrs: [DDR-005, DDR-001, DDR-002, DDR-003]
related_adrs: [ADR-020]
ds_components_used: [button.primary, button.text, dialog.confirm, banner.status, badge.status, timeline.event, surface.card, section.group-header, sidebar.admin, data-table, panel, chip, stat-card, drawer-detail, dialog-confirm, btn.primary, btn.outline, toast]
exceptions_to_ds: [pattern.intent-disambiguation (novo — folha de escolha de intenção, registrado em patterns.md), banner.status (novo — banner persistente read-only, registrado em components.md), dialog.confirm variante campo-obrigatório (extensão, components.md)]
viewports: [mobile, desktop]   # contratante/profissional: paridade; admin: desktop-first (PDR-003)
prototype_path: SCREEN-STORY-091-disputa/index.html
prototype_last_validated_at: 2026-06-10   # aprovado por Alexandro em chat ("aprovado")
---

# Spec de tela — SCREEN-STORY-091 — Disputa de check-out (3 superfícies)

> Referência: estória `STORY-091`. CAs e contexto vêm de lá — **não duplico**.
> Decisões de design em **DDR-005** (entrada única que desambigua a recusa · profissional read-only sem justificativa · caso do admin com nota obrigatória). Modelo/transições em **ADR-020**.
> Esta spike cobre **três superfícies** em **duas plataformas**:
> (1) **Contratante** — recusa + abertura de disputa no check-out (WebApp **Flutter**, mobile+desktop);
> (2) **Profissional** — banner read-only de disputa no detalhe do turno (WebApp **Flutter**, mobile+desktop);
> (3) **Admin** — fila `/disputas` + caso + "resolver: pagar integral" (Backoffice **Laravel/Livewire**, desktop-first PDR-003).
> Locale/horário: DDR-002 (pt-BR, 24h). Princípios que dirigiram: **#1** (uma chamada primária por tela; recusa é secundário, disputa é o ramo pesado de recusar) · **#3** (tom profissional, sem alarmismo) · **#5** (estado nunca só por cor; foco/teclado nos formulários) · **#7** (vazio/erro/irreversível/race desenhados).

---

## Tema e papéis

- **Contratante** (Flutter): acento **mostarda** — `accent` `#9A6E25` (4.5:1 ✅), `accent.ink` `#6E4E12` (7.6:1 ✅), `accent.soft` `#FBEED1`.
- **Profissional** (Flutter): acento **verde-sage** — `accent` `#2D5F3F` (7.4:1 ✅).
- **Admin** (Backoffice): perfil **azul-navy** — `accent` `#2A4D8F` (8.2:1 ✅), shell idêntico ao `preview-backoffice.html`.
- **Estado/feedback usa cor semântica, não de perfil:** disputa = `error` (selo/banner `error soft`); SLA = `success`/`warning`/`error`; cor **nunca** é o único canal (ícone + texto + borda — tokens §4).

---

## 1. Objetivo (por superfície)

- **Contratante:** decidir o check-out em um olhar — **validar** (caminho feliz, um toque) ou, quando não vai validar, **declarar a intenção** e, se for por mérito, **abrir disputa** com justificativa, ciente de que é irreversível.
- **Profissional:** saber, sem ambiguidade, que o turno está **em disputa** e que há um processo com prazo — sem ação a tomar.
- **Admin:** ver a fila de disputas com urgência vs SLA, abrir um caso, ler a **trilha completa** e **resolver: pagar integral** com nota registrada.

---

## 2. Fluxo

### 2.1. Contratante — recusar / abrir disputa (estende SCREEN-064)

**Entrada:** detalhe `/turnos/{id}`, papel contratante, turno `aguardando_checkout` — o bloco de validação do check-out (SCREEN-064 §3.3).

**Ações:**
- **Validar check-out** (`button.primary`) — inalterado (SCREEN-064): `finalizado`.
- **"Não vai validar agora? Recusar check-out"** (`button.text`) — **muda em relação à 064**: não vai mais direto ao `dialog.confirm` de recusa→ativo; abre a **folha de desambiguação** (`pattern.intent-disambiguation`).
  - **Folha — escolha de intenção:** dois rádios + "Continuar":
    - `○ O turno ainda não terminou` → ao continuar, `recusar()` → turno volta a `ativo`, cronômetro retoma (comportamento da 064; motivo opcional).
    - `○ Tenho um problema com este turno` → ao continuar, abre o **diálogo de disputa**.
  - **Diálogo de disputa** (`dialog.confirm`, variante campo-obrigatório): justificativa **obrigatória** + aviso de irreversibilidade → `Abrir disputa` (desabilitado até ter texto) → `AbrirDisputaService` → `em_disputa`.

**Saída:**
- Validar → `finalizado` (SCREEN-064 §4.11).
- "Ainda não terminou" → `ativo` (cronômetro retoma — SCREEN-064 §4.6).
- "Abrir disputa" confirmada → detalhe em `em_disputa`: selo `⚠ Em disputa`, área de ações vazia (estado read-only para o contratante também — só aguarda mediação), timeline ganha "Disputa aberta", snackbar "Disputa aberta — a equipe Turni vai mediar."
- Cancelar/Voltar em qualquer etapa → volta ao bloco de validação, nada muda.

### 2.2. Profissional — banner de disputa (estende SCREEN-060)

**Entrada:** detalhe `/turnos/{id}`, papel profissional, turno `em_disputa` (chega da notificação in-app/e-mail — STORY-067/ADR-020 — ou da lista 059, seção "Em disputa").
**Ações:** **nenhuma** (read-only). "Voltar" e "Ver aceite eletrônico" seguem da 060.
**Saída:** quando o admin resolve `paga_integral`, o turno vira `finalizado` (a tela recarrega via polling existente da 060/064 → banner some, vira estado finalizado + Pix da 065).

### 2.3. Admin — fila e caso (Backoffice)

**Entrada:** item **"Disputas"** na sidebar do Backoffice (rota `/disputas`), abaixo de "Cadastros pendentes". Pré: sessão `web` + `role=admin` (`AdminOnly`).
**Ações:** abrir um caso (**Ver caso** → drawer); dentro do caso, **Resolver: pagar integral** (`dialog.confirm` com nota obrigatória); fechar o drawer.
**Saída:** após resolver → drawer fecha → toast "Disputa resolvida — pagamento integral liberado." → item sai da fila → contador cai. Race (outro admin já resolveu) → toast de erro + lista atualiza.

---

## 3. Layout

### 3.1. Contratante — folha de desambiguação (mobile ≥360px)

A entrada "Recusar check-out" vive no bloco de validação (SCREEN-064 §3.3, inalterado acima dela). Ao tocá-la:

```
  (bottom-sheet modal, radius.xl no topo)
+------------------------------------------+
| Por que não vai validar?                 |  título (titleMedium)
|                                          |
| ○ O turno ainda não terminou             |  RadioListTile
|   Volta para “Em andamento”. O tempo     |  descrição (14px text.muted)
|   continua contando e o profissional     |
|   gera um novo PIN.                      |
|                                          |
| ○ Tenho um problema com este turno       |  RadioListTile
|   Abre uma disputa: a equipe Turni media |
|   em até 30 minutos. Esta ação é         |
|   irreversível.                          |
|                                          |
|            [ Voltar ]   [ Continuar ]    |  Continuar disabled até escolher
+------------------------------------------+
```

### 3.2. Contratante — diálogo de disputa (mobile, ramo "tenho um problema")

`dialog.confirm`, variante **campo obrigatório** (espelha a anatomia da recusa da 064, mas justificativa é obrigatória):

```
+------------------------------------------+
| Abrir disputa deste turno?               |  título-pergunta
|                                          |
| O turno fica em disputa e a equipe Turni |  corpo (14px text.muted)
| vai mediar em até 30 minutos. O valor    |
| continua reservado até a decisão. Esta   |
| ação é irreversível.                     |
|                                          |
| O que aconteceu? (obrigatório)           |  label
| ┌──────────────────────────────────────┐|  textarea (≤280)
| │ Descreva o problema com o turno…      │|
| └──────────────────────────────────────┘|
|   ⚠ Conte o que aconteceu para abrir.    |  errorText quando vazio
|              [ Voltar ] [ Abrir disputa ]|  destrutiva; disabled até ter texto
+------------------------------------------+
```

### 3.3. Profissional — banner de disputa (mobile, no detalhe do turno)

No topo da área de conteúdo do detalhe (SCREEN-060), acima do card de estado/valor, em `em_disputa`:

```
+------------------------------------------+
| ←  Detalhe do turno                      |
+------------------------------------------+
| ┌──────────────────────────────────────┐|  banner.status (error soft)
| │ ⚠ Valor em disputa                     │|  título (15px w700)
| │ O contratante contestou o check-out.   │|  corpo (14px text.muted)
| │ A equipe Turni vai mediar em até 30    │|
| │ minutos e avisaremos você do desfecho. │|
| └──────────────────────────────────────┘|
| ┌──────────────────────────────────────┐|  card de estado (060)
| │ ⚠ Em disputa                           │|  badge.status (error soft)
| │ Garçom · Bar do Zé                     │|
| │ Sex, 12/06 · 18:00–23:00               │|
| └──────────────────────────────────────┘|
|  (card de valor — “Você recebe …”)       |  060, inalterado
|  (sem área de ações — read-only)         |  060 §4.1 oculta ação em não-terminal? ver nota
| HISTÓRICO                                |
|  ●  Disputa aberta                       |  timeline (novo evento)
|  │  O contratante contestou o check-out. |
|  │  Sex, 12/06 · 23:14                   |
|  ●  Check-out solicitado …               |
+------------------------------------------+
```

> **Nota à 060:** em `em_disputa` (estado **não-terminal**) a 060 §4.1 mostraria o placeholder "Nenhuma ação disponível no momento". Para o profissional em disputa isso é redundante com o banner — **a área de ações é omitida** quando o `banner.status` de disputa está presente (o banner já diz "não há o que fazer, aguarde"). Ajuste consciente sobre a 060, registrado no §11.

### 3.4. Admin — fila `/disputas` (desktop ≥1024px, primário)

Shell idêntico ao `preview-backoffice.html`: sidebar navy + main. Novo item de sidebar "Disputas" com badge de contagem.

```
+-----------+-------------------------------------------------------------+
| TURNI.    | Backoffice · Admin                                          |
| Backoffice| Disputas                                                    |
|           | 2 em aberto · SLA público de 30 min                         |
| [av] Admin|                                                             |
|           | [Em aberto 2][⚠ 1 com SLA estourado]   (stat-cards)         |
| OPERAÇÃO  |                                                             |
| ▸ Visão   | ⚠ 1 disputa há mais de 30 min — priorize.                   |  feedback-banner
| ▸ Penden. | +---------------------------------------------------------+ |
| ● Dispu.2 | | Fila de disputas                                        | |
|           | +---------------------------------------------------------+ |
| CADASTRO  | | Partes / função     Valor      Aberta há      →        | |
| ▸ Profis. | | Bar do Zé ⇄ Carlos   R$ 230,00  🔴 há 42 min  Ver caso | |
| ▸ Contrat.| | Garçom                                                   | |
| ▸ Config. | | Hotel Aurora ⇄ Ana   R$ 264,00  🟡 há 18 min  Ver caso | |
| [Sair]    | | Cozinheira                                               | |
|           | +---------------------------------------------------------+ |
+-----------+-------------------------------------------------------------+
```

- Componentes: `sidebar.admin`, `stat-card` (em aberto / com SLA estourado), `feedback-banner` (alerta SLA, só se houver > 30 min), `panel` + `data-table`, `chip` (SLA), `btn.outline` ("Ver caso").
- **SLA por item:** ícone + cor + texto — 🟢 `≤ 15 min` (success) · 🟡 `15–30 min` (warning) · 🔴 `> 30 min` (error, "estourado"). Derivado de `disputa.aberta_em`.

### 3.5. Admin — caso (drawer lateral ~640px, desktop)

```
                +----------------------------------------------+
                | Caso de disputa                         [✕]  |
                +----------------------------------------------+
                | Bar do Zé  ⇄  Carlos H. Silva                |
                | Garçom · R$ 230,00 · 🔴 há 42 min (SLA 30)   |
                +----------------------------------------------+
                | JUSTIFICATIVA DO CONTRATANTE                 |  section.group-header
                | “O profissional saiu 40 min antes do fim     |  destaque (surface.sunken)
                |  combinado e não terminou a limpeza.”        |
                +----------------------------------------------+
                | TRILHA DO TURNO                              |  section.group-header
                | ●  Disputa aberta · 23:14                    |  timeline.event
                | │  Contratante contestou o check-out.        |
                | ●  Check-out solicitado · 23:10              |
                | │  Geofencing: a 12 m do estabelecimento.    |
                | ●  Cronômetro encerrado · duração 04:58:00   |
                | ●  Checklist: 6/8 itens concluídos       ⌄   |  expansível
                | ●  Chat (4 mensagens)                    ⌄   |  expansível
                | ●  Check-in validado · 18:02                 |
                | ●  Vaga original                         ↗   |  link p/ snapshot
                | ●  Turno confirmado · 03/06 15:46            |
                +----------------------------------------------+
                | [ Resolver: pagar integral ]   (sucesso)     |  btn.primary
                +----------------------------------------------+
```

- A **justificativa** vem primeiro e em destaque — é a peça que motiva a decisão. A **trilha** reusa `timeline.event` (mesma anatomia da 060); blocos densos (chat, checklist) são **expansíveis** para não inflar o drawer. **Vaga original** abre o snapshot (link/modal de leitura).
- Única ação real: **Resolver: pagar integral** (não há "parcial"/"não pagar" no MVP — DDR-005/ADR-020).

### 3.6. Admin — diálogo "Resolver: pagar integral"

```
+------------------------------------------+
| Resolver: pagar integral?                |
|                                          |
| Captura o valor e libera o Pix ao        |
| profissional. O turno será finalizado.   |
| Esta ação é irreversível.                |
|                                          |
| Nota da decisão (obrigatória)            |  label
| ┌──────────────────────────────────────┐|  textarea
| │                                      │|
| └──────────────────────────────────────┘|
|   ⚠ Descreva o motivo da decisão.        |  erro quando vazio
|            [ Voltar ] [ Pagar integral ] |  confirmar disabled até ter texto
+------------------------------------------+
```

### 3.7. Desktop / paridade

- **Contratante/Profissional (Flutter):** a folha de desambiguação vira **`AlertDialog` central** (~480px) no desktop (em vez de bottom-sheet); o diálogo de disputa idem. O banner do profissional ocupa a largura da coluna de conteúdo da 060. Tablet: colapso do grid da 060, sem comportamento próprio.
- **Admin (Backoffice):** **desktop-first** (PDR-003). Abaixo de 1024px, aviso "Backoffice é desktop-first" + tabela colapsa em cards + drawer full-screen (espelho da 019 §3 — não quebra, mas o uso pretendido é desktop). Exceção consciente ao Princípio #2, já coberta por PDR-003 (§8).

---

## 4. Estados

### 4.1. Contratante

- **Folha — nenhuma opção escolhida:** "Continuar" desabilitado (opacidade 38%); foco no título ao abrir.
- **Diálogo de disputa — justificativa vazia:** "Abrir disputa" desabilitado; ao tentar enviar vazio (ou ao desfocar vazio), `errorText` "Conte o que aconteceu para abrir." vinculado ao campo.
- **Enviando:** "Abrir disputa" em loading ("Abrindo…"), campo e Voltar bloqueados.
- **Sucesso:** diálogo fecha → detalhe em `em_disputa` (selo + timeline "Disputa aberta" + snackbar "Disputa aberta — a equipe Turni vai mediar.").
- **Erro de rede/servidor:** erro inline no rodapé do diálogo (o diálogo **não** fecha) — "Não foi possível abrir a disputa. Tente de novo." Estado não muda.
- **Estado mudou em outra aba** (turno já não está em `aguardando_checkout`): 422 de estado → UI recarrega silenciosamente a verdade (padrão 064).
- **Contratante em `em_disputa`:** read-only — sem ação; o detalhe mostra selo + (opcional) um `banner.status` mais sóbrio "Disputa em análise — você será avisado da decisão." (sem expor que está aguardando ação dele, pois não há).

### 4.2. Profissional

- **`em_disputa`:** `banner.status` (error soft) + selo + timeline "Disputa aberta"; **sem ação**. Banner é `liveRegion` ao aparecer.
- **Pós-resolução (`finalizado`):** o detalhe recarrega (polling da 060/064) → banner some → estado `finalizado` + Pix (065). Nenhuma tela nova aqui.
- **Lista (059):** seção "Em disputa" + selo `⚠ Em disputa` — **sem mudança**.

### 4.3. Admin

- **Caminho feliz (fila com itens):** §3.4, ordenação por **mais antiga primeiro** (FIFO — quem está há mais tempo, mais perto de estourar o SLA, no topo).
- **Loading:** skeleton de 2–3 linhas da tabela; contadores em `—` (padrão 019).
- **Vazio — fila zerada (sucesso operacional):** ícone ✓ `success-soft` + "Nenhuma disputa em aberto" + "Casos novos aparecem aqui assim que um contratante contestar um check-out." (espelho 019 §4.3).
- **Erro de carregamento:** banner `error-soft` + "Tentar de novo" (padrão 019 §4.5).
- **Resolução — enviando:** "Pagar integral" em loading; campos bloqueados.
- **Resolução — sucesso:** drawer fecha → toast "Disputa resolvida — pagamento integral liberado." → item sai da fila → contador cai.
- **Race (CA — outro admin já resolveu):** toast de erro "Esta disputa já foi resolvida por outro admin." → drawer fecha → lista re-renderiza (item sumiu). Fail-secure (espelho 019 §4.5).
- **Erro genérico na resolução:** erro inline no diálogo (não fecha) "Não foi possível resolver. Tente novamente." — sem stack trace (CA-14 da 019).
- **Sem permissão:** `AdminOnly` → 403/redirect (sem UI própria — 019 §4.6).
- **Trilha parcial:** se um bloco da trilha (chat/checklist) não carregar, o caso renderiza o resto + "Parte do histórico indisponível no momento." — o caso nunca quebra por uma peça da trilha.

---

## 5. Microcopy completo

> Textos marcados (CA) são fixados pela estória. **Atenção:** a `nota_admin` foi decidida **obrigatória** (DDR-005 Decisão 3) — diverge do CA-3 ("opcional"); requer chancela do PO para editar o critério (ver §11 e Notas do agente da STORY-091).

### 5.1. Contratante

| Lugar | Texto |
|---|---|
| Entrada da recusa (`button.text`) | Não vai validar agora? Recusar check-out |
| Folha — título | Por que não vai validar? |
| Folha — opção 1 (título) | O turno ainda não terminou |
| Folha — opção 1 (descrição) | Volta para “Em andamento”. O tempo continua contando e o profissional gera um novo PIN. |
| Folha — opção 2 (título) | Tenho um problema com este turno |
| Folha — opção 2 (descrição) | Abre uma disputa: a equipe Turni media em até 30 minutos. Esta ação é irreversível. |
| Folha — voltar | Voltar |
| Folha — continuar | Continuar |
| Diálogo disputa — título | Abrir disputa deste turno? |
| Diálogo disputa — corpo | O turno fica em disputa e a equipe Turni vai mediar em até 30 minutos. O valor continua reservado até a decisão. Esta ação é irreversível. |
| Diálogo disputa — label justificativa | O que aconteceu? (obrigatório) |
| Diálogo disputa — placeholder | Descreva o problema com o turno |
| Diálogo disputa — erro (vazio) | Conte o que aconteceu para abrir. |
| Diálogo disputa — confirmar | Abrir disputa |
| Diálogo disputa — confirmar (loading) | Abrindo… |
| Diálogo disputa — voltar | Voltar |
| Diálogo disputa — erro de envio | Não foi possível abrir a disputa. Tente de novo. |
| Snackbar de sucesso | Disputa aberta — a equipe Turni vai mediar. |
| Selo do turno (contratante) | ⚠ Em disputa (SCREEN-059 §4.1) |
| Banner contratante em `em_disputa` (sóbrio) | Disputa em análise — você será avisado da decisão. |
| Timeline — disputa aberta (título) | Disputa aberta |
| Timeline — disputa aberta (descrição) | Você contestou o check-out. |

### 5.2. Profissional

| Lugar | Texto |
|---|---|
| Banner — título | Valor em disputa |
| Banner — corpo | O contratante contestou o check-out deste turno. A equipe Turni vai mediar em até 30 minutos e avisaremos você do desfecho. |
| Selo do turno | ⚠ Em disputa (SCREEN-059 §4.1) |
| Timeline — disputa aberta (título) | Disputa aberta |
| Timeline — disputa aberta (descrição, profissional) | O contratante contestou o check-out. |

> A justificativa do contratante **não** aparece em nenhum lugar para o profissional (DDR-005 Decisão 2).

### 5.3. Admin (Backoffice)

| Lugar | Texto |
|---|---|
| Item de sidebar | Disputas |
| Título da tela | Disputas |
| Subtítulo | {n} em aberto · SLA público de 30 min |
| Stat-card — em aberto | Em aberto / {n} |
| Stat-card — SLA estourado | Com SLA estourado / {k} |
| Banner SLA (só se houver > 30 min) | {k} disputa(s) há mais de 30 min em aberto — priorize. |
| Cabeçalho do painel | Fila de disputas |
| Colunas | Partes · Valor · Aberta há · (ações) |
| Linha — partes | {Estabelecimento} ⇄ {Profissional} |
| Linha — sub (função) | {Função} |
| Chip SLA | há {m} min |
| CTA por linha | Ver caso |
| Caso — título | Caso de disputa |
| Caso — fechar (aria) | Fechar caso |
| Caso — tempo na fila | há {m} min · SLA 30 min |
| Caso — header justificativa | Justificativa do contratante |
| Caso — header trilha | Trilha do turno |
| Caso — vaga original | Vaga original |
| Caso — checklist (resumo) | Checklist: {x}/{y} itens concluídos |
| Caso — chat (resumo) | Chat ({n} mensagens) |
| Caso — geofencing | Geofencing: a {d} m do estabelecimento |
| CTA resolver | Resolver: pagar integral |
| Diálogo resolver — título | Resolver: pagar integral? |
| Diálogo resolver — corpo | Captura o valor e libera o Pix ao profissional. O turno será finalizado. Esta ação é irreversível. |
| Diálogo resolver — label nota | Nota da decisão (obrigatória) |
| Diálogo resolver — erro (vazio) | Descreva o motivo da decisão. |
| Diálogo resolver — confirmar | Pagar integral |
| Diálogo resolver — confirmar (loading) | Processando… |
| Diálogo resolver — voltar | Voltar |
| Diálogo resolver — erro genérico | Não foi possível resolver. Tente novamente. |
| Toast — resolvido | Disputa resolvida — pagamento integral liberado. |
| Toast — race (erro) | Esta disputa já foi resolvida por outro admin. |
| Vazio — título | Nenhuma disputa em aberto |
| Vazio — instrução | Casos novos aparecem aqui assim que um contratante contestar um check-out. |
| Erro de carregamento | Não foi possível carregar as disputas. + CTA Tentar de novo |
| Aviso mobile | Backoffice é desktop-first (≥1024px). Alargue a janela para ver o shell completo. |

Datas/horas pt-BR 24h (DDR-002); valores `R$ 1.234,56`; vocabulário do glossário (Turno, Vaga, Profissional, Contratante, Disputa). Tom direto, sem "Ops!".

---

## 6. Acessibilidade (notas específicas)

- **Folha de desambiguação:** `RadioListTile` com label + descrição lidos juntos; foco inicial no **título** (nunca num rádio); "Continuar" só habilita após escolha; navegação ←/→ entre opções, Enter confirma; ESC/Voltar fecha sem efeito.
- **Diálogos (disputa / resolver):** `role="alertdialog"`/focus trap; foco inicial no **campo de texto** (a justificativa/nota é o que o usuário precisa preencher), nunca no botão destrutivo; `errorText` **vinculado ao campo** e anunciado por leitor de tela (`liveRegion`); confirmar destrutivo em `error` sólido (5.7:1) ou sucesso conforme o caso; ESC cancela.
- **Banner do profissional (`banner.status`):** `Semantics(liveRegion: true)` ao aparecer; ícone decorativo (`excludeSemantics`), o título+corpo carregam o significado (cor nunca é canal único); **não** anunciado como clicável (read-only).
- **Fila do admin:** indicador de SLA = ícone (●/▲/■) + cor + texto "há {m} min" (nunca só cor); Tab percorre linhas → "Ver caso"; drawer com focus trap, foco no título ao abrir, Esc fecha e devolve foco à linha; `aria-live="polite"` na lista após resolver ("Disputa resolvida, 1 em aberto"); toasts `assertive` (erro)/`polite` (sucesso).
- **Caso/trilha:** cada evento é um nó `Semantics` ("{título}, {descrição}, {hora}"); blocos expansíveis (chat/checklist) com `aria-expanded`; justificativa é um bloco de texto navegável com header semântico.
- **Contraste:** todos os pares são sancionados em `tokens.md §6` para os temas usados (contratante mostarda, profissional sage, admin navy; semânticas error/warning/success). Nenhuma combinação nova.
- **Alvos de toque:** ≥48dp (Flutter) / ≥40px (Backoffice desktop, ≥44 no fallback mobile).

---

## 7. Identificadores estáveis sugeridos para teste

### 7.1. Contratante (Flutter — `Key`/`ValueKey`)

| Elemento | Identificador lógico |
|---|---|
| Entrada da recusa (reusa 064) | `recusar-checkout-btn` |
| Folha de desambiguação | `disputa-intencao-sheet` |
| Opção “ainda não terminou” | `disputa-intencao-ativo` |
| Opção “tenho um problema” | `disputa-intencao-problema` |
| Continuar (folha) | `disputa-intencao-continuar` |
| Voltar (folha) | `disputa-intencao-voltar` |
| Diálogo de disputa | `abrir-disputa-dialog` |
| Justificativa (textarea) | `abrir-disputa-justificativa-input` |
| Erro da justificativa | `abrir-disputa-justificativa-erro` |
| Confirmar (abrir disputa) | `abrir-disputa-confirmar-btn` |
| Voltar (diálogo) | `abrir-disputa-voltar-btn` |
| Erro de envio (diálogo) | `abrir-disputa-erro` |
| Snackbar de sucesso | `abrir-disputa-sucesso` |
| Banner contratante em disputa | `disputa-contratante-banner` |

### 7.2. Profissional (Flutter)

| Elemento | Identificador lógico |
|---|---|
| Banner de disputa | `disputa-banner` |

### 7.3. Admin (Backoffice — `data-testid`)

| Elemento | Identificador |
|---|---|
| Item de sidebar | `nav-disputas` |
| Container da tela | `screen-disputas` |
| Contador em aberto | `disputas-count-aberto` |
| Contador SLA estourado | `disputas-count-sla` |
| Banner SLA | `disputas-sla-banner` |
| Tabela/lista | `disputas-list` |
| Linha de item | `disputas-item-{turnoId}` |
| Indicador SLA do item | `disputas-item-{turnoId}-sla` |
| CTA ver caso | `disputas-item-{turnoId}-ver` |
| Drawer do caso | `disputas-caso` |
| Caso — fechar | `disputas-caso-close` |
| Caso — justificativa | `caso-justificativa` |
| Caso — trilha | `caso-trilha` |
| Caso — link vaga original | `caso-vaga-original` |
| CTA resolver | `disputas-caso-resolver` |
| Diálogo resolver | `dialog-resolver` |
| Nota (textarea) | `resolver-nota-input` |
| Erro da nota | `resolver-nota-erro` |
| Confirmar (pagar integral) | `dialog-resolver-confirm` |
| Voltar (diálogo) | `dialog-resolver-cancel` |
| Toast | `disputas-toast` |
| Estado vazio | `disputas-empty` |

> `{turnoId}` é UUIDv7 string (ADR-018). E2E ancora: contratante `recusar-checkout-btn` → `disputa-intencao-problema` → `abrir-disputa-confirmar-btn` → selo `em_disputa`; admin `disputas-item-{id}-ver` → `disputas-caso-resolver` → `dialog-resolver-confirm` → item sai da fila.

---

## 8. Exceções ao Design System

| O que diverge | Por quê | Vira DDR? |
|---|---|---|
| `pattern.intent-disambiguation` — folha de escolha de intenção antes de ação ramificada de alto custo | DS não tem; é o coração da Decisão 1 do DDR-005. `showModalBottomSheet`/`AlertDialog` + `RadioListTile`. | **Sim — DDR-005** (registrar em `patterns.md` nesta operação). |
| `banner.status` — banner persistente read-only de estado (não erro recuperável, não gate) | "banner" era usado informalmente; esta operação separa o banner de **estado** (sem CTA) do banner de erro e do `banner.gate`. Família visual do `banner.gate` (DDR-004). | **Sim — DDR-005** (registrar em `components.md`). |
| `dialog.confirm` — variante **campo obrigatório** (erro quando vazio, confirmar desabilitado) | O `dialog.confirm` tinha campo opcional; disputa e resolução exigem o campo. Mesma anatomia. | Não — **extensão** do componente; registrar em `components.md`. |
| Admin **desktop-first** (Princípio #2) | PDR-003 (Backoffice é ferramenta de mesa). Mobile é fallback que não quebra. | Não — já coberto por PDR-003/DDR-001. |
| Omitir a área de ações "placeholder" da 060 em `em_disputa` quando há `banner.status` | Redundante com o banner read-only. | Não — ajuste local consciente (§3.3/§11). |

Nenhuma cor nova: tudo em tokens auditados AA (DDR-001 §6).

---

## 9. Protótipo HTML fiel (validação humana)

- **Localização:** `SCREEN-STORY-091-disputa/index.html`.
- **Cobertura:** seletor de **superfície** (Contratante · Profissional · Admin), **viewport** (mobile/desktop; admin desktop + estreito) e **estado**. Fluxo navegável de verdade:
  - **Contratante:** bloco de validação → "Recusar check-out" → folha → escolher "tenho um problema" → diálogo de disputa → justificativa vazia (erro) → preencher → "Abrir disputa" → `em_disputa` com selo + timeline + snackbar; ramo "ainda não terminou" volta ao bloco. Estados: `validacao`, `folha`, `dialogo-disputa`, `dialogo-erro`, `em-disputa`.
  - **Profissional:** detalhe em `em_disputa` com `banner.status` + selo + timeline; estado `em-disputa`.
  - **Admin:** fila (`lista`, `vazio`, `erro`), caso (`caso`), diálogo resolver (`resolver`, `resolver-erro`), toasts (`toast-resolvido`, `toast-race`). Tema navy claro/escuro.
- **Fidelidade:** tokens reais dos temas (DDR-001) — mostarda/sage/navy; microcopy = §5 palavra por palavra; identificadores §7 como `data-testid`/`id`; horários 24h pt-BR.
- **Restrições:** HTML/CSS/JS vanilla, sem rede, mock inline, comentário "protótipo de validação, não código de produção".

### Checklist antes de marcar spec `ready`

- [ ] Protótipo abre sem erro; todos os estados da §4 acessíveis nas três superfícies e viewports.
- [ ] Fluxo do contratante percorrível ponta a ponta (validação → folha → disputa → em_disputa) + ramo "ainda não terminou".
- [ ] Fluxo do admin percorrível (fila → caso → resolver → sai da fila) + race + vazio.
- [ ] Microcopy do protótipo bate palavra por palavra com a §5.
- [ ] Identificadores da §7 presentes.
- [ ] Tokens reais dos três temas aplicados.
- [ ] Protótipo apresentado ao humano (Alexandro) e sinal de validação capturado.

---

## 10. Dependências e premissas

- **ADR-020** fixa o backend: `turnos.disputa` (jsonb), `AbrirDisputaService` (`aguardando_checkout → em_disputa`, justificativa obrigatória), `ResolverDisputaService` (comando da api, `em_disputa → finalizado`, reusa `TurnoFinalizado` → captura+Pix), evento `DisputaAberta` → notificação ao profissional, fila derivada do estado. Mecanismo do canal admin→api e forma da leitura do caso = **IDR de implementação** (ADR-020 Decisões 3/6).
- **Endpoints (contrato — formato fino é do Programador):**
  - Contratante: `POST /api/turnos/{uuid}/abrir-disputa { justificativa }` → `200 { estado: 'em_disputa' }`; 422 `justificativa_obrigatoria` / `estado_invalido`; 403.
  - Recusa benigna: endpoint atual da 064 (`recusar()` → `ativo`), inalterado.
  - Admin: leitura do caso (agregação) + `resolver: pagar integral` via comando da api (ADR-020).
- **SCREEN-064** (validação) é onde a entrada da recusa vive — STORY-094 a estende (a entrada deixa de ir direto ao `dialog.confirm` de recusa→ativo; passa pela folha).
- **SCREEN-060** ganha o `banner.status` + evento "Disputa aberta" na timeline — STORY-095.
- **SCREEN-059 / SCREEN-019** sem mudança (reuso).
- **Conflito `nota_admin`** (CA-3 opcional × ADR-020 obrigatória) — resolvido **obrigatória**; requer chancela do PO para editar o CA-3 (§11 / Notas do agente).

---

## 11. Histórico de mudanças

| Data | Mudança | Quem | Motivo |
|---|---|---|---|
| 2026-06-10 | criação (spec completo das 3 superfícies + DDR-005 + protótipo v1) | claude-opus-4-8 (designer) | STORY-091; direções centrais pré-validadas no sync com o dono (entrada única que desambigua · profissional não vê justificativa · nota_admin obrigatória) |
| 2026-06-10 | ajustes conscientes sobre specs vigentes | claude-opus-4-8 (designer) | (a) SCREEN-064: a entrada "Recusar check-out" passa a abrir a folha de desambiguação (a recusa→ativo vira uma das opções) — STORY-094; (b) SCREEN-060: área de ações placeholder omitida em `em_disputa` quando o `banner.status` está presente — STORY-095 |
| 2026-06-10 | validação humana — aprovado | Alexandro | "aprovado" em chat (protótipo + DDR-005). Inclui chancela do PO para editar o CA-3 (nota_admin "opcional" → "obrigatória"); `status: ready` |

> **Mudança depois que o código começou** é mudança consciente — registrar aqui e em "Notas do agente" da STORY-091.
