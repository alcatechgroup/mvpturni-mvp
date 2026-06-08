# Padrões compostos

> Combinações recorrentes de widgets/componentes para resolver problemas frequentes, baixando a carga cognitiva do usuário não-técnico. Cada padrão entra/evolui por **DDR** quando se torna durável.

A versão 0.1 (fundação EPIC-000) ainda não catalogava padrões compostos. A partir do EPIC-012, o catálogo começa a ser preenchido com os padrões já decididos por DDR; os demais seguem como **ponteiros nomeados** até a primeira tela que os exija ser especificada.

| Padrão | Quando entra | Composição (widget Flutter) | Estado |
|---|---|---|---|
| `pattern.navigation` | EPIC-012 (shell) | **Shell adaptativo** `NavigationSuiteScaffold`: `NavigationBar` (mobile) → `NavigationRail` (tablet) → `NavigationDrawer` (desktop), pintado no chrome do perfil. Ver **DDR-003**. | **decidido (DDR-003)** |
| `pattern.form` | EPIC-001 (cadastro) | `Form` + `TextFormField` empilhados, validação no blur, CTA no rodapé. | ponteiro |
| `pattern.wizard` | EPIC-001 (cadastro multi-etapa) | `Stepper` (horizontal web / vertical mobile), progresso "Passo N de M". | ponteiro |
| `pattern.listing` | EPIC-002 (feed de vagas) | `ListView.builder` paginado + filtros (`BottomSheet` mobile / lateral web) + estado vazio. | ponteiro |
| `pattern.empty` | EPIC-001+ | `empty-state` com instrução + CTA contextual. | ponteiro |
| `pattern.error` | EPIC-001+ | recuperável (`SnackBar` + "Tentar de novo") vs tela dedicada com saída clara. | ponteiro |

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
