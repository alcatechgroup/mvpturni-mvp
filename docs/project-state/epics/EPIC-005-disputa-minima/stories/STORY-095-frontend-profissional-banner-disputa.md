---
story_id: STORY-095
slug: frontend-profissional-banner-disputa
title: Frontend Profissional — banner de disputa no detalhe do turno + estado em_disputa nas listas
epic_id: EPIC-005
sprint_id: SPRINT-2026-W31
type: implementation
target_role: programador
requires_design: true
status: blocked
owner_agent: null
created_at: 2026-06-10
updated_at: 2026-06-10
estimated_session_size: S
---

# STORY-095 — Frontend Profissional: banner de disputa

> **Para o agente que vai executar:** estória **pequena (S)**, display-only. Leia-a por inteiro; implemente conforme a SCREEN-spec aprovada da STORY-091. Se algo estiver ambíguo, registre em "Notas do agente" e pause.

## Contexto (por que esta estória existe)

No MVP, o profissional **não age** na disputa — apenas é informado (`disputa.md`). A notificação (in-app + e-mail) já é disparada pelo backend (STORY-092). Falta a parte visual persistente: um **banner** no detalhe do turno em `em_disputa` ("valor em disputa — equipe Turni vai mediar em até 30 min") e a marcação do estado nas listas de turnos. É read-only e reusa a infraestrutura de notificação/estado já existente.

- Épico: `epics/EPIC-005-disputa-minima/epic.md`
- Design: SCREEN-spec da STORY-091 + DDR-005.
- Specs: `docs/especificacao/domain/disputa.md` (profissional só visualiza), `domain/turno.md` (estado `em_disputa`).

## O quê (objetivo desta estória)

Exibir, no WebApp do profissional (mobile) dentro do shell, o banner de disputa no detalhe do turno em `em_disputa` e o estado `em_disputa` na lista "Meus turnos", sem nenhuma ação disponível ao profissional.

## Por quê (valor para o usuário)

Tranquiliza o profissional num momento de tensão (pagamento retido): mostra que há um processo e um prazo, em vez de um turno que simplesmente "não pagou".

## Critérios de aceite

- [ ] **CA-1:** Dado um turno em `em_disputa`, quando o profissional abre o detalhe, então vê o banner com a copy aprovada (DDR-005) sobre disputa + mediação em até 30 min, sem botões de ação.
- [ ] **CA-2:** Na lista "Meus turnos", o turno em `em_disputa` aparece com o rótulo/estado correto (distinto de `finalizado`/`ativo`), conforme SCREEN-spec.
- [ ] **CA-3:** Quando a disputa é resolvida (`finalizado`), o banner some e o turno passa a exibir o estado normal (apto à avaliação) — sem resíduo visual de disputa no caminho feliz pós-resolução.
- [ ] **CA-4:** Acessibilidade: o banner é anunciável por leitor de tela e não comunica o estado só por cor.

## Fora de escopo

- Qualquer ação do profissional sobre a disputa (recurso, contato) — fora do MVP.
- Disparo de notificação/e-mail (já é da STORY-092).
- Telas de contratante/admin (094/096).

## Padrões de qualidade exigidos

Segue `quality-standards.md`:

- ≥ 80% no código novo.
- Testes de widget cobrindo: banner presente em `em_disputa`, ausente em outros estados, rótulo correto na lista. E2E não é obrigatório por ser display-only, mas o estado `em_disputa` deve aparecer num cenário existente se já houver seed.
- Sem código não testado; deploy homolog verificado.

## Dependências

- **Bloqueada por:** STORY-091 (design aprovado), STORY-092 (turno chega a `em_disputa` + contrato de leitura)
- **Bloqueia:** STORY-097 (validação)
- **Pré-requisitos de ambiente:** homologação operante.

## Decisões já tomadas (não as reabra)

- DDR-005 (banner/copy), ADR-020, DDR-001/002/003, PDR-006 (profissional só é notificado).

## Liberdade técnica do agente

Você decide estrutura de componentes/testes de FE dentro do DS e do shell. Não decide copy (DDR-005) nem contrato (API). Divergência → **pare e registre**.

## Definição de Pronto (DoD)

- [ ] CAs passam com testes de widget; CI verde; deploy homolog verificado.
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
- Unitários/widget: <%>

### Links de evidência
- PR / Pipeline / Deploy homolog: <urls>
