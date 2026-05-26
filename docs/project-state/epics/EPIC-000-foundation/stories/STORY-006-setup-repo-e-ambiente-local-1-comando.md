---
story_id: STORY-006
slug: setup-repo-e-ambiente-local-1-comando
title: Setup do repositório e ambiente local em 1 comando
epic_id: EPIC-000
sprint_id: null
type: enablement
target_role: programador
requires_design: false
status: ready
owner_agent: null
created_at: 2026-05-26
updated_at: 2026-05-26
estimated_session_size: M
---

# STORY-006 — Setup do repositório e ambiente local em 1 comando

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Ela contém tudo o que você precisa. Se algo estiver ambíguo, registre a dúvida na seção "Notas do agente" no final e pause em vez de adivinhar.

## Contexto (por que esta estória existe)

Princípio não-negociável #6 do PO (`docs/skills/po/SKILL.md`) e `quality-standards.md` seção 2.1 exigem: **"um comando único leva alguém de 'acabei de clonar o repo' até 'API e FE rodando localmente com dados de seed'"**. Esta é a fundação da automação total que o projeto persegue desde o dia 1 — sem ela, todo novo agente programador (ou Alexandro entrando no papel de Programador) gasta tempo configurando ambiente, e a fricção mata o ciclo TDD que `quality-standards.md` exige.

Esta estória é **horizontal por natureza** (`type: enablement`) — não atravessa um fluxo de usuário, configura a base sobre a qual estórias de feature vão rodar. A justificativa de horizontalidade (`story-craft.md` seção "Estórias que resistem ao vertical slicing"): setup de ambiente local não pertence a fluxo de usuário específico; destrava STORY-007 (pipeline CI/CD), STORY-008/009 (hello world) e toda estória subsequente que escreve código.

A estória entra após as spikes do Arquiteto (STORY-001 a STORY-005) porque a estrutura concreta depende da stack, da topologia, da estratégia de repositório e do banco — todas decididas em ADRs.

- Épico: `docs/project-state/epics/EPIC-000-foundation/epic.md`
- Documentos canônicos a ler ANTES de codificar:
  - `docs/skills/po/references/quality-standards.md` seções 2.1 (ambiente local), 2.2 (CI/CD), 2.4 (banco), 4 (segurança — segredos)
  - `docs/skills/programador/SKILL.md` (skill que você está executando)
  - `docs/project-state/decisions/adr/ADR-000-postgresql-banco-principal.md` (banco do ambiente local é PostgreSQL real, não SQLite)
  - `docs/project-state/decisions/adr/ADR-001-stack-principal.md` (linguagem, framework, ORM, ferramenta de teste)
  - `docs/project-state/decisions/adr/ADR-002-topologia.md` (monolito vs separação — afeta o que sobe)
  - `docs/project-state/decisions/adr/ADR-003-monorepo-vs-polirepo.md` (estrutura do(s) repositório(s))
  - `docs/project-state/decisions/adr/ADR-004-hospedagem-iac-deploy.md` (variáveis de ambiente, paridade dev/prod)
  - `docs/project-state/decisions/adr/ADR-008-observabilidade-minima.md` (formato de log local coerente com produção)
  - `docs/project-state/decisions/adr/ADR-005-integracao-pagarme.md` (mock local em container — Pagar.me não é chamado em dev/CI)

## O quê (objetivo desta estória)

Criar o(s) repositório(s) conforme ADR-003 e implementar um **único comando** (ex: `make setup && make up`, `./scripts/dev`, `pnpm dev`, `cargo run` — o que a stack e o ADR-003 indicarem) que, partindo de máquina limpa com pré-requisitos mínimos documentados (ex: Docker + runtime da linguagem), sobe localmente:

- **WebApp** (rota raiz responde 200 com placeholder mínimo — ainda sem `/health`, isso é STORY-008/009);
- **Backoffice** (idem);
- **PostgreSQL** com schema vazio e migração inicial idempotente aplicada;
- **Mock do Pagar.me** em container conforme ADR-005 (rodando, mesmo que sem rotas implementadas — só precisa estar de pé para STORYs futuras consumirem);
- **Quaisquer outros serviços base** que as ADRs aceitas indiquem.

E também: dados de seed mínimos no banco (pelo menos um usuário admin de teste para o backoffice — sem login funcional ainda, só presença), README do projeto, hook de pré-push automatizado conforme `quality-standards.md` seção 2.2.

## Por quê (valor para o usuário)

Esta estória entrega valor ao **time** (Alexandro nos 5 papéis e qualquer agente programador futuro): reduz de "horas configurando" para "minutos" o ciclo entre clonar o repo e começar a escrever código + testes. Sem ela, cada estória de feature subsequente paga uma taxa de fricção desproporcional, e o princípio #6 ("automação por padrão") vira aspiracional em vez de real.

Indiretamente, é também a primeira evidência de que as ADRs propostas pelo Arquiteto **funcionam na prática**: se a stack escolhida exige configuração manual heroica para subir local, é sinal de revisão de ADR.

## Critérios de aceite

- [ ] **CA-1:** Repositório(s) criado(s) e estruturado(s) conforme ADR-003 (monorepo ou polirepo). README na raiz contém: visão de uma frase do Turni, link para `AGENTS.md`, link para `docs/project-state/`, pré-requisitos para rodar local (versão mínima de runtime, Docker, etc — lista curta) e a frase exata do comando único.
- [ ] **CA-2:** Em máquina limpa com os pré-requisitos instalados, executar o comando único da raiz sobe **WebApp + Backoffice + PostgreSQL + mock Pagar.me** em estado saudável (cada processo aceita conexão na porta configurada) em ≤ 5 minutos no primeiro `setup` e ≤ 1 minuto em runs subsequentes (`up` apenas, sem rebuild).
- [ ] **CA-3:** PostgreSQL local sobe com schema inicial aplicado via **migração automatizada e idempotente** (rodar o comando duas vezes não quebra — `quality-standards.md` seção 2.4). A migração inicial pode ser vazia (ou só com a tabela de controle de migrações) — não cria modelo de domínio ainda.
- [ ] **CA-4:** O ambiente local **não** chama Pagar.me real — usa o mock em container. Variável de ambiente / arquivo de configuração local aponta para o mock.
- [ ] **CA-5:** Segredos (mesmo de mock/dev) **não** ficam commitados em texto — usa `.env.example` versionado + `.env` no `.gitignore`. README explica como criar o `.env` a partir do `.env.example` (idealmente o comando de setup faz isso quando ausente).
- [ ] **CA-6:** **Hook de pré-push** instalado por um comando padrão do projeto (`quality-standards.md` seção 2.2), rodando: testes unitários + testes de integração contra PostgreSQL local + medição de cobertura. Hook falha = `git push` abortado. **Para esta estória**, basta o aparato existir e rodar 1 teste trivial (smoke) — testes E2E em browser real ficam em STORY-008/009.
- [ ] **CA-7:** Dados de seed mínimos: pelo menos um usuário admin de teste (sem login funcional — só presença no banco para próximas estórias consumirem). Seed é executado pelo comando de setup; rodar duas vezes é idempotente.
- [ ] **CA-8:** Comando de setup é **testado em CI periodicamente** (job de CI ou script agendado) para não apodrecer — `quality-standards.md` seção 2.1. Pode ser apenas um workflow que `clones em runner limpo + executa setup + faz curl nas portas`. Pode ser feito junto com STORY-007 se o pipeline ainda não existe; aqui basta o trabalho estar previsto no PR ou criar a tarefa para STORY-007 absorver.
- [ ] **CA-9:** README de cada interface (WebApp, Backoffice) e do repositório raiz documenta: comando único, comandos auxiliares (rodar testes, rodar lint, parar tudo, limpar), e estrutura de pastas em alto nível.
- [ ] **CA-10:** **Teste smoke unitário** existe em pelo menos um dos componentes (mesmo que trivial — "1 + 1 == 2" no framework de teste de ADR-001), rodando no pré-push, **só para garantir que o aparato de teste está plugado** desde a primeira estória.

## Fora de escopo

- Health-check `/health` — STORY-008/009.
- Login real, telas de cadastro — EPIC-001.
- Pipeline CI/CD com deploy automático — STORY-007.
- Configurar ambiente de produção — fora do EPIC-000 (EPIC-006 na próxima onda).
- Implementar mock do Pagar.me com rotas funcionais (só precisa estar **de pé** para próximas estórias popularem).
- Aplicar Design System / tokens do DDR-001 nas páginas raiz — STORY-008 (paralelo com STORY-010).
- Criar tabelas de domínio (`usuario`, `vaga`, etc) — EPIC-001 em diante.

## Padrões de qualidade exigidos

Esta estória segue os padrões em `docs/skills/po/references/quality-standards.md`. Aplicáveis em particular:

- **Cobertura unitária ≥ 80% no código novo**, com a nuance de que o **código novo** desta estória é majoritariamente scripts de setup e configuração — onde houver lógica testável (script de seed, migração customizada), cobrir conforme exigência geral. Trivialidades de configuração ficam fora da medição quando justificado.
- **Sem testes E2E** ainda — o aparato E2E entra em STORY-008/009; aqui o ambiente precisa estar **pronto para receber** E2E (browser real conforme ADR-001 + ferramenta de ADR-001 instalada como dev dependency).
- **Automação total**: zero passo manual entre clonar e ter ambiente rodando, além de instalar pré-requisitos listados no README. Passo manual recorrente é bug do processo (princípio #4 do PO).
- **Segurança**: segredos via variável injetada, nunca em código (`quality-standards.md` seção 4). Hook de pré-push roda detector de segredos (mesmo que mínimo).
- **Banco**: migrações idempotentes e versionadas (`quality-standards.md` seção 2.4).

## Dependências

- **Bloqueada por:** STORY-001 (ADR-001/002/003 aceitas), STORY-002 (ADR-004 aceita — necessária para alinhar variáveis de ambiente / paridade dev↔prod), STORY-005 (ADR-000 aceita — PostgreSQL formalizado), STORY-003 (ADR-005 aceita — desenho do mock Pagar.me), STORY-004 (ADR-008 aceita — formato de log local coerente com produção).
- **Bloqueia:** STORY-007 (pipeline depende do repo existir e do comando de setup ser invocável de CI), STORY-008 (hello world precisa do repo+app vazio), STORY-009 (idem backoffice), STORY-011 (validação).
- **Pré-requisitos de ambiente:** Docker disponível na máquina do executor; runtime da stack escolhida (versão definida em ADR-001).

## Decisões já tomadas (não as reabra)

- **ADR-000** — PostgreSQL como banco local (não SQLite, não in-memory para testes de integração).
- **ADR-001** — Stack principal define linguagem, framework, ORM, ferramenta de teste. Use o que a ADR mandou.
- **ADR-002** — Topologia (monolito modular ou separação) define o que sobe.
- **ADR-003** — Monorepo vs polirepo define a estrutura do(s) repo(s).
- **ADR-004** — Hospedagem/IaC define variáveis de ambiente e modelo de cofre de segredos (mesmo em dev).
- **ADR-005** — Pagar.me é mockado em container localmente.
- **ADR-008** — Formato de log estruturado é o mesmo em dev e prod.
- **Princípio #6 do PO** — ambiente em 1 comando é exigência.
- **`quality-standards.md` seção 2.2** — hook de pré-push é obrigatório.

## Liberdade técnica do agente

Você (agente programador) decide:
- Como estruturar pastas, módulos, scripts dentro do que ADR-002/003 permitem.
- Nome do comando único (`make`, `pnpm`, `task`, script próprio) — coerente com a stack.
- Ferramenta de orquestração local (Docker Compose, Devcontainer, equivalente).
- Como o `.env.example` é estruturado e quais variáveis canônicas.
- Estrutura concreta do seed (linguagem do projeto vs SQL puro).
- Conteúdo dos placeholders de WebApp e Backoffice na rota raiz (texto simples basta; visual coerente entra em STORY-008).
- Refatorações estruturais locais.

Você (agente programador) NÃO decide:
- Substituir PostgreSQL por outro banco (ADR-000).
- Mudar stack (ADR-001).
- Mudar topologia ou estratégia de repo (ADR-002/003).
- Suprimir hook de pré-push (`quality-standards.md` seção 2.2).
- Commitar segredos (`quality-standards.md` seção 4).
- Implementar funcionalidade fora do escopo desta estória.

Se durante a execução você perceber que uma ADR precisa ser revisada (ex: o comando único na stack escolhida exige acrobacia que sinaliza problema), **registre em "Notas do agente"** com tag `[ESCALONAMENTO]` e mude `status: blocked`. Não decida sozinho mudar a stack.

## Definição de Pronto (DoD)

- [ ] Todos os critérios de aceite (CA-1 a CA-10) passam.
- [ ] Testes unitários escritos e passando atingindo as coberturas exigidas no código novo testável.
- [ ] Não há teste E2E aplicável nesta estória (próxima entrada em STORY-008/009) — declarado.
- [ ] Pipeline de CI verde no PR (mesmo que o pipeline ainda seja mínimo — STORY-007 vai expandi-lo).
- [ ] Hook de pré-push instalado e funcionando localmente (evidência: rodar uma vez localmente e mostrar log no PR).
- [ ] README na raiz e em cada interface atualizado.
- [ ] `index.json` atualizado: status desta estória = `in_review` ao abrir PR; `done` após merge.
- [ ] Esta estória atualizada com "Notas do agente" preenchida.
- [ ] IDR registrado se houve decisão técnica de baixo nível com impacto futuro (ex: padrão de organização de migrações, padrão de estrutura de testes — qualquer coisa que outras estórias vão herdar).

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Resumo:

1. **Ao iniciar:** carregue `docs/skills/programador/SKILL.md`. Edite frontmatter desta estória: `status: in_progress`, `owner_agent`, `updated_at`. Atualize `index.json`.
2. **Durante:** TaskList interna; TDD onde aplicável (lógica testável); commits pequenos e nomeados; mantenha "Notas do agente" atualizada.
3. **Se travar:** `status: blocked`, registre.
4. **Decisões técnicas de baixo nível** com impacto futuro vão em IDR.
5. **Ao terminar:** preencha "Notas", `status: in_review`, atualize `index.json`, abra PR. Após merge e deploy verde (próximas estórias consomem), `status: done`.

## Notas do agente (preenchido durante/após execução)

### Decisões tomadas
- <data> — <decisão local>

### Descobertas
- <data> — <surpresa / gotcha>

### Bloqueios encontrados
- <data> — <bloqueio>

### IDRs criados
- IDR-XXX — <título> — `decisions/idr/IDR-XXX-<slug>.md`

### Cobertura final
- Unitários: <%>
- E2E: N/A nesta estória

### Links de evidência
- PR: <url>
- Pipeline: <url>
- Comando único em ação (asciinema / vídeo / log): <link>
