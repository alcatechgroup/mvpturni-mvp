---
sprint_id: SPRINT-2026-W27
wave: WAVE-2026-01
status: active
start_date: 2026-06-01
end_date: null
soft_cap_date: 2026-06-22  # ~21 dias corridos, espelhando W24/W25
opened_at: 2026-06-01
opened_by: "PO (Alexandro / Claude)"
closure_rule: "Fechamento por goal-atingido: encerra quando STORY-041, STORY-042, STORY-044, STORY-045, STORY-046, STORY-047, STORY-048, STORY-049, STORY-050, STORY-051, STORY-052, STORY-053 estiverem `done` E STORY-054 (validador) tiver emitido veredito em `validation/report.md` aceitável pelo PO (`approved` ou `approved_with_pending` que o PO assuma como goal-atingido). Soft-cap em 2026-06-22 (~21 dias corridos) serve como gatilho de reavaliação — não é prazo de entrega."
goal: "Primeiro encontro Turni vivo em homolog: contratante publica vaga e recebe candidatura em ≤ 2h; profissional vê feed ranqueado por match (p95 ≤ 800ms com 1k vagas) com breakdown explicável; candidatura em 1 toque com 3 gates (PDR-005 avaliação, conflito horário, habitualidade PDR-002); painel de candidatos do contratante ranqueado; edição material PDR-009 com snapshot imutável + notificação a candidatos + cron de auto-retirada 24h; notificações in-app + e-mail (5 templates) entregando ao destino certo. WebApp Flutter instalável como PWA com identidade Turni (ícones substituem logo padrão do Flutter; ação 'Instalar app' com prompt nativo Android/Chromium e fallback iOS). 2 ADRs novas aceitas (ADR-013 modelo Vaga/Candidatura/snapshot; ADR-014 algoritmo Match + cache + eventos) e 1 IDR (IDR-020 estratégia de instalação PWA). Validador independente (STORY-054) emite veredito do EPIC-002."
---

# SPRINT-2026-W27

## Objetivo do sprint

A SPRINT-2026-W25 fechou o EPIC-001 (funil de identidade ponta a ponta com aceite eletrônico imutável, RBAC vivo nas duas interfaces, e-mails transacionais ao vivo, worker Cloud Run Job operante). A SPRINT-2026-W26 fechou o EPIC-007 Web-only (`integration_test` adotado, Playwright reduzido a smoke HTTP, padrão Flutter de testes E2E em vigor) e moveu a camada Patrol/mobile para EPIC-009 (backlog) — decisão de produto: **MVP sem mobile**.

Esta sprint é a **mais larga até hoje** — 13 estórias entre 2 épicos, abrindo o primeiro **encontro entre profissional e contratante** (EPIC-002) enquanto entrega a **instalabilidade** do WebApp (EPIC-008). Recorte e composição:

1. **EPIC-002 — Vaga, feed e candidatura (11 estórias).** Primeira sprint do projeto que materializa o pilar **Match IA** prometido na landing. Sai do "usuário entra" para "usuário encontra oferta e candidata". Inclui 2 spikes do Arquiteto na base (modelo + algoritmo), 8 estórias de implementação (publicar vaga, lista de vagas, feed com match, detalhe com breakdown, candidatura em 1 toque com 3 gates, painel de candidatos, edição material PDR-009, notificações), e validação final independente (STORY-054 — 3ª aparição do validador no projeto após STORY-011 e STORY-025).
2. **EPIC-008 — PWA instalável (2 estórias).** Resolve as duas faltas de UX que o EPIC-001 deixou expostas: profissional/contratante hoje não conseguem instalar o WebApp na home sem saber o gesto manual; e o ícone instalado é o logo padrão do Flutter (não a marca Turni). Coexiste com a auto-atualização da STORY-037 sem regressão (gate explícito do EPIC-008).

Por que os dois épicos juntos? Decisão do PO em chat de 2026-06-01: time de execução em **ritmo bom** (W24 entregou 10 estórias em 2 dias; W25 fechou 6 em 3 dias com validador; W26 fechou Web-only em 1 dia). EPIC-008 é pequeno (S + M) e completamente ortogonal ao EPIC-002 (toca `apps/webapp/web/` e `lib/core/install/`; não cruza com `app/Domain/Match/` nem `app/Http/Controllers/Api/Vaga*`). Conflitos de merge são triviais. Goal único: encontro vivo + WebApp instalável.

## Escopo e duração

- **Escopo**: 13 estórias — EPIC-002 inteiro (11) + EPIC-008 inteiro (2). Mix: 1 S + 11 M + 1 L. STORY-048 (feed do profissional, **L**) é a única estória LARGE da sprint, candidata natural a estouro de sessão única — agente escala ao PO antes de inflar; critério de quebra: separar query+ranqueamento (backend) da UI (frontend) em duas estórias.
- **Duração**: **aberta**, com fechamento por goal-atingido (padrão consolidado W22→W26). Soft-cap em 2026-06-22 (~21 dias corridos, espelhando W24/W25) serve como gatilho de reavaliação — não é prazo de entrega.
- **Disciplina herdada**: "métrica primária observada no estado final do épico" (W23/W25), "validador se atém a evidência + veredito" (W23/W25), "sprint_id no frontmatter da estória atualizado no mesmo commit que altera index.json" (W23), "marcação de CA `[x]` antes de status `done`" (W23), "F-NB-1 do EPIC-000 (migrate:rollback) quitado em estória de migração nova" — quitado nesta sprint pela STORY-044.

## Estórias incluídas

### EPIC-002 — Vaga, feed e candidatura

| ID        | Título                                                 | Papel       | Tipo           | Tamanho | Bloqueada por                |
| --------- | ------------------------------------------------------ | ----------- | -------------- | ------- | ---------------------------- |
| STORY-044 | Spike modelo Vaga + Candidatura + snapshot PDR-009     | arquiteto   | spike          | M       | —                            |
| STORY-045 | Spike algoritmo Match (40/20/30/10) + eventos          | arquiteto   | spike          | M       | 044                          |
| STORY-046 | Publicar vaga no WebApp + gate PDR-005                 | programador | implementation | M       | 044                          |
| STORY-047 | Lista "Minhas vagas" do contratante + cancelar         | programador | implementation | S       | 044, 046                     |
| STORY-048 | Feed do profissional com match + filtros (p95 ≤ 800ms) | programador | implementation | **L**   | 044, 045                     |
| STORY-049 | Detalhe da vaga + breakdown explicável                 | programador | implementation | M       | 044, 045, 048                |
| STORY-050 | Candidatura em 1 toque + 3 gates                       | programador | implementation | M       | 044, 045, 049                |
| STORY-051 | Painel de candidatos do contratante (ranqueado)        | programador | implementation | M       | 044, 045, 049, 050           |
| STORY-052 | Edição material PDR-009 + snapshot + cron 24h          | programador | implementation | M       | 044, 034, 047                |
| STORY-053 | Notificações in-app + e-mail (3 eventos, 5 templates)  | programador | implementation | M       | 020, 021, 034, 047, 050, 052 |
| STORY-054 | Validação final EPIC-002                               | validador   | validation     | M       | tudo acima                   |

### EPIC-008 — PWA instalável

| ID | Título | Papel | Tipo | Tamanho | Bloqueada por |
|---|---|---|---|---|---|
| STORY-041 | Ícones do PWA com a marca Turni | programador | implementation | S | — (independente do EPIC-002) |
| STORY-042 | Ação "Instalar app" + fallback iOS (produz IDR-020) | programador | implementation | M | 041 ideal mas não obrigatório |

**Sizing total da sprint**: 2 S + 10 M + 1 L. **Atenção ao L (STORY-048)** — gatilho de quebra documentado na própria estória.

## Ordem de execução obrigatória (dependências)

```
EPIC-002 (caminho crítico):

STORY-044 (spike modelo)
    │
    ├─► STORY-045 (spike algoritmo Match)
    │        │
    │        ├─► STORY-048 (feed)
    │        │        │
    │        │        └─► STORY-049 (detalhe + breakdown)
    │        │                 │
    │        │                 └─► STORY-050 (candidatura)
    │        │                          │
    │        │                          └─► STORY-051 (painel candidatos)
    │        │                                   │
    │        │                                   └─► STORY-054 (validação) ◄────┐
    │        │                                                                  │
    │        └─► STORY-049, STORY-051 (consumem breakdown)                     │
    │                                                                           │
    └─► STORY-046 (publicar vaga)                                              │
             │                                                                  │
             └─► STORY-047 (lista minhas vagas)                                │
                      │                                                         │
                      └─► STORY-052 (edição material) ─► STORY-053 (notif) ────┘

EPIC-008 (paralelo, independente):

STORY-041 (ícones)   ─► STORY-042 (ação instalar + IDR-020)
   (pode rodar em qualquer momento da sprint; recomendado começar cedo
    porque é pequeno e fecha rápido; não bloqueia nada do EPIC-002)
```

**Paralelismo legítimo**:
- EPIC-008 (041, 042) roda em paralelo a qualquer estória do EPIC-002 — diferentes pastas, zero overlap.
- STORY-046/STORY-047 (lado contratante de vaga) roda em paralelo a STORY-048/STORY-049 (lado profissional) depois que STORY-044 + STORY-045 fecharem.
- STORY-050 (candidatura) precisa de STORY-049 (UI) mas o **backend** dela pode começar antes da UI.

**O que NÃO paralelizar**:
- STORY-052 antes de STORY-047 (ambas tocam UI do contratante; risco de conflito de merge real).
- STORY-053 antes de STORY-050 + STORY-052 (consome eventos emitidos por elas).
- STORY-054 (validador) — sempre por último, com tudo deployado em homolog.

## Compromisso visível ao fim do sprint

Diferente das sprints de fundação anteriores, esta entrega **ações de produto reais para os dois lados do marketplace**:

**Em `app.homolog.turni.com.br` (WebApp Flutter):**

- Contratante autenticado e `ativo` consegue:
  - Publicar uma vaga (formulário com função, data/hora, valor, posições, observações).
  - Ver "Minhas vagas" agrupadas por estado e cancelar uma vaga `aberta`.
  - Editar materialmente uma vaga e ver "X candidatos serão notificados" antes de confirmar.
  - Abrir painel de candidatos de uma vaga e ver candidatos ranqueados por score (0-100) com breakdown clicável.
  - Receber e-mail + notificação in-app a cada nova candidatura (com nome e score do profissional).
- Profissional autenticado e `ativo` consegue:
  - Abrir o feed e ver vagas que se encaixam (`aberta`, função primária ou secundária, dentro do raio, data futura), ranqueadas por match.
  - Filtrar feed por "Todas", "Minha função", "Alto match (80%+)", "Candidatadas".
  - Tocar em uma vaga e ver detalhe com breakdown explicável (4 componentes do match).
  - Candidatar-se em 1 toque (bloqueio claro se 1 dos 3 gates dispara).
  - Receber e-mail + notificação in-app quando vaga em que candidatou é editada materialmente ou cancelada.
  - **Instalar o WebApp na tela inicial** (Android Chromium via prompt nativo; iOS Safari via modal de instruções), com ícones da marca Turni (não mais logo do Flutter).
- Auto-atualização da STORY-037 continua passando (gate de não-regressão do EPIC-008).
- Performance: feed responde em p95 ≤ 800ms com 1k vagas seedadas em homolog (medido em CI + reproduzido em homolog pelo validador na STORY-054).
- Métrica primária do EPIC-002 verificada em homolog pelo validador: vaga publicada e primeira candidatura observada em ≤ 2h em cenário seedado.

**Em `admin.homolog.turni.com.br` (Backoffice Livewire):**

- Editor de templates (STORY-020) ganha 5 templates novos relacionados a candidatura (carregados como `TemplateVersao` ativa, mesmo padrão do EPIC-001).
- Audit log captura todas as ações novas: `vaga.criada`, `vaga.editada_materialmente`, `vaga.cancelada`, `candidatura.criada`, `candidatura.mantida_apos_edicao`, `candidatura.retirada_por_edicao_voluntaria`, `candidatura.retirada_por_edicao_auto`, `notificacao.criada` (imutável por trigger Postgres herdado do EPIC-001).

**Decisões registradas:**

- **ADR-013** — Modelo Vaga + Candidatura + VagaVersao (snapshot PDR-009) em `decisions/adr/`.
- **ADR-014** — Algoritmo Match on-demand + payload `MatchBreakdown` + 4 eventos de telemetria em `decisions/adr/`.
- **IDR-020** — Estratégia de instalação PWA (gatilho da ação, pontos de exibição, política de dispensa, critério "já instalado", microcopy CTA + modal iOS, formato e tamanhos dos ícones) em `decisions/idr/`.

**Quita F-NB-1 do EPIC-000** — STORY-044 cria migrações com lógica de negócio real (`vagas`, `vaga_versoes`, `candidaturas`) e exercita `migrate:rollback` em homolog, fechando o critério herdado da W23.

## Decisões de produto/arquitetura que entram em vigor agora

Esta sprint **respeita** todas as decisões já aceitas e **adiciona** 2 ADRs + 1 IDR. Os agentes operam sob:

- **ADRs vigentes** (todas aceitas em EPIC-000/EPIC-001): ADR-000 (Postgres), ADR-001/002/003 (stack), ADR-004 (GCP), ADR-007/008 (Sanctum + Argon2id + log JSON + health), ADR-009 (modelo identidade), ADR-010 (template imutável), ADR-011 (provedor e-mail), ADR-012 (landing — não afeta esta sprint).
- **PDRs vigentes**: PDR-002 (habitualidade), PDR-003 (duas interfaces), PDR-004 (Taxa Turni — não afeta EPIC-002 ainda), PDR-005 (gate avaliação — afeta candidatura e publicação), PDR-009 (edição material), PDR-012 (editor de templates — usado para os 5 templates novos), PDR-013 (emergente do W22), PDR-015 (fronteira landing — não afeta).
- **DDR-001** — Design System vivo, dual-theme claro/escuro, cor por perfil. Telas novas (publicar vaga, lista, feed, detalhe, painel, modal de instalação) consomem tokens. Designer entrega SCREEN specs em paralelo no início da sprint (STORY-046, 047, 048, 049, 050, 051, 052, 053 — 8 telas; o screen spec já deve estar `ready` antes da estória de implementação começar).
- **IDR-010/011** (W26) — modelo híbrido E2E + padrão Flutter de testes (Keys/mocks/helpers/naming). Todos os E2E desta sprint usam `integration_test` em Chrome headless; Playwright só para smoke HTTP do build deployado.
- **IDR-017** (auto-update WebApp) — STORY-041 e STORY-042 **não tocam** entry chain Flutter, service worker nem `firebase.json` no entry chain. Gate explícito do EPIC-008.

Agente programador, arquiteto e designer carregam suas próprias skills + as decisões vigentes antes de começar. Conflito real entre decisão vigente e necessidade da estória escala ao papel dono (Arquiteto via nova ADR, PO via novo PDR, Designer via novo DDR) — não se ajusta silenciosamente no código.

## Riscos identificados na abertura

| Risco | Probabilidade | Impacto | Mitigação | Owner |
|---|---|---|---|---|
| Sprint pesada demais — 13 estórias em 2 épicos é o maior escopo até hoje | **alta** | **alto** | Soft-cap em 2026-06-22 (~21d) com reavaliação; PO faz mid-sprint check em 2026-06-10 (D+9); se STORY-044+045 não fecharem até D+5, considerar quebrar STORY-048 (única L); EPIC-008 pode ser deferido para W28 se EPIC-002 atrasar (decisão do PO no mid-sprint check) | PO |
| STORY-048 (L) estoura sessão única — feed com perf + UI + telemetria é peça grande | **alta** | médio | Critério de quebra explícito na própria estória (backend × frontend em 2 estórias); agente escala ao PO antes de inflar; aceitar carry-over de uma metade para W28 é exceção válida | Programador + PO |
| Performance p95 ≤ 800ms do feed não é atingido com índice escolhido na STORY-044 | média | alto | STORY-044 CA-8 exige microbenchmark com `EXPLAIN ANALYZE` antes de fechar; STORY-048 CA-6 exige teste de carga no CI; reavaliar índice se p95 entre 800-1200ms; quebrar STORY-048 e abrir estória de tuning de query se p95 > 1200ms | Arquiteto + Programador |
| 8 SCREEN specs do Designer (046, 047, 048, 049, 050, 051, 052, 053) não ficam prontos a tempo — Designer vira gargalo | **alta** | alto | Designer prioriza no D1-D3 entregando os 8 specs antes da semana 2; PO faz sync diário com Designer nos 3 primeiros dias; estórias com `requires_design: true` ficam `blocked` se o screen spec não estiver `ready`; SCREEN spec pode ser entregue como wireframe textual em primeira passada (designer detalha visual depois) — exceção válida se sinalizada na abertura | Designer + PO |
| 3 gates da STORY-050 (PDR-005, conflito, habitualidade) interagem mal e bloqueiam profissional seed em cenário inesperado | média | médio | Cobertura ≥ 98% no núcleo da STORY-050 (regra de `quality-standards.md`); testes cobrem todas as combinações de gates; validador (STORY-054) repete o cenário em homolog | Programador + Validador |
| Snapshot PDR-009 em `vaga_versoes` viola imutabilidade em produção (constraint mal aplicada) | baixa | **alto** | Trigger Postgres bloqueia UPDATE/DELETE testado em STORY-044 CA-5; validador (STORY-054 CA-8) tenta UPDATE/DELETE manual via SQL como evidência | Arquiteto + Validador |
| Cron de auto-retirada (STORY-052) atrasa por falha do Cloud Run Job | média | médio | Worker já operante desde STORY-034 (W25); STORY-052 reusa (não cria infra nova); alerta SLA > 20h herdado da W25 ainda como F-NB-1 (PO acompanha em paralelo) | Programador + PO |
| Notificações da STORY-053 spammam contratante quando há muitos candidatos | média | baixo | SLA 60s no worker (não realtime); microcopy revisada pelo PO; preferências do usuário ficam para wishlist (não MVP); validador observa volume em homolog | PO + Programador |
| EPIC-008 STORY-042 quebra auto-atualização da STORY-037 (entry chain Flutter) | baixa | **alto (gate)** | EPIC-008 epic.md já lista invariantes (não tocar SW/Cache/firebase entry chain); CA-17 da STORY-037 vira gate de fechamento do EPIC-008 (smoke obrigatório em homolog) | Programador |
| Custo GCP em homolog explode com 1k vagas seedadas + worker + cron + mais e-mails | média | médio | Alerta de orçamento herdado da STORY-007; revisar custo diário pela primeira vez na 2ª semana; aceitar trade-off "homolog mais realista = mais cara" | PO + Alexandro |
| 5 templates novos (STORY-053) ficam sem texto-seed v1 do PO no momento certo, atrasando STORY-053 | média | médio | PO escreve os 5 texto-seed em paralelo nos primeiros 5 dias da sprint (sessão dedicada); STORY-053 só fecha com `TemplateVersao` ativa carregada (CA-6); seguir padrão de validação por chat do EPIC-001 (STORY-015) | PO |
| Alexandro nos 5 papéis em sprint maior — fadiga cognitiva real | alta | médio | Sessão dedicada por papel, troca declarada; PO faz check diário curto (~10 min) separado de execução; aceitar ritmo mais devagar como dado, não como falha; planejar pausa entre EPIC-002 e EPIC-003 | Alexandro |

## Acompanhamento contínuo (PO)

- **Diário (~10 min)**: olhar `index.json`, identificar o que está `in_progress` / `blocked` / `in_review`. Desbloquear o que pode (especialmente SCREEN specs do Designer e texto-seed dos 5 templates).
- **Mid-sprint check em 2026-06-10 (quarta, D+9)**: PO verifica se STORY-044+045+046+047 fecharam e se EPIC-008 (041+042) está perto de fechar. Se não, considerar: (a) deferir EPIC-008 para W28, (b) quebrar STORY-048, (c) deferir STORY-052 (edição material) para próxima sprint.
- **Soft-cap check em 2026-06-22 (~21d)**: se goal não bateu, abrir seção "Mudanças no escopo" abaixo e decidir entre seguir, deferir, ou abrir mini-sprint dedicada para STORY-054.

## Disciplina herdada das sprints anteriores (aplicada sem nova negociação)

1. **`sprint_id` no frontmatter** atualizado no mesmo commit que altera `sprints[*].story_ids` no `index.json`. *Já aplicado na abertura desta sprint nas 13 estórias.*
2. **Marcação de CA `[x]`** ao transicionar estória para `status: done`. **Se houver `[ ]` em estória `done`, o PO devolve para `in_progress`.**
3. **"Verdade de corredor" vira PDR/ADR/DDR antes do código.** Decisão de produto/arquitetura/design sem registro associado pausa a estória.
4. **Métrica primária do épico observada no estado final** (aprendizado W23) — validador (STORY-054) só verifica métrica com o último merge do épico deployado.
5. **Validador se atém a evidência + veredito** (aprendizado W23/W25) — não planeja correções, não sugere próximos passos.
6. **F-NB-1 do EPIC-000** (migrate:rollback) **quitado** nesta sprint pela STORY-044 (primeira migração com lógica de negócio real).

## Mudanças no escopo do sprint

> Toda alteração no conjunto de estórias após esta abertura registra aqui, com data e motivo.

| Data | O que mudou | Motivo | Custo (estória solta/movida) |
|---|---|---|---|
| — | — | — | — |

## Atualização de progresso — 2026-06-02 (D+1)

> Snapshot do estado da sprint registrado pelo PO no dia seguinte à abertura.
> Próxima atualização programada para o mid-sprint check em **2026-06-10 (D+9)** — antecipável se passarmos de 80% antes.

### Placar das 13 estórias

| ID        | Status   | Épico    | Observação                                                                                            |
| --------- | -------- | -------- | ----------------------------------------------------------------------------------------------------- |
| STORY-041 | **done** | EPIC-008 | Ícones da marca Turni publicados (rc.44/45). PO validou CA-13/CA-15 ao vivo em iOS; CA-14 dispensado. |
| STORY-042 | **done** | EPIC-008 | Ação "Instalar app" + IDR-020 aceita; bug do layout iOS corrigido em rc.46→rc.47. **EPIC-008 fechado.** |
| STORY-044 | **done** | EPIC-002 | ADR-013 aceita; modelo Vaga/Candidatura/VagaVersao verde. **F-NB-1 do EPIC-000 (migrate:rollback) quitado.** |
| STORY-045 | **done** | EPIC-002 | ADR-014 aceita; módulo Match puro + 4 eventos de telemetria verde.                                    |
| STORY-046 | **done** | EPIC-002 | Publicar vaga + gate PDR-005 verde. Emergiram IDR-025 (restaurar sessão no boot) e **DDR-002 (locale pt-BR + horário 24h transversal)**. |
| STORY-047 | **done** | EPIC-002 | "Minhas vagas" + cancelar verde (S, rápida como previsto).                                            |
| STORY-048 | **done** | EPIC-002 | **A única L da sprint fechou em 1 sessão** — feed do profissional com match, filtros e visibilidade entregue sem precisar acionar o gatilho de quebra. |
| STORY-049 | **done** | EPIC-002 | Detalhe da vaga + breakdown explicável do match entregue.                                             |
| STORY-050 | **done** | EPIC-002 | Candidatura em 1 toque + 3 gates (conflito/habitualidade/avaliação), SCREEN-050, retirada. api 444 testes/97.4% (núcleo 100%); E2E 0 flake em 3 runs; PO aprovou em chat. Extra: selo "já candidatou" no card do feed. |
| STORY-051 | ready    | EPIC-002 | Aguarda STORY-049 + STORY-050.                                                                        |
| STORY-052 | ready    | EPIC-002 | Independente do feed (consome STORY-044 + STORY-047).                                                 |
| STORY-053 | ready    | EPIC-002 | Aguarda STORY-050 + STORY-052; PO precisa entregar texto-seed dos 5 templates.                        |
| STORY-054 | ready    | EPIC-002 | Validador independente — última estória.                                                              |

**Entregue:** 7/13 estórias (54%) em **1 dia** — 1 S + 5 M + 1 L. **EPIC-008 100% fechado**, EPIC-002 com spikes + 3 telas + feed fechados.

### O que ficou registrado de durável neste primeiro dia

- **ADR-013** — modelo Vaga + Candidatura + VagaVersao (snapshot PDR-009) **accepted**.
- **ADR-014** — algoritmo Match on-demand + `MatchBreakdown` + 4 eventos de telemetria **accepted**.
- **IDR-020** — estratégia de instalação PWA (ação, dispensa, microcopy, modal iOS) **accepted**.
- **IDR-025** — restauração de sessão no boot (deep-link/reload não desloga) **accepted** (emergente da STORY-046).
- **DDR-002** — locale pt-BR + horário 24h transversal em todo o app **accepted** (emergente da STORY-046).
- **F-NB-1 do EPIC-000** (migrate:rollback em homolog) **quitado** pela STORY-044 conforme planejado.

### Riscos da abertura — releitura em D+1

| Risco                                                       | Estado                                                                                                                                                                            |
| ----------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Sprint pesada demais (13 estórias)                          | **Mitigado.** Em D+1 já temos 54% entregue; ritmo W24/W26 confirmado, soft-cap 2026-06-22 deve folgar.                                                                            |
| STORY-048 (L) estoura sessão única                          | **Não materializou.** Fechou em 1 sessão; gatilho de quebra não foi acionado.                                                                                                     |
| Performance p95 ≤ 800ms do feed                             | Mantido. Validador (STORY-054) repete em homolog ao fim.                                                                                                                          |
| 8 SCREEN specs do Designer viram gargalo                    | **Reduzido.** SCREENs de 046, 047, 048 entregues e consumidos sem atrito; restam 049, 050, 051, 052, 053. Designer está dentro do plano de priorizar D1-D3.                       |
| 3 gates da STORY-050 interagem mal                          | Ainda em aberto — será exercitado quando STORY-050 iniciar.                                                                                                                       |
| Snapshot PDR-009 viola imutabilidade                        | Trigger Postgres verde em STORY-044 CA-5; validador repete em STORY-054 CA-8.                                                                                                     |
| Cron de auto-retirada atrasa                                | Ainda em aberto — reusa worker da W25.                                                                                                                                            |
| Notificações spammam contratante                            | Ainda em aberto — será exercitado em STORY-053.                                                                                                                                   |
| EPIC-008 quebra auto-atualização (STORY-037)                | **Mitigado.** EPIC-008 fechou sem regredir auto-update; smoke verde em rc.47.                                                                                                     |
| Custo GCP em homolog                                        | Monitoramento mantido; reavaliação na 2ª semana segue planejada.                                                                                                                  |
| 5 texto-seed dos templates da STORY-053                     | **Pendência ativa do PO.** Janela aberta — STORY-053 está bloqueada por STORY-050 + STORY-052, então PO tem ~5 dias úteis para entregar antes de virar gargalo.                   |
| Alexandro nos 5 papéis — fadiga                             | Ritmo agressivo no D1; PO precisa atentar para não confundir velocidade de execução com sustentabilidade da sprint maior do projeto.                                              |

### Decisões do PO neste mid-sprint antecipado

- **Manter** o escopo cheio (13 estórias). Nenhum motivo para deferir EPIC-008 ou STORY-052 — EPIC-008 já fechou e o caminho crítico do EPIC-002 destravou.
- **Antecipar o mid-sprint check formal** para 2026-06-04 (D+3) se STORY-049 + STORY-050 fecharem até lá — soft-cap 2026-06-22 segue como teto, mas o cenário realista virou "fechar EPIC-002 antes de 2026-06-10".
- **Próxima estória a iniciar:** STORY-049 (detalhe da vaga + breakdown). Em paralelo, agente pode começar **STORY-052** (edição material) — já tem STORY-044 e STORY-047 prontas, e o overlap de UI com STORY-047 é aceitável agora que STORY-047 fechou.
- **Texto-seed dos 5 templates da STORY-053:** PO compromete entregar até 2026-06-05 (D+4), antes da STORY-053 destravar.

## Atualização de progresso — 2026-06-02 (D+1, fim do dia)

> Segundo snapshot do mesmo dia: STORY-049 (15:34) e STORY-050 (17:14) fecharam em sequência.
> Próxima atualização: mid-sprint check formal antecipado para **2026-06-03 (D+2)** se STORY-051 fechar até lá.

### Estado atual: 9/13 done (69%) em D+1

| ID        | Status   | Observação                                                                                                                                                                                                          |
| --------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| STORY-049 | **done** | Detalhe da vaga + breakdown explicável entregue. Contrato unificado (vaga + 4 componentes + flags de candidatura). API 423 testes (novos 100%), WebApp 250 widget (tela 97,9%), E2E 3/3 sem flake. `BreakdownRow` público (reuso pela STORY-051). |
| STORY-050 | **done** | Candidatura em 1 toque + 3 gates (conflito horário, habitualidade PDR-002, avaliação PDR-005). SCREEN-050 (modal confirmação + 3 modais de bloqueio + retirada). API 444 testes / 97,4% (núcleo 100%). E2E 0 flake em 3 runs. Telemetria `match.candidatura_enviada` + audit `candidatura.criada` + evento de domínio `CandidaturaEnviada` (consumido por STORY-053). **Extra aprovado pelo PO**: selo "Você já se candidatou" no card do feed. Follow-up explícito: conflito de horário no card do feed ficou fora de escopo (custo no p95). PO aprovou em chat. |

**Acumulado da sprint:** 9/13 estórias done (1 S + 7 M + 1 L). Restam **4 estórias** — todas do EPIC-002.

### Caminho restante (4 estórias)

| ID        | Status | Bloqueada por                                          | Pendência                                                                            |
| --------- | ------ | ------------------------------------------------------ | ------------------------------------------------------------------------------------ |
| STORY-051 | ready  | 044, 045, 049, 050 — **todas done**, pode iniciar já   | Próxima a iniciar. Reusa `BreakdownRow` da STORY-049.                                |
| STORY-052 | ready  | 044, 034, 047 — **todas done**, pode iniciar em paralelo | Independente de 051; ortogonal (toca admin + WebApp do contratante).                |
| STORY-053 | ready  | 020, 021, 034, 047, 050, 052 — restam **052** + texto-seed do PO | Depende de STORY-052 fechar **e** texto-seed dos 5 templates do PO.       |
| STORY-054 | ready  | tudo acima                                             | Validador independente; última estória.                                              |

### Riscos da abertura — releitura no fim do D+1

| Risco                                                       | Estado                                                                                                                                                       |
| ----------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Sprint pesada demais                                        | **Praticamente mitigado.** 69% em D+1 — cenário realista é fechar EPIC-002 até 2026-06-04/05.                                                                |
| 3 gates da STORY-050 interagem mal                          | **Não materializou.** 444 testes verdes, núcleo 100%, E2E 0 flake. Cobertos os 3 caminhos de bloqueio e a reativação idempotente.                            |
| Cron de auto-retirada (STORY-052)                           | Ainda em aberto — próxima janela.                                                                                                                            |
| Notificações spammam contratante                            | Ainda em aberto — STORY-053.                                                                                                                                 |
| Texto-seed dos 5 templates (PO)                             | **Vira gargalo nas próximas ~24-36h.** STORY-052 ortogonal pode iniciar já; quando 052 fechar, STORY-053 só destrava com o texto-seed entregue.              |
| Alexandro nos 5 papéis                                      | Ritmo muito acima do previsto. Vigiar fadiga — sprint pode fechar metade do soft-cap, e isso é bom motivo para pausa antes de EPIC-003, não para encavalar.  |

### Decisões do PO (fim do D+1)

- **Antecipar a entrega do texto-seed para 2026-06-03 (D+2)** — passou de "antes da 053 destravar" para "antes do mid-sprint check" porque o ritmo de implementação está acima do projetado.
- **Próximas estórias a iniciar:** STORY-051 (caminho crítico de UI do contratante) **e** STORY-052 (edição material) **em paralelo**. Ortogonais e sem conflito de merge esperado (051 toca painel novo; 052 toca admin + fluxo de edição da vaga).
- **Reavaliar a inclusão de STORY-053 no escopo da W27** no mid-sprint check de 2026-06-03 — se STORY-051+052+054 fecharem antes do PO entregar o texto-seed, é razoável fechar o sprint com 12/13 e mover STORY-053 para W28 dedicada a notificações + acabamento.
- **Follow-up registrado da STORY-050:** "conflito de horário no card do feed" como item de wishlist (pré-backlog) — não MVP do EPIC-002.

## Atualização de progresso — 2026-06-02 (D+1, noite) — STORY-051 fechada

> Terceiro snapshot do mesmo dia: STORY-051 (painel de candidatos do contratante) entregue e
> validada no app real local por Alexandro.

### Estado atual: 10/13 done (77%) em D+1

| ID        | Status   | Observação                                                                                                                                                                                                  |
| --------- | -------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| STORY-051 | **done** | Painel de candidatos do contratante (ranqueado por score snapshot + breakdown reusando `BreakdownRow` da 049). Nova coluna `candidaturas.score_breakdown jsonb` + `alerta_habitualidade` persistidas no envio (STORY-050 service). SCREEN-051 `shipped` (validado no app). Cobertura: controller 95% / service 100% / tela 98,6% / service Dart 100%; CA-8 perf (50 candidatos p95≤500ms); E2E 3/3 sem flake. SCREEN-051 + protótipo. |

**Acumulado da sprint:** 10/13 done (1 S + 8 M + 1 L). Restam **3 estórias** — STORY-052 (edição
material, ortogonal — pode iniciar já), STORY-053 (notificações — bloqueada por 052 + texto-seed
do PO), STORY-054 (validador, última).

### Decisões / aprendizados do fechamento da 051

- **Snapshot do breakdown nasceu como dívida da 050, paga na 051.** A 050 só persistia o total
  (`score_no_momento`); a 051 precisava do breakdown do instante da candidatura (CA-4), então a
  migração `score_breakdown jsonb` + `alerta_habitualidade` foi adicionada e carimbada no
  `CriarCandidaturaService`. Aprendizado: snapshot de payload explicável deve ser previsto já na
  estória que cria o dado, não na que o consome.
- **Reuso do `BreakdownRow` (049) confirmou a aposta.** A 049 publicou o widget antecipando a 051;
  o consumo foi direto, sem refatoração. Família `match.*` (barra/chip/breakdownrow) agora no 3º
  uso → candidata firme a promoção formal ao DS.
- **Determinismo de E2E exige ordenar leitura antes de mutação.** O E2E da 047 cancela uma vaga
  arbitrária (`Cancelar vaga`.first) e mexe no filtro; a 051 (que só lê) passou a rodar **antes**
  dela no aggregator, e o seeder reabre a vaga seed a cada `db:seed`. Padrão para próximos E2E que
  compartilham o mesmo usuário seed: testes read-only antes dos que mutam estado.

## Atualização de progresso — 2026-06-03 (D+2, STORY-052 done)

> Quarto snapshot. STORY-052 fechou no início do D+2; sprint chega a **11/13 (85%)** e o EPIC-002
> está com **todas as estórias de implementação `done`** — restam apenas notificações (053) e a
> validação final (054).

### Estado atual: 11/13 done (85%) — restam STORY-053 e STORY-054

| ID        | Status   | Observação                                                                                                                                                                                                          |
| --------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| STORY-051 | **done** | Painel de candidatos do contratante (ranqueado + breakdown) shipped — SCREEN-051 validado.                                                                                                                          |
| STORY-052 | **done** | Edição material PDR-009 (Designer + Programador). SCREEN-052 validado no browser e **estória aprovada por Alexandro**. Backend: `PATCH /vagas/{id}` + detector material puro + transação (snapshot v(N+1) + transição candidaturas + evento `VagaEditadaMaterialmente`), endpoints confirmar/retirar-apos-edicao, cron `candidaturas:auto-retirar-apos-edicao` (everyMinute, reusa STORY-034). Frontend: tela `/contratante/vagas/{id}/editar` com preview do diff + aviso de candidatos; **CA-11 completo** — selo "Vaga editada — confirme" no card do feed (Candidatadas, `em_revisao`) **+** banner de revisão no detalhe (049) com Manter/Retirar. **api 496 testes** (núcleo ≈98.4%), **webapp 326 testes** (editar 87.2%, detalhe 93.5%), E2E backend do ciclo completo (`travel(25h)`) + integration_test same-origin. **Emergiu IDR-026** (política única de data/hora `TurniDateTime`): bug de fuso achado no teste humano (card 15:00 vs edição 18:00) resolvido de forma centralizada — UTC na API, local na UI, round-trip lossless; 6 telas + 3 serviços passaram a delegar. Follow-up não-bloqueante: `make e2e-webapp-integration` + deploy homolog no próximo pacote. |

### O que falta concretamente nesta sprint

| Estória   | Status | Bloqueio real                                              | Quem destrava                          |
| --------- | ------ | ---------------------------------------------------------- | -------------------------------------- |
| STORY-053 | ready  | **Texto-seed v1 dos 5 templates** (entrega do PO, ainda não feita) | PO (Alexandro) — antes de iniciar 053  |
| STORY-054 | ready  | Tudo o resto deployado em homolog                          | Validador (independente)               |

**Caminho:** PO entrega texto-seed v1 dos 5 templates → agente programador executa STORY-053 (listener dos 3 eventos + tabela `notificacoes` + `GET /api/notificacoes` + `POST /api/notificacoes/{id}/marcar-lida` + cron via Cloud Run Job da STORY-034 + carregamento dos 5 templates como `TemplateVersao` ativa no editor da STORY-020) → deploy em homolog → STORY-054 (validador) verifica métrica primária do EPIC-002 (vaga publicada → primeira candidatura ≤ 2h em cenário seedado), reexecuta o ciclo em homolog e emite `validation/report.md`.

### Riscos da abertura — releitura no D+2

| Risco                                       | Estado                                                                                                                                          |
| ------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| Sprint pesada demais                        | **Mitigado.** 11/13 (85%) em D+2 — soft-cap 2026-06-22 não será acionado.                                                                       |
| Cron de auto-retirada (STORY-052)           | **Mitigado.** Cron `everyMinute` reusou STORY-034; E2E `travel(25h)` verde.                                                                     |
| Notificações spammam contratante (STORY-053) | Aberto — SLA 60s herdado da abertura; PO revisa microcopy ao validar texto-seed.                                                                |
| Texto-seed do PO                            | **Vira gargalo agora.** Sprint depende da entrega para STORY-053 iniciar — sem isso, a sprint trava com 11/13. **Sem progresso registrado.**    |
| Alexandro nos 5 papéis                      | Ritmo mantido; texto-seed exige modo PO dedicado (sem programar em paralelo).                                                                   |

### Decisões do PO (D+2)

- **Próximo bloco de trabalho:** PO em modo dedicado para escrever **texto-seed v1 dos 5 templates** (`candidatura_recebida_contratante`, `vaga_editada_material_profissional`, `vaga_cancelada_profissional`, `vaga_editada_material_candidatura_mantida_contratante`, `vaga_editada_material_candidatura_retirada_contratante`). Variáveis disponíveis estão documentadas no editor da STORY-020.
- **STORY-053 só inicia quando o texto-seed estiver pronto e validado.** Iniciar antes seria entregar a infra sem o conteúdo — anti-padrão do EPIC-001 (STORY-015).
- **STORY-054 entra em sequência** depois que 053 deployar em homolog. Não tentar paralelizar — validador depende do estado final do épico.
- **Reavaliação do escopo da sprint:** mantido. Mover 053 para W28 só se o texto-seed estourar 48h sem entrega.
- **Follow-up registrado:** `make e2e-webapp-integration` + deploy homolog do código da STORY-052 entra no próximo pacote, não bloqueia 053.

## Atualização de progresso — 2026-06-03 (D+2, texto-seed v1 aprovado)

> Gargalo do PO **quitado no mesmo dia**: texto-seed v1 dos 5 templates da STORY-053 escrito e aprovado pelo PO em chat. STORY-053 destravada — pronta para o agente programador pegar.

### Estado: 11/13 done, 1/13 destravada, 1/13 aguarda

| Estória   | Status | Bloqueio                                                       | Próximo movimento                                                              |
| --------- | ------ | -------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| STORY-053 | ready  | **Nenhum.** Texto-seed v1 aprovado, dependências (021/020/034/050/052/047) todas done. | Agente programador pega e executa (M).                                          |
| STORY-054 | ready  | Aguarda STORY-053 deployar em homolog.                         | Validador independente entra em sequência.                                     |

### Decisões / aprendizados do fechamento do texto-seed

- **Padrão STORY-015 mantido.** Texto-seed escrito como rascunho na própria estória, validado em chat pelo PO no mesmo dia, marcado como "v1 aprovado" antes do agente programador pegar — sem etapa separada de PDR, porque a decisão durável é o assunto canônico (já em ADR-011), não a copy.
- **Risco "texto-seed do PO vira gargalo" não materializou.** Diferente do que o snapshot da manhã previa, a janela de produção de conteúdo (escrita + revisão) coube em uma sessão de PO dedicada — sem programar em paralelo.
- **Idempotência do envio:** chave sugerida no rascunho (`"{tipo}:{candidatura_id}:{vaga_versao}"` para edição material; `"{tipo}:{candidatura_id}"` para os demais) — agente pode reusar como está ou propor IDR se descobrir caso de borda.

## Aprendizados em curso (mid-sprint)

> Registrar conforme acontecem; consolidar na seção "Fechamento do sprint" no fim.

- **STORY-048 (L) cabe em 1 sessão quando o spike de algoritmo (045) precede de verdade.** O gatilho de quebra documentado virou seguro morto, não plano A. Manter a disciplina spike-antes-de-implementação.
- **Decisões transversais emergem em estórias-âncora.** STORY-046 produziu DDR-002 (locale pt-BR + 24h) e IDR-025 (sessão no boot) — ambos não previstos na abertura, ambos com efeito em todas as telas futuras. Sinal de que a primeira estória de cada tipo de fluxo merece slot extra de revisão.
- **EPIC-008 ortogonal foi o certo.** Rodou em paralelo, fechou rápido, zero conflito de merge com EPIC-002. Padrão a repetir quando houver épico pequeno com superfície disjunta.
- **PO como pendência de planejamento ativo.** Texto-seed dos 5 templates da STORY-053 é entrega do PO, não do agente. Risco real se o ritmo de implementação ultrapassar o ritmo de produção de conteúdo — **e está ultrapassando** (status fim de D+1).
- **Estória "Designer + Programador na mesma sessão" entrega bem.** STORY-049 e STORY-050 fecharam SCREEN + back + front em uma sessão cada. Padrão útil quando a tela é pequena e a regra de negócio cabe num spike pré-existente — não tentar quando uma das duas dimensões está grande.
- **Reuso de componente nasce na estória anterior.** `BreakdownRow` saiu como público na STORY-049 antecipando o consumo pela STORY-051. Custo de planejar reuso na hora certa é baixo; custo de não planejar é refatoração tardia.
- **Componente compartilhado backend (Haversine→Support\Geo).** Refatoração de oportunidade na STORY-049 evitou duplicação feed↔detalhe. Sinal saudável; não inflar estória só pra refatorar, mas aceitar quando o overhead é nulo.
- **Snapshot de payload explicável tem que nascer na estória que cria o dado, não na que consome.** A STORY-050 só persistia `score_no_momento` (total); a 051 precisou voltar e adicionar `score_breakdown jsonb` + `alerta_habitualidade`. Pequena dívida cobrada com juros baixos, mas evitável: na próxima estória que persista resultado de algoritmo, exigir CA explícita de "snapshot do payload completo".
- **Bug de fuso revela política transversal faltante.** STORY-052 expôs em teste humano uma inconsistência entre card e edição (15:00 vs 18:00) que tinha causa em UTC↔local espalhado pelo código. Em vez de patch local, virou **IDR-026** (TurniDateTime) e 6 telas + 3 serviços passaram a delegar. Padrão: bug que aparece numa estória pode ser sintoma de regra transversal — antes de corrigir local, perguntar se vira IDR.
- **Cron `everyMinute` reusando STORY-034 funcionou sem mais infra.** Mais um voto a favor de manter "1 worker, vários commands" no MVP em vez de proliferar Cloud Run Jobs por feature.

## Fechamento do sprint (preencher no encerramento)

### O que foi entregue
- 

### O que ficou para trás (e por quê)
- 

### Aprendizados de produto
- 

### Aprendizados de processo
- 

### Ajustes para o próximo sprint
- 
