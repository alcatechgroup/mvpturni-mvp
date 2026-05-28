---
story_id: STORY-013
slug: spike-template-versao-e-aceite-eletronico
title: Spike Arquiteto — modelo de Template/TemplateVersao e renderização imutável do AceiteEletronico (ADR-010)
epic_id: EPIC-001
sprint_id: SPRINT-2026-W24
type: spike
target_role: arquiteto
requires_design: false
status: done
owner_agent: claude-sonnet-4-6-arquiteto-2026-05-28
created_at: 2026-05-28
updated_at: 2026-05-28
estimated_session_size: S
---

# STORY-013 — Spike Arquiteto: Template/TemplateVersao e AceiteEletronico imutável

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Ela contém tudo o que você precisa. Se algo estiver ambíguo, registre a dúvida na seção "Notas do agente" no final e pause em vez de adivinhar.

## Contexto (por que esta estória existe)

PDR-012 reverteu a abordagem original do EPIC-001 que tinha "spike jurídico" como dependência externa bloqueante. A nova abordagem: **templates contratuais são entidades de dados editáveis pelo admin no backoffice**, com versionamento append-only; cada aceite eletrônico gerado pelo sistema referencia a **versão específica** do template que estava vigente no momento da assinatura, e contratos passados continuam apontando para a versão original mesmo após edições futuras. `domain/compliance.md` §"Estrutura do template no banco" já descreve o desenho conceitual (`Template`, `TemplateVersao`, `AceiteEletronico` com `template_versao_id`, `conteudo_renderizado`, `dados_renderizados`, `timestamp`, `ip`, `fingerprint`). Falta **fixar o modelo de dados e o mecanismo de renderização e imutabilidade em ADR** — sem isso, STORY-020 (editor de templates), STORY-023 e STORY-024 (completar cadastro com aceite) vão decidir o esquema ad-hoc.

A decisão é separada de ADR-009 (modelo de identidade) porque **contratos eletrônicos versionados são um subsistema distinto** — operam sobre identidade, mas têm regras próprias de imutabilidade, retenção e renderização que merecem tratamento independente. Junto seria spike inchada (`story-craft.md` §"Sinais de spike inchada").

- Épico: `docs/project-state/epics/EPIC-001-cadastro-e-aprovacao/epic.md`
- Documentos canônicos a ler ANTES de deliberar:
  - `docs/especificacao/domain/compliance.md` §"Aceite eletrônico por turno" e §"Estrutura do template no banco" e §"Placeholders esperados nos templates" e §"Imutabilidade do aceite"
  - `docs/project-state/decisions/pdr/PDR-012-templates-contratuais-editaveis-no-backoffice.md` (especialmente §"Consequências para o time técnico" e §"Modelo de dados afetado")
  - `docs/project-state/decisions/pdr/PDR-001-tipos-de-pessoa-aceitos.md` (dois templates: PF autônomo eventual e MEI/PJ B2B)
  - `docs/project-state/decisions/adr/ADR-007-auth-base-e-roteamento.md` §e (audit log) — edição de template é evento auditável
  - STORY-012 e ADR-009 (precisa estar aceita ou estado avançado — ownership e audit log são consumidos por esta decisão)
  - `docs/skills/arquiteto/SKILL.md`

## O quê (objetivo desta estória)

Deliberar e propor **ADR-010 — modelo de Template/TemplateVersao e renderização imutável do AceiteEletronico**, em estado `proposed`, cobrindo:

1. **Esquema de `Template`** (catálogo): `slug` (chave estável: `pf_autonomo_eventual`, `mei_pj_b2b`), `nome_amigavel`, metadados.
2. **Esquema de `TemplateVersao`** (versionamento append-only): `template_id`, `versao` sequencial, `conteudo` com placeholders (formato a decidir: Blade-like, Mustache, Markdown puro com substituição simples), `criado_por_admin_id`, `criado_em`, `ativa` (apenas uma versão por template fica ativa).
3. **Esquema de `AceiteEletronico`**: `template_versao_id` (FK), `usuario_id` (ou `turno_id` em uso futuro), `conteudo_renderizado` (string final exibida ao usuário), `dados_renderizados` (JSON estruturado com pares placeholder→valor), `timestamp`, `ip`, `fingerprint`. **Imutável após criação.**
4. **Motor de renderização**: como `{{contratante.razao_social}}`, `{{profissional.documento}}`, `{{turno.valor}}` etc. (lista em `compliance.md` §"Placeholders esperados") são resolvidos a partir do contexto do usuário/turno. Pelo menos 2 opções avaliadas (engine do framework vs interpretador próprio mínimo) com trade-offs explícitos. Comportamento de placeholder ausente (falha dura ou string vazia).
5. **Garantia de imutabilidade do aceite**: mecanismo escolhido (trigger no banco, REVOKE de UPDATE/DELETE no role de runtime, contrato de aplicação) — coerente com a decisão equivalente para audit log em ADR-009 (idealmente mesmo padrão).
6. **Fluxo de "ativação" de uma nova versão**: ao admin marcar uma versão como ativa, a versão anterior fica `ativa=false` mas permanece referenciável; nenhum aceite passado é afetado.

A ADR é aceita por Alexandro antes da STORY-020 (editor) e das STORY-023/024 (que consomem `AceiteEletronico`).

## Por quê (valor para o usuário)

Esta spike entrega valor ao **time** — destrava o editor de templates (STORY-020) e a geração de aceite no completar cadastro (STORY-023, STORY-024). Indiretamente, destrava um valor de produto crítico: **a equipe Turni pode editar o contrato sem release**, conforme PDR-012, e contratos passados permanecem juridicamente imutáveis. Errar este desenho compromete a defensibilidade do aceite eletrônico — o pilar do compliance do MVP segundo `compliance.md`.

## Critérios de aceite

Spike não produz código de produção. Critério é a **existência e qualidade do artefato ADR**.

- [ ] **CA-1:** Existe `docs/project-state/decisions/adr/ADR-010-template-versao-e-aceite-eletronico.md` em `status: proposed`, conforme `docs/skills/arquiteto/templates/adr.md`, com contexto, forças, opções (mínimo 2 por dimensão decidida), decisão, justificativa, diagrama (entidades e relação 1-N entre Template/TemplateVersao/AceiteEletronico), consequências, plano de verificação, sinais de revisão.
- [ ] **CA-2:** A ADR fixa o **esquema de `Template`** (slug único, nome amigável, lista canônica dos dois slugs do MVP: `pf_autonomo_eventual` e `mei_pj_b2b`).
- [ ] **CA-3:** A ADR fixa o **esquema de `TemplateVersao`** com `versao` sequencial por template, garantia de unicidade de versão ativa por template (constraint ou regra de aplicação documentada), referência ao admin que criou e timestamp.
- [ ] **CA-4:** A ADR fixa o **esquema de `AceiteEletronico`** com referência forte a `template_versao_id`, conteúdo renderizado (string), dados renderizados (JSON), timestamp, IP, fingerprint. Imutabilidade garantida por mecanismo concreto (trigger ou REVOKE ou contrato de aplicação + justificativa).
- [ ] **CA-5:** A ADR decide **motor de renderização** com ao menos 2 opções avaliadas (ex.: Blade do Laravel restrito a placeholders simples; substituição própria via regex; engine independente). Justifica a escolha pelo perfil do conteúdo (texto contratual com placeholders bem definidos, **sem lógica condicional complexa exceto** a cláusula de habitualidade override descrita em `compliance.md` §"Placeholders esperados" — `{{habitualidade.override_aceito}}`). Documenta o comportamento de placeholder ausente.
- [ ] **CA-6:** A ADR documenta o **fluxo de ativação** de versão: ao criar nova versão e marcá-la ativa, qual transação acontece (commit atômico que desativa a antiga e ativa a nova; nenhum aceite passado é afetado).
- [ ] **CA-7:** A ADR registra **eventos auditáveis** correspondentes (entram no audit log de ADR-009): `admin.template.version_created`, `admin.template.version_activated`. Documenta que **edição direta de versão já ativa não é permitida** (toda edição é nova versão append-only — coerente com PDR-012).
- [ ] **CA-8:** A ADR cita PDR-012, PDR-001 (dois templates), ADR-007 (auth/admin), ADR-009 (audit log e ownership). Coerência interna verificada.
- [ ] **CA-9:** `index.json` atualizado com a entrada em `decisions.adr[]` para ADR-010 (status `proposed`, path correto, `decided_at` da proposta, `approved_by: null`, `source_story: STORY-013`).
- [ ] **CA-10:** ADR fica em `proposed` até aprovação humana do Alexandro registrada explicitamente.

## Fora de escopo

- Decidir o **texto-seed dos templates** — isso é STORY-015 (responsabilidade do PO).
- Implementar a UI do editor de templates — STORY-020.
- Implementar a geração concreta do aceite em código — STORY-023/024.
- Modelo da trilha de auditoria do **turno** (`compliance.md` §"Trilha de auditoria do turno") — fora do EPIC-001.
- Aceite eletrônico por **turno** (`compliance.md` §"Aceite eletrônico por turno") — fora do EPIC-001; volta no EPIC-003 reutilizando o desenho proposto aqui.
- Assinatura digital qualificada / ICP-Brasil — declarado fora do MVP em epic.md §"Fora de escopo".
- Implementar qualquer linha de código de produção.

## Padrões de qualidade exigidos

Esta estória é **spike**. Segue `docs/skills/po/references/quality-standards.md` com as exceções de "Spikes e cobertura de testes" de `story-craft.md`:

- **Cobertura unitária / E2E:** N/A.
- **Disciplina aplicável:** rigor argumentativo, mínimo 2 opções avaliadas por dimensão, trade-offs explícitos, viabilidade técnica verificada via docs oficiais.
- **Compatível com:** PostgreSQL (ADR-000), Eloquent (ADR-001), domínio compartilhado (ADR-002), Sanctum/admin guard (ADR-007), audit log de ADR-009 (consome).

## Dependências

- **Bloqueada por:** STORY-012 (ADR-009 deve estar ao menos em `in_review` para esta decisão consumir o esquema de ownership e a tabela de audit log). Se ADR-009 estiver `proposed` mas estável, esta spike pode ser iniciada em paralelo no risco de retrabalho mínimo se ADR-009 mudar.
- **Bloqueia:** STORY-020 (editor de templates), STORY-023 (completar cadastro profissional + aceite), STORY-024 (completar cadastro contratante + aceite), STORY-025 (validação).
- **Pré-requisitos de ambiente:** nenhum.

## Decisões já tomadas (não as reabra)

- **PDR-012** — Templates editáveis no backoffice, versionamento append-only, aceite imutável referenciando versão.
- **PDR-001** — Dois templates: PF autônomo eventual e MEI/PJ B2B.
- **`domain/compliance.md`** — desenho conceitual de entidades, placeholders esperados, imutabilidade.
- **ADR-009** (consumida) — ownership, audit log.
- **ADR-007** — auth e admin.
- **Princípio do PO #5** — Estado registrado, sempre.

## Liberdade técnica do agente

Você decide:
- Esquema concreto de colunas/tipos/índices para Template, TemplateVersao, AceiteEletronico.
- Mecanismo de unicidade de versão ativa (constraint parcial, trigger, aplicação).
- Motor de renderização (engine reutilizado vs próprio).
- Mecanismo de imutabilidade (preferencialmente coerente com o escolhido em ADR-009 para audit log).
- Estratégia de fingerprint da sessão (que fonte: user-agent + IP + headers; level de robustez para o MVP).

Você NÃO decide:
- Reabrir PDR-012 (templates são editáveis pelo admin) ou PDR-001 (existem 2 templates no MVP).
- Conteúdo dos templates (STORY-015).
- UI do editor (STORY-020 + Designer).

## Definição de Pronto (DoD)

- [ ] CA-1 a CA-10 passam.
- [ ] ADR-010 em `status: accepted` após aprovação humana de Alexandro.
- [ ] `index.json` atualizado.
- [ ] "Notas do agente" preenchida.
- [ ] Sem código de produção criado.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Resumo:

1. Carregue `docs/skills/arquiteto/SKILL.md`. Frontmatter: `status: in_progress`, `owner_agent`, `updated_at`. Atualize `index.json`.
2. Leia documentos referenciados por inteiro; estruture opções com matriz.
3. Submeta ADR a Alexandro; após aprovação, `status: done`.

## Notas do agente (preenchido durante/após execução)

### Entrada inicial
Lidos: compliance.md (§aceite eletrônico, §estrutura do template, §placeholders, §imutabilidade), PDR-012, PDR-001, ADR-007, ADR-009, SKILL.md do Arquiteto e template de ADR. ADR-009 estava aceita — consumida como base de padrão de imutabilidade e de eventos auditáveis. Sem bloqueios.

### Decisões tomadas
1. **Template (catálogo):** slug VARCHAR UNIQUE; dois registros canônicos `pf_autonomo_eventual` / `mei_pj_b2b`.
2. **TemplateVersao:** partial unique index `(template_id) WHERE ativa = TRUE` para unicidade de versão ativa. Trigger restringe UPDATE ao campo `ativa` — conteúdo é imutável após INSERT.
3. **AceiteEletronico:** trigger BEFORE UPDATE OR DELETE + REVOKE no `turni_app_runtime` (padrão ADR-009). Campo `turno_id` omitido no EPIC-001; adicionado via ALTER TABLE no EPIC-003.
4. **Motor de renderização:** regex própria (`preg_replace_callback`) — simples, zero dependência, falha dura em placeholder ausente. Cláusula de habitualidade resolvida pelo chamador antes da renderização.
5. **Fingerprint:** SHA-256 de `user_agent:ip:date`.

### Descobertas
- `turno_id` em `aceites_eletronicos` deve ser omitido no EPIC-001 (tabela `turnos` não existe ainda) e adicionado via ALTER TABLE no EPIC-003 — mais limpo do que FK nullable para tabela inexistente.
- A função trigger de imutabilidade do `AceiteEletronico` é análoga mas separada da do `admin_audit_log` (ADR-009) — cada tabela tem sua função própria, seguindo o padrão já estabelecido.
- ADR-009 já define `admin.template.version_created` e `admin.template.version_activated` na lista canônica de eventos — esta ADR referencia sem redefinir.

### Bloqueios encontrados
Nenhum.

### ADR proposta
`docs/project-state/decisions/adr/ADR-010-template-versao-e-aceite-eletronico.md` — status: `proposed`. Aguardando aprovação de Alexandro.

### Resultado final / evidência
ADR-010 aceita por Alexandro em chat (2026-05-28). Todos os CAs (CA-1 a CA-10) atendidos. STORY-013 fechada.
