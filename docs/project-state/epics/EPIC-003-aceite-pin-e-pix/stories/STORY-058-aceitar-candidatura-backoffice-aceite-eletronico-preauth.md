---
story_id: STORY-058
slug: aceitar-candidatura-backoffice-aceite-eletronico-preauth
title: Aceitar candidatura no Backoffice + AceiteEletronico imutável + pré-autorização via gateway (fake genérico — PDR-017)
epic_id: EPIC-003
sprint_id: SPRINT-2026-W28
type: implementation
target_role: programador
requires_design: true  # 2026-06-04 (PO em chat): aprovação é do CONTRATANTE no WebApp; designer especifica os modais (bloqueio PF / override PJ / confirmação)
design_screen_id: SCREEN-STORY-058-aprovar-candidatura
status: in_progress
owner_agent: claude-opus-4-8
created_at: 2026-06-03
updated_at: 2026-06-04
estimated_session_size: M
produces_idr: null
---

# STORY-058 — Aceitar candidatura: criar Turno + AceiteEletronico + pré-autorização via gateway

> **Nota PDR-017 (2026-06-04):** "pré-autorização" continua sendo o conceito do domínio; o que muda é que o gateway implementador é o **fake genérico** (STORY-056), não o Pagar.me real. O contrato da ACL (`preAutorizar`) e o comportamento esperado (idempotência, emissão de evento `PagamentoPreAutorizado`, audit log) são os mesmos. Quando Pagar.me real entrar na próxima wave, esta estória **não precisa ser tocada** — só o adapter muda.

## Contexto

EPIC-002 entregou painel de candidatos ranqueados (STORY-051). Esta estória pega o **botão "Aprovar" desse painel** e o transforma na ação que **abre o turno** — cria Turno em `confirmado`, emite AceiteEletronico imutável (com cláusula de override de habitualidade PJ se aplicável), aplica gate PDR-002 (bloqueia 3ª alocação PF; alerta+override 3ª PJ), e dispara pré-autorização via `preAutorizar` da ACL de pagamento (STORY-056) de forma idempotente.

É a **primeira escrita** sobre o modelo da STORY-055 e o **primeiro consumo real** da ACL da STORY-056.

- Épico: `epics/EPIC-003-aceite-pin-e-pix/epic.md`
- Documentos:
  - `docs/especificacao/domain/turno.md` (atributos do turno, transição inicial)
  - `docs/especificacao/domain/compliance.md` (AceiteEletronico do turno, placeholders)
  - `docs/especificacao/domain/pagamento.md` (pré-autorização do total_contratante)
  - PDR-002 (habitualidade PF/PJ), PDR-004 (taxa Turni), PDR-012 (templates editáveis), **PDR-017 (pagamento via fake genérico no MVP)**
  - ADR-006 (consulta de habitualidade), ADR-010 (padrão de imutabilidade), ADR-015 (modelo Turno), ADR-016 (ACL de pagamento — revisada pós-PDR-017)

## O quê

Implementar a ação de aceitar candidatura no Backoffice de modo que: (a) consulta habitualidade do par profissional×estabelecimento na semana do turno; (b) se PF e 3ª, bloqueia com mensagem clara em ambos os lados; (c) se PJ e 3ª, mostra alerta com botão "Assumo o risco e aceito"; (d) ao aceitar, cria Turno em `confirmado`, gera AceiteEletronico renderizando o `TemplateVersao` ativa (PF ou MEI/PJ), e dispara `preAutorizar` da ACL (fake genérico — PDR-017) com idempotência (clique duplo não cobra dobrado).

## Por quê

Sem essa ação, o produto não tem Turno. Sem o AceiteEletronico imutável anexado, não há governança jurídica do MVP. Sem habitualidade aplicada no aceite, PDR-002 não está em vigor de verdade.

## Critérios de aceite

- [ ] **CA-1:** Botão "Aceitar candidatura" do painel de candidatos (STORY-051, WebApp do contratante) chama endpoint backend `POST /api/candidaturas/{id}/aprovar` (RBAC **contratante dono da vaga**; não-dono/profissional → 403). *(Corrigido em 2026-06-04 por decisão do PO em chat: o título original dizia "Backoffice"/RBAC admin, mas épico + `domain/candidatura.md` §"Aprovação pelo contratante" fixam que quem aprova é o contratante no WebApp.)*
- [ ] **CA-2:** Endpoint executa em transação Postgres: consulta habitualidade (ADR-006), aplica regra PDR-002, e — se aprovado — cria Turno (`status: confirmado`), AceiteEletronico imutável (placeholders renderizados a partir de Turno + Profissional + Contratante + flag `habitualidade.override_aceito`), e dispara `preAutorizar` da ACL de pagamento (fake — PDR-017) com chave de idempotência `aceite:{candidatura_id}`.
- [ ] **CA-3:** Habitualidade — PF 3ª: endpoint retorna 422 com mensagem "este profissional é PF e já tem 2 alocações nesta semana neste estabelecimento; bloqueado por PDR-002"; UI mostra modal específico. ~~Profissional vê mesma razão em "Minhas candidaturas"~~ *(ajustado 2026-06-04 por decisão do PO em chat: a tela "Minhas candidaturas" não existe no MVP; o lado do profissional entra com as listas da STORY-059/060).*
- [ ] **CA-4:** Habitualidade — PJ 3ª: UI mostra modal "este profissional já tem 2 alocações nesta semana; clique 'Assumo o risco e aceito' para continuar (registrado no AceiteEletronico)". O clique chama endpoint com `override: true`; AceiteEletronico carimba `habitualidade_override: true` e renderiza cláusula adicional (PDR-002).
- [ ] **CA-5:** Idempotência — duas requisições de aprovação para a mesma candidatura geram **um único** Turno + AceiteEletronico + pré-autorização. Teste cobre clique duplo no botão e double-submit do formulário.
- [ ] **CA-6:** Pré-autorização dispara via worker (assíncrona — ADR-002) com idempotência da STORY-056. Sucesso emite evento de domínio `PagamentoPreAutorizado` → audit log captura; falha emite `PagamentoPreAutorizacaoFalhou` → admin vê na fila. **Fake genérico (PDR-017) responde com sucesso por padrão; falha pode ser simulada por configuração do fake para testar o caminho de exceção.**
- [ ] **CA-7:** Audit log captura `turno.criado`, `aceite_eletronico.emitido`, `pagamento.pre_autorizado` (ou `.pre_autorizacao_falhou`) — imutável por trigger Postgres herdado.
- [ ] **CA-8:** Template-seed v1 dos 2 templates de turno (PF + MEI/PJ) — espelha texto já em `docs/especificacao/contratos/template-pf-autonomo-eventual-v1.md` e `template-mei-pj-b2b-v1.md`; SHA-256 do conteúdo registrado. PO entrega + valida em chat antes de a estória fechar. *(Ajustado 2026-06-04 por decisão do PO em chat: os 2 templates JÁ existem como `TemplateVersao` v1 ativa desde a STORY-020 — categoria `contrato`, SHA-256 logado no seed. O aceite por turno REUSA esses templates (Seção 1+2); não há seed novo nem categoria `contrato_turno`. O CA vira: validar fidelidade da v1 ativa aos docs canônicos.)*
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

- **Bloqueada por:** STORY-055 (modelo Turno), STORY-056 (ACL de pagamento + fake + idempotência). PDR-002 já implementado em EPIC-002 — apenas adapta para o aceite do turno.
- **Bloqueia:** STORY-059, STORY-060, STORY-066, STORY-067.
- **Pré-requisitos:** ~~Pagar.me sandbox credentials no Secret Manager~~ **REMOVIDO por PDR-017** — fake genérico não precisa de credenciais externas.

## Decisões já tomadas

- ADR-006, ADR-010, ADR-015, ADR-016, **ADR-018 (UUIDv7 em PKs — Turno + AceiteEletronicoTurno + pagamento_operacoes têm `id` uuid; FKs `foreignUuid`; idempotência usa UUID do turno; URLs/rotas RESTful aceitam UUIDs)** — PDR-002, PDR-004, PDR-010, PDR-012.

## Liberdade técnica

Decide: estrutura interna do controller/service, formato exato dos modais de bloqueio/alerta no admin (reusa padrão do painel da STORY-051).

NÃO decide: regra de habitualidade (PDR-002); valor da taxa Turni (PDR-004 = 15%).

## Definição de Pronto

- [ ] CAs marcados, todos os testes verdes, cobertura exigida.
- [ ] Deploy em homolog verificado por Alexandro (botão "Aprovar" cria turno + pré-autorização registrada em `pagamento_operacoes` com status `concluida` + audit log `pagamento.pre_autorizado` + evento `PagamentoPreAutorizado` emitido — verificável via GET na fila do admin ou inspeção direta do Postgres).
- [ ] Templates carregados como `TemplateVersao` ativa (categoria `contrato_turno`).
- [ ] `index.json` atualizado.
- [ ] "Notas do agente" preenchida.

## Protocolo

`docs/skills/po/references/agent-task-format.md`.

## Notas do agente

### Entrada inicial (2026-06-04 — disciplina de leitura)

**Documentos lidos:** estória inteira; ADR-006/015/016/018; PDR-002/004/012/017; `domain/turno.md` (via ADR-015), `domain/compliance.md` §aceite por turno, `domain/pagamento.md`, `domain/candidatura.md` §aprovação; STORY-051 (estória + SCREEN-051 + código); código existente: `GateHabitualidade`, `CriarCandidaturaService`, `GatewayPagamento`/`OperacaoIdempotente`/`PagarmeGateway`, `Turno`/`TurnoStatus`/`AceiteEletronicoTurno`/`Template`/`TemplateVersao`, `AceiteAdesaoRenderer`, `AuditLog`, `TemplatesContratuaisSeeder`, `painel_candidatos_screen.dart`.

**Entendimento consolidado:** o botão "Aceitar candidatura" do painel do contratante (STORY-051) vira a ação que abre o turno. Endpoint `POST /api/candidaturas/{id}/aprovar` (RBAC contratante dono) roda em transação: consulta habitualidade **sobre `turnos`** (índice de ADR-006/015), aplica PDR-002 (PF 3ª → 422; PJ 3ª → exige `override: true`), cria Turno `confirmado` (financeiro congelado: `valor` da vaga, `taxa_turni` = 15% PDR-004, `total = valor + taxa`), transita candidatura → `aprovada`, preenche posição da vaga (fecha ao preencher a última — domain/vaga.md), emite `AceiteEletronicoTurno` imutável (renderiza TemplateVersao ativa PF ou MEI/PJ, Seção 1+2, cláusula 10 condicional ao override), grava audit logs, e **após o commit** despacha job assíncrono (fila database/ADR-002) que chama `preAutorizar` via `OperacaoIdempotente`.

**Dúvidas escaladas e respondidas pelo PO em chat (2026-06-04):**
1. Quem aprova: **contratante no WebApp** (CA-1 corrigido — o "Backoffice"/RBAC admin do texto original contradizia épico + domain spec).
2. CA-3 lado do profissional: **adiado para STORY-059/060** (tela "Minhas candidaturas" não existe).
3. CA-8: **reusa** os templates seedados na STORY-020 (categoria `contrato`); sem categoria `contrato_turno` nova.

**Plano (resumo):**
1. Designer: SCREEN-STORY-058 (modais de confirmação/bloqueio PF/override PJ + estados) + protótipo HTML, reusando padrão do painel 051.
2. Backend TDD (red→green por CA): service `AprovarCandidaturaService` + `GateHabitualidadeAceite` (sobre turnos) + `AceiteTurnoRenderer` + job `PreAutorizarTurnoJob` + eventos `PagamentoPreAutorizado`/`PagamentoPreAutorizacaoFalhou`.
3. WebApp: habilitar botão, modais conforme spec, service de aprovação.
4. E2E backend (4 cenários PDR-002) + `integration_test` same-origin (IDR-021, gate local IDR-004).

**Mapeamento CA → testes planejados (antes de codar):**
- CA-1 → `AprovarCandidaturaTest`: dono 200/cria turno; não-dono 403; profissional 403; 401; candidatura inexistente 404. (a/b)
- CA-2 → `AprovarCandidaturaTest`: transação cria Turno+Aceite+job em um commit; rollback se aceite falha (ex.: template sem versão ativa → 500 sem turno órfão). (a/c)
- CA-3 → `HabitualidadeAceiteTest`: PF 3ª → 422 com mensagem PDR-002, sem turno; PF 1ª/2ª libera. (b)
- CA-4 → PJ 3ª sem `override` → 422 com `requer_override`; com `override: true` → turno criado + `habitualidade_override: true` no aceite + cláusula 10 renderizada. (a/b)
- CA-5 → clique duplo/double-submit: 2ª chamada não duplica (409/200 idempotente; um único turno/aceite/pré-auth — UNIQUE candidatura_id + UNIQUE (turno_id,tipo)). (d)
- CA-6 → `PreAutorizarTurnoJobTest`: sucesso emite `PagamentoPreAutorizado` + audit; falha fatal emite `PagamentoPreAutorizacaoFalhou` + audit + operação `falhou`; `GatewayIndisponivel` → retry do job. (a/c)
- CA-7 → audit `turno.criado`, `aceite_eletronico.emitido`, `pagamento.pre_autorizado`/`.pre_autorizacao_falhou`. (a)
- CA-8 → teste de fidelidade: SHA-256 da v1 ativa == SHA-256 do doc canônico (PF e MEI/PJ). (a)
- CA-9 → E2E backend 4 cenários (PF 1ª/2ª, PF 3ª, PJ 3ª override, virada de semana) + `integration_test` da aprovação no painel. (a/b/d)
- CA-10 → cobertura ≥98% núcleo (gate, renderer, idempotência) / ≥80% resto.
- Bordas extras: renderização com placeholder ausente falha duro (sem aceite incompleto); vaga fechada/cancelada → 422; candidatura `retirada` → 422; última posição fecha a vaga.

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
