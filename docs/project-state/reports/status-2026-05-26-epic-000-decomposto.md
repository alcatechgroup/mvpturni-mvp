---
report_date: 2026-05-26
sprint_id: null
wave: WAVE-2026-01
audience: humano-stakeholder
event: epic-000-decomposto
---

# Status Turni — EPIC-000 decomposto em 11 estórias (2026-05-26)

> Delta curto sobre o snapshot anterior (`status-2026-05-26-wave-open.md`). Mesma data; foco específico: o Fluxo C do EPIC-000 foi executado nesta sessão.

## TL;DR (3 linhas)

- **O que mudou desde o snapshot de abertura da onda**: EPIC-000 Foundation foi decomposto em 11 estórias detalhadas e todas estão em `status: ready` no `index.json`, com `target_role`, dependências e CAs testáveis preenchidos.
- **Onde estamos**: WAVE-2026-01 segue ativa, sem sprint aberto ainda; EPIC-000 está com `epic.status: ready` e `story_ids` populado (11 entradas em `stories[]`). Pronto para abrir SPRINT-2026-W22.
- **Próxima entrega visível ao usuário**: inalterada — ao fim do EPIC-000 (estimativa ~2 semanas após início da SPRINT-2026-W22), `app.homolog.turni.com.br` e `admin.homolog.turni.com.br` no ar com hello world + health-check, pipeline deployando automático em cada merge.

## O que foi feito nesta sessão (Fluxo C do EPIC-000)

| # | Estória | Tipo | Papel | Status | Saída esperada |
|---|---|---|---|---|---|
| 1 | Spike: stack + topologia + monorepo | spike | arquiteto | ready | ADR-001, ADR-002, ADR-003 |
| 2 | Spike: hospedagem + IaC + deploy | spike | arquiteto | ready | ADR-004 |
| 3 | Spike: Pagar.me alto nível + habitualidade | spike | arquiteto | ready | ADR-005, ADR-006 |
| 4 | Spike: auth base + observabilidade mínima | spike | arquiteto | ready | ADR-007, ADR-008 |
| 5 | Spike: ADR-000 retroativo PostgreSQL | spike | arquiteto | ready | ADR-000 |
| 6 | Setup repo + ambiente local 1 comando | enablement | programador | ready | repo + `up` em 1 comando |
| 7 | Pipeline CI/CD + deploy automático | enablement | programador | ready | merge `main` → tag → deploy ≤ 10 min |
| 8 | Hello world WebApp (requires_design) | implementation | programador | ready | `app.homolog.turni.com.br` + `/health` |
| 9 | Hello world Backoffice | implementation | programador | ready | `admin.homolog.turni.com.br` + `/health` |
| 10 | DDR-001: fundação do Design System | implementation | designer | ready | DDR-001 + tokens + screen spec de STORY-008 |
| 11 | Validação final do EPIC-000 | validation | validador | ready | `validation/report.md` com veredito |

Cada estória contém: contexto, referências por caminho (especificação + PDRs + ADRs/DDRs aplicáveis), CAs testáveis (caminho feliz + desvios), padrões de qualidade (com exceções declaradas para spikes/validação), dependências (`blocked_by` / `blocks`), liberdade técnica vs decisões já tomadas, DoD e protocolo do agente. Definition of Ready conferido para cada uma antes de marcar `ready`.

## Sequência de execução prevista (paralelizável)

```
Sprint 1 (paralelizável a partir do início):
  ├─► STORY-001 (spike stack)         ─┐
  ├─► STORY-005 (ADR-000 retroativo)   │  ◄── independentes, paralelas
  └─► STORY-010 (DDR-001 designer)    ─┘

Sprint 1 ou 2 (após STORY-001 aceita):
  ├─► STORY-002 (hospedagem)
  ├─► STORY-003 (Pagar.me + habitualidade)
  └─► STORY-004 (auth + obs)

Sprint 2 (após STORY-001 a 005 aceitas):
  ├─► STORY-006 (setup local)
  └─► STORY-007 (pipeline + IaC) ◄── depende de STORY-006

Sprint 2 ou 3 (após STORY-007 + STORY-010):
  ├─► STORY-008 (hello world WebApp, paralelo Designer↔Programador)
  └─► STORY-009 (hello world Backoffice)

Sprint final do épico:
  └─► STORY-011 (validação)
```

## Estado do `index.json`

- `stories[]`: 11 entradas novas, todas em `status: ready`.
- `epics[id == EPIC-000].story_ids`: populado com STORY-001 → STORY-011 na ordem.
- `epics[id == EPIC-000].status`: permanece `ready` (épico inteiro; estórias individuais é que avançam ao serem executadas).
- `project.phase`: `wave-2026-01-aberta-epic-000-decomposto`.
- `project.current_sprint`: ainda `null` — SPRINT-2026-W22 não foi aberta nesta sessão.
- Invariantes (`indexing.md`) conferidas: 1, 2, 3, 4 atendidas; 9 (`requires_design == true` exige screen spec antes de `in_review`) aplicável apenas a STORY-008, com plano declarado em STORY-010 CA-10/11; 11 e 12 entram quando DDR-001 e screen spec passarem para `accepted`/`ready`.

## Qualidade do detalhamento

- **DoR atendida** em cada estória (cobertura, dependências, ADRs/PDRs citados, liberdade vs decisões já tomadas, DoD, protocolo).
- **Exceções declaradas** onde aplicável: spikes e validação não escrevem código de produção; cobertura unitária/E2E marcadas como `N/A` com referência ao `story-craft.md` seção "Spikes e cobertura de testes" e `quality-standards.md`.
- **Tamanho L** apenas em STORY-007 (pipeline + IaC + observabilidade ativa), justificado por incoesão se fatiada antes de existir um deploy completo (CI sem CD não destrava; CD sem IaC não tem onde deployar).
- **`requires_design: true`** apenas em STORY-008. STORY-009 fica sem screen spec exigido (placeholder mínimo aplica tokens base de DDR-001 sem layout administrativo elaborado — escopo justificado nas Notas da estória).

## Decisões registradas no período

Nenhum PDR/ADR/DDR/IDR novo nesta sessão — apenas decomposição em estórias. Decisões surgirão como **saída** das estórias quando executadas:

- 9 ADRs propostas (ADR-000 a ADR-008) virão de STORY-001 a STORY-005.
- 1 DDR (DDR-001) virá de STORY-010.
- IDRs surgirão localmente nas estórias 006, 007, 008, 009 conforme decisões transversais de baixo nível.

Cada uma exige aprovação humana explícita do Alexandro antes de transitar para `accepted` (`indexing.md` invariantes 11, e disciplina geral de ADR/DDR).

## Bloqueios e riscos abertos

- **Sem novos bloqueios** introduzidos por esta sessão.
- **Riscos da abertura da onda** (1 a 4 em `status-2026-05-26-wave-open.md`) permanecem ativos. O risco #4 ("Alexandro nos 5 papéis") fica mais saliente agora que o EPIC-000 entra em sprint: as 11 estórias cobrem todos os 5 papéis (PO já entregou; Arquiteto, Designer, Programador e Validador serão acionados em sequência/paralelo conforme a sequência acima).
- **Risco específico de paralelismo**: STORY-007 (tamanho L) é o ponto de tensão maior do épico. Sinal de revisão: se ao executar virar > 4h, o agente deve escalar e considerar quebrar.

## Olhando à frente

### Próximos 7–14 dias

- **Abrir SPRINT-2026-W22** (provavelmente em 2026-05-27 ou 2026-05-28), incluindo no mínimo STORY-001, STORY-005 e STORY-010 (as 3 independentes paralelizáveis).
- **Aprovar 9 ADRs** propostas conforme cada spike for fechando — cada uma exige `approved_by: Alexandro` explícito.
- **Aprovar DDR-001** ao final de STORY-010 — também exige aprovação humana explícita.
- **Designer + Programador sync** antes de STORY-008 entrar em `in_progress` (`requires_design: true` exige rabisco + ≤ 15 min de alinhamento; ver `designer/references/collaboration-with-developer.md`).

### Decisões aguardando Alexandro

- Nenhuma de produto **agora**. As 9 ADRs e o DDR-001 virão ao longo da SPRINT-2026-W22 e cada uma exigirá aprovação explícita.

### Próximos marcos previstos

- **~ 2026-06-09** — fim previsto do EPIC-000 (inalterado). Primeiro **entregável visível** da onda: as duas URLs de homologação operantes + métrica primária (3 deploys ≤ 10 min) atestada pelo validador em STORY-011.

## Apêndice — links rápidos

- Índice do projeto: `docs/project-state/index.json`
- EPIC-000 (atualizado nesta sessão): `docs/project-state/epics/EPIC-000-foundation/epic.md`
- Estórias do EPIC-000: `docs/project-state/epics/EPIC-000-foundation/stories/` (11 arquivos)
- Status anterior (abertura da onda): `docs/project-state/reports/status-2026-05-26-wave-open.md`
- Roadmap da onda: `docs/project-state/roadmap/current-wave.md`
- Protocolo do agente: `docs/skills/po/references/agent-task-format.md`
- Padrões de qualidade: `docs/skills/po/references/quality-standards.md`
