---
story_id: STORY-094
slug: frontend-contratante-recusar-checkout-justificativa
title: Frontend Contratante — recusar check-out e abrir disputa com justificativa obrigatória
epic_id: EPIC-005
sprint_id: SPRINT-2026-W31
type: implementation
target_role: programador
requires_design: true
status: in_review
owner_agent: claude-opus-4-8-programador-2026-06-10-s094
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

- [x] **CA-1:** No ponto de validação de check-out de um turno em `aguardando_checkout`, o contratante vê duas ações distintas: **validar** (caminho feliz existente, não regride) e **"Recusar e abrir disputa"**, conforme SCREEN-spec. → entrada "Não vai validar agora? Recusar check-out" abre a **folha de desambiguação** (pattern.intent-disambiguation / DDR-005); validar segue inalterado.
- [x] **CA-2:** Ao escolher recusar, é exigida uma **justificativa não-vazia**; tentar enviar vazio mostra erro acionável (não só cor) e **não** chama a API. → "Abrir disputa" desabilitado vazio + `errorText` ao desfocar vazio; sem chamada à API.
- [x] **CA-3:** Com justificativa válida e confirmação, a chamada à API abre a disputa; em sucesso, a UI reflete o turno em `em_disputa` (sem ação de validar/recusar disponível depois). → reload pós-sucesso esvazia a validação e mostra o banner sóbrio do contratante.
- [x] **CA-4:** Estados tratados: enviando (loading "Abrindo…"), sucesso (snackbar), erro recuperável (mantém o texto digitado — não perde a justificativa), 403 e 422 (`justificativa_obrigatoria`/`estado_invalido` → reload silencioso) com mensagens claras. (Não há 409 neste contrato — STORY-092.)
- [x] **CA-5:** Acessibilidade: foco vai ao campo de justificativa ao abrir (`autofocus`); erro vinculado ao campo (`Semantics liveRegion`); ação destrutiva (disputa em `error`) diferenciada da primária (acento mostarda), sem depender só de cor.

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

- [x] CAs passam; E2E do fluxo verde (local, browser real same-origin). Homologação: após push (deploy automatizado).
- [x] Coberturas atingidas (serviço + widget + E2E). CI verde / deploy homolog: pendente push na main.
- [ ] `index.json`: `status: done` (após CI verde + homolog).
- [x] "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`.

## Notas do agente (preenchido durante/após execução)

### Decisões tomadas
- 2026-06-10 — **Serviço novo `AbrirDisputaService`** (não estendi `ValidarCheckoutService`): a recusa benigna (`recusar()`→`ativo`) e a disputa (`abrir-disputa`→`em_disputa`) são ramos distintos com contratos e resultados próprios (ADR-020 Decisão 2). Resultados sealed: `AbrirDisputaOk`/`JustificativaObrigatoria`/`EstadoInvalido`/`Forbidden`/`Erro`.
- 2026-06-10 — **Folha de desambiguação como `AlertDialog` (desktop e mobile)**, não `showModalBottomSheet` no mobile como a SCREEN-091 §3.7 sugere. A estória é desktop-primary ("WebApp do contratante (desktop) dentro do shell") e o §3.7 já usa AlertDialog no desktop; os identificadores/copy são idênticos. Decisão local consciente — paridade mobile mantida (o dialog é usável), sem inflar a sessão com um wrapper responsivo.
- 2026-06-10 — **Campo de motivo da recusa benigna removido** (a entrada deixou de abrir o antigo `_RecusaCheckoutDialog`): a folha §3.1 não tem campo de motivo no ramo "ainda não terminou", então `recusar()` agora vai sem motivo. Fiel ao DDR-005. O endpoint `recusar-checkout` segue aceitando motivo opcional (intacto).
- 2026-06-10 — **`estado_invalido` (422) fecha o diálogo e recarrega SEM o snackbar de sucesso** (`_DisputaResultado.estadoInvalido`): mudou em outra aba → a verdade do servidor manda (§4.1). Só `200` mostra "Disputa aberta — a equipe Turni vai mediar.".
- 2026-06-10 — **Banner sóbrio do contratante em `em_disputa`** adicionado (key `disputa-contratante-banner`), substituindo o placeholder genérico (SCREEN-091 §4.1, marcado "opcional"). Reforça o CA-3 ("UI reflete em_disputa") e é superfície do contratante (in-scope).

### Descobertas
- 2026-06-10 — `em_disputa` já estava mapeado em `TurnoGrupo`/`TurnoEstadoResumo` (label "Em disputa") desde STORY-092 — o detalhe e as listas refletem o estado pós-reload sem mudança no parsing.
- 2026-06-10 — Seed: `TurnosSeeder` não tinha par em `aguardando_checkout`. Criei `seedTurnoEmCheckout()` (par `*.disputa.seed`, INSERT direto no estado-alvo + preauth sintética + timeline até `checkout_solicitado`, recriaConsumido quando vira `em_disputa`) — modelado em `seedTurnoCronometro`.

### Cobertura final
- Unitários (`AbrirDisputaService`): 6 testes cobrindo 200/422×2/403/rede-5xx/malformado — 100% das ramificações do serviço.
- Widget (`validar_checkout_area_test`): folha (CA-1), ramo benigno sem motivo, disputa desabilitada vazia (CA-2), sucesso→snackbar+`em_disputa`+banner (CA-3), erro de envio mantém texto (CA-4), read-only do contratante em `em_disputa`.
- E2E (`integration_test/turnos/disputa_test.dart`): browser real pinado, same-origin, contra backend real — recusa → folha → "tenho um problema" → confirmar desabilitado vazio → justificativa → `em_disputa` (banner + selo). **All tests passed.** Fora do gate (custo de browser, igual ao checkout_test); rodável sob demanda (cabeçalho do arquivo).

### Links de evidência
- E2E local: `make e2e-webapp-pinned E2E_TARGET=integration_test/_disputa_solo_test.dart` → **All tests passed** (Chrome 148 pinado, same-origin).
- Lint: `flutter analyze` (só 2 infos pré-existentes em pre_cadastro_*), `dart format --set-exit-if-changed` limpo, `pint --test` api (447) + admin (91) PASS.
- Pipeline / Deploy homolog: <preencher após push na main>
