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
