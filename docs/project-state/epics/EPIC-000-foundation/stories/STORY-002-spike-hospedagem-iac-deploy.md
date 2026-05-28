---
story_id: STORY-002
slug: spike-hospedagem-iac-deploy
title: Spike Arquiteto — hospedagem, Infra-as-Code e estratégia de deploy
epic_id: EPIC-000
sprint_id: SPRINT-2026-W22
type: spike
target_role: arquiteto
requires_design: false
status: done
owner_agent: claude-opus-arquiteto-2026-05-27
created_at: 2026-05-26
updated_at: 2026-05-27
estimated_session_size: M
---

# STORY-002 — Spike Arquiteto: hospedagem, IaC e estratégia de deploy

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Ela contém tudo o que você precisa. Se algo estiver ambíguo, registre a dúvida na seção "Notas do agente" no final e pause em vez de adivinhar.

## Contexto (por que esta estória existe)

O EPIC-000 Foundation só fecha quando `app.homolog.turni.com.br` e `admin.homolog.turni.com.br` estão no ar com deploy automático a cada merge em `main`. Para isso, alguém precisa decidir **onde** essas duas interfaces vão rodar (provedor cloud), **como** o ambiente é provisionado (Infra-as-Code — exigência do PO em `quality-standards.md` seção 2.3) e **como** o deploy promove código entre branch → homologação → produção (a onda atual só entrega homologação, mas o pipeline já nasce desenhado para promoção tag-based até produção, como exige `quality-standards.md` seção 2.2).

Esta ADR é independente das outras spikes do EPIC-000 (assunto separado: infra/operação, não código), portanto vive sozinha em uma estória — em linha com a regra "1 ADR = 1 spike" do `story-craft.md`. Ela **depende** da stack escolhida em STORY-001 porque a viabilidade do provedor (runtime suportado, footprint do artefato) varia conforme a linguagem/framework — por isso é a segunda spike.

- Épico: `docs/project-state/epics/EPIC-000-foundation/epic.md`
- Documentos canônicos a ler ANTES de deliberar:
  - `docs/project-state/decisions/pdr/PDR-003-duas-interfaces-webapp-e-backoffice.md` (dois deploys independentes, dois subdomínios)
  - `docs/project-state/decisions/pdr/PDR-011-escopo-da-wave-2026-01.md` (orçamento e prazos da onda)
  - `docs/especificacao/non-functional.md` (SLOs internos: disponibilidade ≥99.5% webapp, ≥99% backoffice; performance; segurança HTTPS; compatibilidade PWA)
  - `docs/skills/po/references/quality-standards.md` seções 2.2 (CI/CD), 2.3 (Infraestrutura) e 3 (Observabilidade mínima)
  - `docs/project-state/decisions/adr/ADR-001-stack-principal.md` (saída de STORY-001 — runtime da stack precisa ser suportado pelo provedor escolhido)
  - `docs/project-state/decisions/adr/ADR-002-topologia.md` e `ADR-003-monorepo-vs-polirepo.md` (afetam estrutura do pipeline)

## O quê (objetivo desta estória)

Deliberar e propor **ADR-004 — Hospedagem, IaC e estratégia de deploy**, em estado `proposed`, de modo que STORY-006 (setup local) e STORY-007 (pipeline CI/CD com deploy automático para homologação) tenham fundação operacional decidida.

## Por quê (valor para o usuário)

Sem hospedagem decidida, o entregável central do EPIC-000 ("merge em main faz deploy automático em ≤ 10 min, repetível 3 vezes consecutivas, com health-check verde em ambas as URLs") não pode ser perseguido. A escolha errada de provedor / IaC pode adicionar semanas de retrabalho nos próximos épicos (refazer pipeline, migrar dados) — daí o investimento agora em deliberação cuidadosa.

## Critérios de aceite

- [ ] **CA-1:** Existe `docs/project-state/decisions/adr/ADR-004-hospedagem-iac-deploy.md` em `status: proposed`, escrito conforme `docs/skills/arquiteto/templates/adr.md`, com no mínimo 2 opções reais de provedor avaliadas (não "AWS porque AWS").
- [ ] **CA-2:** A ADR especifica:
  - (a) provedor cloud escolhido e por quê (custo MVP, ergonomia, suporte ao runtime de ADR-001, presença em pt-BR/região aceitável);
  - (b) ferramenta de Infra-as-Code escolhida (Terraform, Pulumi, CDK, equivalente) com justificativa;
  - (c) estratégia de provisionamento: como subir do zero **homologação + produção** a partir do código (mesmo que produção venha só no EPIC-006);
  - (d) estratégia de promoção: tag-based — `vX.Y.Z-rc.N` dispara homologação automática, `vX.Y.Z` dispara produção com gate humano de 1 clique (`quality-standards.md` seção 2.2);
  - (e) como **WebApp** e **Backoffice** ficam em URLs distintas (`app.homolog.turni.com.br` e `admin.homolog.turni.com.br`) com deploys independentes;
  - (f) modelo de variáveis de ambiente / cofre de segredos (segredos nunca no código — `quality-standards.md` seção 4);
  - (g) modelo de logs estruturados básico (destino e formato — alinha com ADR-008 a ser proposta em STORY-004).
- [ ] **CA-3:** A ADR demonstra **viabilidade orçamentária para o MVP** — estimativa mensal em homologação dentro de faixa razoável para projeto em fase pré-receita (ordem de grandeza, não centavos). Provedor escolhido permite escalar para produção sem migrar.
- [ ] **CA-4:** A ADR contempla o **caminho de subir tudo do zero** — recriar homologação ou produção a partir do IaC é um runbook viável e idealmente exercitado (`quality-standards.md` seção 2.3).
- [ ] **CA-5:** A ADR contempla **rollback** — como reverter um deploy ruim em homologação ou produção sem intervenção manual fora do que está versionado em git.
- [ ] **CA-6:** A ADR explicita compatibilidade com a topologia escolhida (ADR-002) e com a estratégia de repositório (ADR-003) — pipelines distintos por interface ou monorepo com matriz de deploy, conforme couber.
- [ ] **CA-7:** A ADR é coerente com `non-functional.md`: HTTPS obrigatório, SLO de disponibilidade alcançável no provedor escolhido, suporte a PWA (cache, service worker, headers) para o WebApp mobile-first.
- [ ] **CA-8:** O `index.json` é atualizado com a entrada de ADR-004 em `decisions.adr[]` (`status: proposed`, path correto, `decided_at`, `approved_by: null`).
- [ ] **CA-9:** A ADR fica em `proposed` até aprovação humana do Alexandro registrada explicitamente; só então transita para `accepted`.

## Fora de escopo

- Implementar IaC ou pipeline — isso é STORY-006 e STORY-007.
- Decidir provedor de identidade / auth — STORY-004 (ADR-007).
- Decidir provedor de Pagar.me — já é PDR-004; a integração detalhada é STORY-003 (ADR-005).
- Definir mecanismo concreto de monitoramento avançado (APM, traces distribuídos) — fora do EPIC-000 conforme `epic.md` ("Fora de escopo").
- Provisionar produção neste épico — produção é EPIC-006 na próxima onda; aqui só desenhamos o pipeline pensando nela.

## Padrões de qualidade exigidos

Estória **spike** — segue `docs/skills/po/references/quality-standards.md` com as exceções declaradas em `docs/skills/po/references/story-craft.md` seção "Spikes e cobertura de testes":

- **Cobertura unitária / E2E:** N/A — não produz código de produção.
- **Rigor aplicável:** opções reais avaliadas com critérios documentados; trade-offs explícitos; viabilidade do provedor verificada na documentação oficial (custo, runtime suportado, regiões); decisão coerente com PDRs e outras ADRs.
- **Não-negociável:** estratégia escolhida precisa permitir o cumprimento de `quality-standards.md` seções 2.2 (pipeline tag-based + gate humano de 1 clique em produção) e 2.3 (IaC sem cliques manuais).

## Dependências

- **Bloqueada por:** STORY-001 (precisa de ADR-001 e ADR-002 aceitas para validar runtime e topologia no provedor escolhido). Pode iniciar enquanto STORY-001 está em `in_review` se as opções de stack já estiverem claras o suficiente para avaliar provedores.
- **Bloqueia:** STORY-006 (setup local consome a decisão de IaC para alinhar variáveis de ambiente / scripts), STORY-007 (pipeline CI/CD), STORY-008 (hello world webapp), STORY-009 (hello world backoffice), STORY-011 (validação).
- **Pré-requisitos de ambiente:** nenhum.

## Decisões já tomadas (não as reabra)

- **PDR-003** — duas interfaces em URLs distintas e deploys independentes → afeta CA-2(e).
- **PDR-011** — escopo da onda; orçamento e prazo razoáveis para fase pré-receita.
- **ADR-001 / ADR-002 / ADR-003** (saídas de STORY-001) — runtime, topologia e estratégia de repositório já decididos; provedor precisa suportar.
- **`quality-standards.md` seção 2.2** — promoção tag-based + gate humano de 1 clique em produção. Não negocie.

## Liberdade técnica do agente

Você (agente arquiteto) decide:
- Quais provedores avaliar (AWS, GCP, Fly.io, Render, Railway, Vercel, etc — no mínimo 2 reais).
- Qual ferramenta de IaC (Terraform / Pulumi / CDK / equivalente).
- Estrutura do pipeline (jobs, gates, paralelização).
- Estratégia de domínio/DNS (Route53, Cloudflare, etc), desde que respeite os subdomínios exigidos.
- Mecanismo concreto de gate humano em produção (CI nativo, manual approval, etc).

Você (agente arquiteto) NÃO decide:
- Quebrar princípio do PO sobre IaC obrigatório.
- Stack principal (ADR-001 já decidiu).
- Suprimir o gate humano em produção (`quality-standards.md` seção 2.2).

Se a deliberação revelar que o provedor escolhido em STORY-001 não suporta requisitos (ex: PWA com service worker, websockets se vierem depois), **escale para o PO** antes de inventar workaround.

## Definição de Pronto (DoD)

- [ ] CA-1 a CA-9 atendidos.
- [ ] ADR-004 em `proposed` no path correto.
- [ ] `index.json` com a entrada nova em `decisions.adr[]`.
- [ ] Esta estória com "Notas do agente" preenchida.
- [ ] Frontmatter desta estória: `status: in_review` (aguardando aprovação humana).
- [ ] Nenhum código de produção introduzido (diff só de `.md` e `index.json`).
- [ ] **Pré-condição para `done`:** Alexandro aprovou ADR-004 explicitamente; `index.json` reflete `status: accepted`.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Resumo:

1. **Ao iniciar:** carregue `docs/skills/arquiteto/SKILL.md`. Edite frontmatter desta estória (`status: in_progress`, `owner_agent`, `updated_at`). Atualize `index.json`.
2. **Durante:** deliberação documental; sem código de produção.
3. **Se travar:** `status: blocked`, registre em "Notas do agente". Decisões de produto/orçamento escalam para o PO.
4. **Ao terminar:** preencha "Notas do agente", `status: in_review`, atualize `index.json`, abra PR.

## Notas do agente (preenchido durante/após execução)

### Decisões tomadas
- 2026-05-27 — **Provedor: GCP** (Cloud Run + Cloud SQL + Firebase Hosting), região `southamerica-east1`. Decidido com Alexandro na sessão, motivado pelos ~US$2K de crédito da parceria Google + presença no Brasil + provider Terraform madura. **AWS (ECS Fargate + RDS + CloudFront, sa-east-1) registrada como alternativa de primeira classe.**
- 2026-05-27 — **IaC: Terraform** (provider Google), state remoto em GCS, organizado multi-ambiente (homolog + prod escritos juntos; prod só aplicado no EPIC-006).
- 2026-05-27 — **CI/CD: GitHub Actions** + Workload Identity Federation (OIDC, sem chave de service account). Promoção tag-based: `vX.Y.Z-rc.N` → homolog sem gate; `vX.Y.Z` → prod com gate de 1 clique via GitHub Environments.
- 2026-05-27 — **DNS: Cloud DNS**; **segredos: Secret Manager**; **logs: JSON em stdout → Cloud Logging** (detalhe fino fica para ADR-008/STORY-004); **admin restrito via `ingress=internal` + IAP**.
- 2026-05-27 — Fly.io (GRU) avaliada e descartada como escolha (deixaria os créditos Google na mesa), mantida como alternativa de menor footprint.

### Descobertas
- 2026-05-27 — Diferença de custo em **homologação** vem de dois fatores estruturais: scale-to-zero do Cloud Run vs. Fargate always-on, e a **taxa fixa de ALB (~US$16-18/mês)** da AWS. GCP fica ~US$20-30/mês sem créditos vs. ~US$60-80/mês na AWS — e ~US$0 com os créditos.
- 2026-05-27 — Único ponto em que a AWS é genuinamente melhor neste cenário: **fit do `worker`** (`queue:work`). Fargate roda processo long-running limpo; no Cloud Run (que exige HTTP) o caminho limpo é uma VM `e2-micro` à parte. Asterisco aceito; alternativa managed (Cloud Scheduler + Cloud Run job) registrada na ADR.

### Bloqueios encontrados
- Nenhum.

### ADRs criados
- ADR-004 — Hospedagem, IaC e estratégia de deploy — `decisions/adr/ADR-004-hospedagem-iac-deploy.md` — status: **accepted** (aprovada por Alexandro em 2026-05-27).

### Cobertura final
- Unitários: N/A (spike)
- E2E: N/A (spike)

### Links de evidência
- PR: commit direto na `main` (autorizado por Alexandro em 2026-05-27).
- ADR aceita: `docs/project-state/decisions/adr/ADR-004-hospedagem-iac-deploy.md`
- Aprovação registrada: chat de 2026-05-27 (seção "Aprovação humana" da ADR-004 + `index.json`).
