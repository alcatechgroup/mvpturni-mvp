---
id: DDR-005
title: Disputa de check-out — desambiguação da recusa (entrada única), banner read-only do profissional e tela de caso do admin
status: accepted   # proposed | accepted | superseded | rejected | deferred
created_at: 2026-06-10
decided_at: 2026-06-10
approved_by: Alexandro
supersedes: ~
superseded_by: ~
related_ddrs: [DDR-001, DDR-002, DDR-003, DDR-004]
related_adrs: [ADR-015, ADR-016, ADR-019, ADR-020]
related_pdrs: [PDR-003, PDR-006, PDR-017]
scope: disputa (check-out do contratante · banner do profissional · caso no backoffice admin)
affects_screens: [SCREEN-STORY-064-pin-checkout, SCREEN-STORY-060-detalhe-turno, SCREEN-STORY-059-listas-turnos, SCREEN-STORY-019-fila-aprovacao, SCREEN-STORY-091-disputa]
---

# DDR-005 — Disputa de check-out: desambiguação da recusa, banner do profissional e tela de caso do admin

## Contexto

O EPIC-005 entrega o caminho de exceção do check-out: o contratante recusa validar o turno **por mérito** (contesta valor/execução), o turno vai para `em_disputa`, a equipe Turni resolve no backoffice e o profissional é notificado. Esta decisão fixa **como o usuário experimenta** as três superfícies que a disputa toca, dentro do DS (DDR-001), do idioma/formatos (DDR-002) e do shell (DDR-003) vigentes. É o spike da **STORY-091**, que bloqueia as estórias de frontend 094/095/096.

**Documentos lidos:** STORY-091 (inteira), `epic.md` do EPIC-005, `domain/disputa.md` (justificativa obrigatória, SLA 30 min, profissional read-only), `domain/turno.md` (estado `em_disputa`, transições), **ADR-020** (modelo de disputa + transições + comando de captura do admin — `accepted` em 2026-06-10), PDR-006 (disputa via admin), PDR-017 (gateway fake no MVP), PDR-003 (WebApp Flutter mobile-first × Backoffice Laravel/Livewire desktop-first), DDR-001/002/003, DDR-004 (`banner.gate` — precedente de banner persistente não-dispensável), e as specs vigentes que esta decisão toca: **SCREEN-064** (validação do check-out do contratante — já tem uma recusa benigna), **SCREEN-060** (detalhe do turno — onde mora o banner), **SCREEN-059** (listas — já marca `em_disputa`), **SCREEN-019** (fila do backoffice — padrão de fila + drawer de caso).

**O fato que estreita tudo (ADR-020, Decisão 2):** no ponto de check-out passam a existir **duas ações distintas e separadas** do contratante, com comandos de domínio diferentes:

1. **`ValidarCheckoutService::recusar()`** — **já existe** (SCREEN-064): "Turno ainda não terminou? Recusar check-out" → devolve o turno a `ativo`, motivo **opcional**, reversível, o cronômetro retoma. É o "peça um novo PIN, ele ainda não terminou".
2. **`AbrirDisputaService`** — **novo**: contestar por mérito → `em_disputa`, justificativa **obrigatória**, **irreversível** (não há caminho de volta a `ativo`), pré-autorização permanece bloqueada, a equipe Turni media em até 30 min.

O ADR-020 declara explicitamente que *"qual affordance de UI mapeia para cada uma é decisão do Designer"*. **Como essas duas recusas convivem sem o contratante abrir disputa por engano é o coração desta DDR** — é também o risco que a própria estória nomeia (recusa é momento de tensão; dinheiro dos dois lados em jogo).

Três pontos de produto foram alinhados com o dono **antes** de cristalizar o design (sync da STORY-091, 2026-06-10), e estão registrados nas decisões abaixo: (a) a forma de conviver das duas recusas; (b) o que o profissional vê da justificativa; (c) obrigatoriedade da `nota_admin`.

## Forças (drivers)

- **Persona não-técnica em momento de tensão** (alto): o contratante decide na frente do profissional, com dinheiro em jogo dos dois lados. A ação tem que revelar a consequência **antes** do toque — abrir disputa por engano custa caro (turno congelado, mediação, atrito).
- **Princípio #1 — simplicidade radical** (alto): duas ações "recusar"-parecidas competindo na mesma tela é carga cognitiva e fonte de erro. A tela de validação tem **uma** chamada primária (validar); recusar é secundário e a disputa é o ramo pesado de recusar.
- **Princípio #7 — estados além do feliz são entregáveis** (alto): justificativa vazia, enviando, irreversibilidade, fila vazia/cheia, race entre admins, sem permissão — todos desenhados.
- **Princípio #4 — padronização > criatividade** (alto): reusar o que as 059/060/064/019 já entregaram (`dialog.confirm`, `badge.status` `em_disputa`, `timeline.event`, shell admin, drawer de caso) e só criar componente quando o DS realmente não cobre.
- **ADR-020 / fronteira de papéis** (alto): o profissional é **read-only** na disputa (só notificado — `disputa.md`); o admin resolve com a trilha completa; a resolução `paga_integral` é irreversível e move dinheiro. O design não pode sugerir ações que o domínio não tem.
- **Duas plataformas** (médio-alto, PDR-003): contratante e profissional são **Flutter** (mobile-first com paridade); o admin é **Backoffice Laravel/Livewire desktop-first**. A mesma decisão de DS, render diferente — como na SCREEN-019.
- **SLA público de 30 min** (médio, `disputa.md`/`non-functional.md`): o "30 min" tem que aparecer sem prometer o que o sistema não controla (a mediação é humana).
- **Custo de reversão** (médio): a desambiguação da recusa é padrão de fluxo durável; reabri-la depois de implementada em 094 é caro — daí ser DDR.

## Decisão 1 — Recusa do contratante: **entrada única que desambigua a intenção** (não duas ações irmãs)

No bloco de validação do check-out (SCREEN-064) há **uma** chamada primária — **Validar check-out** — e **uma** entrada secundária de recusa: **"Não vai validar agora? Recusar check-out"** (`button.text`, baixa ênfase). Tocá-la **não recusa nada ainda**: abre uma **folha de escolha de intenção** (`pattern.intent-disambiguation`, novo — Decisão 4) que obriga o contratante a escolher, em linguagem de não-técnico, **por que** não vai validar:

```
[      Validar check-out      ]      ← button.primary (a chamada da tela)

  Não vai validar agora? Recusar check-out   ← button.text (abre a folha)
          │
          ▼  (bottom-sheet mobile / dialog desktop)
  ┌─────────────────────────────────────────────┐
  │ Por que não vai validar?                      │
  │                                               │
  │  ○ O turno ainda não terminou                 │
  │    Volta para “Em andamento”, o tempo continua│
  │    contando. O profissional gera um novo PIN. │
  │                                               │
  │  ○ Tenho um problema com este turno           │
  │    Abre uma disputa: a equipe Turni media em  │
  │    até 30 minutos. Esta ação é irreversível.  │
  │                                               │
  │                    [ Voltar ]  [ Continuar ]  │
  └─────────────────────────────────────────────┘
```

- Escolher **"ainda não terminou"** → confirma → `recusar()` → turno volta a `ativo` (comportamento atual da 064; o motivo segue **opcional**, captado depois ou omitido — sem mudança financeira).
- Escolher **"tenho um problema"** → segue para o **diálogo de disputa** (`dialog.confirm`, variante campo obrigatório — Decisão 4): justificativa **obrigatória** (erro quando vazia, "Continuar/Abrir disputa" desabilitado até ter texto), reforço de **irreversibilidade**, e só então `AbrirDisputaService` → `em_disputa`.

### Opções consideradas

**Opção A — duas ações irmãs de baixa ênfase, lado a lado** ("Recusar check-out" → ativo **e** "Abrir disputa" → em_disputa, ambas `button.text` sob o primário). O gate (justificativa + irreversibilidade) só apareceria no diálogo da disputa.
- Prós: 1 toque a menos para cada caminho; mapeia 1:1 nos dois comandos do ADR-020.
- Contras: **dois verbos de recusa competindo** na mesma dobra — exatamente a carga cognitiva que o Princípio #1 condena e o risco que a estória nomeia. Um contratante apressado pode tocar "Abrir disputa" achando que é "não validar agora". A diferença benigno × irreversível fica só na cor/rótulo de dois links parecidos.

**Opção B — entrada única que desambigua (escolhida).** Uma recusa só; a intenção é escolhida numa folha que descreve a **consequência** de cada caminho antes de seguir.
- Prós: respeita Princípio #1 (uma ação secundária, não duas); força a **leitura da consequência** antes de comprometer (a folha não recusa nada — só pergunta o porquê); separa fisicamente o benigno do irreversível; reduz disputa acidental; reusa `dialog.confirm` para o gate da disputa.
- Contras: **um passo a mais** no caminho da disputa (folha → diálogo). Aceito: a disputa **deve** ser deliberada — fricção aqui é recurso, não defeito (o caminho frequente, validar, segue em um toque).

**Status quo — manter só a recusa→ativo da 064.** Não atende o épico: não há como abrir disputa.

### Avaliação contra os princípios

| Princípio | A (duas irmãs) | **B (entrada única)** | Status quo |
|---|---|---|---|
| 1. Simplicidade radical | ❌ dois "recusar" competindo | ✅ 1 primário, 1 recusa; intenção sob demanda | ✅ mas não entrega disputa |
| 2. Mobile-first com paridade | ✅ | ✅ sheet (mobile) ↔ dialog (desktop) | ✅ |
| 3. Tom profissional | ⚠️ risco de copy ambígua entre dois links | ✅ consequência explícita, sem alarmismo | ✅ |
| 4. Padronização > criatividade | ✅ | ✅ reusa `dialog.confirm`; 1 padrão novo (folha) | ✅ |
| 5. Acessibilidade | ⚠️ dois alvos parecidos confundem leitor de tela | ✅ rádio com descrição, foco gerenciado | ✅ |
| 6. Performance percebida | ✅ | ✅ folha local, sem fetch | ✅ |
| 7. Estados além do feliz | ➖ | ✅ vazio/erro/irreversível desenhados | ❌ não há disputa |

## Decisão 2 — O profissional **não vê** o texto da justificativa; vê um banner read-only de estado

No detalhe do turno (SCREEN-060) em `em_disputa`, o profissional vê um **banner persistente, não-dispensável, read-only** (`banner.status` — Decisão 4), e **nenhuma ação**:

```
┌────────────────────────────────────────────┐
│ ⚠ Valor em disputa                           │
│ O contratante contestou o check-out deste    │
│ turno. A equipe Turni vai mediar em até       │
│ 30 minutos e avisaremos você do desfecho.     │
└────────────────────────────────────────────┘
```

O **texto livre da justificativa do contratante não é exibido ao profissional**. Razão (alinhada com o PO no sync da 091, e coerente com o precedente das 062/064): a justificativa é **insumo da mediação do admin**, não comunicação direta entre as partes — exibir uma acusação não-mediada ao profissional antes de o admin avaliar inflama o atrito e foge ao papel read-only que `disputa.md` lhe dá. É a mesma postura do "motivo da recusa" hoje (fica no audit log do admin, não vaza para o outro lado sem revisão). Nas listas (SCREEN-059), o estado já aparece como seção própria "Em disputa" + selo `⚠ Em disputa` (`error soft`) — **sem mudança**, só reuso.

> **Registro para o PO (cumpre o pedido da STORY-091 §Liberdade técnica):** "o que exatamente o profissional pode ver da justificativa" foi decidido como **não exibir o texto** no MVP. Se a próxima onda quiser dar transparência ao profissional (ex.: após a resolução), é evolução — não reabre esta DDR, abre estória nova.

## Decisão 3 — Caso do admin: fila derivada + drawer de caso com trilha completa; resolução com **`nota_admin` obrigatória**

A superfície do admin vive **dentro do shell do Backoffice** (SCREEN-019 / `preview-backoffice.html`, perfil **admin azul-navy**, desktop-first PDR-003) e reusa o padrão fila→drawer já validado:

- **Fila `/disputas`** (novo item operacional na sidebar, abaixo de "Cadastros pendentes"): lista os turnos em `em_disputa` (fila **derivada do estado**, ADR-020 Decisão 4). Cada item: contratante, profissional, função, **valor**, e **tempo decorrido vs SLA 30 min** com indicador de urgência (ícone+cor+texto, nunca só cor — espelha o SLA da 019): 🟢 `≤ 15 min` · 🟡 `15–30 min` · 🔴 `> 30 min` (SLA estourado). Ação por linha: **Ver caso** (`btn.outline`, secundária) — resolver **só** dentro do caso.
- **Caso (drawer lateral, ~640px):** cabeçalho (partes, função, valor, tempo na fila vs SLA) + **trilha completa em `timeline.event`** agregando, em ordem cronológica, o que `disputa.md`/ADR-020 §Decisão 6 listam: **justificativa do contratante** (em destaque, é a peça central), **chat**, **geofencing** (check-in/out, distância), **checklist**, **cronômetro** (duração), **vaga original** (snapshot) e o histórico de auditoria. É **leitura** — agregação de dados já existentes (ADR-020 não cria contrato de domínio novo).
- **Resolver: pagar integral** (`btn.primary`/sucesso, dentro do caso) → **`dialog.confirm`** com: explicação ("Captura o valor e libera o Pix ao profissional. Ação irreversível."), campo **Nota da decisão — obrigatória** (erro quando vazia, confirmar desabilitado até ter texto) e par Voltar/confirmar. Confirma → chama o comando da api (`ResolverDisputaService`, ADR-020 Decisão 3) → caso sai da fila → toast.

### Conflito resolvido — `nota_admin` obrigatória

A STORY-091 (CA-3) diz `nota_admin` **opcional**; o ADR-020 (Decisão 3) diz que o comando **exige** `nota_admin`. **Decisão (aprovada pelo dono no sync da 091): obrigatória** — alinha com a invariante do comando (ADR-020) e com a trilha de auditoria (`disputa.md`: 100% das disputas registram a decisão e o admin). **Implica ajuste de redação do CA-3 com o PO** (de "opcional" para "obrigatória"); registrado nas Notas do agente da STORY-091 para o PO chancelar a edição do critério (o Designer não edita CA por conta própria).

> **Fora de escopo (ADR-020 Decisão 5):** `paga_parcial` e `sem_pagamento` não existem na UI do MVP — a única resolução desenhada é **pagar integral**. O caso **não** oferece "pagar parcial"/"não pagar"; comunicação externa com as partes é operacional, fora do app.

## Decisão 4 — Impacto no Design System (componentes/padrões)

Tudo reusa o DS; o genuinamente novo é mínimo e entra **nesta operação**:

1. **`pattern.intent-disambiguation` (novo padrão composto → `patterns.md`).** Folha (bottom-sheet mobile / dialog desktop) que, antes de uma ação ramificada de alto custo, pergunta a **intenção** com opções em rádio, cada uma com **descrição da consequência**, e só então segue. Primeiro uso: a recusa do check-out. `Flutter`: `showModalBottomSheet`/`AlertDialog` + `RadioListTile`. Foco no título ao abrir; "Continuar" desabilitado até uma opção escolhida.
2. **`banner.status` (novo componente → `components.md`).** Banner **persistente, não-dispensável, read-only**, de estado do recurso (não é erro recuperável nem gate de ação). Família visual do `banner.gate` (DDR-004) — `*.soft` + ícone + texto, nunca só cor — mas **sem CTA**. Primeiro uso: "valor em disputa" no detalhe do turno do profissional (`error soft`). Consolida o uso informal de "banner" das specs anteriores ao separá-lo do banner de erro recuperável (mid-flow) e do `banner.gate` (bloqueante com CTA).
3. **`dialog.confirm` — variante campo obrigatório (extensão → `components.md`).** O `dialog.confirm` já existe (recusa de check-in/out) com campo **opcional**. Esta operação adiciona a variante de **campo obrigatório** (erro quando vazio, confirmar desabilitado até preencher), usada na **justificativa da disputa** (contratante) e na **nota da resolução** (admin). Mesma anatomia; é extensão, não componente novo.
4. **Reuso sem mudança:** `badge.status` `em_disputa` (`⚠ Em disputa`, `error soft`) e seção "Em disputa" das listas (059); `timeline.event` (060) para a trilha do admin; shell admin / `data-table` / `drawer-detail` / `chip` / `stat-card` / `toast` / `btn.*` (019); `button.primary`/`button.text` (064).

## Decisão (consolidada)

> **A recusa do check-out do contratante é uma entrada única ("Recusar check-out") que abre uma folha de desambiguação de intenção — "ainda não terminou" (→ `ativo`, reversível) × "tenho um problema" (→ disputa, irreversível, justificativa obrigatória) — separando o benigno do pesado e prevenindo disputa por engano (Princípio #1). O profissional vê apenas um banner read-only "valor em disputa — mediação em até 30 min", sem o texto da justificativa (insumo do admin). O admin opera dentro do shell do Backoffice (azul-navy, desktop-first): fila `/disputas` derivada do estado, com tempo decorrido vs SLA 30 min, e caso em drawer com a trilha completa em `timeline.event` + ação "Resolver: pagar integral" com nota obrigatória. Novos no DS: `pattern.intent-disambiguation`, `banner.status`, e a variante campo-obrigatório do `dialog.confirm`; o resto é reuso.**

## Consequências

### Positivas
- O caminho frequente (validar) segue em **um toque**; a disputa exige deliberação proporcional ao seu custo.
- Disputa por engano fica improvável: a consequência é lida **antes** do comprometimento, e a justificativa obrigatória + aviso de irreversibilidade são um segundo gate.
- O profissional tem segurança de que há processo (banner + SLA), sem ser exposto a acusação não-mediada.
- O admin resolve com a trilha completa numa única superfície, reusando o padrão fila→drawer já validado (019).
- DS cresce só o necessário (1 padrão + 1 componente + 1 variante); o resto é reuso.

### Negativas / trade-offs assumidos
- **Um passo a mais** no caminho da disputa (folha → diálogo). Aceito: fricção deliberada num caminho irreversível.
- **`nota_admin` obrigatória** diverge do CA-3 da estória — exige o PO chancelar a edição do critério (registrado).
- O profissional **não** vê a justificativa no MVP — menos transparência, em troca de menos atrito não-mediado. Reversível por estória futura, sem reabrir esta DDR.

### Impacto no Design System
- `patterns.md`: + `pattern.intent-disambiguation` (esta operação).
- `components.md`: + `banner.status`; + variante campo-obrigatório do `dialog.confirm` (esta operação).
- Nenhum token novo — tudo em tokens auditados AA (DDR-001 §6), perfis contratante/admin e cor semântica `error`/`warning`.

### Impacto em telas existentes
- **SCREEN-064:** a recusa benigna passa a viver **dentro** da folha de desambiguação (a entrada "Recusar check-out" deixa de ir direto ao `dialog.confirm` de recusa→ativo). Revisão é da STORY-094, registrada aqui; o comportamento `recusar()→ativo` em si não muda.
- **SCREEN-060:** ganha o `banner.status` de disputa no estado `em_disputa` (STORY-095).
- **SCREEN-059 / SCREEN-019:** **sem mudança** — `em_disputa` já marcado (059); fila/drawer reusam o padrão (019).

## Implementação sugerida (notas para o Programador)

- **Contratante (Flutter, STORY-094):** entrada `recusar-checkout-btn` → `showModalBottomSheet` (mobile) / `AlertDialog` (desktop) com dois `RadioListTile` (`disputa-intencao-ativo` / `disputa-intencao-problema`) + "Continuar" (`disputa-intencao-continuar`, disabled até escolher). Ramo "problema" → `dialog.confirm` campo-obrigatório (`abrir-disputa-dialog`, `abrir-disputa-justificativa-input`, `abrir-disputa-confirmar-btn`) → `POST /api/turnos/{uuid}/abrir-disputa` (`AbrirDisputaService`). Ramo "ativo" → caminho `recusar()` atual.
- **Profissional (Flutter, STORY-095):** `banner.status` no topo da área de conteúdo do detalhe em `em_disputa` (`disputa-banner`), `Semantics(liveRegion: true)` ao aparecer, sem CTA, alvo nenhum (read-only). Lista 059 inalterada.
- **Admin (Livewire/Blade, STORY-096):** item de sidebar `disputas` + tela `screen-disputas` (`data-table` com `disputas-item-{turnoId}`, `disputas-item-{turnoId}-sla`, `disputas-item-{turnoId}-ver`), drawer `disputas-caso` com `timeline.event` (`caso-trilha`), `disputas-caso-resolver` → `dialog.confirm` (`dialog-resolver`, `resolver-nota-input` obrigatório, `dialog-resolver-confirm`) chamando o comando da api (ADR-020 Decisão 3; mecanismo do canal = IDR de implementação). `data-testid`, não `Key()`.
- **SLA visível:** mostrar "há {m} min · SLA 30 min" derivado de `disputa.aberta_em`; o "30 min" é **promessa de mediação**, não contagem regressiva do sistema — copy evita prometer automação.

## Critérios para revisitar

- Se a taxa de disputa por engano (contratante que abre e a equipe reverte) for relevante — reavaliar a fricção da folha (mais/menos passos).
- Se a próxima onda ligar `paga_parcial`/`sem_pagamento` (EPIC-007) — o caso do admin ganha mais resoluções; a folha de resolução vira escolha, não confirmação direta.
- Se a operação pedir que o profissional veja a justificativa (transparência pós-resolução) — estória nova, não reabre esta DDR.
- Se a fila de disputas crescer a ponto de precisar de filtros/paginação pesada — reavaliar o padrão (hoje é volume baixo, SLA 30 min).

## Aprovação humana

| Campo | Valor |
|---|---|
| Apresentado em | 2026-06-10 |
| Aprovado por | Alexandro |
| Data da aprovação | 2026-06-10 |
| Observações do aprovador | "aprovado" — protótipo (`SCREEN-STORY-091-disputa/index.html`) + DDR-005 validados em chat. Direções centrais (entrada única que desambigua · profissional não vê justificativa · nota_admin obrigatória) confirmadas. Inclui a chancela do PO para editar o CA-3 da STORY-091 de "opcional" → "obrigatória". |

> DDR-005 `accepted`. Protótipo navegável em `design/screens/SCREEN-STORY-091-disputa/index.html`. STORY-094/095/096 destravadas (parte de design); seguem bloqueadas pelos respectivos backends (092/093).
