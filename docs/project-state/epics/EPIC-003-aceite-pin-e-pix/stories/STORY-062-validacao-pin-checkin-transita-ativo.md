---
story_id: STORY-062
slug: validacao-pin-checkin-transita-ativo
title: Validação do PIN de check-in pelo contratante + transição para `ativo`
epic_id: EPIC-003
sprint_id: SPRINT-2026-W28
type: implementation
target_role: programador
requires_design: true
design_screen_id: SCREEN-STORY-062-validar-checkin
status: ready
owner_agent: null
created_at: 2026-06-03
updated_at: 2026-06-03
estimated_session_size: M
produces_idr: null
---

# STORY-062 — Validar PIN de check-in + transitar para `ativo`

## Contexto

Profissional gerou PIN (STORY-061). Contratante recebe notificação in-app (STORY-067) e abre o turno no WebApp para validar. Esta estória entrega o campo de input + validação + transição para `ativo` (que dispara o cronômetro da STORY-063). Inclui aviso destacado quando `geofencing_ok: false`.

- Épico: `epics/EPIC-003-aceite-pin-e-pix/epic.md`
- Documentos: `domain/turno.md` (transição `aguardando_checkin → ativo`; "contratante recusa → volta confirmado; pro gera novo PIN"), PDR-008.

## O quê

Área de ação no detalhe do turno (STORY-060) para o contratante quando estado é `aguardando_checkin`: input de 4 dígitos (PIN), botão "Validar check-in". Se `geofencing_ok: false`: card de aviso destacado **antes** do input mostrando distância e razão (`permissao_negada`, `timeout`, `fora_do_raio`). Validação correta: transita para `ativo`, grava `check_in_at`, dispara evento de domínio `TurnoIniciado` (consumido por STORY-063 cronômetro e STORY-067 notificações). Validação incorreta: retorna 422 com microcopy.

## Por quê

PIN bilateral só é "bilateral" quando o contratante valida. Sem essa validação, profissional ficaria preso em `aguardando_checkin` para sempre. Aviso de geofencing é o que coloca PDR-008 na vida real.

## Critérios de aceite

- [ ] **CA-1:** `POST /api/turnos/{id}/validar-checkin` recebe `{ pin: "1234" }`, valida contra hash server-side da STORY-061, transita para `ativo` em transação (com gravação de `check_in_at`), emite evento `TurnoIniciado`. RBAC: só contratante do turno; outros 403.
- [ ] **CA-2:** PIN errado retorna 422 com microcopy "PIN inválido. Confira com o profissional" (sem expor número de tentativas — segurança por obscuridade não é defesa, mas evitamos dar pista para força bruta). Rate limit 5 tentativas / 60s por turno (configurável via env).
- [ ] **CA-3:** Após 3 PINs errados: backend invalida o PIN ativo e devolve mensagem "PIN expirado por excesso de tentativas; peça ao profissional para gerar novo". Profissional vê estado `confirmado` novamente (botão "Gerar novo PIN" — STORY-061 idempotente).
- [ ] **CA-4:** Validação ≤ 500ms p95 (NFR do EPIC-003 — `non-functional.md`). Microbenchmark em CI.
- [ ] **CA-5:** `geofencing_ok: false` no turno: card de aviso **destacado** acima do input com cor de atenção do DS, mostrando distância em metros e razão amigável (`Localização não disponível` / `Profissional está a 350m do estabelecimento`). Contratante pode validar mesmo assim (PDR-008 — não bloqueia).
- [ ] **CA-6:** "Recusar check-in" como botão secundário (com confirmação) — volta turno para `confirmado` e invalida PIN; profissional gera novo. Audit log captura `turno.checkin_recusado` com motivo opcional (textarea).
- [ ] **CA-7:** Audit log captura `turno.checkin_validado` (com `pin_tentativas_até_acerto: N`) ou `turno.checkin_recusado`.
- [ ] **CA-8:** Cobertura ≥ 98% no núcleo (validação + transição + invalidação por tentativas); ≥ 80% no resto. E2E cobre PIN correto + 3 errados + recusa + geofencing false.

## Fora de escopo

- Cronômetro vivo (STORY-063 consome o evento `TurnoIniciado`).
- Notificação ao profissional de "check-in validado" (STORY-067).
- Vencimento de horário → `no_show_pro` (STORY-066).

## Padrões de qualidade

≥ 80% / ≥ 98% no núcleo. E2E cobre 5 cenários. P95 ≤ 500ms verificado em CI.

## Dependências

- **Bloqueada por:** STORY-061 (PIN gerado), STORY-060 (área de ações).
- **Bloqueia:** STORY-063 (cronômetro), STORY-064 (check-out só vem depois de `ativo`).
- **Pré-requisitos:** SCREEN-STORY-062 entregue.

## Decisões já tomadas

ADR-015, **ADR-018 (UUIDv7 em PKs — URL `/turnos/{uuid}/validar-checkin` aceita UUID; rate limit chave por `turno_id` UUID; evento `TurnoIniciado` carrega `turno_id` UUID string)**, PDR-008.

## Liberdade técnica

Decide: rate limit exato, microcopy de erro, estrutura do card de aviso.

NÃO decide: imutabilidade do snapshot de check-in (ADR-015); que geofencing não bloqueia (PDR-008).

## Definição de Pronto

- [ ] CAs marcados; deploy verificado.
- [ ] SCREEN-STORY-062 `shipped`.
- [ ] Alexandro testa em homolog (2 navegadores, valida PIN, vê transição).
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
