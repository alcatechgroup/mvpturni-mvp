---
epic_id: EPIC-000
type: validation-checklist
created_at: 2026-05-28
created_by: claude-sonnet-4-6-validador
filled_at: 2026-05-28
---

# Checklist de validação — EPIC-000 Foundation

> **Preenchido pelo Validador em 2026-05-28.** Cada item tem status e evidência.

---

## Pré-condições de início

- [x] **PRE-1:** `pass` — STORY-001 a STORY-010 com `status: done` no `index.json` (verificado em 2026-05-28 após fechamento de STORY-006 pelo Programador).
- [x] **PRE-2:** `pass` — EPIC-000 com `status: in_review` no `index.json` (atualizado pelo Programador em 2026-05-28).
- [x] **PRE-3:** `pass com ressalva` — `app.homolog.turni.com.br` acessível (200). `admin.homolog.turni.com.br` **não tem DNS** — admin acessado via URL direta do Cloud Run, que retorna **403**.

---

## Bloco 1 — Critérios de aceite das estórias

### STORY-001 a STORY-005 (Spikes do Arquiteto)
- [x] **CA-B1-1:** `pass` — 9 ADRs (ADR-000 a ADR-008) existem em `decisions/adr/` com `status: accepted` e `approved_by: Alexandro` em todos. `index.json` reflete estado correto. Evidência: `ls docs/project-state/decisions/adr/*.md` → 9 arquivos; `grep "status: accepted"` → 9 matches; `grep "approved_by"` → 9 matches.

### STORY-006 (Setup do repositório)
- [x] **CA-B1-2:** `pass` — `scheduled-setup-test.yml` existe em `.github/workflows/`, roda diariamente às 03:00 UTC. Evidência: CI run #26559779061 (`Setup local test (scheduled)`) — `completed/success` em 2026-05-28T06:57.
- [x] **CA-B1-3:** `pass` — Setup em ≤5min confirmado. Evidência: notas STORY-006 "~34s" + log do hook de pré-push do Programador (2026-05-28) com `make setup` completando com sucesso.
- [x] **CA-B1-4:** `pass` — Hook de pré-push em `scripts/hooks/pre-push`, instalado via `core.hooksPath`. Evidência: push do Programador em 2026-05-28 executou o hook (saída "── pré-push: detector de segredos ── ok" + testes verdes + "pré-push ok — push liberado").

### STORY-007 (Pipeline CI/CD)
- [x] **CA-B1-5:** `FAIL BLOQUEANTE` — CI **não está verde** nos commits do EPIC-000 com código de STORY-008/009. Evidência: CI runs #26570008113 (commit `62eba0e` — STORY-008), #26572115767 (`9da1107`), #26572590149 (`8a8d71b` — STORY-009), #26572746593 (`ce0700e`), #26573607477 (`565fcf9` — commit Programador). Todos com `conclusion: failure`. Falhas: (a) `Flutter lint & analyze` — `dart format` reporta 3 arquivos alterados: `lib/ds/theme.dart`, `lib/features/welcome/welcome_screen.dart`, `lib/router.dart`; (b) `PHP lint & audit (admin)` — Pint encontra 3 style issues: `RequestLogMiddleware.php`, `bootstrap/app.php`, `RequestLogMiddlewareTest.php`. CI estava verde até commit `9887a2e` (fecha STORY-007) — quebrou a partir de `62eba0e` (STORY-008). Nota: gitleaks PASSOU em todos os runs; composer audit (api) PASSOU.
- [x] **CA-B1-6:** `pass` — Separação CI/release verificada. `ci.yml` tem `tags-ignore: ["**"]`; `release.yml` usa `push.tags`. Evidência: notas STORY-007 "Evidência de não-disparo: CI runs #26548933473 e #26549040001 são pushes em main sem tag — release.yml ficou inativo".
- [x] **CA-B1-7:** `pass com ressalva` — 3 deploys rc.1/rc.2/rc.3 consecutivos com ≤2min cada demonstraram que a pipeline funciona. Evidência: STORY-007 notas — runs #26548939383 (rc.1, ~2min), #26549114906 (rc.2, ~2min), #26549196329 (rc.3, ~2min). **Ressalva:** esses deploys foram feitos com código de STORY-007 (antes de STORY-008/009). Servem como prova do pipeline, não do código final do épico.
- [x] **CA-B1-8 (MÉTRICA PRIMÁRIA):** `FAIL BLOQUEANTE` — 3 deploys consecutivos com **código completo do épico** (incluindo STORY-008/009) nunca ocorreram. Releases rc.4, rc.5, rc.6 (commit `565fcf9`, pós-STORY-009) falharam. Evidência: runs #26573612619, #26573612690, #26573612712 — todos `conclusion: failure`. Falha em `Deploy Admin → homolog / Health check admin`: admin retorna 403 persistentemente (IAM policy não propagada). O código correto foi buildado (build passou em todos) mas **deploy admin não completou com sucesso**. Consequência: E2E nunca chegou a rodar (job `e2e-homolog` com `skipped` em todos os 3 runs).
- [x] **CA-B1-9:** `pass` — IaC em `infra/envs/homolog/` com 4 arquivos `.tf` + 10 módulos em `infra/modules/`. Terraform state confirmado em GCS bucket `turni-terraform-state` (notas STORY-007). Recriar do zero documentado em `docs/operacao/runbook-homolog.md`.
- [x] **CA-B1-10:** `fail não-bloqueante` — Rollback documentado em `docs/operacao/runbook-homolog.md#rollback` com comandos para Cloud Run (`gcloud run services update-traffic --to-revisions=PREV=100`) e Firebase (`firebase hosting:rollback`). **Sem evidência de execução de rollback em homologação.** STORY-011 CA-13 exige "ao menos uma vez testado em homologação". STORY-007 CA-10 menciona apenas "documentado". Sem log ou CI run demonstrando rollback executado.

### STORY-008 (Hello world WebApp)
- [x] **CA-B1-11:** `pass` — `app.homolog.turni.com.br` acessível com hello world. Evidência (verificado diretamente pelo Validador em 2026-05-28): `curl -s -o /dev/null -w "%{http_code}" https://app.homolog.turni.com.br/` → `200`. Página retorna title "Turni". Versão `v0.1.0-rc.4` injetada (confirmada via `/version.json`).
- [x] **CA-B1-12:** `pass` — `/health` webapp retorna 200 com payload ADR-008. Evidência: `curl https://app.homolog.turni.com.br/health` → `{"status":"ok","version":"v0.1.0-rc.4","timestamp":"2026-05-28T12:06:40Z","service":"webapp"}`. Todos os campos obrigatórios presentes.
- [x] **CA-B1-13:** `FAIL BLOQUEANTE` — E2E Playwright da webapp **nunca executou na pipeline de homologação**. Spec existe em `apps/webapp/tests/e2e/webapp-hello-world.spec.ts` (criada pelo Programador em 2026-05-28). Evidência de não-execução: job `e2e-homolog` com `skipped` em todos os 3 releases (rc.4/rc.5/rc.6) — skipped porque `deploy-admin-homolog` falhou. Nenhum CI run anterior tinha o job de E2E.
- [x] **CA-B1-14:** `pass` — Cobertura webapp 85.5% ≥ 80%. Evidência: `apps/webapp/coverage/lcov.info` — 65/76 linhas cobertas. Detalhe: `welcome_screen.dart` 93.5%, `theme.dart` 100%, `main.dart` 75%, `router.dart` 50%.
- [x] **CA-B1-15:** `pass` — PWA manifesto em `apps/webapp/web/manifest.json` (`display: standalone`, `start_url: /`) + `flutter_service_worker.js` presente no build. Evidência: arquivo verificado localmente.

### STORY-009 (Hello world Backoffice)
- [x] **CA-B1-16:** `FAIL BLOQUEANTE` — `admin.homolog.turni.com.br` inacessível. URL do Cloud Run (`https://turni-admin-homolog-dnj2tcr2xa-rj.a.run.app`) retorna **403** persistentemente. Evidência: `curl -s -o /dev/null -w "%{http_code}" https://turni-admin-homolog-dnj2tcr2xa-rj.a.run.app/health` → `403`. 12 tentativas de health check em cada release rc.4/rc.5/rc.6 retornaram 403. Causa identificada: `--allow-unauthenticated` no `gcloud run deploy` não propagou IAM policy (service account do CI provavelmente não tem permissão `roles/run.admin` para modificar IAM bindings). admin.homolog.turni.com.br não tem DNS customizado.
- [x] **CA-B1-17:** `FAIL BLOQUEANTE` — `/health` admin não verificável. Impossível acessar (403). Não é possível confirmar payload ADR-008 (`service: "backoffice"`).
- [x] **CA-B1-18:** `FAIL BLOQUEANTE` — E2E Playwright admin nunca executou. Job `e2e-homolog` com `skipped` nos 3 releases. Spec existe em `apps/admin/tests/e2e/admin-hello-world.spec.ts`.
- [x] **CA-B1-19:** `FAIL BLOQUEANTE` — Logs admin com request_id não verificáveis (admin inacessível). Notas STORY-009 confirmam implementação do `RequestLogMiddleware`, mas evidência em homolog não pode ser colhida.

### STORY-010 (DDR-001 Design System)
- [x] **CA-B1-20:** `pass` — DDR-001 em `decisions/ddr/DDR-001-fundacao-do-design-system.md` com `status: accepted` e `approved_by: Alexandro`.
- [x] **CA-B1-21:** `pass` — `docs/project-state/design/system/tokens.md` e `voice-and-tone.md` existem.
- [x] **CA-B1-22:** `pass` — Screen spec STORY-008 em `docs/project-state/design/screens/STORY-008-hello-world-webapp.md` com `status: ready`.

---

## Bloco 2 — Cobertura de testes

- [x] **CA-2-1:** `pass com ressalva` — WebApp: 85.5% verificado via lcov.info local. Admin: notas STORY-009 declaram "21 testes passando (39 assertions)" mas cobertura formal não medida (sem Xdebug na imagem dev). API: notas STORY-007 declaram 100% nos testes de /health. **Ressalva:** cobertura de admin e API não tem artefato formal de CI (Xdebug/PHPUnit coverage) — baseado exclusivamente em declaração do Programador.
- [x] **CA-2-2:** `n/a` — EPIC-000 não implementa regras de negócio (apenas `/health`, versionamento, identidade visual). Não há módulo de núcleo a verificar com régua 98%. Justificativa alinhada com STORY-011 CA-9.
- [x] **CA-2-3:** `FAIL BLOQUEANTE` — E2E webapp em browser real **nunca executou na pipeline**. Spec existe mas o job `e2e-homolog` nunca rodou (skipped nos 3 releases).
- [x] **CA-2-4:** `FAIL BLOQUEANTE` — E2E admin em browser real nunca executou. Mesma causa de CA-2-3.

---

## Bloco 3 — Automação

- [x] **CA-3-1:** `pass` — Setup automatizado em ≤5min. Evidência: notas STORY-006 + hook de pré-push executado com sucesso em 2026-05-28.
- [x] **CA-3-2:** `pass` — `scheduled-setup-test.yml` ativo; run #26559779061 executado em 2026-05-28T06:57 com `success`.
- [x] **CA-3-3:** `FAIL BLOQUEANTE` — CI **não está verde** nos últimos commits em `main` após STORY-009. Falhas desde commit `62eba0e` (STORY-008). 5 CI runs consecutivos com `failure` (Flutter format + PHP Pint). Última execução verde: `9887a2e` (fecha STORY-007, 2026-05-27).
- [x] **CA-3-4:** `FAIL BLOQUEANTE` — 3 deploys consecutivos com código completo do épico não ocorreram. Releases rc.4, rc.5, rc.6 (todos sobre commit `565fcf9`, pós-STORY-009) com `failure`. Evidência: runs #26573612619, #26573612690, #26573612712.
- [x] **CA-3-5:** `pass` — Deploy para produção automatizado com gate humano. `release.yml` tem job `deploy-prod` com `environment: name: prod` (GitHub Environment com revisor obrigatório configurado). Evidência: arquivo verificado.
- [x] **CA-3-6:** `pass` — Ambientes homolog em IaC (`infra/envs/homolog/main.tf`). Terraform state em GCS. Recriar do zero documentado em `docs/operacao/runbook-homolog.md`.

---

## Bloco 4 — Funcionalidade observável

- [x] **CA-4-1:** `pass` — `app.homolog.turni.com.br` retorna página inicial (200), versão `v0.1.0-rc.4` via `/version.json`, `/health` 200 com payload ADR-008. Verificado diretamente pelo Validador em 2026-05-28.
- [x] **CA-4-2:** `FAIL BLOQUEANTE` — `admin.homolog.turni.com.br` não tem DNS; URL direta do Cloud Run retorna 403. Não é possível verificar nenhum conteúdo do admin.
- [x] **CA-4-3:** `fail não-bloqueante` — Percurso manual end-to-end incompleto. WebApp verificado com sucesso (abre, versão visível, link /health funciona). Admin inacessível — percurso não pode ser completado. Sem admin, a definição do EPIC-000 ("ambas as URLs") não está atingida.
- [x] **CA-4-4:** `n/a com ressalva` — Logs e métricas: Cloud Logging e Monitoring Terraform aplicados (STORY-007 notas). WebApp (Firebase) gera logs de acesso automáticos. **Ressalva:** Admin e API sem DNS customizado — uptime checks do Cloud Monitoring para essas URLs provavelmente falham. Não foi possível verificar Cloud Logging diretamente (sem acesso gcloud no escopo desta sessão).

---

## Bloco 5 — Qualidade transversal

- [x] **CA-5-1:** `pass` — Gitleaks passou em todos os CI runs verificados. Evidência: CI run #26573607477 — job `Secret scan (gitleaks)` com `success`. Run #26559779061 (scheduled) também passou. Nenhum segredo detectado.
- [x] **CA-5-2:** `pass com ressalva` — `composer audit` (api) PASSOU em CI run #26573607477. Trivy foi **skipped** porque `smoke-build-php` foi skipped (dependia de `php-lint` que falhou por causa do Pint do admin). **Ressalva:** Trivy não executou nos últimos 5 CI runs. Última execução verde com Trivy foi anterior ao STORY-008. O gate de vulnerabilidade de imagens de container não foi verificado para o código atual.
- [x] **CA-5-3:** `fail não-bloqueante` — Migrações de banco: arquivos em `apps/api/database/migrations/` — são as 3 migrações padrão do Laravel (users, cache, jobs). Todas têm método `down()` (verificado). Runbook documenta rollback forward-only para schema. **Sem evidência de rollback executado em homologação** — CA-13 de STORY-011 exige teste.
- [x] **CA-5-4:** `n/a` — EPIC-000 não coleta dados pessoais. Nenhuma tabela de usuários real criada (apenas seed de admin de teste). LGPD entra a partir de EPIC-001.
- [x] **CA-5-5:** `n/a com ressalva` — Cloud Monitoring configurado via Terraform (notas STORY-007 CA-11 "ativo após terraform apply"). Canal de e-mail para Alexandro configurado. **Ressalva:** uptime check para admin usa host `admin.homolog.turni.com.br` (sem DNS) e para API usa `api.homolog.turni.com.br` (sem DNS — Cloud Run domain mapping não suportado em southamerica-east1). Esses checks provavelmente estão falhando silenciosamente. WebApp (`app.homolog.turni.com.br` → Firebase) deve funcionar. Não verificável diretamente nesta sessão.

---

## Bloco 6 — Documentação

- [x] **CA-6-1:** `pass` — READMEs existem em `/README.md`, `apps/webapp/README.md`, `apps/admin/README.md`. Verificados como presentes e com conteúdo relevante.
- [x] **CA-6-2:** `pass` — 9 ADRs (ADR-000 a ADR-008) indexados em `index.json` com `status: accepted` em todos.
- [x] **CA-6-3:** `pass` — DDR-001 em `index.json` com `status: accepted`.
- [x] **CA-6-4:** `pass` — IDR-002 e IDR-003 em `index.json`. Ambos com `status: accepted` e arquivos correspondentes em `decisions/idr/`.
- [x] **CA-6-5:** `pass` — "Notas do agente" preenchidas em todas as 10 estórias. Verificação por cabeçalho + presença de entradas datadas (2026-05-27 ou 2026-05-28) em cada arquivo.
- [x] **CA-6-6:** `pass` — `docs/operacao/runbook-homolog.md` existe com seções de setup, operação e rollback (CA-10 de STORY-007). Comandos viáveis e documentados.
- [x] **CA-6-7:** `pass` — Rollback descrito em `runbook-homolog.md#rollback` com comandos Cloud Run (`gcloud run services update-traffic`) e Firebase (`firebase hosting:rollback`). Procedimento claro para executor.

---

## Bloco 7 — Veredito

- [ ] **CA-7-1:** ~~APROVADO~~ — não se aplica.
- [x] **CA-7-2:** **REPROVADO** — 7 fails identificados (5 bloqueantes, 2 não-bloqueantes). Lista detalhada no `report.md`.

---

## Contagem de resultados

| Status | Quantidade |
|---|---|
| `pass` | 20 |
| `pass com ressalva` | 4 |
| `n/a` | 1 |
| `n/a com ressalva` | 2 |
| `fail bloqueante` | 8 |
| `fail não-bloqueante` | 2 |

**Veredito: REJECTED** — 8 fails bloqueantes impedem aprovação do EPIC-000.
