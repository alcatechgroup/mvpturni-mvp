---
story_id: STORY-085
slug: backend-modelo-motor-xp-score-nivel
title: "Backend — modelo de avaliação + motor de XP/score + subida de nível + evento de pendência"
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
estimated_session_size: L
produces_idr: null
---

# STORY-085 — Backend: modelo de avaliação + motor de XP/score/nível

> **Para o agente que vai executar:** leia a estória inteira. Implementa **ADR-019** (STORY-083). TDD: vermelho antes de verde. Migração reversível.

## Contexto (por que esta estória existe)

É o coração transacional do EPIC-004: persistir a avaliação recíproca e fazer o motor de XP/score/nível andar a cada evento. Sem isso, o ciclo do turno não fecha e a reputação não evolui.

- Decisão: ADR-019 (modelo, eventos, idempotência do motor).
- Spec: `domain/niveis-e-score.md` (tabela de XP, limites de nível 500/1000/3000, score como média com leve viés recente), `flows/avaliacao-reciproca.md`.

## O quê (objetivo desta estória)

- Migração + modelo de **avaliação** (estrelas 1–5 obrigatória, comentário opcional, direção, linkage com turno, timestamps; unicidade 1 por direção/turno) conforme ADR-019.
- Evento **`turno_finalizado`** cria as **duas pendências** de avaliação (uma por direção).
- Endpoint(s) de API para **submeter avaliação** (autenticado, RBAC, valida estrelas obrigatórias, idempotente por direção/turno).
- **Motor de XP/score/nível**: ao `avaliacao_recebida`, recalcula XP (tabela da spec), score (média com leve viés recente) e **sobe nível automaticamente** ao cruzar 500/1000/3000; XP pode ficar negativo sem rebaixar.
- Expor no perfil (API) score, nível, XP atual e XP até o próximo nível; depoimentos (comentários não-vazios) por direção.

## Por quê (valor para o usuário)

Faz a avaliação virar progressão real: XP sobe, nível sobe, score público atualiza — a evolução do produto a cada turno.

## Critérios de aceite

- [ ] **CA-1:** Migração reversível cria o modelo de avaliação conforme ADR-019; unicidade 1 avaliação por direção/turno (tentativa duplicada rejeitada).
- [ ] **CA-2:** `turno_finalizado` gera as 2 pendências de avaliação (idempotente — reprocessar não duplica).
- [ ] **CA-3:** Submeter avaliação valida estrelas obrigatórias (1–5), comentário opcional, RBAC (só quem participou do turno avalia, na direção correta), e persiste imutável.
- [ ] **CA-4:** `avaliacao_recebida` recalcula XP conforme a tabela da spec (turno +30; 5★ +10; 4★ +3; 3★ 0; 1–2★ −5) e atualiza score (média com viés recente).
- [ ] **CA-5:** Nível sobe automaticamente ao cruzar 500/1000/3000; XP negativo não rebaixa (spec). Idempotência: reprocessar o mesmo evento não soma XP em dobro.
- [ ] **CA-6:** API do perfil expõe score (1 casa), nível, XP atual, XP até o próximo nível e depoimentos por direção (comentário não-vazio, mais recentes primeiro).
- [ ] **CA-7:** Cobertura ≥ 80% no código novo; **núcleo (motor de XP/score/nível) ≥ 98%** com caminho feliz + bordas (limites de nível, XP negativo, 1–2★) + inválidos (estrela fora de 1–5, direção errada, duplicata). E2E/feature test do fluxo submeter→XP/score/nível.
- [ ] **CA-8:** Deploy homologação verificado.

## Fora de escopo

- Gate bloqueante (STORY-086). Telas (STORY-087/088). Motor de penalidade/decay (PDR-007).

## Padrões de qualidade exigidos

`quality-standards.md`. ≥80% geral / ≥98% núcleo; migração reversível e testada; TDD; sem PII em log.

## Dependências

- **Bloqueada por:** STORY-083 (ADR-019 `accepted`).
- **Bloqueia:** STORY-086 (gate consulta pendência), STORY-087/088 (telas consomem API), STORY-089 (validação).

## Decisões já tomadas (não as reabra)

- ADR-019, ADR-015 (Turno), ADR-007 (RBAC), ADR-018 (UUID), PDR-005. Valores de XP da spec (ajustáveis em operação — o que importa é o motor existir).

## Liberdade técnica do agente

Decide: estrutura do service/motor, listeners, design dos testes, forma do cálculo do viés recente (dentro da spec). NÃO decide: campos do modelo (ADR-019), valores de XP/limites (spec), CAs.

## Definição de Pronto (DoD)

- [ ] CAs passam; testes verdes; cobertura atingida; migração reversível.
- [ ] Pipeline verde; deploy homolog verificado.
- [ ] `index.json` atualizado: status = `done`. "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

`docs/skills/po/references/agent-task-format.md` + skill `programador`.

## Notas do agente (preenchido durante/após execução)

### Decisões / Descobertas / Bloqueios
- 
