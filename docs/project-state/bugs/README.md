# bugs — defeitos encontrados na plataforma

Este diretório guarda **bugs**: defeitos observados na plataforma que ainda **não foram corrigidos**. É um inventário durável de problemas encontrados em validação (de épico, de sprint, ad-hoc), por usuários, em produção/homologação ou em monitoramento — capturados para triagem, análise e entrada no planejamento de correção.

## Por que existe (e o que NÃO é)

- **É** um lugar durável para anotar defeitos sem perder, permitindo triagem posterior e entrada controlada no planejamento.
- **É** complementar ao `validation/report.md` do épico: o report nasce, fecha o épico e fica como histórico; bugs encontrados nele que não bloquearam aprovação podem virar entries aqui para serem corrigidos depois.
- **Não é** backlog. Bug aqui ainda não tem estória; quando vira estória, status muda para `planned` com link.
- **Não é** fila de incidentes em produção. Incidente operacional ao vivo segue outro fluxo (runbook); só **vira** entry aqui se houver bug subjacente a corrigir.
- **Não é** debt/melhoria. Refator e dívida vivem em outro lugar (a definir quando aparecer); aqui é só **defeito** — algo que **funciona diferente** do especificado/esperado.

## Estrutura

```
project-state/bugs/
├── README.md          ← este arquivo
├── bugs.json          ← índice queryable de todos os bugs
└── items/
    └── BUG-XXX-<slug>.md
```

- `bugs.json` é a fonte de verdade queryable (id, status, severidade, origem, datas, links).
- `items/BUG-XXX-<slug>.md` é o conteúdo descritivo: reprodução, esperado vs observado, impacto, workaround, referências.

## Estados de um bug

```
reported ──► triaged ──► confirmed ──► planned ──► fixed ──► verified
                  │
                  ├──► wont_fix
                  └──► duplicate (aponta para BUG-YYY ou STORY-YYY)
```

| Status | Significado |
|---|---|
| `reported` | Recém-capturado. Ainda não foi reproduzido nem analisado pelo PO. |
| `triaged` | PO leu, classificou severidade, vinculou contexto. Aguarda confirmação/repro. |
| `confirmed` | Reprodução confirmada (PO ou validador conseguiu reproduzir). Pronto para entrar em planejamento. |
| `planned` | Virou estória de correção. Campo `fix_link` aponta para a estória/épico. |
| `fixed` | Estória de correção concluída (`done`). Aguarda verificação independente. |
| `verified` | Verificado em homologação/produção após o fix. Bug encerrado. |
| `wont_fix` | PO decidiu não corrigir (custo > benefício, fora de escopo, comportamento aceitável). `wont_fix_reason` obrigatório. |
| `duplicate` | Mesmo defeito de outro registro. `duplicate_of` obrigatório apontando para `BUG-YYY` ou `STORY-YYY`. |

## Severidade

| Nível | Critério |
|---|---|
| `critical` | Bloqueia uso, perde/corrompe dado, expõe dado, ou impede transação financeira (Pix, contrato, repasse). Vai direto para próximo sprint, mesmo que custe escopo. |
| `high` | Fluxo principal afetado **sem workaround**, ou afeta confiança/segurança percebida (não vaza dado, mas usuário sente). Entra na próxima onda de planejamento. |
| `medium` | Fluxo afetado **com workaround** aceitável, ou fluxo secundário sem workaround. Entra na fila de priorização normal. |
| `low` | Cosmético, edge case raro, inconsistência menor sem impacto operacional. Pode ficar parado até houver janela. |

Severidade é decisão de produto (impacto sobre o usuário), não técnica.

## Origem (de onde veio o bug)

Categorize sempre. Ajuda a priorizar e a melhorar o próprio processo de captura.

| Origem | Significado |
|---|---|
| `validation` | Encontrado em validação formal de épico/estória. Cite `validation/report.md`. |
| `user` | Reportado por usuário (profissional, contratante, suporte). |
| `monitoring` | Sentry, log, alerta. Cite ID do alerta/evento se houver. |
| `po_review` | PO encontrou navegando o produto fora de validação formal. |
| `dev_review` | Programador encontrou implementando outra coisa. |
| `designer_review` | Designer encontrou validando UI contra spec de tela. |
| `e2e` | Teste E2E falhando expôs bug. |

## Como o PO opera a lista de bugs (3 comandos)

Mesmo padrão da wishlist — protocolo completo em `docs/skills/po/references/bugs.md`.

### 1. Listar

> "lista os bugs", "quais bugs temos abertos?", "mostra bugs críticos"

PO lê `bugs.json`, agrupa por status (default) ou severidade (se pedido), apresenta `id · severidade · título · status · origem`. Aplica filtros pedidos.

### 2. Adicionar

> "adiciona um bug", "encontrei um problema em X", "registra: ao clicar Y aparece Z"

PO captura com no máximo 4 perguntas curtas (título, reprodução, esperado vs observado, severidade), cria `BUG-XXX-<slug>.md` com status `reported`, atualiza `bugs.json`.

### 3. Promover para o plano

> "promove o BUG-XXX para correção", "coloca BUG-XXX no planejamento", "vamos corrigir esse"

PO confirma reprodução (passa para `confirmed` se ainda não estiver), cria estória de correção via Fluxo C, vincula `fix_link` no bug, atualiza status para `planned`, atualiza `bugs.json` e `index.json`.

## Numeração

IDs são `BUG-001`, `BUG-002`, … sequenciais e **imutáveis**. Bug `wont_fix` ou `duplicate` **não** libera número.

## Convenções

- Datas em ISO `YYYY-MM-DD`.
- Acentuação portuguesa padrão (UTF-8).
- Slug em kebab-case, ASCII.
- Nunca remova arquivo de bug — para "remover", mude status para `wont_fix` ou `duplicate`.
- Bug com severidade `critical` sem `confirmed` ou `planned` em 24h é alerta de processo — sinalize no próximo status report.
