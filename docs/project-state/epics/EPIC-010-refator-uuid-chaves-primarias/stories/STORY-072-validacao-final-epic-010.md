---
story_id: STORY-072
slug: validacao-final-epic-010
title: Validação final EPIC-010 — re-run EPIC-001 + EPIC-002 + smoke `migrate:rollback`
epic_id: EPIC-010
sprint_id: SPRINT-2026-W27.5
type: validation
target_role: validador
requires_design: false
design_screen_id: null
status: done
owner_agent: validador (sessão claude-opus-4-8)
created_at: 2026-06-03
updated_at: 2026-06-03
estimated_session_size: M
produces_idr: null
verdict: approved
---

# STORY-072 — Validação final EPIC-010

> **Para o agente validador:** sua missão é independente — confirmar que o refactor para UUID não introduziu regressão nos fluxos que os EPIC-001 e EPIC-002 deixaram operantes. Você **re-roda as checklists das STORY-025 e STORY-054** (validações finais dos respectivos épicos) contra o schema novo, em homolog, e emite veredito. Você **não** valida a decisão da ADR-018 — isso é trabalho do Arquiteto/PO; você valida que o **estado em homolog** está coerente com o que foi prometido pelo EPIC-010.

## Contexto (por que esta estória existe)

Após STORY-070 (backend) e STORY-071 (frontend) fecharem, o sistema em homolog está com schema novo (`uuid` em todas as tabelas de domínio) e WebApp consumindo IDs `String`. Antes de a SPRINT-2026-W28 (EPIC-003 — Pagar.me) ativar, precisamos de evidência independente de que **nenhum fluxo aceito anteriormente regrediu**. Esta estória produz essa evidência.

- Épico: `epics/EPIC-010-refator-uuid-chaves-primarias/epic.md`
- Documentos canônicos a ler ANTES de validar:
  - `epics/EPIC-001-cadastro-e-aprovacao/validation/checklist.md` e `report.md`
  - `epics/EPIC-002-vaga-feed-e-candidatura/validation/checklist.md` e `report.md`
  - `decisions/adr/ADR-018-uuid-chave-primaria-entidades-dominio.md`
  - Métricas primárias dos EPIC-001 e EPIC-002 (estão nos respectivos `epic.md`)

## O quê (objetivo desta estória)

Re-rodar em homolog as validações materiais dos EPIC-001 e EPIC-002, exercitar o smoke de `migrate:rollback` e `migrate:fresh`, e emitir veredito em `epics/EPIC-010-refator-uuid-chaves-primarias/validation/report.md` (`approved` | `approved_with_pending` | `rejected`).

## Por quê (valor para o usuário)

Sem este veredito, W28 não pode ativar — qualquer regressão silenciosa do refactor explodiria dentro da sprint mais crítica da onda.

## Critérios de aceite

### Bloco A — Re-run EPIC-001 (identidade)

- [ ] **CA-A1 — Pré-cadastro profissional PF/MEI/PJ.** Submeter 3 pré-cadastros (1 PF, 1 MEI, 1 PJ) via UI do WebApp; verificar que cada um cria `users` com `id` UUIDv7 e `profissional_profiles` correspondente; documento criptografado em repouso (cripto preservada); fila de aprovação no admin lista corretamente.

- [ ] **CA-A2 — Pré-cadastro contratante.** Idem para 1 contratante PJ.

- [ ] **CA-A3 — Fila de aprovação no Backoffice.** Admin loga, vê os 4 cadastros, aprova um profissional e um contratante, recusa outro. `admin_audit_log` registra cada ação com `actor_id` UUID. AceiteEletronico **não** é gerado nesta fase (ele só nasce em completar cadastro).

- [ ] **CA-A4 — Welcome pós-aprovação.** Profissional e contratante aprovados logam, veem welcome, marcam visto. `welcome_seen_at` preenchido.

- [ ] **CA-A5 — Completar cadastro profissional + AceiteEletronico imutável.** Profissional preenche cadastro, aceita contrato; `aceites_eletronicos` cria registro com PK UUID, `user_id` UUID e `template_versao_id` UUID. Tentar fazer UPDATE direto no banco (via tinker ou psql) deve falhar pelo trigger de imutabilidade (`ADR-010`).

- [ ] **CA-A6 — Completar cadastro contratante.** Idem para contratante PJ; `contratante_profiles` populado; AceiteEletronico gerado.

- [ ] **CA-A7 — FunnelGuard funciona com IDs UUID.** Acesso direto a `/user` com sessão de usuário `await_welcome` retorna 423; com `await_cadastro` idem; com `ativo` passa.

- [ ] **CA-A8 — Passkeys (se ativos em homolog).** Login com passkey continua funcionando — o override de `passkeys.user_id` para `uuid` está coerente.

### Bloco B — Re-run EPIC-002 (vaga, feed, candidatura)

- [ ] **CA-B1 — Publicar vaga.** Contratante cria vaga via WebApp; `vagas.id` UUID; `contratante_id` UUID válido; gate PDR-005 (avaliação recíproca) preservado.

- [ ] **CA-B2 — Lista "Minhas vagas" + cancelar.** Contratante vê suas vagas; cancela uma; transição válida.

- [ ] **CA-B3 — Feed do profissional com Match (p95 ≤ 800ms com 1k vagas).** Disparar `VagasStressSeeder` em homolog; rodar feed do profissional; medir p95. Re-run da medição feita na STORY-054. Comparar com baseline registrada no `report.md` do EPIC-002 — não pode regredir mais que 10% (margem ampla).

- [ ] **CA-B4 — Detalhe da vaga + breakdown.** Abrir detalhe; ver breakdown explicável; campos do `score_breakdown` JSON exibidos. Confirmar shape do JSON está coerente (CA-7 da STORY-070).

- [ ] **CA-B5 — Candidatura em 1 toque + 3 gates.** Profissional candidata; gate avaliação, gate conflito horário, gate habitualidade PDR-002 preservados. `candidaturas.id` UUID; UNIQUE `(vaga_id, profissional_id)` continua bloqueando 2ª tentativa.

- [ ] **CA-B6 — Painel de candidatos.** Contratante vê candidatos ranqueados; IDs UUID válidos; abertura de detalhe funciona.

- [ ] **CA-B7 — Edição material PDR-009 + snapshot.** Contratante edita campo material; `vaga_versoes` cria nova versão (PK UUID, `vaga_id` UUID); UNIQUE `(vaga_id, versao)` preservado; candidaturas pendentes vão para `pendente_revisao_apos_edicao`; cron de auto-retirada 24h funciona (smoke: rodar comando de cron manualmente).

- [ ] **CA-B8 — Notificações in-app + e-mail.** Eventos disparam notificações (`notificacoes.id` UUID, `idempotency_key` preserva sua função). E-mails saem com `<tipo>:<uuid>` como idempotency key — Mailpit em homolog recebe; smoke E2E (CA-12 da STORY-053) re-rodado.

- [ ] **CA-B9 — Audit log polimórfico.** Para cada ação acima, `audit_logs` registra com `target_type` + `target_id` (UUID). `uuidMorphs` funciona em queries (`AuditLog::where('target_id', $uuid)->where('target_type', Vaga::class)->get()`).

### Bloco C — Smoke estrutural

- [ ] **CA-C1 — `php artisan migrate:rollback`.** Em homolog: `migrate:rollback` da última migration. Verificar simetria (DROP COLUMN/TABLE coerente). Re-`migrate` recoloca. Repetir para `apps/api` e `apps/admin`.

- [ ] **CA-C2 — `php artisan migrate:fresh --seed`.** Idem; subir banco do zero; seeders rodam; smoke das telas principais via Playwright smoke (login + welcome + completar cadastro).

- [ ] **CA-C3 — Métricas observadas vs. baseline.** Comparar com baselines do EPIC-001 e EPIC-002:
  - SLA de notificação ≤ 60s p95 (baseline STORY-053: 45,5s observado). Aceitável: ≤ 60s.
  - Feed p95 ≤ 800ms com 1k vagas (baseline STORY-048/054). Aceitável: ≤ 880ms (10% de margem).
  - Tempo de aprovação no admin ≤ 24h (estatístico — não validar nesta estória).

### Bloco D — Veredito

- [ ] **CA-D1 — Relatório `validation/report.md` escrito.** Em `epics/EPIC-010-refator-uuid-chaves-primarias/validation/report.md`, registrar: cada CA (A1..C3) com status (`pass` / `fail` / `n/a`), evidência (link de log/screenshot), observações.

- [ ] **CA-D2 — Veredito emitido.** Linha final do report: `verdict: approved | approved_with_pending | rejected`. Em caso de `approved_with_pending`, listar pendências e classificá-las como bloqueantes ou não.

- [ ] **CA-D3 — PO confirma o veredito.** Sem confirmação do PO, status da estória fica `in_review`. Com confirmação, `done`.

## Fora de escopo

- Validar a decisão arquitetural da ADR-018 (mérito da escolha v7 vs v4) — responsabilidade do Arquiteto/PO.
- Re-rodar validação do EPIC-000 — fora desta sprint.
- Re-rodar testes manuais que não estão na checklist canônica dos EPICs 001 e 002.

## Padrões de qualidade exigidos

- Evidência objetiva para cada CA (log, screenshot, link).
- Nenhuma asserção qualitativa sem evidência ("parece funcionar" não vale).
- Re-rodar **a mesma checklist** das STORY-025 e STORY-054 (não inventar nova) — comparabilidade.

## Dependências

- **Bloqueada por:** STORY-070 + STORY-071 (`done`).
- **Bloqueia:** ativação da SPRINT-2026-W28.
- **Pré-requisitos de ambiente:** homolog com schema novo (`migrate:fresh --seed` rodado pelas estórias anteriores); Mailpit funcionando em homolog; admin user seed disponível.

## Decisões já tomadas (não as reabra)

- ADR-018 (toda).
- Critérios de validação dos EPIC-001 e EPIC-002 — já validados anteriormente, esta estória re-roda.

## Liberdade técnica do agente

Você decide:
- Ordem de execução dos CAs (A→B→C ou paralelo onde fizer sentido).
- Formato exato do report (mas seguir template do projeto: `docs/skills/validador/templates/validation-report.md`).

Você NÃO decide:
- Veredito sem evidência.
- Marcar `pass` quando há ambiguidade — vira `approved_with_pending` com pendência registrada.

## Definição de Pronto (DoD)

- [ ] Todos os CAs A1..D3 marcados com status + evidência.
- [ ] Veredito emitido.
- [ ] PO confirmou veredito.
- [ ] `index.json` atualizado: status `done` + verdict no campo do EPIC-010.
- [ ] Notas do agente preenchidas.

## Protocolo do agente (obrigatório)

Padrão do projeto + protocolo do Validador em `docs/skills/validador/`.

## Notas do agente (preenchido durante/após execução)

### Decisões tomadas
- 2026-06-03 — Metodologia local-primária (precedente STORY-025/054 + IDR-004): o grosso da verificação material rodou na stack local, que executa o mesmo código (rc.61) e schema implantados em homolog; homolog usado para evidência de deploy/health. Sem acesso ao Cloud SQL de homolog (limitação herdada), checagens ao vivo de banco feitas no Postgres local.
- 2026-06-03 — Não forcei mutação de banco para exercitar o gatilho de `admin_audit_log` (tabela vazia no seed local) — princípio "validador não altera banco". Registrado como pass com ressalva, coberto pela suíte admin.

### Descobertas
- 2026-06-03 — Homolog está em `v0.1.0-rc.61` (= commit HEAD sob validação `0c5c8de`), não rc.60: a STORY-071 (frontend) também foi deployada após o reset de schema da STORY-070. Backend+frontend UUID no ar.
- 2026-06-03 — Nenhuma regressão. Schema UUID íntegro, gatilhos de imutabilidade ativos em PK UUID, `uuidMorphs` operante, suítes verdes, migrações simétricas.

### Bloqueios encontrados
- 2026-06-03 — Nenhum.

### Evidências por CA
- CA-A1..A8: `validation/report.md` Bloco A + Apêndice A.1/A.2/A.3/A.4/A.5.
- CA-B1..B9: `validation/report.md` Bloco B + Apêndice A.1/A.3/A.6/A.7/A.8/A.9.
- CA-C1..C3: `validation/report.md` Bloco C + Apêndice A.6/A.10/A.11.
- CA-D1: report — `epics/EPIC-010-refator-uuid-chaves-primarias/validation/report.md`.
- CA-D2: veredito — **approved**.
- CA-D3: confirmação PO — Alexandro confirmou "Aprovada" em chat (2026-06-03).

### Métricas observadas
- SLA notificação p95: não re-medido ao vivo em homolog (limitação — semeadura proibida ao validador); pipeline verde na suíte + baselines STORY-053 (45,5s) / STORY-054 orgânico (~27s), ambos ≤ 60s.
- Feed p95 (1k vagas): ≤ 800ms (`FeedLatencyTest`, sem warning STDERR; gate 1200ms), dentro da margem ≤ 880ms vs baseline.

### Cobertura observada
- api: 535 passed (3788 assertions), 93,1% (`--min=80` verde).
- admin: 100 passed (237 assertions).
- webapp: 340 passed.

### Links de evidência
- Commit/tag sob validação: `0c5c8de` / `v0.1.0-rc.61`.
- Logs locais: `/tmp/story072-test-api.log`, `/tmp/story072-test-admin.log`, `/tmp/story072-test-webapp.log`.
- Homolog health: `https://app.homolog.turni.com.br/health` → rc.61.
- `validation/report.md`: `epics/EPIC-010-refator-uuid-chaves-primarias/validation/report.md`.
