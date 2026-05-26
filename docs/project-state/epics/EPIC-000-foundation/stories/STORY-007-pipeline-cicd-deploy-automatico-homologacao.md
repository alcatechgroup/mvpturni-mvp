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

- [ ] **CA-1:** Todo PR para `main` dispara CI que executa: lint da linguagem/framework (ADR-001), lint de commit messages (ex: Conventional Commits — agente escolhe especificação coerente), análise de dependências vulneráveis (scanner público/grátis), detecção de segredos commitados (scanner público/grátis), **build de smoke** do artefato de **cada interface** (WebApp e Backoffice) — verifica que o artefato compila, mas **não** é o artefato de release publicado nem deployado. Falha em qualquer step bloqueia merge.
- [ ] **CA-2:** CI **não sobe banco nem browser** no runner (testes pesados são responsabilidade do hook de pré-push em STORY-006).
- [ ] **CA-3:** CI executa em ≤ 5 min em PR típico.

### CD tag-based para homologação

- [ ] **CA-4:** Criação de tag `vX.Y.Z-rc.N` (no commit já mergeado em `main`) é o **único disparador** de build de release + deploy. O pipeline executa, sem gate humano, build dos artefatos de WebApp e Backoffice **com a tag injetada como versão**, publica os artefatos no registry/storage do provedor, e deploya em `app.homolog.turni.com.br` e `admin.homolog.turni.com.br`. Tempo total (tag criada → health-check verde em ambas as URLs) ≤ **10 min** em pelo menos 3 execuções consecutivas (evidência: logs de CI).
- [ ] **CA-5:** Deploys das duas interfaces são **independentes** — falha em uma não impede a outra (PDR-003). Reexecutar deploy da interface que falhou é uma ação de 1 comando ou 1 clique no CI usando os artefatos **já publicados pela mesma tag** (sem precisar recriar a tag nem rebuildar do zero).
- [ ] **CA-6:** Promoção é **tag-based exclusiva** — push, commit ou merge em `main` (sem tag posterior) faz **apenas o CI leve** do PR/branch passar; **não** builda artefato de release, **não** publica e **não** deploya. Só a criação da tag `vX.Y.Z-rc.N` dispara homologação. Evidência: ao menos um push em `main` (com `git push origin main` ou merge) registrado nos logs de CI que **não** resultou em deploy, mostrando o disparo apenas do CI leve.
- [ ] **CA-7:** Estrutura de promoção para produção (`vX.Y.Z` sem `-rc`) está **desenhada no pipeline com gate humano de 1 clique**, mesmo que o ambiente de produção ainda não exista (EPIC-006). O gate é o mecanismo nativo do CI escolhido (`quality-standards.md` seção 2.2). Tags de produção reutilizam os artefatos publicados pela tag `-rc.N` correspondente (não rebuildam).

### Stamping da tag e exposição da versão em runtime

- [ ] **CA-7b:** O pipeline de release **injeta o nome da tag** (`vX.Y.Z-rc.N`) no artefato de cada interface no momento do build, via mecanismo escolhido pelo agente (build arg, variável de ambiente de build, arquivo gerado no build, label de imagem, equivalente). A versão injetada **persiste** no artefato publicado — não depende de variável de runtime do provedor para existir.
- [ ] **CA-7c:** Cada interface expõe a versão em runtime por um **mecanismo padronizado e único para as duas interfaces** (à escolha do agente — ex: variável global em JS, arquivo estático `/version.json`, endpoint `/version`, header HTTP de resposta — desde que seja **o mesmo padrão nas duas**). Documentação do padrão no README do repositório, em formato consumível por STORY-008 (página inicial + payload de `/health`) e STORY-009 (página inicial + payload de `/health`) **sem que essas estórias precisem inventar** o mecanismo.
- [ ] **CA-7d:** A versão exposta em runtime no artefato deployado bate **exatamente** com o nome da tag que disparou o deploy. Evidência: para um deploy com tag `vX.Y.Z-rc.N`, fazer `curl` (ou inspeção pelo mecanismo escolhido) retorna `vX.Y.Z-rc.N`. Versão `unknown`, `dev`, `0.0.0` ou similar **não** é aceitável em homologação — é `fail` da estória.
- [ ] **CA-7e:** Se o agente escolher um mecanismo que requer convenção transversal (ex: endpoint `/version` que outras estórias devem implementar nas próximas interfaces), o padrão é registrado em **IDR** referenciado no `index.json`, de modo que estórias futuras herdem sem reabrir a decisão.

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

- [ ] Todos os CAs (CA-1 a CA-3, CA-4 a CA-7, CA-7b a CA-7e, CA-8 a CA-16) atendidos.
- [ ] Cobertura unitária ≥ 80% no código novo testável.
- [ ] **Métrica primária do EPIC-000 demonstrada**: 3 tags `-rc.N` consecutivas (cada uma criada em commit já mergeado em `main`) resultaram em build de release + deploy automático verde em ambas as URLs em ≤ 10 min — evidência (links de CI) registrada em "Notas do agente". Cada um dos 3 deploys teve a versão correta exposta em runtime conferida via `curl` no mecanismo padronizado (CA-7d).
- [ ] **Evidência de não-disparo**: ao menos um push/merge em `main` sem tag posterior, mostrando que CI leve passou mas nenhum deploy foi disparado (CA-6).
- [ ] Pipeline verde no PR.
- [ ] IaC versionado, runbook de recriação documentado.
- [ ] Health-check ativo em ambas as URLs com alerta plugado.
- [ ] README atualizado: como rodar, como deployar (criar tag), como acessar logs, como rollback, **como STORY-008/009 consomem a versão do artefato**.
- [ ] IDR registrado para padrões transversais — no mínimo: convenção de tags, estrutura de IaC, naming de recursos, **mecanismo de stamping da tag no artefato**, **mecanismo de exposição da versão em runtime**.
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
- Tag 1 (`vX.Y.Z-rc.N`) → build+deploy: <link CI> — tempo total: <X min> — health-check: <link> — versão exposta em runtime: `<vX.Y.Z-rc.N>` (link curl)
- Tag 2 (`vX.Y.Z-rc.N`) → build+deploy: <link CI> — tempo total: <X min> — health-check: <link> — versão exposta em runtime: `<vX.Y.Z-rc.N>` (link curl)
- Tag 3 (`vX.Y.Z-rc.N`) → build+deploy: <link CI> — tempo total: <X min> — health-check: <link> — versão exposta em runtime: `<vX.Y.Z-rc.N>` (link curl)

### Evidência de não-disparo por push/merge em `main`
- Push/merge em `main` sem tag posterior: <link CI mostrando só CI leve, sem job de deploy>

### Padrão de versionamento documentado (consumido por STORY-008/009)
- Mecanismo de stamping no artefato: <descrição>
- Mecanismo de exposição em runtime: <descrição + path no README>
- IDR: <link>

### Links de evidência
- PR: <url>
- Pipeline: <url>
- IaC repo/módulo: <url>
- Runbook de recriação: <link>
- Runbook de rollback: <link>
