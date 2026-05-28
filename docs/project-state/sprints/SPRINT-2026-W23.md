---
sprint_id: SPRINT-2026-W23
wave: WAVE-2026-01
status: active
start_date: 2026-05-27
end_date: open
soft_cap_date: 2026-06-14
closure_rule: "Fechamento por goal-atingido: a sprint encerra assim que STORY-011 entregar veredito `approved`. Soft-cap em 2026-06-14 (~18 dias corridos) serve só como gatilho de reavaliação se o goal ainda não tiver batido; não é prazo de entrega."
goal: "EPIC-000 fechado: hello world em ambas as homologações (WebApp + Backoffice) deployado por tag, pipelines verdes, e veredito `approved` da STORY-011 (Validador)."
goal_outcome: pending
---

# SPRINT-2026-W23

## Objetivo do sprint

A SPRINT-2026-W22 fechou a fundação documental do EPIC-000 (9 ADRs aceitas + DDR-001 aceito + PDR-013 emergente + Design System vivo + screen spec ready). Esta sprint é o complemento: **transformar essa fundação em código que roda em homologação**, com pipelines duplos automáticos, hello world visível em WebApp e Backoffice, e veredito independente do Validador fechando o EPIC-000. É a **primeira sprint com código de produção** do projeto Turni — a régua de qualidade herdada (cobertura ≥ 80% geral / ≥ 98% núcleo, E2E em browser real, automação por padrão) entra em vigor a partir daqui sem exceção.

## Escopo e duração

- **Escopo**: 5 estórias — 2 de enablement (006 setup, 007 pipeline), 2 de implementation (008 WebApp, 009 Backoffice) e 1 de validation (011) — que juntas fecham o EPIC-000 Foundation.
- **Duração**: **aberta**, com fechamento por goal-atingido. Decisão deliberada do PO (alinhado com Alexandro), apoiada no precedente cunhado na W22: sprint cujo goal foi 100% atingido é fechada imediatamente em vez de manter calendário inerte.
- **Soft-cap em 2026-06-14** (~18 dias corridos): se nessa data o goal ainda não tiver batido, **não é prazo estourado** — é gatilho para o PO reavaliar (escopo realista, dependência aberta, sinal de mudança de plano). A reavaliação documenta no campo "Mudanças no escopo do sprint" e segue.

## Estórias incluídas

| ID | Título | Épico | Tipo | Papel | Tamanho | Status atual |
|---|---|---|---|---|---|---|
| STORY-006 | Setup do repositório e ambiente local em 1 comando | EPIC-000 | enablement | programador | M | ready |
| STORY-007 | Pipeline CI/CD com deploy automático para as duas homologações | EPIC-000 | enablement | programador | **L** | done |
| STORY-008 | "Hello world" no WebApp — rota raiz, health-check e identidade visual base | EPIC-000 | implementation | programador (+ designer em paralelo) | M | ready |
| STORY-009 | "Hello world" no Backoffice — rota raiz e health-check | EPIC-000 | implementation | programador | S | ready |
| STORY-011 | Validação final do EPIC-000 Foundation | EPIC-000 | validation | validador | M | ready |

**Sizing total**: 1 S + 3 M + 1 L. **Atenção ao L (STORY-007)** — única estória LARGE do sprint, candidata natural a estouro de sessão única. Critério de quebra está na própria estória; se na execução o agente sentir que não cabe em uma sessão, escala ao PO antes de inflar.

## Ordem de execução obrigatória (dependências do EPIC-000)

```
STORY-006 (ambiente local em 1 comando)
    │
    ▼
STORY-007 (pipeline CI/CD + deploy tag-based para as 2 homologações)
    │
    ├─► STORY-008 (hello world WebApp)   ──┐
    └─► STORY-009 (hello world Backoffice)─┤  podem rodar em paralelo
                                            │  (sessões distintas, mesma main)
                                            ▼
                                       STORY-011 (validação final do EPIC-000)
```

**Por que esta ordem.** É a única sequência respeitada pelos `blocked_by` registrados no `index.json`. Pular ordem força E2E impossível (não há ambiente para validar). O paralelismo legítimo está só entre 008 e 009, depois que 007 acabar — e mesmo lá depende do Designer ter feito o sync de 15 min com o Programador da STORY-008 (CA-14 da STORY-010 cobre isso, mas a entrega aconteceu na W22, então o sync acontece dentro da W23, no início de STORY-008).

## Compromisso visível ao fim do sprint

Diferente da W22, **esta sprint entrega coisas que o usuário externo consegue ver**:

- Duas URLs em homologação, acessíveis pelo browser:
  - WebApp em homologação (Flutter) servindo a tela hello world com identidade visual do DDR-001.
  - Backoffice em homologação (Livewire) servindo rota raiz + health-check.
- Pipeline CI/CD ativo no GitHub Actions: PR → testes verdes → build → deploy automático para homologação a cada tag aplicada na main. Três deploys consecutivos verdes em ≤ 10 min como CA herdado da STORY-007.
- Comando único de setup local funcionando para um novo agente/desenvolvedor: do `git clone` ao "está rodando" em ≤ 1 comando.
- `validation/report.md` da STORY-011 com veredito `approved` e evidências (logs, prints, link de homologação). Esse arquivo é o gatilho formal para marcar o EPIC-000 como `done`.

## Decisões de produto/arquitetura que entram em vigor agora

A fundação fechada na W22 não é decorativa. A partir desta sprint, os agentes operam sob:

- **ADR-001/002/003** — stack Laravel + Livewire + Flutter; monolito modular com api/admin/worker; monorepo poliglota único.
- **ADR-004** — hospedagem GCP (Cloud Run + Cloud SQL + Firebase Hosting); IaC Terraform; deploy promoção tag-based.
- **ADR-000** — PostgreSQL como banco principal.
- **ADR-007/008** — Sanctum + Argon2id + RBAC por coluna; log JSON estruturado em stdout + health-check padrão + métricas RED via log-based metrics no Cloud Monitoring.
- **ADR-005/006** — não entram nesta sprint (Pagar.me + habitualidade são para EPIC-003), mas ficam latentes para que STORY-006 não faça nada que conflite.
- **DDR-001 + PDR-013** — Design System vivo, dual-theme claro/escuro (padrão = claro), cor por perfil. STORY-008 consome o screen spec `SCREEN-STORY-008-hello-world-webapp` (status `ready`).

Programador e Designer carregam suas próprias skills + as ADRs/DDR vigentes antes de começar. Conflito real entre ADR vigente e necessidade da estória escala ao Arquiteto via nova ADR; não se ajusta silenciosamente no código.

## Riscos identificados na abertura

| Risco | Probabilidade | Impacto | Mitigação | Owner |
|---|---|---|---|---|
| Throughput de implementação muito menor do que o documental — sprint pode levar 2-3 semanas em vez de fechar rápido | **alta** | médio | Soft-cap em 2026-06-14 com reavaliação; PO não força calendário; aprende para sizing futuro | PO |
| STORY-007 (L) estoura sessão única — pipeline CI/CD + 2 deploys + tag-based é peça grande | alta | médio | Agente escala ao PO antes de inflar; quebra em sub-estórias documentadas se necessário; aceitar carry-over para W24 é exceção válida aqui | Programador + PO |
| Custo GCP em homologação sai do bolso do Alexandro e pode crescer sem alerta — ambientes ficam ligados 24×7 | média | médio | STORY-007 deve incluir alerta de orçamento básico (CA da própria estória); revisar custo diário durante a sprint | PO + Alexandro |
| Primeira interação real Designer ↔ Programador (STORY-008) — sync de 15 min nunca foi exercitado | média | médio | Designer faz disponibilidade prévia; sync registrado em "Notas do agente" da STORY-008; se descoberta de design emergir, vira DDR-002 imediato (não corrige no código) | Designer + Programador |
| STORY-011 reprova alguma estória anterior — validador independente pode achar gap não óbvio | média | alto (atrasa fechamento do EPIC-000) | Aceitar reprovação como sinal saudável; PO abre estórias de correção em mini-sprint W24; **não** pressiona Validador a aprovar | Validador + PO |
| Alexandro nos 5 papéis em sprint com mais código real — fadiga cognitiva maior do que na W22 | média | médio | Sessão dedicada por papel, troca declarada; PO faz check diário curto separado de execução; aceitar ritmo mais lento como dado, não como falha | Alexandro |
| Risco herdado da W22: throughput documental criou expectativa irrealista para implementação | alta | baixo (já mapeado) | Comunicado em "Aprendizados W22" e neste documento; PO não usa W22 como baseline | PO |

## Acompanhamento contínuo (PO)

- **Diário** (~10 min): olhar `index.json`, identificar o que está `in_progress` / `blocked` / `in_review`. Desbloquear o que pode.
- **Mid-sprint check em 2026-06-03 (quarta)**: PO verifica se 006+007 fecharam. Se 007 ainda estiver `in_progress` e já passou de 7 dias, considerar quebra e replanejamento.
- **Soft-cap check em 2026-06-14**: se goal não bateu, abrir seção "Mudanças no escopo do sprint" abaixo e decidir entre (a) seguir sem ajuste, (b) tirar STORY-011 e fazê-la em mini-sprint dedicada, (c) tirar STORY-009 (Backoffice) e fazer só WebApp ponta a ponta.

## Disciplina de processo nova (vinda das lições da W22)

Estes itens são **regras explícitas** a partir desta sprint — não dependem de boa vontade:

1. **`sprint_id` no frontmatter** da estória é atualizado no mesmo commit que adiciona a estória ao `sprints[*].story_ids` do `index.json`. Sem isso, a abertura está incompleta. *Já aplicado na abertura desta sprint nas 5 estórias.*
2. **Marcação de CA**: ao transicionar uma estória para `status: done` no frontmatter, todos os CAs atendidos no corpo do `.md` devem estar `[x]`. **Se houver `[ ]` em estória `done`, o PO devolve para `in_progress`.** Aplica a partir desta sprint sem retroatividade.
3. **"Verdade de corredor" vira PDR/ADR/DDR antes**: se uma estória citar uma decisão de produto/arquitetura/design sem registro associado, o agente para, escala ao papel dono e só prossegue depois do registro. PDR-013 mostrou que o custo é baixo.
4. **Sync Designer ↔ Programador na STORY-008**: ≤ 15 min, registrado em "Notas do agente" da estória, antes de qualquer linha de UI. Cobre CA-14 da STORY-010 que entregou DDR-001.

## Mudanças no escopo do sprint

> Toda alteração no conjunto de estórias após esta abertura registra aqui, com data e motivo.

| Data | O que mudou | Motivo | Custo (estória solta/movida) |
|---|---|---|---|
| — | (nenhuma até o momento) | — | — |

## Aprendizados em curso (mid-sprint)

Para registrar conforme acontecem; consolidados na seção "Fechamento do sprint" no fim.

- (vazio na abertura)

## Fechamento do sprint (preencher no encerramento)

### O que foi entregue
- ...

### O que ficou para trás (e por quê)
- ...

### Aprendizados
- <aprendizado de produto>
- <aprendizado de processo>

### Ajustes para o próximo sprint
- <ajuste>
