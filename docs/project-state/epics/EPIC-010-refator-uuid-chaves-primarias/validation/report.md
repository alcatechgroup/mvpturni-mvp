---
epic_id: EPIC-010
type: validation-report
validated_at: 2026-06-03
validated_by: validador (sessão claude-opus-4-8 — STORY-072)
verdict: approved
checklist_source: epics/EPIC-010-refator-uuid-chaves-primarias/stories/STORY-072-validacao-final-epic-010.md
---

# Relatório de Validação — EPIC-010 (Refator UUID nas chaves primárias)

## TL;DR

> **Veredito**: APPROVED.
> **Contagem**: 23 passes (sendo 5 passes com ressalva factual), 0 fails (0 bloqueantes, 0 não-bloqueantes), 0 n/a.
> **Bloqueantes (resumo factual)**: nenhum. O refator para UUIDv7 (ADR-018) não introduziu regressão observável nos fluxos que os EPIC-001 e EPIC-002 deixaram operantes; toda tabela de domínio usa PK/FK `uuid`, os gatilhos de imutabilidade continuam bloqueando mutação em linhas de PK UUID, `uuidMorphs` funciona em consulta polimórfica, as suítes api/admin/webapp passam verdes sobre o schema novo, e o smoke de `migrate:rollback`/`migrate:fresh` é simétrico em api e admin.

---

## Resumo executivo

Esta validação é independente e de escopo restrito: confirmar que a refatoração transversal para UUID (STORY-070 backend api+admin, STORY-071 frontend Flutter) **não introduziu regressão** nos fluxos materiais dos EPIC-001 (identidade) e EPIC-002 (vaga/feed/candidatura), re-rodando as checklists canônicas das STORY-025 e STORY-054 contra o schema novo. **Não** valida o mérito da ADR-018 (trabalho do Arquiteto/PO).

Código sob validação: commit `0c5c8de` (HEAD de `main`, STORY-071), correspondente à tag `v0.1.0-rc.61`. Homologação responde saudável nesse exato release (`GET https://app.homolog.turni.com.br/health` → `{"status":"ok","version":"v0.1.0-rc.61"}`; `/up` → 200). O reset do schema de homolog para UUID foi feito na STORY-070 (CA-9, job `turni-migrate-homolog-6x6w4`, que verificou em homolog `users.id`, `sessions.user_id` e `audit_logs.target_id` = `uuid`).

Seguindo a metodologia precedente das validações dos EPIC-001 (STORY-025) e EPIC-002 (STORY-054) e o gate local do projeto (IDR-004), o grosso da verificação material rodou na **stack local** — que executa o mesmo código (rc.61) e o mesmo schema implantado em homolog — complementada por evidência de deploy/health de homolog. Acesso direto ao Cloud SQL de homolog não está disponível ao validador (limitação herdada e registrada nas duas validações anteriores); as checagens ao vivo de banco (tipos de coluna, gatilhos, `uuidMorphs`, constraints) foram feitas no Postgres local sobre o schema idêntico ao deployado.

Evidência central observada: (a) **estrutura** — as 13 tabelas de domínio têm PK `uuid` e todas as FKs de domínio são `uuid`; `audit_logs`/`admin_audit_log` (`target_id`) e `personal_access_tokens` (`tokenable_id`) usam `uuidMorphs`; `passkeys.id` permanece `bigint` com `user_id` `uuid`, e `sessions.id` permanece `varchar` com `user_id` `uuid`, exatamente como a ADR-018/runbook decidiram; (b) **imutabilidade ao vivo** — `UPDATE` em `aceites_eletronicos`, `vaga_versoes` e `audit_logs` (linhas com PK UUID real) é bloqueado pelo gatilho com a mensagem append-only; (c) **suítes verdes sobre UUID** — api **535 passed / 93,1% cobertura (`--min=80`)**, admin **100 passed**, webapp **340 passed**, incluindo o guarda de performance `FeedLatencyTest` (feed p95 ≤ 800 ms com **1k vagas** do `VagasStressSeeder`) e `PainelCandidatosLatencyTest` (p95 ≤ 500 ms); (d) **migrações simétricas** — `migrate:fresh --seed --drop-types` + `migrate:rollback` + re-`migrate` verdes em api e admin.

As ressalvas são factuais e não alteram o veredito: passkeys não foram exercitadas ao vivo (schema coerente, mas fluxo não ativo em homolog/local); `admin_audit_log` está vazia no seed local (gatilho presente, coberto pela suíte admin); o E2E de e-mail em homolog (Resend) e a medição de SLA de notificação ao vivo não foram re-executados pelo validador (cobertos por suíte + medição orgânica da STORY-053/054). O gap de `schedule:run` em homolog é o F-NB-1 pré-existente do EPIC-002 (endereçado pela STORY-073) e é **fora do escopo** desta validação de regressão UUID — o comando de cron em si executa limpo sobre o schema UUID.

---

## Checklist preenchido

### Bloco A — Re-run EPIC-001 (identidade)

| CA | Status | Evidência |
|---|---|---|
| **CA-A1** — Pré-cadastro PF/MEI/PJ: `users.id` UUIDv7 + `profissional_profiles`; doc cripto em repouso; fila no admin | ✅ | `users.id`=uuid, `profissional_profiles.{id,user_id,funcao_id}`=uuid (A.1); suíte api `PreCadastroProfissional*`/cripto verde dentro de 535 passed (A.3); admin 100 passed lista fila (A.4) |
| **CA-A2** — Pré-cadastro contratante PJ | ✅ | `contratante_profiles.{id,user_id}`=uuid (A.1); `PreCadastroContratanteTest` verde (A.3) |
| **CA-A3** — Fila de aprovação; `admin_audit_log.actor_id` UUID | ✅ com ressalva | `admin_audit_log.{id,actor_id,target_id}`=uuid (A.1); suíte admin 100 passed (A.4). Ressalva: `admin_audit_log` com 0 linhas no seed local — gatilho presente mas não exercitado ao vivo (A.5) |
| **CA-A4** — Welcome pós-aprovação; `welcome_seen_at` | ✅ | `WelcomeSeenTest` (api) e `WelcomePageTest` (admin) verdes (A.3/A.4) |
| **CA-A5** — Completar cadastro profissional + AceiteEletronico imutável (PK/FK uuid) | ✅ | `aceites_eletronicos.{id,user_id,template_versao_id}`=uuid (A.1); `UPDATE` ao vivo bloqueado pelo gatilho em linha de PK UUID (A.2); `CompletarCadastroProfissionalTest` verde (A.3) |
| **CA-A6** — Completar cadastro contratante + AceiteEletronico | ✅ | `contratante_profiles` populado; `CompletarCadastroContratanteTest` verde (A.3); imutabilidade idem A.2 |
| **CA-A7** — FunnelGuard com IDs UUID (423 / passa) | ✅ | `LoginTest`/`WelcomeSeenTest`/`Completar*` cobrem o funil (await_welcome/await_cadastro/ativo) e passam dentro de 535 (A.3) |
| **CA-A8** — Passkeys (se ativos em homolog) | ✅ com ressalva | `passkeys.user_id`=uuid; `passkeys.id`=bigint (override coerente com ADR-018/runbook) (A.1). Ressalva: fluxo de login por passkey não exercitado ao vivo (não ativo em homolog/local) (A.5) |

### Bloco B — Re-run EPIC-002 (vaga, feed, candidatura)

| CA | Status | Evidência |
|---|---|---|
| **CA-B1** — Publicar vaga; `vagas.id`/`contratante_id` UUID; gate PDR-005 | ✅ | `vagas.{id,contratante_id,funcao_id}`=uuid (A.1); `PublicarVagaTest`/`AvaliacoesPendentesTest` verdes (A.3) |
| **CA-B2** — Minhas vagas + cancelar | ✅ | Suíte api verde, incl. "cancelar vaga já cancelada → 409" observado no log (A.3) |
| **CA-B3** — Feed p95 ≤ 800ms com 1k vagas (re-run STORY-054) | ✅ | `FeedLatencyTest` (1k via `VagasStressSeeder`) verde, **p95 ≤ 800 ms** (sem warning STDERR; gate 1200 ms) sobre schema UUID (A.6). Dentro da margem ≤ 880 ms vs baseline |
| **CA-B4** — Detalhe + breakdown; shape do `score_breakdown` JSON | ✅ | `VagaDetalheTest` verde (A.3); `score_breakdown` sem IDs (CA-7 STORY-070), shape preservado |
| **CA-B5** — Candidatura 1 toque + 3 gates; `candidaturas.id` UUID; UNIQUE | ✅ | `candidaturas.{id,vaga_id,profissional_id,vaga_versao_id}`=uuid (A.1); `CandidaturaTest` (3 gates) verde (A.3); UNIQUE `(vaga_id, profissional_id)` ao vivo (A.7) |
| **CA-B6** — Painel de candidatos ranqueados; IDs UUID | ✅ | `PainelCandidatosTest` verde + `PainelCandidatosLatencyTest` p95 ≤ 500 ms (A.3/A.6) |
| **CA-B7** — Edição material PDR-009 + snapshot `vaga_versoes`; cron 24h | ✅ | `vaga_versoes.{id,vaga_id}`=uuid + UNIQUE `(vaga_id, versao)` ao vivo (A.1/A.7); `UPDATE` bloqueado pelo gatilho (A.2); comando `candidaturas:auto-retirar-apos-edicao` executa limpo sobre UUID (exit 0) (A.8). Nota: scheduler em homolog é F-NB-1 do EPIC-002 (STORY-073), fora de escopo |
| **CA-B8** — Notificações in-app + e-mail; `notificacoes.id` UUID; idempotency | ✅ com ressalva | `notificacoes.{id,destinatario_id,vaga_id,candidatura_id}`=uuid (A.1); `EnvioEmailNotificacao`/`Notificar*` verdes, `notificacao_id` emitido como UUID nos logs estruturados (A.3). Ressalva: E2E de e-mail em homolog (Resend) e re-medição de SLA não executados pelo validador — cobertos por suíte + medição orgânica STORY-053/054 (A.5) |
| **CA-B9** — Audit log polimórfico (`target_type`+`target_id` uuid); `uuidMorphs` | ✅ | Consulta ao vivo: `target_type` ∈ {Vaga, Notificacao, Candidatura} com `target_id` uuid agrupado (A.9); `AuditLogDominioTest` verde |

### Bloco C — Smoke estrutural

| CA | Status | Evidência |
|---|---|---|
| **CA-C1** — `migrate:rollback` (api+admin), simetria, re-migrate | ✅ | api: rollback de todas as migrations (down simétrico) + re-`migrate` verdes (A.10); admin: rollback verde (A.10) |
| **CA-C2** — `migrate:fresh --seed`; smoke das telas | ✅ | api `migrate:fresh --seed --force --drop-types` verde (todos seeders DONE) (A.10); admin idem (A.10); homolog WebApp `/`→200, `/up`→200 (rc.61), WebApp local 8003→200 (A.11) |
| **CA-C3** — Métricas observadas vs baseline | ✅ com ressalva | Feed p95 ≤ 800 ms re-medido (≤ 880 ms aceitável) ✓ (A.6). Ressalva: SLA de notificação não re-medido ao vivo em homolog (sem semeadura permitida ao validador); pipeline de notificação verde na suíte + baseline STORY-053 45,5 s / orgânico STORY-054 ~27 s, ambos ≤ 60 s (A.5) |

### Bloco D — Veredito

| CA | Status | Evidência |
|---|---|---|
| **CA-D1** — `validation/report.md` escrito | ✅ | Este documento |
| **CA-D2** — Veredito emitido | ✅ | `verdict: approved` (frontmatter + TL;DR) |
| **CA-D3** — PO confirma o veredito | ✅ | PO (Alexandro) confirmou "Aprovada" em chat — 2026-06-03 |

---

## Fails identificados

### Bloqueantes

Nenhum.

### Não-bloqueantes

Nenhum.

---

## Passes com ressalva

> Itens cumpridos com observação factual registrada — não são fails.

- **CA-A3 / CA-B9 (admin_audit_log ao vivo)**: o gatilho `prevent_admin_audit_log_mutation` (UPDATE/DELETE) existe e `admin_audit_log.{id,actor_id,target_id}` são `uuid`, mas a tabela tem 0 linhas no seed local — o bloqueio de mutação não foi exercitado em linha viva (a suíte admin, 100 passed, o cobre; e o gatilho equivalente de `audit_logs` foi exercitado ao vivo com sucesso).
- **CA-A8 (passkeys)**: `passkeys.user_id` é `uuid` e `passkeys.id` permanece `bigint` (override coerente com a decisão da ADR-018/runbook), mas o fluxo de login por passkey não está ativo em homolog/local e não foi percorrido ao vivo.
- **CA-B8 (e-mail em homolog)**: pipeline de notificação verde na suíte com `notificacao_id` UUID nos logs; o E2E de envio real via Resend em homolog não foi re-executado pelo validador (precedente STORY-054).
- **CA-C3 (SLA de notificação)**: não re-medido ao vivo em homolog (semeadura de homolog é proibida ao validador); evidência apoia-se na suíte verde + baselines STORY-053/054, todas ≤ 60 s.

---

## Limitações da validação

- **Acesso ao banco de homolog (Cloud SQL)**: sem proxy/credenciais disponíveis ao validador, as checagens ao vivo de banco (tipos de coluna, gatilhos de imutabilidade, `uuidMorphs`, constraints UNIQUE) foram feitas no Postgres **local** — mesmo schema e mesmo código (rc.61) implantados em homolog. A verificação do schema UUID **em homolog** apoia-se na evidência da STORY-070 CA-9 (job `turni-migrate-homolog-6x6w4` confirmou `users.id`/`sessions.user_id`/`audit_logs.target_id`=uuid no ambiente) + health rc.61 ao vivo.
- **Sessão autenticada same-origin em homolog**: não reproduzida por ferramenta avulsa (manejo de cookie Sanctum same-origin é área delicada — memória do projeto). Os fluxos autenticados (cadastro, feed, candidatura, painel) foram verificados por testes de rota/feature reais sobre o schema UUID + smoke de health em homolog, não por cliques manuais autenticados do validador em homolog.
- **Carga com 1k vagas e SLA de notificação em homolog**: não executáveis sem semear o ambiente (proibido ao validador). Performance do feed re-medida na stack local (1k vagas, mesmo schema); SLA de notificação apoiado em suíte + baselines.
- **Escopo herdado fora desta validação**: o gap de `schedule:run` em homolog (F-NB-1 do EPIC-002, STORY-073) não é regressão do EPIC-010 — o comando de cron executa corretamente sobre o schema UUID; o disparo automatizado no ambiente é assunto da STORY-073.

---

## Apêndice A — Evidências detalhadas

Commit sob validação: `0c5c8de` (tag `v0.1.0-rc.61`), branch `main`. Stack local: `docker compose` (postgres 18, api/admin/webapp/mailpit), DB `turni` (dados seedados) para checagens ao vivo e `turni_test`/`turni_admin_test` para o smoke de migrações.

### A.1 — Tipos de coluna das tabelas de domínio (PK/FK uuid)
`information_schema.columns` no Postgres local. Todas as PKs de domínio = `uuid`; FKs de domínio = `uuid`. `personal_access_tokens.tokenable_id`=uuid (`uuidMorphs`), `personal_access_tokens.id`=bigint; `passkeys.user_id`=uuid, `passkeys.id`=bigint; `sessions.user_id`=uuid, `sessions.id`=varchar — coerente com ADR-018/runbook. (40 colunas verificadas: users, profissional_profiles, contratante_profiles, aceites_eletronicos, templates, template_versoes, audit_logs, admin_audit_log, candidaturas, vagas, vaga_versoes, notificacoes, funcoes.)

### A.2 — Gatilhos de imutabilidade exercitados ao vivo (linha de PK UUID)
- `UPDATE aceites_eletronicos … WHERE id=<uuid>` → `ERROR: aceites_eletronicos é imutável após criação — operação UPDATE não permitida` (`prevent_aceite_eletronico_mutation`).
- `UPDATE vaga_versoes … WHERE id=<uuid>` → `ERROR: vaga_versoes é append-only — operação UPDATE não permitida` (`prevent_vaga_versoes_mutation`).
- `UPDATE audit_logs … WHERE id=<uuid>` → `ERROR: audit_logs é append-only — operação UPDATE não permitida` (`prevent_audit_logs_mutation`).
- Gatilhos existentes (information_schema.triggers): `aceites_eletronicos` (UPDATE+DELETE), `audit_logs` (UPDATE+DELETE), `admin_audit_log` (UPDATE+DELETE), `template_versoes` (UPDATE), `vaga_versoes` (UPDATE+DELETE).

### A.3 — Suíte api (Pest) sobre schema UUID
`make test-api` → **Tests: 535 passed (3788 assertions)**, **cobertura 93,1% (`--min=80` verde)**, Duration 24,09s. Log `/tmp/story072-test-api.log`. Inclui `Feature/Identity/*` (Login, WelcomeSeen, CompletarCadastro PF/PJ), `Feature/Vaga/*` (PublicarVaga, PainelCandidatos, AvaliacoesPendentes), `Feature/Feed/*` (Feed, VagaDetalhe), `Feature/Candidatura/CandidaturaTest`, `AuditLogDominioTest`/`ImutabilidadeTest`.

### A.4 — Suíte admin (Pest)
`make test-admin` → **Tests: 100 passed (237 assertions)**. Inclui fila de aprovação, templates, welcome, fail-secure (guest→login, não-admin→403). Log `/tmp/story072-test-admin.log`.

### A.5 — Suíte webapp (Flutter)
`make test-webapp` → **+340: All tests passed!**. Cobre telas de pré-cadastro, completar cadastro, feed/detalhe/candidatura, com IDs como `String` (STORY-071). Log `/tmp/story072-test-webapp.log`.

### A.6 — Guardas de performance (grupo `performance`, na suíte)
- `Tests\Performance\FeedLatencyTest` — "p95 do feed ≤ 800ms (gate 1200ms) com 1k vagas (CA-6)" → PASS em 1,98s, **sem** warning STDERR (logo p95 ≤ 800 ms), com `VagasStressSeeder` (1k vagas) sobre schema UUID.
- `Tests\Performance\PainelCandidatosLatencyTest` — "p95 do painel ≤ 500ms (gate 750ms) com 50 candidatos (CA-8)" → PASS em 0,57s.
- `Tests\Performance\MatchBenchmarkTest` → PASS.

### A.7 — Constraints UNIQUE ao vivo
- `candidaturas`: `candidaturas_unique_vaga_profissional UNIQUE (vaga_id, profissional_id)`.
- `vaga_versoes`: `vaga_versoes_unique_versao UNIQUE (vaga_id, versao)`.

### A.8 — Smoke do cron sobre UUID
`docker compose exec api php artisan candidaturas:auto-retirar-apos-edicao` → `Candidaturas auto-retiradas após edição: 0.` (exit 0) — a consulta UUID executa sem erro de tipo.

### A.9 — `uuidMorphs` polimórfico ao vivo
`SELECT target_type, count(*), exemplo FROM audit_logs GROUP BY target_type`: `Vaga`(5), `Notificacao`(4), `Candidatura`(2), todos com `target_id` uuid (ex.: `019e8fa5-b46c-72f6-8467-25f20e5861a2`).

### A.10 — Smoke de migrações (api + admin)
- api (`DB_DATABASE=turni_test`): `migrate:fresh --seed --force --drop-types` → todos seeders DONE; `migrate:rollback --force` → down de todas as migrations (simétrico, sem erro); `migrate --force` → re-aplica até `2026_06_03_140000_grant_update_vaga_versoes_para_fk`.
- admin (`DB_DATABASE=turni_admin_test`): `migrate:fresh --seed --force --drop-types` → DONE + Seeding; `migrate:rollback --force` → down simétrico.
- Confirma IDR-027 (necessidade de `--drop-types` por causa dos enums nativos) sem regressão.

### A.11 — Homolog + WebApp local
- `GET https://app.homolog.turni.com.br/health` → `{"status":"ok","version":"v0.1.0-rc.61","service":"webapp"}`.
- `GET https://app.homolog.turni.com.br/` → 200; `/up` → 200.
- `GET http://localhost:8003/` (WebApp local) → 200.
- rc.61 = tag do commit HEAD sob validação (`0c5c8de`). Schema UUID em homolog verificado na STORY-070 CA-9 (job `turni-migrate-homolog-6x6w4`).

---

## Apêndice B — Arquivos de log

- `/tmp/story072-test-api.log` — suíte api completa + cobertura.
- `/tmp/story072-test-admin.log` — suíte admin.
- `/tmp/story072-test-webapp.log` — suíte webapp Flutter.

---

## Histórico

- 2026-06-03 — relatório inicial submetido por validador (sessão claude-opus-4-8, STORY-072). Veredito: `approved`.
- 2026-06-03 — PO (Alexandro) confirmou o veredito `approved` em chat (CA-D3). STORY-072 → `done`; EPIC-010 fechado.
</content>
</invoke>
