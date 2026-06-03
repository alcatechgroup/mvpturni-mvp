---
story_id: STORY-067
slug: notificacoes-eventos-turno
title: Notificações in-app + e-mail dos eventos do turno (8 templates via STORY-020)
epic_id: EPIC-003
sprint_id: SPRINT-2026-W28
type: implementation
target_role: programador
requires_design: false  # reusa centro de notificações da STORY-053
design_screen_id: null
status: ready
owner_agent: null
created_at: 2026-06-03
updated_at: 2026-06-03
estimated_session_size: M
produces_idr: null
---

# STORY-067 — Notificações in-app + e-mail dos eventos do turno

## Contexto

EPIC-001 entregou e-mails transacionais. EPIC-002 entregou notificações in-app + e-mail para eventos da candidatura (STORY-053). Esta estória **reusa** a infraestrutura (worker `notificacoes:enviar-emails`, tabela `notificacoes`, editor de templates STORY-020) e adiciona **8 templates novos** para os eventos do turno: `turno_confirmado`, `checkin_solicitado`, `turno_ativo`, `checkout_solicitado`, `turno_finalizado`, `pix_enviado`, `turno_cancelado`, `no_show_pro`.

- Épico: `epics/EPIC-003-aceite-pin-e-pix/epic.md`
- Documentos: STORY-053 (padrão), STORY-021 (worker), ADR-011 (provedor), PDR-012 (editor).

## O quê

8 listeners de eventos de domínio (emitidos pelas STORY-058, 062, 064, 065, 066) criam notificações na tabela `notificacoes` e enviam e-mail via worker existente. Cada notificação carrega tipo, destinatário (profissional ou contratante), payload jsonb com placeholders renderizados. Templates editáveis no Backoffice pelo admin (STORY-020) com texto-seed v1 escrito + validado pelo PO antes da estória fechar.

## Por quê

Sem notificação automática, profissional e contratante precisam ficar olhando o app constantemente — quebra a UX e elimina o valor do "tempo real" do turno. Sem editor, ajustar microcopy de aprovação vira release.

## Critérios de aceite

- [ ] **CA-1:** 8 listeners criados, consumindo os eventos de domínio emitidos pelas estórias de implementação:
  - `TurnoCriado` (STORY-058) → notifica profissional ("turno_confirmado")
  - `CheckinSolicitado` (STORY-061) → notifica contratante ("checkin_solicitado")
  - `TurnoIniciado` (STORY-062) → notifica profissional ("turno_ativo")
  - `CheckoutSolicitado` (STORY-064) → notifica contratante ("checkout_solicitado")
  - `TurnoFinalizado` (STORY-064) → notifica profissional ("turno_finalizado")
  - `PixEnviado` (STORY-065) → notifica profissional ("pix_enviado")
  - `TurnoCancelado` (STORY-066) → notifica o **outro lado** ("turno_cancelado")
  - `TurnoNoShow` (STORY-066) → notifica ambos os lados ("no_show_pro")
- [ ] **CA-2:** Cada notificação grava na tabela `notificacoes` (reuso da STORY-053) + envia e-mail via worker `notificacoes:enviar-emails` (reuso STORY-021/034).
- [ ] **CA-3:** Idempotência: chave `"{tipo}:{turno_id}"` para a maioria; `"{tipo}:{turno_id}:{geracao_pin_id}"` para checkin/checkout (já que profissional pode gerar novo PIN). Repetir o mesmo evento **não** envia 2 notificações.
- [ ] **CA-4:** SLA: notificação no centro in-app ≤ 60s p95 da emissão do evento (log-based metric da STORY-053 — adicionar tipos novos ao filtro).
- [ ] **CA-5:** 8 `TemplateVersao` ativa criadas no editor da STORY-020 (categoria `email`) com texto-seed v1 escrito + validado pelo PO em chat (mesma disciplina STORY-053/W27). PO entrega antes da estória destravar.
- [ ] **CA-6:** Wiring: e-mail consome o template correto pelo `slug` (`turno_confirmado_email`, `checkin_solicitado_email`, etc); in-app consome microcopy mais curta do mesmo `payload`.
- [ ] **CA-7:** E2E em homolog: 3 cenários no Mailpit, 0 flake em 3 runs (espelha CA-12 da STORY-053 — disciplina herdada).
- [ ] **CA-8:** Endpoint `GET /api/notificacoes` (reuso STORY-053) retorna notificações novas dos 8 tipos para o usuário autenticado; `POST /api/notificacoes/{id}/marcar-lida` funciona igual.
- [ ] **CA-9:** Cobertura ≥ 98% no núcleo (idempotência + listeners); ≥ 80% no resto.

## Fora de escopo

- Push notifications (mobile) — `non-functional.md` exclui no MVP.
- Preferências de notificação por usuário (opt-in/out) — wishlist; padrão MVP é "tudo ligado".
- Push web (Web Push API) — fora MVP.

## Padrões de qualidade

≥ 80% / ≥ 98% no núcleo. E2E Mailpit 0 flake. SLA p95 ≤ 60s.

## Dependências

- **Bloqueada por:** STORY-058 (evento `TurnoCriado`), STORY-062 (`TurnoIniciado`), STORY-064 (`TurnoFinalizado`), STORY-065 (`PixEnviado`), STORY-066 (`TurnoCancelado`/`NoShow`). **E** texto-seed v1 do PO entregue (gargalo histórico — antecipar).
- **Bloqueia:** STORY-068 (validador verifica notificações ao vivo).
- **Pré-requisitos:** worker `notificacoes:enviar-emails` operante (herdado da W27); SMTP de homolog operante (herdado do EPIC-001).

## Decisões já tomadas

ADR-011, **ADR-018 (UUIDv7 em PKs — tabela `notificacoes` herda `id` UUIDv7 da refatoração; payload jsonb referencia `turno_id`/`profissional_id`/`contratante_id` como UUID string; chave de idempotência `"{tipo}:{turno_id}"` usa UUID)**, PDR-012, IDR de idempotência da STORY-053 (se houver).

## Liberdade técnica

Decide: estrutura interna de listeners, esquema do payload jsonb, formato dos templates (reuso máximo de helpers da STORY-053).

NÃO decide: que e-mails vão pela infra STORY-021 (decidido); que texto-seed é responsabilidade do PO (padrão herdado STORY-015/053).

## Definição de Pronto

- [ ] CAs marcados; deploy verificado.
- [ ] 8 templates `TemplateVersao` ativa carregados.
- [ ] PO valida cada texto-seed em chat antes da estória fechar.
- [ ] E2E Mailpit verde em 3 runs.
- [ ] SLA p95 verificado em homolog.
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
