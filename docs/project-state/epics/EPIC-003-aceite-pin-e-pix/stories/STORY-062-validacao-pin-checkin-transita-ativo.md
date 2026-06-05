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
status: done
owner_agent: claude-opus-4-8
created_at: 2026-06-03
updated_at: 2026-06-05
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

- [x] **CA-1:** `POST /api/turnos/{id}/validar-checkin` recebe `{ pin: "1234" }`, valida contra hash server-side da STORY-061, transita para `ativo` em transação (com gravação de `check_in_at`), emite evento `TurnoIniciado`. RBAC: só contratante do turno; outros 403.
- [x] **CA-2:** PIN errado retorna 422 com microcopy "PIN inválido. Confira com o profissional" (sem expor número de tentativas — segurança por obscuridade não é defesa, mas evitamos dar pista para força bruta). Rate limit 5 tentativas / 60s por turno (configurável via env).
- [x] **CA-3:** Após 3 PINs errados: backend invalida o PIN ativo e devolve mensagem "PIN expirado por excesso de tentativas; peça ao profissional para gerar novo". Profissional vê estado `confirmado` novamente (botão "Gerar novo PIN" — STORY-061 idempotente).
- [x] **CA-4:** Validação ≤ 500ms p95 (NFR do EPIC-003 — `non-functional.md`). Microbenchmark em CI.
- [x] **CA-5:** `geofencing_ok: false` no turno: card de aviso **destacado** acima do input com cor de atenção do DS, mostrando distância em metros e razão amigável (`Localização não disponível` / `Profissional está a 350m do estabelecimento`). Contratante pode validar mesmo assim (PDR-008 — não bloqueia).
- [x] **CA-6:** "Recusar check-in" como botão secundário (com confirmação) — volta turno para `confirmado` e invalida PIN; profissional gera novo. Audit log captura `turno.checkin_recusado` com motivo opcional (textarea).
- [x] **CA-7:** Audit log captura `turno.checkin_validado` (com `pin_tentativas_até_acerto: N`) ou `turno.checkin_recusado`.
- [x] **CA-8:** Cobertura ≥ 98% no núcleo (validação + transição + invalidação por tentativas); ≥ 80% no resto. E2E cobre PIN correto + 3 errados + recusa + geofencing false.

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

- [x] CAs marcados; deploy verificado (rc.74 em homolog).
- [x] SCREEN-STORY-062 `shipped`.
- [x] Alexandro testa em homolog (2 navegadores, valida PIN, vê transição) — aprovado em chat 2026-06-05.
- [x] `index.json` atualizado.
- [x] "Notas do agente" preenchida.

## Protocolo

`docs/skills/po/references/agent-task-format.md`.

## Notas do agente

### Decisões tomadas
- **Fluxo designer → programador:** SCREEN-STORY-062 especificada e validada por Alexandro (protótipo HTML aprovado sem ajustes) ANTES do código. Premissas da spec confirmadas na implementação.
- **Duas camadas de proteção contra força bruta (CA-2/CA-3):** rate limit HTTP 5/60s por turno (`RateLimiter`, chave `validar-checkin:{uuid}` — ADR-018; configurável `TURNI_CHECKIN_VALIDACAO_MAX_POR_MINUTO`) no controller; limite de domínio (3 erros expiram o PIN) no service, persistido em `turnos.pin_checkin_tentativas` (coluna nova — transacional, sobrevive a restart; zerada na (re)geração da 061, recusa e validação). Request mal-formado (não 4 dígitos) não consome nenhuma das duas.
- **PIN é de uso único:** o hash é limpo também na validação com sucesso (não só na recusa/expiração).
- **Evento `TurnoIniciado`** carrega só `turno_id` UUID string (ADR-018) — consumidor (063/067) recarrega o agregado; evita serializar o modelo em fila. Despachado pós-commit.
- **Geofencing no payload do contratante:** snapshot exposto top-level (`geofencing_check_in {ok, distancia_metros, razao}`) só em `aguardando_checkin` — o aviso é do momento de validar, não atributo permanente.
- **Timeline:** whitelist ganhou `checkin_recusado` e `checkin_pin_expirado` (premissa §4.11 da spec); o MOTIVO da recusa fica só na trilha do admin (não vaza para as partes).
- **Recusa devolve 200 mesmo em `estado_invalido` na UI** (recarrega a verdade — padrão da 061).
- **Seed:** `seedTurnoNaJanela()` genérico (refactor do pin.seed); par novo `*.validar.seed` com recriação quando o turno é consumido (`ativo` não volta — máquina de estados/trigger; o turno antigo fica como histórico, aceite imutável impede delete).
- **DS:** `button.text` promovido a definitivo no `components.md` (3º uso — previsto na SCREEN-061 §8).

### Descobertas
- `PinCheckinForaDaJanelaException`/`PinCheckinEstadoInvalidoException` (061) viviam no mesmo arquivo do `PinCheckinService` — **não autoloadáveis** (PSR-4) por quem não carrega o service: o throw da 062 dava 500 "class not found". Extraídas para arquivos próprios (correção que beneficia a 061 também).
- Rodar a suíte completa da API em paralelo com o gate E2E degrada o stack (falhas em cascata no E2E) — rodar sequencial.

### Bloqueios encontrados
- Nenhum.

### IDRs criados
- Nenhum (decisões cobertas por ADR-015/ADR-018/PDR-008 e liberdade técnica da estória).

### Cobertura final
- Unitários: API 833 testes / 93,3% total — núcleo da 062 a **100%** (`ValidarCheckinService`, `ValidarCheckinController`, `TurnoDetalheController`, `PinCheckinService`, `TurnoIniciado`); benchmark CA-4 verde (p95 ≤ 500ms, gate 750ms). WebApp 471 testes (17 da área de validação + 13 do service + timeline/parse).
- E2E: gate local completo verde (`make e2e-webapp-integration`) — 3 cenários bilaterais da 062: (1) geo negada → card de aviso + PIN errado inline + recusa com motivo; (2) 3 errados → PIN expirado (banner + `confirmado`); (3) PIN correto → `ativo` (snackbar + badge + "Turno iniciado."). Anti-flake: anchor no ciclo do botão (aprendizado dos runs 2–4 — `enterText('')` não esvazia campo no Web; tap em botão desabilitado é perdido em silêncio).
### Links de evidência
- PR: n/a (commit direto na main — workflow do projeto)
- Pipeline: CI da main verde (run 27031246772); Release `v0.1.0-rc.74` success (run 27031377128)
- Deploy de homologação: `https://app.homolog.turni.com.br` servindo `v0.1.0-rc.74` (`/version.json` verificado); roteiro de verificação manual entregue ao PO em chat (2 navegadores, par `*.validar.seed`)
