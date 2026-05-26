---
story_id: STORY-005
slug: spike-adr-000-postgresql-retroativo
title: Spike Arquiteto — ADR-000 retroativo formalizando PostgreSQL como banco principal
epic_id: EPIC-000
sprint_id: null
type: spike
target_role: arquiteto
requires_design: false
status: ready
owner_agent: null
created_at: 2026-05-26
updated_at: 2026-05-26
estimated_session_size: S
---

# STORY-005 — Spike Arquiteto: ADR-000 retroativo formalizando PostgreSQL

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Ela contém tudo o que você precisa. Se algo estiver ambíguo, registre a dúvida na seção "Notas do agente" no final e pause em vez de adivinhar.

## Contexto (por que esta estória existe)

PostgreSQL **já é** o banco principal do Turni — é princípio arquitetural vigente, referenciado no `epic.md` do EPIC-000 e na SKILL do PO ("PostgreSQL já decidido"). Mas a decisão **não está registrada como ADR**, o que viola o princípio não-negociável #5 do PO: *"Estado registrado, sempre — toda decisão de produto vai para um PDR. Sem registro, a decisão não existe."* — e o equivalente arquitetural: sem ADR, não é decisão durável, é folclore.

Esta spike é simples: **formalizar retroativamente** PostgreSQL como banco principal em **ADR-000**, capturando o contexto histórico (por que foi escolhido, em que momento), as alternativas que foram consideradas (mesmo que informalmente), e os trade-offs aceitos. ADR retroativo é menor em deliberação (a decisão já está tomada) mas igualmente exigente em qualidade documental: sem ele, qualquer agente futuro que questione a escolha não tem referência para responder.

ADR-000 é numerada com `000` propositalmente — marca a decisão de fundação que precede todas as outras ADRs do projeto (incluindo a stack em ADR-001, que pode citar ADR-000 como restrição).

- Épico: `docs/project-state/epics/EPIC-000-foundation/epic.md`
- Documentos canônicos a ler ANTES de escrever:
  - `docs/skills/arquiteto/references/architecture-principles.md` (princípio #3 vigente — PostgreSQL)
  - `docs/skills/arquiteto/templates/adr.md`
  - `docs/skills/po/SKILL.md` ("PostgreSQL já decidido", linha 311)
  - `docs/project-state/epics/EPIC-000-foundation/epic.md` (ADR-000 explicitamente listada nas decisões necessárias)
  - `docs/especificacao/non-functional.md` (requisitos que PostgreSQL precisa suportar — disponibilidade, segurança em repouso)
  - `docs/especificacao/business-rules.md` (volume e perfis de carga MVP)

## O quê (objetivo desta estória)

Escrever e propor **ADR-000 — PostgreSQL como banco de dados principal (formalização retroativa)** em estado `proposed`, pronta para aprovação humana do Alexandro, formalizando uma decisão já em vigor para que ela possa ser citada por outras ADRs e PDRs.

## Por quê (valor para o usuário)

Esta estória não entrega valor direto ao usuário. Entrega disciplina ao processo: cumpre o princípio "estado registrado, sempre" do PO, fechando uma lacuna de governança documental que vai pesar mais e mais a cada nova decisão arquitetural que assuma PostgreSQL implicitamente. O preço de formalizar agora (uma sessão `S`) é minúsculo comparado ao custo de descobrir, daqui a 6 meses, que ninguém sabe por que PostgreSQL foi escolhido nem o que isso impede no futuro.

## Critérios de aceite

- [ ] **CA-1:** Existe `docs/project-state/decisions/adr/ADR-000-postgresql-banco-principal.md` em `status: proposed`, escrito conforme `docs/skills/arquiteto/templates/adr.md`.
- [ ] **CA-2:** A ADR é explicitamente **retroativa** — declara no campo "Contexto" que formaliza uma decisão já vigente como princípio arquitetural (referenciando `architecture-principles.md` princípio #3) e na seção "Decisão" cita a data efetiva de início (informal, antes desta formalização).
- [ ] **CA-3:** A ADR documenta as **alternativas que foram (informalmente) consideradas** — no mínimo 2 (ex: MySQL, MariaDB, banco NoSQL como MongoDB/DynamoDB) — com razão pela qual PostgreSQL prevaleceu. Mesmo que a deliberação original tenha sido informal, a documentação dos trade-offs precisa ficar.
- [ ] **CA-4:** A ADR explicita as **consequências aceitas**:
  - (a) capacidades que PostgreSQL viabiliza no MVP e além (transações ACID, JSON nativo, full-text search se útil, PostGIS se geofencing virar query — `non-functional.md`);
  - (b) restrições/limitações aceitas (escalonamento horizontal exige réplicas/sharding mais cedo que NoSQL puro; operação requer DBA-skill mais cedo);
  - (c) implicações para outras ADRs (ORM/camada de query escolhida em ADR-001 precisa ter driver maduro para PostgreSQL; provedor escolhido em ADR-004 precisa oferecer PostgreSQL gerenciado a custo razoável).
- [ ] **CA-5:** A ADR define **sinais de revisão** — gatilhos concretos que motivariam reabrir a decisão (ex: "se um requisito de produto exigir consistência fraca em escala global"; "se o custo operacional do PostgreSQL gerenciado virar > X% do orçamento de infra"; etc).
- [ ] **CA-6:** A ADR é **numerada como ADR-000** propositalmente (não ADR-009 nem outra), marcando-se como decisão de fundação anterior em ordem lógica à stack (ADR-001).
- [ ] **CA-7:** O `index.json` é atualizado com a entrada de ADR-000 em `decisions.adr[]` (`status: proposed`, path correto, `decided_at`, `approved_by: null`). Por ser retroativa, o `decided_at` é a data de proposta da formalização, e a ADR registra no texto a data efetiva original (mesmo que aproximada).
- [ ] **CA-8:** A ADR fica em `proposed` até aprovação humana do Alexandro registrada explicitamente.

## Fora de escopo

- Reabrir a decisão de PostgreSQL — esta spike formaliza, não delibera.
- Decidir versão específica do PostgreSQL, extensões, parâmetros de tuning — decisão local do Programador via IDR quando relevante.
- Decidir banco de dados auxiliar (Redis para cache, ElasticSearch para busca, etc) — fora do EPIC-000, vira ADR própria quando surgir necessidade.
- Decidir provedor gerenciado de PostgreSQL — isso é parte da ADR-004 (hospedagem).

## Padrões de qualidade exigidos

Estória **spike** — segue `docs/skills/po/references/quality-standards.md` com exceções declaradas:

- **Cobertura unitária / E2E:** N/A — sem código de produção.
- **Rigor aplicável:** documentação clara, alternativas honestas mesmo que retroativas, consequências aceitas explícitas, sinais de revisão concretos.

## Dependências

- **Bloqueada por:** nenhuma. Pode rodar em paralelo a STORY-001 a STORY-004 (todas as outras spikes do Arquiteto) e a STORY-010 (DDR-001 do Designer).
- **Bloqueia:** STORY-011 (validação). Indiretamente, ADR-001 (STORY-001) e ADR-004 (STORY-002) ganham clareza ao referenciar ADR-000 como restrição já formalizada — mas não a bloqueiam (podem rodar em paralelo assumindo PostgreSQL vigente).
- **Pré-requisitos de ambiente:** nenhum.

## Decisões já tomadas (não as reabra)

- **Princípio arquitetural #3 vigente** (`docs/skills/arquiteto/references/architecture-principles.md`) — PostgreSQL como banco principal. Esta spike formaliza, não questiona.
- **Princípio não-negociável #5 do PO** — "estado registrado, sempre". Esta spike existe para cumpri-lo.

## Liberdade técnica do agente

Você (agente arquiteto) decide:
- Como articular o contexto retroativo de forma honesta (não inventar deliberação que não houve).
- Quais alternativas listar (PostgreSQL não foi escolhido no vácuo — recupere o que foi pensado).
- Quais sinais de revisão definir.
- Tom e nível de detalhe da ADR — proporcional ao tamanho da decisão.

Você (agente arquiteto) NÃO decide:
- Mudar o banco principal — não é o que esta spike faz.
- Numerar a ADR como qualquer outra coisa que não `000`.

## Definição de Pronto (DoD)

- [ ] CA-1 a CA-8 atendidos.
- [ ] ADR-000 em `proposed` no path correto.
- [ ] `index.json` com a entrada nova em `decisions.adr[]`.
- [ ] Esta estória com "Notas do agente" preenchida.
- [ ] Frontmatter desta estória: `status: in_review` (aguardando aprovação).
- [ ] Nenhum código de produção introduzido.
- [ ] **Pré-condição para `done`:** Alexandro aprovou ADR-000 explicitamente; `index.json` reflete `accepted`.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Resumo:

1. **Ao iniciar:** carregue `docs/skills/arquiteto/SKILL.md`. Atualize frontmatter desta estória e `index.json`.
2. **Durante:** simples deliberação documental retroativa.
3. **Se travar:** `status: blocked`, registre.
4. **Ao terminar:** preencha "Notas", `status: in_review`, atualize `index.json`, abra PR.

## Notas do agente (preenchido durante/após execução)

### Decisões tomadas
- <data> — <decisão local>

### Descobertas
- <data> — <surpresa relevante (ex: alternativa antes não considerada)>

### Bloqueios encontrados
- <data> — <bloqueio>

### ADRs criados
- ADR-000 — PostgreSQL como banco de dados principal (formalização retroativa) — `decisions/adr/ADR-000-postgresql-banco-principal.md` — status: <proposed/accepted>

### Cobertura final
- Unitários: N/A (spike)
- E2E: N/A (spike)

### Links de evidência
- PR: <url>
- ADR proposta: <link>
- Aprovação registrada: <link>
