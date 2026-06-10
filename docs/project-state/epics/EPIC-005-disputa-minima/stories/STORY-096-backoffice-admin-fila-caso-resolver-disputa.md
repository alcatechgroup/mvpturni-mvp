---
story_id: STORY-096
slug: backoffice-admin-fila-caso-resolver-disputa
title: Backoffice Admin — fila de disputas + caso com trilha completa + resolver "pagar integral"
epic_id: EPIC-005
sprint_id: SPRINT-2026-W31
type: implementation
target_role: programador
requires_design: true
status: blocked
owner_agent: null
created_at: 2026-06-10
updated_at: 2026-06-10
estimated_session_size: M
---

# STORY-096 — Backoffice Admin: fila + caso + resolver disputa

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Implemente conforme a SCREEN-spec aprovada da STORY-091 e o comando server-side da STORY-093. Se algo estiver ambíguo, registre em "Notas do agente" e pause.

## Contexto (por que esta estória existe)

A disputa só fecha quando a equipe Turni a resolve. Esta estória entrega a ferramenta do admin no backoffice (`admin.homolog.turni.com.br`): a **fila de disputas**, a **tela do caso** com toda a trilha de auditoria para decidir, e a ação **"Resolver: pagar integral"** que dispara o comando da STORY-093. É a peça que torna o SLA de 30 min operável.

- Épico: `epics/EPIC-005-disputa-minima/epic.md`
- Design: SCREEN-spec da STORY-091 + DDR-005.
- API: comando de resolução (STORY-093) + consulta de pendência/trilha (STORY-092/093, ADR-020).
- Specs: `docs/especificacao/domain/disputa.md` (fluxo do admin, trilha, `nota_admin`), `non-functional.md` (SLA 30 min).

## O quê (objetivo desta estória)

Entregar, no app `admin`, a rota `/disputas` com a fila de turnos em `em_disputa` e a tela de caso (trilha completa: chat, geofencing, checklist, cronômetro, justificativa do contratante, vaga original) + ação "Resolver: pagar integral" com confirmação e `nota_admin` opcional.

## Por quê (valor para o usuário)

Sem a ferramenta, o admin não tem como mediar — o caminho de exceção fica sem desfecho. A trilha legível é o que permite resolver com contexto e dentro do prazo público.

## Critérios de aceite

- [ ] **CA-1:** Em `/disputas`, o admin vê a **fila** de turnos em `em_disputa` (consumindo a pendência derivada do estado — ADR-020), com contratante, profissional, valor e **tempo decorrido vs SLA 30 min**, ordenada por mais antigo primeiro.
- [ ] **CA-2:** Ao abrir um caso, o admin vê a **trilha completa**: chat, geofencing (check-in/out), checklist, cronômetro, `justificativa_contratante`, vaga original e dados de ambos os lados, conforme `disputa.md` e a fronteira de dados da ADR-020.
- [ ] **CA-3:** A ação **"Resolver: pagar integral"** abre um diálogo de confirmação com campo `nota_admin` opcional; ao confirmar, chama o comando da STORY-093 e, em sucesso, o caso sai da fila e o turno aparece como `finalizado`.
- [ ] **CA-4:** Estados tratados: lista vazia ("nenhuma disputa aberta"), loading, erro de carga, erro/sucesso da resolução, e o caso de resolução concorrente (turno já resolvido por outro admin → 409 com mensagem clara, sem efeito duplicado).
- [ ] **CA-5:** RBAC: somente perfil **admin** acessa `/disputas` e resolve; outros papéis recebem bloqueio (sem vazar dados de disputa). Fail-secure.
- [ ] **CA-6:** Acessibilidade AA no nível das telas do backoffice já vigente (foco, rótulos, contraste; estado não só por cor).

## Fora de escopo

- O comando de captura/Pix em si (STORY-093 — esta estória só o aciona).
- Resoluções `paga_parcial`/`sem_pagamento` na UI (fora do MVP — não renderizar essas opções).
- UI rica de mediação (chat dedicado admin↔partes) — fora do MVP.
- Penalidade manual de score via backoffice — evolução pós-MVP.

## Padrões de qualidade exigidos

Segue `quality-standards.md`:

- ≥ 80% no código novo do backoffice.
- **E2E** cobrindo o fluxo do admin: abrir `/disputas` → abrir caso → resolver "pagar integral" → caso sai da fila / turno `finalizado`. No padrão dos E2E vigentes.
- Sem código não testado; deploy homolog verificado.

## Dependências

- **Bloqueada por:** STORY-091 (design aprovado) e STORY-093 (comando de resolução); herda STORY-092 transitivamente via 093 (estado/consulta de disputa)
- **Bloqueia:** STORY-097 (validação)
- **Pré-requisitos de ambiente:** `admin.homolog.turni.com.br` operante; seed de turno em `em_disputa`.

## Decisões já tomadas (não as reabra)

- DDR-005 (telas do admin), ADR-020 (consulta/trilha + comando), PDR-006 (disputa via admin), PDR-003 (backoffice mínimo), `non-functional.md` (SLA 30 min).

## Liberdade técnica do agente

Você decide estrutura de componentes/serviços/testes do backoffice dentro do DS. Não decide telas (DDR-005) nem contrato (ADR-020/OpenAPI). Divergência design↔API → **pare e registre**.

## Definição de Pronto (DoD)

- [ ] CAs passam; E2E do fluxo do admin verde em homologação.
- [ ] Coberturas atingidas; CI verde; deploy homolog verificado.
- [ ] `index.json`: `status: done`.
- [ ] "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`.

## Notas do agente (preenchido durante/após execução)

### Decisões tomadas
- <data> — <decisão>

### Descobertas
- <data> — <descoberta>

### Cobertura final
- Unitários: <%> · E2E: <cenários>

### Links de evidência
- PR / Pipeline / Deploy homolog: <urls>
