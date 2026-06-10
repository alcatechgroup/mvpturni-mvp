# Padrões compostos

> Combinações recorrentes de widgets/componentes para resolver problemas frequentes, baixando a carga cognitiva do usuário não-técnico. Cada padrão entra/evolui por **DDR** quando se torna durável.

A versão 0.1 (fundação EPIC-000) ainda não catalogava padrões compostos. A partir do EPIC-012, o catálogo começa a ser preenchido com os padrões já decididos por DDR; os demais seguem como **ponteiros nomeados** até a primeira tela que os exija ser especificada.

| Padrão | Quando entra | Composição (widget Flutter) | Estado |
|---|---|---|---|
| `pattern.navigation` | EPIC-012 (shell) | **Shell adaptativo** `NavigationSuiteScaffold`: `NavigationBar` (mobile) → `NavigationRail` (tablet) → `NavigationDrawer` (desktop), pintado no chrome do perfil. Ver **DDR-003**. | **decidido (DDR-003)** |
| `pattern.form` | EPIC-001 (cadastro) | `Form` + `TextFormField` empilhados, validação no blur, CTA no rodapé. | ponteiro |
| `pattern.wizard` | EPIC-001 (cadastro multi-etapa) | `Stepper` (horizontal web / vertical mobile), progresso "Passo N de M". | ponteiro |
| `pattern.listing` | EPIC-002 (feed de vagas) | `ListView.builder` paginado + filtros (`BottomSheet` mobile / lateral web) + estado vazio. | ponteiro |
| `pattern.empty` | EPIC-001+ | `state.empty` (`TurniEmptyState`): ícone + título + mensagem que instrui o próximo passo + CTA contextual. Ver abaixo. | **decidido (STORY-079)** |
| `pattern.error` | EPIC-001+ | recuperável (`state.error` `TurniRetryState`: ícone + texto + "Tentar de novo") vs não-recuperável (`state.empty` com ícone de bloqueio + saída para um destino do shell). Ver abaixo. | **decidido (STORY-079)** |
| `pattern.loading` | EPIC-001+ | `state.loading` (`TurniSkeletonList`/`TurniSkeletonCard`/`TurniSkeletonBox`): skeleton/placeholder no formato do conteúdo que vem, no lugar de spinner solto. Ver abaixo. | **decidido (STORY-079)** |
| `pattern.gate-avaliacao` | EPIC-004 (avaliação recíproca) | `banner.gate` **bloqueante proativo** no topo do destino onde a ação vive; conteúdo segue visível; CTA "Avaliar agora" deep-linka ao turno pendente. Ver **DDR-004** / **ADR-019**. | **decidido (DDR-004)** |
| `pattern.intent-disambiguation` | EPIC-005 (disputa) | Folha (`showModalBottomSheet` mobile / `AlertDialog` desktop) que, antes de uma ação **ramificada de alto custo**, pergunta a **intenção** com `RadioListTile` (cada opção com descrição da consequência) e só então segue. 1º uso: recusa do check-out (benigno → `ativo` × disputa → `em_disputa`). Ver **DDR-005**. | **decidido (DDR-005)** |

> Regra herdada dos tokens: tabela com >5 colunas vira lista de cards no mobile; estado vazio sempre instrui o próximo passo; erro nunca é só cor.

---

## `pattern.navigation` — shell de navegação global

> Decidido em **DDR-003** (`decisions/ddr/DDR-003-shell-de-navegacao-global.md`). Protótipo navegável: `design/screens/SCREEN-STORY-077-app-shell/index.html`.

**Problema.** Dar a Profissional (mobile) e Contratante (desktop) um mapa coerente do produto sem que cada tela reinvente a sua porta de entrada.

**Composição.** Um **único shell adaptativo** que troca a forma de navegação pelo breakpoint do DDR-001 §5.6, mantendo **os mesmos destinos e a mesma ordem** — só muda a forma:

| Breakpoint | Widget | Forma |
|---|---|---|
| `bp.compact` (0–599) | `NavigationBar` (inferior) + `AppBar` (título + sino) | primária do Profissional |
| `bp.medium`/`bp.expanded` (600–1199) | `NavigationRail` (estende rótulos no expanded) | tablet |
| `bp.large` (≥1200) | `NavigationDrawer` persistente + header de conteúdo | primária do Contratante |

```
mobile                       desktop
+--------------------+       +----------+----------------------+
| Vagas          🔔 |       | TURNI.   | Minhas vagas   🔔 ☾ ◑|
|                    |       | Contrat. |                      |
|   [conteúdo]       |       | ⊙ Vagas  |    [conteúdo]        |
|                    |       | ▸ Turnos |                      |
+--------------------+       | ▸ Perfil |                      |
| [⊙Vagas][Turnos][P]|       | [+ Nova vaga]                   |
+--------------------+       | ⏻ Sair   |                      |
                             +----------+----------------------+
```

**Regras.**
- **Destinos por papel** (derivados das telas entregues, sem inventar tela): Profissional = **Vagas · Turnos · Perfil**; Contratante = **Vagas · Turnos · Perfil**. Crescem acrescentando item à lista, sem redesenho.
- **Chrome por perfil** em todos os breakpoints (DDR-001 §2.2): Profissional `#1B2E1F`, Contratante `#3D2A0E` (escuro nos dois temas).
- **Estado ativo:** indicador `accent.soft` + rótulo no acento de tema escuro do perfil (`#5FA37C` / `#D4A95C`).
- **Notificações = sino** na barra superior (badge), **não** é destino. **"Nova vaga" = FAB/ação** do Contratante, **não** é destino.
- **Drill-downs** (detalhe de vaga/turno, candidatos, editar) empilham **dentro** do destino ativo e mantêm o shell.
- **Acessibilidade:** alvos ≥48dp, foco visível (anel `accent`), teclado, todo destino com rótulo textual; sino com `Semantics`/`tooltip`.

---

## `pattern.empty` / `pattern.error` / `pattern.loading` — estados padrão

> Decididos em **STORY-079** (EPIC-012). Implementação: `apps/webapp/lib/ds/components/state_views.dart`. Antes, cada tela reimplementava o seu `_VazioView`/`_ErroView`/`_SkeletonCard`; agora os três são componentes do DS consumidos por todas as listas (feed, minhas vagas, candidatos, turnos, notificações).

**Problema.** Estado vazio, de erro e de carregamento são onde a confiança do usuário não-técnico se ganha ou se perde. Tratados ad-hoc, cada tela comunica "vazio/erro/travou" de um jeito — carga cognitiva e inconsistência.

**Regras herdadas dos tokens (DDR-001).** "Estado vazio sempre instrui o próximo passo"; "erro nunca é só cor" (sempre ícone + texto). Os três componentes nascem AA: texto `text.strong`/`text.muted`, alvos de CTA ≥48dp.

### `pattern.empty` — vazio (`TurniEmptyState`)

Centralizado: **ícone** (contornado, neutro) + **título** curto + **mensagem** que instrui o próximo passo (ou o que esperar) + **CTA contextual opcional**. A `message` nunca é só "vazio" — diz o que fazer.

- **Lista vazia "de verdade"** (nunca houve conteúdo): título + próximo passo + CTA (ex.: "Você ainda não publicou vagas" → *Publicar vaga*).
- **Vazio por filtro** (há conteúdo, o filtro escondeu): variante leve, só mensagem + atalho para limpar o filtro — não usa o `TurniEmptyState` cheio (é transitório).

### `pattern.error` — erro

- **Recuperável** (`TurniRetryState`): ícone `error_outline` + título "Não foi possível carregar …" + linha de apoio ("Verifique sua conexão.") + botão **"Tentar de novo"**, que **re-dispara a mesma ação de carga** da tela. É o padrão para falha de fetch.
- **Não-recuperável** (sem retry): reusa `TurniEmptyState` com ícone de bloqueio (`lock_outline`) e um **CTA de saída** para um destino do shell (ex.: RBAC cruzado → "Voltar ao início"; recurso inexistente → "Voltar às minhas vagas"). Mesmo arranjo visual do vazio; muda ícone, copy e a ação.
- **Erro inline/mid-flow** (dentro de uma tela já populada — gerar PIN, validar check-in, cronômetro) permanece um **banner** recuperável local com "Tentar de novo"; é um micro-padrão distinto do estado de tela inteira e não foi unificado nesta estória.

### `pattern.loading` — carregamento (`TurniSkeletonList` + `TurniSkeletonCard`/`TurniSkeletonBox`)

Skeleton/placeholder no **formato do conteúdo que vem** (card de lista, linha com avatar), repetido ~3×, no lugar de spinner solto. Estático (sem animação — mesma leitura nos dois temas). `ExcludeSemantics` (não anuncia ao leitor de tela). `TurniSkeletonBox` é o primitivo (barra/círculo); `TurniSkeletonCard` é o card de 3 linhas; `TurniSkeletonList` repete o item com o espaçamento padrão e aceita um `itemBuilder` para formatos diferentes (ex.: linha com avatar das notificações/candidatos).

**Convenção de `key`.** Os componentes não fixam `Key` — a tela passa a sua (`feed-vazio`, `turnos-erro-banner`, `*-retry-btn`, `*-skeleton`), preservando os seletores de teste/E2E.

---

## `pattern.gate-avaliacao` — gate bloqueante de avaliação

> Decidido em **DDR-004**; lógica em **ADR-019** (Decisão 5) e `flows/avaliacao-reciproca.md`. Componente: `banner.gate`. Protótipo: `design/screens/SCREEN-STORY-084-avaliacao-e-perfil/index.html` (tela "Gate").

**Problema.** A avaliação recíproca é obrigatória e bloqueante (PDR-005): o profissional não se candidata e o contratante não publica nova vaga enquanto houver avaliação pendente. Bloquear **só na hora** do toque ("tap → parede") frustra o usuário não-técnico; bloquear a tela inteira esconderia o feed, que deve seguir visível.

**Composição.** Um **banner proativo** (`banner.gate`) no **topo do destino** onde a ação bloqueada vive, abaixo do header e acima do conteúdo:

- **Profissional** → destino **Vagas/feed**: "Avalie seu último turno para se candidatar." + CTA "Avaliar agora".
- **Contratante** → destino **Nova vaga / Minhas vagas**: "Avalie seu último turno para publicar uma nova vaga." + CTA "Avaliar agora".

**Regras.**
- **Bloqueia a ação, não a visibilidade.** O feed/lista continua visível e rolável; só a ação (candidatar/publicar) é barrada (fluxo §gate).
- **Cor `warning` soft + ícone + texto** (tokens §4 — nunca só cor); `Semantics(liveRegion: true)` ao aparecer.
- **Não dispensável** — é bloqueio, não aviso. Some sozinho quando a última pendência do papel é resolvida (motor recomputa ≤1s — ADR-019).
- **CTA deep-linka** ao `turno_id` da pendência mais antiga (devolvido pelo serviço com `gate_avaliacao`) → tela de avaliação (SCREEN-084 T1/T2).
- **Reativo (fail-secure):** se o usuário tentar a ação assim mesmo, o serviço devolve `gate_avaliacao` (nunca código cru ao usuário) e o app realça o banner / leva à avaliação.
- **Editar/cancelar vaga existente NÃO é bloqueado** — o gate é sobre *publicar nova* (ADR-019).

**Acessibilidade.** CTA ≥48dp, foco visível; `error.soft` na variante "ação tentada" mantém ícone + texto.

---

## `pattern.intent-disambiguation` — desambiguação de intenção

> Decidido em **DDR-005** (`decisions/ddr/DDR-005-disputa-recusa-banner-caso.md`). 1º uso: recusa do check-out do contratante (SCREEN-091/094). Protótipo: `design/screens/SCREEN-STORY-091-disputa/index.html`.

**Problema.** Uma mesma entrada de UI ("não vou validar") leva a **dois caminhos** com custos muito diferentes — um **benigno e reversível** (turno volta a `ativo`, "ainda não terminou") e um **pesado e irreversível** (abre disputa, `em_disputa`, mediação de 30 min). Oferecer os dois como ações irmãs lado a lado faz dois verbos parecidos competirem (carga cognitiva do não-técnico, Princípio #1) e convida ao erro caro (abrir disputa por engano).

**Composição.** Uma **entrada única** de baixa ênfase (`button.text`) abre uma **folha** que **não executa nada** — só pergunta a **intenção**:

```
[      ação primária      ]              ← a chamada da tela segue em 1 toque

  <entrada única secundária> ────┐ (button.text)
                                 ▼  bottom-sheet (mobile) / AlertDialog (desktop)
  ┌──────────────────────────────────────┐
  │ <pergunta de intenção>                │
  │  ○ <opção benigna>                    │  RadioListTile + descrição da consequência
  │  ○ <opção de alto custo (irreversível)│  RadioListTile + descrição da consequência
  │                [ Voltar ] [ Continuar ]│  Continuar disabled até escolher
  └──────────────────────────────────────┘
```

**Regras.**
- A folha **não comete a ação** — só captura a intenção. "Continuar" desabilitado até uma opção ser escolhida.
- Cada opção descreve a **consequência** em linguagem de não-técnico (o que muda, se é reversível, o prazo).
- O ramo de **alto custo** segue para um **`dialog.confirm` (variante campo obrigatório)** que reforça a irreversibilidade e exige o dado (justificativa) — segundo gate.
- O ramo **benigno** confirma e executa direto.
- **Flutter:** `showModalBottomSheet` (compact) / `AlertDialog` (≥medium) + `RadioListTile`; foco inicial no **título** (nunca num rádio); ←/→ entre opções, Enter confirma; ESC/Voltar fecha sem efeito.
- **Acessibilidade:** label + descrição de cada opção lidos juntos; alvos ≥48dp; não usar **só cor** para distinguir os caminhos (o texto da consequência carrega o significado).
