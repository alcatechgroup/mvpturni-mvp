---
story_id: STORY-058
slug: aceitar-candidatura-backoffice-aceite-eletronico-preauth
title: Aceitar candidatura no Backoffice + AceiteEletronico imutável + pré-autorização Pagar.me
epic_id: EPIC-003
sprint_id: SPRINT-2026-W28
type: implementation
target_role: programador
requires_design: false  # Backoffice; reusa botão/modal do painel de candidatos (STORY-051)
design_screen_id: null
status: ready
owner_agent: null
created_at: 2026-06-03
updated_at: 2026-06-03
estimated_session_size: M
produces_idr: null
---

# STORY-058 — Aceitar candidatura: criar Turno + AceiteEletronico + pré-autorização Pagar.me

## Contexto

EPIC-002 entregou painel de candidatos ranqueados (STORY-051). Esta estória pega o **botão "Aprovar" desse painel** e o transforma na ação que **abre o turno** — cria Turno em `confirmado`, emite AceiteEletronico imutável (com cláusula de override de habitualidade PJ se aplicável), aplica gate PDR-002 (bloqueia 3ª alocação PF; alerta+override 3ª PJ), e dispara pré-autorização Pagar.me sandbox de forma idempotente.

É a **primeira escrita** sobre o modelo da STORY-055 e o **primeiro consumo real** da ACL da STORY-056.

- Épico: `epics/EPIC-003-aceite-pin-e-pix/epic.md`
- Documentos:
  - `docs/especificacao/domain/turno.md` (atributos do turno, transição inicial)
  - `docs/especificacao/domain/compliance.md` (AceiteEletronico do turno, placeholders)
  - `docs/especificacao/domain/pagamento.md` (pré-autorização do total_contratante)
  - PDR-002 (habitualidade PF/PJ), PDR-004 (taxa Turni), PDR-012 (templates editáveis)
  - ADR-006 (consulta de habitualidade), ADR-010 (padrão de imutabilidade), ADR-015 (modelo Turno), ADR-016 (ACL Pagar.me)

## O quê

Implementar a ação de aceitar candidatura no Backoffice de modo que: (a) consulta habitualidade do par profissional×estabelecimento na semana do turno; (b) se PF e 3ª, bloqueia com mensagem clara em ambos os lados; (c) se PJ e 3ª, mostra alerta com botão "Assumo o risco e aceito"; (d) ao aceitar, cria Turno em `confirmado`, gera AceiteEletronico renderizando o `TemplateVersao` ativa (PF ou MEI/PJ), e dispara pré-autorização Pagar.me sandbox via `preAutorizar` da ACL (idempotente — clique duplo não cobra dobrado).

## Por quê

Sem essa ação, o produto não tem Turno. Sem o AceiteEletronico imutável anexado, não há governança jurídica do MVP. Sem habitualidade aplicada no aceite, PDR-002 não está em vigor de verdade.

## Critérios de aceite

- [ ] **CA-1:** Botão "Aprovar" do painel de candidatos (STORY-051) chama endpoint backend `POST /admin/candidaturas/{id}/aprovar` (RBAC admin).
- [ ] **CA-2:** Endpoint executa em transação Postgres: consulta habitualidade (ADR-006), aplica regra PDR-002, e — se aprovado — cria Turno (`status: confirmado`), AceiteEletronico imutável (placeholders renderizados a partir de Turno + Profissional + Contratante + flag `habitualidade.override_aceito`), e dispara `preAutorizar` da ACL Pagar.me com chave de idempotência `aceite:{candidatura_id}`.
- [ ] **CA-3:** Habitualidade — PF 3ª: endpoint retorna 422 com mensagem "este profissional é PF e já tem 2 alocações nesta semana neste estabelecimento; bloqueado por PDR-002"; UI mostra modal específico. Profissional vê mesma razão em "Minhas candidaturas".
- [ ] **CA-4:** Habitualidade — PJ 3ª: UI mostra modal "este profissional já tem 2 alocações nesta semana; clique 'Assumo o risco e aceito' para continuar (registrado no AceiteEletronico)". O clique chama endpoint com `override: true`; AceiteEletronico carimba `habitualidade_override: true` e renderiza cláusula adicional (PDR-002).
- [ ] **CA-5:** Idempotência — duas requisições de aprovação para a mesma candidatura geram **um único** Turno + AceiteEletronico + pré-autorização. Teste cobre clique duplo no botão e double-submit do formulário.
- [ ] **CA-6:** Pré-autorização Pagar.me dispara via worker (assíncrona — ADR-002) com idempotência da STORY-056. Sucesso emite evento de domínio `PagamentoPreAutorizado` → audit log captura; falha emite `PagamentoPreAutorizacaoFalhou` → admin vê na fila.
- [ ] **CA-7:** Audit log captura `turno.criado`, `aceite_eletronico.emitido`, `pagamento.pre_autorizado` (ou `.pre_autorizacao_falhou`) — imutável por trigger Postgres herdado.
- [ ] **CA-8:** Template-seed v1 dos 2 templates de turno (PF + MEI/PJ) — espelha texto já em `docs/especificacao/contratos/template-pf-autonomo-eventual-v1.md` e `template-mei-pj-b2b-v1.md`; SHA-256 do conteúdo registrado. PO entrega + valida em chat antes de a estória fechar.
- [ ] **CA-9:** E2E cobre os 4 cenários PDR-002: PF 1ª/2ª libera (turno criado); PF 3ª bloqueia (sem turno); PJ 3ª com override cria turno com cláusula; transição de semana reseta.
- [ ] **CA-10:** Cobertura ≥ 98% no núcleo (regra PDR-002, idempotência, emissão de AceiteEletronico); ≥ 80% no resto.

## Fora de escopo

- UI de listagem dos turnos criados (STORY-059).
- UI de detalhe do turno (STORY-060).
- Qualquer ação sobre o turno depois do `confirmado` (estórias seguintes).
- Tratamento de falha permanente de pré-autorização — registra erro, alerta admin, mas não tenta retry automático.

## Padrões de qualidade

≥ 80% / ≥ 98% no núcleo. E2E backend (cobre os 4 cenários PDR-002) e admin (via `integration_test` mesma origem se aplicável, ou via Playwright smoke do build deployado).

## Dependências

- **Bloqueada por:** STORY-055 (modelo Turno), STORY-056 (ACL Pagar.me + idempotência). PDR-002 já implementado em EPIC-002 — apenas adapta para o aceite do turno.
- **Bloqueia:** STORY-059, STORY-060, STORY-066, STORY-067.
- **Pré-requisitos:** Pagar.me sandbox credentials no Secret Manager (Alexandro).

## Decisões já tomadas

- ADR-006, ADR-010, ADR-015, ADR-016, **ADR-018 (UUIDv7 em PKs — Turno + AceiteEletronicoTurno + pagamento_operacoes têm `id` uuid; FKs `foreignUuid`; idempotência usa UUID do turno; URLs/rotas RESTful aceitam UUIDs)** — PDR-002, PDR-004, PDR-010, PDR-012.

## Liberdade técnica

Decide: estrutura interna do controller/service, formato exato dos modais de bloqueio/alerta no admin (reusa padrão do painel da STORY-051).

NÃO decide: regra de habitualidade (PDR-002); valor da taxa Turni (PDR-004 = 15%).

## Definição de Pronto

- [ ] CAs marcados, todos os testes verdes, cobertura exigida.
- [ ] Deploy em homolog verificado por Alexandro (botão "Aprovar" cria turno + pré-autorização visível no painel sandbox Pagar.me).
- [ ] Templates carregados como `TemplateVersao` ativa (categoria `contrato_turno`).
- [ ] `index.json` atualizado.
- [ ] "Notas do agente" preenchida.

## Protocolo

`docs/skills/po/references/agent-task-format.md`.

## Notas do agente

### Decisões tomadas
### Descobertas
### Bloqueios encontrados
### IDRs criados
### Cobertura final
- Unitários: <%>
- E2E: 
### Links de evidência
- PR:
- Pipeline:
- Deploy de homologação:
