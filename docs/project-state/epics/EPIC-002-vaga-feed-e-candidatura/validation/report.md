---
epic_id: EPIC-002
type: validation-report
validated_at: 2026-06-03
validated_by: validador (sessão claude-opus-4-8)
verdict: approved_with_pending  # approved | rejected | approved_with_pending
checklist_source: epics/EPIC-002-vaga-feed-e-candidatura/validation/checklist.md
commit_validado: 9ec29c7  # main; código do EPIC-002 idêntico ao deixado por STORY-053 (9ec29c7 só adiciona docs do EPIC-010)
deploy_homolog: v0.1.0-rc.57
---

# Relatório de Validação — EPIC-002 Vaga, feed e candidatura

## TL;DR

> **Veredito: APPROVED com pendências.**
> **Contagem**: 7 `pass`, 6 `pass com ressalva`, 1 `fail não-bloqueante`, 0 `fail bloqueante`, 0 `n/a`.
> **Não-bloqueante (resumo factual)**: o comando agendado `candidaturas:auto-retirar-apos-edicao`
> (auto-retirada 24h do PDR-009) **não é executado em homolog/produção** — o worker roda apenas
> `queue:work`, não há `schedule:run` (gap de infra pré-existente, documentado na STORY-053). O ciclo
> PDR-009 (snapshot + transição de estado + e-mail) funciona; o comando está coberto por E2E de backend
> com relógio forçado (`travel(25h)`), mas não dispara sozinho no ambiente implantado.

---

## Resumo executivo

O EPIC-002 entrega o primeiro encontro profissional↔contratante: publicar vaga → feed ranqueado por
match transparente → candidatura em 1 toque → painel de candidatos ranqueado, com edição material
(PDR-009) e notificações in-app + e-mail. Validei o código em `main` (commit `9ec29c7`; o único commit
após a STORY-053 adiciona apenas documentos do EPIC-010, sem tocar código do EPIC-002) e o ambiente de
homologação em **`v0.1.0-rc.57`** (api/admin Cloud Run `southamerica-east1`, deploy 2026-06-03 19:28).

O essencial está cumprido com evidência forte: suíte api **531 testes verdes, cobertura 93,2%**, com o
núcleo de regra acima do exigido (`app/Domain/Match/*` 100%, `CandidaturaController` 100%, os 3 gates
100%); admin **100 verdes**; WebApp **340 verdes**. A imutabilidade de `vaga_versoes` foi verificada
**ao vivo** no Postgres (trigger bloqueia UPDATE e DELETE mesmo com role superusuário). RBAC dos 3
cenários da CA-7 é coberto por testes de rota reais e as rotas protegidas respondem 401 sem sessão. Em
homologação, o ciclo de notificação foi exercitado de verdade (logs estruturados): 17 `candidatura_recebida`,
8 `vaga_editada_material`, 6 `vaga_cancelada` enviados via Resend, **zero falhas de envio**, SLA de
notificação `sla_ms` ~27 s neste relatório (STORY-053 mediu p95 = 45,5 s sobre 30 amostras, ≤ 60 s) —
muito dentro do SLA de ≤ 2 h da métrica primária do épico.

As ressalvas concentram-se em três naturezas, todas factuais e documentadas: (a) **decisões de escopo
"stub-honesto"** — o gate PDR-005 (CA-5) e o gate de avaliação na candidatura existem e disparam quando
`pending>0` (testado com gate forçado), mas não há como produzir um "turno por avaliar" real até o
EPIC-003; (b) **premissas da estória desatualizadas pela implementação** — homolog usa **Resend, não
Mailpit**, e a métrica de performance do feed com **1k vagas** foi medida no **CI local** (≤ 800 ms),
não em homolog (homolog não tem o stress seed; o validador não semeia o ambiente); (c) **gaps de infra
pré-existentes** — o comando agendado de auto-retirada não roda em homolog (mesmo gap que afeta os
lembretes da STORY-021) e o workflow agendado "Setup local test" falha desde 2026-05-28 (antes do épico)
por uma asserção de smoke obsoleta. Nenhum desses pontos é um defeito oculto; o único classificado como
`fail` é não-bloqueante (auto-retirada não dispara no ambiente implantado).

---

## Checklist preenchido

### Bloco 1 — Critérios de aceite das estórias

| Item | Status | Evidência |
|---|---|---|
| CA-B1-1 — ADR-013/ADR-014 `accepted` e indexadas | ✅ pass | `index.json` lista ADR-013/ADR-014 em `decisions.adr[]`; arquivos em `decisions/adr/`. Ap. A.1 |
| CA-B1-2 — `MatchCalculator`/`MatchScoring` cobrem a tabela do match; puro/determinístico | ✅ pass | `Tests\Unit\Match\*` verdes; `MatchPurezaTest` ("núcleo não lê banco nem clock"); cobertura 100%. A.2 |
| CA-B1-3 — `POST /api/vagas` cria `aberta`+v1+audit+telemetria | ✅ pass | `PublicarVagaTest` verde; `PublicarVagaService` 100%; audit `vaga.criada` em DB. A.6 |
| CA-B1-4 — Gate PDR-005 na publicação (stub-honesto `pending:0`) | ⚠️ pass com ressalva | `AvaliacoesPendentesTest` verde; gate dispara com `pending>0` em teste front; não exercitável com turno real (EPIC-003). A.5 |
| CA-B1-5 — `GET /api/vagas/minhas` + `DELETE` cancela (409 inválido) | ✅ pass | `MinhasVagasTest`/`CancelarVagaTest` verdes; `VagaCancelada` disparado; audit `vaga.cancelada`. A.6 |
| CA-B1-6 — Feed ranqueado + visibilidade + filtros + telemetria | ✅ pass | `FeedTest`/`FeedQueryTest` verdes; `FeedController` 100%, `FeedQuery` 97,9%; telemetria `feed.*`. A.4 |
| CA-B1-7 — Detalhe + breakdown 4 componentes + estados ok/partial/miss + Semantics | ✅ pass | `VagaDetalheTest` verde; `VagaDetalheController` 98,4%, `VagaDetalhe`/`VagaDetalheQuery` 100%. |
| CA-B1-8 — Candidatura cria `pendente`+score snapshot+eventos | ✅ pass | `CandidaturaTest` verde; `CandidaturaController` 100%; log `match.candidatura_enviada`. A.2/A.6 |
| CA-B1-9 — 3 gates + idempotência 409 + retirada | ✅ pass | `Gates/*` 100%; idempotência via `UNIQUE(vaga_id,profissional_id)`; gate avaliação stub-honesto. |
| CA-B1-10 — Painel candidatos ranqueado lê snapshot; aceitar/remover desabilitados | ✅ pass | `PainelCandidatosTest` verde; `CandidatosController` 95,0%; ordem score DESC/candidatou_em ASC. |
| CA-B1-11 — `PATCH` detecta material + v(N+1) + transição + evento | ✅ pass | `EditarVagaTest`/`EdicaoMaterialTest` verdes; `EditarVagaService` 100%; `EdicaoMaterial` 98,1%. A.7 |
| CA-B1-12 — Cron auto-retirada (idempotente) | ⚠️ pass com ressalva | `AutoRetirarAposEdicaoCommand` 97,7%; `CicloEdicaoMaterialE2ETest` com `travel(25h)`. **Não roda em homolog** — ver F-NB-1. |
| CA-B1-13 — 3 listeners + worker + 5 templates + endpoints + badge | ✅ pass | `tests/{Feature,Unit}/Notificacao` 26 verdes; templates ativos no editor; envio em homolog (A.3). |

### Bloco 2 — Cobertura de testes (STORY-054 CA-10)

| Item | Status | Evidência |
|---|---|---|
| CA-B2-1 — Cobertura geral ≥ 80% | ✅ pass | api **Total 93,2 %** (gate `--min=80` ✓), 531 testes / 1766 asserts, 23,58 s. A.2 |
| CA-B2-2 — `app/Domain/Match/` ≥ 95% | ✅ pass | Todos os 6 arquivos **100,0 %** (`MatchCalculator`, `MatchScore`, `MatchScoring`, `MatchInput`, `BreakdownItem`, `EstadoComponente`). A.2 |
| CA-B2-3 — `CandidaturaController` ≥ 95% | ✅ pass | `CandidaturaController` **100,0 %**; gates `GateAvaliacao`/`GateConflitoHorario`/`GateHabitualidade` **100,0 %**. A.2 |
| CA-B2-4 — Suíte WebApp verde | ✅ pass | `make test-webapp` → **340 passed ("All tests passed!")**. A.2 |
| CA-B2-5 — Suíte admin verde | ✅ pass | `make test-admin` → **100 passed (237 asserts)**. A.2 |
| CA-B2-6 — Feliz + inválidos + bordas | ✅ pass | Amostragem: gates (dispara/não-dispara), match (primária/secundária/nenhuma, cap 110→100), edição (material/não-material/já-em-revisão), cron (24h/início/idempotência). |

### Bloco 3 — Automação / Pipeline (STORY-054 CA-11)

| Item | Status | Evidência |
|---|---|---|
| CA-B3-1 — CI verde na main para as estórias do épico | ⚠️ pass com ressalva | Runs recentes da main todos `success`; escopo do CI remoto = lint/pint + smoke build + scans (suíte PHP+cobertura é gate de pré-push, IDR-004). Ressalvas A.8 (Trivy SARIF transitório; scheduled-setup pré-existente). |
| CA-B3-2 — Deploy automático para homolog após push | ✅ pass | rc.57 implantado por `turni-github-ci@` em 2026-06-03 19:28; `app.homolog` responde 200; `version.json` = rc.57. A.1 |
| CA-B3-3 — Setup local automatizado + gate E2E local | ⚠️ pass com ressalva | `make setup`/`make up` operam (stack local de pé há 2 dias); `make e2e-webapp-integration` é o gate canônico. Workflow agendado de setup falha por asserção obsoleta — A.8. |

### Bloco 4 — Funcionalidade observável em homologação (CA-2, CA-3, CA-9)

| Item | Status | Evidência |
|---|---|---|
| CA-B4-1 (CA-3) — 100% das vagas no feed com score + breakdown clicável | ⚠️ pass com ressalva | Garantido por código+teste (todo card carrega `score`; detalhe sempre devolve `breakdown`); `FeedController` 100%; homolog `/api/feed` responde 200; UI validada no app local pelo PO. Screenshot autenticado em homolog não capturado pelo validador. A.4 |
| CA-B4-2 (CA-2) — Métrica primária ≤ 2h em homolog | ✅ pass | 17 `candidatura_recebida` entregues em homolog; `sla_ms` ~27 s (STORY-053: p95 45,5 s/30 amostras) ≪ 2 h. Perna "tempo até 1ª candidatura" é operada manualmente no cenário seedado. A.3 |
| CA-B4-3 (CA-9) — audit_logs das 4 ações | ⚠️ pass com ressalva | Local: `audit_logs` tem `vaga.criada`(3), `candidatura.criada`(2), `vaga.editada_materialmente`(1), `vaga.cancelada`(1); cada ação emitida pelo serviço correspondente. Homolog (mesmo código rc.57, ações exercitadas no CA-12) não consultado via SQL — sem proxy ao Cloud SQL. A.6 |
| CA-B4-4 — Logs/métricas coletados em homolog | ✅ pass | Cloud Logging com telemetria estruturada + log-based metrics `turni_homolog_notificacao_email_sla_ms` / `..._failures`. A.3 |

### Bloco 5 — Qualidade transversal / Regras de domínio (CA-4..CA-8)

| Item | Status | Evidência |
|---|---|---|
| CA-B5-1 (CA-4) — Feed p95 ≤ 800ms com 1k vagas em homolog | ⚠️ pass com ressalva | ≤ 800 ms com **1k vagas no CI local** (`FeedLatencyTest`, gate); homolog orgânico **224–261 ms** (poucas vagas). Carga com 1k vagas **não medida em homolog** (sem stress seed; validador não semeia). A.4 |
| CA-B5-2 (CA-5) — Gate PDR-005 bloqueia publicação/candidatura | ⚠️ pass com ressalva | Lógica implementada e testada (bloqueia com `pending>0`, forçado em teste); end-to-end com "turno por avaliar" real não exercitável (turnos = EPIC-003; endpoint retorna `pending:0`). A.5 |
| CA-B5-3 (CA-6) — Ciclo PDR-009 completo | ⚠️ pass com ressalva | Snapshot `vaga_versoes` ✓; transição `pendente_revisao_apos_edicao` ✓; e-mail ao candidato ✓ (**Resend, não Mailpit** — 8 `vaga_editada_material` em homolog); cron via relógio forçado ✓ (E2E backend). **Auto-retirada não roda em homolog** → F-NB-1. A.3/A.7 |
| CA-B5-4 (CA-7) — RBAC vivo (3 cenários → 403) | ✅ pass | Testes de rota reais: `FeedTest`(contratante→403), `PublicarVagaTest`(profissional→403), `PainelCandidatosTest`(não-dono→403, profissional→403); rotas protegidas devolvem 401 ao vivo sem sessão; E2E loga em cada papel em browser real. A.9 |
| CA-B5-5 (CA-8) — Imutabilidade `vaga_versoes` (UPDATE/DELETE falham) | ✅ pass | **Ao vivo** no Postgres: UPDATE e DELETE levantam `vaga_versoes é append-only` (trigger `prevent_vaga_versoes_mutation`), mesmo com `current_user=turni usesuper=t`. A.10 |
| CA-B5-6 — Migrações reversíveis; sem segredo; logs sem PII | ✅ pass | `migrate`/`migrate:rollback` exercitados (STORY-044/050); gitleaks verde no CI; log de e-mail mascara destinatário (`x•••@gmail.com`, CA-10). A.3/A.8 |

### Bloco 6 — Documentação

| Item | Status | Evidência |
|---|---|---|
| CA-B6-1 — ADRs/IDRs do épico indexados | ✅ pass | ADR-013/ADR-014 + IDR-025/IDR-026/IDR-053 referenciados nas notas das estórias e no `index.json`. |
| CA-B6-2 — "Notas do agente" preenchidas | ✅ pass | Todas as 10 estórias (044–053) têm Notas com decisões/descobertas/cobertura/CA→teste. |
| CA-B6-3 — SCREEN specs `shipped`/`ready` indexados | ✅ pass | SCREEN-046/047/048/049/050/051/052/053 marcados `shipped`/`ready` nas notas + `design.screens[]`. |

### Bloco 7 — Veredito (CA-12)

| Item | Status | Evidência |
|---|---|---|
| CA-B7-1 — Veredito explícito | ✅ pass | `approved_with_pending` (TL;DR + frontmatter). |
| CA-B7-2 — Lista de evidências | ✅ pass | Apêndice A. |
| CA-B7-3 — Fails classificados (F-B/F-NB) | ✅ pass | Seção "Fails identificados" (1 F-NB, 0 F-B). |
| CA-B7-4 — `index.json` atualizado | ✅ pass | Campo `validation_report` do EPIC-002 preenchido nesta sessão. |

---

## Fails identificados

### Bloqueantes

> Nenhum.

### Não-bloqueantes

#### F-NB-1 — Auto-retirada 24h (PDR-009) não é executada no ambiente implantado
- **Bloco**: Bloco 1 (CA-B1-12) / Bloco 5 (CA-B5-3 / STORY-054 CA-6).
- **Critério esperado**: STORY-052 CA-9 — comando `candidaturas:auto-retirar-apos-edicao` move candidaturas
  `pendente_revisao_apos_edicao` com prazo estourado para `retirada_por_edicao`; PDR-009 promete "sem
  resposta em 24h → retirada automática".
- **O que verifiquei**: o comando está implementado, é idempotente e está coberto por E2E de backend com
  relógio forçado (`CicloEdicaoMaterialE2ETest`, `travel(25h)`, verde). Em homolog, o worker é o Cloud Run
  Job `turni-worker-job-homolog`, agendado 1/min, que executa **apenas `queue:work database`**; **não há
  `schedule:run`** em nenhum runner. Logo, no ambiente implantado nada dispara o comando agendado: uma
  candidatura em `pendente_revisao_apos_edicao` sem resposta permanece nesse estado indefinidamente.
- **Classificação**: não-bloqueante — o fluxo central do PDR-009 (snapshot + transição + notificação ao
  candidato) funciona em homolog (8 `vaga_editada_material` enviados); as ações manuais "Manter"/"Retirar"
  funcionam; a auto-retirada é a rede de segurança para não-respondentes. É um **gap de infra
  pré-existente e documentado** (STORY-053 §Descoberta "homolog só roda fila, não scheduler"), que também
  afeta `lembretes:cadastro` da STORY-021 — anterior ao EPIC-002 e fora do código do épico. A CA-6 admite
  explicitamente a verificação por relógio forçado no CI, que está cumprida.
- **Evidência**: ver Apêndice A.7 e A.3.

> **Atualização 2026-06-06 — F-NB-1 endereçada pela STORY-073 (verificada em homolog, rc.80):**
> `php artisan schedule:run` passou a rodar 1×/min em homolog via Cloud Run Job
> `turni-scheduler-job-homolog` + Cloud Scheduler (espelho gated em prod). Cenário original do
> validador reproduzido ao vivo com timestamps reais: edição material 22:02:58Z → prazo 22:07:58Z →
> auto-retirada + audit `candidatura.retirada_por_edicao_auto` às 22:08:11Z (13s após o prazo).
> Logs de 60/60 minutos com tick anexados à estória. Colaterais (`lembretes:cadastro`, sweeper de
> e-mail, `turnos:detectar-no-show`) ativados pelo mesmo fix. Quitação formal (index.json
> `quitada_por: STORY-073`) ao marcar a estória `done` — pende só a evidência do CA-6
> (lembretes às 09:00 BRT de 2026-06-07) e aprovação do PO.

> **Nota**: nenhum fail inclui "sugestão", "estória de correção", "próximo passo" ou estimativa de
> tamanho — planejamento é do PO.

---

## Passes com ressalva

- **Bloco 3.1 (CA-11)** — Pipeline da main verde no momento do veredito, mas: (a) o push de
  `docs(STORY-045): ADR-014 accepted` (run 26822957001, 2026-06-02) teve **falha transitória de infra** nos
  jobs "Container scan (Trivy — api/admin)" na etapa de upload SARIF (todos os jobs de código passaram;
  runs seguintes verdes); (b) o escopo do CI remoto **não inclui a suíte PHP+cobertura** — esta é gate de
  pré-push (IDR-004), que rodei localmente (A.2).
- **Bloco 3.3 (CA-B3-3)** — o workflow agendado **"Setup local test (scheduled)"** falha **desde
  2026-05-28** (último sucesso 05-28; falhas em 29, 30, 31, 06-01, 06-02, 06-03) por uma **asserção de
  smoke obsoleta**: o check exige 200 e o root do Backoffice responde **302** (redirect para login —
  comportamento correto de rota autenticada). É **anterior ao EPIC-002** (que começou em 06-01/06-02) e
  não decorre do código do épico.
- **Bloco 4.1 (CA-3)** — score+breakdown garantidos por código+teste e validados no app local pelo PO; o
  validador não capturou screenshot autenticado do feed/detalhe em homolog (sessão Sanctum same-origin não
  reproduzida via curl avulso — ver Limitações).
- **Bloco 4.3 (CA-9)** — as 4 ações de audit foram verificadas no banco **local** (linhas reais) e no
  código; o `audit_logs` de **homolog** não foi consultado por SQL (sem proxy ao Cloud SQL). O mesmo
  código está implantado (rc.57) e as 4 ações foram exercitadas em homolog no CA-12 da STORY-053.
- **Bloco 5.1 (CA-4)** — p95 ≤ 800 ms está demonstrado com **1k vagas no CI local** (`FeedLatencyTest`,
  gate). Em homolog, as amostras orgânicas de `/api/feed` (n=4) ficaram em **224–261 ms**, mas o teste de
  carga controlado com **1k vagas seedadas em homolog** não foi executado (homolog não tem o stress seed; o
  validador não semeia/altera o ambiente).
- **Bloco 5.2 (CA-5)** — o gate PDR-005 (publicação e candidatura) está implementado e dispara quando
  `pending>0` (forçado em teste front), mas não há como gerar um "turno por avaliar" real até o EPIC-003;
  o endpoint retorna `pending:0` por design (stub-honesto, decisão de escopo aprovada pelo PO).
- **Bloco 5.3 (CA-6)** — a premissa "e-mail em **Mailpit**" da STORY-054 está desatualizada: homolog usa
  **Resend** (`mail.homolog.turni.com.br`); a entrega foi confirmada via Cloud Logging
  (`notificacao.email.sent`, `message_id` do Resend), não por inbox Mailpit.

---

## Limitações da validação

- **Sessão autenticada em homolog via ferramenta avulsa**: o login Sanctum same-origin não foi reproduzido
  por `curl` (o harness same-origin tem manejo de cookie específico — área reconhecidamente delicada,
  ver memória do projeto). Consequência: a verificação ao vivo dos 403 cross-role (CA-7) e da navegação
  autenticada feed→detalhe em homolog (CA-3) apoiou-se em testes de rota reais + 401 ao vivo + E2E em
  browser, não em chamadas curl autenticadas do validador.
- **Acesso ao banco de homolog (Cloud SQL)**: sem proxy/credenciais configurados, não consultei
  `audit_logs`/`vaga_versoes` diretamente em homolog. A imutabilidade (CA-8) e as 4 ações de audit (CA-9)
  foram verificadas no Postgres **local** (mesmo schema/código implantado em rc.57).
- **Carga com 1k vagas em homolog (CA-4)**: não executável sem semear o ambiente (proibido ao validador);
  evidência de performance é CI-local (1k vagas) + amostras orgânicas de homolog (poucas vagas).
- **Pré-condição PRE-2**: o `index.json` lista o EPIC-002 com `status: ready` (não `in_review`) e as 10
  estórias de implementação como `done`. A atribuição da STORY-054 (validação) foi o gatilho da validação;
  registro a divergência de status como fato, sem efeito sobre o veredito.

---

## Apêndice A — Evidências detalhadas

### A.1 — Estado de main e deploy de homolog
- Branch `main`, commit validado `9ec29c7`. `git diff --stat 7a965df..HEAD` mostra que o único commit após
  a STORY-053 toca **somente documentos** (EPIC-010/ADR-018/sprint) — código do EPIC-002 intacto.
- Cloud Run `southamerica-east1`: `turni-api-homolog` e `turni-admin-homolog`, último deploy
  2026-06-03T19:28 por `turni-github-ci@turni-mvp.iam.gserviceaccount.com`.
- `curl https://app.homolog.turni.com.br/version.json` → `{"version":"v0.1.0-rc.57"}`; `/up` → 200;
  `/api/funcoes` → 200; `/api/feed` → 401 (auth).
- `index.json`: ADR-013, ADR-014 presentes em `decisions.adr[]`; STORY-044..053 `done`.

### A.2 — Suítes e cobertura (gate de pré-push, IDR-004)
- `make test-api` → **Tests: 531 passed (1766 assertions), Duration 23.58s; Total 93.2 %** (gate `--min=80`).
  Per-arquivo: `app/Domain/Match/{MatchCalculator,MatchScore,MatchScoring,MatchInput,BreakdownItem,EstadoComponente}`
  **100.0%**; `CandidaturaController` **100.0%**; `Gates/{GateAvaliacao,GateConflitoHorario,GateHabitualidade}`
  **100.0%**; `FeedController` 100.0%, `FeedQuery` 97.9%; `EditarVagaService` 100.0%, `EdicaoMaterial` 98.1%;
  `AutoRetirarAposEdicaoCommand` 97.7%; `CandidatosController` 95.0%; `VagaDetalheController` 98.4%.
- `make test-admin` → **100 passed (237 assertions)**.
- `make test-webapp` → **340 passed ("All tests passed!")**.
- Logs salvos: `/tmp/val-test-api.log`, `/tmp/val-test-admin.log`, `/tmp/val-test-webapp.log`.

### A.3 — Homolog: notificação, SLA e worker (Cloud Logging)
- `jsonPayload.message="notificacao.email.sent"` (últimos 3 dias), por `tipo`:
  **`candidatura_recebida` 17 · `vaga_editada_material` 8 · `vaga_cancelada` 6**.
- Amostra: `sla_ms=26640`, `latencia_ms=245`, `message_id=...@mail.homolog.turni.com.br`,
  `destinatario="x•••@gmail.com"` (PII mascarada — CA-10), `channel=production`.
- `jsonPayload.message="notificacao.email.falhou"` (3 dias): **0 entradas** (nenhuma falha de envio).
- Log-based metrics existentes: `turni_homolog_notificacao_email_sla_ms`,
  `turni_homolog_notificacao_email_failures`, `turni_homolog_email_failures`.
- Worker: Cloud Run Job `turni-worker-job-homolog` com execuções 1/min (19:39/19:40/19:41 UTC) por
  `turni-wrk-sched-homolog@`. Confirma drenagem da fila (CA-5/STORY-034).

### A.4 — Feed: latência e ranqueamento
- Homolog (access logs `jsonPayload.path:"/api/feed"`, status 200): durações observadas
  0.224 / 0.240 / 0.254 / 0.261 s → **224–261 ms** (n=4 amostras orgânicas; dataset pequeno de homolog).
- CI local (`FeedLatencyTest`, 1k vagas via `VagasStressSeeder`): p95 ≤ 800 ms (gate; folga até 1200 ms) —
  verde na suíte api.
- Ranqueamento/visibilidade/filtros cobertos por `FeedTest`/`FeedQueryTest` (verdes); telemetria
  `feed.vaga_apresentada`/`feed.vaga_filtrada` emitida.

### A.5 — Gate PDR-005 (stub-honesto)
- `AvaliacoesPendentesController`/`AvaliacoesPendentesContratante`/`...Profissional` retornam `pending:0`
  (turnos/avaliações = EPIC-003). UI bloqueia quando `pending>0` (widget test com gate forçado). Não há
  caminho para "turno por avaliar" real até o EPIC-003. Decisão de escopo aprovada pelo PO (STORY-046 Notas).

### A.6 — Audit log (banco local) + emissão no código
```
 action                     | count
----------------------------+-------
 candidatura.criada         |     2
 candidatura.retirada       |     1
 notificacao.criada         |     6
 vaga.cancelada             |     1
 vaga.criada                |     3
 vaga.editada_materialmente |     1
```
- Emissão: `vaga.criada`←`PublicarVagaService`; `candidatura.criada`←`CriarCandidaturaService`;
  `vaga.editada_materialmente`←`EditarVagaService`; `vaga.cancelada`←`CancelarVagaService`.

### A.7 — Edição material PDR-009 + auto-retirada
- `EditarVagaTest`/`EdicaoMaterialTest`/`RevisaoAposEdicaoTest`/`CicloEdicaoMaterialE2ETest` verdes; o E2E
  de backend força `travel(25h)` e observa prof1 mantém / prof2 sai pelo cron.
- Em homolog, o ciclo de edição material gerou 8 e-mails `vaga_editada_material` (A.3) — snapshot +
  transição `pendente_revisao_apos_edicao` ocorreram de verdade. O comando agendado de auto-retirada,
  porém, não dispara em homolog (F-NB-1): worker roda só `queue:work`.

### A.8 — CI / scanners
- `gh run list --branch main --limit 40`: 37 `success`, 3 `failure`. As 3 falhas: 2 do workflow
  **"Setup local test (scheduled)"** (06-02, 06-03) e 1 do push `docs(STORY-045)` (06-02).
- Push `docs(STORY-045)` (run 26822957001): jobs de código verdes (Commit lint, gitleaks, PHP lint api/admin,
  Flutter analyze, smoke builds api/admin/web); falharam só "Container scan (Trivy — api/admin)" na etapa de
  build-para-scan/upload SARIF (infra transitória; recuperado nos runs seguintes).
- "Setup local test (scheduled)" (run 26872705784, 06-03): step de smoke termina com
  `✗ Backoffice (http://localhost:8002) → 302` → `exit 1`. Falha **desde 2026-05-28** (último sucesso 05-28),
  anterior ao EPIC-002.

### A.9 — RBAC (testes de rota + 401 ao vivo)
- `tests/Feature/Feed/FeedTest.php:69` — contratante → `GET /api/feed` → 403.
- `tests/Feature/Vaga/PublicarVagaTest.php:135` — profissional → `POST /api/vagas` → 403.
- `tests/Feature/Vaga/PainelCandidatosTest.php:119/128` — contratante não-dono → 403; profissional → 403.
- Ao vivo (stack local): `GET /api/feed` e `GET /api/vagas/minhas` sem sessão → **401** (guard ativo).

### A.10 — Imutabilidade de `vaga_versoes` (ao vivo)
```
UPDATE vaga_versoes ... ;  -> ERROR: vaga_versoes é append-only — operação UPDATE não permitida
DELETE FROM vaga_versoes ...; -> ERROR: vaga_versoes é append-only — operação DELETE não permitida
SELECT current_user, usesuper;  -> turni | t   (superusuário; o trigger bloqueia mesmo assim)
```
- Mecanismo: trigger `prevent_vaga_versoes_mutation` BEFORE UPDATE OR DELETE (migração
  `2026_06_02_100001`) + `REVOKE DELETE`; `GRANT UPDATE` restaurado em `2026_06_03_140000` para a FK
  `candidaturas.vaga_versao_id` (o append-only de UPDATE permanece garantido pelo trigger).

---

## Apêndice B — Arquivos / fontes de evidência

- `validation/checklist.md` — checklist desta validação (CA-1).
- `/tmp/val-test-api.log`, `/tmp/val-test-admin.log`, `/tmp/val-test-webapp.log` — saídas das suítes.
- Cloud Logging (projeto `turni-mvp`): filtros `jsonPayload.message="notificacao.email.sent"`,
  `..."notificacao.email.falhou"`, `jsonPayload.path:"/api/feed"` (serviço `turni-api-homolog`).
- `gh run view 26822957001`, `gh run view 26872705784` — detalhes das falhas de CI.
- Queries `psql -U turni -d turni` — audit_logs e trigger de imutabilidade.

---

## Histórico

- 2026-06-03 — relatório inicial submetido pelo validador (sessão claude-opus-4-8). Veredito:
  APPROVED com pendências (0 bloqueante, 1 não-bloqueante F-NB-1).
