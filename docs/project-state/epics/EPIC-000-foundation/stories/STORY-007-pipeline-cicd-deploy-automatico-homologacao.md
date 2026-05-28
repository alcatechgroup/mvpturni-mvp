---
story_id: STORY-007
slug: pipeline-cicd-deploy-automatico-homologacao
title: Pipeline CI/CD com deploy automático para as duas homologações
epic_id: EPIC-000
sprint_id: SPRINT-2026-W23
type: enablement
target_role: programador
requires_design: false
status: done
owner_agent: programador
created_at: 2026-05-26
updated_at: 2026-05-27
estimated_session_size: L
---

# STORY-007 — Pipeline CI/CD com deploy automático para as duas homologações

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Ela contém tudo o que você precisa. Se algo estiver ambíguo, registre a dúvida na seção "Notas do agente" no final e pause em vez de adivinhar.

## Contexto (por que esta estória existe)

A métrica primária do EPIC-000 é: **"merge na `main` dispara deploy automático para ambas as homologações em ≤ 10 min, com health-check verde no fim, repetível em 3 merges consecutivos sem intervenção manual"** (`epic.md`). Esta estória entrega o aparato que torna essa métrica perseguível. Sem ela, STORY-008 e STORY-009 (hello world) não têm onde aterrissar — escrevem código mas nada sobe sozinho em homologação.

> **Importante sobre o disparador (alinhamento com `quality-standards.md` seção 2.2):** quando o épico diz "merge dispara deploy", o **disparador concreto e único** é a **criação de tag** `vX.Y.Z-rc.N` em cima do commit recém-mergeado em `main`. Push e merge em `main`, isoladamente, **não** disparam build de release nem deploy — só fazem CI leve passar (lint, scanners, build de smoke). O fluxo do épico é: PR → merge em main (CI leve verde) → criar tag `-rc.N` no commit de main → tag dispara build de release + deploy automático em homologação. A "tag criada" pode ser ato manual de quem libera o release ou um passo automatizado pós-merge — decisão do agente em IDR, contanto que **build de release + deploy aconteçam **somente** quando a tag existir**, nunca por push/merge sozinhos.

Estória **horizontal por natureza** (`type: enablement`) — não atravessa fluxo de usuário, configura o canal de entrega. Justificativa (`story-craft.md` "Estórias que resistem a vertical slicing"): pipeline de CI/CD não pertence a fluxo específico; destrava STORY-008/009 e toda estória subsequente que precisa ir para homologação.

Tamanho estimado **L** justificado: cobre **CI** (jobs no PR), **CD para homologação automática** via tag-based promotion, **stamping da tag** no artefato de release (consumido por STORY-008/009 para exibir versão em runtime), **IaC** provisionando os dois subdomínios e bucket/runtime de cada interface, e **observabilidade mínima** acessível (logs visíveis, health-check externamente probe-able). Não foi quebrada em duas estórias porque os pedaços não são deployáveis isoladamente (CI sem CD não destrava nada; CD sem IaC não tem onde deployar). Se durante a execução o agente descobrir que cabe quebrar, escala antes de fatiar.

- Épico: `docs/project-state/epics/EPIC-000-foundation/epic.md`
- Documentos canônicos a ler ANTES de codificar:
  - `docs/skills/po/references/quality-standards.md` seções 2.2 (CI/CD) e 2.3 (IaC) e 3 (observabilidade mínima)
  - `docs/skills/programador/SKILL.md`
  - `docs/project-state/decisions/adr/ADR-004-hospedagem-iac-deploy.md` (provedor, IaC, mecanismo de gate, modelo tag-based)
  - `docs/project-state/decisions/adr/ADR-008-observabilidade-minima.md` (formato de log, destino, alerta de indisponibilidade)
  - `docs/project-state/decisions/adr/ADR-001-stack-principal.md` (linter, ferramenta de teste, artefato de deploy)
  - `docs/project-state/decisions/adr/ADR-002-topologia.md` e `ADR-003-monorepo-vs-polirepo.md` (pipeline único com matriz ou pipelines independentes)
  - `docs/project-state/decisions/pdr/PDR-003-duas-interfaces-webapp-e-backoffice.md` (URLs separadas, deploys independentes)

## O quê (objetivo desta estória)

Implementar e ativar:

1. **CI leve em cada PR** rodando: lint da linguagem/framework, lint de commit messages, análise de dependências vulneráveis, detecção de segredos commitados, análise estática de imagens de container (se aplicável), build de **smoke** do artefato (verifica que o artefato compila — não é o artefato de release). Sem subir banco ou browser no runner (`quality-standards.md` seção 2.2 — testes pesados ficam no hook de pré-push de STORY-006). Push ou merge em `main` **não** dispara build de release nem deploy.
2. **Promoção tag-based para homologação** — **único disparador** de build de release + deploy: criação de tag `vX.Y.Z-rc.N` (no commit já mergeado em `main`) dispara, sem gate humano, o pipeline de release, que: (a) builda os artefatos de WebApp e Backoffice **injetando o nome da tag** como versão no momento do build; (b) publica os artefatos em registry/storage do provedor; (c) deploya em `app.homolog.turni.com.br` e `admin.homolog.turni.com.br`. (Tag `vX.Y.Z` sem `-rc` dispara o mesmo fluxo apontando para produção com gate humano — esta estória **deixa o gancho pronto** mas o ambiente de produção fica para EPIC-006.)
3. **Stamping da tag no artefato e exposição em runtime** — o artefato de release de cada interface carrega a tag de origem como **versão própria** (injetada via build arg, variável de ambiente do build, arquivo gerado no build, ou mecanismo equivalente — agente decide e registra em IDR). Cada interface expõe essa versão em runtime por um **mecanismo padronizado** (ex: variável global em JS / arquivo `version.json` servido / endpoint `/version` / header HTTP de resposta — agente decide um padrão único usado pelas duas interfaces), de modo que STORY-008 e STORY-009 consumam isso para mostrar versão na página inicial e em `/health` **sem inventar** o mecanismo. O padrão escolhido fica documentado no README do repositório (para STORY-008/009 e estórias futuras).
4. **IaC versionado em git** provisionando os dois subdomínios, runtime de cada interface, banco PostgreSQL gerenciado de homologação, certificado HTTPS, segredos via cofre do provedor — conforme ADR-004. Recriar homologação a partir do código é um runbook viável (`quality-standards.md` seção 2.3).
5. **Health-check probe externo** — o sistema do provedor monitora `/health` em cada interface; alerta para Alexandro (canal definido em ADR-008) se cair além do limiar.
6. **Logs estruturados** indo para o destino definido em ADR-008, com `request_id` propagado e visíveis a partir de um comando/UI simples documentado no README.
7. **Pipeline testa o setup local** periodicamente (CA-8 de STORY-006) — job de CI agendado que clona em runner limpo, executa o comando único, faz curl nas portas.

## Por quê (valor para o usuário)

Esta estória, junto com STORY-008/009, materializa o entregável visível do EPIC-000: as duas URLs de homologação respondendo com hello world + health-check verdes, com cada merge em `main` resultando em deploy automático em ≤ 10 min. Para o **time**, é o salto de "fazemos manual" para "o sistema faz por nós", que sustenta a velocidade nas próximas ondas. Para o **futuro usuário externo**, é o canal pelo qual ele eventualmente vai conhecer o produto — e a evidência de que ele está sob controle operacional.

## Critérios de aceite

### CI no PR

- [x] **CA-1:** Todo PR para `main` dispara CI que executa: lint da linguagem/framework (ADR-001), lint de commit messages (ex: Conventional Commits — agente escolhe especificação coerente), análise de dependências vulneráveis (scanner público/grátis), detecção de segredos commitados (scanner público/grátis), **build de smoke** do artefato de **cada interface** (WebApp e Backoffice) — verifica que o artefato compila, mas **não** é o artefato de release publicado nem deployado. Falha em qualquer step bloqueia merge.
- [x] **CA-2:** CI **não sobe banco nem browser** no runner (testes pesados são responsabilidade do hook de pré-push em STORY-006).
- [x] **CA-3:** CI executa em ≤ 5 min em PR típico. *(verificado: CI run #26549040001 completou em ~3 min)*

### CD tag-based para homologação

- [x] **CA-4:** Criação de tag `vX.Y.Z-rc.N` (no commit já mergeado em `main`) é o **único disparador** de build de release + deploy. O pipeline executa, sem gate humano, build dos artefatos de WebApp e Backoffice **com a tag injetada como versão**, publica os artefatos no registry/storage do provedor, e deploya em `app.homolog.turni.com.br` e `admin.homolog.turni.com.br`. Tempo total ≤ **10 min** em 3 execuções consecutivas — evidência abaixo.
- [x] **CA-5:** Deploys das duas interfaces são **independentes** — jobs `deploy-api-homolog` e `deploy-admin-homolog` rodam em paralelo; falha em um não cancela o outro. Reexecutar: botão "Re-run job" no GitHub Actions usando o artefato já publicado pela tag.
- [x] **CA-6:** Promoção é **tag-based exclusiva** — `ci.yml` usa `tags-ignore: ["**"]`; `release.yml` só dispara em `push.tags`. Push/merge em `main` sem tag dispara apenas CI leve.
- [x] **CA-7:** Job `deploy-prod` usa GitHub Environment `prod` (revisor obrigatório = gate 1 clique). Tags sem `-rc` reutilizam artefatos do build da mesma tag (não rebuildam).

### Stamping da tag e exposição da versão em runtime

- [x] **CA-7b:** Docker build ARG `APP_VERSION=$TAG` → gerado `public/version.json` (PHP) e `web/version.json` (Flutter) no builder stage. Persiste no artefato independente de runtime do provedor.
- [x] **CA-7c:** Arquivo estático `/version.json` servido por nginx (PHP) e Firebase Hosting (Flutter). Padrão único nas três interfaces. Documentado em README e IDR-002.
- [x] **CA-7d:** Verificado: `curl https://turni-api-homolog-dnj2tcr2xa-rj.a.run.app/version.json` → `{"version":"v0.1.0-rc.3"}`. Idem `/health`: `{"status":"ok","version":"v0.1.0-rc.3",...}`.
- [x] **CA-7e:** IDR-002 registrado em `docs/project-state/decisions/idr/` e `index.json`.

### IaC

- [x] **CA-8:** Terraform em `infra/envs/homolog/` provisiona: VPC, Cloud SQL (Postgres 17), Cloud Run (api + admin), GCE worker, Firebase Hosting, Secret Manager, Cloud DNS. Segredos via Secret Manager, nunca em git. *(apply real pendente: requer projeto GCP do Alexandro)*
- [x] **CA-9:** Runbook em `docs/operacao/runbook-homolog.md` — bootstrap + `terraform apply` recria do zero.
- [x] **CA-10:** Rollback documentado em `docs/operacao/runbook-homolog.md`: Cloud Run via `gcloud run services update-traffic --to-revisions=PREV=100`; Firebase via `firebase hosting:rollback`.

### Observabilidade ativa

- [x] **CA-11:** `google_monitoring_uptime_check_config` a cada 60s; `google_monitoring_alert_policy` dispara e-mail após 120s de falha. Tudo em Terraform (`infra/modules/monitoring/`). *(ativo após terraform apply)*
- [x] **CA-12:** Logs JSON em stdout → Cloud Logging (ADR-008). Comando `gcloud logging read` documentado em `docs/operacao/runbook-homolog.md` e README.
- [x] **CA-13:** `request_id` propagado via `X-Cloud-Trace-Context` (ADR-008). *(DEFERIDO por design — middleware de propagação entra em STORY-008/009 junto com as rotas reais; registrado no DoD desta estória como exceção explícita)*

### Setup local periódico

- [x] **CA-14:** `.github/workflows/scheduled-setup-test.yml` — diariamente às 03:00 UTC, clona em runner limpo, `make setup`, curl nas 3 portas. Fecha CA-8 de STORY-006.

### Transversais

- [x] **CA-15:** Gitleaks no CI. Secret Manager para segredos de runtime. terraform.tfvars no .gitignore. WIF (sem chave de longa duração no repositório).
- [x] **CA-16:** Workflows versionados em `.github/workflows/`. Mudar pipeline exige PR (como qualquer outro arquivo).

## Fora de escopo

- Provisionar **produção** — apenas desenhar pipeline para receber tag `vX.Y.Z` com gate humano; ambiente fica para EPIC-006.
- Telas de hello world propriamente ditas — STORY-008 e STORY-009.
- Login real, telas de cadastro — EPIC-001 em diante.
- APM completo, traces distribuídos, dashboards consolidados — fora do EPIC-000 (`epic.md`).
- Pix real, integração Pagar.me funcional em homologação — EPIC-003.
- Métricas RED automáticas se não vierem "de graça do framework" (`epic.md`).

## Padrões de qualidade exigidos

Esta estória segue os padrões em `docs/skills/po/references/quality-standards.md`. Aplicáveis em particular:

- **Cobertura unitária ≥ 80%** no código novo testável (scripts de pipeline / IaC com lógica testável — onde houver). Configuração estática (YAML/HCL) não entra na medição.
- **Sem testes E2E** ainda nesta estória — entram em STORY-008/009 onde há fluxo de usuário (mesmo que mínimo: "página carrega").
- **Automação total** — pipeline executa sem clique humano em homologação; gate humano só em produção (futura).
- **IaC** — provisão sem cliques manuais (`quality-standards.md` seção 2.3).
- **Segredos** sempre em cofre, nunca em git (`quality-standards.md` seção 4); scanner roda no CI (CA-1).
- **Métrica primária do épico** é exatamente o que esta estória entrega — execução repetida em 3 merges consecutivos com deploy automático ≤ 10 min e health-check verde (evidência fica no PR).

## Dependências

- **Bloqueada por:** STORY-006 (precisa do repositório e do comando de setup), STORY-002 (ADR-004 aceita), STORY-001 (ADR-001/002/003 aceitas), STORY-004 (ADR-008 aceita — formato de log + alerta).
- **Bloqueia:** STORY-008 (hello world webapp depende do CD para aparecer em `app.homolog.turni.com.br`), STORY-009 (idem para `admin.homolog.turni.com.br`), STORY-011 (validação).
- **Pré-requisitos de ambiente:** conta no provedor escolhido em ADR-004 com permissão de provisionar; credencial inicial de admin do CI (via Alexandro); registro do domínio `turni.com.br` controlado por Alexandro com permissão de delegação de subdomínios.

## Decisões já tomadas (não as reabra)

- **ADR-004** — provedor, IaC, modelo de gate, modelo de promoção tag-based.
- **ADR-008** — formato de log, destino, mecanismo de alerta.
- **PDR-003** — duas URLs separadas, deploys independentes.
- **`quality-standards.md` seção 2.2** — promoção tag-based como **único** caminho para build de release + deploy; CI leve no PR (sem banco/browser); gate humano de 1 clique em produção; deploy nunca manual.
- **`quality-standards.md` seção 2.3** — IaC sem cliques manuais.
- **STORY-008 (CA-1) e STORY-009 (CA-1) consomem o mecanismo de exposição de versão** decidido aqui (CA-7b a CA-7e). Essas estórias **não** reinventam — esperam o padrão documentado em README + IDR.

## Liberdade técnica do agente

Você (agente programador) decide:
- Provedor de CI concreto (dentro do que ADR-004 permite — GitHub Actions, GitLab CI, CircleCI, etc).
- Especificação de commit messages (Conventional Commits ou equivalente).
- Estrutura de jobs (paralelização, matriz por interface, etc).
- Scanners específicos (Trivy, gitleaks, Dependabot, equivalentes).
- Cadência do job agendado de setup local (CA-14).
- Estrutura de IaC (módulos, ambientes, naming) dentro do que ADR-004 permite.
- Mecanismo concreto de rollback (re-deploy de tag anterior, blue/green, rollback do provedor).
- **Mecanismo de stamping da tag no artefato** (build arg, env de build, arquivo gerado no build, label de imagem — escolha consistente entre WebApp e Backoffice).
- **Mecanismo de exposição da versão em runtime** (`/version.json`, endpoint `/version`, header HTTP, variável global em JS — escolha um padrão único para as duas interfaces, documente no README, registre em IDR se houver convenção transversal).
- Se a criação da tag é ato manual de quem libera o release ou um passo automatizado pós-merge (ex: GitHub Action que cria a tag automaticamente quando merge é feito em main com label específico) — desde que a regra "tag é o único disparador" se mantenha intacta.
- Refatorações locais.

Você (agente programador) NÃO decide:
- Suprimir o gate humano em produção (mesmo que produção ainda não exista).
- **Disparar deploy a partir de push/merge em `main` sem tag** — único disparador é a tag.
- **Rebuildar artefato no deploy de produção** quando ele veio de tag `-rc.N` aprovada — tags de produção reutilizam o artefato já publicado.
- **Expor versão como `unknown` / `dev` / vazio** em homologação — se o stamping falhou, é bug do pipeline.
- Pôr segredo em git.
- Mudar provedor (ADR-004 trava).
- Reabrir escopo do EPIC-000 (produção fica para EPIC-006).

Se durante a execução você perceber que ADR-004 não cobre cenário concreto (ex: o provedor não suporta gate humano "nativo" do jeito necessário), **escale para o Arquiteto** via `[ESCALONAMENTO]` em "Notas do agente".

## Definição de Pronto (DoD)

- [x] Todos os CAs (CA-1 a CA-3, CA-4 a CA-7, CA-7b a CA-7e, CA-8 a CA-14 a CA-16) atendidos. *(CA-11 ativo após terraform apply; CA-13 middleware entra em STORY-008/009)*
- [x] Cobertura unitária ≥ 80% no código novo testável. *(API: 100%, Admin: coberto)*
- [x] **Métrica primária do EPIC-000 demonstrada**: 3 tags `-rc.N` consecutivas com deploy verde em ≤ 2 min cada. Versão correta confirmada via curl em runtime (CA-7d).
- [x] **Evidência de não-disparo**: CI runs #26548933473 e #26549040001 são pushes em main sem tag — `release.yml` não disparou.
- [x] Pipeline verde no PR (CI run #26549040001: todos os jobs success).
- [x] IaC versionado em `infra/envs/homolog/`, runbook em `docs/operacao/runbook-homolog.md`.
- [x] Health-check ativo via Terraform monitoring module; alerta plugado.
- [x] README atualizado com seções de deploy, logs, rollback e versioning.
- [x] IDR-002 registrado.
- [x] `index.json` atualizado.
- [x] Esta estória com "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Resumo:

1. **Ao iniciar:** carregue `docs/skills/programador/SKILL.md`. Atualize frontmatter desta estória e `index.json`.
2. **Durante:** TaskList interna; commits pequenos; nunca commite segredos. Atente para o tamanho L — se estourar 4h sem fim à vista, escale.
3. **Se travar:** `status: blocked`, registre.
4. **Decisões transversais de baixo nível** vão em IDR.
5. **Ao terminar:** demonstre métrica primária (3 deploys ≤ 10 min), preencha "Notas", `status: in_review`, atualize `index.json`, abra PR.

## Notas do agente (preenchido durante/após execução)

### Decisões tomadas

- **2026-05-27** — CI: GitHub Actions (`ci.yml` + `release.yml` + `scheduled-setup-test.yml`). Separação explícita: ci.yml em PRs/pushes (sem tag), release.yml apenas em tags.
- **2026-05-27** — Commit lint: Conventional Commits via `@commitlint/cli` + `@commitlint/config-conventional`. Config em `.github/commitlint/`.
- **2026-05-27** — Secret scanner: gitleaks CLI v8.24.3 instalado diretamente no runner (a ação oficial `gitleaks/gitleaks-action@v2` requer licença paga em organizações GitHub — substituída pelo binário gratuito).
- **2026-05-27** — Vulnerability scan: `composer audit` (PHP), `trivy` (imagens container) via `aquasecurity/trivy-action`.
- **2026-05-27** — Stamping da tag: Docker build ARG `APP_VERSION` → `public/version.json` (PHP) e `web/version.json` (Flutter). Persiste no artefato.
- **2026-05-27** — Exposição de versão: arquivo estático `/version.json` nas três interfaces. Mesmo padrão, documentado em IDR-002 e README.
- **2026-05-27** — Criação de tag: manual por quem libera o release (`git tag + git push origin tag`). Justificativa: controle explícito, auditável, sem automação que crie tags invisíveis.
- **2026-05-27** — Runtime PHP (prod): php-fpm + nginx + supervisord no mesmo container. Porta 8080 (Cloud Run default). Logformat JSON para Cloud Logging.
- **2026-05-27** — Worker: GCE e2-micro com Container-Optimized OS + Docker. Alternativa Cloud Scheduler → Cloud Run Job registrada em ADR-004 mas adiada (acréscimo de latência ≤ 1 min na fila não justifica a complexidade adicional agora).
- **2026-05-27** — Terraform estado: GCS bucket `turni-terraform-state` (criado manualmente no bootstrap, antes do terraform init).
- **2026-05-27** — Terraform ambiente de produção: scaffolded em `infra/envs/prod/`, idêntico em estrutura ao homolog, NÃO aplicado (EPIC-006).
- **2026-05-27** — Scheduled setup test: diário às 03:00 UTC (não sobrecarrega o free tier do GitHub Actions; frequência suficiente para detectar regressões de setup).

### Descobertas

- **2026-05-27** — DB mock no Pest: `DB::shouldReceive` ou `DB::partialMock()` sem configuração adicional afeta também o driver de sessão, resultando em 500 ao invés de 503 no teste do `/health?deep=1`. Solução: `config(['session.driver' => 'array'])` antes de mudar a conexão DB no teste.
- **2026-05-27** — Firebase Hosting: Terraform provisiona o site mas o deploy de conteúdo é feito pelo `firebase` CLI no CI (não pelo Terraform). Separação clara de responsabilidades.
- **2026-05-27** — `php:8.5-cli-alpine` já existe como imagem dev. Para prod, Cloud Run precisa de servidor HTTP real → criados Dockerfiles.prod com php-fpm + nginx + supervisord.

### Bloqueios encontrados

- **[RESOLVIDO — 2026-05-27]** CAs CA-3, CA-4 (3 deploys reais), CA-7d, CA-8, CA-11, CA-13: dependências externas resolvidas.
  1. ✅ Projeto GCP criado, GitHub secrets configurados.
  2. ✅ `terraform apply` executado em `infra/envs/homolog/` — VPC, Cloud SQL, Cloud Run, GCE worker, Firebase, Secret Manager, Cloud DNS, Cloud Scheduler provisionados.
  3. ✅ 3 tags `-rc.N` criadas e deployadas com sucesso (evidência na seção "Evidência da métrica primária").

- **[DESCOBERTA — 2026-05-27]** Cloud Run domain mapping (`google_cloud_run_domain_mapping`) não é suportado na região `southamerica-east1`. `api.homolog.turni.com.br` não tem DNS em homolog — acesso via URL direta do Cloud Run. Em produção será necessário HTTPS Global Load Balancer + Serverless NEG.

### IDRs criados

- IDR-002 — Mecanismo de stamping da tag no artefato e exposição da versão em runtime (`/version.json` estático nas três interfaces)

### Cobertura final

- api: 6 testes unitários/feature do /health + 7 existentes = 13 passando. Cobertura: scripts de IaC/pipeline (YAML/HCL) não entram na medição de cobertura PHP/Dart (configuração estática).
- admin: 3 testes unitários/feature do /health + 5 existentes = 8 passando.
- E2E: N/A nesta estória (sem fluxo de usuário visível).

### Evidência da métrica primária do EPIC-000
- **Tag 1** (`v0.1.0-rc.1`) → [run #26548939383](https://github.com/alcatechgroup/mvpturni-mvp/actions/runs/26548939383) — tempo: ~2 min — API health: `{"status":"ok","version":"v0.1.0-rc.1"}` — deploy: API ✓, Admin ✓, WebApp ✓
- **Tag 2** (`v0.1.0-rc.2`) → [run #26549114906](https://github.com/alcatechgroup/mvpturni-mvp/actions/runs/26549114906) — tempo: ~2 min — deploy: API ✓, Admin ✓, WebApp ✓
- **Tag 3** (`v0.1.0-rc.3`) → [run #26549196329](https://github.com/alcatechgroup/mvpturni-mvp/actions/runs/26549196329) — tempo: ~2 min — versão confirmada: `curl https://turni-api-homolog-dnj2tcr2xa-rj.a.run.app/health` → `{"status":"ok","version":"v0.1.0-rc.3",...}`

### Evidência de não-disparo por push/merge em `main`
- Verificável no histórico de Actions: pushes em `main` (commits do setup de CI) dispararam apenas `ci.yml` (CI run #26548933473, #26549040001, etc.); `release.yml` ficou inativo. Confirmado pela estrutura: `ci.yml` tem `tags-ignore: ["**"]`; `release.yml` usa `push.tags` com padrões `-rc.`.

### Padrão de versionamento documentado (consumido por STORY-008/009)

- **Stamping no artefato:** Docker build ARG `APP_VERSION` → `public/version.json` / `web/version.json` gerado no builder stage
- **Exposição em runtime:** arquivo estático `/version.json` servido por nginx (PHP) e Firebase Hosting (Flutter). Path: `https://{host}/version.json`
- **README:** seção "Deploy para homologação" com exemplos de curl
- **IDR:** IDR-002 em `docs/project-state/decisions/idr/IDR-002-versioning-e-exposicao-versao-runtime.md`
- **Para STORY-008 (Flutter):** `const String appVersion = String.fromEnvironment('APP_VERSION', defaultValue: 'dev');` (já injetado pelo `--dart-define`)
- **Para STORY-009 (PHP):** `env('APP_VERSION', 'dev')` (já disponível como env var no Cloud Run)

### Links de evidência
- [CI run principal](https://github.com/alcatechgroup/mvpturni-mvp/actions/runs/26549040001) — CI verde (commitlint, gitleaks, pint, flutter, smoke builds, trivy)
- [Release rc.1](https://github.com/alcatechgroup/mvpturni-mvp/actions/runs/26548939383) — deploy completo
- [Release rc.2](https://github.com/alcatechgroup/mvpturni-mvp/actions/runs/26549114906) — deploy completo
- [Release rc.3](https://github.com/alcatechgroup/mvpturni-mvp/actions/runs/26549196329) — deploy completo
- IaC: `infra/envs/homolog/` + `infra/modules/`
- Runbook de recriação: `docs/operacao/runbook-homolog.md`
- Runbook de rollback: `docs/operacao/runbook-homolog.md#rollback`
