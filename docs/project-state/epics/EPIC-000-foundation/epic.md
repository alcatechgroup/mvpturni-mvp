---
epic_id: EPIC-000
slug: foundation
title: Foundation — stack decidida, pipelines duplos rodando, hello world em homologação
wave: WAVE-2026-01
status: ready
owner_role: po
created_at: 2026-05-26
updated_at: 2026-05-26
target_completion: 2026-06-09  # estimativa orientativa
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

- [ ] `https://app.homolog.turni.com.br` retorna página inicial com versão e link para health-check `/health` em verde.
- [ ] `https://admin.homolog.turni.com.br` retorna página inicial com versão e link para health-check `/health` em verde.
- [ ] PR mergeado em `main` dispara deploy automático para ambas as homologações (demonstrado em 3 merges consecutivos).
- [ ] CI roda testes unitários, lint, e ao menos um E2E smoke ("a página carrega") em cada PR, com bloqueio de merge se falhar.
- [ ] Pasta `docs/project-state/decisions/adr/` contém os ADRs aceitos pelo Alexandro listados em "Decisões arquiteturais necessárias" abaixo.

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

> Estórias detalhadas serão escritas pelo PO via Fluxo C antes de cada uma entrar em sprint. Aqui fica a sequência prevista e o tipo.

**Fase de spike (Arquiteto):**

- [ ] **STORY-001** — Spike Arquiteto: stack principal + topologia + monorepo vs polirepo
  - `type: spike`, `target_role: arquiteto`
  - Saída: ADR-001, ADR-002, ADR-003 propostos para aprovação.

- [ ] **STORY-002** — Spike Arquiteto: hospedagem, IaC e estratégia de deploy
  - `type: spike`, `target_role: arquiteto`
  - Saída: ADR-004 proposto para aprovação. Confirma viabilidade de deployar ambas as interfaces em homologação no provedor escolhido.

- [ ] **STORY-003** — Spike Arquiteto: Pagar.me alto nível + estratégia de habitualidade
  - `type: spike`, `target_role: arquiteto`
  - Saída: ADR-005 e ADR-006 propostos. Não implementa nada — apenas decide a abordagem para os épicos seguintes.

- [ ] **STORY-004** — Spike Arquiteto: autenticação base e observabilidade mínima
  - `type: spike`, `target_role: arquiteto`
  - Saída: ADR-007 e ADR-008 propostos.

- [ ] **STORY-005** — Spike Arquiteto: ADR-000 retroativo formalizando PostgreSQL
  - `type: spike`, `target_role: arquiteto`
  - Saída: ADR-000 proposto. Decisão simples mas formaliza disciplina "estado registrado, sempre".

**Fase de implementação:**

- [ ] **STORY-006** — Setup do repositório, ambiente local em 1 comando (princípio #6)
  - `type: enablement`, `target_role: programador`
  - Entregável: `git clone && <um comando>` sobe o app vazio + banco + serviços mockados.

- [ ] **STORY-007** — Pipeline CI/CD configurado, deploy automático para ambas as homologações
  - `type: enablement`, `target_role: programador`
  - Entregável: merge em `main` faz deploy.

- [ ] **STORY-008** — "Hello world" no webapp: rota raiz + health-check
  - `type: implementation`, `target_role: programador`
  - Entregável: `app.homolog.turni.com.br` retornando página inicial.
  - **Designer entra em paralelo**: rabisco inicial da página de boas-vindas (não é a tela final do produto — é placeholder para evidenciar que o deploy funciona; visual mínimo coerente com identidade da landing).

- [ ] **STORY-009** — "Hello world" no backoffice: rota raiz + health-check
  - `type: implementation`, `target_role: programador`
  - Entregável: `admin.homolog.turni.com.br` retornando página inicial separada.

- [ ] **STORY-010** — DDR-001: fundação do Design System (tokens base, tipografia, paleta inicial)
  - `type: implementation`, `target_role: designer`
  - Entregável: DDR-001 aprovado registrando padrão visual base que será aplicado em EPIC-001 em diante. Executável em paralelo com STORY-001 a STORY-005.

**Validação final:**

- [ ] **STORY-011** (validação) — Validação final do EPIC-000
  - `type: validation`, `target_role: validador`
  - Executa checklist em `validation/checklist.md`.

## Validação final

Critérios em `validation/checklist.md`. Relatório do validador em `validation/report.md`.

**Definição de épico concluído**: todas as 11 estórias `done` + 9 ADRs aceitos pelo Alexandro + DDR-001 aceito + 3 merges consecutivos em `main` resultando em deploy automático verde em ambas as homologações + relatório de validação `approved`.

## Histórico

- 2026-05-26 — criado por PO (Alexandro / Claude) durante planejamento da WAVE-2026-01.
