# Padrões compostos

> Combinações recorrentes de widgets/componentes para resolver problemas frequentes, baixando a carga cognitiva do usuário não-técnico. Cada padrão entra/evolui por **DDR** quando se torna durável.

A versão 0.1 (fundação EPIC-000) ainda **não cataloga padrões compostos** — a página de boas-vindas (STORY-008) é uma tela estática simples. Os padrões abaixo são **ponteiros nomeados** para EPIC-001 em diante; serão detalhados (com sketch + regras) quando a primeira tela que os exija for especificada.

| Padrão | Quando entra | Composição prevista (widget Flutter) |
|---|---|---|
| `pattern.form` | EPIC-001 (cadastro) | `Form` + `TextFormField` empilhados, validação no blur, CTA no rodapé. |
| `pattern.wizard` | EPIC-001 (cadastro multi-etapa) | `Stepper` (horizontal web / vertical mobile), progresso "Passo N de M". |
| `pattern.listing` | EPIC-002 (feed de vagas) | `ListView.builder` paginado + filtros (`BottomSheet` mobile / lateral web) + estado vazio. |
| `pattern.empty` | EPIC-001+ | `empty-state` com instrução + CTA contextual. |
| `pattern.error` | EPIC-001+ | recuperável (`SnackBar` + "Tentar de novo") vs tela dedicada com saída clara. |

> Regra herdada dos tokens: tabela com >5 colunas vira lista de cards no mobile; estado vazio sempre instrui o próximo passo; erro nunca é só cor.
