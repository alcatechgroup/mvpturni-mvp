---
report_date: 2026-05-26
sprint_id: null
wave: WAVE-2026-01
audience: humano-stakeholder
event: abertura-de-onda
---

# Status Turni — abertura da WAVE-2026-01 (2026-05-26)

## TL;DR (3 linhas)

- **Onde estamos**: WAVE-2026-01 aberta com 6 épicos (Foundation → Cadastro → Vaga → PIN/Pix → Avaliação → Disputa mínima) cobrindo o ciclo completo do turno em homologação.
- **O que mudou desde o último relatório**: encerrada a fundação de produto; aberta a onda com PDR-011 registrando escopo; EPIC-000 Foundation `ready` para entrar em sprint; demais épicos `draft` com epic.md esqueleto.
- **Próxima entrega visível ao usuário**: ao fim do EPIC-000 (estimativa: ~2 semanas), `app.homolog.turni.com.br` e `admin.homolog.turni.com.br` no ar com hello world + health-check; pipeline deployando automático em ambas em cada merge.

## Onda atual

- **Onda**: WAVE-2026-01 — "Ciclo completo do turno em homologação".
- **Objetivo**: demonstrar que os 3 pilares (Match IA + PIN Bilateral + Pix em 15 min) funcionam ponta a ponta no caminho feliz, em homologação, com Pagar.me sandbox.
- **Métrica-alvo**: ≥ 1 turno completo executado em homologação por dia útil ao final da onda (com PIN, Pix sandbox e avaliação recíproca registrada).
- **Estimativa de duração**: ~2,5 meses (orientativo).
- **Progresso**: 0 de 6 épicos concluídos (0%).
- **Roadmap detalhado**: `docs/project-state/roadmap/current-wave.md`.

## Épicos

### Em andamento

Nenhum.

### Próximo a entrar em sprint

| Épico | Status | Próximo marco |
|---|---|---|
| **EPIC-000** Foundation | `ready` | Abertura da SPRINT-2026-W22 com STORY-001 (spike Arquiteto: stack + topologia + monorepo) |

### Demais épicos da onda (`draft`)

- **EPIC-001** Cadastro e aprovação — esqueleto criado; primeira estória será o **spike jurídico/contábil** (templates de contrato PF e MEI/PJ + mapa tributário).
- **EPIC-002** Vaga, feed e candidatura — esqueleto.
- **EPIC-003** Aceite, PIN e Pix — esqueleto (XL, mais arriscado da onda; depende de Pagar.me sandbox).
- **EPIC-004** Avaliação recíproca — esqueleto.
- **EPIC-005** Disputa mínima via backoffice — esqueleto (fecha a onda).

## Sprint corrente

- Nenhum sprint aberto. Próximo: **SPRINT-2026-W22** (a abrir).

## O que o usuário pode ver agora em homologação

Nada ainda. Ambientes de homologação são o **entregável do EPIC-000**.

O **protótipo navegável** em `docs/prototipo/` segue como referência viva visual.

## Qualidade

Não aplicável ainda — primeira linha de código não foi escrita. Padrões herdados (cobertura ≥ 80% geral, ≥ 98% em núcleo, E2E obrigatório) ficam ativos a partir da primeira estória do EPIC-000.

## Decisões registradas no período

- **PDR-011** — Escopo da WAVE-2026-01 (objetivo, sequência de épicos, fora de escopo, hipótese central, métrica-alvo).
- Roadmap atual versionado em `current-wave.md`; rascunho da próxima onda em `next-wave.md`.

Nenhum ADR ou DDR ainda — primeiros virão como saída das estórias do EPIC-000 (spikes do Arquiteto + DDR-001 do Designer).

## Bloqueios e riscos abertos

Nenhum bloqueio operacional (ainda não há sprint).

**Riscos confirmados na abertura da onda**:

1. **Integração Pagar.me em sandbox** — variabilidade do provedor pode atrasar EPIC-003.
   - **Probabilidade**: média. **Impacto**: alto.
   - **Mitigação**: spike de Arquiteto cobre Pagar.me no EPIC-000 (ADR-005, alto nível), antes de implementar. Em paralelo, manter mock dedicado em container que permite seguir mesmo se sandbox cair.
2. **Templates de contrato eletrônico (dependência externa)** — calendário de advogado/contador pode estourar.
   - **Probabilidade**: média. **Impacto**: alto (bloqueia EPIC-001 se atrasar).
   - **Mitigação**: spike jurídico é primeira estória do EPIC-001, executável em paralelo com setup técnico restante do EPIC-000. Iniciar contato com advogado/contador **agora**, durante o EPIC-000.
3. **Performance da consulta de habitualidade (PDR-002)** — pode virar gargalo se base crescer.
   - **Probabilidade**: baixa no MVP (volume pequeno). **Impacto**: médio.
   - **Mitigação**: ADR-006 (estratégia de habitualidade) decidido no spike do EPIC-000.
4. **Alexandro nos 5 papéis cria gargalo cognitivo** — alternar entre PO, Arquiteto, Designer, Programador e Validador na mesma semana.
   - **Probabilidade**: alta. **Impacto**: médio.
   - **Mitigação**: separação clara por sessão; declarar troca de papel explicitamente; cada artefato (PDR/ADR/DDR/IDR) registrado no local correto.

## Olhando à frente

### Próximos 7-14 dias

- **Abrir SPRINT-2026-W22** com 4-5 estórias do EPIC-000 (spikes do Arquiteto: stack, hospedagem, monorepo, Pagar.me alto nível, habitualidade, autenticação, observabilidade, ADR-000 retroativo do PostgreSQL).
- **Iniciar contato externo** com advogado trabalhista e contador para destravar o spike jurídico que vira primeira estória do EPIC-001.
- **Designer começa DDR-001** em paralelo: fundação do Design System (tokens, tipografia, paleta) que será aplicada no EPIC-001.
- **Aprovar 9 ADRs** propostos pelo Arquiteto ao longo da SPRINT-2026-W22 (Alexandro como aprovador).

### Decisões aguardando Alexandro

- Nenhuma decisão de produto aguardando.
- Quando o Arquiteto propor ADRs no spike inicial, cada uma exige aprovação humana explícita.
- Quando o Designer propor DDR-001, exige aprovação humana explícita.

### Riscos abertos

Detalhados acima na seção "Bloqueios e riscos".

### Próximos marcos previstos

- **~ 2026-06-09** — fim previsto do EPIC-000 com ADRs aceitos, hello world em ambas as homologações, pipelines automáticos. Primeiro **entregável visível** da onda.
- **~ 2026-07-07** — fim previsto do EPIC-001 com cadastro+aprovação fim a fim em homologação e templates de contrato aprovados.
- **~ 2026-07-28** — fim previsto do EPIC-002 com vaga publicada e candidato ranqueado por match.
- **~ 2026-08-18** — fim previsto do EPIC-003 com ciclo completo do turno + Pix sandbox confirmado. **Marco crítico da onda** — hipótese central validada.
- **~ 2026-08-25** — fim previsto do EPIC-004 com avaliação recíproca + trilha de níveis.
- **~ 2026-09-01** — fim previsto do EPIC-005 com disputa mínima via backoffice. **Fechamento da onda**.

Estimativas orientativas, não compromissos rígidos.

## Apêndice — links rápidos

- Índice do projeto: `docs/project-state/index.json`
- Onda atual: `docs/project-state/roadmap/current-wave.md`
- Próxima onda (rascunho): `docs/project-state/roadmap/next-wave.md`
- PDR-011 (escopo): `docs/project-state/decisions/pdr/PDR-011-escopo-da-wave-2026-01.md`
- EPIC-000 Foundation: `docs/project-state/epics/EPIC-000-foundation/epic.md`
- Visão de produto: `docs/project-state/product/vision.md`
- Personas: `docs/project-state/product/personas.md`
- Métrica de norte: `docs/project-state/product/north-star.md`
- Status anterior (fundação): `docs/project-state/reports/status-2026-05-26.md`
