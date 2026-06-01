# wishlist — pre-backlog do PO

Este diretório guarda **desejos** do produto: ideias, vontades, "seria bom ter" e oportunidades que **ainda não foram priorizadas** para virar épico/estória/spec. É o estágio anterior ao backlog formal — uma fila de captura, não de execução.

## Por que existe (e o que NÃO é)

- **É** um lugar durável para anotar desejos sem perder, para que sessões futuras saibam que existem e o que significam.
- **Não é** roadmap. Item na wishlist não tem promessa de entrega nem prazo.
- **Não é** backlog. Só vira backlog quando o PO promove para estória/spec.
- **Não é** PDR. Decisão durável vai para `decisions/pdr/`. A wishlist guarda intenção e contexto antes da decisão.

## Estrutura

```
project-state/wishlist/
├── README.md          ← este arquivo
├── wishlist.json      ← índice queryable de todos os itens
└── items/
    └── WISH-XXX-<slug>.md
```

- `wishlist.json` é a fonte de verdade queryable (status, id, valor, datas, link para spec se já promovido).
- `items/WISH-XXX-<slug>.md` é o conteúdo descritivo do desejo: problema, motivação, valor, referências, restrições conhecidas, histórico.

## Estados de um item

```
new ──► triaged ──► accepted ──► specced ──► done
                     │
                     └──► rejected
```

| Status | Significado |
|---|---|
| `new` | Recém-capturado. Ainda não foi conversado/refinado. |
| `triaged` | PO leu, entendeu, vinculou contexto. Aguarda decisão de aceitar/rejeitar. |
| `accepted` | PO decidiu que faz sentido. Fica esperando momento certo na roadmap. |
| `specced` | Virou spec/estória/épico. Campo `spec_link` aponta para o artefato resultante. |
| `done` | Implementado e entregue (épico/estória `done`). |
| `rejected` | PO decidiu não fazer. Campo `rejected_reason` registra o porquê. |

## Como o PO opera a wishlist (3 comandos)

O usuário pode pedir uma destas três operações em qualquer sessão de PO. O passo a passo completo do agente está em `docs/skills/po/references/wishlist.md`.

### 1. Listar

> "lista a wishlist", "quais desejos temos?", "mostra os items"

O PO lê `wishlist.json`, agrupa por status, mostra `id · título · status · one-liner`. Se o usuário pedir filtro (`só os new`, `só os accepted`), aplica.

### 2. Adicionar

> "adiciona um desejo", "inclui um item: <coisa>"

O PO faz no máximo 3 perguntas curtas (título canônico, problema/uso, valor esperado) via `AskUserQuestion` apenas quando faltar dado essencial, cria `WISH-XXX-<slug>.md` com status `new`, atualiza `wishlist.json` e confirma com link.

### 3. Transformar em spec

> "transforma WISH-001 em spec", "promove esse desejo"

O PO decide o **destino** do item:

- **Regra de negócio / domínio / fluxo** → vira/atualiza arquivo em `docs/especificacao/` (`business-rules.md`, `domain/*.md`, `flows/*.md`, `screens/*.md`).
- **Trabalho implementável** → vira estória em épico apropriado (Fluxo C da skill PO) ou novo épico se justificar.
- **Decisão de produto** → vira PDR.

Depois preenche `spec_link` no item, muda status para `specced`, atualiza `wishlist.json` e o `index.json` principal (se virou estória/épico/PDR).

## Numeração

IDs são `WISH-001`, `WISH-002`, … sequenciais e **imutáveis**. Item rejeitado não libera o número.

## Convenções

- Datas em ISO `YYYY-MM-DD`.
- Acentuação portuguesa padrão (UTF-8).
- Slug em kebab-case, ASCII (`consulta-cep`, `auto-update-mobile`).
- Nunca remova arquivo de item — para "remover" um desejo, mude status para `rejected` e registre `rejected_reason`.
