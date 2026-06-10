---
story_id: STORY-093
slug: backend-resolucao-paga-integral-captura-pix
title: Backend — resolução "paga integral" pelo admin (captura via ACL fake + Pix + finalizado + trilha)
epic_id: EPIC-005
sprint_id: SPRINT-2026-W31
type: implementation
target_role: programador
requires_design: false
status: blocked
owner_agent: null
created_at: 2026-06-10
updated_at: 2026-06-10
estimated_session_size: M
---

# STORY-093 — Backend: resolução "paga integral" pelo admin

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Se algo estiver ambíguo, registre em "Notas do agente" e pause.

## Contexto (por que esta estória existe)

Com a abertura da disputa entregue (STORY-092), o turno em `em_disputa` precisa de um desfecho. No MVP, a única resolução é **"pagar integral"**: o admin decide pagar, o sistema executa a **captura padrão + Pix do `valor`** ao profissional (via ACL de pagamento fake — PDR-017), o turno transita para `finalizado` e a trilha de auditoria registra quem decidiu, quando e a nota. As demais resoluções (`paga_parcial`, `sem_pagamento`) são fora do MVP (EPIC-007 da próxima onda).

- Épico: `epics/EPIC-005-disputa-minima/epic.md`
- Decisão que rege esta estória: **ADR-020** (transição `em_disputa → finalizado` + comando de captura do admin).
- Documentos canônicos:
  - `docs/especificacao/domain/disputa.md` (resolução `paga_integral`, `nota_admin`, `resolvida_em`, `resolvida_por`)
  - `docs/especificacao/domain/pagamento.md` (`paga_integral` → captura igual ao fluxo normal; Pix do `valor`)
  - `docs/especificacao/domain/turno.md` (`em_disputa → finalizado`)
  - `docs/project-state/decisions/pdr/PDR-017-...md` + `ADR-016-...md` (ACL + idempotência da captura/Pix)

## O quê (objetivo desta estória)

Expor o comando do admin **"Resolver: pagar integral"** que, para um turno em `em_disputa`: executa captura padrão + Pix do `valor` ao profissional via ACL de pagamento; transita para `finalizado`; persiste `resolucao: paga_integral`, `nota_admin` (opcional), `resolvida_em`, `resolvida_por`; e deixa o turno apto à avaliação recíproca (PDR-005), como qualquer `finalizado`.

## Por quê (valor para o usuário)

É o fim defensável do caminho de exceção: o profissional recebe o que combinou e o contratante tem a decisão registrada. Sem isso, o turno em disputa não fecha e o SLA de 30 min não tem desfecho.

## Critérios de aceite

- [ ] **CA-1:** Dado um turno em `em_disputa`, quando um **admin** executa "pagar integral", então ocorre **captura padrão + Pix do `valor`** ao profissional via ACL de pagamento (fake PDR-017), idêntico ao check-out feliz (`pagamento.md`).
- [ ] **CA-2:** Após a captura, o turno transita para `finalizado` e fica apto à avaliação recíproca (mesmo caminho de um `finalizado` normal — reusa o gate/notificação do EPIC-004, sem regredir).
- [ ] **CA-3:** A disputa registra `resolucao: paga_integral`, `nota_admin` (texto livre opcional), `resolvida_em` (timestamp) e `resolvida_por` (admin) — trilha de auditoria completa (`disputa.md`).
- [ ] **CA-4:** **Idempotência:** reprocessar/reenviar a resolução do mesmo turno **não** captura nem paga em dobro (reusa idempotência da ADR-016). Segunda chamada é no-op ou 409, sem efeito financeiro duplicado.
- [ ] **CA-5:** RBAC: apenas **admin** resolve. Contratante, profissional ou não autenticado recebem 403, fail-secure. Resolver turno que **não** está em `em_disputa` retorna 409/422 sem efeito.
- [ ] **CA-6:** Falha de Pix após captura **não** trava o estado: segue a política de `pagamento.md`/PDR-010 (executa uma vez; falha gera alerta no backoffice, sem retry automático). O turno fica `finalizado` com o pagamento sinalizado para tratamento manual.
- [ ] **CA-7:** Notificação ao profissional na resolução (desfecho da disputa), reusando o padrão de evento da ADR-020/ADR-019, idempotente.

## Fora de escopo

- Resoluções `paga_parcial` e `sem_pagamento` (e estados `finalizado_ajustado` / `disputa_resolvida_sem_pagamento`) — fora do MVP.
- A UI da fila/caso do admin — é a STORY-096 (esta entrega o comando server-side).
- Penalidade automática de score por disputa — fora do MVP.

## Padrões de qualidade exigidos

Segue `quality-standards.md`:

- ≥ 80% no código novo; **≥ 98% no núcleo** (transição de resolução, comando de captura, idempotência financeira, RBAC, trilha de auditoria).
- Teste de API por CA, incluindo idempotência (dupla chamada), RBAC e estado errado.
- TDD; sem código não testado; deploy de homologação verificado.

## Dependências

- **Bloqueada por:** STORY-090 (ADR-020), STORY-092 (turno chega a `em_disputa`)
- **Bloqueia:** STORY-096 (backoffice consome este comando), STORY-097 (validação)
- **Pré-requisitos de ambiente:** ACL de pagamento (fake PDR-017) operante em homologação.

## Decisões já tomadas (não as reabra)

- ADR-020 (comando de captura do admin + transição), ADR-016 (idempotência), PDR-017 (fake), PDR-010 (Pix uma vez, falha → alerta), PDR-004 (modelo financeiro: profissional recebe `valor`).

## Liberdade técnica do agente

Você decide estrutura de código/serviço/testes dentro das ADRs. Não decide critério de aceite nem modelo (ADR-020). Decisão arquitetural não coberta → **pare e escale** ao Arquiteto.

## Definição de Pronto (DoD)

- [ ] CAs passam com testes; coberturas atingidas (núcleo ≥ 98%, ênfase em idempotência financeira).
- [ ] CI verde; deploy homolog verificado.
- [ ] OpenAPI/contrato atualizado; IDR se houver decisão relevante.
- [ ] `index.json`: `status: done`; STORY-096 destravada.
- [ ] "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`.

## Notas do agente (preenchido durante/após execução)

### Decisões tomadas
- <data> — <decisão>

### Descobertas
- <data> — <descoberta>

### IDRs criados
- IDR-XXX — <título>

### Cobertura final
- Unitários: <%> · Núcleo: <%>

### Links de evidência
- PR / Pipeline / Deploy homolog: <urls>
