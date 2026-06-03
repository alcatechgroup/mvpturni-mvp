---
story_id: STORY-070
slug: refactor-backend-uuid-api-admin
title: Refactor backend — schema, models, FKs, polimórficos, seeders, factories, testes (apps/api + apps/admin)
epic_id: EPIC-010
sprint_id: SPRINT-2026-W27.5
type: refactor
target_role: programador
requires_design: false
design_screen_id: null
status: ready
owner_agent: null
created_at: 2026-06-03
updated_at: 2026-06-03
estimated_session_size: L
produces_idr: null  # produz IDR se houver descoberta técnica relevante durante a execução
---

# STORY-070 — Refactor backend: UUIDv7 em `apps/api` + `apps/admin`

> **Para o agente que vai executar:** esta é a estória **L** desta sprint — único candidato natural a estouro de sessão única. **Antes de começar**, leia (a) `epics/EPIC-010-.../runbook-refactor-backend.md` produzido pela STORY-069, (b) ADR-018 completa, (c) as 27 migrations de `apps/api/database/migrations/` e as ≈14 de `apps/admin/database/migrations/`. O runbook é a sua sequência mecânica; siga-o. Se a sessão estourar, **pare e quebre** em duas estórias 070a (`apps/api`) e 070b (`apps/admin`) — critério no fim desta estória.

## Contexto (por que esta estória existe)

ADR-018 está `accepted` (STORY-069 fechou). O schema atual usa `bigint` auto-increment em todas as 15 tabelas de domínio, em duas bases Laravel idênticas (`apps/api` e `apps/admin`). Esta estória **executa o refactor mecânico** definido pela ADR-018 e pelo runbook do spike, sem reabrir decisões. Premissa "zero produção" confirmada pela STORY-069 (CA-4) — estratégia é **reset das migrations**.

- Épico: `epics/EPIC-010-refator-uuid-chaves-primarias/epic.md`
- Documentos canônicos a ler ANTES de codificar:
  - `epics/EPIC-010-.../runbook-refactor-backend.md` (produzido pela STORY-069)
  - `decisions/adr/ADR-018-uuid-chave-primaria-entidades-dominio.md` (`accepted`)
  - `decisions/adr/ADR-009-modelo-de-dados-identidade-epic-001.md` e `ADR-013-modelo-vaga-candidatura-snapshot.md` — modelo lógico permanece igual.

## O quê (objetivo desta estória)

Converter, em `apps/api` e `apps/admin`, todas as PKs e FKs das 15 tabelas de domínio para `uuid` nativo Postgres com geração `HasVersion7Uuids` em PHP; converter as 2 colunas polimórficas para `uuidMorphs()`; atualizar seeders, factories e tests; rodar `migrate:fresh --seed` em homolog; deixar suíte Pest verde em ambos os apps.

## Por quê (valor para o usuário)

Indireto, mas crítico: paga uma dívida estrutural antes que vire não-corrigível na W28 (Pagar.me). Sem este refactor, o débito atravessa toda a WAVE-2026-01.

## Critérios de aceite

- [ ] **CA-0 — Premissa "zero produção" reconfirmada no início.** Antes de qualquer mudança, executar a query do CA-4 da STORY-069 em homolog e em qualquer outra base não-local conhecida; resultado precisa ser 0 (ou lista revisada). Se mudou, **parar e escalar ao PO** — Decisão 5 da ADR pode precisar virar 5B.

- [ ] **CA-1 — Migrations reescritas com `uuid` e `foreignUuid` nas 15 tabelas de domínio.** Em ambos os apps (`apps/api/database/migrations/` e `apps/admin/database/migrations/`):
  - `users.id` → `uuid` (manter timestamps, soft-deletes, etc; manter `email_verified_at`, `aprovado_em`, `welcome_seen_at`, `cadastro_completed_at`).
  - `profissional_profiles.id` e `.user_id` → `uuid` / `foreignUuid`.
  - `contratante_profiles.id` e `.user_id` → idem.
  - `admin_audit_log.id` e `.actor_id` → idem.
  - `funcoes.id` → `uuid`; `profissional_profiles.funcao_id` → `foreignUuid`.
  - `templates.id`, `template_versoes.id`, `.template_id`, `.criado_por_admin_id` → `uuid` / `foreignUuid`.
  - `aceites_eletronicos.id`, `.template_versao_id`, `.user_id` → idem.
  - `cadastro_lembretes.id` e FKs → idem.
  - `vagas.id`, `.contratante_id`, `.funcao_id` → idem.
  - `vaga_versoes.id`, `.vaga_id`, `.editado_por` → idem. **Preservar `UNIQUE (vaga_id, versao)` `vaga_versoes_unique_versao`.**
  - `candidaturas.id`, `.vaga_id`, `.profissional_id`, `.vaga_versao_id` → idem. **Preservar `UNIQUE (vaga_id, profissional_id)` `candidaturas_unique_vaga_profissional`.**
  - `audit_logs.id`, `.actor_id` → idem. `target_type` + `target_id` → `uuidMorphs('target')`. Preservar index composto.
  - `notificacoes.id`, `.destinatario_id`, `.vaga_id`, `.candidatura_id` → idem. Preservar `UNIQUE` em `idempotency_key`.
  - `passkeys.user_id` → `foreignUuid` (override da migration do pacote conforme decidido em CA-3 da STORY-069).
  - `personal_access_tokens.tokenable_id` → `uuidMorphs('tokenable')` (override da migration default do Sanctum).
  - `down()` simétrico para cada migration. F-NB-1 do EPIC-000 quitado.

- [ ] **CA-2 — Models recebem trait + keyType.** Em ambos os apps, todos os 14 models de domínio recebem:
  ```php
  use Illuminate\Database\Eloquent\Concerns\HasVersion7Uuids;
  
  class Model extends ... {
      use HasVersion7Uuids;
      protected $keyType = 'string';
      public $incrementing = false;
      // ...
  }
  ```
  Lista de models a tocar (em ambos `apps/api/app/Models/` e `apps/admin/app/Models/`):
  - `User`, `ProfissionalProfile`, `ContratanteProfile`, `AdminAuditLog`, `Funcao`, `Template`, `TemplateVersao`, `AceiteEletronico`, `CadastroLembrete`, `Vaga`, `VagaVersao`, `Candidatura`, `AuditLog`, `Notificacao`.

- [ ] **CA-3 — Tabelas internas do Laravel NÃO mudam.** `cache`, `cache_locks`, `jobs`, `failed_jobs`, `sessions`, `password_reset_tokens`, `personal_access_tokens.id` (a PK), `passkeys.id` (PK do pacote) — ficam exatamente como o Laravel/pacote entrega. Apenas `tokenable_id` e `user_id` do Passkeys mudam (já cobertos em CA-1). Verificar com `git diff` que essas migrations não foram tocadas além do necessário.

- [ ] **CA-4 — Seeders rodam verdes.** `php artisan migrate:fresh --seed` em ambos os apps em ambiente local sobe schema novo com:
  - Admin seed (`AdminUserSeeder`)
  - Funções (`FuncaoSeeder`)
  - Templates contratuais (`TemplatesContratuaisSeeder`)
  - Fila de aprovação (`FilaAprovacaoPendentesSeeder`)
  Sem erro. Toda referência a `$user->id`, `$contratante->id`, `$funcao?->id` continua funcionando porque Eloquent abstrai o tipo — mas auditar caso a caso na escrita do seeder onde houver `string` vs `int` explícito.

- [ ] **CA-5 — Factories ajustadas.** `UserFactory` e qualquer factory implícita (Pest pode estar criando inline) devem funcionar com `HasVersion7Uuids`. Auditar `tests/Feature/Identity/*Test.php` e `tests/Feature/Vaga/*Test.php` — se algum teste assume `$user->id === 1` ou compara IDs como int, ajustar.

- [ ] **CA-6 — Suíte Pest verde em CI.** `php artisan test` em `apps/api` e `apps/admin` passa 100% no novo schema, sem skip. Lista de arquivos de teste afetados conhecidos (auditar todos, não apenas estes):
  - `tests/Feature/Identity/PreCadastroProfissionalTest.php`
  - `tests/Feature/Identity/CompletarCadastroProfissionalTest.php`
  - `tests/Feature/Identity/CompletarCadastroContratanteTest.php`
  - `tests/Feature/Identity/WelcomeSeenTest.php`
  - `tests/Feature/Identity/MigrationSchemaTest.php` — **especial atenção**: pode assertar tipo de coluna (`bigInteger`); precisa virar `uuid`.
  - `tests/Feature/Identity/AuditLogTest.php`
  - `tests/Feature/Vaga/CandidaturaModelTest.php`
  - `tests/Unit/ProfileModelsTest.php`, `tests/Unit/ContratanteProfileModelTest.php`
  - `tests/Unit/AuditLogServiceTest.php`

- [ ] **CA-7 — `score_breakdown` JSON ajustado se necessário.** Auditar shape do JSON em `candidaturas.score_breakdown` (saída do Match — STORY-045). Se contiver IDs string, garantir formato UUID. Se for apenas valores numéricos do score, registrar no commit que está "sem impacto". Cobrir com test unitário em `tests/Unit/MatchScoreBreakdownTest.php` (se não existir, criar).

- [ ] **CA-8 — Admin audit log e domain audit log preservam idempotência.** Reexecutar testes que cobrem a propriedade append-only (`AuditLogTest.php`) e verificar que `actor_id` e `target_id` são UUID válidos. Trigger ou check de imutabilidade preservado (ADR-013).

- [ ] **CA-9 — Deploy em homolog.** Executar em homolog: `php artisan migrate:fresh --seed` em ambos os apps; smoke de `php artisan migrate:rollback` (rollback simétrico para a migration mais nova) e re-`migrate` — verde. Capturar log do deploy e linkar nas notas do agente.

- [ ] **CA-10 — Convenções de log preservadas.** As linhas de log estruturado existentes (`cadastro.template_indisponivel`, `aceite.gerado`, `notificacao.criada`, etc.) continuam emitindo `user_id`, `aceite_id`, `actor_id` como string UUID — pesquisar no codebase (`grep -rn "user_id.*->id"`) e confirmar que não há cast explícito para `int`. ADR-008 (observabilidade) preservada.

- [ ] **CA-11 — `docker-compose.yml` e `.env.example` revisados.** Sem mudança esperada — Postgres já é PG14+, tipo `uuid` é nativo desde PG 9. Confirmar mesmo assim e marcar este CA.

- [ ] **CA-12 — IDR aberto se houve descoberta técnica relevante.** Se durante a execução o agente descobriu algo que merece registro (ex: workaround para Spatie passkeys, particularidade do override Sanctum), abrir IDR em `decisions/idr/IDR-XXX-<slug>.md` antes de fechar a estória.

## Fora de escopo

- Refactor do `apps/webapp` (Flutter) — é STORY-071.
- Mudar lógica de negócio, regras de gates, FunnelGuard, máquina de estados de candidatura/vaga.
- Performance tuning (índices novos) além do que ADR-013 já fixou.
- Mexer em tabelas internas do Laravel (`cache`, `jobs`, `sessions`).

## Padrões de qualidade exigidos

- **Cobertura ≥ 80% no código novo** (qualquer model/test ajustado); **≥ 98% no que tocar regras de negócio**.
- **Sem teste skipped**. Toda regressão preserva intenção do teste original.
- **Suíte Pest verde nos dois apps** antes do PR.
- **Pipeline CI verde** em ambos.
- **Commits pequenos e nomeados** — recomendado um commit por tabela (ou por grupo coeso: identidade, vaga, audit/notificação).

## Dependências

- **Bloqueada por:** STORY-069 (`done`, ADR-018 `accepted`, runbook backend pronto).
- **Bloqueia:** STORY-072 (validação).
- **Pré-requisitos de ambiente:** Docker local com Postgres ≥ 14 (já é o padrão do projeto); homolog operante; pgcrypto ativo (default).

## Decisões já tomadas (não as reabra)

- ADR-018 (todas as 7 decisões).
- ADR-009 e ADR-013 (modelo lógico das tabelas).
- ADR-008 (formato de log estruturado).
- F-NB-1 do EPIC-000 (`migrate:rollback` simétrico).

## Liberdade técnica do agente

Você (agente programador) decide:
- Reescrever as migrations existentes vs. criar nova migration "reset" — opte por reescrever, mais limpo.
- Ordem de execução: começar por `users` faz sentido (tudo depende).
- Como agrupar commits.
- Se IDR vale a pena para algum gotcha descoberto.

Você (agente programador) NÃO decide:
- Variante UUID, tipo de coluna, escopo, polimórficos, geração na app vs. banco — ADR-018.
- Modelo lógico — ADR-009 e ADR-013.

Se descobrir bloqueador real, **pare** e ajuste o frontmatter para `status: blocked`.

## Critério de quebra (se sessão estourar)

Se ao chegar ao fim de uma sessão a estória estiver ≥ 50% mas não fechada, **quebrar** em:
- **STORY-070a** — refactor `apps/api` apenas (escopo: 7 CAs primeiros).
- **STORY-070b** — refactor `apps/admin` + tarefas que sobraram.

A quebra é decisão técnica do agente, comunicada ao PO antes de fechar a sessão. Não inflar a sessão.

## Definição de Pronto (DoD)

- [ ] Todos os 12 CAs passam.
- [ ] Testes unitários e Feature verdes em ambos os apps.
- [ ] Pipeline CI verde no PR.
- [ ] Deploy em homolog feito (`migrate:fresh --seed`) com log capturado.
- [ ] Smoke de `migrate:rollback` exercitado e capturado.
- [ ] IDR registrado se houve descoberta relevante (CA-12).
- [ ] `index.json` atualizado: status `done`.
- [ ] Notas do agente preenchidas.

## Protocolo do agente (obrigatório)

Padrão do projeto. Em particular:

1. **Ao iniciar:** rodar CA-0 antes de qualquer mudança no schema.
2. **Durante:** commits pequenos; rodar `php artisan test` localmente antes de cada commit.
3. **Se travar:** `status: blocked` + descrição clara.
4. **Ao terminar:** notas preenchidas, `status: in_review`.

## Notas do agente (preenchido durante/após execução)

### Decisões tomadas
- <data> — <decisão local>

### Descobertas
- <data> — <gotcha>

### Bloqueios encontrados
- <data> — <bloqueio>

### Evidências por CA
- CA-0: <output da query>
- CA-1..CA-11: <link de commits / log>
- CA-12: IDR aberto? <sim — IDR-XXX / não>

### Cobertura final
- `apps/api`: Pest — <%>
- `apps/admin`: Pest — <%>

### Links de evidência
- PR: <url>
- Pipeline: <url>
- Deploy homolog: <url + log>
