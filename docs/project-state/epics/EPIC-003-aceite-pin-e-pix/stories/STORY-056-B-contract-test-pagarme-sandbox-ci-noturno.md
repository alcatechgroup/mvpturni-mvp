---
story_id: STORY-056-B
slug: contract-test-pagarme-sandbox-ci-noturno
title: Contract test consumer-driven Pagar.me sandbox no CI noturno + alerta de divergência
epic_id: EPIC-003
sprint_id: SPRINT-2026-W28
type: spike
target_role: arquiteto
requires_design: false
design_screen_id: null
status: ready
owner_agent: null
created_at: 2026-06-04
updated_at: 2026-06-04
estimated_session_size: S
produces_idr: null  # opera sob ADR-016 (já decide o desenho do contract test)
blocked_by: [STORY-056]  # consome a ACL + o contrato versionado da 056-A
---

# STORY-056-B — Contract test Pagar.me sandbox no CI noturno

> **Origem:** quebra da estória L **STORY-056** em 2026-06-04 (gatilho documentado na própria
> estória + SPRINT-2026-W28 §"Mudanças no escopo"). A STORY-056-A entregou a ACL inteira
> (interface, adapter, mock, idempotência, webhook, observabilidade) e o **desenho** do contract
> test em ADR-016 §h. Esta estória **implementa** esse desenho. **Não reabre** o desenho.

## Contexto

A ADR-016 (§h) fixou: o contrato esperado está versionado em
`docs/project-state/integrations/pagarme/contract.md`; o contract test consumer-driven roda
contra o **sandbox real do Pagar.me** num job de **cron noturno** do GitHub Actions (fora do
caminho de PR — princípio #6, não depende de internet no push); divergência mock↔sandbox
notifica Alexandro pelo **canal do ADR-008**. Como há um único adapter (`PagarmeGateway`,
Decisão 2A da ADR-016) que fala com mock e sandbox pela mesma config, o contract test exercita
exatamente o caminho de produção — só trocando `PAGARME_DRIVER=sandbox` + credenciais.

- Documentos a ler ANTES: `decisions/adr/ADR-016-acl-pagarme-sandbox-idempotencia-webhook.md`
  (§h e §plano de verificação), `docs/project-state/integrations/pagarme/contract.md`,
  `.github/workflows/scheduled-setup-test.yml` (padrão de job agendado já existente),
  `decisions/adr/ADR-008-observabilidade-minima.md` (canal de alerta).

## Critérios de aceite

- [ ] **CA-1 (era CA-8 da 056):** Contract test consumer-driven em job dedicado no CI, rodando
  contra o **sandbox real do Pagar.me** em `cron noturno` (não em PR). Verifica que cada operação
  do `contract.md` (pré-auth/captura/captura parcial/liberação/Pix) e o formato do webhook batem
  com o sandbox. Divergência mock↔sandbox **falha o job** e **notifica** pelo canal do ADR-008.
- [ ] **CA-2:** Credenciais sandbox via Secret Manager/GitHub Secrets (WIF — ADR-004), nunca no
  código. Documentado em `infra/` + `docs/operacao/runbook-homolog.md` (como rotacionar, como
  reagir à divergência: atualizar `contract.md` + mock na estória que toca o contrato).
- [ ] **CA-3:** Primeiro run verde contra o sandbox registrado como evidência.

## Pré-requisitos de ambiente

- **Credenciais Pagar.me sandbox** no Secret Manager/GitHub Secrets — **Alexandro provê** (bloqueio
  atual da estória).

## Fora de escopo

- Tudo o que a STORY-056-A já entregou (ACL, adapter, mock, idempotência, webhook, observabilidade).
- Mudança de qualquer decisão da ADR-016.

## Definição de Pronto (DoD)

- [ ] Job de contract test no CI noturno; primeiro run verde contra sandbox.
- [ ] Alerta de divergência wirado no canal do ADR-008.
- [ ] Runbook atualizado.
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
- Aguardando credenciais Pagar.me sandbox (Alexandro).
