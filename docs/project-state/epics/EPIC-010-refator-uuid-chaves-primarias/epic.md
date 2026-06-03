---
epic_id: EPIC-010
slug: refator-uuid-chaves-primarias
title: Refatoração transversal — UUID nas chaves primárias das entidades de domínio
wave: WAVE-2026-01
status: ready
owner_role: po
created_at: 2026-06-03
updated_at: 2026-06-03
target_completion: 2026-06-07  # janela curta — entre W27 (em fechamento) e W28 (planned)
related_adrs: [ADR-018]
related_epics: [EPIC-001, EPIC-002]
---

# EPIC-010 — Refatoração transversal: UUID nas chaves primárias

> **Natureza deste épico:** é um **épico de refatoração transversal**, não de produto. Não entrega valor diretamente ao usuário final — entrega uma **base estrutural** que sustentará os EPIC-003 em diante sem dívida acumulada. Existe porque um desejo arquitetural antigo (IDs como UUID string, válido também no banco) ficou para trás durante a execução dos EPIC-001 e EPIC-002, e a janela para corrigi-lo a custo baixo está se fechando antes do início da SPRINT-2026-W28 (EPIC-003 — Pagar.me + Pix).

## Por que existimos (problema)

O Turni assumiu, na origem, o desejo arquitetural de **IDs de entidade como UUID string** (incluindo a representação no PostgreSQL). Esta intenção **nunca foi registrada em ADR** — viveu como folclore técnico, equivalente ao que aconteceu com o princípio #3 (Postgres-first) antes da ADR-000. Na pressão de execução das W22–W27, as migrations adotaram o padrão default do Laravel (`$table->id()` — `bigIncrements`) e o desejo ficou para trás.

Ao fim da SPRINT-2026-W27 o débito materializou-se em escala não-trivial: ~27 migrations (× 2 apps — `api` e `admin`), 14 models, 17 FKs bigint, 2 colunas polimórficas (`personal_access_tokens.tokenable_id` do Sanctum e `audit_logs.target_id`), constraints únicas materiais em `candidaturas` e `vaga_versoes`, JSON `score_breakdown` em `candidaturas`, e ~8 telas Flutter assumindo `int?` como tipo de ID. A próxima sprint (W28, EPIC-003) introduz a integração Pagar.me com `external_reference` apontando para IDs do Turni (STORY-056) — a partir desse commit, o sandbox externo passa a guardar referências aos IDs atuais e o custo de virar o tipo cresce de forma não-linear (limpeza de sandbox + reemissão de webhooks idempotentes).

Sem corrigir agora, a dívida atravessa todos os EPICs restantes da WAVE-2026-01. Corrigir agora cabe em uma sprint pequena porque **não há dados de produção** (zero) e **nenhum sistema externo** ainda referencia IDs do Turni.

## Resultado esperado (outcome)

Ao fim deste épico, **todas as entidades de domínio do Turni têm chave primária do tipo `uuid` no PostgreSQL** (representado como `string` em PHP/Dart), com FKs idem, polimórficos coerentes (`uuidMorphs()`), constraints únicas preservadas, seeders/factories/testes verdes em ambos os apps Laravel (`apps/api` e `apps/admin`), e o WebApp Flutter (`apps/webapp`) consumindo IDs como `String` em DTOs, services e UI.

## Métrica de sucesso

- **Métrica primária:** ADR-018 `accepted`; suíte completa de testes (Pest + integration_test + Playwright smoke) verde em CI; `php artisan migrate` + `php artisan migrate:rollback` simétricos em homolog (F-NB-1 do EPIC-000 quitado para a nova base); zero referência a `bigint`/`int? id` em código de domínio (não-Laravel-default).
- **Métrica de qualidade:** zero regressão no caminho coberto pelas validações dos EPIC-001 e EPIC-002 (validador re-roda as checklists das STORY-025 e STORY-054 em homolog após o refactor).

## Entregável visível no fim do épico

- [ ] ADR-018 `accepted` em `decisions/adr/ADR-018-uuid-chave-primaria-entidades-dominio.md`.
- [ ] Banco Postgres em homolog com colunas `id`/FKs em tipo `uuid` nas tabelas de domínio.
- [ ] `apps/api` e `apps/admin` rodando com schema novo; testes verdes em CI.
- [ ] `apps/webapp` Flutter compilando e rodando integration_test verde com IDs `String`.
- [ ] Relatório do validador em `validation/report.md` cobrindo: re-run dos fluxos do EPIC-001 (pré-cadastro PF/MEI/PJ, fila de aprovação, welcome, completar cadastro, AceiteEletronico imutável) e do EPIC-002 (publicar vaga, feed com match, candidatura em 1 toque, painel, edição material com snapshot, notificações).

## Fora de escopo (explicitamente)

- **Mudar tabelas internas do Laravel** (`cache`, `jobs`, `sessions`, `password_reset_tokens`, `failed_jobs`) — permanecem como o framework entrega (`bigint`/`string` de sessão). Custo zero deixá-las como estão; ganho zero mexer.
- **Migração de dados em produção** — não há produção. Estratégia é **reset das migrations**, não migration de conversão.
- **Refatoração de naming convention** ou qualquer outra dívida que não seja a chave primária — esta é uma refator cirúrgica.
- **Mudar `idempotency_key` de e-mail/notificação** — convenção textual livre (`<tipo>:<id>`), continua válida com IDs string (na prática fica mais limpa).
- **Tocar lógica de negócio** — invariantes, regras, gates, máquina de estados ficam idênticos.

## Referências da especificação

- `docs/especificacao/glossary.md` — termo "Identificador de entidade".
- `docs/project-state/decisions/adr/ADR-000-postgresql-banco-principal.md` — restrição: tipo nativo Postgres.
- `docs/project-state/decisions/adr/ADR-001-stack-principal.md` — restrição: Eloquent/Laravel.
- `docs/project-state/decisions/adr/ADR-009-modelo-de-dados-identidade-epic-001.md` — modelos identidade afetados.
- `docs/project-state/decisions/adr/ADR-013-modelo-vaga-candidatura-snapshot.md` — modelos vaga/candidatura afetados.
- `docs/project-state/decisions/adr/ADR-018-uuid-chave-primaria-entidades-dominio.md` — ADR desta refator (a ser criada pela STORY-069).

## Dependências

- **Bloqueia:** SPRINT-2026-W28 inteira (EPIC-003). W28 só ativa após este épico fechar — antes disso, ADR-018 precisa estar `accepted` e o schema novo precisa estar em homolog para os spikes STORY-055/056/057 já assumirem UUID.
- **Bloqueado por:** fechamento da SPRINT-2026-W27 (STORY-053 + STORY-054 `done`, veredito do validador aceito pelo PO). Não misturar refator estrutural com sprint em curso — disciplina herdada das W22–W26.
- **Decisões arquiteturais necessárias:** ADR-018 — produzida pela STORY-069 deste épico.

## Estórias

- [ ] STORY-069 — Spike Arquiteto: variante UUID, escopo, polimórficos, plano de execução (produz ADR-018)
- [ ] STORY-070 — Refactor schema + models + FKs + polimórficos + seeders + factories + testes (api + admin)
- [ ] STORY-071 — Refactor Flutter webapp: DTOs, services, telas, integration_test (IDs como String)
- [ ] STORY-072 (validação) — Re-run E2E homolog dos EPICs 001 + 002 + smoke `migrate:rollback`

## Validação final

Critérios em `validation/checklist.md` (a ser criado junto com STORY-072). Relatório do validador em `validation/report.md`.

**Definição de épico concluído:** STORY-069/070/071 `done` + STORY-072 com veredito `approved` ou `approved_with_pending` aceito pelo PO + ADR-018 `accepted` + schema novo demonstrado em homolog + testes verdes em CI.

## Histórico

- 2026-06-03 — criado por PO (Alexandro / Claude), em paralelo ao fechamento da SPRINT-2026-W27, para abrir SPRINT-2026-W27.5 antes da ativação de SPRINT-2026-W28 (EPIC-003).
