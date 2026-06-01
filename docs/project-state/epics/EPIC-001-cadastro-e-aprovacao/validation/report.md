---
epic_id: EPIC-001
type: validation-report
validated_at: 2026-06-01
validated_by: validador (sessão Claude — STORY-025, rodada 1)
verdict: approved_with_pending  # approved | rejected | approved_with_pending
checklist_source: epics/EPIC-001-cadastro-e-aprovacao/validation/checklist.md
commit_validado: 0e1e4068fbdb282eef6b20d965b22e07f5a030f1
branch: main
---

# Relatório de Validação — EPIC-001 Cadastro e aprovação

**Legenda:** ✅ pass · ⚠️ pass com ressalva · ❌ fail · 🚫 n/a · ⏳ pendente (não verificado nesta sessão)

> **Régua de pipeline (decisão do PO nesta validação):** o checklist pede testes/cobertura/E2E "na pipeline"; por **IDR-004** esses são gates **locais** (`make test` no pre-push; `make e2e` antes da tag rc). Logo, os itens "na pipeline" foram tratados como **n/a-na-pipeline** e exigiram **verificação local** para pass. A verificação local foi executada nesta sessão (cobertura medida + `make e2e` em browser real).
> **Imutabilidade (decisão do PO):** Cloud SQL homolog é private-IP-only; imutabilidade evidenciada por **migração+trigger+REVOKE + suíte `api` contra Postgres real** (não re-rodei psql ao vivo em homolog).

---

## TL;DR

> **Veredito**: **APPROVED com pendências** (`approved_with_pending`).
> **Contagem**: nenhum **fail bloqueante**. Fails não-bloqueantes: 1 (alerta de SLA>20h não observado). Passes com ressalva: 5. Itens não verificáveis desta sessão (pendentes/limitação, não-centrais): cookies de sessão autenticada, entrega real de e-mail em inbox, cronometragem exata do fluxo, lista LGPD de dados, env efetivo de Argon2id em homolog.
> **Bloqueantes**: nenhum. A funcionalidade essencial do épico foi verificada funcionando: cadastro → aprovação → completar → ativo com aceite imutável; RBAC vivo; editor de templates; audit log e aceite imutáveis; **cenário central PDR-012 (aceite mantém versão original após nova ativação) coberto por teste contra Postgres real**.

---

## Resumo executivo

EPIC-001 entrega o funil de identidade do Turni (pré-cadastro profissional PF/MEI/PJ e contratante → aprovação manual no backoffice → welcome → completar cadastro com AceiteEletronico imutável → ativo), RBAC vivo WebApp/Backoffice, audit log de admin append-only, editor de templates versionados (PDR-012) e e-mails transacionais.

A validação encontrou uma **fundação de qualidade sólida e verificável**: suítes verdes com cobertura medida (`api` 238 testes / **96,1%**; `admin` 91 testes / **93,6%**; `webapp` 121 testes / 76,8% app-inteiro), **E2E local em browser real verde** (`make e2e`: WebApp integration_test same-origin + smoke Playwright + Backoffice Playwright — 13 admin passed, 1 flaky que passou no retry), imutabilidade garantida por trigger+REVOKE nas três tabelas críticas e **comprovada por teste contra Postgres real**, observabilidade com métricas RED e alertas configurados, e amostragem de acessibilidade (admin 100, WebApp 88–92 no Lighthouse). O achado estrutural — testes/cobertura/E2E são gates **locais** e não de CI — foi tratado sob a régua IDR-004 (o PO confirmou) e a verificação local correspondente foi executada e está verde. As pendências remanescentes são **não-centrais e não-bloqueantes**: ausência de um alerta dedicado a SLA>20h, e um conjunto de checagens "vivas" (cookies autenticados, e-mail em inbox real, cronometragem exata, lista LGPD) que não foram percorridas nesta sessão. Daí o veredito **approved_with_pending** — o épico cumpre o essencial; o PO decide o tratamento das pendências.

---

## Pré-condições

| Item | Status | Evidência |
|---|---|---|
| PRE-1 — STORY-012..024 `done` | ✅ | `index.json`: STORY-012..024 todas `done` (+ STORY-034/037 do EPIC-001 `done`). |
| PRE-2 — EPIC-001 `in_review` | ⚠️ | `index.json` `epics[EPIC-001].status = "ready"` (não `in_review`); `validation_report = null`. Por decisão do PO, a invocação da STORY-025 foi o go-signal; ressalva registrada. Validador não altera status do épico. |
| PRE-3 — homolog acessível | ✅ | WebApp `app.homolog` 200 / rc.42; admin Cloud Run `/health` 200 (após cold start — A.7), `/login` 200, rc.42. |

---

## Checklist preenchido

### Bloco 1 — Critérios de aceite das estórias

| Item | Status | Evidência |
|---|---|---|
| CA-B1-1 — ADR-009/010/011 accepted + approved_by | ✅ | Frontmatter dos três: `status: accepted`, `approved_by: Alexandro`. |
| CA-B1-2 — seed contratual (pf + mei-pj) | ✅ | `template-pf-autonomo-eventual-v1.md`, `template-mei-pj-b2b-v1.md` presentes. |
| CA-B1-3 — migração role/status/flags idempotente/reversível | ⚠️ | Migrações com `down()`; rollback exercido (runbook); idempotência indireta pelos deploys verdes. |
| CA-B1-4 — `migrate:rollback` homolog (F-NB-1) | ✅ | runbook §rollback-migracoes (bug `down()` corrigido, commit `806ce03`). |
| CA-B1-5 — login admin + cookie | ⚠️ | E2E `rbac-login` (admin login/logout) verde; flags do cookie de sessão não inspecionadas (ver CA-5-6). |
| CA-B1-6 — login profissional WebApp (Sanctum SPA) | ✅ | WebApp integration_test (`auth_test`) verde same-origin (`make e2e` → "All tests passed"). |
| CA-B1-7 — admin no WebApp rejeitado | ✅ | Teste `api` "admin não acessa o endpoint do WebApp"; middleware `WebAppOnly` 100%. |
| CA-B1-8 — não-admin no Backoffice → erro fail-secure | ✅ | E2E admin `rbac-login` (CA-13d): "contratante tentando logar no backoffice recebe erro" verde. |
| CA-B1-9 — fail-secure cookie cross-host | ⏳ | Não percorrido ao vivo (cross-host) nesta sessão. |
| CA-B1-10 — funnel guard | ✅ | `FunnelGuard` 90%; `webapp` `welcome_funnel_screen_test`; integration_test verde. |
| CA-B1-11 — audit log recebe `admin.login` | ⚠️ | `AuditLogService` 100% + testes; query no banco homolog não executada (psql — decisão PO). |
| CA-B1-12 — audit log imutável | ✅ | Trigger `prevent_admin_audit_log_mutation` BEFORE UPDATE/DELETE + REVOKE (A.4); exercido pela suíte `api`. |
| CA-B1-13/19 — `/cadastro/*` renderiza | ✅ | homolog `/cadastro/profissional` 200, `/cadastro/contratante` 200; pré-cadastro coberto por integration_test + widget tests. |
| CA-B1-14 — PF/MEI/PJ → `pendente_aprovacao` | ✅ | `webapp` `pre_cadastro_profissional_test`; controllers `api` cobertos. |
| CA-B1-15 — e-mail duplicado genérico | ✅ | `pre_cadastro_profissional_test`: "banner genérico sem enumeração (CA-4)". |
| CA-B1-16 — checkbox aceite (client+server) | ✅ | `StoreProfissionalPreCadastroRequest` 100% + testes; `PreCadastro*Test` "aceite não marcado bloqueado no servidor". |
| CA-B1-17 — pré-cadastro NÃO coleta documento | ✅ | `StoreProfissionalPreCadastroRequest` sem campo documento. |
| CA-B1-18 — foto signed URL / path não enumerável | ⏳ | Esquema de storage/signed URL não auditado nesta sessão. |
| CA-B1-20/21 — contratante `pendente` + proteções | ✅ | `pre_cadastro_contratante_test` (banner genérico) verde; `ContratanteCadastroController` 92,7%. |
| CA-B1-22 — fila FIFO + filtros + contador | ✅ | E2E admin `fila-aprovacao` (a): "lista pendentes e filtra por profissional MEI" verde (no retry — ver ressalva flaky). |
| CA-B1-23 — detalhe com campos + template + versão | ⚠️ | Coberto indiretamente pelos cenários de fila/templates; detalhe campo-a-campo não auditado isolado. |
| CA-B1-24 — aprovar transiciona + audit + e-mail | ✅ | E2E admin `fila-aprovacao` (b): "aprova → item sai da fila e e-mail é despachado". |
| CA-B1-25 — remover com dupla confirmação + audit | ✅ | E2E admin `fila-aprovacao` (d): "remove um cadastro com confirmação dupla". |
| CA-B1-26 — race condition (2 admins) | ✅ | E2E admin `fila-aprovacao` (c): "aprovar o mesmo cadastro em 2 abas — 2ª erra com mensagem clara". |
| CA-B1-27 — indicador SLA (não-só-cor / WCAG) | ⏳ | Não verificado o indicador SLA ao vivo nesta sessão. |
| CA-B1-28..31 — editor templates (lista/histórico/validação/ativação atômica) | ✅ | E2E admin `templates-editor` (a) catálogo lista 2; (b+c) cria+ativa nova versão; (d) placeholder fora da lista bloqueado. Ativação atômica: partial unique index `template_versoes_active_per_template`. |
| CA-B1-32 — audit `version_created`/`version_activated` | ✅ (código/teste) | `admin` `TemplateServiceTest`/`TemplatesLivewireTest` verdes; AuditLogService 100%. |
| CA-B1-33 — `template_versoes` UPDATE/DELETE bloqueado | ✅ | Trigger `prevent_template_versao_content_mutation` BEFORE UPDATE + REVOKE DELETE (A.4). |
| CA-B1-34 — seed templates idempotente | ✅ | `admin` `TemplatesSeederTest` verde. |
| CA-B1-35 — SPF/DKIM/DMARC | ✅ | runbook §e-mail: dig + valores (SPF/DKIM/DMARC). |
| CA-B1-36 — `aprovacao_concedida` em inbox real | ⏳ | Entrega real a inbox/provedor não verificada (render do e-mail testado em `EmailTransacionalTest`). |
| CA-B1-37 — job lembrete (≤3, para 14d, sem duplicar) | ✅ (código) | `EnviarLembretesCadastroCommand` 95,6% + `CadastroLembrete`; worker scheduler 1/min ENABLED (A.8). Limites 3/14d não exercitados ao vivo. |
| CA-B1-38 — reset senha sem leak | ✅ | `webapp` `password_reset_test`; `NeutralPasswordResetLinkResponse` 100%. |
| CA-B1-39 — logs mascarados | ✅ (código) | `App\Support\Pii` 100%; amostra em Cloud Logging homolog não colhida. |
| CA-B1-40..43 — welcome | ✅ | `welcome_funnel_screen_test` + `WelcomeSeenTest`/`WelcomePageTest`/`WelcomeController` 100%. |
| CA-B1-44..52 — completar prof. + aceite | ✅ | `webapp` `completar_cadastro_screen_test` + `api` `CompletarCadastroProfissionalTest` (CA-9/12 conclui+aceite+ativo); núcleos altos (A.1). |
| CA-B1-45/46 — validação CPF/CNPJ + Pix | ✅ | `DocumentoValidator` 97%, `ChavePixValidator` 100%. |
| CA-B1-48 — sensíveis criptografados | ✅ (código) | casts `encrypted`: documento/chave_pix (prof), cnpj (contratante). |
| CA-B1-50 — aceite com versão correta + atômico | ✅ | `CompletarCadastroProfissionalTest` CA-9/12; `AceiteAdesaoRenderer` 100%. |
| CA-B1-51 — aceite imutável | ✅ | `api` `CompletarCadastroProfissionalTest:200` "CA-11: aceite imutável — UPDATE/DELETE lançam exceção do banco" verde; trigger + REVOKE (A.4). |
| CA-B1-52 — após aceite vira `ativo, cadastro_completo` | ✅ | `CompletarCadastroProfissionalTest` CA-9/12. |
| **CA-B1-53 (CENTRAL — PDR-012)** | ✅ | `api` `CompletarCadastroProfissionalTest:213` **"CA-16: aceite continua na versão original após admin ativar nova versão"** verde (contra Postgres real). |
| CA-B1-54..57 — completar contratante + aceite + plano | ✅ | `webapp` `completar_cadastro_contratante_screen_test`; `api` `CompletarCadastroContratanteTest` "CA-9/12: ... vira ativo com plano Member Start"; `CepLookup` 100%; CA-10 "sem versão ativa → 503, nada persiste". |

### Bloco 2 — Cobertura de testes

| Item | Status | Evidência |
|---|---|---|
| CA-2-1 — cobertura ≥ 80% por componente | ⚠️ | **api 96,1%** (gate `--min=80`); **admin 93,6%** (medido manualmente — A.2b); **webapp 76,8%** linha **app-inteiro** (inclui código fora do EPIC-001 p.ex. app_update). Cobertura do **código novo isolado** do webapp não foi medida; telas do épico têm 121 widget tests + integration_test verdes. Ressalva: webapp app-inteiro abaixo de 80% e sem gate. |
| CA-2-2 — ≥ 98% núcleos | ⚠️ | api: AceiteAdesaoRenderer 100%, ChavePixValidator 100%, AuditLogService 100%, CompletarCadastroProfissionalService 98,7%; **DocumentoValidator 97,0%** (< 98%). Sem gate de 98%. |
| CA-2-3 — E2E browser real (local, sob IDR-004) | ✅ | `make e2e` exit 0: WebApp integration_test "All tests passed" + smoke 4 passed; Backoffice 13 passed (1 flaky → retry). Versões: Chrome 148 / ChromeDriver 148. Evidência `evidence/bloco2-e2e-local.txt`. |

### Bloco 3 — Automação

| Item | Status | Evidência |
|---|---|---|
| CA-3-1 — CI verde (main) | ✅ | `gh run list`: últimos ~11 `success` (rc.42). Ressalva: CI não roda testes/cobertura/E2E (gates locais, IDR-004). |
| CA-3-2 — deploy auto homolog após rc | ✅ | `release.yml`: rc.* → build+migrate+seed+deploy+smoke; homolog em rc.42 nas 3 interfaces. |
| CA-3-3 — migrações idempotentes/reversíveis | ⚠️ | `down()` presente; rollback exercido (runbook); ausência de hotfix manual não auditada. |
| CA-3-4 — job lembrete agendado | ✅ | `turni-worker-scheduler-homolog` `* * * * *` ENABLED; worker job atualizado no release (A.8). |

### Bloco 4 — Funcionalidade observável (Métrica primária)

| Item | Status | Evidência |
|---|---|---|
| CA-4-1 (MÉTRICA PRIMÁRIA) — fim-a-fim ≤5min + aprovação ≤30s | ⚠️ | Caminho funcional completo verificado verde (integration_test cadastro/auth + E2E admin fila/aprovar). **Cronometragem exata (≤5min/≤30s) não medida pelo Validador**; PO validou ao vivo STORY-024 (rc.42) e STORY-023 (rc.41) — git log. |
| CA-4-2 — 3 tipos prof. + contratante ciclo c/ aceite | ✅ (teste) | `api` `CompletarCadastro{Profissional,Contratante}Test` (PF + contratante c/ plano); pré-cadastro PF/MEI/PJ coberto. Percurso vivo por-tipo não cronometrado. |
| CA-4-3 — backoffice operacional | ✅ | E2E admin ao vivo: fila lista/filtra/aprova/remove, race, editor cria+ativa, RBAC, logout (13 passed). homolog admin `/login` 200, `/` 302. Ressalva: 1º hit a frio 502 (cold start — A.7). |
| CA-4-4 — texto-seed v1 ativo | ✅ | `TemplatesContratuaisSeeder` no deploy; E2E `templates-editor` "catálogo lista os 2 templates do MVP" confirma os 2 templates servidos. |

### Bloco 5 — Qualidade transversal

| Item | Status | Evidência |
|---|---|---|
| CA-5-1 — gitleaks | ✅ | `ci.yml` job gitleaks (8.24.3); runs verdes. |
| CA-5-2 — composer audit + Trivy | ✅ | `ci.yml` php-lint (`composer audit`) + trivy-scan (CRITICAL,HIGH, exit 1). |
| CA-5-3 — Argon2id | ⚠️ | `.env.example` `HASH_DRIVER=argon2id`; env efetivo de homolog não inspecionado. |
| CA-5-4 — anti-enumeração | ✅ | testes pré-cadastro (banner genérico) + `password_reset_test` + `NeutralPasswordResetLinkResponse` 100%. |
| CA-5-5 — throttling Fortify | ✅ | `FortifyServiceProvider` `RateLimiter::for('login', perMinute(5))`. |
| CA-5-6 — cookies homolog (httpOnly+Secure+SameSite=Lax) | ⏳ | HSTS presente no WebApp; Set-Cookie de sessão autenticada não inspecionado (precisa fluxo login vivo). |
| CA-5-7 — LGPD: lista de dados + sensíveis criptografados | ⚠️ | casts `encrypted` confirmados; **lista atualizada de dados pessoais (LGPD) não localizada/auditada** nesta sessão. |
| CA-5-8 — audit log imutável homolog | ✅ | Ver CA-B1-12 (código+teste; runbook documenta teste prévio). |
| CA-5-9 — aceite imutável homolog | ✅ | Ver CA-B1-51 (teste CA-11 verde). |
| CA-5-10 — F-NB-1 rollback homolog | ✅ | Ver CA-B1-4 (runbook). |

### Bloco 6 — Observabilidade e acessibilidade

| Item | Status | Evidência |
|---|---|---|
| CA-6-1 — log JSON com request_id | ✅ | E2E admin "X-Request-Id está presente no response (CA-7)"; `RequestLogMiddlewareTest` verde. Formato JSON em todas as ações não amostrado linha-a-linha. |
| CA-6-2 — métricas RED | ✅ | log-based metrics: `turni_homolog_requests`, `turni_homolog_request_duration_ms`, `turni_homolog_errors_5xx`, `turni_homolog_email_failures` (A.9). |
| CA-6-3 — alertas (SLA>20h; falha envio crítico) | ❌ não-bloqueante | 3 políticas ENABLED: "falha de e-mail crítico" ✅, "indisponível", "taxa de erro 5xx alta". **Não observei alerta dedicado a "cadastro pendente >20h / risco de SLA"** (A.9). A metade "falha de envio crítico" está atendida; a metade "SLA>20h" não foi observada. |
| CA-6-4 — WCAG 2.1 AA (amostragem Lighthouse) | ⚠️ | admin `/login` **100** (sem falhas); WebApp `/login` **88** (falhas: `label`, `meta-viewport`); WebApp `/cadastro/profissional` **92** (`meta-viewport`). Evidência `evidence/lh-*.json`. Não é auditoria AA completa; amostragem conforme checklist. |

### Bloco 7 — Documentação

| Item | Status | Evidência |
|---|---|---|
| CA-7-1 — runbook (rollback/imutabilidade/SPF-DKIM-DMARC) | ✅ | `runbook-homolog.md` §rollback-migracoes, §imutabilidade, §e-mail. |
| CA-7-2 — `index.json` reflete estado real | ⚠️ | Estórias `done` ok; **`epics[EPIC-001].status="ready"`** com 012–024 `done` e validação em curso (esperado `in_review`); `validation_report=null`. |
| CA-7-3 — notas dos agentes | ✅ | Amostragem STORY-016/017/019/020/021/023/024: seções presentes. |

---

## Fails identificados

### Bloqueantes
> Nenhum.

### Não-bloqueantes

#### F-NB-1 — Alerta de risco de SLA (>20h) não observado
- **Bloco**: 6 (CA-6-3).
- **Critério esperado**: "alerta ativo quando há cadastro pendente há > 20h (risco de SLA)".
- **O que verifiquei**: Monitoring REST `alertPolicies` retornou 3 políticas ENABLED ("Turni falha de e-mail crítico", "Turni indisponível", "Turni taxa de erro 5xx alta"). Nenhuma referente a SLA/cadastro pendente.
- **Classificação**: não-bloqueante — lacuna de alerta de observabilidade (a metade "falha de envio crítico" está coberta). Per `verdict-criteria.md`: métrica/alerta não totalmente seguido = não-bloqueante.
- **Evidência**: A.9.

---

## Passes com ressalva

- **PRE-2** — EPIC-001 em `ready`, não `in_review`.
- **CA-2-1** — webapp cobertura **76,8% app-inteiro** (< 80%, sem gate); cobertura do código novo isolado não medida; telas do épico cobertas por 121 widget tests + integration_test.
- **CA-2-2** — `DocumentoValidator` 97,0% (< 98% do alvo de núcleo); sem gate de 98%.
- **CA-3-1 / CA-2-3** — CI verde, mas testes/cobertura/E2E são gates **locais** (IDR-004), não de pipeline; verificação local executada e verde.
- **CA-4-3** — admin operacional, 1º hit a frio retornou 502 (cold start Cloud Run scale-to-zero) antes de estabilizar em 200.
- **CA-6-4** — WebApp `/login` a11y 88 (`label`, `meta-viewport`) e `/cadastro` 92 (`meta-viewport`).

---

## Limitações da validação (não verificado nesta sessão e por quê)

1. **psql ao vivo no Cloud SQL homolog** — instância private-IP-only; por decisão do PO, imutabilidade evidenciada por migração+trigger+runbook+suíte `api`. Afeta CA-B1-11 (query do `admin.login`), CA-4-4 (confirmar `versao=1 ativa` por query), CA-5-7 (criptografia em repouso por query).
2. **Cronometragem exata da métrica primária** (CA-4-1) — caminho funcional verde por E2E; tempos ≤5min/≤30s não medidos pelo Validador (PO validou ao vivo STORY-023/024).
3. **Cookies de sessão autenticada** (CA-5-6, CA-B1-5) — flags httpOnly/Secure/SameSite não inspecionadas (precisa fluxo login vivo com captura de Set-Cookie).
4. **Entrega real de e-mail em inbox** (CA-B1-36) — render testado; entrega ponta-a-ponta a provedor real não percorrida.
5. **Lista LGPD de dados pessoais** (CA-5-7) — documento da lista não localizado/auditado.
6. **Argon2id efetivo em homolog** (CA-5-3) — `.env.example` ok; valor do env/secret em runtime não inspecionado.
7. **RBAC cross-host ao vivo** (CA-B1-9), **indicador SLA WCAG** (CA-B1-27), **foto signed URL** (CA-B1-18) — não percorridos.

---

## Apêndice A — Evidências detalhadas

**Reprodução geral:** commit `0e1e4068fbdb282eef6b20d965b22e07f5a030f1`, branch `main`, stack docker-compose local no ar (postgres 18 healthy), homolog `v0.1.0-rc.42`. Chrome 148 / ChromeDriver 148.

### A.1 — Cobertura `api`
`make test-api` → **238 passed (790 assertions)**, exit 0, **Total 96,1%**. Núcleos: AceiteAdesaoRenderer/ChavePixValidator/AuditLogService 100%, CompletarCadastroProfissionalService 98,7%, DocumentoValidator 97,0%. Arquivo `evidence/bloco2-api-coverage.txt`.

### A.2 — Testes/cobertura `admin`
`make test-admin` → **91 passed (201 assertions)**, exit 0. Cobertura **não** medida pelo Makefile. (A.2b) `docker compose run -e DB_DATABASE=turni_test admin pest --coverage --min=80` → **Total 93,6%**, exit 0. Arquivos `evidence/bloco2-admin-tests.txt`, `evidence/bloco2-admin-coverage.txt`.

### A.3 — Testes `webapp`
`flutter test --coverage` → **121 widget tests passed**, exit 0; lcov **76,8% (2015/2623)** app-inteiro. `evidence/bloco2-webapp-tests.txt`.

### A.4 — Imutabilidade (migrações)
- `2026_05_28_200003_create_admin_audit_log_table.php`: trigger `prevent_admin_audit_log_mutation` BEFORE UPDATE OR DELETE + `REVOKE UPDATE, DELETE`.
- `2026_05_29_130000_create_templates_and_template_versoes_table.php`: trigger `prevent_template_versao_content_mutation` BEFORE UPDATE (conteudo/template_id/versao/criado_por imutáveis) + UNIQUE INDEX `template_versoes_active_per_template WHERE ativa=TRUE` + `REVOKE DELETE`.
- `2026_06_01_120000_completar_cadastro_profissional_e_aceites.php`: trigger `prevent_aceite_eletronico_mutation` BEFORE UPDATE OR DELETE + `REVOKE UPDATE, DELETE`.
- Cobertura por teste: `CompletarCadastroProfissionalTest` CA-11 (imutável) e **CA-16 (mantém versão original após nova ativação — central PDR-012)**.

### A.5 — CI / pipeline
- `ci.yml`: commitlint, gitleaks, php-lint (pint+composer audit), flutter-lint (format+analyze), smoke-build, trivy. **Sem testes/cobertura/E2E.**
- `release.yml`: rc.* → build+migrate+seed+deploy(Cloud Run api/admin + Firebase webapp)+smoke HTTP. Comentário: "E2E é gate LOCAL — IDR-004".
- `gh run list --branch main`: ~11 últimos `success`.

### A.6 — Homolog
WebApp 200 (`/`, `/cadastro/profissional`, `/cadastro/contratante`), version rc.42. Admin Cloud Run `/version.json` rc.42, `/login` 200, `/` 302.

### A.7 — Admin cold start
1ª chamada `/health` → 502/000; após ~5 tentativas (3s) estabiliza em **200** `{"service":"backoffice","version":"v0.1.0-rc.42"}`. Consistente com Cloud Run `min-instances=0`.

### A.8 — Scheduler / Cloud SQL
`gcloud scheduler jobs list`: `turni-worker-scheduler-homolog` `* * * * *` ENABLED (+ `turni-homolog-sql-start`/`stop`). Cloud SQL `turni-homolog` `RUNNABLE`/`ALWAYS`.

### A.9 — Observabilidade
log-based metrics: `turni_homolog_requests`, `turni_homolog_request_duration_ms`, `turni_homolog_errors_5xx`, `turni_homolog_email_failures`.
alertPolicies (Monitoring REST): "Turni falha de e-mail crítico (homolog)" / "Turni indisponível (homolog)" / "Turni taxa de erro 5xx alta (homolog)" — todas `enabled:true`. **Sem** política observada para SLA>20h / cadastro pendente.

### A.10 — E2E local (`make e2e`)
exit 0. WebApp: integration_test (`web_test.dart`, same-origin via proxy:3000, `flutter drive` Chrome headless) "All tests passed"; smoke Playwright `webapp-hello-world` 4 passed. Backoffice Playwright: 13 passed, 1 flaky (`fila-aprovacao` filtro MEI: timeout 30s 1ª tentativa, passou no retry #1). `evidence/bloco2-e2e-local.txt`.

### A.11 — Acessibilidade (Lighthouse)
`npx lighthouse --only-categories=accessibility` (Chrome headless): admin `/login` **100**; WebApp `/login` **88** (label, meta-viewport); WebApp `/cadastro/profissional` **92** (meta-viewport). `evidence/lh-*.json`.

---

## Apêndice B — Arquivos anexados (`validation/evidence/`)

- `bloco2-api-coverage.txt`, `bloco2-admin-tests.txt`, `bloco2-admin-coverage.txt`, `bloco2-webapp-tests.txt` — testes/cobertura.
- `bloco2-e2e-local.txt` — saída `make e2e`.
- `lh-admin-login.json`, `lh-webapp-login.json`, `lh-webapp-cadastro-prof.json` — Lighthouse a11y.

---

## Resumo do veredito

- **Fail bloqueante**: 0
- **Fail não-bloqueante**: 1 (F-NB-1 — alerta SLA>20h não observado)
- **Pass com ressalva**: 6 (PRE-2; CA-2-1 webapp; CA-2-2 DocumentoValidator; CA-3-1/2-3 gates locais; CA-4-3 cold start; CA-6-4 a11y WebApp)
- **Pendente/Limitação (não-central, não verificado nesta sessão)**: CA-5-6 cookies, CA-B1-36 e-mail inbox, CA-4-1 cronometragem exata, CA-5-7 lista LGPD, CA-5-3 env Argon2id, CA-B1-9/18/27.
- **Pass**: demais itens (maioria do Bloco 1, Blocos 2–3–5–7 majoritariamente, métricas RED, imutabilidade, PDR-012 central, E2E local).

**Veredito final**: **`approved_with_pending`** — zero fails bloqueantes; o épico cumpre o essencial (cadastro→aprovação→completar→ativo com aceite imutável; RBAC vivo; editor de templates; PDR-012 central comprovado; observabilidade e a11y amostradas). As pendências (1 fail não-bloqueante + itens de verificação viva não percorridos) ficam para decisão do PO.

---

## Histórico

- 2026-06-01 — relatório (rodada 1, sessão 1). Evidência: pré-condições; Blocos 1–7 com cobertura medida (api/admin/webapp), E2E local em browser real verde, imutabilidade por código+teste (incl. PDR-012 central CA-16), métricas RED + alertas, Lighthouse a11y. Veredito `approved_with_pending`.
- 2026-06-01 — **Decisão do PO (Alexandro):** veredito `approved_with_pending` aceito; EPIC-001 fechado (`status: done`). Pendências (F-NB-1 alerta SLA>20h + verificações vivas não percorridas: cronometragem exata, cookies autenticados, e-mail em inbox, lista LGPD, Argon2id efetivo) tratadas como **carry-forward** sob gestão do PO. O veredito técnico do Validador permanece `approved_with_pending` (não reescrito para `approved`).
