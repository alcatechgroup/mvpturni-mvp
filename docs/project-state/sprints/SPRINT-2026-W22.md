---
sprint_id: SPRINT-2026-W22
wave: WAVE-2026-01
status: closed
start_date: 2026-05-27
end_date: 2026-06-07
closed_at: 2026-05-27
closed_by: PO (Alexandro / Claude)
goal: "Fundação documental do EPIC-000 fechada: 9 ADRs aceitas (ADR-000 a ADR-008) + DDR-001 aceito; estórias de implementação prontas para SPRINT-2026-W23."
goal_outcome: achieved
---

# SPRINT-2026-W22

## Objetivo do sprint

Antes de qualquer linha de código de produção, o EPIC-000 Foundation exige decisões arquiteturais registradas (9 ADRs) e a fundação do Design System (DDR-001). Esta sprint concentra exatamente isso: 5 spikes do Arquiteto + 1 estória do Designer, todas paralelizáveis em boa parte. Ao fim, a sprint seguinte (W23) pode partir direto para STORY-006/007/008/009/011 com a base documental travada e aprovada pelo Alexandro. Nenhum código de produção é escrito nesta sprint — o que sai daqui são ADRs aceitas, DDR-001 aceito, tokens base, voice-and-tone e a screen spec da página de boas-vindas do WebApp em estado `ready`.

## Estórias incluídas

| ID | Título | Épico | Tipo | Papel | Tamanho | Status atual |
|---|---|---|---|---|---|---|
| STORY-001 | Spike Arquiteto — stack principal, topologia e monorepo vs polirepo | EPIC-000 | spike | arquiteto | M | **done** (2026-05-27) — ADR-001, ADR-002, ADR-003 aceitas |
| STORY-002 | Spike Arquiteto — hospedagem, IaC e estratégia de deploy | EPIC-000 | spike | arquiteto | M | **done** (2026-05-27) — ADR-004 aceita |
| STORY-003 | Spike Arquiteto — Pagar.me alto nível e estratégia de consulta de habitualidade | EPIC-000 | spike | arquiteto | M | **done** (2026-05-27) — ADR-005, ADR-006 aceitas |
| STORY-004 | Spike Arquiteto — autenticação base e observabilidade mínima | EPIC-000 | spike | arquiteto | M | **done** (2026-05-27) — ADR-007, ADR-008 aceitas |
| STORY-005 | Spike Arquiteto — ADR-000 retroativo formalizando PostgreSQL | EPIC-000 | spike | arquiteto | S | **done** (2026-05-27) — ADR-000 aceita |
| STORY-010 | DDR-001 — Fundação do Design System (tokens, tipografia, paleta) | EPIC-000 | implementation | designer | M | **done** (2026-05-27) — DDR-001 aceito; DS + screen spec de STORY-008 em `ready` |

**Progresso**: **6 de 6 estórias `done`** (STORY-001, 002, 003, 004, 005, 010). **9 ADRs aceitas** pelo Alexandro (ADR-000 a ADR-008) + **DDR-001 aceito**.

**Saída esperada (atingida)**: as 9 ADRs do goal estão `accepted` (ADR-005 e ADR-006 fechadas em 2026-05-27 com STORY-003). DDR-001, tokens, voice-and-tone e screen spec de STORY-008 (`ready`) entregues. Goal documental do EPIC-000 cumprido; o "Fechamento do sprint" formal abaixo fica para o PO no encerramento.

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

**Frentes disponíveis a partir de 2026-05-28** (registro original do dia 1, mantido como histórico):
- STORY-003 (Pagar.me + habitualidade) — Arquiteto.

Na prática, STORY-004 e STORY-010 fecharam ainda em 2026-05-27 (ver atualização abaixo) e **STORY-003 também fechou no mesmo dia**, eliminando a fila para 2026-05-28. Detalhe registrado na seção "Execução real — fechamento (2026-05-27)".

### Execução real — atualização 2026-05-27 (fim do dia)

Além das três spikes da manhã (001/002/005), no mesmo dia fecharam:
- **STORY-004** (Arquiteto) — ADR-007 (auth base Sanctum) e ADR-008 (observabilidade mínima) aceitas.
- **STORY-010** (Designer) — DDR-001 (Fundação do Design System) aceito por Alexandro. Saiu o Design System vivo (`design/system/`: tokens com contraste AA, README, components, patterns, voice-and-tone + 2 previews HTML), o screen spec `SCREEN-STORY-008` em `ready`, e — como subproduto — **PDR-013** (dual-theme claro/escuro) com a seção "Temas" adicionada em `non-functional.md`.

Resultado: **5 de 6 estórias `done` no dia 1**. Resta STORY-003.

### Execução real — fechamento (2026-05-27)

No mesmo dia 1, encerrando o sprint inteiro em janela de horas, o Arquiteto também concluiu **STORY-003** (Pagar.me + habitualidade) com ADR-005 (integração Pagar.me alto nível) e ADR-006 (estratégia de consulta de habitualidade) aceitas por Alexandro. Commit final do sprint: `6320665 feat: add ADR-005 e ADR-006, fecha STORY-003`.

Resultado consolidado: **6 de 6 estórias `done` no dia 1**, **9 ADRs aceitas (ADR-000 a ADR-008)** + **DDR-001 aceito** + **PDR-013 aceito** (subproduto). Goal documental do EPIC-000 **cumprido 11 dias antes do end_date original** (2026-06-07).

## Compromisso visível ao fim do sprint

Ao fim do sprint, **nada novo é visível ao usuário externo** — esta sprint é deliberação documental. O que estará observável:

- **Em `docs/project-state/decisions/adr/`**: 9 arquivos de ADR (ADR-000 a ADR-008) em `status: accepted`, cada um com `approved_by: Alexandro` registrado.
- **Em `docs/project-state/decisions/ddr/`**: DDR-001 em `status: accepted` com `approved_by` registrado.
- **Em `docs/project-state/design/system/`**: `tokens.md`, `voice-and-tone.md`, e (se aplicável) `components.md` e `patterns.md` placeholders.
- **Em `docs/project-state/design/screens/`**: `STORY-008-hello-world-webapp.md` em `status: ready`.
- **No `index.json`**: `decisions.adr[]` com 9 entradas aceitas; `decisions.ddr[]` com DDR-001 aceito; `design.system.*` populado; `design.screens[]` com SCREEN-STORY-008-hello-world-webapp; STORY-008 ganha `design_screen_id` apontando para o screen criado.
- **Esta sprint fechada** em `SPRINT-2026-W22.md` com seção "Fechamento" preenchida.

## Decisões pendentes que podem afetar o sprint

- **Aprovações humanas restantes**: **nenhuma**. Em 2026-05-27 todas as aprovações foram concluídas — 9 ADRs (ADR-000 a ADR-008), DDR-001 e PDR-013 estão `accepted`, com `approved_by: Alexandro` registrado.
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

## Fechamento do sprint (encerrado em 2026-05-27)

> Sprint fechado pelo PO em **2026-05-27**, mesmo dia da abertura. Goal documental do EPIC-000 atingido em janela de horas, **11 dias antes do `end_date` original** (2026-06-07). Decisão de fechar agora em vez de manter aberto até 2026-06-07 é deliberada: o compromisso do sprint foi 100% entregue, manter o sprint aberto sem trabalho residual só polui o estado. SPRINT-2026-W23 começa em seguida com as estórias de implementação (STORY-006/007/008/009 + validação STORY-011).

### O que foi entregue

**Estórias (6/6 `done`):**
- **STORY-001** — ADRs aceitas: ADR-001 (stack Laravel + Livewire + Flutter), ADR-002 (topologia: monolito modular + api/admin/worker), ADR-003 (monorepo poliglota único).
- **STORY-002** — ADR-004 aceita (hospedagem GCP — Cloud Run + Cloud SQL + Firebase Hosting; IaC Terraform; deploy promoção tag-based).
- **STORY-003** — ADRs aceitas: ADR-005 (integração Pagar.me alto nível, ACL no módulo Pagamento, mock dedicado, idempotência, pré-autorização → captura → Pix com webhook validado) e ADR-006 (consulta de habitualidade — query direta + índice composto sobre Postgres, janela semana corrida America/Sao_Paulo, PF×PJ na mesma consulta).
- **STORY-004** — ADRs aceitas: ADR-007 (auth base — Sanctum cookie SPA no WebApp + sessão web no Backoffice, Argon2id, RBAC por coluna) e ADR-008 (observabilidade mínima — log JSON em stdout, health-check padrão, métricas RED via log-based metrics, alerta de indisponibilidade).
- **STORY-005** — ADR-000 aceita (formalização retroativa do PostgreSQL como banco principal).
- **STORY-010** — DDR-001 aceito (fundação do Design System: dual-theme claro/escuro + cor por perfil); Design System vivo em `design/system/` (tokens com contraste AA, README, `components.md`, `patterns.md`, `voice-and-tone.md`, 2 previews HTML); screen spec `SCREEN-STORY-008-hello-world-webapp` em `ready`.

**Decisões registradas no sprint:** 9 ADRs (ADR-000 a ADR-008), 1 DDR (DDR-001), 1 PDR novo (PDR-013, dual-theme — emergiu de DDR-001 e cobriu silêncio do `non-functional.md`).

**Subprodutos não previstos no goal mas valiosos:**
- `non-functional.md` ganhou seção "Temas" (antes silente).
- Previews HTML versionados do Design System (`preview.html`, `preview-backoffice.html`) — ferramenta barata e de alto valor para decisão visual.
- Atualização contínua do `index.json` em cada commit — o índice nunca ficou defasado por mais de algumas horas.

### O que ficou para trás (e por quê)

**Nada do escopo do sprint ficou para trás.** O sprint entregou 6/6 estórias e o goal completo.

Itens **fora do escopo** que continuam pendentes (esperado, registrado aqui só para contexto da próxima sprint):
- STORY-006/007/008/009 (implementação Foundation) — destravadas, vão para SPRINT-2026-W23.
- STORY-011 (validação final do EPIC-000) — depende das anteriores.

### Aprendizados

**Aprendizados de produto:**

- **PDR-013 nasceu de uma estória de design.** O dual-theme não estava previsto no roadmap, mas emergiu quando o Designer foi estruturar tokens e percebeu que "MVP só no claro" era uma suposição sem registro. Esse padrão — decisão de produto silente virando PDR a partir de uma decisão técnica/de design adjacente — é saudável e deve continuar. Lição: quando um papel não-PO encontra uma "verdade de corredor", o gesto correto é parar e pedir PDR, não absorvê-la na própria estória.
- **Cor por perfil emergiu como decisão de produto, não só visual.** Migrar admin de vermelho para azul-navy liberou o vermelho para significar apenas erro/destrutivo — semântica de cor é decisão de produto disfarçada de design. Vale revisitar outras semânticas de cor antes de telas de fluxo financeiro entrarem (Epic-003).
- **A fundação documental foi maior do que o goal explicitava.** O sprint pedia "9 ADRs + DDR-001"; entregou também tokens AA, voice-and-tone, screen spec, dois previews HTML navegáveis e atualização do `non-functional.md`. A definição mínima do goal estava conservadora.

**Aprendizados de processo:**

- **Throughput de fundação documental ficou ~11× acima do planejado.** Plano era 6 estórias em até 11 dias; saíram em ~1 dia. Hipóteses concorrentes: (a) tamanho S/M de spike puramente documental está superdimensionado quando ADRs já têm referência clara de stack candidata; (b) "Alexandro nos 5 papéis" elimina ciclos de aprovação cross-pessoa; (c) viés de fundação — primeira sprint é toda contexto novo, o Arquiteto carrega ele de uma vez só. Vigiar nas próximas sprints: quando entrar estória de implementação real (STORY-006+), o efeito pode desaparecer. **Não recalibrar o sizing ainda — esperar 2-3 sprints com naturezas diferentes para ter sinal real.**
- **Aprovação humana no mesmo dia funcionou em massa.** 9 ADRs + DDR-001 + PDR-013 aprovados todos em 2026-05-27. Risco "atraso na aprovação humana bloqueia estórias dependentes" não se materializou. Manter a janela diária dedicada e a disciplina de propor → revisar → `accepted` em ciclo curto.
- **Inconsistência de checklist no `.md` da estória (CAs `[ ]` em estória `done`) persistiu em 4 das 6 estórias.** STORY-001, 002, 003, 004 fecharam com frontmatter `done` mas CAs no corpo continuam `[ ]`. STORY-005 e STORY-010 marcaram corretamente. PO observou já na primeira metade do dia (entrada de mid-sprint) e **não vai reprovar retroativamente** — as ADRs aceitas pelo Alexandro são sinal forte de cumprimento real. Mas o padrão se repetiu mesmo após o aviso, o que mostra que "lembrar o agente no chat" é fraco. **Ação para a próxima sprint:** reforçar no preâmbulo da estória de spike um lembrete explícito de marcação de CA no fechamento, e considerar um pre-commit hook leve (ou check do PO) que rejeita transição de status para `done` enquanto houver `[ ]` no corpo.
- **`sprint_id` no frontmatter de estória diverge do `index.json`.** STORY-001, 002, 005, 010 ficaram com `sprint_id: null` no frontmatter, embora `index.json` as tenha em `sprints[0].story_ids`. Inconsistência de baixo impacto operacional (o índice manda) mas de alta confusão para quem ler só o `.md`. **Será corrigida no fechamento desta sprint** (parte do mesmo commit) e adicionada à disciplina de "abertura de sprint": ao incluir uma estória no sprint, atualizar `sprint_id` no `.md` da estória junto do `index.json`.
- **DDR-001 mostrou que "preview navegável vale a pena".** Duas revisões guiadas pelo Alexandro antes do `accepted`, com base em `preview.html` e `preview-backoffice.html` versionados. Custo baixíssimo (HTML estático), valor de decisão alto. Replicar o hábito em qualquer decisão de design ambígua daqui pra frente.
- **Sprint terminou no dia 1 — mid-sprint check (2026-06-01) não foi necessário.** Mecânica de sprint do `sprint-mechanics.md` precisa absorver o caso "sprint pequeno fecha cedo": critério explícito para fechar antecipadamente em vez de manter aberto sem trabalho. Está sendo aplicado aqui pela primeira vez, registrado neste fechamento, e vira regra: **sprint cujo goal foi 100% atingido e sem estórias residuais é fechado imediatamente, e a próxima sprint é aberta em seguida em vez de manter o calendário original.**

### Ajustes para o próximo sprint

- **Disciplina de marcação de CA**: ao transicionar uma estória para `done`, marcar `[x]` em todo CA atendido no corpo do `.md`, no mesmo commit que atualiza o frontmatter. Validar no PR (visualmente no diff) — se houver `[ ]` em estória `done`, devolve para `in_progress` (regra explícita, não dependente de boa vontade).
- **Disciplina de `sprint_id` na abertura**: ao puxar uma estória para a sprint, atualizar o `sprint_id` no frontmatter da estória junto do `index.json` (par único de commits).
- **SPRINT-2026-W23 abre logo em seguida** (provavelmente 2026-05-28) com STORY-006 (setup do repositório e ambiente local em 1 comando) como ponto de partida — primeira sprint com código de produção do projeto. Manter o tamanho conservador na abertura: o throughput observado nesta sprint é de natureza documental e não deve ser projetado para sprints de implementação.
- **Manter previews HTML como ferramenta padrão de decisão de design ambígua** — registrar no `docs/skills/designer/` se ainda não estiver.
- **Vigiar "verdades de corredor"** — se uma estória citar uma decisão de produto sem PDR associado, parar e pedir PDR antes de prosseguir. PDR-013 mostrou que esse gesto é barato e evita débito.
