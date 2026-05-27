---
sprint_id: SPRINT-2026-W22
wave: WAVE-2026-01
status: active
start_date: 2026-05-27
end_date: 2026-06-07
goal: "Fundação documental do EPIC-000 fechada: 9 ADRs aceitas (ADR-000 a ADR-008) + DDR-001 aceito; estórias de implementação prontas para SPRINT-2026-W23."
---

# SPRINT-2026-W22

## Objetivo do sprint

Antes de qualquer linha de código de produção, o EPIC-000 Foundation exige decisões arquiteturais registradas (9 ADRs) e a fundação do Design System (DDR-001). Esta sprint concentra exatamente isso: 5 spikes do Arquiteto + 1 estória do Designer, todas paralelizáveis em boa parte. Ao fim, a sprint seguinte (W23) pode partir direto para STORY-006/007/008/009/011 com a base documental travada e aprovada pelo Alexandro. Nenhum código de produção é escrito nesta sprint — o que sai daqui são ADRs aceitas, DDR-001 aceito, tokens base, voice-and-tone e a screen spec da página de boas-vindas do WebApp em estado `ready`.

## Estórias incluídas

| ID | Título | Épico | Tipo | Papel | Tamanho | Status atual |
|---|---|---|---|---|---|---|
| STORY-001 | Spike Arquiteto — stack principal, topologia e monorepo vs polirepo | EPIC-000 | spike | arquiteto | M | **done** (2026-05-27) — ADR-001, ADR-002, ADR-003 aceitas |
| STORY-002 | Spike Arquiteto — hospedagem, IaC e estratégia de deploy | EPIC-000 | spike | arquiteto | M | **done** (2026-05-27) — ADR-004 aceita |
| STORY-003 | Spike Arquiteto — Pagar.me alto nível e estratégia de consulta de habitualidade | EPIC-000 | spike | arquiteto | M | ready (única restante — todas as outras `done`) |
| STORY-004 | Spike Arquiteto — autenticação base e observabilidade mínima | EPIC-000 | spike | arquiteto | M | **done** (2026-05-27) — ADR-007, ADR-008 aceitas |
| STORY-005 | Spike Arquiteto — ADR-000 retroativo formalizando PostgreSQL | EPIC-000 | spike | arquiteto | S | **done** (2026-05-27) — ADR-000 aceita |
| STORY-010 | DDR-001 — Fundação do Design System (tokens, tipografia, paleta) | EPIC-000 | implementation | designer | M | **done** (2026-05-27) — DDR-001 aceito; DS + screen spec de STORY-008 em `ready` |

**Progresso**: 5 de 6 estórias `done` (STORY-001, 002, 004, 005, 010); resta **STORY-003** (`ready`). 7 ADRs aceitas pelo Alexandro (ADR-000 a 004, 007, 008) + **DDR-001 aceito**.

**Saída esperada (atualizada)**: faltam apenas **ADR-005 e ADR-006** (STORY-003 — Pagar.me + habitualidade) para fechar as 9 ADRs do goal. DDR-001, tokens, voice-and-tone e screen spec de STORY-008 (`ready`) já entregues.

## Ordem de execução sugerida (paralelização)

```
Dia 1 (paralelo, sem bloqueio entre si):
  ├─► STORY-001 (stack + topologia + monorepo)    ─┐
  ├─► STORY-005 (ADR-000 retroativo PostgreSQL)    │  3 frentes paralelas
  └─► STORY-010 (DDR-001 + tokens + screen spec)  ─┘  desde o dia 1

Após STORY-001 fechar (ADRs aceitas pelo Alexandro):
  ├─► STORY-002 (hospedagem + IaC + deploy)
  ├─► STORY-003 (Pagar.me + habitualidade)
  └─► STORY-004 (auth + observabilidade — depende também de STORY-002)
```

**Por que esta ordem:** STORY-001 destrava 002, 003, 004 (todas dependem de ADR-001). STORY-005 não tem dependência — pode rodar em qualquer momento. STORY-010 idem. Começar pelas três independentes (001/005/010) no dia 1 garante throughput desde o primeiro momento e cria material para validar o fluxo de "spike → ADR proposta → aprovação humana de Alexandro → `accepted`" antes da próxima onda de spikes.

### Execução real — dia 1 (2026-05-27)

O Arquiteto executou em rajada três spikes do plano original (STORY-001, STORY-002 e STORY-005) e Alexandro aprovou as 5 ADRs resultantes no mesmo dia. Ordem efetiva: 001 → 002 (puxada antes de 005 porque o agente já tinha contexto de stack) → 005. STORY-010 (Designer) e STORY-003/004 (Arquiteto) seguem `ready` para os próximos dias do sprint.

**Frentes disponíveis a partir de 2026-05-28:**
- STORY-003 (Pagar.me + habitualidade) — Arquiteto. **Única estória restante do sprint.**

STORY-004 (auth/observabilidade) e STORY-010 (DDR-001) foram concluídas ainda em 2026-05-27 (ver atualização abaixo), restando só STORY-003 para fechar o goal.

### Execução real — atualização 2026-05-27 (fim do dia)

Além das três spikes da manhã (001/002/005), no mesmo dia fecharam:
- **STORY-004** (Arquiteto) — ADR-007 (auth base Sanctum) e ADR-008 (observabilidade mínima) aceitas.
- **STORY-010** (Designer) — DDR-001 (Fundação do Design System) aceito por Alexandro. Saiu o Design System vivo (`design/system/`: tokens com contraste AA, README, components, patterns, voice-and-tone + 2 previews HTML), o screen spec `SCREEN-STORY-008` em `ready`, e — como subproduto — **PDR-013** (dual-theme claro/escuro) com a seção "Temas" adicionada em `non-functional.md`.

Resultado: **5 de 6 estórias `done` no dia 1**. Resta STORY-003.

## Compromisso visível ao fim do sprint

Ao fim do sprint, **nada novo é visível ao usuário externo** — esta sprint é deliberação documental. O que estará observável:

- **Em `docs/project-state/decisions/adr/`**: 9 arquivos de ADR (ADR-000 a ADR-008) em `status: accepted`, cada um com `approved_by: Alexandro` registrado.
- **Em `docs/project-state/decisions/ddr/`**: DDR-001 em `status: accepted` com `approved_by` registrado.
- **Em `docs/project-state/design/system/`**: `tokens.md`, `voice-and-tone.md`, e (se aplicável) `components.md` e `patterns.md` placeholders.
- **Em `docs/project-state/design/screens/`**: `STORY-008-hello-world-webapp.md` em `status: ready`.
- **No `index.json`**: `decisions.adr[]` com 9 entradas aceitas; `decisions.ddr[]` com DDR-001 aceito; `design.system.*` populado; `design.screens[]` com SCREEN-STORY-008-hello-world-webapp; STORY-008 ganha `design_screen_id` apontando para o screen criado.
- **Esta sprint fechada** em `SPRINT-2026-W22.md` com seção "Fechamento" preenchida.

## Decisões pendentes que podem afetar o sprint

- **Aprovações humanas restantes**: só as 2 ADRs de STORY-003 (ADR-005, ADR-006) dependem do Alexandro. As demais (7 ADRs + DDR-001) já estão `accepted`.
- **Decisão de produto nova surgida na sprint:** **PDR-013** (dual-theme claro/escuro; padrão do MVP = claro) — emergiu da fundação do Design System (DDR-001), aprovada pelo Alexandro e já `accepted`. Atualizou `non-functional.md` (seção "Temas"), que era silente sobre o tema.

## Riscos identificados na abertura

| Risco | Probabilidade | Impacto | Mitigação | Owner |
|---|---|---|---|---|
| Atraso na aprovação humana das ADRs/DDR pelo Alexandro bloqueia estórias dependentes (002, 003, 004) | média | alto | Alexandro reserva janela diária (~30 min) para revisar artefatos `in_review`; aprovações em até 24h | PO |
| STORY-001 descobre que stack escolhida é ruim para PWA/PostgreSQL/Pagar.me e exige revisão de princípios | baixa | alto | Arquiteto avalia mínimo 2 opções reais por ADR (CA-1 da STORY-001); se descoberta significativa, escala antes de propor ADR | Arquiteto |
| STORY-003 (Pagar.me + habitualidade) descobre que as duas ADRs deveriam ser estórias separadas | média | médio | A própria estória diz: se complexidade emergir, escalar ao PO antes de forçar junto — não inflar | Arquiteto + PO |
| STORY-010 (DDR-001) atrasa e STORY-008/009 do próximo sprint não terão tokens nem screen spec | baixa | médio | DDR-001 começa no dia 1 em paralelo às spikes; sync curto com o Programador antes do screen spec ser fechado (CA-14 da STORY-010) | Designer + PO |
| Alexandro nos 5 papéis cria sobreposição cognitiva no mesmo dia (PO desbloqueando, Arquiteto escrevendo, Designer entregando) | alta | médio | Disciplina de sessão dedicada por papel; troca declarada explicitamente; PO faz check diário curto (~10 min) sobre `index.json` em janela separada | Alexandro |
| Risco herdado da onda: Pagar.me sandbox indisponível no momento de STORY-003 limita validação técnica das opções de mock | baixa | baixo nesta sprint | STORY-003 só decide abordagem; implementação real fica para EPIC-003. Documentação Pagar.me pública é suficiente para deliberar agora | Arquiteto |

## Mudanças no escopo do sprint

> Toda alteração no conjunto de estórias após esta abertura registra aqui, com data e motivo.

| Data | O que mudou | Motivo | Custo (estória solta/movida) |
|---|---|---|---|
| — | (nenhuma até o momento) | — | — |

## Aprendizados em curso (mid-sprint)

Para registrar conforme acontecem; consolidados na seção "Fechamento do sprint" no fim.

- **2026-05-27 — Throughput inicial muito acima do esperado.** 3 estórias `done` + 5 ADRs aceitas no dia 1. Indica que o tamanho estimado das spikes pode estar conservador, **ou** que o Arquiteto + aprovador estão muito sintonizados nesta fase (ainda 1 pessoa nos dois papéis). Sinal a vigiar: STORY-003 e STORY-004 envolvem mais incerteza técnica (Pagar.me, habitualidade, auth) — manter rigor de "mínimo 2 opções reais por ADR" mesmo no ritmo rápido.
- **2026-05-27 — Inconsistência de processo nos arquivos `.md` de STORY-001 e STORY-002.** Frontmatter foi para `status: done` mas os CAs no corpo continuam `[ ]`. STORY-005 está correta (`[x]` em cada CA). Ação para o próximo sprint: agente deve marcar cada CA com `[x]` ao fechar a estória, junto da transição de status — está no template e na disciplina de "Notas do agente" do `agent-task-format.md`, mas precisa ser hábito. PO **não vai reprovar** STORY-001/002 retroativamente — ADRs aceitas pelo Alexandro são sinal forte de cumprimento — mas vale o ajuste daqui em diante.
- **2026-05-27 — Cadência de aprovação humana funcionou.** 7 ADRs + DDR-001 aprovadas no mesmo dia em que foram propostas; risco "atraso na aprovação humana bloqueia estórias dependentes" não se materializou. Manter a janela diária dedicada.
- **2026-05-27 — DDR-001 mostrou que iterar visualmente vale a pena.** O Design System passou por duas revisões guiadas pelo Alexandro antes do `accepted`: (1) fonte de verdade restrita ao `app.html` (landing é do marketing); (2) admin migrado de vermelho para azul-navy, liberando o vermelho para significar só erro/destrutivo. Previews HTML versionados (`design/system/preview*.html`) foram decisivos para esse julgamento — barato de produzir, alto valor de decisão. Replicar o hábito de "preview navegável" quando uma decisão de design for ambígua.
- **2026-05-27 — `non-functional.md` estava silente sobre tema.** Estórias citavam "dark fora do MVP" atribuindo ao doc, sem lastro. Lição de processo: suposição repetida em estória não substitui decisão registrada — virou PDR-013. Vigiar outras "verdades de corredor" sem PDR/ADR/DDR.
- **2026-05-27 — STORY-010 seguiu a disciplina de checklist** (CAs e DoD marcados ao fechar), corrigindo na prática a inconsistência notada em STORY-001/002.

## Acompanhamento contínuo (PO)

- **Diário** (~10 min): olhar `index.json`, identificar o que está `in_progress`, `blocked`, `in_review`. Desbloquear o que pode.
- **Aprovações humanas**: janela diária dedicada para revisar ADRs/DDR em `in_review` e marcar `accepted` ou pedir revisão.
- **Mid-sprint check** (~2026-06-01, segunda): verificar se o goal vai bater. Se 3 ou mais ADRs ainda em `proposed` sem decisão, intensificar revisão.

## Fechamento do sprint (preencher no encerramento — 2026-06-07)

### O que foi entregue
- ...

### O que ficou para trás (e por quê)
- ...

### Aprendizados
- <aprendizado de produto>
- <aprendizado de processo>

### Ajustes para o próximo sprint
- <ajuste>
