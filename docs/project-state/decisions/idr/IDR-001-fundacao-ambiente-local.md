---
idr_id: IDR-001
slug: fundacao-ambiente-local
title: Padrões de fundação do monorepo e do ambiente local em 1 comando
status: accepted
decided_at: 2026-05-27
decided_by: programador
owner_agent: programador-claude
related_story: STORY-006
related_adrs: [ADR-001, ADR-002, ADR-003, ADR-004, ADR-005, ADR-008, ADR-000]
related_idrs: []
supersedes: null
superseded_by: null
created_at: 2026-05-27
updated_at: 2026-05-27
---

# IDR-001 — Padrões de fundação do monorepo e do ambiente local

## Contexto

A STORY-006 montou o repositório de produção do zero conforme ADR-001/002/003 (Laravel api + admin + worker, Flutter WebApp, domínio compartilhado, monorepo poliglota) e o "ambiente local em 1 comando". No caminho, várias decisões de implementação de baixo nível precisaram ser tomadas. Elas não pertencem a um módulo só: **toda estória futura herda essas escolhas** (como rodar testes, onde mora o vendor, qual versão do Postgres, como o domínio é compartilhado). Por isso ficam registradas aqui, e não apenas nas "Notas do agente".

## Decisão

> **Decidi os padrões abaixo como base do ambiente local e do monorepo.** Outras estórias devem segui-los até que um IDR/ADR os substitua.

1. **Comando único = `make` + Docker Compose.** `make setup` (clone → tudo de pé) e `make up` (runs subsequentes). Toda operação de dev tem alvo no `Makefile` (`test`, `lint`, `migrate`, `seed`, `down`, `clean`, `hooks`). Orquestração local é Docker Compose.
2. **Imagem PHP única e compartilhada (`turni/php:dev`)** em `infra/docker/php`, base `php:8.5-cli-alpine` (alvo da ADR-001), com `pdo_pgsql`, `pcntl`, `pcov` e Composer embutido. `api`, `admin` e `worker` reusam a mesma imagem (worker = mesmo código do `api` rodando `queue:work`, ADR-002).
3. **`vendor/` em volume Docker nomeado** (`api_vendor`, `admin_vendor`), não no bind mount. Evita a corrida de extração do Composer sobre o filesystem do macOS e é muito mais rápido. Consequência: `vendor` não fica visível no host (é gitignored de qualquer forma); IDE sem autocompletar a menos que rode `composer install` no host.
4. **Domínio compartilhado via Composer path repository** (`packages/domain`, símlink). Montado no container em `/packages/domain` para que o caminho `../../packages/domain` resolva **igual** no host e no container.
5. **Pest 4 como framework de teste** (ADR-001), adicionado por cima do scaffold do Laravel (que vem com PHPUnit). Smoke test trivial em cada componente desde já (CA-10).
6. **Testes de integração contra PostgreSQL real**, em banco isolado **`turni_test`** criado por script em `infra/docker/postgres/initdb/`. Nunca SQLite/in-memory (ADR-000). `RefreshDatabase` recria o schema do banco de teste, sem tocar o banco de dev (`turni`).
7. **Cobertura via PCOV** com `pcov.directory=/app` (o default `/app/app` deixaria `database/` fora). `<source>` do phpunit inclui `app` + `database/seeders`. Gate `--min=80` no `api`.
8. **PostgreSQL `18-alpine`** com o volume montado em `/var/lib/postgresql` (a imagem 18+ guarda dados em subpasta versionada — montar em `/data` quebra o boot). Porta publicada no host default **5433** (evita conflito comum na 5432; a interna é sempre 5432).
9. **Log JSON em stdout sem código**: `LOG_CHANNEL=stderr` + `LOG_STDERR_FORMATTER=Monolog\Formatter\JsonFormatter` (ADR-008, paridade dev↔prod).
10. **Migrações: mantidos os defaults do framework** (`users`, `cache`, `jobs`). `jobs` é exigida pela fila driver `database` (ADR-002); `users` é a base do seed de admin (CA-7). **Sem tabelas de domínio Turni** ainda — entram no EPIC-001.
11. **Hook de pré-push via `git core.hooksPath=scripts/hooks`** (versionado, instalado por `make hooks`). Roda detector de segredos mínimo + suíte completa + cobertura.

## Por quê

Cada escolha segue um princípio ou uma ADR: imagem/volume/Compose servem o "1 comando" (princípio #6) com o mínimo de peças; Pest e Postgres-real seguem ADR-001/000 e a disciplina de testes do PO; PCOV é o caminho leve para a "medição de cobertura" exigida; manter os defaults do Laravel honra "seguir o framework opinativo" (princípio #4) e evita modelagem de domínio fora de hora (KISS). O volume de `vendor` resolve um problema concreto e reprodutível (corrida de extração no macOS) que, sem registro, cada agente reencontraria.

## Alternativas consideradas

- **`composer install` direto no bind mount** (sem volume nomeado): descartado — corrida de extração intermitente no macOS (`Failed to open directory` no `vendor`), além de lento.
- **SQLite em testes**: descartado — ADR-000 exige Postgres real; mock de banco esconde divergência de schema/SQL.
- **PHPUnit (default do scaffold) em vez de Pest**: descartado — ADR-001 fixa Pest como padrão.
- **PostgreSQL 17** (convenção de mount antiga, mais simples): viável, mas optei pela 18 (release estável mais recente, espírito da ADR-001) documentando a convenção de mount nova.

## Consequências

### Para outros agentes
- Escreva testes em **Pest**; testes de integração assumem **Postgres `turni_test`** disponível (suba via `make test-*` ou `docker compose up -d postgres`).
- Não reintroduza `vendor` no bind mount; use os volumes nomeados.
- Novas migrações de domínio entram a partir do EPIC-001 — siga a organização padrão do Laravel (`database/migrations`).
- Para um novo serviço PHP, **reuse `turni/php:dev`**; não crie imagem nova sem motivo.
- Cobertura nova deve cair sob `pcov.directory=/app`; adicione o diretório ao `<source>` do phpunit do app.

### Para o projeto
- +1 imagem Docker base compartilhada; +2 volumes nomeados de vendor.
- Build da imagem PHP compila `pcov`/`pdo_pgsql` (custo one-time de ~2 min; depois cacheado).
- `make clean` (`down -v`) apaga os volumes de vendor — exige `composer install` no próximo `setup` (já coberto pelo `make setup`).

### Trade-offs aceitos
- `vendor` fora do host reduz a ergonomia de IDE local (mitigável com `composer install` no host por quem quiser).
- Porta default 5433 diverge do 5432 padrão — documentado no README e no `.env.example`.

## Como verificar

- `make setup` numa máquina limpa sobe api+admin+webapp+postgres+pagarme-mock saudáveis (CA-2).
- `make test` roda verde com cobertura ≥ 80% no `api`.
- `docker compose exec postgres psql -U turni -l` mostra `turni` e `turni_test`.
- Logs dos apps saem em JSON (uma linha por evento) no stdout do container.
