---
story_id: STORY-007
slug: pipeline-cicd-deploy-automatico-homologacao
title: Pipeline CI/CD com deploy automático para as duas homologações
epic_id: EPIC-000
sprint_id: null
type: enablement
target_role: programador
requires_design: false
status: ready
owner_agent: null
created_at: 2026-05-26
updated_at: 2026-05-26
estimated_session_size: L
---

# STORY-007 — Pipeline CI/CD com deploy automático para as duas homologações

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Ela contém tudo o que você precisa. Se algo estiver ambíguo, registre a dúvida na seção "Notas do agente" no final e pause em vez de adivinhar.

## Contexto (por que esta estória existe)

A métrica primária do EPIC-000 é: **"merge na `main` dispara deploy automático para ambas as homologações em ≤ 10 min, com health-check verde no fim, repetível em 3 merges consecutivos sem intervenção manual"** (`epic.md`). Esta estória entrega o aparato que torna essa métrica perseguível. Sem ela, STORY-008 e STORY-009 (hello world) não têm onde aterrissar — escrevem código mas nada sobe sozinho em homologação.

Estória **horizontal por natureza** (`type: enablement`) — não atravessa fluxo de usuário, configura o canal de entrega. Justificativa (`story-craft.md` "Estórias que resistem a vertical slicing"): pipeline de CI/CD não pertence a fluxo específico; destrava STORY-008/009 e toda estória subsequente que precisa ir para homologação.

Tamanho estimado **L** justificado: cobre **CI** (jobs no PR), **CD para homologação automática** via tag-based promotion, **IaC** provisionando os dois subdomínios e bucket/runtime de cada interface, e **observabilidade mínima** acessível (logs visíveis, health-check externamente probe-able). Não foi quebrada em duas estórias porque os pedaços não são deployáveis isoladamente (CI sem CD não destrava nada; CD sem IaC não tem onde deployar). Se durante a execução o agente descobrir que cabe quebrar, escala antes de fatiar.

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

1. **CI leve em cada PR** rodando: lint da linguagem/framework, lint de commit messages, análise de dependências vulneráveis, detecção de segredos commitados, análise estática de imagens de container (se aplicável), build do artefato de deploy. Sem subir banco ou browser no runner (`quality-standards.md` seção 2.2 — testes pesados ficam no hook de pré-push de STORY-006).
2. **Promoção tag-based para homologação**: criação de tag `vX.Y.Z-rc.N` em `main` dispara deploy automático **sem gate humano** para `app.homolog.turni.com.br` e `admin.homolog.turni.com.br`. (Tag `vX.Y.Z` sem `-rc` dispara produção com gate humano — esta estória **deixa o gancho pronto** mas o ambiente de produção em si fica para EPIC-006.)
3. **IaC versionado em git** provisionando os dois subdomínios, runtime de cada interface, banco PostgreSQL gerenciado de homologação, certificado HTTPS, segredos via cofre do provedor — conforme ADR-004. Recriar homologação a partir do código é um runbook viável (`quality-standards.md` seção 2.3).
4. **Health-check probe externo** — o sistema do provedor monitora `/health` em cada interface; alerta para Alexandro (canal definido em ADR-008) se cair além do limiar.
5. **Logs estruturados** indo para o destino definido em ADR-008, com `request_id` propagado e visíveis a partir de um comando/UI simples documentado no README.
6. **Pipeline testa o setup local** periodicamente (CA-8 de STORY-006) — job de CI agendado que clona em runner limpo, executa o comando único, faz curl nas portas.

## Por quê (valor para o usuário)

Esta estória, junto com STORY-008/009, materializa o entregável visível do EPIC-000: as duas URLs de homologação respondendo com hello world + health-check verdes, com cada merge em `main` resultando em deploy automático em ≤ 10 min. Para o **time**, é o salto de "fazemos manual" para "o sistema faz por nós", que sustenta a velocidade nas próximas ondas. Para o **futuro usuário externo**, é o canal pelo qual ele eventualmente vai conhecer o produto — e a evidência de que ele está sob controle operacional.

## Critérios de aceite

### CI no PR

- [ ] **CA-1:** Todo PR para `main` dispara CI que executa: lint da linguagem/framework (ADR-001), lint de commit messages (ex: Conventional Commits — agente escolhe especificação coerente), análise de dependências vulneráveis (scanner público/grátis), detecção de segredos commitados (scanner público/grátis), build do artefato de deploy de **cada interface** (WebApp e Backoffice). Falha em qualquer step bloqueia merge.
- [ ] **CA-2:** CI **não sobe banco nem browser** no runner (testes pesados são responsabilidade do hook de pré-push em STORY-006).
- [ ] **CA-3:** CI executa em ≤ 5 min em PR típico.

### CD tag-based para homologação

- [ ] **CA-4:** Criação de tag `vX.Y.Z-rc.N` em `main` dispara, automaticamente e sem gate humano, deploy do WebApp para `app.homolog.turni.com.br` e do Backoffice para `admin.homolog.turni.com.br`. Tempo total (tag criada → health-check verde em ambas as URLs) ≤ **10 min** em pelo menos 3 execuções consecutivas (evidência: logs de CI).
- [ ] **CA-5:** Deploys das duas interfaces são **independentes** — falha em uma não impede a outra (PDR-003). Reexecutar deploy da interface que falhou é uma ação de 1 comando ou 1 clique no CI, sem precisar recriar a tag.
- [ ] **CA-6:** Promoção é **tag-based explícita** — push em `main` sem tag faz CI passar, mas **não** dispara deploy. Só a tag `-rc.N` dispara homologação.
- [ ] **CA-7:** Estrutura de promoção para produção (`vX.Y.Z` sem `-rc`) está **desenhada no pipeline com gate humano de 1 clique**, mesmo que o ambiente de produção ainda não exista (EPIC-006). O gate é o mecanismo nativo do CI escolhido (`quality-standards.md` seção 2.2).

### IaC

- [ ] **CA-8:** IaC (ferramenta definida em ADR-004) provisiona, a partir de `main` em ramo limpo: domínios + DNS, runtime de cada interface, PostgreSQL gerenciado de homologação, certificado HTTPS válido, cofre de segredos com valores injetados (segredos via mecanismo do provedor, nunca em git).
- [ ] **CA-9:** Recriar a homologação a partir do IaC do zero é exercício viável — documentado em runbook no README ou em `docs/operacao/` (estrutura à escolha do agente, contanto que esteja versionado em git).
- [ ] **CA-10:** Rollback: existe procedimento documentado (1 comando / 1 clique) para reverter o deploy ativo para o anterior, sem intervenção fora de git. Pode ser via re-deploy de tag anterior — basta estar testado e documentado.

### Observabilidade ativa

- [ ] **CA-11:** Health-check externo monitora `/health` em ambas as URLs com intervalo razoável (≤ 1 min) e dispara alerta para Alexandro pelo canal definido em ADR-008 quando indisponível por X consecutivas (X documentado).
- [ ] **CA-12:** Logs estruturados produzidos em homologação são visíveis por comando / UI do provedor; README documenta como acessá-los.
- [ ] **CA-13:** `request_id` propagado em logs end-to-end (decidido em ADR-008) — quando o validador fizer uma requisição em homologação, deve conseguir rastrear no log pelo id retornado no header de resposta.

### Setup local periódico

- [ ] **CA-14:** Job de CI agendado (ex: 1x/dia ou 1x/semana — agente escolhe cadência razoável) clona o repositório em runner limpo, executa o comando único de STORY-006, e verifica que cada porta responde com curl. Falha desse job dispara o mesmo canal de alerta. (Fecha CA-8 de STORY-006.)

### Transversais

- [ ] **CA-15:** **Nenhum segredo** em git nem em log (scanner do CI passa). Segredos vivem no cofre do provedor (definido em ADR-004).
- [ ] **CA-16:** Pipeline é versionado em git (arquivo(s) de configuração do CI). Mudar pipeline exige PR.

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
- **`quality-standards.md` seção 2.2** — modelo de promoção tag-based; CI leve no PR (sem banco/browser); gate humano de 1 clique em produção; deploy nunca manual.
- **`quality-standards.md` seção 2.3** — IaC sem cliques manuais.

## Liberdade técnica do agente

Você (agente programador) decide:
- Provedor de CI concreto (dentro do que ADR-004 permite — GitHub Actions, GitLab CI, CircleCI, etc).
- Especificação de commit messages (Conventional Commits ou equivalente).
- Estrutura de jobs (paralelização, matriz por interface, etc).
- Scanners específicos (Trivy, gitleaks, Dependabot, equivalentes).
- Cadência do job agendado de setup local (CA-14).
- Estrutura de IaC (módulos, ambientes, naming) dentro do que ADR-004 permite.
- Mecanismo concreto de rollback (re-deploy de tag, blue/green, rollback do provedor).
- Refatorações locais.

Você (agente programador) NÃO decide:
- Suprimir o gate humano em produção (mesmo que produção ainda não exista).
- Disparar deploy em homologação sem tag-based promotion.
- Pôr segredo em git.
- Mudar provedor (ADR-004 trava).
- Reabrir escopo do EPIC-000 (produção fica para EPIC-006).

Se durante a execução você perceber que ADR-004 não cobre cenário concreto (ex: o provedor não suporta gate humano "nativo" do jeito necessário), **escale para o Arquiteto** via `[ESCALONAMENTO]` em "Notas do agente".

## Definição de Pronto (DoD)

- [ ] Todos os CAs (CA-1 a CA-16) atendidos.
- [ ] Cobertura unitária ≥ 80% no código novo testável.
- [ ] **Métrica primária do EPIC-000 demonstrada**: 3 merges consecutivos em `main` (cada um com tag `-rc.N` após merge) resultaram em deploy automático verde em ambas as URLs em ≤ 10 min — evidência (links de CI) registrada em "Notas do agente".
- [ ] Pipeline verde no PR.
- [ ] IaC versionado, runbook de recriação documentado.
- [ ] Health-check ativo em ambas as URLs com alerta plugado.
- [ ] README atualizado: como rodar, como deployar, como acessar logs, como rollback.
- [ ] IDR registrado para padrões transversais (ex: convenção de tags, estrutura de IaC, naming de recursos).
- [ ] `index.json` atualizado.
- [ ] Esta estória com "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Resumo:

1. **Ao iniciar:** carregue `docs/skills/programador/SKILL.md`. Atualize frontmatter desta estória e `index.json`.
2. **Durante:** TaskList interna; commits pequenos; nunca commite segredos. Atente para o tamanho L — se estourar 4h sem fim à vista, escale.
3. **Se travar:** `status: blocked`, registre.
4. **Decisões transversais de baixo nível** vão em IDR.
5. **Ao terminar:** demonstre métrica primária (3 deploys ≤ 10 min), preencha "Notas", `status: in_review`, atualize `index.json`, abra PR.

## Notas do agente (preenchido durante/após execução)

### Decisões tomadas
- <data> — <decisão local>

### Descobertas
- <data> — <surpresa / gotcha>

### Bloqueios encontrados
- <data> — <bloqueio>

### IDRs criados
- IDR-XXX — <título>

### Cobertura final
- Unitários: <%>
- E2E: N/A nesta estória

### Evidência da métrica primária do EPIC-000
- Merge 1 → deploy: <link CI> — tempo total: <X min> — health-check: <link>
- Merge 2 → deploy: <link CI> — tempo total: <X min> — health-check: <link>
- Merge 3 → deploy: <link CI> — tempo total: <X min> — health-check: <link>

### Links de evidência
- PR: <url>
- Pipeline: <url>
- IaC repo/módulo: <url>
- Runbook de recriação: <link>
- Runbook de rollback: <link>
