---
story_id: STORY-087
slug: frontend-telas-avaliacao-reciproca
title: "Frontend — telas de avaliação recíproca (estrelas obrigatórias + comentário) no shell"
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

# STORY-087 — Frontend: telas de avaliação recíproca

> **Para o agente que vai executar:** leia a estória inteira. Implementa as SCREEN specs da STORY-084 dentro do shell (DDR-003). TDD + E2E (integration_test).

## Contexto (por que esta estória existe)

Com modelo/API (STORY-085) e specs/protótipo (STORY-084) prontos, o WebApp precisa das duas telas onde cada lado avalia o outro após o turno `finalizado`.

- Specs: `design/screens/SCREEN-STORY-084-avaliacao-e-perfil/` (protótipo = fonte de verdade visual).
- API: endpoints de submissão e de pendências (STORY-085).

## O quê (objetivo desta estória)

Implementar em Flutter, dentro do shell:
- Tela **profissional → contratante**: estrelas obrigatórias (1–5) + comentário opcional + submeter.
- Tela **contratante → profissional**: idem.
- Acesso a partir do turno `finalizado` e do ponto de bloqueio (link para o turno pendente).
- Estados vazio/erro/loading reusando o DS (STORY-079); microcopy pt-BR (DDR-002).

## Por quê (valor para o usuário)

É onde o usuário efetivamente fecha o ciclo — uma interação rápida e clara para avaliar e destravar a próxima ação.

## Critérios de aceite

- [ ] **CA-1:** Tela profissional→contratante: estrelas obrigatórias (não submete com 0), comentário opcional, submissão chama a API e trata sucesso/erro (retry).
- [ ] **CA-2:** Tela contratante→profissional: idem.
- [ ] **CA-3:** As telas habitam o shell (DDR-003), responsivas nos dois tamanhos; alcançáveis pelo turno pendente (sem digitar rota); fiéis ao protótipo da STORY-084.
- [ ] **CA-4:** Erro de submissão é recuperável ("tentar de novo"); sucesso confirma e retorna ao contexto, refletindo que a pendência foi resolvida.
- [ ] **CA-5:** RBAC: cada papel só vê/submete a sua direção (fail-secure).
- [ ] **CA-6:** Cobertura ≥ 80% no código novo; **E2E** (integration_test, Chrome headless) cobre, por papel: abrir a tela do turno pendente, tentar submeter sem estrela (bloqueado), submeter com estrela (sucesso).
- [ ] **CA-7:** Deploy homologação verificado.

## Fora de escopo

- Perfil (score/nível/XP/depoimentos) + UX do gate — STORY-088. Backend — STORY-085/086.
- Dívida de a11y parqueada — só não regredir o piso AA dos componentes do DS.

## Padrões de qualidade exigidos

`quality-standards.md`. ≥80%; E2E integration_test; pt-BR/24h; AA por construção (DS).

## Dependências

- **Bloqueada por:** STORY-084 (specs/protótipo) e STORY-085 (API).
- **Bloqueia:** STORY-088 (perfil/UX do gate parte daqui) e STORY-089 (validação).

## Decisões já tomadas (não as reabra)

- DDR-003 (shell), DDR-004 (depoimentos — afeta o perfil, não a captura), ADR-019, PDR-005, IDR-010/011/021 (E2E).

## Liberdade técnica do agente

Decide: estrutura dos widgets, componente de rating (se DDR-004/Designer promoveu um ao DS, consome), design dos testes. NÃO decide: layout (protótipo STORY-084), obrigatoriedade (PDR-005), CAs.

## Definição de Pronto (DoD)

- [ ] CAs passam; widget + E2E verdes; cobertura atingida.
- [ ] Pipeline verde; deploy homolog verificado (PO confirma visualmente nos 2 papéis).
- [ ] `index.json` atualizado: status = `done`. "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

`docs/skills/po/references/agent-task-format.md` + skill `programador`. Designer revisa contra o protótipo.

## Notas do agente (preenchido durante/após execução)

### Decisões / Descobertas / Bloqueios
- 
