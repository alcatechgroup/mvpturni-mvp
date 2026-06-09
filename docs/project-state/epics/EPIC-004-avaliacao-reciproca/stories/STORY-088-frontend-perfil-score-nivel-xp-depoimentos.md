---
story_id: STORY-088
slug: frontend-perfil-score-nivel-xp-depoimentos
title: "Frontend — perfil com score/nível/XP/depoimentos + UX do gate bloqueante"
epic_id: EPIC-004
sprint_id: SPRINT-2026-W30
type: implementation
target_role: programador
requires_design: true
design_screen_id: SCREEN-STORY-084-avaliacao-e-perfil
status: ready
owner_agent: null
created_at: 2026-06-09
updated_at: 2026-06-09
estimated_session_size: M
produces_idr: null
---

# STORY-088 — Frontend: perfil (score/nível/XP/depoimentos) + UX do gate

> **Para o agente que vai executar:** leia a estória inteira. Fecha a superfície visível do EPIC-004. TDD + E2E.

## Contexto (por que esta estória existe)

A reputação só vira valor quando é **visível**: o perfil precisa mostrar score público, nível/badge, XP até o próximo nível e depoimentos; e o bloqueio (STORY-086) precisa de uma UX clara que leve ao turno pendente.

- Specs: `SCREEN-STORY-084-avaliacao-e-perfil` (perfil + UX do gate), DDR-004 (visibilidade de depoimentos).
- API: perfil expõe score/nível/XP/depoimentos (STORY-085); bloqueio retorna mensagem + turno pendente (STORY-086).

## O quê (objetivo desta estória)

- Atualizar o **perfil** (profissional e contratante — reciprocidade): score público (1 casa, ex. 4.9★), nível + badge (Iniciante/Confiável/Destaque/Elite), XP atual + XP até o próximo nível, depoimentos (até 3 mais recentes, conforme DDR-004).
- **UX do gate bloqueante**: ao ser bloqueado (candidatar/publicar), mostrar mensagem clara + **link para o turno pendente** que abre a tela de avaliação (STORY-087) dentro do shell.
- Estados vazio/erro/loading reusando o DS (STORY-079).

## Por quê (valor para o usuário)

Reputação visível motiva a operar bem; o bloqueio com saída clara transforma uma fricção em um próximo passo óbvio.

## Critérios de aceite

- [ ] **CA-1:** Perfil do profissional mostra score (1 casa), nível + badge, XP atual e XP até o próximo nível, e depoimentos (até 3, conforme DDR-004) — fiel ao protótipo.
- [ ] **CA-2:** Perfil do contratante (acessível pelo profissional) mostra score + depoimentos (reciprocidade), sem nível (MVP).
- [ ] **CA-3:** Subida de nível reflete no perfil em ≤1s após avaliação recebida (métrica do épico) — verificável em homolog.
- [ ] **CA-4:** UX do gate: tentar candidatar-se/publicar com pendência mostra mensagem clara + link que abre a avaliação do turno pendente no shell.
- [ ] **CA-5:** Estados vazio (sem avaliações/depoimentos), erro (com retry) e loading (skeleton) padronizados (DS).
- [ ] **CA-6:** Cobertura ≥ 80% no código novo; **E2E** cobre: perfil exibe score/nível/depoimentos; bloqueio ao candidatar/publicar leva ao turno pendente.
- [ ] **CA-7:** Deploy homologação verificado.

## Fora de escopo

- Telas de captura da avaliação (STORY-087). Backend (085/086). Dívida de a11y parqueada (só não regredir o piso AA).

## Padrões de qualidade exigidos

`quality-standards.md`. ≥80%; E2E integration_test; pt-BR/24h; AA por construção.

## Dependências

- **Bloqueada por:** STORY-087 (telas de avaliação — o gate linka para elas), STORY-085 (API do perfil), STORY-086 (resposta do bloqueio).
- **Bloqueia:** STORY-089 (validação).

## Decisões já tomadas (não as reabra)

- DDR-004 (depoimentos), DDR-003 (shell), ADR-019, PDR-005, spec de níveis/score.

## Liberdade técnica do agente

Decide: estrutura dos widgets do perfil, componente de badge/nível, design dos testes. NÃO decide: visibilidade de depoimentos (DDR-004), limites de nível (spec), CAs.

## Definição de Pronto (DoD)

- [ ] CAs passam; widget + E2E verdes; cobertura atingida.
- [ ] Pipeline verde; deploy homolog verificado (PO confirma visualmente).
- [ ] `index.json` atualizado: status = `done`. "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

`docs/skills/po/references/agent-task-format.md` + skill `programador`. Designer revisa contra o protótipo.

## Notas do agente (preenchido durante/após execução)

### Decisões / Descobertas / Bloqueios
- 
