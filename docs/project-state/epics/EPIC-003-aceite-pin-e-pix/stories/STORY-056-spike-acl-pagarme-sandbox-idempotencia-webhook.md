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
status: ready
owner_agent: null
created_at: 2026-06-03
updated_at: 2026-06-03
estimated_session_size: L  # gatilho de quebra documentado abaixo
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

- [ ] **CA-1:** ADR-016 escrita seguindo o padrão de ADR-005/ADR-009/ADR-013, status `accepted`, aprovação do Alexandro registrada. Inclui esquema concreto de: nome e operações de `GatewayPagamento`, estrutura do adapter Pagar.me, estrutura do mock em container, tabela de correlação (turno_id ↔ order_id/charge_id), tabela de idempotência (chave + status + payload), endpoint do webhook.
- [ ] **CA-2:** Interface `GatewayPagamento` definida no domínio (`app/Domain/Pagamento/`) com 5 operações: `preAutorizar`, `capturar`, `capturarParcial` (para EPIC-005), `liberar`, `transferirPix`. Vocabulário do domínio Turni — não vaza `order_id`/`charge_id` do Pagar.me.
- [ ] **CA-3:** Adapter Pagar.me implementado contra a interface; usa `Http` do Laravel; segredos do Secret Manager (ADR-004); nunca em código.
- [ ] **CA-4:** Mock em container adicionado ao `docker-compose.yml` (`pagarme-mock`), expondo os mesmos endpoints (pré-auth, capture, Pix, release) que o Pagar.me real. Mock **emite o webhook de volta** para o `api` local quando uma operação completa. Switching via env var `PAGARME_DRIVER=mock|sandbox|live` (default `mock` em local, `sandbox` em homolog, `live` em produção — produção fora do MVP).
- [ ] **CA-5:** Idempotência sobre Postgres: tabela `pagamento_operacoes` com chave composta (turno_id + tipo_operacao), guarda status + payload da requisição + payload da resposta. Repetir a mesma operação com a mesma chave retorna o resultado guardado em vez de chamar o Pagar.me de novo. Teste de "clique duplo no aceite" garante zero duplicação.
- [ ] **CA-6:** Endpoint de webhook entrante `POST /api/webhooks/pagarme` no `api` (Cloud Run público, `southamerica-east1`, ADR-004). Validação de assinatura HMAC do Pagar.me; payload deserializado pela ACL; eventos `pre_autorizacao.criada`, `captura.confirmada`, `pix.enviado`, `pix.falhou`, `pre_autorizacao.liberada` emitidos como eventos de domínio para os listeners da STORY-067 (notificações) e da STORY-065 (captura + Pix).
- [ ] **CA-7:** `make setup` continua funcionando 100% local sem internet (princípio #6 herdado de STORY-006). Mock sobe junto no `docker compose up`. Teste E2E local exercita o ciclo pré-auth → captura → Pix → webhook sem tocar Pagar.me real.
- [ ] **CA-8:** Contract test consumer-driven em job dedicado no CI: roda contra o **sandbox real do Pagar.me** em `cron noturno` (não em PR). Divergência entre mock e sandbox notifica via canal do ADR-008. Job documentado em `infra/` + `runbook-homolog.md`.
- [ ] **CA-9:** Log JSON estruturado em todas as operações da ACL: `request_id` propagado `api`→fila→`worker`; campos `operacao`, `turno_id`, `idempotencia_chave`, `pagarme_id`, `latencia_ms`, `resultado`. Log-based metrics de Cloud Monitoring (ADR-008) definidas para: taxa de erro de operações financeiras (SLO ≤ 1%), latência p95 de captura, latência p95 do webhook.
- [ ] **CA-10:** Cobertura ≥ 98% no núcleo da ACL (idempotência, parsing do webhook, mapeamento de erro); ≥ 80% no adapter Pagar.me.

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
- PDR-004 / PDR-010

## Liberdade técnica do agente

Você decide: nomes das tabelas, estrutura interna do adapter, schema exato do mock, formato do contract test (Pact-like, snapshot, etc).

Você NÃO decide: estratégia de alto nível (vive em ADR-005, não reabrir); decisão de retry de Pix (PDR-010 fixa 1 tentativa).

## Definição de Pronto (DoD)

- [ ] ADR-016 escrita, revisada, `accepted`.
- [ ] `make setup` + ambiente local com mock funcionando sem internet (verificado pelo Alexandro em chat).
- [ ] Job de contract test rodando no CI noturno; primeiro run verde contra sandbox.
- [ ] Webhook validado funcionando em homolog (deploy verificado).
- [ ] Pipeline verde com cobertura exigida.
- [ ] `index.json` atualizado.
- [ ] "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

`docs/skills/po/references/agent-task-format.md`.

## Notas do agente

### Decisões tomadas
- 

### Descobertas
- 

### Bloqueios encontrados
- 

### ADRs/IDRs criados
- ADR-016 — ACL Pagar.me sandbox + idempotência + webhook — `decisions/adr/ADR-016-<slug>.md`

### Cobertura final
- Unitários: <%>
- E2E: <quantos cenários>

### Links de evidência
- PR:
- Pipeline:
- Deploy de homologação:
