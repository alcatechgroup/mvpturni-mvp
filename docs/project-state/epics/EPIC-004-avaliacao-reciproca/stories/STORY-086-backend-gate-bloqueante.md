---
story_id: STORY-086
slug: backend-gate-bloqueante
title: "Backend — gate bloqueante: sem candidatar/publicar com avaliação pendente"
epic_id: EPIC-004
sprint_id: SPRINT-2026-W30
type: implementation
target_role: programador
requires_design: false
design_screen_id: null
status: ready
owner_agent: null
created_at: 2026-06-09
updated_at: 2026-06-09
estimated_session_size: M
produces_idr: null
---

# STORY-086 — Backend: gate bloqueante de avaliação pendente

> **Para o agente que vai executar:** leia a estória inteira. Implementa o ponto de gate decidido em ADR-019 (STORY-083). Fail-secure.

## Contexto (por que esta estória existe)

A avaliação só é obrigatória se houver **gate** (PDR-005): quem tem avaliação pendente não avança. É o mecanismo que fecha o ciclo — força a reflexão antes da próxima ação.

- Decisão: ADR-019 (ponto/estratégia do gate).
- Spec: `domain/niveis-e-score.md` (regra de bloqueio), `flows/avaliacao-reciproca.md`.

## O quê (objetivo desta estória)

Aplicar o gate no ponto decidido (ADR-019): **profissional não pode candidatar-se** e **contratante não pode publicar nova vaga** enquanto houver avaliação pendente de turno `finalizado`. O bloqueio retorna mensagem clara + referência ao turno pendente (para o front linkar). Fail-secure (na dúvida, bloqueia) e RBAC-aware.

## Por quê (valor para o usuário)

Garante que a reciprocidade aconteça de fato — sem gate, a avaliação vira opcional e os dados de qualidade não acumulam.

## Critérios de aceite

- [ ] **CA-1:** Profissional com avaliação pendente é bloqueado ao tentar candidatar-se; resposta tem mensagem clara + identificador do turno pendente.
- [ ] **CA-2:** Contratante com avaliação pendente é bloqueado ao publicar nova vaga; idem mensagem + turno pendente.
- [ ] **CA-3:** Sem pendência, as ações fluem normalmente (sem regressão de candidatura/publicação da W26/W28).
- [ ] **CA-4:** Fail-secure: erro ao consultar pendência não libera a ação. RBAC preservado (ADR-007).
- [ ] **CA-5:** Cobertura ≥ 80% no código novo; cenários: com pendência (bloqueia, os 2 papéis), sem pendência (libera), múltiplas pendências, e falha de consulta (bloqueia). E2E/feature test do bloqueio nos 2 papéis.
- [ ] **CA-6:** Deploy homologação verificado.

## Fora de escopo

- UX do bloqueio no front (STORY-088). Motor de XP (STORY-085).

## Padrões de qualidade exigidos

`quality-standards.md`. ≥80%; fail-secure; TDD; mensagens sem dado sensível.

## Dependências

- **Bloqueada por:** STORY-085 (consulta a pendência de avaliação).
- **Bloqueia:** STORY-088 (UX do bloqueio), STORY-089 (validação).

## Decisões já tomadas (não as reabra)

- ADR-019 (ponto do gate), PDR-005, ADR-007 (RBAC).

## Liberdade técnica do agente

Decide: implementação concreta do gate na camada decidida, design dos testes, forma da resposta de bloqueio. NÃO decide: que as ações são bloqueadas (PDR-005), o ponto do gate (ADR-019), CAs.

## Definição de Pronto (DoD)

- [ ] CAs passam; testes verdes; cobertura atingida.
- [ ] Pipeline verde; deploy homolog verificado.
- [ ] `index.json` atualizado: status = `done`. "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

`docs/skills/po/references/agent-task-format.md` + skill `programador`.

## Notas do agente (preenchido durante/após execução)

### Decisões / Descobertas / Bloqueios
- 
