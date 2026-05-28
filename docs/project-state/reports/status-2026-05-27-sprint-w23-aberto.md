---
report_date: 2026-05-27
sprint_id: SPRINT-2026-W23
wave: WAVE-2026-01
audience: humano-stakeholder
event: abertura-de-sprint
---

# Status Turni — abertura da SPRINT-2026-W23 (2026-05-27)

> Delta sobre o fechamento da SPRINT-2026-W22 (mesmo dia, ~1h antes). Foco específico: a sprint que **fecha o EPIC-000** acaba de abrir, com escopo cheio.

## TL;DR (3 linhas)

- **O que mudou**: SPRINT-2026-W22 fechada com goal 100% atingido em 1 dia; SPRINT-2026-W23 aberta logo em seguida com as 5 estórias restantes do EPIC-000 (006/007/008/009/011) — primeira sprint com código de produção do projeto.
- **Goal do sprint**: EPIC-000 fechado — hello world em ambas as homologações (WebApp + Backoffice) deployado por tag, pipelines verdes, e veredito `approved` da STORY-011.
- **Próxima entrega visível ao usuário**: **duas URLs em homologação** servindo hello world (WebApp Flutter com identidade visual do DDR-001 + Backoffice Livewire). Primeira coisa do Turni acessível por browser fora do protótipo.

## Sprint corrente

- **Sprint:** SPRINT-2026-W23, aberta em 2026-05-27.
- **Duração:** **aberta** — fechamento por goal-atingido (veredito `approved` da STORY-011). Soft-cap em 2026-06-14 (~18 dias corridos) como gatilho de reavaliação, não como prazo.
- **Goal:** "EPIC-000 fechado: hello world em ambas as homologações deployado por tag, pipelines verdes, veredito `approved` da STORY-011".
- **Estórias:** 0 done / 0 in_progress / 0 blocked / 5 ready.
- **Path:** `docs/project-state/sprints/SPRINT-2026-W23.md`.

### Estórias no sprint

| ID | Título | Papel | Tamanho | Bloqueada por |
|---|---|---|---|---|
| STORY-006 | Setup do repositório e ambiente local em 1 comando | programador | M | — (todas dependências da W22 estão `done`) |
| STORY-007 | Pipeline CI/CD com deploy automático para as duas homologações | programador | **L** | STORY-006 |
| STORY-008 | Hello world WebApp (Flutter) + identidade visual | programador (+ designer em paralelo) | M | STORY-007 |
| STORY-009 | Hello world Backoffice (Livewire) | programador | S | STORY-007 |
| STORY-011 | Validação final do EPIC-000 | validador | M | todas as demais |

### Ordem obrigatória

```
STORY-006 ─► STORY-007 ─┬─► STORY-008 ──┐
                        └─► STORY-009 ──┤
                                        ▼
                                   STORY-011
```

Único paralelismo legítimo: STORY-008 ∥ STORY-009 depois que STORY-007 fechar. STORY-008 exige sync ≤15 min Designer↔Programador antes da primeira linha de UI (cobre CA-14 da STORY-010 / DDR-001).

### Sizing total

1 S + 3 M + 1 L. **Atenção ao L (STORY-007)** — única LARGE do sprint, candidata natural a estouro de sessão única (pipeline CI/CD + deploy automático para 2 homologações + estratégia tag-based). Critério explícito na própria estória: se não couber em uma sessão, escala ao PO antes de inflar; quebra em sub-estórias é aceita como exceção válida nessa estória.

## Onda atual

- **Onda:** WAVE-2026-01 — "Ciclo completo do turno em homologação".
- **Progresso da onda:** 0 de 6 épicos `done`. EPIC-000 com 6 de 11 estórias `done`; 5 restantes nesta sprint. **EPIC-000 deve fechar nesta sprint** se goal bater.
- **Métrica-alvo da onda:** inalterada (≥ 1 turno completo em homologação por dia útil ao final da onda).

## O que o usuário pode ver agora em homologação

**Por enquanto, nada novo.** O entregável visível desta sprint é o próprio fechamento do EPIC-000:

- WebApp em homologação servindo hello world com identidade visual base (logo, tipografia, paleta, microcopy do voice-and-tone, tudo do DDR-001).
- Backoffice em homologação servindo rota raiz + health-check.
- Pipeline CI/CD ativo no GitHub Actions: PR verde → tag aplicada → deploy automático ≤ 10 min para as duas homologações.

Estimativa de quando isso vai estar no ar: orientativa, depende do throughput real desta primeira sprint de código. Ver "Olhando à frente".

## Qualidade — régua entra em vigor

Diferente da W22 (deliberação documental), esta sprint produz código de produção. Régua herdada **ativa sem exceção**:

- **Cobertura geral ≥ 80%**, núcleo de regras de negócio ≥ 98%.
- **E2E em browser real** para todo fluxo de usuário visível.
- **Automação por padrão** — setup local em 1 comando (STORY-006), deploy automatizado por tag (STORY-007). Nada de "por enquanto manual".
- **Observabilidade mínima** do ADR-008 já no hello world: log JSON estruturado em stdout, health-check padrão, métrica RED via log-based metrics, alerta de indisponibilidade.

Padrões consultáveis em `docs/skills/programador/references/quality-standards.md`.

## Decisões em vigor (vindas da W22 e onda)

Programador e Designer carregam essas decisões antes de tocar a primeira linha de código:

**Arquitetura** (todas `accepted` por Alexandro em 2026-05-27):
- ADR-000 PostgreSQL como banco principal.
- ADR-001 stack Laravel + Livewire + Flutter.
- ADR-002 monolito modular com api/admin/worker.
- ADR-003 monorepo poliglota único.
- ADR-004 hospedagem GCP (Cloud Run + Cloud SQL + Firebase Hosting), Terraform, deploy tag-based.
- ADR-007 Sanctum + Argon2id + RBAC por coluna.
- ADR-008 observabilidade mínima (log JSON + health-check + métricas RED via log-based metrics + alerta no Cloud Monitoring).
- ADR-005/006 Pagar.me + habitualidade — latentes nesta sprint, mas STORY-006 não pode fechar nada que os contradiga.

**Produto/Design**:
- DDR-001 fundação do Design System (dual-theme claro/escuro + cor por perfil).
- PDR-013 dual-theme suportado, padrão MVP = claro.
- Screen spec `SCREEN-STORY-008-hello-world-webapp` em `ready`, consumido pela STORY-008.

## Decisões aguardando Alexandro

**Nenhuma na abertura.** Todas as 9 ADRs e DDR-001 da fundação estão `accepted`; PDR-013 também. Próximas aprovações humanas devem surgir só se houver DDR-002 (descoberta de design durante STORY-008) ou IDR relevante do Programador.

## Bloqueios e riscos abertos

Riscos do sprint (também em `SPRINT-2026-W23.md` com mitigação/owner):

1. **Throughput de implementação muito menor que documental** — alta probabilidade, médio impacto. Mitigação: soft-cap em 2026-06-14 com reavaliação; PO não força calendário.
2. **STORY-007 (L) estoura sessão única** — alta/médio. Mitigação: agente escala antes de inflar; quebra aceita como exceção válida.
3. **Custo GCP em homologação cresce sem alerta** — média/médio. Mitigação: STORY-007 inclui alerta de orçamento básico; revisar custo diário.
4. **Primeira interação real Designer↔Programador em STORY-008** — média/médio. Mitigação: sync ≤15 min registrado em "Notas do agente"; descoberta de design vira DDR-002 imediato.
5. **STORY-011 reprova alguma estória** — média/alto. Mitigação: aceitar como sinal saudável; PO abre estórias de correção em mini-sprint W24; **não** pressionar Validador.
6. **Alexandro nos 5 papéis com mais código real** — média/médio. Mitigação: sessão dedicada por papel; troca declarada; aceitar ritmo mais lento como dado.
7. **Herdado da W22: expectativa irrealista de throughput** — alta/baixo. Já mapeado; PO não usa W22 como baseline.

Riscos da onda (herdados de `status-2026-05-26-wave-open.md`) seguem ativos, sem mudança nesta abertura.

Nenhum bloqueio operacional ativo.

## Disciplinas novas que entram em vigor agora

Saíram das lições da W22, registradas em `SPRINT-2026-W23.md`:

1. **`sprint_id` no frontmatter** atualizado no mesmo commit da abertura — **já aplicado nas 5 estórias** desta sprint.
2. **Marcação de CA**: estória só vai para `status: done` se todos os CAs estiverem `[x]` no corpo. Se houver `[ ]`, PO devolve para `in_progress`.
3. **"Verdade de corredor" vira PDR/ADR/DDR antes** — agente para e escala, não absorve na estória.
4. **Sync Designer↔Programador na STORY-008** ≤15 min, registrado em "Notas do agente", antes de qualquer linha de UI.

## Olhando à frente

### Próximos 7 dias (2026-05-28 a 2026-06-03)

- **Dia 1-3**: STORY-006 em execução. Setup local em 1 comando — primeira coisa concreta para um agente novo conseguir subir o ambiente.
- **Dia 3-7**: STORY-007 começa. Pipeline CI/CD + deploy automático para as duas homologações. Estória L — pode estourar a janela e isso está ok.
- **Mid-sprint check em 2026-06-03 (quarta)**: PO verifica se 006+007 fecharam. Se 007 ainda estiver `in_progress` e já passou de 7 dias, considerar quebra e replanejamento.

### Próximos 8-14 dias (2026-06-04 a 2026-06-10)

- STORY-007 fechando → STORY-008 e STORY-009 entram em paralelo (sessões distintas, mesma main).
- STORY-008: sync Designer↔Programador ≤15 min antes do código de UI; consumo do screen spec.
- STORY-011 (Validador) começa quando 006/007/008/009 estiverem todas `done`.

### Próximos 15-18 dias (2026-06-11 a 2026-06-14, soft-cap)

- STORY-011 entrega `validation/report.md` com veredito.
- Se `approved` → EPIC-000 marcado `done` pelo PO, status report de fechamento, abertura da SPRINT-2026-W24 (provavelmente abrindo EPIC-001 ou estórias de correção, dependendo do veredito).
- Se `rejected` → PO abre estórias de correção em mini-sprint W24; EPIC-000 permanece `in_review`.

### Próximos marcos previstos

- **~ 2026-06-10** — fim previsto do EPIC-000 (entregável visível: duas URLs no ar com health-check verde). Estimativa orientativa.
- **~ 2026-07-10** — fim previsto do EPIC-001 (depende do fechamento de EPIC-000).

## Apêndice — links rápidos

- Índice do projeto: `docs/project-state/index.json`
- Sprint atual: `docs/project-state/sprints/SPRINT-2026-W23.md`
- Sprint anterior (fechada): `docs/project-state/sprints/SPRINT-2026-W22.md`
- EPIC-000: `docs/project-state/epics/EPIC-000-foundation/epic.md`
- Onda atual: `docs/project-state/roadmap/current-wave.md`
- Status anterior (fechamento W22 implícito no próprio `SPRINT-2026-W22.md` — não gerei report dedicado de fechamento porque abertura e fechamento aconteceram no mesmo dia)
- Status de abertura da W22: `docs/project-state/reports/status-2026-05-27-sprint-w22-aberto.md`
- Skill do Programador (próxima troca de papel): `docs/skills/programador/SKILL.md`
- Skill do Designer (sync da STORY-008): `docs/skills/designer/SKILL.md`
- Skill do Validador (para STORY-011): `docs/skills/validador/SKILL.md`
