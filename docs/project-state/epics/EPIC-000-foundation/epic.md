---
epic_id: EPIC-000
slug: foundation
title: Foundation — stack decidida, pipelines duplos rodando, hello world em homologação
wave: WAVE-2026-01
status: done
owner_role: po
created_at: 2026-05-26
updated_at: 2026-05-28
closed_at: 2026-05-28
closed_by: PO (Alexandro / Claude)
target_completion: 2026-06-09  # estimativa orientativa — fechou 12 dias antes
actual_completion: 2026-05-28
stories_detailed_at: 2026-05-26  # Fluxo C concluído — 11 estórias escritas e em status `ready`
validation_verdict: approved_with_pending  # 0 fails bloqueantes; 1 fail não-bloqueante carregado como pendência operacional
---

# EPIC-000 — Foundation

## Por que existimos (problema do usuário)

Antes de qualquer feature do Turni existir, precisamos da fundação técnica: linguagem, framework, banco, hospedagem, pipelines, ambientes, observabilidade básica. Sem essa fundação, o primeiro épico de funcionalidade não tem onde rodar — vira ficção. E sem **duas interfaces em homologação desde o dia 1** (PDR-003), o backoffice fica "para depois" e a equipe Turni acaba operando manualmente no banco quando o volume começar.

Este épico não entrega valor para profissional nem contratante — entrega valor para o **time** (Alexandro nos 5 papéis), destravando todos os épicos seguintes.

## Resultado esperado (outcome)

Ao fim deste épico, o time tem **stack escolhida e registrada em ADRs vigentes**, **pipelines automáticos em verde** publicando em duas URLs públicas de homologação a cada merge na main, e **"hello world" deployado** em ambas. A partir daqui, qualquer estória do EPIC-001 começa "com o motor já ligado".

## Métrica de sucesso (como saberemos que funcionou)

- **Primária**: merge na `main` dispara deploy automático para ambas as homologações em ≤ 10 min, com health-check verde no fim. Repetível em 3 merges consecutivos sem intervenção manual.
- **Qualidade**: pipeline tem TDD/E2E configurados desde a primeira estória (mesmo que com 1 teste trivial cada — o aparato precisa estar lá).
- **Decisões**: ADRs aceitos cobrindo stack, hospedagem, monorepo vs polirepo, integração Pagar.me (alto nível), estratégia de habitualidade, autenticação, observabilidade mínima, formalização retroativa do PostgreSQL (ADR-000).

## Entregável visível no fim do épico

- [x] `https://app.homolog.turni.com.br` retorna página inicial com versão e link para health-check `/health` em verde. *(verificado em 2026-05-28: HTTP 200, v0.1.0-rc.12, `/health` payload ADR-008 ok)*
- [x] `https://admin.homolog.turni.com.br` retorna página inicial com versão e link para health-check `/health` em verde. *(servido via URL do Cloud Run `turni-admin-homolog-dnj2tcr2xa-rj.a.run.app` — DNS customizado bloqueado por constraint regional do Cloud Run em `southamerica-east1`, registrado em IDR-003. Funcionalmente equivalente: HTTP 200, v0.1.0-rc.12, `/health` payload ADR-008 ok)*
- [x] PR mergeado em `main` dispara deploy automático para ambas as homologações (demonstrado em 3 merges consecutivos). *(via tag — rc.10 3:34 / rc.11 3:39 / rc.12 4:12, todos com health-check verde e E2E ✅)*
- [x] CI roda testes unitários, lint, e ao menos um smoke ("a página carrega") em cada PR ou tag, com bloqueio de merge/release se falhar. *(5 CI runs consecutivos verdes pós-correção, com Trivy api + admin, gitleaks, lint PHP/Flutter, smoke builds. **Política revista em 2026-05-28 via IDR-004:** E2E em browser real é gate LOCAL (`make e2e` antes de criar tag rc.N); pipeline pós-deploy faz apenas smoke curl (`/health` + `/version.json` nas 3 interfaces). Histórico de E2E rodando no pipeline em rc.10/11/12 fica como evidência da política anterior.)*
- [x] Pasta `docs/project-state/decisions/adr/` contém os ADRs aceitos pelo Alexandro listados em "Decisões arquiteturais necessárias" abaixo. *(9 ADRs aceitas — ADR-000 a ADR-008)*

## Fora de escopo (explicitamente)

- Cadastro de usuário, login real, autenticação completa (vira EPIC-001).
- Qualquer página além do "hello world" + health-check + página de erro 404.
- Spike jurídico/contábil (templates de contrato PF e MEI/PJ) — vira primeira estória do EPIC-001.
- Ambiente de produção — vira EPIC-006 na próxima onda. **Mas:** pipeline já deve ser desenhado pensando em produção (multi-ambiente desde o início).
- Push notifications, integração de e-mail transacional real, geo PostGIS — apenas mocks placeholders se necessário; integrações reais vêm com os épicos que as exigem.
- Observabilidade avançada (traces distribuídos, dashboards consolidados) — apenas básico (logs estruturados, health-check, métrica RED automática se vier de graça do framework).

## Referências da especificação

- `docs/especificacao/glossary.md` — termos canônicos (foundation, homologação, PWA, backoffice).
- `docs/especificacao/non-functional.md` — NFRs aplicáveis (SLOs internos, observabilidade, segurança, compatibilidade).
- `docs/especificacao/business-rules.md` — números que afetam dimensionamento inicial (planos, tipos de pessoa).
- `docs/project-state/decisions/pdr/PDR-003-duas-interfaces-webapp-e-backoffice.md` — exige ambas as interfaces no Foundation.
- `docs/project-state/decisions/pdr/PDR-002-habitualidade-no-mesmo-estabelecimento.md` — exige decisão arquitetural sobre estratégia de consulta de habitualidade.
- `docs/project-state/decisions/pdr/PDR-004-modelo-financeiro-taxa-do-contratante.md` — exige ADR de integração Pagar.me (alto nível) já no Foundation.

## Dependências

- **Bloqueia**: todos os demais épicos (EPIC-001, 002, 003, 004, 005).
- **Bloqueado por**: aprovação humana do Alexandro em cada ADR proposto pelo Arquiteto.
- **Decisões arquiteturais necessárias** (cada uma vira ADR):
  - **ADR-000** — Formalização retroativa de PostgreSQL como banco principal (princípio #3 já vigente).
  - **ADR-001** — Stack principal (linguagem + framework opinativo + ORM/query layer + ferramenta de teste).
  - **ADR-002** — Topologia (monolito modular vs separação inicial FE/BE/worker).
  - **ADR-003** — Estratégia de monorepo vs polirepo para webapp + backoffice (PDR-003).
  - **ADR-004** — Hospedagem (provedor cloud, IaC, ambientes, deploy).
  - **ADR-005** — Estratégia de integração Pagar.me em alto nível (ACL, mock local, contract testing, idempotência).
  - **ADR-006** — Estratégia de consulta de habitualidade (PDR-002) — materialized view, índice composto, cache, ou query direta com plano garantido.
  - **ADR-007** — Modelo de autenticação base e roteamento por papel.
  - **ADR-008** — Observabilidade mínima (logs estruturados, health-check, formato de log).

## Estórias

> Fluxo C concluído em 2026-05-26 — todas as 11 estórias previstas foram escritas em `stories/` e estão em `status: ready` no `index.json`. As estórias detalhadas contêm contexto, CAs testáveis, dependências, padrões de qualidade e protocolo do agente. Os checkboxes abaixo marcam **estória escrita e em `ready`**; serão completados na etapa de execução conforme cada estória passar por `in_progress` → `in_review` → `done`.

**Fase de spike (Arquiteto):**

- [x] **STORY-001** — Spike Arquiteto: stack principal + topologia + monorepo vs polirepo
  - `type: spike`, `target_role: arquiteto`, `status: ready`
  - Path: `stories/STORY-001-spike-stack-topologia-monorepo.md`
  - Saída: ADR-001, ADR-002, ADR-003 propostos para aprovação.

- [x] **STORY-002** — Spike Arquiteto: hospedagem, IaC e estratégia de deploy
  - `type: spike`, `target_role: arquiteto`, `status: ready`
  - Path: `stories/STORY-002-spike-hospedagem-iac-deploy.md`
  - Saída: ADR-004 proposto. Confirma viabilidade de deployar ambas as interfaces no provedor escolhido. Bloqueada por STORY-001.

- [x] **STORY-003** — Spike Arquiteto: Pagar.me alto nível + estratégia de habitualidade
  - `type: spike`, `target_role: arquiteto`, `status: ready`
  - Path: `stories/STORY-003-spike-pagarme-e-habitualidade.md`
  - Saída: ADR-005 e ADR-006 propostos. Não implementa — decide a abordagem para os épicos seguintes. Bloqueada por STORY-001.

- [x] **STORY-004** — Spike Arquiteto: autenticação base e observabilidade mínima
  - `type: spike`, `target_role: arquiteto`, `status: ready`
  - Path: `stories/STORY-004-spike-auth-e-observabilidade.md`
  - Saída: ADR-007 e ADR-008 propostos. Bloqueada por STORY-001 e STORY-002.

- [x] **STORY-005** — Spike Arquiteto: ADR-000 retroativo formalizando PostgreSQL
  - `type: spike`, `target_role: arquiteto`, `status: ready`
  - Path: `stories/STORY-005-spike-adr-000-postgresql-retroativo.md`
  - Saída: ADR-000 proposto. Roda em paralelo às demais spikes — sem bloqueio.

**Fase de implementação (Programador / Designer):**

- [x] **STORY-006** — Setup do repositório, ambiente local em 1 comando (princípio #6)
  - `type: enablement`, `target_role: programador`, `status: ready`
  - Path: `stories/STORY-006-setup-repo-e-ambiente-local-1-comando.md`
  - Entregável: `git clone && <um comando>` sobe app vazio + PostgreSQL + mock Pagar.me + hook de pré-push instalado. Bloqueada por STORY-001/002/003/004/005.

- [x] **STORY-007** — Pipeline CI/CD configurado, deploy automático para ambas as homologações
  - `type: enablement`, `target_role: programador`, `status: ready`
  - Path: `stories/STORY-007-pipeline-cicd-deploy-automatico-homologacao.md`
  - Entregável: merge em `main` + tag `-rc.N` faz deploy automático ≤ 10 min nas duas URLs com health-check verde. Bloqueada por STORY-006/002/001/004. Tamanho L justificado.

- [x] **STORY-008** — "Hello world" no WebApp: rota raiz + health-check + identidade visual base
  - `type: implementation`, `target_role: programador`, `requires_design: true`, `status: ready`
  - Path: `stories/STORY-008-hello-world-webapp.md`
  - Entregável: `app.homolog.turni.com.br` retornando página de boas-vindas + `/health` + PWA mínimo + E2E em browser real. Designer entra em paralelo via STORY-010 (rabisco + screen spec). Bloqueada por STORY-007/006/001/004/010.

- [x] **STORY-009** — "Hello world" no Backoffice: rota raiz + health-check
  - `type: implementation`, `target_role: programador`, `status: ready`
  - Path: `stories/STORY-009-hello-world-backoffice.md`
  - Entregável: `admin.homolog.turni.com.br` retornando página identificadora + `/health` + E2E em browser real. Sem `requires_design` (placeholder mínimo aplica DDR-001 sem screen spec). Bloqueada por STORY-007/006/001/004/010.

- [x] **STORY-010** — DDR-001: fundação do Design System (tokens base, tipografia, paleta)
  - `type: implementation`, `target_role: designer`, `status: ready`
  - Path: `stories/STORY-010-ddr-001-fundacao-design-system.md`
  - Entregável: DDR-001 proposto + `tokens.md` + `voice-and-tone.md` + screen spec da página de boas-vindas em `ready`. Sem bloqueio — roda em paralelo às spikes do Arquiteto.

**Validação final:**

- [x] **STORY-011** (validação) — Validação final do EPIC-000
  - `type: validation`, `target_role: validador`, `status: ready`
  - Path: `stories/STORY-011-validacao-final-epic-000.md`
  - Executa checklist em `validation/checklist.md` e produz `validation/report.md` com veredito. Bloqueada por todas as 10 estórias anteriores em `done`.

## Validação final

Critérios em `validation/checklist.md`. Relatório do validador em `validation/report.md`.

**Definição de épico concluído**: todas as 11 estórias `done` + 9 ADRs aceitos pelo Alexandro + DDR-001 aceito + 3 merges consecutivos em `main` resultando em deploy automático verde em ambas as homologações + relatório de validação `approved`.

**Resultado (2026-05-28)**: 11/11 estórias `done`; 9 ADRs `accepted`; DDR-001 `accepted`; 3 deploys consecutivos (rc.10/11/12) ≤ 10 min com health-check verde + E2E ✅; veredito da STORY-011 = `approved_with_pending` em 2ª rodada (0 bloqueantes, 1 não-bloqueante). PO trata `approved_with_pending` como goal atingido — ver "Pendência operacional carregada" abaixo.

## Pendência operacional carregada (não-bloqueante)

- **`php artisan migrate:rollback` não executado em homolog** (F-NB-1 do `validation/report.md`). As 3 migrações atuais (`create_users_table`, `create_cache_table`, `create_jobs_table`) são Laravel-default com `down()` declarado; risco operacional baixo. O exercício real do rollback fica como **critério herdado** para a primeira estória do EPIC-001 que crie migração com lógica de negócio (provavelmente STORY-1 ao criar tabela `profissionais` ou equivalente). PO vai exigir a evidência de execução do `migrate:rollback` no fechamento daquela estória.

## Histórico

- 2026-05-26 — criado por PO (Alexandro / Claude) durante planejamento da WAVE-2026-01.
- 2026-05-26 — Fluxo C concluído: 11 estórias detalhadas escritas em `stories/`, todas em `status: ready` no `index.json`. Sequência prevista, dependências (`blocked_by`/`blocks`) e `target_role` corretos. Pronto para abertura da SPRINT-2026-W22.
- 2026-05-27 — SPRINT-2026-W22 abriu e fechou no mesmo dia. 6 estórias documentais (STORY-001/002/003/004/005/010) `done`; 9 ADRs aceitas (ADR-000 a ADR-008) + DDR-001 aceito + PDR-013 emergente.
- 2026-05-27 — SPRINT-2026-W23 aberta com escopo cheio para fechar o EPIC-000 (STORY-006/007/008/009 + validação STORY-011).
- 2026-05-28 — SPRINT-2026-W23 fechada com goal atingido em ~1 dia. STORY-006 (setup `make setup` ~34s), STORY-007 (CI/CD com deploy tag-based e rollback exercido), STORY-008 (WebApp em homolog v0.1.0-rc.12), STORY-009 (Backoffice em homolog v0.1.0-rc.12 via URL do Cloud Run) e STORY-011 (validação em 2 rodadas: 1ª `rejected` por 8 bloqueantes, 2ª `approved_with_pending`).
- 2026-05-28 — **EPIC-000 fechado** pelo PO. Veredito `approved_with_pending` tratado como goal atingido. Pendência de `migrate:rollback` em homolog carregada como critério herdado para EPIC-001.
