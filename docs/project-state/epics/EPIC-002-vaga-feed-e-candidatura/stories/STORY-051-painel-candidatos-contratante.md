---
story_id: STORY-051
slug: painel-candidatos-contratante
title: Painel de candidatos do contratante — lista ranqueada por match + breakdown
epic_id: EPIC-002
sprint_id: SPRINT-2026-W27
type: implementation
target_role: programador
requires_design: true
design_screen_id: SCREEN-STORY-051-painel-candidatos
status: ready
owner_agent: null
created_at: 2026-06-01
updated_at: 2026-06-01
estimated_session_size: M
produces_idr: null
---

# STORY-051 — Painel de candidatos do contratante

> **Para o agente:** lado espelho do feed do profissional. O contratante vê candidatos da sua vaga ranqueados por score, com o **mesmo breakdown** do lado do profissional (transparência simétrica — `domain/match.md`). Aprovar candidato **NÃO** vira turno nesta estória — o aceite real entra no EPIC-003. Aqui só **prepara**: o contratante vê quem tem, com qual score, e sai pronto para aceitar quando EPIC-003 entregar.

## Contexto

Sem painel, o contratante publica e fica no escuro até receber notificação (STORY-053). Mesmo com notificação, precisa de tela para revisar candidatos lado a lado. O ranqueamento por match é o que diferencia: "Júlia 92/100, Bruno 88/100, Carlos 71/100" + breakdown explica.

- Épico: `epics/EPIC-002-vaga-feed-e-candidatura/epic.md`
- Documentos: `domain/match.md` (Visibilidade para o contratante), `domain/candidatura.md` (Aprovação pelo contratante — mas a parte de virar Turno fica para EPIC-003), STORY-049 (widget `BreakdownRow` reaproveitado).

## O quê

Tela `/contratante/vagas/{id}/candidatos` no WebApp listando todos os candidatos pendentes da vaga, ranqueados por `score_no_momento DESC, plano_boost DESC, candidatou_em ASC`. Cada candidato mostra: nome, foto, função primária, score numérico, barra, e botão "Ver breakdown" expandindo o widget reusado da STORY-049. Marca `alerta_habitualidade: true` quando vier (STORY-050 CA-4). **Não** implementa o aceite — botão "Aceitar candidatura" fica desabilitado com tooltip "Disponível no EPIC-003 — Aceite, PIN e Pix".

## Por quê

Fecha o ciclo do EPIC-002 do lado do contratante: publicou, recebeu, viu ranqueado, está pronto. Sem esta tela, a métrica primária do épico ("Contratante publica vaga e recebe primeira candidatura em ≤ 2h") fica observável só no banco.

## Critérios de aceite

- [ ] **CA-1:** `GET /api/vagas/{id}/candidatos` autenticado como contratante dono retorna `{ candidatos: [{ id, profissional: { id, nome, foto_url, funcao_primaria, nivel, score_historico, plano }, score_no_momento, score_breakdown, candidatou_em, alerta_habitualidade } ], total }`. RBAC: contratante não-dono → 403; profissional → 403.
- [ ] **CA-2:** Tela renderiza lista ordenada por `score_no_momento DESC, plano_boost DESC, candidatou_em ASC` (mesma regra do feed — STORY-048 CA-3 — mas usando o `score_no_momento` persistido pela STORY-050, **não** recalculando).
- [ ] **CA-3:** Cada card mostra: avatar + nome, função primária, nível (Iniciante/Confiável/Destaque/Elite), score numérico + barra (DDR-001), data/hora da candidatura formatada PT-BR. Badge "Turni Ads" / "Turnificado" quando plano aplicável (stub se planos ainda não estão modelados — STORY-045 CA-5 documenta).
- [ ] **CA-4:** Expansão "Ver breakdown" mostra o widget de breakdown da STORY-049 (4 linhas com ícone/barra/descrição) usando `score_breakdown` persistido em `candidaturas.score_breakdown jsonb` no momento da candidatura (não recalcula — preserva o snapshot histórico).
- [ ] **CA-5:** Alerta de habitualidade (vindo de STORY-050 CA-4 para MEI/PJ na 3ª alocação): badge laranja no card "⚠ Habitualidade — 3ª alocação na semana" com tooltip explicando.
- [ ] **CA-6:** Botão "Aceitar candidatura" fica **desabilitado** com tooltip "Disponível no EPIC-003". Botão "Remover candidato" também desabilitado (estado `recusada` é Lacuna do MVP per `candidatura.md`). Isto é proposital — fecha o EPIC-002 sem invadir EPIC-003.
- [ ] **CA-7:** Estado vazio: "Ainda sem candidatos — vamos avisar assim que chegar o primeiro" com indicador do SLA prometido (≤ 2h para Member Start, ≤ 1h para Enterprise — referência de `business-rules.md`).
- [ ] **CA-8:** Performance: query suporta vaga com até 50 candidatos sem degradação (>100 fica para depois). p95 ≤ 500ms no CI.
- [ ] **CA-9:** Cobertura: backend (controller + serializer + RBAC) ≥ 95%; widget Flutter ≥ 80%. Testes: contratante dono vê seus candidatos / contratante outro 403 / profissional 403 / vaga sem candidatos / vaga com 5 candidatos retornados na ordem correta.
- [ ] **CA-10:** E2E em `integration_test`: contratante seed loga, navega da STORY-047 (lista de vagas) → painel de candidatos da vaga seed com 3 candidatos seedados → vê os 3 na ordem correta + breakdown expansível. 0 flake em 3 runs.

## Fora de escopo

- Aceite real (pré-autorização Pagar.me + criar Turno) → EPIC-003.
- Recusa explícita do contratante → Lacuna `candidatura.md` MVP.
- Mensagem do profissional ao candidatar → Lacuna `candidatura.md` MVP.
- Notificação push em tempo real quando chegar nova candidatura → STORY-053 trata e-mail + in-app; push é onda seguinte.
- Exportar lista de candidatos.

## Padrões de qualidade

≥ 95% backend, ≥ 80% widget, E2E verde, RBAC testado.

## Dependências

- **Bloqueada por:** STORY-044, STORY-045, STORY-050 (precisa de candidaturas reais com snapshot de score), STORY-049 (widget `BreakdownRow`).
- **Bloqueia:** STORY-054 (validação).
- **Pré-req:** vaga seed `aberta` com 3+ candidaturas seedadas.

## Decisões já tomadas

- ADR-013, ADR-014.
- `domain/match.md`: Visibilidade para o contratante (ordenação padrão por score decrescente).
- `domain/candidatura.md`: aceite vira Turno (mas isso é EPIC-003).

## Liberdade técnica

Decide: estrutura do card, estratégia de expand/collapse do breakdown, paginação se necessário. NÃO decide: ordem de ranqueamento (fixada por `domain/match.md`), aceite (fora de escopo).

## DoD

- [ ] CAs checados.
- [ ] Cobertura + E2E verdes.
- [ ] Deploy de homolog: contratante seed navega da vaga até o painel e vê 3 candidatos.
- [ ] `index.json` atualizado.
- [ ] "Notas do agente" preenchida.

## Notas do agente

### Decisões / Descobertas / Bloqueios / IDRs
- 
### Cobertura final
- Unitários: 
- E2E: 
### Links
- PR / Pipeline / Deploy
