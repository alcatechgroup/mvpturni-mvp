---
epic_id: EPIC-000
type: validation-checklist
created_at: 2026-05-28
created_by: claude-sonnet-4-6-validador
---

# Checklist de validação — EPIC-000 Foundation

> Para o **validador**: execute cada item em ordem. Para cada um, registre status `pass | fail | n/a` e evidência (link, screenshot, log). Não invente resultados. Em caso de falha, **não tente consertar** — registre e devolva para o PO.

---

## Pré-condições de início

- [ ] **PRE-1:** Todas as estórias do EPIC-000 (STORY-001 a STORY-010) estão com `status: done` no `index.json`.
- [ ] **PRE-2:** EPIC-000 está com `status: in_review` no `index.json`.
- [ ] **PRE-3:** Ambiente de homologação acessível (`app.homolog.turni.com.br` e `admin.homolog.turni.com.br`).

> **Nota:** Se qualquer pré-condição falhar, o validador para e notifica o PO antes de prosseguir.

---

## Bloco 1 — Critérios de aceite das estórias

### STORY-001 a STORY-005 (Spikes do Arquiteto)
- [ ] **CA-B1-1:** STORY-001 a STORY-005 `done` e ADRs produzidas (ADR-000 a ADR-008) existem com `status: accepted` e `approved_by` preenchido. Evidência: arquivos em `decisions/adr/` + `index.json`.

### STORY-006 (Setup do repositório)
- [ ] **CA-B1-2 (CA-8 via STORY-007):** Setup testado em CI periódico — `scheduled-setup-test.yml` existe e está ativo. Evidência: arquivo no `.github/workflows/` + execução de CI documentada.
- [ ] **CA-B1-3:** `make setup` (ou equivalente) sobe o stack local em ≤ 5 min — evidência nas notas da STORY-006.
- [ ] **CA-B1-4:** Hook de pré-push versionado e instalado automaticamente. Evidência: `scripts/hooks/` + configuração.

### STORY-007 (Pipeline CI/CD)
- [ ] **CA-B1-5:** CI em PRs dispara lint + scanners + smoke build (sem banco/browser). Evidência: `.github/workflows/ci.yml` + CI run #26549040001.
- [ ] **CA-B1-6:** Deploy é tag-based exclusivo (push/merge em `main` sem tag NÃO dispara release). Evidência: `ci.yml` com `tags-ignore` + `release.yml` com `push.tags`.
- [ ] **CA-B1-7:** 3 deploys consecutivos (rc.1, rc.2, rc.3) com deploy ≤ 10 min e health-check verde. Evidência: runs #26548939383, #26549114906, #26549196329.
- [ ] **CA-B1-8 (MÉTRICA PRIMÁRIA):** Os 3 deploys são com código do EPIC-000 completo (incluindo STORY-008/009). **Requer tag pós-STORY-009.** Evidência: nova tag + CI run pós-commit `ce0700e`.
- [ ] **CA-B1-9:** IaC em `infra/envs/homolog/` provisionando ambas as interfaces. Evidência: Terraform state ativo.
- [ ] **CA-B1-10:** Rollback documentado e testado. Evidência: `docs/operacao/runbook-homolog.md#rollback`.

### STORY-008 (Hello world WebApp)
- [ ] **CA-B1-11:** `app.homolog.turni.com.br` retorna página de boas-vindas com versão e link para `/health`. Evidência: screenshot + curl.
- [ ] **CA-B1-12:** `/health` retorna 200 com payload conforme ADR-008. Evidência: curl response.
- [ ] **CA-B1-13:** E2E Playwright executa verde em homolog. Evidência: CI run após deploy.
- [ ] **CA-B1-14:** Cobertura unitária ≥ 80% (webapp). Evidência: `85.5%` nas notas (verificar CI).
- [ ] **CA-B1-15:** PWA manifesto + service worker presentes. Evidência: DevTools / Lighthouse.

### STORY-009 (Hello world Backoffice)
- [ ] **CA-B1-16:** `admin.homolog.turni.com.br` retorna página identificadora com versão e link para `/health`. Evidência: screenshot + curl.
- [ ] **CA-B1-17:** `/health` retorna 200 com payload ADR-008 (`service: "backoffice"`). Evidência: curl.
- [ ] **CA-B1-18:** E2E Playwright executa verde em homolog. Evidência: CI run após deploy.
- [ ] **CA-B1-19:** Logs com `request_id` propagado. Evidência: log de request em homolog.

### STORY-010 (DDR-001 Design System)
- [ ] **CA-B1-20:** DDR-001 existe com `status: accepted` e `approved_by`. Evidência: `decisions/ddr/DDR-001-fundacao-do-design-system.md`.
- [ ] **CA-B1-21:** `design/system/tokens.md` e `design/system/voice-and-tone.md` existem. Evidência: arquivos no repo.
- [ ] **CA-B1-22:** Screen spec de STORY-008 em `design/screens/STORY-008-hello-world-webapp.md` com status `ready`. Evidência: arquivo.

---

## Bloco 2 — Cobertura de testes

- [ ] **CA-2-1:** Cobertura unitária do código novo ≥ **80%** — api (PHP), admin (PHP), webapp (Dart). Evidência: relatório do CI ou ferramenta de cobertura.
- [ ] **CA-2-2:** Cobertura unitária de módulos de núcleo/regras de negócio ≥ **98%** — N/A justificável: EPIC-000 não implementa regras de negócio (apenas `/health`, versionamento, identidade visual). Registrar `n/a` com justificativa.
- [ ] **CA-2-3:** E2E em browser real para WebApp (`app.homolog.turni.com.br`) executado com sucesso. Evidência: CI run.
- [ ] **CA-2-4:** E2E em browser real para Backoffice (`admin.homolog.turni.com.br`) executado com sucesso. Evidência: CI run.

---

## Bloco 3 — Automação

- [ ] **CA-3-1:** Setup de ambiente local automatizado em ≤ 5 min (evidência nas notas STORY-006). Evidência: log de `make setup`.
- [ ] **CA-3-2:** Job periódico (`scheduled-setup-test.yml`) testa setup em máquina limpa — ativo e com pelo menos 1 execução. Evidência: histórico de CI runs agendados.
- [ ] **CA-3-3:** CI verde nos últimos commits em `main` após STORY-009. Evidência: link para CI run.
- [ ] **CA-3-4:** Deploy para homologação automático via tag — verificado com ≥ 3 tags consecutivas (incluindo pós-STORY-009). Evidência: CI runs de release.
- [ ] **CA-3-5:** Deploy para produção automatizado (com gate humano) — pipeline existe e está scaffolded. Evidência: `release.yml` com path para produção.
- [ ] **CA-3-6:** Ambientes de homologação em IaC — `infra/envs/homolog/` em git com Terraform aplicado. Evidência: state GCS + `terraform show`.

---

## Bloco 4 — Funcionalidade observável

- [ ] **CA-4-1:** `app.homolog.turni.com.br` retorna página inicial com versão e link para `/health` verde. Evidência: screenshot manual + curl.
- [ ] **CA-4-2:** `admin.homolog.turni.com.br` retorna página identificadora com versão e link para `/health` verde. Evidência: screenshot manual + curl.
- [ ] **CA-4-3:** Percurso manual end-to-end: abre ambas as URLs, vê health-check — funcionou sem erro. Evidência: notas do validador.
- [ ] **CA-4-4:** Logs e métricas básicas visíveis no destino de ADR-008 (Cloud Logging ou equivalente). Evidência: link para dashboard ou comando de query.

---

## Bloco 5 — Qualidade transversal

- [ ] **CA-5-1:** Scanner de segurança (gitleaks) passou em todos os CIs do épico — nenhum segredo detectado. Evidência: link para CI run.
- [ ] **CA-5-2:** Scanner de vulnerabilidades de dependências (composer audit + trivy) sem aviso crítico aberto introduzido pelo épico. Evidência: CI run.
- [ ] **CA-5-3:** Migração de banco (`migrations/` inicial) é reversível — `php artisan migrate:rollback` testado. Evidência: log ou nota no STORY-006/007.
- [ ] **CA-5-4:** LGPD — nenhum dado pessoal sendo coletado ainda. `n/a` justificável (EPIC-000 não coleta dados de usuário; entra a partir do EPIC-001). Registrar justificativa.
- [ ] **CA-5-5:** Health-check externo (CA-11 de STORY-007) ativo e alerta configurado para Alexandro. Evidência: Cloud Monitoring alert policy + canal de notificação.

---

## Bloco 6 — Documentação

- [ ] **CA-6-1:** READMEs do repositório raiz, WebApp (`apps/webapp/`) e Backoffice (`apps/admin/`) atualizados. Evidência: leitura dos arquivos + coerência com estado final.
- [ ] **CA-6-2:** As 9 ADRs (ADR-000 a ADR-008) existem em `decisions/adr/` com `status: accepted` e entradas no `index.json`. Evidência: `index.json` + arquivos.
- [ ] **CA-6-3:** DDR-001 existe em `decisions/ddr/` com `status: accepted`. Evidência: arquivo + `index.json`.
- [ ] **CA-6-4:** IDR-002 existe em `decisions/idr/` e está no `index.json`. Evidência: arquivo + `index.json`.
- [ ] **CA-6-5:** "Notas do agente" preenchidas em STORY-001, STORY-002, STORY-003, STORY-004, STORY-005, STORY-006, STORY-007, STORY-008, STORY-009, STORY-010. Evidência: leitura das seções.
- [ ] **CA-6-6:** Runbook de recriação de homolog (`docs/operacao/runbook-homolog.md`) existe e é viável. Evidência: leitura do arquivo.
- [ ] **CA-6-7:** Runbook de rollback (`docs/operacao/runbook-homolog.md#rollback`) existe e descreve procedimento executável. Evidência: leitura.

---

## Bloco 7 — Veredito

- [ ] **CA-7-1:** **APROVADO** — todos os itens acima `pass` ou `n/a` justificado. Zero fails.
- [ ] **CA-7-2:** **REPROVADO** — pelo menos um `fail`. Listar no relatório e propor estórias de correção.

> Preencher `validation/report.md` com veredito e evidências consolidadas.

---

## Legenda de status

| Status | Significado |
|---|---|
| `pass` | Atende o critério com evidência verificável |
| `pass com ressalva` | Atende o critério, mas há detalhe que o PO deve conhecer |
| `fail` | Não atende o critério (com evidência) |
| `n/a` | Não se aplica a este épico (com justificativa em prosa) |
