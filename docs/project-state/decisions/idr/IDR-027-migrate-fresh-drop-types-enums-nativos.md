---
idr_id: IDR-027
slug: migrate-fresh-drop-types-enums-nativos
title: migrate:fresh exige --drop-types por causa dos enums nativos do Postgres
status: accepted
decided_at: 2026-06-03
decided_by: programador
owner_agent: claude-opus-4-8
related_story: STORY-070
related_adrs: [ADR-018, ADR-013]
related_ddrs: []
related_idrs: []
supersedes: null
superseded_by: null
created_at: 2026-06-03
updated_at: 2026-06-03
---

# IDR-027 — `migrate:fresh` exige `--drop-types` (enums nativos do Postgres)

## Contexto

A STORY-070 (refactor UUIDv7) trocou as PKs para `uuid` e definiu, no runbook backend §5, o reset de
homolog como `php artisan migrate:fresh --seed --force`. Ao validar localmente o `migrate:fresh --seed`
(CA-4), o comando falhou **antes** de qualquer questão de UUID:

```
SQLSTATE[42710]: Duplicate object: 7 ERROR:  type "vaga_estado" already exists
```

Três tabelas de domínio (STORY-044/STORY-053) criam **tipos enum nativos** via `DB::statement` —
`vaga_estado`, `candidatura_estado`, `notificacao_tipo` — em vez de `varchar`, por decisão da ADR-013
(Decisão 4/CA-4). O `migrate:fresh` do Laravel chama `db:wipe`, que por padrão dropa **tabelas, views e
sequences, mas NÃO tipos definidos pelo usuário** — o drop de tipos só acontece com a flag
`--drop-types`. Logo, num banco que **já tem** esses enums (homolog persistente, ou qualquer DB local que
já rodou as migrations uma vez), o `migrate:fresh` recria as tabelas mas esbarra no `CREATE TYPE` de um
tipo que sobreviveu ao wipe.

Não é um bug introduzido pelo UUID — é uma característica latente do par "enum nativo + migrate:fresh"
que só apareceu agora porque a STORY-070 é a **primeira** vez que `migrate:fresh` roda contra um homolog
populado (estratégia de reset, Decisão 5 da ADR-018). O spike (STORY-069) validou o mecanismo do UUID com
tabelas temporárias, não exercitou um `migrate:fresh` do schema real.

## Decisão

> **Todo `migrate:fresh` do app `api` usa `--drop-types`.** O alvo `make fresh` passa a incluir a flag, e
> o reset único de homolog da STORY-070 (runbook backend §5, passo 2) também:
> `php artisan migrate:fresh --seed --force --drop-types`.

O `db:wipe --drop-types` remove os enums junto com as tabelas; o `up()` das migrations os recria limpos.
O `down()` de cada migration de enum já dropa o tipo (`DROP TYPE IF EXISTS ...`), então
`migrate:rollback` permanece simétrico (F-NB-1) sem precisar da flag — ela só importa para o caminho
`fresh`/`wipe`, que não chama `down()`.

`apps/admin` **não** tem tipos enum (não modela vaga/candidatura/notificação), então `--drop-types` é
no-op lá; mantemos a flag por uniformidade quando o fresh é exercitado contra o DB de teste do admin.

## Alternativas consideradas

- **Converter os enums para `varchar` + CHECK:** reabriria a ADR-013 (Decisão 4 escolheu enum nativo de
  propósito) e está fora do escopo da STORY-070. Rejeitada.
- **`db:wipe` manual antes do migrate no deploy:** mais passos, mesmo efeito que `--drop-types`. A flag é
  o caminho idiomático do framework.
- **Deixar como está e documentar "rode migrate:fresh só em DB limpo":** frágil — o homolog da STORY-070 é
  justamente um DB **populado**. Rejeitada.

## Consequências

- `make fresh` volta a ser idempotente em qualquer estado do DB local (antes, um 2º fresh quebrava).
- O reset de homolog da STORY-070 (CA-9) usa `--drop-types`; sem ele o deploy do refactor falharia no
  `CREATE TYPE`.
- Qualquer migration futura que introduza um tipo nativo (enum/composite/domain) herda esta regra: o
  `down()` precisa dropar o tipo, e o caminho `fresh` precisa de `--drop-types`. ADR-013 ganha esta nota
  operacional via este IDR.

## Verificação

- `migrate:fresh --seed --force --drop-types` no `api` sobe schema novo (UUID) + seed verde — CA-4.
- `migrate:rollback` + `migrate:fresh` simétricos no `api` (F-NB-1) — verdes localmente.
- `make fresh` documentado com o porquê inline + ponteiro para este IDR.
