---
story_id: STORY-056
slug: spike-acl-pagarme-sandbox-idempotencia-webhook
title: Spike Arquiteto — ACL Pagar.me + adapter sandbox/mock em container + idempotência + webhook
epic_id: EPIC-003
sprint_id: SPRINT-2026-W28
type: spike
target_role: arquiteto
requires_design: false
design_screen_id: null
status: in_review
owner_agent: claude-opus-4-8-arquiteto-2026-06-04
created_at: 2026-06-03
updated_at: 2026-06-04
estimated_session_size: L  # QUEBRADA em 2026-06-04: este arquivo = STORY-056-A (CA-1..7, 9-10, tamanho M); CA-8 → STORY-056-B (contract test no CI noturno, tamanho S). Ver "Gatilho de quebra" + SPRINT-2026-W28 §"Mudanças no escopo".
produces_idr: null  # produz ADR-016 (detalha ADR-005)
---

# STORY-056 — Spike Arquiteto: ACL Pagar.me + mock + idempotência + webhook

> **Para o agente arquiteto:** esta é a estória **L** desta sprint — risco técnico nº 1 da WAVE-2026-01. Leia ADR-005 inteira antes de propor a implementação concreta — esta estória **não reabre** a decisão de alto nível (ACL + mock em container + contract test contra sandbox no CI noturno + idempotência por chave + webhook validado), mas a **detalha**. Se durante a execução perceber que o escopo não cabe em uma sessão, **pare e escale ao PO** com a proposta de quebra (adapter+mock em uma; contract test+webhook em outra) — esse caminho é exceção válida e está documentado nos riscos do sprint.

## Contexto (por que esta estória existe)

ADR-005 fixou a estratégia de alto nível: ACL no módulo Pagamento, mock em container, idempotência, webhook validado. Esta estória entrega a **implementação concreta** dessa estratégia em código + IaC + CI: a interface `GatewayPagamento`, o adapter Pagar.me real, o mock em container no `docker-compose`, o esquema de idempotência (chave + tabela), o endpoint de webhook entrante validado, e o contract test consumer-driven contra o sandbox real no CI noturno.

Sem esta estória, STORY-058 (pré-autorização no aceite), STORY-065 (captura + Pix) e STORY-066 (liberação da pré-autorização no cancelamento) não conseguem testar nem rodar localmente.

- Épico: `epics/EPIC-003-aceite-pin-e-pix/epic.md`
- Documentos canônicos a ler ANTES de codificar:
  - `decisions/adr/ADR-005-integracao-pagarme.md` (estratégia de alto nível — não reabrir)
  - `docs/especificacao/domain/pagamento.md` (ciclo: pré-autorização → captura → Pix; variações)
  - `decisions/pdr/PDR-004-modelo-financeiro-taxa-do-contratante.md`
  - `decisions/pdr/PDR-010-refresh-pix-fora-de-escopo-mvp.md` (1 tentativa, alerta admin em falha)
  - `decisions/adr/ADR-002-topologia.md` (worker assíncrono + webhook no api)
  - `decisions/adr/ADR-008-observabilidade-minima.md` (log JSON + métricas que esta ADR alimenta)

## O quê (objetivo desta estória)

Propor **ADR-016** (implementação concreta da ACL Pagar.me) e entregar o código + IaC + CI correspondente, com o ambiente local subindo em 1 comando contra o mock e o CI noturno rodando o contract test contra o sandbox real.

## Por quê (valor para o usuário)

Sem ACL bem desenhada, o domínio do Turni vira refém do Pagar.me (princípio #5/#6 da arquitetura). Sem mock em container, dev local quebra sem internet (princípio #6). Sem idempotência, clique duplo no aceite cobra dobrado (PDR-004). Sem webhook validado, captura/Pix viram caixa preta. Esta estória ataca o risco técnico nº 1 da onda.

## Critérios de aceite

> **Quebra (2026-06-04):** este arquivo é **STORY-056-A**. CA-1..7, 9-10 entregues aqui;
> **CA-8** (contract test no CI noturno contra o sandbox real) movido para **STORY-056-B**
> (`ready`, bloqueada por credenciais sandbox que Alexandro provê). Ver SPRINT-2026-W28
> §"Mudanças no escopo". ADR-016 está `proposed` — vira `accepted` na aprovação do Alexandro.

- [x] **CA-1:** ADR-016 escrita seguindo o padrão de ADR-005/ADR-009/ADR-013 (status `proposed`, aguardando aprovação do Alexandro p/ `accepted` — o Arquiteto não marca `accepted` sozinho). Inclui esquema concreto de: operações de `GatewayPagamento`, estrutura do adapter, mock em container, correlação (desnormalizada em `pagamento_operacoes`, Decisão 1A), idempotência (chave + status + payload), endpoint do webhook.
- [x] **CA-2:** Interface `GatewayPagamento` em `app/Domain/Pagamento/GatewayPagamento.php` com 5 operações: `preAutorizar`, `capturar`, `capturarParcial`, `liberar`, `transferirPix`. Vocabulário Turni; retorno `ResultadoOperacao` com ids opacos — não vaza `order_id`/`charge_id`.
- [x] **CA-3:** Adapter `PagarmeGateway` (`app/Domain/Pagamento/Pagarme/`) contra a interface; usa `Http` do Laravel; segredos via `config('services.pagarme')`/env/Secret Manager (ADR-004), nunca em código.
- [x] **CA-4:** Mock funcional no `pagarme-mock` (orders/capture/cancel/transfers) **emitindo o webhook assinado de volta** ao `api` (verificado em container real). Seleção por `PAGARME_DRIVER=mock|sandbox|live` via `config/services.php` (um adapter, sem ramificação por driver — Decisão 2A).
- [x] **CA-5:** Idempotência sobre Postgres: `pagamento_operacoes` (`id` UUIDv7, `turno_id` foreignUuid), índice único `(turno_id, tipo_operacao)`, guarda status + request/response payload. Curto-circuito em `concluida`; teste de "clique-duplo" garante 1 chamada ao provedor. `external_reference` carrega o UUID do turno (string) — ida verificada; volta verificada via contract test em **STORY-056-B**.
- [x] **CA-6:** `POST /api/webhooks/pagarme` no `api` (público, fora de auth). HMAC validado (401 se inválido); dedup por `event_id` (200 sem reprocessar); 5 eventos de domínio (`PreAutorizacaoCriada`, `CapturaConfirmada`, `PixEnviado`, `PixFalhou`, `PreAutorizacaoLiberada`) para STORY-065/067.
- [x] **CA-7:** Mock sobe no `docker compose up`; E2E local (`CicloPagamentoLocalTest`) exercita pré-auth → captura → Pix → webhook com `Http::preventStrayRequests` (0 rede). *DoD §`make setup` sem internet: verificação manual final pelo Alexandro.*
- [ ] **CA-8:** → **STORY-056-B** (contract test consumer-driven no CI noturno contra o sandbox real + alerta de divergência). Bloqueada por credenciais sandbox.
- [x] **CA-9:** Log JSON (`PagamentoEvents`) por operação: `event`, `operacao`, `turno_id`, `idempotencia_chave`, `pagarme_id`, `latencia_ms`, `resultado`; `request_id` propagado pelo mecanismo do ADR-008. Chave Pix **nunca** logada (verificado em teste). Log-based metrics (erro ≤ 1%, p95 captura, p95 webhook) definidas em `docs/operacao/` para o Terraform da STORY-007 wirar.
- [x] **CA-10:** Cobertura do núcleo (idempotência, parsing/validação de webhook, mapeamento de erro) = **100%**; adapter `PagarmeGateway` = **100%** (≥ 98% / ≥ 80% exigidos). 50 testes do módulo; suíte `api` 648 verdes.

## Fora de escopo

- Implementação concreta do aceite (STORY-058) — só interface + ACL + mock.
- Implementação concreta da captura + Pix (STORY-065) — só ACL.
- Tratamento de captura parcial (PDR-006 — para EPIC-005).
- UI de fila de Pix com falha no admin — fica em STORY-065.

## Gatilho de quebra (estória L)

Se durante a execução o agente sentir que o escopo não cabe em uma sessão única, **parar e escalar ao PO** com a seguinte proposta de quebra:

- **STORY-056-A** — Interface + adapter Pagar.me + mock em container + idempotência + webhook (CA-1..7, 9-10). Tamanho M.
- **STORY-056-B** — Contract test consumer-driven no CI noturno + alerta de divergência (CA-8). Tamanho S.

Quebra documentada via "Mudanças no escopo do sprint" no `SPRINT-2026-W28.md`. **Não inflar** a sessão tentando entregar tudo de uma vez.

## Padrões de qualidade exigidos

`docs/skills/po/references/quality-standards.md`. ≥ 80% geral, ≥ 98% no núcleo (idempotência, parsing de webhook, mapeamento de operações). Teste E2E local cobrindo o ciclo completo contra o mock. Job de contract test contra sandbox no CI noturno.

## Dependências

- **Bloqueada por:** nenhuma (consome estado herdado de EPIC-000/EPIC-001).
- **Bloqueia:** STORY-058 (precisa de `preAutorizar`), STORY-065 (precisa de `capturar` + `transferirPix` + webhook), STORY-066 (precisa de `liberar`).
- **Pré-requisitos de ambiente:** Secret Manager configurado com credenciais Pagar.me sandbox (Alexandro provê), `docker-compose` operante (herdado de STORY-006).

## Decisões já tomadas (não as reabra)

- ADR-005 — Pagar.me alto nível (esta estória detalha em ADR-016)
- ADR-002 — Worker assíncrono + webhook no api
- ADR-004 — GCP + Secret Manager + IaC Terraform
- ADR-008 — Log JSON + log-based metrics
- **ADR-018 — UUIDv7 em PKs (aplicado em EPIC-010/W27.5). `external_reference` Pagar.me carrega UUID string; tabela de correlação e tabela de idempotência têm `id` UUIDv7 e FKs `foreignUuid`. Janela cirúrgica para virar o tipo se fecha NESTE commit — feita antes para evitar limpar sandbox + reemitir webhooks depois.**
- PDR-004 / PDR-010

## Liberdade técnica do agente

Você decide: nomes das tabelas, estrutura interna do adapter, schema exato do mock, formato do contract test (Pact-like, snapshot, etc).

Você NÃO decide: estratégia de alto nível (vive em ADR-005, não reabrir); decisão de retry de Pix (PDR-010 fixa 1 tentativa).

## Definição de Pronto (DoD)

> DoD desta estória (056-A). Itens de CI noturno/sandbox migraram para STORY-056-B.

- [x] ADR-016 escrita e revisada — `proposed` (vira `accepted` na aprovação do Alexandro; o Arquiteto não marca `accepted` sozinho).
- [~] `make setup` + ambiente local com mock sem internet: **mock + webhook verificados em container real** (POST /orders → webhook assinado → api valida HMAC → worker processa). *Falta a verificação manual final do `make setup` ponta-a-ponta pelo Alexandro em chat.*
- [ ] Job de contract test rodando no CI noturno; primeiro run verde contra sandbox → **STORY-056-B** (bloqueada por credenciais).
- [ ] Webhook validado funcionando em homolog (deploy verificado) → após merge + deploy rc.N (mesmo gate de STORY-055).
- [x] Suíte `api` verde com cobertura exigida (648 testes; núcleo 100%, adapter 100%; gate `--min=80` EXIT=0).
- [x] `index.json` atualizado.
- [x] "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

`docs/skills/po/references/agent-task-format.md`.

## Notas do agente

### Decisões tomadas
- **Quebra da estória L** (gatilho da própria estória): 056-A (CA-1..7, 9-10, esta) + 056-B (CA-8). Decisão do PO em chat (2026-06-04); credenciais sandbox ainda não disponíveis. Registrada em SPRINT-2026-W28 §"Mudanças no escopo".
- **Decisão 1A (ADR-016): uma tabela `pagamento_operacoes`** (log + idempotência + correlação desnormalizada) em vez de duas — relação ~1:1 com os ids do provedor, ≤ 5 operações/turno; CA-1/CA-5 atendidos numa tabela só (princípio #1). Índice único `(turno_id, tipo_operacao)` = barreira de não-duplicação.
- **Decisão 2A: um único adapter `PagarmeGateway`**; driver (`mock|sandbox|live`) só troca `base_url`+credencial em config — sem ramificação de código, o que mantém o contract test (056-B) guardando o caminho real.
- **Decisão 3A: erro por exceção de domínio tipada** (espelha o idioma dos outros módulos do `api`); `mapearErro()` testável (5xx/rede → `GatewayIndisponivel` recuperável; 4xx → fatal por operação).
- **Refinamento sobre a ADR-005:** interface recebe `string $turnoId` + valores primitivos (não o modelo Eloquent `Turno`) — não acopla a ACL à persistência e mantém o núcleo testável sem banco. Valores como **string decimal** (coerente com `decimal:2` do Turno); adapter converte p/ centavos por parsing de string (sem bcmath — ausente na imagem — e sem float).

### Descobertas
- **`api` em `php artisan serve` é single-thread** → o mock devolvendo o webhook enquanto o `api` aguarda a resposta da operação (re-entrância) daria **deadlock**. Resolvido com `PHP_CLI_SERVER_WORKERS=8` no serviço `api` do `docker-compose` (mesmo padrão já usado no `webapp`).
- **`bcmath` não está na imagem PHP** → conversão para centavos feita por parsing de string ("123.45" → 12345), sem float nem bcmath.
- O `pagarme-mock` já existia "de pé" desde STORY-006; esta estória implementou as rotas funcionais + emissão do webhook assinado (HMAC compartilhado).
- O `worker` de longa duração precisa de `restart` para autoload de classes de Job novas (gotcha de dev — não afeta homolog, onde o worker sobe por deploy).

### Bloqueios encontrados
- **CA-8 / DoD do contract test:** credenciais Pagar.me sandbox no Secret Manager ainda não disponíveis (Alexandro provê). Movido para STORY-056-B; não bloqueia 056-A.

### ADRs/IDRs criados
- **ADR-016** — Implementação concreta da ACL Pagar.me — `decisions/adr/ADR-016-acl-pagarme-sandbox-idempotencia-webhook.md` (`proposed`).
- Contrato versionado: `docs/project-state/integrations/pagarme/contract.md`.

### Cobertura final
- Núcleo (OperacaoIdempotente, PagarmeWebhookValidator, mapearErro) e adapter `PagarmeGateway`: **100%** (exigido ≥ 98% núcleo / ≥ 80% adapter). Suíte `api`: **648** verdes, gate `--min=80` EXIT=0.
- Cenários do módulo: **50** testes (validador HMAC/parsing puro; idempotência/clique-duplo; adapter Http::fake + mapa de erro; webhook endpoint 401/422/200/dup; job mapeamento+idempotência; schema/constraints; **E2E local do ciclo completo sem internet** com asserção de não-vazamento da chave Pix).

### Links de evidência
- Commit(s): na `main` (workflow Turni — sem PR).
- Suíte verde: `make test-api` (648 testes, cobertura ≥ 80%; núcleo + adapter 100%).
- Smoke em container real: `POST localhost:8090/orders` → webhook `charge.pending` assinado → `webhook_eventos_pagarme.processado_em` preenchido pelo worker.

### Links de evidência
- PR:
- Pipeline:
- Deploy de homologação:
