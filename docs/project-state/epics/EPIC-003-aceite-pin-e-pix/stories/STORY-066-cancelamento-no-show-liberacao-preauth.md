---
story_id: STORY-066
slug: cancelamento-no-show-liberacao-preauth
title: Cancelamento antes do check-in + `no_show_pro` + liberação da pré-autorização
epic_id: EPIC-003
sprint_id: SPRINT-2026-W28
type: implementation
target_role: programador
requires_design: true
design_screen_id: SCREEN-STORY-066-cancelamento
status: ready
owner_agent: null
created_at: 2026-06-03
updated_at: 2026-06-03
estimated_session_size: M
produces_idr: null
---

# STORY-066 — Cancelamento + `no_show_pro` + liberação da pré-autorização

## Contexto

Caminho de exceção do caminho feliz. PDR-007 permite cancelamento **antes** do check-in (estados `confirmado` para `cancelado_pro` ou `cancelado_emp`) sem motor de penalidade no MVP. `no_show_pro` é a transição automática quando profissional não faz check-in até X horas após o início previsto (definição numérica de X resolvida pelo spike STORY-055 ou aqui — registrar como descoberta).

Esta estória é **ortogonal ao caminho feliz** — pode iniciar a partir de quando STORY-058 fechar.

- Épico: `epics/EPIC-003-aceite-pin-e-pix/epic.md`
- Documentos: `domain/turno.md` (transições `confirmado → cancelado_*` e `confirmado/aguardando_checkin → no_show_pro`), `domain/pagamento.md` (liberação), PDR-007.

## O quê

Botão "Cancelar turno" no detalhe do turno (STORY-060) para profissional e contratante quando estado é `confirmado`. Modal de confirmação com textarea opcional de motivo. Sucesso: transita para `cancelado_pro` ou `cancelado_emp` conforme o lado, grava `cancelamento: { lado, motivo, antecedencia_horas, em }`, dispara `liberar` via ACL Pagar.me. Cron job (reusa worker da STORY-034 — `everyMinute`) detecta turnos `confirmado` ou `aguardando_checkin` cujo `data_inicio + X horas < now()` e transita para `no_show_pro`, também liberando a pré-autorização.

## Por quê

Sem cancelamento, contratante e profissional ficam presos com pré-autorização ativa no Pagar.me consumindo limite. Sem `no_show_pro`, turno em que profissional sumiu fica em `confirmado` para sempre, distorcendo métricas e poluindo listas.

## Critérios de aceite

- [ ] **CA-1:** Botão "Cancelar turno" no detalhe quando estado é `confirmado`. Modal de confirmação com mensagem clara ("Cancelar este turno libera a pré-autorização Pagar.me e notifica o outro lado") + textarea opcional de motivo.
- [ ] **CA-2:** `POST /api/turnos/{id}/cancelar` recebe `{ motivo?: string }`, valida estado `confirmado` (outros 422), transita para `cancelado_pro` ou `cancelado_emp` conforme RBAC, grava `cancelamento`, dispara `liberar(turno_id)` via ACL com idempotência `liberar:{turno_id}`.
- [ ] **CA-3:** Sucesso da liberação: audit log `pagamento.liberado`; emissão de evento `TurnoCancelado` (consumido por STORY-067 notificação).
- [ ] **CA-4:** Falha da liberação: audit log `pagamento.liberacao_falhou` com motivo; alerta destacado na fila operacional do admin (mesma fila da STORY-065).
- [ ] **CA-5:** Cron job `turnos:detectar-no-show` em `everyMinute` (reusa worker da STORY-034) detecta turnos cujo `data_inicio + X horas < now() AND status IN ('confirmado', 'aguardando_checkin')` e os transita para `no_show_pro`. Decisão do **X**: documentar no IDR ou na própria estória (sugestão inicial PO: **2h** — discutir com Alexandro em chat antes de codificar). Notifica ambos os lados (STORY-067).
- [ ] **CA-6:** `no_show_pro` libera pré-autorização igual cancelamento (audit log `pagamento.liberado` com `motivo: 'no_show'`).
- [ ] **CA-7:** Telas (STORY-059 lista, STORY-060 detalhe) mostram turnos terminais (`cancelado_*`, `no_show_pro`) com badge visual e timeline completa.
- [ ] **CA-8:** Cobertura ≥ 98% no núcleo (regra de cancelamento, regra de no-show, idempotência da liberação); ≥ 80% no resto. E2E cobre cancelamento dos 2 lados + no-show por travel-time-jump.

## Fora de escopo

- Motor de penalidade (PDR-007 — placeholder no modelo; cálculo pós-MVP).
- Cancelamento depois de `ativo` (não permitido — `domain/turno.md`).
- UI de "Por que cancelei" → vai para wishlist se aparecer demanda.

## Padrões de qualidade

≥ 80% / ≥ 98% no núcleo. E2E cobre cancelamento + no-show. Cron exercitado em CI via `travel(Xh + 1m)`.

## Dependências

- **Bloqueada por:** STORY-058 (modelo + turnos em `confirmado`), STORY-056 (ACL `liberar`), STORY-060 (detalhe é onde o botão fica).
- **Bloqueia:** nenhuma direta; STORY-068 verifica que os caminhos terminais aparecem.
- **Pré-requisitos:** SCREEN-STORY-066 entregue (modal + estado terminal).

## Decisões já tomadas

ADR-015 / ADR-016 / **ADR-018 (UUIDv7 em PKs — URL `/turnos/{uuid}/cancelar` aceita UUID; chave de idempotência da liberação usa UUID; evento `TurnoCancelado`/`TurnoNoShow` carrega `turno_id` UUID string)**, PDR-007.

## Liberdade técnica

Decide: estrutura interna do listener de cron, formato da nota de motivo, microcopy do modal.

NÃO decide: motor de penalidade (PDR-007 — fora MVP); que cancelamento depois de `ativo` não é permitido (`domain/turno.md`).

## Definição de Pronto

- [ ] CAs marcados; deploy verificado.
- [ ] SCREEN-STORY-066 `shipped`.
- [ ] Alexandro decide X de no-show em chat antes do código fechar.
- [ ] Alexandro testa em homolog (cancelamento + no-show forçado via travel).
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
- Unitários:
- E2E:
### Links de evidência
- PR:
- Pipeline:
- Deploy de homologação:
