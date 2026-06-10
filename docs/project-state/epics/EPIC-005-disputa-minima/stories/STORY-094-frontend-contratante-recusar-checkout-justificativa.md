---
story_id: STORY-094
slug: frontend-contratante-recusar-checkout-justificativa
title: Frontend Contratante — recusar check-out e abrir disputa com justificativa obrigatória
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

# STORY-094 — Frontend Contratante: recusar check-out e abrir disputa

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Implemente as telas conforme a SCREEN-spec aprovada da STORY-091. Se algo estiver ambíguo, registre em "Notas do agente" e pause.

## Contexto (por que esta estória existe)

No fluxo de validação de check-out, o contratante hoje só pode validar (caminho feliz). Esta estória adiciona a ação **"Recusar e abrir disputa"** com campo de justificativa obrigatório, consumindo a API de abertura entregue na STORY-092 e seguindo o design da STORY-091. É a porta de entrada do caminho de exceção pelo lado do contratante.

- Épico: `epics/EPIC-005-disputa-minima/epic.md`
- Design: SCREEN-spec da STORY-091 + DDR-005 (aprovados pelo dono).
- API: endpoint de abertura de disputa (STORY-092) — contrato em OpenAPI atualizado.
- Specs: `docs/especificacao/domain/disputa.md` (justificativa obrigatória), `domain/turno.md` (estado `em_disputa`).

## O quê (objetivo desta estória)

Entregar, no WebApp do contratante (desktop) dentro do shell, a ação "Recusar e abrir disputa" no ponto de validação de check-out: campo de justificativa obrigatório, confirmação explícita, chamada à API e transição visível do turno para `em_disputa`.

## Por quê (valor para o usuário)

Dá ao contratante um caminho legítimo e claro para contestar um check-out — sem improviso e sem deixar o turno preso. A justificativa obrigatória reduz disputas abertas por engano.

## Critérios de aceite

- [ ] **CA-1:** No ponto de validação de check-out de um turno em `aguardando_checkout`, o contratante vê duas ações distintas: **validar** (caminho feliz existente, não regride) e **"Recusar e abrir disputa"**, conforme SCREEN-spec.
- [ ] **CA-2:** Ao escolher recusar, é exigida uma **justificativa não-vazia**; tentar enviar vazio mostra erro acionável (não só cor) e **não** chama a API.
- [ ] **CA-3:** Com justificativa válida e confirmação, a chamada à API abre a disputa; em sucesso, a UI reflete o turno em `em_disputa` (sem ação de validar/recusar disponível depois).
- [ ] **CA-4:** Estados tratados: enviando (loading), sucesso, erro recuperável (mantém o texto digitado — não perde a justificativa), 403/409/422 com mensagens claras por caso (ex.: turno já não está em `aguardando_checkout`).
- [ ] **CA-5:** Acessibilidade: foco vai ao campo de justificativa ao abrir; erro associado ao campo; ação destrutiva ("recusar") visualmente diferenciada da primária ("validar"), sem depender só de cor.

## Fora de escopo

- Lado servidor (STORY-092). Banner do profissional (STORY-095). Backoffice (STORY-096).
- Edição/cancelamento da disputa pelo contratante após aberta (não existe no MVP).

## Padrões de qualidade exigidos

Segue `quality-standards.md`:

- ≥ 80% no código novo de frontend.
- **E2E** cobrindo o fluxo no browser (web): contratante recusa → digita justificativa → turno em `em_disputa`, incluindo o caso de justificativa vazia bloqueada. Same-origin, no padrão dos E2E do EPIC-003/004.
- Sem código não testado; deploy homolog verificado.

## Dependências

- **Bloqueada por:** STORY-091 (design aprovado), STORY-092 (API de abertura)
- **Bloqueia:** STORY-097 (validação)
- **Pré-requisitos de ambiente:** homologação operante; seed de turno em `aguardando_checkout`.

## Decisões já tomadas (não as reabra)

- DDR-005 (telas/copy), ADR-020 (contrato de abertura), DDR-001/002/003 (DS, pt-BR/24h, shell), PDR-006.

## Liberdade técnica do agente

Você decide estrutura de componentes/serviços/testes de FE dentro do DS e do shell. Não decide telas (DDR-005) nem contrato de API (ADR-020/OpenAPI). Divergência entre design e API → **pare e registre**.

## Definição de Pronto (DoD)

- [ ] CAs passam; E2E do fluxo verde em homologação.
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
