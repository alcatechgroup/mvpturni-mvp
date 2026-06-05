---
story_id: STORY-064
slug: pin-checkout-validacao-transita-finalizado
title: PIN de check-out — geração + validação + transição para `finalizado`
epic_id: EPIC-003
sprint_id: SPRINT-2026-W28
type: implementation
target_role: programador
requires_design: true
design_screen_id: SCREEN-STORY-064-pin-checkout
status: in_progress
owner_agent: claude-opus-4-8
created_at: 2026-06-03
updated_at: 2026-06-03
estimated_session_size: M
produces_idr: null
---

# STORY-064 — PIN de check-out + validação + transição para `finalizado`

## Contexto

Turno em `ativo` com cronômetro vivo. Profissional termina o trabalho e gera **PIN de check-out de 4 dígitos**. Contratante valida. Turno transita para `finalizado` (cronômetro para; STORY-065 dispara captura + Pix). Esta estória espelha o padrão da STORY-061/062 com diferenças mínimas: estado de origem é `ativo` (não `confirmado`); transição vai para `aguardando_checkout` e então `finalizado`; geofencing de check-out **opcional** (capturado se permitido, mas sem aviso destacado — operação de saída não é tão crítica quanto entrada).

> **Importante:** disputa (`em_disputa` quando contratante recusa) e ajuste financeiro (`finalizado_ajustado`) ficam **fora do escopo deste sprint** — são EPIC-005. Aqui só o caminho feliz `aguardando_checkout → finalizado` + caminho de retorno simples (contratante recusa → volta a `ativo`; profissional gera novo PIN).

- Épico: `epics/EPIC-003-aceite-pin-e-pix/epic.md`
- Documentos: `domain/turno.md` (transições `ativo → aguardando_checkout → finalizado`), STORY-061/062 (padrão a espelhar).

## O quê

Replicar o padrão de geração + validação de PIN da dupla 061/062, mas para check-out:

- Profissional em `ativo` vê botão "Gerar PIN de check-out" no detalhe do turno.
- Geração: PIN aleatório 4 dígitos, hash server-side, transita para `aguardando_checkout`, grava `check_out_at` (timestamp de solicitação — final é o de validação), captura geofencing **opcional** (mesma API, sem aviso destacado).
- Contratante em `aguardando_checkout` vê input de PIN + botão "Validar check-out". Sucesso transita para `finalizado` (cronômetro para; evento `TurnoFinalizado` emitido — consumido por STORY-065 captura e STORY-067 notificação).
- Recusa volta para `ativo` (profissional gera novo PIN). Trilha de auditoria registra a recusa com motivo opcional. **Sem `em_disputa`** nesta sprint.

## Por quê

Fecha o ciclo do PIN bilateral. Sem o check-out, o turno fica preso em `ativo` e o Pix nunca dispara.

## Critérios de aceite

- [x] **CA-1:** Botão "Gerar PIN de check-out" no detalhe do turno aparece **apenas** quando estado é `ativo`. Sem janela horária restritiva (turno pode estender; aceitar).
- [x] **CA-2:** Geração: PIN 4 dígitos, hash server-side, transita `ativo → aguardando_checkout` em transação. Captura geofencing igual STORY-061 (sem aviso destacado na validação do contratante). PIN aparece em plaintext **uma vez** na tela do profissional (mesma disciplina da STORY-061).
- [x] **CA-3:** `POST /api/turnos/{id}/validar-checkout` recebe `{ pin: "5678" }`, valida hash, transita `aguardando_checkout → finalizado`, grava `check_out_at` final, emite `TurnoFinalizado`. Validação ≤ 500ms p95.
- [x] **CA-4:** PIN errado: 422 com microcopy. 3 erradas: invalida PIN; profissional gera novo (espelha STORY-062).
- [x] **CA-5:** "Recusar check-out" como botão secundário: volta turno para `ativo` (cronômetro retoma) + audit log `turno.checkout_recusado` com motivo opcional. **NÃO** transita para `em_disputa` (escopo EPIC-005).
- [x] **CA-6:** Cronômetro (STORY-063) para automaticamente na transição para `aguardando_checkout` e mostra "Aguardando validação — duração: HH:MM:SS"; em `finalizado` mostra "Turno finalizado — duração: HH:MM:SS".
- [x] **CA-7:** Audit log: `turno.checkout_solicitado` (com `geofencing_check_out` opcional), `turno.checkout_validado` ou `turno.checkout_recusado`.
- [x] **CA-8:** Cobertura ≥ 98% no núcleo (validação + transição + invalidação por tentativas + recusa); ≥ 80% no resto. E2E cobre o ciclo completo `confirmado → finalizado` em 1 cenário.

## Fora de escopo

- `em_disputa` (EPIC-005) — recusa volta para `ativo` apenas.
- Captura + Pix (STORY-065 consome o evento `TurnoFinalizado`).
- Notificação "check-out validado" (STORY-067).
- Geofencing destacado no check-out (não é requisito).

## Padrões de qualidade

≥ 80% / ≥ 98% no núcleo. P95 ≤ 500ms. E2E cobre ciclo completo.

## Dependências

- **Bloqueada por:** STORY-063 (cronômetro vivo é pré-requisito visual).
- **Bloqueia:** STORY-065 (captura).
- **Pré-requisitos:** SCREEN-STORY-064 entregue (pode reusar SCREEN-STORY-061/062).

## Decisões já tomadas

ADR-015, **ADR-018 (UUIDv7 em PKs — espelha STORY-061/062; URL `/turnos/{uuid}/...` aceita UUID; evento `TurnoFinalizado` carrega `turno_id` UUID string)**, PDR-006 (disputa — apenas para saber que **não** entra agora).

## Liberdade técnica

Decide: reuso máximo de componentes de PIN da STORY-061/062 — desejado.

NÃO decide: que `em_disputa` está fora (EPIC-005); imutabilidade da transição (ADR-015).

## Definição de Pronto

- [ ] CAs marcados; deploy verificado.
- [ ] SCREEN-STORY-064 `shipped` (ou reuso documentado).
- [ ] Alexandro testa em homolog (ciclo completo até `finalizado`).
- [ ] `index.json` atualizado.
- [ ] "Notas do agente" preenchida.

## Protocolo

`docs/skills/po/references/agent-task-format.md`.

## Notas do agente

### Decisões tomadas
- **Espelhamento literal da dupla 061/062** (liberdade técnica "reuso máximo — desejado"): `PinCheckoutService`/`ValidarCheckoutService` espelham os services de check-in; o WebApp reusa os **resultados sealed** das 061/062 (`PinGerado`, `PinInvalido`, `RecusaOk`…) em services novos com endpoints próprios — zero refactor em código shipped.
- **Exceptions reusadas** (`PinInvalidoException`, `PinExpiradoException`, `PinCheckinEstadoInvalidoException` — mensagem generalizada de "PIN de check-in" para "PIN").
- **Expiração por 3 erros devolve a `ativo`** (estado de origem — espelho da 062, que devolvia a `confirmado`); cronômetro retoma da âncora `check_in_at` intacta.
- **Geofencing silencioso** (CA-2): captura na geração com a mesma API da 061, snapshot na trilha/timeline (único lugar onde aparece — CA-7); sem nota na tela do PIN e sem card de aviso na validação. Loading do gerar diz "Gerando PIN…" (não promete localização).
- **Conflito de microcopy CA-6 × SCREEN-063 arbitrado por Alexandro**: vale o CA-6 da 064 ("Aguardando validação — duração:"); mudança consciente registrada no histórico da SCREEN-063 (testes da 063 atualizados junto).
- **Cronômetro detecta transição que a tela não viu**: polling que pega `aguardando_checkout`/`finalizado` com a tela ainda em `ativo` dispara reload — o contratante ganha o bloco de validação sem refresh manual (melhoria sobre a 063, registrada na SCREEN-064 §histórico).
- **`finalizado` sem placeholder de ações** (regra da 060 §4.1 vence o protótipo v1 — ajuste consciente, SCREEN-064 §4.11).
- **Seed**: par exclusivo `*.checkout.seed` com `recriaConsumido` (o E2E consome o turno até `finalizado`, terminal; run interrompido em `ativo`/`aguardando_checkout` também recria).

### Descobertas
- A 063 já tinha deixado o `CronometroController::encerradoEm()` derivando do evento `turno.checkout_solicitado` — a 064 só precisou gravar o evento com esse nome para a duração congelar bilateral (premissa §10 da SCREEN-063 cumprida sem mudança na API do cronômetro).
- A whitelist da timeline (060) já mapeava `checkout_solicitado`/`checkout_validado`; faltavam só os 3 espelhos (cancelado/recusado/pin_expirado).
- `enum TurnoStatus`/trigger do banco já suportavam todas as transições da 064 (ADR-015 previu o ciclo completo) — nenhuma migration de máquina de estados.

### Bloqueios encontrados
- Nenhum.

### IDRs criados
- Nenhum (zero decisão arquitetural nova — tudo espelho de padrões decididos nas 061/062/063).

### Cobertura final
- Unitários API: 879 testes (46 novos de check-out), **total 93,6%**; núcleo da 064 (PinCheckoutService 100%, ValidarCheckoutService 100% — validação+transição+invalidação+recusa) ✅ ≥ 98%.
- WebApp: 507 testes de widget (17 novos — pin_checkout_area, validar_checkout_area, cronômetro finalizado/transição).
- E2E: ciclo completo `confirmado → finalizado` em 1 cenário bilateral (checkout_test.dart, par `*.checkout.seed`) — CA-8.

### Links de evidência
- PR: n/a (commit direto na main — fluxo do projeto)
- Pipeline: release.yml (tag v0.1.0-rc.76)
- Deploy de homologação: app.homolog.turni.com.br (rc.76)
