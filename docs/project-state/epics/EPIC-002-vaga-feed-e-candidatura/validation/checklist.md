---
epic_id: EPIC-002
type: validation-checklist
created_at: 2026-06-03
created_by: validador (sessão claude-opus-4-8 — STORY-054 CA-1)
status: filled  # empty → in_progress (validador trabalhando) → filled
---

# Checklist de validação — EPIC-002 Vaga, feed e candidatura

> **Nota de processo:** o `checklist.md` normalmente é input do PO. Nesta rodada, a **STORY-054 CA-1**
> atribuiu explicitamente ao validador escrevê-lo uma única vez no início (decisão do PO registrada na
> própria estória). Os itens abaixo derivam dos **entregáveis declarados em `epic.md`** e dos **CAs da
> STORY-054**; nenhum item foi inventado pelo validador além do que `epic.md`/STORY-054 exigem. O
> relatório (`report.md`) preenche status + evidência por item. Sem sugestão de correção; sem próximo
> passo — fato + veredito.

> **Legenda de status:** `pass` | `pass com ressalva` | `fail bloqueante` | `fail não-bloqueante` | `n/a` (com justificativa em prosa).

---

## Pré-condições de início

- [ ] **PRE-1:** STORY-044 a STORY-053 com `status: done` no `index.json`.
- [ ] **PRE-2:** EPIC-002 com `status: in_review` no `index.json` (validation_report `null` antes deste relatório).
- [ ] **PRE-3:** `app.homolog.turni.com.br` acessível; API homolog acessível same-origin (`/api/*`); deploy contém o código completo do épico (lição W23/W25 — métrica medida no estado final).
- [ ] **PRE-4:** Acesso a CI (GitHub Actions), Cloud Logging/Monitoring (gcloud, projeto `turni-mvp`) e stack local para suíte/cobertura.

---

## Bloco 1 — Critérios de aceite das estórias (cruzar CA ↔ teste/comportamento)

> Verifica que cada CA tem teste real que o cobre (não só nome parecido) e/ou comportamento observável.

### STORY-044 / STORY-045 (Spikes do Arquiteto)
- [ ] **CA-B1-1:** ADR-013 (modelo Vaga/Candidatura/VagaVersao) e ADR-014 (algoritmo Match + eventos) existem em `decisions/adr/`, `status: accepted`, indexadas no `index.json`.
- [ ] **CA-B1-2:** Função pura `MatchCalculator`/`MatchScoring` cobre os ramos da tabela `business-rules.md` (função primária/secundária/nenhuma; raio dentro/fora; histórico 4.0/4.5/5.0★/sem; níveis; cap 100). Determinística/pura (sem banco/clock).

### STORY-046 (Publicar vaga + gate PDR-005)
- [ ] **CA-B1-3:** `POST /api/vagas` cria vaga `aberta` (201) com snapshot `vaga_versoes` v1 + audit `vaga.criada` + telemetria `vaga.publicada`. Validação server espelha os 6 campos.
- [ ] **CA-B1-4:** Gate PDR-005 na publicação (`GET /api/avaliacoes/pendentes-do-contratante`): quando `pending>0`, formulário não renderiza. **Registrar a natureza stub-honesto** (turnos/avaliações são EPIC-003; endpoint retorna `pending:0` no estado atual).

### STORY-047 (Minhas vagas + cancelar)
- [ ] **CA-B1-5:** `GET /api/vagas/minhas` lista só vagas do contratante; `DELETE /api/vagas/{id}` faz `aberta→cancelada` (soft), audit `vaga.cancelada`, dispara `VagaCancelada`. Transição inválida → 409.

### STORY-048 (Feed + filtros + p95)
- [ ] **CA-B1-6:** `GET /api/feed` ranqueia por `score DESC, boost DESC, data_inicio ASC`; visibilidade (aberta + função primária/secundária + raio + data futura); 4 filtros (todas/minha_funcao/alto_match/candidatadas); `ja_candidatou`, `pode_candidatar`, `em_revisao` por card; telemetria `feed.vaga_apresentada`/`feed.vaga_filtrada`.

### STORY-049 (Detalhe + breakdown)
- [ ] **CA-B1-7:** `GET /api/vagas/{id}/detalhe` retorna `score_breakdown` (4 componentes com `pontos/pontos_max/estado/descricao`) + `pode_candidatar`/`ja_candidatou`/`motivo_bloqueio`. Estados ok/partial/miss corretos. Acessibilidade (Semantics) presente.

### STORY-050 (Candidatura 1 toque + 3 gates)
- [ ] **CA-B1-8:** `POST /api/vagas/{id}/candidaturas` cria `pendente` (201) com `score_no_momento` + `score_breakdown` snapshot; audit `candidatura.criada`; eventos `match.candidatura_enviada` + `CandidaturaEnviada`.
- [ ] **CA-B1-9:** Os 3 gates server-side com mensagem por gate: conflito de horário (dispara), habitualidade PDR-002 (PF 3ª alocação bloqueia; MEI/PJ alerta), avaliação PDR-005 (**stub-honesto** até EPIC-003). Idempotência: 2ª candidatura → 409 `ja_candidatou` (constraint UNIQUE). `DELETE /api/candidaturas/{id}` → `retirada`.

### STORY-051 (Painel de candidatos)
- [ ] **CA-B1-10:** `GET /api/vagas/{id}/candidatos` (contratante dono) ranqueia por `score_no_momento DESC, candidatou_em ASC` lendo snapshot (não recalcula); breakdown reusado; alerta habitualidade; aceitar/remover desabilitados (EPIC-003). RBAC: não-dono/profissional → 403.

### STORY-052 (Edição material PDR-009 + cron)
- [ ] **CA-B1-11:** `PATCH /api/vagas/{id}` detecta edição material (6 campos), cria `vaga_versoes` v(N+1) + transita candidaturas `pendente→pendente_revisao_apos_edicao` + audit `vaga.editada_materialmente` + evento `VagaEditadaMaterialmente`. Não-material → in-place. Endpoints confirmar/retirar após edição.
- [ ] **CA-B1-12:** Cron `candidaturas:auto-retirar-apos-edicao` move `pendente_revisao_apos_edicao` com prazo estourado → `retirada_por_edicao` (idempotente). **Registrar se o cron roda em homolog** (depende de `schedule:run`/worker).

### STORY-053 (Notificações in-app + e-mail)
- [ ] **CA-B1-13:** 3 listeners (`CandidaturaEnviada`/`VagaEditadaMaterialmente`/`VagaCancelada`) criam linhas em `notificacoes` + audit `notificacao.criada`; worker de fila envia e-mail pelos 5 templates ativos; `GET /api/notificacoes` + marcar-lida; badge in-app.

---

## Bloco 2 — Cobertura de testes (STORY-054 CA-10)

- [ ] **CA-B2-1:** Cobertura geral do código novo do épico **≥ 80%** (suíte api completa via `make test-api --min=80`).
- [ ] **CA-B2-2:** Módulo `app/Domain/Match/` **≥ 95%** (STORY-045 — núcleo de regra).
- [ ] **CA-B2-3:** `CandidaturaController` (gates) **≥ 95%** (STORY-050 — núcleo de regra).
- [ ] **CA-B2-4:** Suíte WebApp (Flutter) verde; widgets dos fluxos do épico cobertos (publicar/feed/detalhe/candidatura/painel/edição/notificações).
- [ ] **CA-B2-5:** Suíte admin verde (templates de e-mail / editor categoria-aware).
- [ ] **CA-B2-6:** Testes cobrem caminho feliz + casos inválidos + bordas (não só feliz) — amostragem nos núcleos (gates, match, edição material).

---

## Bloco 3 — Automação / Pipeline (STORY-054 CA-11)

- [ ] **CA-B3-1:** Pipeline CI (GitHub Actions `ci.yml`) **verde na main** para os commits das estórias do EPIC-002 no momento do veredito. **Registrar o escopo do CI remoto** (lint/pint + smoke build + scans; a suíte PHP completa+cobertura é gate de **pré-push** local — IDR-004).
- [ ] **CA-B3-2:** Deploy automático para homologação dispara após push na main — verificado (rc.57 no ar).
- [ ] **CA-B3-3:** Setup local automatizado (`make setup`/`make up`) e gate E2E local (`make e2e-webapp-integration`) existem e são o caminho canônico.

---

## Bloco 4 — Funcionalidade observável em homologação (STORY-054 CA-2, CA-3, CA-9)

- [ ] **CA-B4-1 (CA-3):** Match transparente — 100% das vagas no feed exibem score com breakdown clicável. Validador navega feed + detalhe em homolog e captura evidência.
- [ ] **CA-B4-2 (CA-2):** Métrica primária — publicar vaga e medir tempo até primeira candidatura em homolog em cenário seedado, contra SLA ≤ 2h (Member Start). Com **código completo do épico deployado** (rc.57).
- [ ] **CA-B4-3 (CA-9):** Audit log das 4 ações (criar vaga, candidatar, editar materialmente, cancelar) gravadas em `audit_logs` — verificação por query SQL.
- [ ] **CA-B4-4:** Logs/métricas básicas coletados em homolog (Cloud Logging) — incluindo telemetria de match e SLA de notificação (log-based metric STORY-053 CA-9).

---

## Bloco 5 — Qualidade transversal / Regras de domínio (STORY-054 CA-4..CA-8)

- [ ] **CA-B5-1 (CA-4):** Performance — feed p95 ≤ 800ms com **1k vagas seedadas** medido em **homolog** (stress seed + script de carga), não no CI.
- [ ] **CA-B5-2 (CA-5):** Gate PDR-005 — contratante com turno por avaliar bloqueado na publicação; profissional com turno por avaliar bloqueado na candidatura. **Registrar a limitação stub-honesto** (não há turno/avaliação real até EPIC-003).
- [ ] **CA-B5-3 (CA-6):** Ciclo PDR-009 completo — editar vaga materialmente (mudar valor) com 2 candidatos pendentes → snapshot `vaga_versoes` + estado candidaturas `pendente_revisao_apos_edicao` + e-mail ao candidato (**homolog usa Resend, não Mailpit** — verificar via Cloud Logging/inbox entregável) + cron auto-retirada 24h (forçando clock no backend/CI **ou** observado em homolog se o cron roda).
- [ ] **CA-B5-4 (CA-7):** RBAC vivo — contratante na rota de feed → 403; profissional na rota de publicar vaga → 403; contratante no painel de candidatos de vaga alheia → 403.
- [ ] **CA-B5-5 (CA-8):** Imutabilidade de `vaga_versoes` — UPDATE/DELETE manual via SQL falha (trigger/REVOKE). (Nota STORY-053: `GRANT UPDATE` foi restaurado para a FK de `candidaturas`; o append-only de UPDATE permanece pelo trigger — verificar que o trigger ainda bloqueia.)
- [ ] **CA-B5-6:** Migrações reversíveis (`migrate`/`migrate:rollback` exercidos); sem segredo em código; logs sem PII além do permitido (CA-10 da STORY-053: e-mail mascarado, sem CPF/telefone no MVP).

---

## Bloco 6 — Documentação

- [ ] **CA-B6-1:** ADRs do épico (ADR-013, ADR-014) e IDRs criados (IDR-025 boot/sessão, IDR-026 TurniDateTime, IDR-053 assuntos de e-mail) indexados em `index.json`.
- [ ] **CA-B6-2:** "Notas do agente" preenchidas em cada estória do épico (decisões/descobertas/cobertura/CA→teste).
- [ ] **CA-B6-3:** SCREEN specs das telas do épico em estado `shipped`/`ready` e indexadas.

---

## Bloco 7 — Veredito (STORY-054 CA-12)

- [ ] **CA-B7-1:** `report.md` termina com veredito explícito (`approved` / `approved_with_pending` / `rejected`).
- [ ] **CA-B7-2:** Lista de evidências (links de CI, deploy rc.57, screenshots, logs, queries SQL).
- [ ] **CA-B7-3:** Fails classificados por gravidade no formato F-B-N (bloqueante) / F-NB-N (não-bloqueante) — só fato + classificação, sem recomendação.
- [ ] **CA-B7-4:** `index.json` atualizado (campo `validation_report` do EPIC-002).
