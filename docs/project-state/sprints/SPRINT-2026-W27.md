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

## Aprendizados em curso (mid-sprint)

> Registrar conforme acontecem; consolidar na seção "Fechamento do sprint" no fim.

- 

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
