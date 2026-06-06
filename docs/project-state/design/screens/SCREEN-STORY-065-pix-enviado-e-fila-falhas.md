---
id: SCREEN-STORY-065-pix-enviado-e-fila-falhas
story: STORY-065-captura-pagarme-pix-sandbox-alerta-falha
epic: EPIC-003-aceite-pin-e-pix
status: ready                # draft | ready | in_implementation | shipped | superseded
created_at: 2026-06-06
updated_at: 2026-06-06
owner_designer: claude-opus-4-8
related_ddrs: [DDR-001, DDR-002]
ds_components_used: [surface.card, badge.status, timeline.event, snackbar, sidebar.admin, panel, data-table, chip, btn.outline, btn.primary, dialog-confirm, toast, empty-state, skeleton]
exceptions_to_ds: [backoffice desktop-first (PDR-003 — exceção já registrada na SCREEN-019)]
viewports: [mobile, desktop]
prototype_path: SCREEN-STORY-065-pix-enviado-e-fila-falhas/index.html
prototype_last_validated_at: 2026-06-06  # aprovado por Alexandro em chat (sem ajustes; falha p/ profissional = "Pix a caminho" confirmado)
---

# Spec de tela — SCREEN-STORY-065 — Pix pós-turno: status no card de valor + fila "Pix com falha" (admin)

> Referência: estória `STORY-065`. CAs e contexto vêm de lá — **não duplico**.
> A estória nasceu `requires_design: false`; Alexandro pediu o fluxo designer→programador
> (2026-06-06). O spec é **leve de propósito**: nenhuma tela nova no WebApp (o card de
> valor da SCREEN-060 ganha uma linha de status — CA-4) e uma **fila nova no Backoffice**
> que **reusa por inteiro** o padrão da SCREEN-019 (shell, panel, data-table, chips,
> dialog, toast). Princípios que dirigiram: **#1** (o profissional só precisa saber UMA
> coisa: "meu dinheiro chegou?"; o admin só precisa fazer UMA coisa: tratar a falha),
> **#3** (dinheiro fecha com discrição — zero confete), **#4** (reuso total — nenhum
> componente novo), **#7** (falha de Pix, fila vazia, erro de carregamento e race entre
> admins são estados desenhados).

---

## Superfícies (duas, em plataformas diferentes)

| Superfície | Plataforma | O que muda |
|---|---|---|
| **A. Detalhe do turno** (`/turnos/{id}`, papel profissional, `finalizado`) | WebApp Flutter, mobile-first | Card de valor ganha **linha de status do Pix** (CA-4); timeline já cobre `pagamento_capturado`/`pix_enviado` (SCREEN-060 §4.12 — sem mudança) |
| **B. Fila "Pix com falha"** (`/pix-falhas`) | Backoffice Laravel/Livewire, desktop-first (PDR-003) | Página nova na seção **Operação** da sidebar (CA-5/CA-8) |

---

## A. WebApp — status do Pix no card de valor (CA-4)

### A.1. Objetivo

O turno acabou; o profissional quer saber **se o dinheiro dele chegou**. A resposta mora
onde ele já olha o valor — o card "Você recebe" da SCREEN-060 — sem tela nova, sem badge
novo, sem competir com o cronômetro final (064 §4.11).

### A.2. Fluxo

- **Entrada:** detalhe `/turnos/{id}`, papel **profissional**, turno `finalizado`.
  Nenhuma ação nova — a linha é **informativa** (estado terminal segue sem ações, 064 §4.11).
- **Contratante:** card de valor **inalterado**. A confirmação dele já existe na timeline
  (`pagamento_capturado` — "R$ 230,00 cobrados do seu meio de pagamento", SCREEN-060 §4.1).
  Decisão consciente (Princípio #1): não duplicar a informação no card.

### A.3. Layout — card de valor do profissional em `finalizado` (mobile ≥360px)

Sub-estado **Pix a caminho** (entre `finalizado` e o webhook de confirmação — fake
confirma em ~30s, SLA configurável até 15 min):

```
|  +------------------------------------+  |
|  | Você recebe                        |  |  (inalterado — SCREEN-060)
|  | R$ 200,00                          |  |
|  | valor integral · taxa Turni        |  |
|  | cobrada do contratante             |  |
|  | ---------------------------------- |  |  divisor (border-subtle)
|  | ◌ Pix a caminho — normalmente      |  |  linha de status: 13.5px,
|  |   chega em até 15 min.             |  |  text.muted; ◌ = spinner discreto 14px
|  +------------------------------------+  |
```

Sub-estado **Pix enviado** (CA-4 — microcopy fixado pela estória):

```
|  | ---------------------------------- |  |
|  | ✓ Pix enviado em 18:32             |  |  13.5px w600, ink success;
|  +------------------------------------+  |  ✓ 14px success
```

- Horário **24h pt-BR** (DDR-002). Dia ≠ corrente: "Pix enviado em 05/06 · 18:32"
  (mesma regra de data da timeline — SCREEN-060 §5).
- **Desktop (≥1024px):** card de valor na coluna esquerda da 060 — sem mudança de grid;
  a linha acompanha o card.

### A.4. Estados (superfície A)

| Estado | O que mostra |
|---|---|
| `finalizado`, Pix ainda não confirmado | Linha "Pix a caminho — normalmente chega em até 15 min." com spinner discreto (◌, 14px, gira a 1s; `prefers-reduced-motion` → estático). O dado vem do payload do detalhe + **polling já existente** do detalhe (mesmo mecanismo da 063/064) — quando o webhook confirma, a linha troca sozinha, sem refresh. |
| `finalizado`, `pix_enviado` | Linha "✓ Pix enviado em {HH:MM}" (ink `success`). Timeline ganha o evento `pix_enviado` (já especificado na 060 — sem trabalho novo de spec). |
| `finalizado`, `pix_falhou` | **O profissional vê a MESMA linha de "Pix a caminho"** — sem mudança. Decisão consciente: PDR-010 define comunicação **manual** pela equipe em falha (fora de escopo automatizar); mostrar "falhou" sem canal de resolução geraria ansiedade sem próximo passo (Princípio #1: próximo passo sempre claro — aqui o próximo passo é da operação, não dele). Por isso o microcopy diz "**normalmente** chega em até 15 min" — não promete o que a falha quebraria. |
| Turno não-`finalizado` | Linha não existe (card de valor da 060 intacto). |
| Loading/erro do detalhe | Inalterados (SCREEN-060 §4.2/4.5) — a linha entra no skeleton existente do card de valor. |

### A.5. Acessibilidade (superfície A)

- A linha de status é um único nó `Semantics` ("Pix a caminho…" / "Pix enviado às 18:32").
- Troca de "a caminho" → "enviado" via polling: container com `liveRegion: true` —
  leitor de tela anuncia a chegada do dinheiro (um anúncio único, não por tick).
- Ink `success` sobre `surface` passa AA (par sancionado em `tokens.md §6`); o ✓ não é o
  único canal (texto completo ao lado).

---

## B. Backoffice — fila "Pix com falha" (CA-5, CA-8)

### B.1. Objetivo

A operação Turni descobre **na hora** que um Pix falhou, com tudo que precisa para tratar
manualmente (valor, chave Pix, razão do gateway) e um jeito de **fechar o caso** com
rastro (nota → audit log). PDR-010: **uma tentativa, sem retry automático** — a fila é o
único caminho de tratamento.

### B.2. Fluxo

- **Entrada:** item novo "**Pix com falha**" na seção **Operação** da sidebar (depois de
  "Cadastros pendentes"), rota `/pix-falhas`, com **contador vermelho** quando há
  pendências (espelho do contador da fila de aprovação; vermelho porque é dinheiro parado).
- **Pré-condições:** `AdminOnly` (STORY-016) — fail-secure idêntico à SCREEN-019 §4.6.
- **Ações na tela:**
  - **Primária por linha:** "Resolver" (btn.outline — abre dialog de resolução).
  - **Copiar chave Pix** (botão inline na célula — o admin vai fazer o Pix manualmente
    em outro sistema; copiar é parte do trabalho real).
  - **Secundárias:** alternar `[Pendentes (n)] [Resolvidos]`; paginar.
- **Saída:** resolvido → item sai de "Pendentes", aparece em "Resolvidos" com nota +
  quem + quando; toast confirma; contador da sidebar decrementa.

### B.3. Layout — desktop (≥1024px, primário — PDR-003)

Shell idêntico ao `preview-backoffice.html`/SCREEN-019. Sem stat-cards (uma fila só não
precisa de visão agregada — Princípio #1; o subtítulo já dá o número).

```
+-----------+-------------------------------------------------------------+
| TURNI.    | Backoffice · Admin                                          |
| Backoffice| Pix com falha                                               |
|           | 2 transferências aguardando tratamento manual               |
| OPERAÇÃO  |                                                             |
| ▸ Visão   | [Pendentes (2)] [Resolvidos]                                |
| ▸ Penden. | +---------------------------------------------------------+ |
| ● Pix     | | Fila de tratamento manual                               | |
|   falha 2 | +---------------------------------------------------------+ |
|           | | Turno          Valor     Chave Pix      Falha    →      | |
| CADASTRO  | | ■ Pix falhou — tratamento manual                        | |
| ▸ Templ.  | | Garçom · Bar   R$200,00  a1b2…@pix ⧉   Sex 05/06 [Resol]| |
|           | |   do Zé · Carlos Silva   conta destino  18:47    [ver]  | |
| [Sair]    | |   razão: invalid_pix_key — chave não encontrada         | |
+-----------+-------------------------------------------------------------+
```

Anatomia da **linha** (uma falha = um caso):

- **Badge vermelho** `■ Pix falhou — tratamento manual` (chip `error-soft` + dot `error`
  — microcopy do CA-5, fixado) no topo da célula principal.
- **Turno:** `{função} · {estabelecimento}` (forte) + sub-linha `{profissional}`.
- **Valor:** `R$ {valor}` (mono, forte — é o que o admin vai transferir).
- **Chave Pix:** truncada com elipse no meio (`a1b2…@pix`) + botão **⧉ Copiar** (copia a
  chave completa; feedback "Copiada" inline 2s).
- **Razão:** código + mensagem retornados pelo gateway (formato Pagar.me-compatível),
  em `mono` 12px `text-subtle` — é dado técnico, não narrativa.
- **Falhou em:** `EEE dd/MM · HH:mm` (24h pt-BR — DDR-002). Ordenação **desc** (CA-8).
- **Ação:** `[Resolver]` (btn.outline.sm).

Aba **Resolvidos**: mesmas colunas, badge neutro `✓ Resolvido manualmente`, coluna extra
"Resolução": nota + `por {admin} · {dd/MM HH:mm}`. Sem ação por linha (caso fechado;
imutável — audit log é a fonte).

### B.4. Dialog de resolução — `dialog-confirm` (padrão SCREEN-019)

```
+------------------------------------------+
| Marcar como resolvido manualmente?       |
|                                          |
| Confirme apenas depois de tratar a       |
| transferência fora da plataforma. O caso |
| sai da fila e fica registrado no         |
| histórico de auditoria.                  |
|                                          |
| Garçom · Bar do Zé — R$ 200,00           |  resumo do caso (sunken)
| Carlos Silva · a1b2…@pix                 |
|                                          |
| O que foi feito (obrigatório)            |
| ┌──────────────────────────────────────┐ |
| │ Ex.: Pix manual feito pela conta     │ |
| │ Turni em 06/06 às 14:20              │ |
| └──────────────────────────────────────┘ |
|            [ Cancelar ] [ Confirmar     ]|
|                         [  resolução   ] |
+------------------------------------------+
```

- **Nota obrigatória** (CA-8 — "com nota"; sem nota o audit log não conta a história).
  ≤500 caracteres. Validação inline: "Descreva o que foi feito antes de confirmar."
- Confirmar → loading no botão → toast "Caso resolvido. Registrado no histórico de
  auditoria." → linha sai da lista → contador decrementa.
- Foco inicial em **Cancelar** (padrão SCREEN-019 — evita confirmação acidental).

### B.5. Estados (superfície B)

| Estado | O que mostra |
|---|---|
| **Lista (pendentes)** | §B.3. Ordenado por falha desc. Paginação `‹ Anterior · Página x de y · Próxima ›`. |
| **Loading** | Skeleton de 3 linhas (padrão SCREEN-019 §4.2); contador da aba mostra `—`. |
| **Vazio (pendentes)** | Estado de sucesso operacional: ✓ em círculo `success-soft` + "Nenhum Pix com falha" + "Falhas de transferência aparecem aqui assim que o gateway reportar. Por enquanto, tudo certo." |
| **Vazio (resolvidos)** | Neutro: "Nenhum caso resolvido ainda" + "Casos tratados manualmente ficam registrados aqui." |
| **Erro de carregamento** | Banner `error-soft` no topo do panel + "Não foi possível carregar a fila." + `[Tentar de novo]`. Não esconde lista anterior se houver. |
| **Race entre admins** | Caso já resolvido por outro admin → toast de erro "Este caso já foi resolvido por outro admin." → dialog fecha → lista re-renderiza. Fail-secure, sem transição parcial. |
| **Erro na ação** | Toast "Não foi possível concluir a ação. Tente novamente." — detalhe técnico vai pro log estruturado, não pra UI. |
| **Atualização pós-sucesso-aparente (CA-6)** | Webhook reportando falha **depois** de a UI já ter visto sucesso só **insere o caso na fila** (fonte de verdade é o webhook). Sem estado visual novo — a fila é o alerta. |
| **Sem permissão** | `AdminOnly` → 403/redirect (SCREEN-019 §4.6 — sem UI própria). |
| **Mobile (<1024px)** | Fallback degradado padrão do Backoffice: aviso "desktop-first", tabela colapsa em cards, dialog full-screen. Não quebra; uso pretendido é mesa. |

### B.6. Acessibilidade (superfície B)

- Badge não depende só de cor: dot + texto completo "Pix falhou — tratamento manual".
- "⧉ Copiar" tem `aria-label="Copiar chave Pix de {profissional}"`; feedback "Copiada"
  em `aria-live="polite"`.
- Dialog: `role="alertdialog"`, focus trap, Esc cancela, foco inicial em Cancelar;
  erro de validação da nota vinculado ao campo (`aria-describedby`).
- Lista re-renderiza após resolver: container `aria-live="polite"` anuncia
  "Caso resolvido, {n} pendentes."
- Abas Pendentes/Resolvidos: `role="tablist"`, setas navegam, contraste AA nos chips.

---

## 5. Microcopy completo

Textos marcados (CA) são fixados pela estória — não alterar sem PO.

### Superfície A — WebApp (profissional)

| Lugar | Texto |
|---|---|
| Linha status — a caminho | Pix a caminho — normalmente chega em até 15 min. |
| Linha status — enviado (CA-4) | Pix enviado em {HH:MM} |
| Linha status — enviado, dia ≠ corrente | Pix enviado em {dd/MM} · {HH:MM} |
| Semantics — a caminho | Pix a caminho, normalmente chega em até quinze minutos |
| Semantics — enviado | Pix enviado às {HH:MM} |

### Superfície B — Backoffice (admin)

| Lugar | Texto |
|---|---|
| Sidebar — item | Pix com falha |
| Breadcrumb | Backoffice · Admin |
| Título da tela | Pix com falha |
| Subtítulo (pendentes > 0) | {n} transferência(s) aguardando tratamento manual |
| Subtítulo (zerada) | Nenhuma transferência aguardando tratamento |
| Abas | Pendentes ({n}) · Resolvidos |
| Cabeçalho do panel (pendentes) | Fila de tratamento manual |
| Cabeçalho do panel (resolvidos) | Casos resolvidos |
| Colunas | Turno · Valor · Chave Pix · Razão · Falhou em · (ações sem rótulo) |
| Badge por linha (CA-5) | Pix falhou — tratamento manual |
| Badge resolvido | Resolvido manualmente |
| Sub-linha do turno | {profissional} |
| Copiar chave | Copiar |
| Copiada (feedback 2s) | Copiada |
| CTA por linha | Resolver |
| Coluna resolução | {nota} — por {admin} · {dd/MM} {HH:mm} |
| Dialog — título | Marcar como resolvido manualmente? |
| Dialog — corpo | Confirme apenas depois de tratar a transferência fora da plataforma. O caso sai da fila e fica registrado no histórico de auditoria. |
| Dialog — label da nota | O que foi feito (obrigatório) |
| Dialog — placeholder da nota | Ex.: Pix manual feito pela conta Turni em 06/06 às 14:20 |
| Dialog — erro de validação | Descreva o que foi feito antes de confirmar. |
| Dialog — confirmar | Confirmar resolução |
| Dialog — cancelar | Cancelar |
| Toast — resolvido | Caso resolvido. Registrado no histórico de auditoria. |
| Toast — race | Este caso já foi resolvido por outro admin. |
| Toast — erro genérico | Não foi possível concluir a ação. Tente novamente. |
| Vazio pendentes — título | Nenhum Pix com falha |
| Vazio pendentes — instrução | Falhas de transferência aparecem aqui assim que o gateway reportar. Por enquanto, tudo certo. |
| Vazio resolvidos — título | Nenhum caso resolvido ainda |
| Vazio resolvidos — instrução | Casos tratados manualmente ficam registrados aqui. |
| Erro de carregamento | Não foi possível carregar a fila. + CTA Tentar de novo |
| Paginação | ‹ Anterior · Página {x} de {y} · Próxima › |

Horários 24h pt-BR (DDR-002). Valores `R$ 1.234,56`.

---

## 7. Identificadores estáveis sugeridos para teste

### Superfície A — `Key()` Flutter (integration_test)

| Elemento | Identificador lógico |
|---|---|
| Linha de status do Pix (container) | `turno-detalhe-pix-status` |
| Variante "a caminho" | `turno-detalhe-pix-acaminho` |
| Variante "enviado" (CA-4) | `turno-detalhe-pix-enviado` |

### Superfície B — `data-testid` (Playwright/Pest)

| Elemento | Identificador |
|---|---|
| Sidebar — item | `nav-pix-falhas` |
| Sidebar — contador | `nav-pix-falhas-count` |
| Container da tela | `screen-pix-falhas` |
| Aba pendentes / resolvidos | `pixfalhas-tab-pendentes` / `pixfalhas-tab-resolvidos` |
| Lista | `pixfalhas-list` |
| Linha de caso | `pixfalhas-item-{turnoId}` |
| Badge da linha | `pixfalhas-item-{turnoId}-badge` |
| Valor | `pixfalhas-item-{turnoId}-valor` |
| Chave Pix | `pixfalhas-item-{turnoId}-chave` |
| Copiar chave | `pixfalhas-item-{turnoId}-copiar` |
| Razão | `pixfalhas-item-{turnoId}-razao` |
| CTA resolver | `pixfalhas-item-{turnoId}-resolver` |
| Dialog | `pixfalhas-dialog` |
| Nota (textarea) | `pixfalhas-dialog-nota` |
| Erro de validação da nota | `pixfalhas-dialog-nota-erro` |
| Confirmar | `pixfalhas-dialog-confirmar` |
| Cancelar | `pixfalhas-dialog-cancelar` |
| Toast | `pixfalhas-toast` |
| Vazio (pendentes/resolvidos) | `pixfalhas-empty` / `pixfalhas-empty-resolvidos` |
| Erro de carregamento | `pixfalhas-erro-banner` |

---

## 8. Exceções ao Design System

| O que diverge | Por quê | Vira DDR? |
|---|---|---|
| Backoffice desktop-first | PDR-003 — exceção já registrada na SCREEN-019 §8. | Não. |

Nenhum componente novo: a linha de status do Pix é conteúdo do `surface.card` existente;
a fila reusa `panel`/`data-table`/`chip`/`dialog-confirm`/`toast` da SCREEN-019; o
contador da sidebar reusa o `sb-count` do shell. O botão "Copiar" é `btn.outline.sm`
com ícone — variante já sancionada.

---

## 9. Protótipo HTML fiel (validação humana)

- **Localização:** `SCREEN-STORY-065-pix-enviado-e-fila-falhas/index.html`.
- **Cobertura:** seletor de **superfície** (WebApp profissional / Backoffice admin).
  - WebApp: estados `pix-acaminho` (spinner discreto vivo; troca sozinha para "enviado"
    após ~6s — simula o webhook do fake) e `pix-enviado`; viewports mobile/desktop.
  - Backoffice: `lista`, `loading`, `vazio`, `vazio-resolvidos`, `erro`, `resolvidos`,
    dialog de resolução **funcional** (nota obrigatória com validação; confirmar remove a
    linha, decrementa contadores e mostra toast; race simulável), copiar chave com
    feedback "Copiada". Tema claro/escuro.
- **Fidelidade:** tokens reais (DDR-001 — perfil profissional verde-sage no WebApp;
  admin navy no Backoffice); microcopy = §5 palavra por palavra; identificadores §7 como
  `data-testid`; 24h pt-BR.
- **Restrições:** HTML/CSS/JS vanilla, sem rede, mock inline, comentário "protótipo de
  validação".

### Checklist antes de marcar spec `ready`

- [x] Protótipo abre sem erro; todos os estados acessíveis nas duas superfícies
      (verificado em Chrome headless: wa-acaminho/wa-enviado/bo-lista/bo-resolvidos).
- [x] Fluxo de resolução ponta a ponta (lista → dialog → nota → toast → resolvidos).
- [x] Microcopy bate palavra por palavra com a §5.
- [x] Identificadores da §7 presentes.
- [x] Tokens reais dos dois perfis.
- [x] Protótipo apresentado ao humano e sinal de validação capturado (2026-06-06,
      em chat — inclui confirmação da decisão §A.4: falha de Pix não muda a linha
      do profissional).

---

## 10. Dependências e premissas

- **Payload do detalhe do turno (WebApp):** em `finalizado`, expõe o status do Pix —
  sugerido `pix { status: 'a_caminho'|'enviado', enviado_em? }` (nulo fora de
  `finalizado`; `pix_falhou` chega como `a_caminho` para o profissional — decisão §A.4,
  formato fino é do Programador). O **polling existente** do detalhe carrega a troca.
- **Fila do admin (back):** lê os turnos com evento `pix.falhou` não resolvido; ação
  grava resolução (nota + admin + timestamp) **em audit log imutável** + flag de
  resolvido (estrutura é do Programador). Razão/código vêm do payload do gateway
  (Pagar.me-compatível — fake configurado para falha exercita em homolog, CA-5).
- **Contador da sidebar:** mesmo mecanismo do contador de "Cadastros pendentes".
- **Timeline (WebApp):** `pagamento_capturado` e `pix_enviado` **já estão na whitelist**
  da SCREEN-060 §4.1 — sem mudança de spec; a 065 só passa a emiti-los de verdade.
- **Sem notificação ao profissional em falha** (PDR-010 — manual; fora de escopo).
- **Banner global de simulação em homolog é STORY-075** — não desenho aqui.
- Spec **não depende** de DDR pendente.

---

## 11. Histórico de mudanças

| Data | Mudança | Quem | Motivo |
|---|---|---|---|
| 2026-06-06 | criação (spec completo + protótipo v1) | claude-opus-4-8 (designer) | STORY-065; Alexandro pediu fluxo designer→programador (estória nasceu `requires_design: false` — atualizada) |
| 2026-06-06 | validação humana — aprovado sem ajustes | Alexandro | confirmou a decisão §A.4 (falha de Pix → profissional segue vendo "Pix a caminho", PDR-010) e aprovou spec+protótipo para implementação; `status: ready` |
