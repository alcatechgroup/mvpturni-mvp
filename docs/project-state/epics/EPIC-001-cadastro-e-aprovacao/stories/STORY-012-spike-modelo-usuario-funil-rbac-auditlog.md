---
story_id: STORY-012
slug: spike-modelo-usuario-funil-rbac-auditlog
title: Spike Arquiteto — modelo de usuário polimórfico, funil pós-aprovação, RBAC com ownership e audit log de admin (ADR-009)
epic_id: EPIC-001
sprint_id: SPRINT-2026-W24
type: spike
target_role: arquiteto
requires_design: false
status: done
owner_agent: claude-sonnet-4-6-arquiteto-2026-05-28
created_at: 2026-05-28
updated_at: 2026-05-28
estimated_session_size: M
---

# STORY-012 — Spike Arquiteto: modelo de usuário polimórfico, funil, RBAC com ownership e audit log

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Ela contém tudo o que você precisa. Se algo estiver ambíguo, registre a dúvida na seção "Notas do agente" no final e pause em vez de adivinhar.

## Contexto (por que esta estória existe)

O EPIC-001 é o primeiro épico que cria entidades de domínio com lógica de negócio (`profissional` polimórfico, `contratante`, fluxo de estado `pendente_aprovacao → liberado → ativo`, papéis com restrições de acesso, log auditável de ação de admin). ADR-007 fixou o **mecanismo de auth** (Sanctum SPA + guard web + coluna `role`+`status` em `users`) mas deixou explicitamente para esta estória: **(a)** a modelagem fina do funil pós-aprovação (welcome / completar cadastro como flags ou como estados próprios), **(b)** ownership/policies para o RBAC ficar **vivo** (não basta `role` — profissional só pode ver os próprios dados, contratante só os do estabelecimento, admin vê tudo) e **(c)** o **audit log de admin** (ADR-007 §e: "tabela append-only no Postgres, imutável, retenção longa; o modelo de tabela é detalhado num ADR de persistência do EPIC-001"). Sem ADR cobrindo isso, as 11 estórias de implementação do EPIC-001 vão decidir ad-hoc no código — exatamente o tipo de dívida que o produto não tolera dado o porte do dado coletado (CPF/CNPJ, chave Pix, dados bancários, foto de documento, aceite contratual).

Por que **uma** ADR cobre as três coisas (e não duas/três spikes separadas): identidade polimórfica, estado do funil, RBAC com ownership e audit log de admin formam **um subsistema único de governança de identidade**. Decidir o modelo de usuário sem decidir como ownership funciona deixa lacuna que vira refactor. Decidir ownership sem decidir audit log do admin deixa metade da governança ad-hoc. As três caem juntas porque a unidade de evidência é a mesma — "quem é o usuário, em que estado está, o que ele pode ver/fazer, e o que o admin fez sobre ele". `story-craft.md` autoriza "2 ADRs fortemente correlatas" — aqui temos uma ADR única cobrindo um subsistema coeso, o que é mais limpo.

- Épico: `docs/project-state/epics/EPIC-001-cadastro-e-aprovacao/epic.md`
- Documentos canônicos a ler ANTES de deliberar:
  - `docs/especificacao/domain/usuario.md` (estados, atributos por papel, funil, regras)
  - `docs/especificacao/domain/compliance.md` (trilha de auditoria do turno — para diferenciar do audit log de admin)
  - `docs/especificacao/non-functional.md` (LGPD básica, log auditável de admin, classificação de dados sensíveis)
  - `docs/project-state/decisions/pdr/PDR-001-tipos-de-pessoa-aceitos.md` (PF/MEI/PJ, validação manual 24h)
  - `docs/project-state/decisions/pdr/PDR-003-duas-interfaces-webapp-e-backoffice.md` (auth compartilhada, roteamento por papel)
  - `docs/project-state/decisions/adr/ADR-007-auth-base-e-roteamento.md` (Sanctum, coluna `role`/`status`, audit log "detalhado num ADR de persistência do EPIC-001")
  - `docs/project-state/decisions/adr/ADR-002-topologia.md` (domínio compartilhado `packages/domain`)
  - `docs/project-state/decisions/adr/ADR-008-observabilidade-minima.md` (log estruturado — para diferenciar do audit log)
  - `docs/skills/arquiteto/SKILL.md` e `docs/skills/arquiteto/references/architecture-principles.md`

## O quê (objetivo desta estória)

Deliberar e propor **ADR-009 — modelo de dados de identidade do EPIC-001**, em estado `proposed`, cobrindo num único artefato:

1. **Identidade polimórfica do profissional**: como `tipo_pessoa` ∈ {`PF`, `MEI`, `PJ`} convive com `documento` (CPF para PF, CNPJ para MEI/PJ) — uma única tabela com colunas opcionais, herança STI, tabela auxiliar 1-1 ou JSON tipado — sua decisão, justificada.
2. **Estado e funil do usuário**: como representar a sequência `pendente_aprovacao → liberado(welcome=false, cad=false) → liberado(welcome=true, cad=false) → ativo` — máquina de estados explícita, coluna `status` + flags, etc. — sua decisão, justificada.
3. **RBAC com ownership**: além do `role` já fixado em ADR-007, como o domínio garante que um profissional só lê os próprios turnos/candidaturas, um contratante só os do próprio estabelecimento, e admin vê tudo. Padrão de policies, métodos de autorização, ou middleware no router — sua decisão, justificada, **sem entrar em detalhes de telas** (essas chegam nas estórias de implementação).
4. **Audit log de admin**: tabela append-only com `actor_user_id`, `action`, `target_type`, `target_id`, `payload`, `ip`, `user_agent`, `created_at`. Contrato de eventos canônicos (login admin, aprovação de usuário, remoção de usuário, edição de template, ativação de versão de template). Imutabilidade (proibir UPDATE/DELETE — trigger ou só por convenção?). Retenção. Distinção do log estruturado do ADR-008 e da trilha de auditoria do turno (`compliance.md`).

A ADR é aceita por Alexandro antes de qualquer estória de implementação do EPIC-001 abrir.

## Por quê (valor para o usuário)

Esta spike não entrega valor direto a profissional/contratante — entrega valor ao **time**. Sem ADR-009, as estórias STORY-016 a STORY-024 vão decidir cada peça no PR, sem coerência, e o validador do épico (STORY-025) não terá referência arquitetural contra a qual avaliar. Em especial, **RBAC vivo pela primeira vez** (STORY-016) só pode entregar resultado defensável se ownership e funnel guard estiverem fixados aqui — não no calor do código. E o **audit log de admin** é uma exigência de `non-functional.md` que, se for postergada, vira refactor caro: cada ação de admin escrita sem log auditável já é dívida.

## Critérios de aceite

Spike não produz código de produção (ver "Padrões de qualidade exigidos" abaixo); o critério é a **existência e qualidade do artefato ADR** + aderência ao processo arquitetural.

- [ ] **CA-1:** Existe `docs/project-state/decisions/adr/ADR-009-modelo-de-dados-identidade-epic-001.md` em `status: proposed`, escrito conforme `docs/skills/arquiteto/templates/adr.md`, contendo: contexto, forças, opções consideradas (mínimo 2 por dimensão), matriz comparativa quando útil, decisão, justificativa, diagrama, consequências, plano de verificação.
- [ ] **CA-2:** A ADR decide **identidade polimórfica do profissional** com no mínimo 2 opções avaliadas (ex.: tabela única com colunas opcionais; STI/herança; tabela 1-1 auxiliar; JSON tipado) e justifica a escolha à luz de Eloquent (ADR-001), domínio compartilhado em `packages/domain` (ADR-002), volumes do MVP e da promessa de "validação manual em 24h" (PDR-001).
- [ ] **CA-3:** A ADR decide **representação do estado/funil** com no mínimo 2 opções avaliadas (coluna `status` enum + flags booleanas; máquina de estados em código; estados como tabela). Cobre as transições documentadas em `domain/usuario.md` e o ponto crítico de "admin é criado já `ativo`" (ADR-007 §c). Decide se reprovação remove o usuário (default PDR-001) ou marca soft-delete — preserva os limites do MVP.
- [ ] **CA-4:** A ADR decide **ownership** (RBAC vivo): padrão de autorização (policies, gates, escopos de query, escolha do framework do Laravel) e como o domínio compartilhado encapsula a regra "profissional vê só os próprios; contratante vê só os do próprio estabelecimento". O **fail-secure** está descrito: dúvida sobre propriedade → nega. A decisão é compatível com `domain/usuario.md` ("Único usuário por papel + e-mail") e PDR-003 (auth compartilhada, roteamento por papel).
- [ ] **CA-5:** A ADR decide **audit log de admin** como modelo de tabela append-only no Postgres (mesmo banco — ADR-000), com: esquema de colunas, lista canônica de **eventos auditáveis do MVP** (mínimo: `admin.login`, `admin.user.approved`, `admin.user.removed`, `admin.template.version_created`, `admin.template.version_activated`), garantia de **imutabilidade** (sua decisão entre trigger no banco e contrato de aplicação + revoke de UPDATE/DELETE no role de runtime), distinção clara em relação ao log estruturado ADR-008 (este é busca de evidência legal/operacional; aquele é observabilidade do sistema) e da trilha de auditoria do turno (`compliance.md` — esta é por turno, fica para EPIC-003+).
- [ ] **CA-6:** A ADR cita explicitamente: (a) PDRs e ADRs que motivam ou restringem cada decisão (PDR-001, PDR-003, ADR-007); (b) o critério herdado de EPIC-000 sobre `migrate:rollback` em homolog (registrado no `index.json` como `inherited_criteria`) — confirmando que o desenho de tabelas permite rollback reversível na primeira migração com lógica de negócio (STORY-016 ou STORY-017); (c) como a decisão respeita os princípios arquiteturais vigentes (`docs/skills/arquiteto/references/architecture-principles.md`).
- [ ] **CA-7:** A ADR define **dados sensíveis** por campo (mapeando `non-functional.md` §Segurança), declarando o que vai criptografado em repouso (CPF/CNPJ, dados bancários, chave Pix, foto de documento) e o que **não** aparece em log nem em response da API (cruza com ADR-008 §mascaramento). A decisão concreta de mecanismo de criptografia (Eloquent encrypted cast, pgcrypto, KMS, etc.) fica registrada.
- [ ] **CA-8:** `index.json` atualizado com a entrada em `decisions.adr[]` (status `proposed`, path correto, `decided_at` preenchido com a data da proposta, `approved_by` ainda em `null`, `source_story` apontando para STORY-012).
- [ ] **CA-9:** ADR fica em `proposed` até aprovação humana do Alexandro registrada explicitamente (campo `approved_by` + data + forma do aceite). Se Alexandro pedir revisão antes de aprovar, a ADR é editada e mantida em `proposed`; só vai para `accepted` após o "ok" registrado.

## Fora de escopo

- Decidir **modelagem de Template / TemplateVersao / AceiteEletronico** — isso é STORY-013 (ADR-010). Esta ADR pode citar essa fronteira mas não decide.
- Decidir **provedor de e-mail transacional** — isso é STORY-014 (ADR-011).
- Decidir **modelagem do turno, candidatura, vaga** — fora do EPIC-001.
- Decidir **políticas de retenção e direito ao esquecimento (LGPD avançado)** — `non-functional.md` declara "fluxo manual no MVP"; esta ADR registra fronteira mas não desenha o fluxo de exclusão.
- Implementar qualquer linha de código de produção (incluindo migrações). Spike propõe ADR; código vem nas estórias de implementação.
- Escolher bibliotecas específicas dentro do Laravel (ex.: pacote de máquina de estados, pacote de auditoria de terceiros) — decisão local do Programador via IDR quando surgir.

## Padrões de qualidade exigidos

Esta estória é **spike** (`type: spike`, `target_role: arquiteto`). Segue `docs/skills/po/references/quality-standards.md` com as exceções explícitas abaixo (autorizadas em `docs/skills/po/references/story-craft.md` §"Spikes e cobertura de testes"):

- **Cobertura unitária:** N/A — spike não produz código de produção.
- **Testes E2E:** N/A — spike não produz fluxo de usuário.
- **Disciplina aplicável:** rigor argumentativo da ADR (mínimo 2 opções reais por dimensão decidida, trade-offs explícitos, sinais de revisão), aderência ao template do Arquiteto, coerência com PDRs/ADRs vigentes, viabilidade verificada via leitura de docs oficiais. Decisão por palpite, sem ao menos 2 opções avaliadas por dimensão, é motivo de rejeição da ADR.
- **Modelagem obrigatoriamente compatível com**: PostgreSQL (ADR-000), Eloquent (ADR-001), domínio compartilhado em `packages/domain` (ADR-002), Sanctum/Fortify/Argon2id (ADR-007), log JSON estruturado (ADR-008), princípios arquiteturais vigentes.
- **Reversibilidade**: o desenho deve permitir `migrate:rollback` da primeira migração com lógica de negócio em homolog (critério herdado do EPIC-000, F-NB-1) — declare na ADR.

## Dependências

- **Bloqueada por:** nenhuma. Primeira estória do EPIC-001.
- **Bloqueia:** STORY-016 (RBAC vivo precisa do modelo); STORY-017, STORY-018 (pré-cadastros precisam do esquema de `users` polimórfico); STORY-019 (fila de aprovação consome estados e audit log); STORY-023, STORY-024 (completar cadastro consome ownership e dados sensíveis); STORY-025 (validação).
- **Pré-requisitos de ambiente:** nenhum. Spike é deliberação documental.

## Decisões já tomadas (não as reabra)

- **PDR-001** — Profissional pode ser PF, MEI ou PJ; validação manual 24h.
- **PDR-003** — Auth compartilhada entre WebApp e Backoffice; roteamento por papel.
- **ADR-000** — PostgreSQL.
- **ADR-001/002/003** — Laravel/Eloquent, monolito modular com `packages/domain`, monorepo poliglota.
- **ADR-007** — Sanctum SPA no WebApp + guard web no Backoffice; Argon2id; coluna `role`+`status` na tabela `users`; audit log de admin existe e é distinto do log de aplicação. **Esta ADR detalha o que ADR-007 deixou aberto, sem reabrir.**
- **ADR-008** — Log estruturado JSON em stdout, com mascaramento. **Audit log é distinto** — esta ADR fixa essa distinção.
- **Princípio do PO #5** — Estado registrado, sempre. ADR obrigatória.
- **Critério herdado de EPIC-000 (F-NB-1)** — `migrate:rollback` em homolog é critério para a primeira estória com migração de lógica de negócio. Esta ADR não executa, mas precisa permitir.

## Liberdade técnica do agente

Você (agente arquiteto) decide:
- Padrão concreto de polimorfismo do profissional (STI, tabela auxiliar, JSON tipado, coluna `documento` única com `tipo_pessoa` qualificando).
- Representação do funil (enum + flags vs estados próprios vs máquina explícita).
- Padrão de ownership (policies Laravel, gates, escopos de query no domínio compartilhado, middleware no router).
- Esquema concreto do audit log (colunas, tipos, índices, particionamento se aplicável).
- Estratégia de imutabilidade (trigger no banco, REVOKE de DML no role de runtime, contrato de aplicação) — argumente trade-offs.
- Mecanismo concreto de criptografia em repouso para dados sensíveis (Eloquent encrypted cast, pgcrypto, KMS) — argumente.

Você (agente arquiteto) NÃO decide:
- Reabrir PDR-001/PDR-003 ou ADR-007 (`role`/`status` na tabela `users` já decidido).
- Tipo de banco (ADR-000).
- Stack/topologia/repo (ADR-001/002/003).
- Modelo de Template/TemplateVersao/AceiteEletronico (STORY-013).
- Provedor de e-mail (STORY-014).
- Telas de cadastro/aprovação (estórias de implementação 016–024).

Se durante a deliberação você perceber que ADR-007 precisa de superseder/ajuste, **registre em "Notas do agente"** com tag `[ESCALONAMENTO]` e mude `status: blocked`. Não decida sozinho reabrir ADR aceita.

## Definição de Pronto (DoD)

- [ ] Todos os critérios de aceite (CA-1 a CA-9) passam.
- [ ] ADR-009 em `status: proposed` revisada por Alexandro; aprovação humana registrada nos campos próprios (`status: accepted`, `approved_by`, data, forma do aceite).
- [ ] `index.json` atualizado: `decisions.adr[]` recebe ADR-009; status desta estória `done` após aprovação humana.
- [ ] "Notas do agente" preenchida com decisões tomadas, descobertas, trade-offs, bloqueios encontrados.
- [ ] Sem código de produção criado (declarado).

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Resumo:

1. **Ao iniciar:** carregue `docs/skills/arquiteto/SKILL.md`. Edite frontmatter desta estória: `status: in_progress`, `owner_agent`, `updated_at`. Atualize `index.json`.
2. **Durante:** leia os documentos referenciados por inteiro; estruture opções com matriz comparativa quando ajudar; submeta a ADR para revisão humana ao terminar.
3. **Se travar:** `status: blocked`, registre em "Notas".
4. **Decisões locais** sem impacto futuro não viram IDR (você está propondo ADR).
5. **Ao terminar:** preencha "Notas", `status: in_review`; após aprovação humana de Alexandro, `status: done`.

## Notas do agente (preenchido durante/após execução)

### Entrada inicial

Agente: claude-sonnet-4-6-arquiteto-2026-05-28. Lidos antes de deliberar: STORY-012 inteira, domain/usuario.md, domain/compliance.md, non-functional.md, PDR-001, PDR-003, ADR-007, ADR-002, ADR-008, SKILL.md, architecture-principles.md, template ADR. Nenhuma ambiguidade encontrada que exigisse escalamento.

### Decisões tomadas

1. **Polimorfismo do profissional:** Tabelas de perfil 1:1 — `profissional_profiles` e `contratante_profiles` — vinculadas a `users` por `user_id FK`. Eloquent `hasOne`. Admin opera só com `users`.
2. **Funil:** `status` enum (4 valores, ADR-007 preservado) + duas colunas nullable em `users`: `welcome_seen_at TIMESTAMPTZ NULL` e `cadastro_completed_at TIMESTAMPTZ NULL`. Transição `liberado → ativo` é atômica com UPDATE duplo.
3. **RBAC ownership:** Laravel Policies em `packages/domain/src/Policies/` + Eloquent Global Scopes nos models. `Gate::denyIfNobodyPoliciesFor()` para fail-secure. Admin bypassa por papel.
4. **Audit log:** Tabela `admin_audit_log` append-only, trigger `BEFORE UPDATE OR DELETE → RAISE EXCEPTION` + `REVOKE UPDATE DELETE ON admin_audit_log FROM turni_app_runtime`. Dois usuários de banco: `turni_app_migrations` (pleno) e `turni_app_runtime` (sem DML destrutivo em audit_log). 6 eventos canônicos definidos.
5. **Criptografia:** Eloquent Encrypted Cast com chave dedicada em GCP Secret Manager. Campos: `documento`, `chave_pix`, `dados_bancarios_json` em profissional_profiles; `cnpj` em contratante_profiles. Lookup por documento via ORM (hash determinístico para busca registrado como evolução).

### Descobertas

- A distinção entre `admin_audit_log` (evidência legal/operacional) e log estruturado ADR-008 (observabilidade) é explícita e importante: fins, granularidade e armazenamento distintos. Compliance.md cobre a trilha por turno (EPIC-003+) — terceira trilha completamente separada.
- Eloquent Encrypted Cast não permite query SQL direta por valor criptografado. Para o MVP (busca por nome/e-mail, não por CPF), é aceitável. Registrado como evolução potencial.
- `Gate::denyIfNobodyPoliciesFor()` é essencial: sem ele, modelo sem Policy registrada permite ação por default em algumas configurações do Laravel.
- `recusado` como soft-delete lógico (registro permanece para referência no audit_log) é mais seguro que hard-delete imediato para referencial integrity com `admin_audit_log.target_id`.

### Bloqueios encontrados

Nenhum. ADR-007 foi respeitada integralmente; nenhuma necessidade de escalamento.

### ADR proposta

`docs/project-state/decisions/adr/ADR-009-modelo-de-dados-identidade-epic-001.md` — status: `proposed`. Aguarda aprovação de Alexandro.

### Resultado final / evidência

ADR-009 criada em `proposed`. `index.json` atualizado com a entrada. STORY-012 em `in_review` aguardando aprovação humana da ADR. Nenhum código de produção criado.
