---
adr_id: ADR-018
slug: uuid-chave-primaria-entidades-dominio
title: UUID como tipo de chave primária das entidades de domínio
status: proposed  # proposed | accepted | superseded | rejected | deferred
decided_at: null
decided_by: arquiteto
approved_by: null
supersedes: null
superseded_by: null
related_adrs: [ADR-000, ADR-001, ADR-007, ADR-009, ADR-013]
related_pdrs: []
related_epics: [EPIC-010]
created_at: 2026-06-03
updated_at: 2026-06-03
---

# ADR-018 — UUID como tipo de chave primária das entidades de domínio

## Contexto

O Turni assumiu, na origem, o desejo arquitetural de **identificadores de entidade como UUID string** — válido também no banco — mas a intenção **nunca foi registrada em ADR**. Vivia como folclore técnico (equivalente ao que o princípio #3 vivia antes da ADR-000). Sob pressão de execução nas SPRINTs W22–W27, as migrations adotaram o default do Laravel (`$table->id()` — `bigIncrements`) e o desejo ficou para trás. Ao fim da W27 a dívida ficou material: ≈27 migrations × 2 apps (`api` e `admin`), 14 models, 17 FKs bigint, 2 colunas polimórficas (`personal_access_tokens.tokenable_id` do Sanctum e `audit_logs.target_id`), constraints únicas materiais em `candidaturas` e `vaga_versoes`, JSON `score_breakdown` em `candidaturas`, e ~8 telas Flutter (`apps/webapp`) consumindo `int?` como tipo de ID.

A SPRINT-2026-W28 (planned, EPIC-003 — Aceite, PIN, Pix) integra Pagar.me sandbox via STORY-056 e passa a usar `external_reference` apontando para IDs de turno/candidatura. A partir desse commit, o sandbox externo guarda referências aos IDs do Turni em webhooks idempotentes — virar o tipo depois exige limpar sandbox e reemitir, custo cresce de forma não-linear. Concluímos que a janela ainda está aberta agora — sem dados de produção, sem integrações externas vivas, validador disponível para re-rodar EPIC-001 e EPIC-002 — e se fecha no commit de STORY-056. Esta ADR existe para **(a)** registrar formalmente a decisão antes que continue como folclore, **(b)** fixar a variante de UUID e o tipo de coluna no Postgres, **(c)** delimitar o escopo (o que muda e o que não muda), **(d)** tratar os polimórficos, **(e)** definir a estratégia de execução (reset vs. conversão), e **(f)** balizar o trabalho da STORY-070 (refactor) e da STORY-071 (Flutter).

As restrições que chegam consolidadas:

- **ADR-000** — PostgreSQL principal, com tipo `uuid` nativo (16 bytes), extensão `pgcrypto` disponível para `gen_random_uuid()` se necessário.
- **ADR-001** — Laravel/Eloquent. Laravel 11+ tem `HasUuids` (v4) e `HasVersion7Uuids` first-class; FK `foreignUuid()` e `uuidMorphs()` nativos no schema builder.
- **ADR-007** — Sanctum SPA + sessão. Coluna `personal_access_tokens.tokenable_id` é polimórfica e referencia o model do User.
- **ADR-009** — modelo de identidade (`users`, `profissional_profiles`, `contratante_profiles`, `admin_audit_log`, `funcoes`, `templates`, `template_versoes`, `aceites_eletronicos`, `cadastro_lembretes`). Tudo bigint hoje.
- **ADR-013** — modelo Vaga/Candidatura/VagaVersao + `audit_logs` (polimórfico em `target_type`/`target_id`) + `notificacoes`. Tudo bigint hoje. Constraints únicas materiais a preservar: `candidaturas (vaga_id, profissional_id)`, `vaga_versoes (vaga_id, versao)`.
- **non-functional.md §Segurança** — não há requisito explícito de "ID não-sequencial" em RNF, mas há requisito de **não enumeração** indireta em listas paginadas e URLs públicas. UUID resolve isso por construção; bigint exige cuidado de produto/UX para esconder ordem.
- **F-NB-1 do EPIC-000** — migrações reversíveis com `migrate:rollback` em homolog. Aplica a este refactor.
- **Volume de dados:** zero em produção; seeders + dados de homolog descartáveis. **Esta ADR assume essa premissa** — se a premissa mudar antes do aceite, a estratégia de execução (Decisão 5) precisa ser reavaliada.

## Forças (drivers) da decisão

- **F1 — Honrar o desejo arquitetural original (registrar antes que vire folclore eterno):** peso **alto**. Princípio não-negociável #5 do PO — "estado registrado, sempre". A intenção é antiga e legítima; a ausência de ADR é a falha a corrigir.
- **F2 — Janela de baixo custo se fechando em W28 (STORY-056 Pagar.me):** peso **alto**. Pagar.me sandbox passará a armazenar `external_reference` para IDs do Turni; depois desse commit, sair de bigint vira limpeza de sandbox + reemissão de webhooks.
- **F3 — Não enumeração de recursos por URL/listagem paginada (segurança por construção):** peso **médio-alto**. UUID elimina a classe de problema "atacante adivinha o próximo ID"; bigint exige disciplina de produto (slug, hash, paginação por cursor) para mitigar.
- **F4 — Federação futura / merges entre ambientes:** peso **médio**. UUID permite gerar IDs em qualquer lado (cliente, worker, fixture) sem colisão; útil para seeders idempotentes, importações, e qualquer cenário futuro multi-tenant ou multi-instância.
- **F5 — Performance de índice B-tree no Postgres:** peso **médio**. UUIDv4 puramente aleatório fragmenta o índice e degrada cache locality (problema conhecido, documentado). UUIDv7 (ordenado por timestamp ms) ou ULID resolve — ordena lexicograficamente e mantém inserção sequencial. **Esta força decide a Decisão 1 (variante).**
- **F6 — Idiomático em Laravel/Eloquent (princípio #4):** peso **médio**. Laravel tem `HasUuids` e `HasVersion7Uuids` first-class, `foreignUuid()`, `uuidMorphs()`. Não exige biblioteca de terceiros.
- **F7 — Custo de refactor agora (humano + risco):** peso **médio**. Estimado 2–3 dias Programador + 0,5 dia Arquiteto + Validador. Crítico mas finito; janela conhecida.
- **F8 — Tamanho da chave (16 bytes vs 8 bytes):** peso **baixo**. Em escala de MVP, a diferença de armazenamento é irrelevante (centenas a milhares de usuários — `business-rules.md`).

---

## Decisão 1 — Variante de UUID

### Opção 1A — UUIDv4 (puramente aleatório, `Str::uuid()` / `HasUuids` do Laravel)
- **Resumo:** v4 é o default histórico. Laravel `HasUuids` gera v4 nativamente. Distribuído uniformemente no espaço — sem ordem temporal.
- **Como atende aos princípios:**
  - ✅ Simplicidade (1): suporte first-class em qualquer lib.
  - ❌ Postgres-first (3): com bilhões de linhas, v4 degrada B-tree e cache locality — não é problema de MVP, mas é problema previsível e gratuito de evitar.
- **Prós:** ubiquidade; sem dependência de relógio; "drop-in" mais fácil.
- **Contras:** ordenação aleatória prejudica clustering de índice e queries tipo "últimos N" que se beneficiariam de paginação por chave ordenada; sem informação temporal embutida.

### Opção 1B — UUIDv7 (RFC 9562, ordenado por timestamp ms — `HasVersion7Uuids` do Laravel)
- **Resumo:** v7 carrega timestamp de 48 bits (ms) nos bits altos + 74 bits aleatórios — lexicograficamente ordenável, mantendo unicidade global. Laravel 11+ tem `HasVersion7Uuids` first-class.
- **Como atende aos princípios:**
  - ✅ Simplicidade (1): trait do Laravel, zero biblioteca extra.
  - ✅ Postgres-first (3): inserções sequenciais no índice B-tree; benefício mensurável em qualquer tabela com alta taxa de insert (notificações, audit log, candidaturas).
  - ✅ Opinativo (4): `HasVersion7Uuids` é o caminho oficial Laravel.
- **Prós:** ordenação por inserção quase grátis (`ORDER BY id` ≈ `ORDER BY created_at` com granularidade ms); cache locality de índice preservada; debug — dá pra inferir "quando" só de olhar o ID; padrão RFC formal (9562 publicada em 2024).
- **Contras:** v7 vaza timestamp — quem ver o ID sabe quando o registro foi criado (já vazamos com `created_at`, mas vale notar); colisões em mesmo ms são possíveis por design — o pool de bits aleatórios (74 bits) torna a probabilidade desprezível para qualquer volume de MVP.

### Opção 1C — ULID (Crockford Base32, ordenado, biblioteca externa)
- **Resumo:** ULID resolve o mesmo problema que UUIDv7 (ordenação por timestamp) com codificação Base32 em vez de hex. 26 caracteres vs. 36 do UUID. Laravel também tem `HasUlids` first-class.
- **Como atende aos princípios:**
  - ✅ Simplicidade (1): trait Laravel idiomático.
  - ⚠️ Postgres-first (3): ULID **não tem** tipo nativo no Postgres — armazenado como `char(26)` (texto) ou `bytea` (16 bytes). Perde o tipo `uuid` nativo e seu operador de igualdade otimizado.
- **Prós:** mais curto na URL/JSON (26 vs 36 chars); ordenável por timestamp como v7.
- **Contras:** sem tipo nativo no Postgres (downgrade vs. UUIDv7); padrão "industry" mas não-RFC; ferramentas de DBA (pgAdmin, DBeaver) tratam como string opaca, não como UUID; ecossistema PHP/Dart trata como string genérica.

### Opção 1D — Snowflake / TSID (inteiro 64 bits ordenado)
- **Resumo:** ID inteiro ordenado por timestamp; menor que UUID; popularizado por Twitter/Discord.
- **Como atende aos princípios:** ❌ não é UUID — o desejo original do Turni é UUID **string** explicitamente. Snowflake é número.
- **Razão da rejeição direta:** viola o desejo arquitetural (F1) que motiva esta ADR. Não cabe revisitar o desejo nesta ADR.

### Decisão 1 — **Optamos pela Opção 1B: UUIDv7.**

`HasVersion7Uuids` do Laravel + tipo `uuid` nativo do Postgres. Ordem temporal nos bits altos preserva cache locality no B-tree, mantém o tipo nativo do banco, e é caminho oficial do framework (princípio #4). v4 é descartado por degradar índice gratuitamente; ULID é descartado por perder o tipo nativo do Postgres; Snowflake é descartado por não ser UUID.

---

## Decisão 2 — Tipo da coluna no Postgres

### Opção 2A — `uuid` nativo do Postgres (16 bytes binários, operador `=` otimizado)
- ✅ Tamanho: 16 bytes (vs. 36 em `char(36)`).
- ✅ Operador `=` e índice B-tree otimizados pelo binário interno.
- ✅ Postgres entende — `EXPLAIN`, queries ad-hoc, ferramentas de DBA.
- ✅ Eloquent `foreignUuid()` e `uuidMorphs()` mapeiam para este tipo nativamente.

### Opção 2B — `char(36)` / `varchar(36)` (texto)
- ❌ 36 bytes + overhead de string.
- ❌ Comparação por string, não otimizada.
- ❌ Postgres trata como texto opaco — sem semântica UUID.

### Decisão 2 — **Optamos pela Opção 2A: `uuid` nativo.**

Sem debate. Postgres tem tipo nativo otimizado; usar `char(36)` seria deixar performance e legibilidade na mesa.

---

## Decisão 3 — Escopo (que tabelas viram UUID)

### Tabelas que **viram UUID** (entidades de domínio)

`users`, `profissional_profiles`, `contratante_profiles`, `admin_audit_log`, `funcoes`, `templates`, `template_versoes`, `aceites_eletronicos`, `cadastro_lembretes`, `vagas`, `vaga_versoes`, `candidaturas`, `audit_logs`, `notificacoes`, `passkeys`.

### Tabelas que **NÃO mudam** (internas do framework / sem valor em mudar)

`cache`, `cache_locks`, `jobs`, `failed_jobs`, `sessions`, `password_reset_tokens`. São tabelas do Laravel default — sem entidade de domínio, sem FK cruzando para fora do framework, custo zero deixar como estão, ganho zero mexer. `personal_access_tokens` mantém seu próprio `id` bigint (é tabela do Sanctum) — mas a coluna polimórfica `tokenable_id` é tratada na Decisão 4.

### Justificativa

A regra é simples: **se é entidade de domínio do Turni, vira UUID; se é mecanismo interno do Laravel sem cruzamento com o domínio, fica como o framework entrega**. Mexer em `cache`/`jobs`/`sessions` traria zero benefício e algum risco de regressão em mecanismos centrais do framework (drivers de fila, store de cache, store de sessão). Princípio #1 (não complicar para dor imaginada).

---

## Decisão 4 — Tratamento das colunas polimórficas

Duas colunas polimórficas no sistema:

1. **`personal_access_tokens.tokenable_id`** (Sanctum) — apontava para `users.id` bigint. Com `users.id` virando UUID, esta coluna precisa virar `uuid`. A migration sobrescreve a coluna que Sanctum cria por default (que é `morphs('tokenable')` — bigint + string). Usaremos `uuidMorphs('tokenable')` na migration do Sanctum (override).
2. **`audit_logs.target_id`** + `target_type` (ADR-013) — aponta polimorficamente para qualquer entidade de domínio. Hoje `morphs('target')` (bigint + string). Vira `uuidMorphs('target')`.

**Padrão geral:** toda coluna polimórfica que possa referenciar entidade de domínio do Turni usa `uuidMorphs()`. Em ADRs futuras que introduzam novas colunas polimórficas, esta ADR é a referência de tipo.

### Decisão 4 — **`uuidMorphs()` em ambas as colunas polimórficas existentes.**

---

## Decisão 5 — Estratégia de execução: reset vs. migration de conversão

### Opção 5A — Reset das migrations (recriar do zero com tipo correto)
- **Resumo:** as migrations existentes são reescritas (ou substituídas) para já usar `$table->uuid('id')->primary()` (ou model com `HasVersion7Uuids` e `$keyType = 'string'`) e `foreignUuid()`. `migrate:fresh --seed` aplica o schema novo. Em homolog, o banco é dropado e recriado.
- **Pré-condição:** zero dados em produção. **Estamos nesse cenário hoje** (2026-06-03 — apenas dados de seeder e homolog descartável).
- **Prós:** simples, limpo, rápido; CI roda sem migração de conversão complexa; histórico de migrations fica coerente com o estado final do schema.
- **Contras:** se a premissa "zero produção" mudar entre o aceite desta ADR e a execução de STORY-070, a estratégia precisa virar 5B — gatilho explícito na STORY-070.

### Opção 5B — Migration de conversão (preservar dados, virar tipo in-place)
- **Resumo:** nova migration adiciona coluna `uuid` paralela, popula com UUIDs gerados, atualiza FKs em duas etapas (dual-write se necessário), troca PK, dropa bigint. Padrão clássico de zero-downtime.
- **Prós:** preserva dados existentes; aplicável em produção viva.
- **Contras:** muitas migrations encadeadas; risco de inconsistência intermediária; demora muito mais; auditável mas mais frágil.

### Decisão 5 — **Optamos pela Opção 5A: reset das migrations.**

Premissa validada: zero produção. STORY-070 abre com check explícito de "ainda zero produção?" — se a resposta mudar, parar e reabrir esta decisão. Em homolog, o procedimento é `php artisan migrate:fresh --seed` no deploy do refactor (registrado no runbook da estória).

---

## Decisão 6 — Geração do UUID: aplicação ou banco?

### Opção 6A — Gerado pela aplicação (`HasVersion7Uuids` do Eloquent)
- ✅ Caminho oficial Laravel; integra com `boot()` do model.
- ✅ Funciona em qualquer ambiente sem extensão Postgres.
- ✅ Permite gerar antes do `INSERT` (útil para `returning` simulado, idempotência, logs).

### Opção 6B — Gerado pelo banco (`DEFAULT gen_random_uuid()` via pgcrypto)
- ✅ Único ponto de verdade; uniformidade garantida.
- ⚠️ Eloquent precisa de configuração extra para ler `id` após `INSERT`.
- ⚠️ Exige extensão `pgcrypto` (já disponível, mas é dependência explícita).
- ❌ `gen_random_uuid()` gera **v4**, não v7. Postgres ainda não tem `uuidv7()` nativo (vem em PG 18+).

### Decisão 6 — **Optamos pela Opção 6A: geração na aplicação via `HasVersion7Uuids`.**

Eloquent gera v7 antes do insert; Postgres armazena o `uuid` recebido. Caminho idiomático Laravel + variante correta (v7).

---

## Decisão 7 — Impacto no frontend Flutter (`apps/webapp`)

### Decisão 7 — **IDs viram `String` em todos os DTOs, services e widgets do `apps/webapp`.**

Hoje `apps/webapp/lib/features/cadastro/cadastro_service.dart` e `completar_cadastro_service.dart` tipam `funcao_id` e relacionados como `int?`. Após refactor, viram `String?` (ou `String` quando não-nullable). O domínio Flutter **não** valida formato UUID — trata como string opaca; quem valida é o backend. Form fields usam `String` no value do dropdown (ex: `CadastroDropdownField<String>` em vez de `<int>`).

Detalhes ficam para STORY-071, mas o tipo escolhido aqui é vinculante.

---

## Matriz comparativa

| Critério (força) | Peso | Opção 1A (v4) | **Opção 1B (v7)** | Opção 1C (ULID) | Opção 1D (Snowflake) |
|---|---|---|---|---|---|
| F1 — Honrar desejo "UUID string" | alto | ✅ é UUID | ✅ é UUID | ⚠️ não é UUID formal | ❌ não é UUID |
| F3 — Não enumeração | médio-alto | ✅ | ✅ | ✅ | ⚠️ ordenado |
| F4 — Federação / geração distribuída | médio | ✅ | ✅ | ✅ | ⚠️ exige worker id |
| F5 — Índice B-tree no Postgres | médio | ❌ fragmenta | ✅ ordenado | ✅ ordenado mas sem tipo nativo | ✅ |
| F6 — Idiomático Laravel | médio | ✅ `HasUuids` | ✅ `HasVersion7Uuids` | ✅ `HasUlids` | ❌ |
| Tipo nativo Postgres | (Decisão 2) | ✅ `uuid` | ✅ `uuid` | ❌ `char(26)` | ❌ |

UUIDv7 vence em todos os critérios materiais sem perder nada relevante.

## Decisão proposta (síntese)

> **Optamos por UUIDv7 como identificador de entidade de domínio, armazenado como `uuid` nativo no PostgreSQL, gerado pela aplicação via `HasVersion7Uuids` do Eloquent. Escopo: 15 tabelas de domínio. Polimórficos viram `uuidMorphs()`. Estratégia de execução: reset das migrations (premissa: zero produção). Flutter trata como `String`.**

## Justificativa

A decisão alinha a força de maior peso (F1 — honrar o desejo original e registrá-lo antes que continue como folclore) com a janela de baixo custo que ainda existe (F2 — Pagar.me ainda não persiste IDs externos). Variante v7 paga zero custo extra em relação a v4 e preserva cache locality de índice (F5) sem comprometer ergonomia. Tipo `uuid` nativo é decisão óbvia no Postgres. Reset de migrations é correto **enquanto** a premissa "zero produção" se sustentar — gatilho explícito na execução. Polimórficos resolvem com `uuidMorphs()` first-class do Laravel. Flutter paga o custo de tipar IDs como `String` — refator mecânico, sem perda de tipagem útil (não há aritmética sobre IDs).

Os trade-offs são reconhecidos: v7 vaza timestamp (já vazamos com `created_at` — não é mudança material); refator custa 2–3 dias do time (custo aceito como menor que o de carregar a dívida pelas próximas 4 sprints).

## Consequências

### Positivas (o que ganhamos)
- **Desejo arquitetural original cumprido e registrado** — o folclore vira ADR; o princípio não-negociável #5 do PO é honrado.
- **Não enumeração por construção** — URLs e listas paginadas não revelam ordem de criação.
- **Cache locality preservada** pela ordenação temporal de v7 — relevante para `notificacoes`, `audit_logs`, `candidaturas` em insert intensivo.
- **Idempotência distribuída facilitada** — geração na aplicação permite emitir ID antes do insert; útil para retries e workers (já usado convencionalmente em e-mail/notificação).
- **Fim do casamento implícito com bigint sequencial** — qualquer integração externa futura recebe um ID opaco que não revela tamanho do banco nem ordem.

### Negativas / trade-offs aceitos
- **Custo de refactor agora** — 2–3 dias Programador + 0,5 Arquiteto + Validador. Aceito porque menor que carregar a dívida.
- **Tamanho de payload JSON** — UUIDs como string (36 chars) ocupam ~9× mais que bigint em JSON. Aceito; volume de MVP irrelevante.
- **Vaza timestamp em v7** — quem decodifica os 48 bits altos sabe quando foi criado. Não é novo (já existe `created_at` na maioria das respostas).
- **Debug por ID fica menos legível** que `User#42` — aceito; logs estruturados continuam ricos.

### Neutras
- Geração na aplicação obriga `HasVersion7Uuids` em todos os models de domínio — disciplina, não bug.
- `personal_access_tokens` mantém PK bigint (Sanctum default) — só `tokenable_id` muda. Coexistência sem problema.

### Para o time
- **Impacto em estórias existentes:** ADR-009 e ADR-013 ganham nota no histórico apontando para ADR-018 (chave primária agora é UUID em todas as tabelas que elas modelaram). Sem supersedir — o modelo lógico (1:1 perfis, snapshot vaga_versoes, polimórfico audit_logs) permanece igual.
- **ADRs/PDRs relacionados que esta decisão limita ou destrava:** qualquer ADR futura sobre nova entidade de domínio assume UUIDv7 + `uuid` Postgres por default — esta ADR é a referência. STORY-055/056/057 (W28) consomem schema novo desde o spike.
- **Necessidade de spike de validação:** **sim** — STORY-069 valida 4 pontos finos antes do refactor:
  1. Comportamento do `HasVersion7Uuids` com replicação/timezone (esperado: nenhum efeito — v7 usa epoch UTC).
  2. Eloquent `whereIn` e `findMany` com lista de UUID — performance e ergonomia (esperado: idem bigint).
  3. Override do schema Sanctum (`personal_access_tokens.tokenable_id`) — caminho oficial documentado.
  4. Override do schema Spatie/Laravel-Passkeys (`passkeys.user_id`) — verificar suporte ou se exige `foreignIdFor` adaptado.

## Plano de verificação

- **Como verificar conformidade:**
  - Migration linter / revisão de PR: nenhuma migration nova de tabela de domínio usa `$table->id()` ou `foreignId()` — só `$table->uuid('id')->primary()` e `foreignUuid()` (ou `uuidMorphs()`).
  - Models de domínio novos têm `use HasVersion7Uuids` e `protected $keyType = 'string'` (já implícito quando trait está presente).
  - Test smoke em CI: `php artisan migrate && php artisan migrate:rollback` segue verde.
- **Sinais de revisão (quando reabrir esta decisão):**
  - **Adoção de Postgres 18+** com `uuidv7()` nativo — pode reabrir Decisão 6 (gerar no banco) por consistência absoluta, embora a aplicação como fonte continue válida.
  - **Necessidade de ID público sequencial visível** (ex: número de protocolo legível) — não substitui a PK; adiciona coluna separada (`numero_publico`). Não reabre esta ADR.
  - **Volume não previsto** (>10M linhas em alguma tabela com inserts massivos) com EXPLAIN mostrando degradação de índice mesmo com v7 — improvável; reabriria estratégia de particionamento, não tipo de PK.
- **Spike de validação proposto:** **STORY-069** — destrava o aceite final desta ADR.

---

## Aprovação humana

> Esta seção é o registro formal do aceite. Não preencher sozinho — preencher quando o humano aprovar no chat ou via PR.

- **Status final:** ⬜ pendente
- **Aprovado por:** —
- **Data:** —
- **Forma do aceite:** —
- **Condicionantes do aceite:** —

### Em caso de rejeição
- **Motivo:** ...
- **Próximos passos sugeridos:** ...

### Em caso de superseding
- **Substituída por:** —
- **Razão da substituição:** —

---

## Histórico

- 2026-06-03 — criada como `proposed` por Arquiteto (rascunho PO), a partir da análise feita em paralelo ao fechamento da SPRINT-2026-W27. Spike de validação dos 4 pontos finos atribuído à STORY-069 da SPRINT-2026-W27.5.
