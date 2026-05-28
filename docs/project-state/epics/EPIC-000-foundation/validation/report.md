---
epic_id: EPIC-000
type: validation-report
verdict: rejected
validated_at: 2026-05-28
validated_by: claude-sonnet-4-6-validador
checklist: epics/EPIC-000-foundation/validation/checklist.md
---

# Relatório de Validação — EPIC-000 Foundation

## TL;DR

**VEREDITO: REJECTED**

5 bloqueantes identificados. O EPIC-000 está substancialmente construído — WebApp em homolog funciona, ADRs estão completas, pipeline existe e foi demonstrado — mas 3 problemas estruturais impedem o `done`:

1. **CI RED desde STORY-008** — lint gates quebrados (Dart format + PHP Pint)
2. **Admin homolog inacessível** — 403 em todas as tentativas (IAM policy não propagada)
3. **E2E nunca rodou na pipeline** — releases rc.4/rc.5/rc.6 falharam antes de atingir o job de E2E

---

## Resumo executivo

A validação do EPIC-000 Foundation foi executada em 2026-05-28 cobrindo as 10 estórias do épico (spikes de arquitetura, setup de repositório, pipeline CI/CD, hello world WebApp e Backoffice, Design System). O épico entregou valor sólido: 9 ADRs formalizadas, pipeline tag-based funcionando, WebApp deployado em `app.homolog.turni.com.br` com versão `v0.1.0-rc.4`, health-check verde, cobertura de testes ≥ 80% no código novo, e setup local em 34s. O ponto crítico de falha é o conjunto CI + admin: o lint do CI quebrou a partir do commit da STORY-008 (flutter format e pint) e o admin em homolog está inacessível (403) porque o `--allow-unauthenticated` do `gcloud run deploy` não propagou a IAM policy. Essas duas falhas em cadeia impediram que os 3 deploys rc.4/rc.5/rc.6 completassem com sucesso e que os testes E2E rodassem na pipeline. O EPIC-000 não pode ser marcado como `done` até que esses itens sejam corrigidos e uma nova rodada de validação confirme os CAs pendentes.

---

## Checklist — resultado por bloco

### Bloco 1 — Critérios de aceite das estórias

| Item | Status | Evidência resumida |
|---|---|---|
| CA-B1-1 (9 ADRs) | `pass` | 9 arquivos em `decisions/adr/`, todos `accepted` + `approved_by` |
| CA-B1-2 (CI periódico setup) | `pass` | Run #26559779061 — `success` em 2026-05-28T06:57 |
| CA-B1-3 (setup ≤5min) | `pass` | 34s — notas STORY-006 + pré-push 2026-05-28 |
| CA-B1-4 (hook pré-push) | `pass` | Hook executado com sucesso no push de 2026-05-28 |
| **CA-B1-5 (CI verde)** | **FAIL BLOQUEANTE** | Runs #26570008113→#26573607477: Flutter format + PHP Pint falham em todos |
| CA-B1-6 (deploy tag-based) | `pass` | ci.yml `tags-ignore`; release.yml `push.tags` — verificado no código |
| CA-B1-7 (3 deploys rc.1-3) | `pass com ressalva` | ≤2min/deploy nos 3 RCs; código pré-STORY-008/009 |
| **CA-B1-8 (métrica primária)** | **FAIL BLOQUEANTE** | rc.4/rc.5/rc.6 todos `failure`; admin 403 |
| CA-B1-9 (IaC) | `pass` | `infra/envs/homolog/*.tf` + state GCS |
| CA-B1-10 (rollback testado) | `fail não-bloqueante` | Documentado; sem evidência de execução em homolog |
| CA-B1-11 (WebApp URL) | `pass` | `https://app.homolog.turni.com.br` → 200, versão v0.1.0-rc.4 |
| CA-B1-12 (/health webapp) | `pass` | `{"status":"ok","version":"v0.1.0-rc.4","service":"webapp"}` |
| **CA-B1-13 (E2E webapp pipeline)** | **FAIL BLOQUEANTE** | Job `e2e-homolog` skipped nos 3 releases; spec existe mas nunca rodou |
| CA-B1-14 (cobertura webapp) | `pass` | 85.5% via lcov.info (65/76 linhas) |
| CA-B1-15 (PWA) | `pass` | `manifest.json` + `flutter_service_worker.js` presentes |
| **CA-B1-16 (Admin URL)** | **FAIL BLOQUEANTE** | 403 em todas as requisições; sem DNS customizado |
| **CA-B1-17 (/health admin)** | **FAIL BLOQUEANTE** | Não verificável (admin 403) |
| **CA-B1-18 (E2E admin pipeline)** | **FAIL BLOQUEANTE** | Job `e2e-homolog` skipped; spec existe mas nunca rodou |
| CA-B1-19 (logs admin) | **FAIL BLOQUEANTE** | Não verificável (admin 403) |
| CA-B1-20 (DDR-001) | `pass` | `accepted` + `approved_by: Alexandro` |
| CA-B1-21 (tokens.md) | `pass` | Arquivos existem em `design/system/` |
| CA-B1-22 (screen spec) | `pass` | `status: ready` em `design/screens/STORY-008-*.md` |

### Bloco 2 — Cobertura de testes

| Item | Status | Evidência |
|---|---|---|
| CA-2-1 (cobertura ≥80%) | `pass com ressalva` | WebApp 85.5% formal; admin/api declarados pelo Programador sem artefato CI |
| CA-2-2 (núcleo ≥98%) | `n/a` | Sem regras de negócio em EPIC-000 |
| **CA-2-3 (E2E webapp CI)** | **FAIL BLOQUEANTE** | Nunca executou na pipeline |
| **CA-2-4 (E2E admin CI)** | **FAIL BLOQUEANTE** | Nunca executou na pipeline |

### Bloco 3 — Automação

| Item | Status | Evidência |
|---|---|---|
| CA-3-1 (setup automático) | `pass` | ≤5min, reprodutível |
| CA-3-2 (CI periódico setup) | `pass` | Run #26559779061 — success |
| **CA-3-3 (CI verde main)** | **FAIL BLOQUEANTE** | 5 runs consecutivos com failure desde commit `62eba0e` |
| **CA-3-4 (3 deploys código final)** | **FAIL BLOQUEANTE** | rc.4/rc.5/rc.6 com failure |
| CA-3-5 (deploy prod gated) | `pass` | release.yml com `environment: prod` + revisor |
| CA-3-6 (IaC) | `pass` | Terraform em git + state aplicado |

### Bloco 4 — Funcionalidade observável

| Item | Status | Evidência |
|---|---|---|
| CA-4-1 (WebApp funciona) | `pass` | Verificado diretamente: 200, v0.1.0-rc.4, /health OK |
| **CA-4-2 (Admin funciona)** | **FAIL BLOQUEANTE** | 403 — inacessível |
| CA-4-3 (percurso manual) | `fail não-bloqueante` | WebApp OK; admin inacessível — percurso incompleto |
| CA-4-4 (logs/métricas) | `n/a com ressalva` | Terraform aplicado; DNS ausente para api/admin pode comprometer uptime checks |

### Bloco 5 — Qualidade transversal

| Item | Status | Evidência |
|---|---|---|
| CA-5-1 (gitleaks) | `pass` | Job `Secret scan` com success em todos os runs verificados |
| CA-5-2 (composer audit/trivy) | `pass com ressalva` | composer audit (api) pass; Trivy skipped por dependência de lint falho |
| CA-5-3 (rollback testado) | `fail não-bloqueante` | Documentado; sem evidência de execução em homolog |
| CA-5-4 (LGPD) | `n/a` | Sem dados pessoais no EPIC-000 |
| CA-5-5 (health-check externo) | `n/a com ressalva` | Infraestrutura configurada; DNS de api/admin ausente pode comprometer checks |

### Bloco 6 — Documentação

| Item | Status | Evidência |
|---|---|---|
| CA-6-1 (READMEs) | `pass` | 3 READMEs existentes e com conteúdo |
| CA-6-2 (ADRs no index.json) | `pass` | 9 ADRs indexadas |
| CA-6-3 (DDR-001 no index.json) | `pass` | Indexado com `accepted` |
| CA-6-4 (IDRs no index.json) | `pass` | IDR-002 e IDR-003 indexados |
| CA-6-5 (notas do agente) | `pass` | Preenchidas nas 10 estórias |
| CA-6-6 (runbook) | `pass` | `docs/operacao/runbook-homolog.md` com conteúdo viável |
| CA-6-7 (rollback documentado) | `pass` | Seção `#rollback` com comandos Cloud Run + Firebase |

---

## Fails bloqueantes — detalhe

### FAIL-1: CI RED desde STORY-008 (CA-B1-5, CA-3-3)

**O que foi observado:** O CI nunca ficou verde para o código de STORY-008 ou STORY-009. A partir do commit `62eba0e` (feat: hello world WebApp, 2026-05-28T10:45), 5 CI runs consecutivos terminaram com `failure`:

- Run #26570008113 — commit `62eba0e` — Flutter format: 3 arquivos com formatação não-padrão
- Run #26572115767 — commit `9da1107` — mesma falha
- Run #26572590149 — commit `8a8d71b` — Flutter format + PHP Pint (admin): 3 style issues
- Run #26572746593 — commit `ce0700e` — mesmas falhas
- Run #26573607477 — commit `565fcf9` — mesmas falhas

**Arquivos afetados:**
- Flutter: `lib/ds/theme.dart`, `lib/features/welcome/welcome_screen.dart`, `lib/router.dart`
- PHP (admin): `app/Http/Middleware/RequestLogMiddleware.php`, `bootstrap/app.php`, `tests/Feature/RequestLogMiddlewareTest.php`

**Impacto:** Smoke builds e Trivy ficaram skipped (dependem de lint). CI não atua como gate de qualidade para o código atual do épico.

**Nota:** Pré-push hook não detectou esse problema porque não executa Pint em modo `--test` nem `dart format` em modo check — executa apenas testes (Pest + Flutter test). O hook cobre o que foi especificado, mas não cobre lint de estilo.

---

### FAIL-2: Admin homolog inacessível (CA-B1-8, CA-B1-16, CA-B1-17, CA-B1-19, CA-4-2)

**O que foi observado:** O admin no Cloud Run retorna 403 em 100% das requisições. URL direta: `https://turni-admin-homolog-dnj2tcr2xa-rj.a.run.app/health` → 403. `admin.homolog.turni.com.br` não tem DNS.

**Causa aparente:** O `gcloud run deploy --allow-unauthenticated` foi adicionado ao job de deploy (IDR-003), mas a IAM policy `roles/run.invoker` para `allUsers` não foi aplicada. Provável causa: a service account do CI (`GCP_SERVICE_ACCOUNT`) não tem `roles/iam.serviceAccountAdmin` ou `roles/run.admin` para modificar IAM bindings do serviço Cloud Run.

**Consequência em cascata:** O job `Deploy Admin → homolog` falha no health check → os releases rc.4, rc.5, rc.6 terminam com `failure` → job `e2e-homolog` não executa (skipped por dependência).

---

### FAIL-3: E2E nunca rodou na pipeline (CA-B1-13, CA-B1-18, CA-2-3, CA-2-4)

**O que foi observado:** O job `e2e-homolog` aparece como `skipped` em todos os 3 releases (rc.4, rc.5, rc.6). Causa direta: dependência de `deploy-admin-homolog` que falhou. Nenhum CI run anterior tinha o job de E2E (adicionado pelo Programador no commit `565fcf9`).

**Status das specs:** Existem e são válidas — `apps/admin/tests/e2e/admin-hello-world.spec.ts` (6 cenários) e `apps/webapp/tests/e2e/webapp-hello-world.spec.ts` (4 cenários). Nunca executadas em ambiente de CI.

---

## Fails não-bloqueantes — detalhe

### FAIL-NB-1: Rollback sem evidência de teste (CA-B1-10, CA-5-3)

Runbook documenta procedimento (`gcloud run services update-traffic`, `firebase hosting:rollback`). Não há log ou CI run demonstrando rollback executado em homologação. STORY-011 CA-13 exige "ao menos uma vez testado em homologação".

### FAIL-NB-2: Percurso manual incompleto (CA-4-3)

WebApp percorrido com sucesso (URL 200, versão visível, /health clicável e funcional). Admin inacessível — percurso end-to-end nas "duas interfaces" não completado.

---

## O que está funcionando bem (para referência do PO)

- WebApp `app.homolog.turni.com.br` → live com v0.1.0-rc.4, health-check verde, versão correta
- Pipeline tag-based: estrutura correta, demonstrada em rc.1/rc.2/rc.3 (STORY-007)
- 9 ADRs formalizadas e aprovadas — fundação arquitetural sólida
- Cobertura webapp ≥ 80% (85.5%) com artefato formal
- Setup local em 34s (1 comando)
- Gitleaks: sem segredos detectados em nenhum commit
- Rollback documentado e procedimento viável

---

## Recomendações ao PO (sem decidir por ele)

### Para as estórias de correção

**STORY-012 — Correção de lint (CI)**
Corrigir formatação Dart em 3 arquivos de STORY-008 e style PHP (Pint) em 3 arquivos de STORY-009. Pequena estória de fixup — pode ser feita em 1 sessão. O pré-push hook deveria também ser reforçado para incluir `dart format --check` e `pint --test` evitando regressão.

**STORY-013 — IAM do admin homolog (desbloqueio do admin)**
Investigar e corrigir a razão pela qual `gcloud run deploy --allow-unauthenticated` não está propagando a IAM policy. Opções: (a) verificar/expandir permissões do `GCP_SERVICE_ACCOUNT` para `roles/run.admin`; (b) usar `gcloud run services set-iam-policy` como step separado; (c) executar `terraform apply` com a mudança de `allow_unauthenticated = true` que está no código mas ainda não aplicada via Terraform. Após resolução, nova tag dispara deploy e valida que admin está acessível.

Após STORY-012 e STORY-013: criar nova tag rc.N (mínimo 3 consecutivas) para que os releases completem com sucesso, E2E rode e a métrica primária seja satisfeita com o código completo do épico.

**STORY-014 — Rollback testado em homolog (não-bloqueante)**
Executar rollback de Cloud Run + Firebase em homologação e documentar evidência no runbook. Pode ser feito após STORY-013 quando o admin estiver acessível.

**Sobre uptime checks de admin/API (não-bloqueante)**
O Arquiteto pode querer endereçar o fato de que `api.homolog.turni.com.br` e `admin.homolog.turni.com.br` não têm DNS customizado funcional em homolog (Cloud Run domain mapping não suportado na região). Os uptime checks do Cloud Monitoring para essas URLs provavelmente estão falhando silenciosamente. Isso pode virar ADR ou IDR de acesso.

---

## Veredito final

**REJECTED**

O EPIC-000 demonstrou fundação técnica sólida (pipeline, ADRs, WebApp, setup local), mas os 3 bloqueios identificados (CI RED, admin inacessível, E2E nunca rodou) são todos diretamente relacionados à métrica primária do épico: "merge em main dispara deploy automático para AMBAS as homologações em ≤ 10 min, com health-check verde no fim". Essa condição não foi satisfeita com o código completo do épico.

Após correção das STORY-012 e STORY-013 e nova rodada de deploys, **esta validação deve ser reexecutada** cobrindo especificamente os itens que falharam. Os itens que passaram não precisam ser reverificados a menos que os commits de correção os afetem.

---

*Relatório produzido pelo Validador independente em 2026-05-28. Decisão de abrir estórias de correção e marcar o épico é do PO.*
