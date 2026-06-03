---
story_id: STORY-059
slug: listas-meus-turnos-vagas-confirmadas
title: Lista "Meus turnos" (profissional) + "Vagas confirmadas" (contratante) no WebApp
epic_id: EPIC-003
sprint_id: SPRINT-2026-W28
type: implementation
target_role: programador
requires_design: true
design_screen_id: SCREEN-STORY-059-listas-turnos
status: ready
owner_agent: null
created_at: 2026-06-03
updated_at: 2026-06-03
estimated_session_size: S
produces_idr: null
---

# STORY-059 — Listas "Meus turnos" e "Vagas confirmadas"

## Contexto

A partir de STORY-058, existem Turnos `confirmado` em homolog. Profissional e contratante precisam de **uma porta de entrada** para ver os turnos deles agrupados por estado — caso contrário, só dá pra acessar via URL direta.

- Épico: `epics/EPIC-003-aceite-pin-e-pix/epic.md`
- Documentos: `docs/especificacao/domain/turno.md` (estados), STORY-047 (padrão de lista "Minhas vagas" — reuso).

## O quê

Duas telas espelhadas no WebApp: `/profissional/turnos` (lista do profissional) e `/contratante/turnos` (lista do contratante), ambas agrupadas pelos estados de `domain/turno.md`. Reuso direto dos componentes da STORY-047 (card + agrupamento + filtros).

## Por quê

Sem essa porta de entrada, o resto da sprint vira invisível para o usuário. É a UI mais barata possível (S) que destrava todas as estórias seguintes.

## Critérios de aceite

- [ ] **CA-1:** `GET /api/profissional/turnos` lista turnos do profissional autenticado agrupados por estado (`confirmado`, `aguardando_checkin`, `ativo`, `aguardando_checkout`, `finalizado`, terminais). Ordem dentro do grupo: por `data_inicio` ascendente (futuros primeiro) ou `data_fim` descendente (passados primeiro), conforme o grupo.
- [ ] **CA-2:** `GET /api/contratante/turnos` espelha — turnos das vagas do contratante autenticado, mesmos grupos.
- [ ] **CA-3:** Tela `/profissional/turnos` renderiza cards de turno (função + data + valor + estado + estabelecimento) agrupados por estado.
- [ ] **CA-4:** Tela `/contratante/turnos` espelha, com tema visual do contratante (DDR-001).
- [ ] **CA-5:** RBAC: profissional vê só os próprios turnos; contratante vê só os turnos das próprias vagas; cruzados retornam 403 fail-secure.
- [ ] **CA-6:** Vazio: estado vazio amigável (microcopy revisado pelo PO em chat) — "Ainda não há turnos — quando o contratante aceitar sua candidatura, ele aparece aqui" / espelho contratante.
- [ ] **CA-7:** Cobertura ≥ 80% no código novo; E2E `integration_test` (Chrome headless) cobre os 2 caminhos.

## Fora de escopo

- Detalhe do turno (STORY-060).
- Qualquer ação sobre o turno (estórias seguintes).
- Filtros avançados — só agrupamento por estado.

## Padrões de qualidade

≥ 80%. E2E em `integration_test` (IDR-010/011). Locale pt-BR + 24h (DDR-002 + IDR-026).

## Dependências

- **Bloqueada por:** STORY-058 (precisa de turnos em `confirmado` para listar).
- **Bloqueia:** nenhuma (paralela a STORY-060).
- **Pré-requisitos:** SCREEN-STORY-059 entregue pelo Designer antes da implementação.

## Decisões já tomadas

- ADR-013 (modelo herdado), ADR-015 (modelo Turno), **ADR-018 (UUIDv7 em PKs — DTOs Flutter tipam `id` como `String`; URLs `/turnos/{uuid}` aceitam string)**, DDR-001/002, IDR-010/011/026.

## Liberdade técnica

Decide: reuso de componentes da STORY-047, estrutura interna da query.

NÃO decide: estados que aparecem (fixados em `domain/turno.md`).

## Definição de Pronto

- [ ] CAs marcados; deploy em homolog verificado por Alexandro.
- [ ] SCREEN-STORY-059 marcado `shipped`.
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
