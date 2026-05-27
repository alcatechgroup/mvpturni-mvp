---
report_date: 2026-05-27
sprint_id: SPRINT-2026-W22
wave: WAVE-2026-01
audience: humano-stakeholder
event: abertura-de-sprint
---

# Status Turni — abertura da SPRINT-2026-W22 (2026-05-27)

> Delta curto sobre `status-2026-05-26-epic-000-decomposto.md`. Foco específico: a primeira sprint do EPIC-000 foi aberta hoje.

## TL;DR (3 linhas)

- **O que mudou**: SPRINT-2026-W22 aberta (2026-05-27 a 2026-06-07) com escopo médio — 5 spikes do Arquiteto + DDR-001 do Designer = 6 estórias, todas paralelizáveis em boa parte.
- **Goal do sprint**: fundação documental do EPIC-000 fechada — 9 ADRs aceitas (ADR-000 a ADR-008) + DDR-001 aceito.
- **Próxima entrega visível ao usuário**: nenhuma nesta sprint (deliberação documental). Visível ao **usuário externo** continua sendo o entregável do EPIC-000 inteiro (~ 2026-06-09 estimado).

## Sprint corrente

- **Sprint:** SPRINT-2026-W22 (de 2026-05-27 a 2026-06-07, 12 dias corridos).
- **Goal:** "fundação documental do EPIC-000 fechada — 9 ADRs aceitas + DDR-001 aceito".
- **Estórias:** 0 done / 0 in_progress / 0 blocked / 6 ready.
- **Path:** `docs/project-state/sprints/SPRINT-2026-W22.md`.

### Estórias no sprint

| ID | Título | Papel | Tamanho | Bloqueada por |
|---|---|---|---|---|
| STORY-001 | Spike — stack + topologia + monorepo | arquiteto | M | — |
| STORY-002 | Spike — hospedagem + IaC + deploy | arquiteto | M | STORY-001 |
| STORY-003 | Spike — Pagar.me + habitualidade | arquiteto | M | STORY-001 |
| STORY-004 | Spike — auth base + observabilidade | arquiteto | M | STORY-001, STORY-002 |
| STORY-005 | Spike — ADR-000 retroativo PostgreSQL | arquiteto | S | — |
| STORY-010 | DDR-001 — Fundação do Design System | designer | M | — |

### Ordem prevista

```
Dia 1 (paralelas, sem bloqueio):       STORY-001  |  STORY-005  |  STORY-010
Após STORY-001 aceita pelo Alexandro:  STORY-002  |  STORY-003
Após STORY-001 + STORY-002 aceitas:    STORY-004
```

### Fora do sprint (vão para SPRINT-2026-W23)

STORY-006 (setup local), STORY-007 (pipeline CI/CD), STORY-008 (hello world WebApp), STORY-009 (hello world Backoffice), STORY-011 (validação) — todas permanecem `ready` mas sem `sprint_id` atribuído.

## Onda atual

- **Onda:** WAVE-2026-01 — "Ciclo completo do turno em homologação".
- **Progresso da onda:** 0 de 6 épicos `done`. EPIC-000 com 6 de 11 estórias agora alocadas em sprint; 5 aguardam W23.
- **Métrica-alvo da onda:** inalterada (≥ 1 turno completo executado em homologação por dia útil ao final da onda).

## O que o usuário pode ver agora em homologação

Inalterado: nada ainda — ambientes de homologação são o entregável do EPIC-000, que se materializa a partir da W23. O protótipo em `docs/prototipo/` segue como referência visual viva.

## Qualidade

Não aplicável nesta sprint — saída esperada são ADRs/DDR (deliberação documental, `target_role: arquiteto` / `target_role: designer`), com exceções de cobertura unitária/E2E declaradas em cada estória conforme `quality-standards.md` e `story-craft.md` seção "Spikes e cobertura de testes".

Padrões herdados de qualidade (cobertura ≥ 80% / ≥ 98%, E2E em browser real) ficam ativos a partir de STORY-006 em diante — sprint W23.

## Decisões aguardando Alexandro

Esta é a seção crítica para esta sprint — risco principal mapeado.

- **9 ADRs propostas chegarão para sua aprovação** ao longo da sprint (saídas das 5 spikes):
  - ADR-000 (PostgreSQL retroativo — saída de STORY-005)
  - ADR-001, ADR-002, ADR-003 (stack/topologia/monorepo — saída de STORY-001)
  - ADR-004 (hospedagem/IaC/deploy — saída de STORY-002)
  - ADR-005, ADR-006 (Pagar.me / habitualidade — saída de STORY-003)
  - ADR-007, ADR-008 (auth / observabilidade — saída de STORY-004)
- **1 DDR proposto chegará** para sua aprovação:
  - DDR-001 (fundação do Design System — saída de STORY-010)
- **Cadência sugerida**: janela diária de ~30 min para revisar artefatos em `status: in_review`; aprovação ou pedido de revisão em ≤ 24h. Sem isso, STORY-002/003/004 ficam bloqueadas esperando ADR-001.

Nenhum PDR aguardando — todos os 12 PDRs vigentes estão `accepted`.

## Bloqueios e riscos abertos

Riscos do sprint (também em `SPRINT-2026-W22.md` com mitigação/owner):

1. **Atraso nas aprovações humanas** bloqueia estórias dependentes — média/alto.
2. **STORY-001 descobre que stack escolhida é ruim** para PWA/PostgreSQL/Pagar.me — baixa/alto.
3. **STORY-003 (Pagar.me + habitualidade) descobre necessidade de quebrar** em duas estórias — média/médio.
4. **STORY-010 (DDR-001) atrasa** e impacta STORY-008/009 da W23 — baixa/médio.
5. **Alexandro nos 5 papéis** cria sobreposição cognitiva — alta/médio.

Riscos da onda (herdados de `status-2026-05-26-wave-open.md`) seguem ativos, sem mudança de probabilidade/impacto nesta abertura.

Nenhum bloqueio operacional ativo.

## Olhando à frente

### Próximos 7 dias

- **Dia 1-2**: 3 frentes paralelas começando (STORY-001, STORY-005, STORY-010). Primeiras ADRs em `proposed` esperadas até dia 3.
- **Dia 3-7**: ondas de aprovação humana de Alexandro destravando STORY-002, STORY-003, STORY-004. Designer convergindo screen spec após sync com Programador (mesmo que o Programador entre só na W23, o sync rápido pode ser feito por escrito).
- **Mid-sprint check em ~2026-06-01 (segunda)**: PO verifica se o goal vai bater. Se 3+ ADRs ainda em `proposed` sem decisão, intensifica revisão.

### Próximos 8-14 dias

- **Fechamento da W22 em 2026-06-07 (domingo)**: review + retro curta no próprio `SPRINT-2026-W22.md`; status report de fechamento.
- **Abertura da SPRINT-2026-W23 em 2026-06-08 (segunda)**: STORY-006/007/008/009/011 entram. Goal previsto: "hello world em ambas as homologações deployado por tag, com 3 deploys consecutivos verdes ≤ 10 min — fechar EPIC-000".

### Próximos marcos previstos

- **2026-06-07** — fechamento da SPRINT-2026-W22 com 9 ADRs + DDR-001 aceitos (alvo).
- **~ 2026-06-09** — fim previsto do EPIC-000 (entregável visível externamente: as duas URLs no ar com health-check verde). Estimativa orientativa — depende do throughput real da SPRINT-2026-W23.
- **~ 2026-07-07** — fim previsto do EPIC-001.

## Apêndice — links rápidos

- Índice do projeto: `docs/project-state/index.json`
- Sprint atual: `docs/project-state/sprints/SPRINT-2026-W22.md`
- EPIC-000: `docs/project-state/epics/EPIC-000-foundation/epic.md`
- Onda atual: `docs/project-state/roadmap/current-wave.md`
- Status anterior (EPIC-000 decomposto): `docs/project-state/reports/status-2026-05-26-epic-000-decomposto.md`
- Status de abertura da onda: `docs/project-state/reports/status-2026-05-26-wave-open.md`
- Skill do Arquiteto (para a próxima troca de papel): `docs/skills/arquiteto/SKILL.md`
- Skill do Designer (para a próxima troca de papel): `docs/skills/designer/SKILL.md`
