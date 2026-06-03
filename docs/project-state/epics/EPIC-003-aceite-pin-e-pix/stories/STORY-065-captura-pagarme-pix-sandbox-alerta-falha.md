---
story_id: STORY-065
slug: captura-pagarme-pix-sandbox-alerta-falha
title: Captura Pagar.me + Pix sandbox + alerta admin em falha (PDR-010)
epic_id: EPIC-003
sprint_id: SPRINT-2026-W28
type: implementation
target_role: programador
requires_design: false  # admin reusa fila padrão; usuário vê confirmação simples no detalhe
design_screen_id: null
status: ready
owner_agent: null
created_at: 2026-06-03
updated_at: 2026-06-03
estimated_session_size: M
produces_idr: null
---

# STORY-065 — Captura Pagar.me + Pix sandbox + alerta admin em falha

## Contexto

Turno em `finalizado` (STORY-064). Esta estória **consome o evento `TurnoFinalizado`** e dispara: (a) `capturar` via ACL Pagar.me (idempotente — STORY-056), (b) `transferirPix` para a chave Pix do profissional, (c) registra `pix_enviado` no audit log; em caso de falha de Pix: alerta destacado na fila operacional do admin (PDR-010 — **uma tentativa, sem retry automático**).

Esta é a estória que **prova o segundo pilar da promessa pública** (Pix em ≤ 15 min) em homolog com sandbox.

- Épico: `epics/EPIC-003-aceite-pin-e-pix/epic.md`
- Documentos: `domain/pagamento.md` (ciclo completo), PDR-004, PDR-010, ADR-005, ADR-016.

## O quê

Listener `TurnoFinalizadoListener` consome o evento, executa `capturar` + `transferirPix` via ACL com idempotência. Sucesso: emite `PagamentoCapturado` + `PixEnviado` (consumido por STORY-067 notificação "Pix enviado"). Falha de Pix: emite `PixFalhou` → fila operacional do admin destaca o turno com badge "Pix falhou — tratamento manual" + dados do erro Pagar.me.

## Por quê

Sem captura, o contratante não paga e o profissional não recebe. Sem Pix em ≤ 15 min, a promessa pública do Turni é vazia. Sem alerta em falha, a operação fica cega.

## Critérios de aceite

- [ ] **CA-1:** Listener `TurnoFinalizadoListener` consome o evento da STORY-064 e executa `capturar(turno_id)` via ACL Pagar.me com chave de idempotência `captura:{turno_id}`. Em job na fila `database` (ADR-002 — worker assíncrono).
- [ ] **CA-2:** Sucesso da captura: emite `PagamentoCapturado` com `charge_id` Pagar.me, valor capturado, timestamp; audit log captura `pagamento.capturado`.
- [ ] **CA-3:** Em sequência, executa `transferirPix(turno_id, valor)` para a chave Pix do profissional (lida do perfil — EPIC-001). Idempotência `pix:{turno_id}`.
- [ ] **CA-4:** Sucesso do Pix: emite `PixEnviado` com `transferencia_id` Pagar.me, valor, timestamp; audit log captura `pix.enviado`. Detalhe do turno mostra "Pix enviado em HH:MM" no card de valor (visível ao profissional).
- [ ] **CA-5:** Falha de Pix (PDR-010 — **uma tentativa**): emite `PixFalhou` com motivo Pagar.me, timestamp; audit log `pix.falhou`. Fila operacional do admin destaca: badge vermelho + microcopy "Pix falhou — tratamento manual" + valor + chave Pix do profissional + razão.
- [ ] **CA-6:** Webhook entrante (STORY-056) é a **fonte de verdade** da confirmação Pagar.me — listener inicial dispara a captura/Pix, mas o estado final do pagamento vem do webhook (assíncrono). Se webhook reportar falha após sucesso aparente, alerta é atualizado.
- [ ] **CA-7:** Métrica primária verificada em CI: em 20 turnos seedados percorrendo o ciclo completo em sandbox, ≥ 95% têm Pix confirmado em ≤ 15 min. Resultado do teste anexado à estória.
- [ ] **CA-8:** Fila operacional do admin tem aba "Pix com falha" — lista paginada de turnos com `pix.falhou`, ordenado por timestamp desc; admin pode marcar "Resolvido manualmente" com nota (audit log).
- [ ] **CA-9:** Em cancelamento (STORY-066) ou caminho onde turno não chega a `finalizado`, captura **não** é disparada (pré-autorização é liberada em vez disso).
- [ ] **CA-10:** Cobertura ≥ 98% no núcleo (listener + parsing de webhook + lógica de fallback do alerta); ≥ 80% no resto.

## Fora de escopo

- Retry automático de Pix (PDR-010 — fora MVP).
- Captura parcial (`finalizado_ajustado` — EPIC-005).
- Comunicação automatizada ao profissional em falha (PDR-010 — manual).
- UI fina da aba "Pix com falha" do admin — fila padrão da operação serve; melhoria é wishlist.

## Padrões de qualidade

≥ 80% / ≥ 98% no núcleo. Métrica primária 95% em ≤ 15 min com 20 turnos seedados. Log JSON em todas as operações financeiras (request_id propagado).

## Dependências

- **Bloqueada por:** STORY-064 (evento `TurnoFinalizado`), STORY-056 (ACL Pagar.me).
- **Bloqueia:** STORY-068 (validador verifica métrica primária — Pix em ≤ 15 min).
- **Pré-requisitos:** mock + sandbox operantes; chave Pix do profissional registrada (EPIC-001).

## Decisões já tomadas

ADR-005 / ADR-008 / ADR-015 / ADR-016 — PDR-004 / PDR-010.

## Liberdade técnica

Decide: tamanho/cor exatos do badge, formato da nota de "resolvido manualmente", estrutura interna do listener.

NÃO decide: 1 tentativa de Pix (PDR-010); que webhook é fonte de verdade (ADR-005/016); imutabilidade do audit log (herdado).

## Definição de Pronto

- [ ] CAs marcados; deploy verificado.
- [ ] Alexandro testa em homolog (1 turno completo: captura + Pix visíveis no painel sandbox Pagar.me).
- [ ] 20 turnos seedados com ≥ 95% em ≤ 15 min.
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
