# project-state — estado vivo do Turni

Este diretório é o **banco de dados em arquivos** do projeto Turni. Tudo que existe, está em andamento ou foi decidido vive aqui — versionado em git, queryable via `index.json`.

## Como navegar

- **`index.json`** — a única fonte de verdade queryable. Reflete o estado atual de tudo. Se ele não bate com a realidade, é bug do PO.
- **`product/`** — fundação durável: visão, personas, métrica de norte. Muda raramente, com PDR.
- **`roadmap/`** — onda atual (detalhada) e próxima (rascunho).
- **`epics/`** — épicos da onda atual e seus arquivos (`epic.md`, `stories/`, `validation/`).
- **`sprints/`** — sprints abertos e fechados, um arquivo por sprint.
- **`decisions/`** — decisões duráveis, separadas por dono:
  - `pdr/` — Product Decision Records (PO)
  - `adr/` — Architecture Decision Records (Arquiteto)
  - `idr/` — Implementation Decision Records (Programador)
  - `ddr/` — Design Decision Records (Designer)
- **`reports/`** — status reports para humanos, datados.

## Regras

1. Mudou estado → atualiza `index.json` na mesma operação.
2. Decisão durável → tem PDR/ADR/DDR/IDR registrado. Sem registro, a decisão não existe.
3. Estória só é `done` quando atende sua DoD e passa pela validação do épico.
4. Épico só é `done` quando o validador entrega `validation/report.md` aprovado.

Detalhe do esquema: `docs/skills/po/references/indexing.md`.
