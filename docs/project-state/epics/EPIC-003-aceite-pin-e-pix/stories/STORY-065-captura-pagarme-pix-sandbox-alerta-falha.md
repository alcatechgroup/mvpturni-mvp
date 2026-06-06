---
story_id: STORY-065
slug: captura-pagarme-pix-sandbox-alerta-falha
title: Captura + Pix via gateway (fake genérico — PDR-017) + alerta admin em falha (PDR-010)
epic_id: EPIC-003
sprint_id: SPRINT-2026-W28
type: implementation
target_role: programador
requires_design: true  # [2026-06-06] Alexandro pediu fluxo designer→programador em chat; era false ("admin reusa fila padrão") — o spec formaliza o card de valor (CA-4) e a aba "Pix com falha" (CA-5/8)
design_screen_id: SCREEN-STORY-065-pix-enviado-e-fila-falhas
status: in_progress
owner_agent: claude-opus-4-8-2026-06-06
created_at: 2026-06-03
updated_at: 2026-06-06
estimated_session_size: M
produces_idr: null
---

# STORY-065 — Captura + Pix via gateway (fake genérico) + alerta admin em falha

> **Nota PDR-017 (2026-06-04):** o gateway implementador no MVP é o **fake genérico** (STORY-056), não o Pagar.me real. O ciclo do domínio (captura → Pix → audit log → fila de Pix com falha) **é idêntico** ao que seria com Pagar.me real — o fake responde com os mesmos formatos de payload (Pagar.me-compatível) e emite o webhook por dentro. **Promessa pública "Pix em 15 min" mantida como simulação**: fake confirma em ~30s, produto mostra "Pix enviado", banner global em homolog (STORY-075) deixa explícito que é simulação. Quando Pagar.me real entrar na próxima wave, esta estória **não muda**.

## Contexto

Turno em `finalizado` (STORY-064). Esta estória **consome o evento `TurnoFinalizado`** e dispara: (a) `capturar` via ACL de pagamento (idempotente — STORY-056), (b) `transferirPix` para a chave Pix do profissional, (c) registra `pix_enviado` no audit log; em caso de falha de Pix: alerta destacado na fila operacional do admin (PDR-010 — **uma tentativa, sem retry automático**).

Esta é a estória que **demonstra o ciclo financeiro do turno fim a fim** em homolog. A promessa pública "Pix em ≤ 15 min" é exercida como **simulação** pelo fake (confirma em ~30s); o banner global em homolog (STORY-075) garante que ninguém confunda com pagamento real. Pagar.me real entra na próxima wave atrás da mesma ACL — esta estória não muda.

- Épico: `epics/EPIC-003-aceite-pin-e-pix/epic.md`
- Documentos: `domain/pagamento.md` (ciclo completo), PDR-004, PDR-010, **PDR-017 (pagamento via fake)**, ADR-005, ADR-016.

## O quê

Listener `TurnoFinalizadoListener` consome o evento, executa `capturar` + `transferirPix` via ACL com idempotência. Sucesso: emite `PagamentoCapturado` + `PixEnviado` (consumido por STORY-067 notificação "Pix enviado"). Falha de Pix: emite `PixFalhou` → fila operacional do admin destaca o turno com badge "Pix falhou — tratamento manual" + dados do erro retornado pelo gateway (formato Pagar.me-compatível, emitido pelo fake configurado para esse cenário).

## Por quê

Sem captura, o contratante não paga e o profissional não recebe. Sem Pix em ≤ 15 min (mesmo como simulação no MVP), a promessa pública do Turni não fica demonstrada. Sem alerta em falha, a operação fica cega — e o fake configurável é exatamente o que torna o teste do caminho de falha **determinístico** (sem depender da variabilidade externa do sandbox real).

## Critérios de aceite

- [ ] **CA-1:** Listener `TurnoFinalizadoListener` consome o evento da STORY-064 e executa `capturar(turno_id)` via ACL de pagamento com chave de idempotência `captura:{turno_id}`. Em job na fila `database` (ADR-002 — worker assíncrono).
- [ ] **CA-2:** Sucesso da captura: emite `PagamentoCapturado` com `charge_id` retornado pelo gateway (formato Pagar.me-compatível — fake mantém o contrato), valor capturado, timestamp; audit log captura `pagamento.capturado`.
- [ ] **CA-3:** Em sequência, executa `transferirPix(turno_id, valor)` para a chave Pix do profissional (lida do perfil — EPIC-001). Idempotência `pix:{turno_id}`.
- [ ] **CA-4:** Sucesso do Pix: emite `PixEnviado` com `transferencia_id` retornado pelo gateway, valor, timestamp; audit log captura `pix.enviado`. Detalhe do turno mostra "Pix enviado em HH:MM" no card de valor (visível ao profissional).
- [ ] **CA-5:** Falha de Pix (PDR-010 — **uma tentativa**): emite `PixFalhou` com motivo retornado pelo gateway, timestamp; audit log `pix.falhou`. Fila operacional do admin destaca: badge vermelho + microcopy "Pix falhou — tratamento manual" + valor + chave Pix do profissional + razão. **Cenário exercitado em homolog via configuração do fake** (`PAGAMENTO_FAKE_FORCE_PIX_FAILURE=true` ou similar — agente decide nome) para validar o caminho determinísticamente.
- [ ] **CA-6:** Webhook entrante (STORY-056) é a **fonte de verdade** da confirmação do gateway — listener inicial dispara a captura/Pix, mas o estado final do pagamento vem do webhook (assíncrono). Se webhook reportar falha após sucesso aparente, alerta é atualizado. **No MVP, o webhook é emitido pelo próprio fake** (com HMAC assinado pelo mesmo segredo) — contrato mantido para troca futura por Pagar.me real.
- [ ] **CA-7:** Métrica primária verificada em CI: em 20 turnos seedados percorrendo o ciclo completo, **100%** completam `confirmado → finalizado → Pix enviado` com o fake em modo `success` (PDR-017 — fake confirma em ~30s ou conforme SLA configurado). Resultado anexado à estória. **Métrica de promessa pública "Pix em ≤ 15 min"** é demonstrada como simulação: SLA do fake é configurável (default ~30s, máximo 15min para fins de teste de promessa); em 20 turnos seedados com SLA 15min, 100% confirmam dentro da janela. Resultado anexado.
- [ ] **CA-8:** Fila operacional do admin tem aba "Pix com falha" — lista paginada de turnos com `pix.falhou`, ordenado por timestamp desc; admin pode marcar "Resolvido manualmente" com nota (audit log). **Cenário exercitado em homolog** com fake configurado para falhar.
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

- **Bloqueada por:** STORY-064 (evento `TurnoFinalizado`), STORY-056 (ACL de pagamento + fake).
- **Bloqueia:** STORY-068 (validador verifica métrica primária — Pix simulado dentro da janela de promessa).
- **Pré-requisitos:** fake genérico (STORY-056) operante em homolog; chave Pix do profissional registrada (EPIC-001). ~~Pagar.me sandbox~~ **REMOVIDO por PDR-017**.

## Decisões já tomadas

ADR-005 / ADR-008 / ADR-015 / ADR-016 / **ADR-018 (UUIDv7 em PKs — `external_reference` carrega `turno_id` UUID string; chave de idempotência da captura/Pix usa UUID; eventos `PagamentoCapturado`/`PixEnviado`/`PixFalhou` referenciam entidades por UUID)** / **PDR-017 (gateway é fake genérico no MVP; contrato Pagar.me-compatível; SLA de Pix configurável no fake)** — PDR-004 / PDR-010.

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
