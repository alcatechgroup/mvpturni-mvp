---
story_id: STORY-060
slug: detalhe-turno-timeline-trilha-auditoria
title: Detalhe do turno (ambos os lados) + timeline + trilha de auditoria visível
epic_id: EPIC-003
sprint_id: SPRINT-2026-W28
type: implementation
target_role: programador
requires_design: true
design_screen_id: SCREEN-STORY-060-detalhe-turno
status: done
owner_agent: claude-opus-4-8
created_at: 2026-06-03
updated_at: 2026-06-05
estimated_session_size: M
produces_idr: null
---

# STORY-060 — Detalhe do turno + timeline + trilha de auditoria

## Contexto

A lista da STORY-059 leva o usuário até o turno individual. Esta tela é a **casa do turno** — onde o profissional gera PIN (STORY-061/064), o contratante valida PIN (STORY-062/064), ambos veem cronômetro (STORY-063), e a timeline mostra eventos passados de forma legível. A trilha de auditoria simplificada vive aqui (admin tem versão completa no Backoffice).

- Épico: `epics/EPIC-003-aceite-pin-e-pix/epic.md`
- Documentos: `domain/turno.md`, `domain/compliance.md` (trilha de auditoria), `domain/pagamento.md` (valores visíveis).

## O quê

Tela `/turnos/{id}` (compartilhada profissional/contratante, RBAC) com: atributos do turno (função, data/hora, estabelecimento, valor — visibilidade diferente por papel conforme `domain/pagamento.md`), estado atual com badge visual, timeline de eventos passados (audit log filtrado para os campos visíveis), área de ações (placeholder — as ações concretas chegam em 061/062/063/064/066).

## Por quê

É o componente que **costura** todas as ações do turno em um único lugar. Sem ele, profissional e contratante precisariam navegar por telas separadas para cada ação.

## Critérios de aceite

- [x] **CA-1:** `GET /api/turnos/{id}` retorna o turno com atributos + timeline filtrada (eventos relevantes para o papel) — RBAC: profissional vê só os próprios; contratante vê só os turnos das próprias vagas; cruzados 403.
- [x] **CA-2:** Tela `/turnos/{id}` renderiza header com função/data/hora/estabelecimento, estado atual com badge visual (DDR-001), e card de valor com **visibilidade diferenciada por papel** (profissional vê `valor` em destaque + "valor integral · taxa Turni cobrada do contratante" em letra menor; contratante vê `valor + taxa_turni + total_contratante` separados — `domain/pagamento.md` §"Visibilidade financeira").
- [x] **CA-3:** Timeline mostra eventos em ordem cronológica descendente: `turno_criado`, `aceite_eletronico_emitido`, `pagamento_pre_autorizado`, `checkin_solicitado`, `checkin_validado`, `checkout_solicitado`, `checkout_validado`, `pagamento_capturado`, `pix_enviado`, `cancelado`, `no_show_pro`. Cada evento traz timestamp em formato 24h pt-BR (IDR-026/DDR-002) e descrição amigável.
- [x] **CA-4:** Área de ações (botão grande, alta legibilidade) com placeholder que as estórias 061/062/063/064/066 vão preencher conforme o estado.
- [x] **CA-5:** Link "Ver aceite eletrônico" abre modal com o `conteudo_renderizado` do AceiteEletronico (somente leitura — imutabilidade).
- [x] **CA-6:** Cobertura ≥ 80%; E2E cobre o caminho lista → detalhe para os 2 papéis.

## Fora de escopo

- Ações sobre o turno (estórias seguintes).
- Cronômetro vivo (STORY-063).
- Trilha de auditoria **completa** no Backoffice (admin tem visão diferente; pode ficar como follow-up se não couber).

## Padrões de qualidade

≥ 80%. E2E em `integration_test`. RBAC verificado por teste explícito.

## Dependências

- **Bloqueada por:** STORY-058 (modelo + dados em `confirmado`).
- **Bloqueia:** STORY-061, STORY-062, STORY-063, STORY-064, STORY-066 (ações vivem aqui).
- **Pré-requisitos:** SCREEN-STORY-060 entregue.

## Decisões já tomadas

ADR-013, ADR-015, ADR-010 (imutabilidade do aceite), **ADR-018 (UUIDv7 em PKs — URL `/turnos/{uuid}`; DTO Flutter tipa `id` como `String`; audit log payload referencia entidades por UUID)**, DDR-001/002, IDR-026.

## Liberdade técnica

Decide: estrutura interna da timeline (componente reaproveitado), tamanho/posição da área de ações.

NÃO decide: visibilidade financeira (fixada em `domain/pagamento.md`).

## Definição de Pronto

- [x] CAs marcados; deploy verificado.
- [x] SCREEN-STORY-060 marcado `shipped`.
- [x] `index.json` atualizado.
- [x] "Notas do agente" preenchida.

## Protocolo

`docs/skills/po/references/agent-task-format.md`.

## Notas do agente

### Decisões tomadas

- **Papel pelo payload, não por estado global**: a tela `/turnos/{id}` descobre o papel pela
  presença de `total_contratante` no payload (servidor é a fonte de verdade do RBAC); a sessão
  local só decide tema/navegação nos estados pré-fetch (loading/erro/não-encontrado).
- **403 renderiza como "Turno não encontrado"** (igual 404) — fail-secure: não confirmar
  existência de turno alheio (SCREEN-060 §4.5, validado pelo PO). O backend devolve 403 (CA-1);
  a distinção fica no log/API.
- **Visibilidade financeira na timeline** (SCREEN-060 §4.1, validado pelo PO): o servidor só
  anexa `valor` ao evento conforme o papel — profissional só em `pix_enviado` (R$ que é dele);
  contratante o total em `pagamento_pre_autorizado`/`capturado`. O payload do profissional nem
  carrega `taxa_turni`/`total_contratante` (defesa em profundidade).
- **Whitelist de eventos no controller** já mapeia os 11 eventos do CA-3 — as STORY-061/062/
  064/065/066 só gravam o audit log (mesmos `action` do fluxo real) e a timeline os exibe sem
  retrabalho. Evento fora da whitelist (ex.: `pagamento.pre_autorizacao_falhou`) não aparece
  para as partes (trilha completa é do admin — compliance.md).
- **Aceite inline** no GET (documento autocontido e imutável); o modal é somente leitura
  (ADR-010/ADR-015).
- **TurnosSeeder ganhou trilha por estado + backfill idempotente**: turnos seedados antes da
  timeline (dev/homolog rc.71) recebem a trilha no próximo `db:seed` sem recriar nada.
- **DS**: `section.group-header` promovido a definitivo (2º uso); `timeline.event` e
  `dialog.document` registrados como exceções candidatas (promover no reuso da 061+).
- **`TurniDateTime.formatEvento`** novo (IDR-026): `"Qua, 03/06 · 15:47"`, ano explícito
  quando ≠ corrente.

### Descobertas

- `audit_logs` é append-only no banco (trigger + REVOKE do EPIC-001): `created_at` retroativo
  precisa ir no INSERT (`forceCreate`) — vale para seeders e testes.
- O evento `aceite_eletronico.emitido` tem target próprio (AceiteEletronicoTurno) e referencia
  o turno via `payload.turno_id` — a query da timeline usa OR e o teste cobre o não-vazamento
  entre turnos.

### Bloqueios encontrados

- Nenhum.

### IDRs criados

- Nenhum (decisões locais; nada transversal novo).

### Cobertura final

- Unitários: API 765 testes verdes, cobertura total 92,9% (`TurnoDetalheController` 100%);
  WebApp 414 testes verdes (13 widget tests da tela + 6 do service + formatEvento).
- E2E: `integration_test/turnos/detalhe_turno_test.dart` — lista → detalhe nos 2 papéis
  (CA-6), incluindo modal do aceite; gate local híbrido (IDR-010/021) verde.

### Links de evidência

- PR: n/a (commit direto na main — fluxo combinado). Commit `892d43b`.
- Pipeline: Release run 27020009553 (verde; migrate+seed executados — backfill da trilha
  aplicado nos turnos do seed antigos).
- Deploy de homologação: **v0.1.0-rc.72** no ar (2026-06-05; `version.json` confere;
  `GET /api/turnos/{uuid}` sem auth → 401, rota viva). Verificação manual de Alexandro:
  **aprovada em chat (2026-06-05)** — roteiro de 4 cenários (detalhe nos 2 papéis,
  fail-secure cruzado, área de ações por estado).
