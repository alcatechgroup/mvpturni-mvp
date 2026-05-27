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
| STORY-001 | Spike Arquiteto — stack principal, topologia e monorepo vs polirepo | EPIC-000 | spike | arquiteto | M | ready |
| STORY-002 | Spike Arquiteto — hospedagem, IaC e estratégia de deploy | EPIC-000 | spike | arquiteto | M | ready |
| STORY-003 | Spike Arquiteto — Pagar.me alto nível e estratégia de consulta de habitualidade | EPIC-000 | spike | arquiteto | M | ready |
| STORY-004 | Spike Arquiteto — autenticação base e observabilidade mínima | EPIC-000 | spike | arquiteto | M | ready |
| STORY-005 | Spike Arquiteto — ADR-000 retroativo formalizando PostgreSQL | EPIC-000 | spike | arquiteto | S | ready |
| STORY-010 | DDR-001 — Fundação do Design System (tokens, tipografia, paleta) | EPIC-000 | implementation | designer | M | ready |

**Total**: 6 estórias (5 spikes + 1 designer). Saída esperada: 9 ADRs propostas → aceitas + 1 DDR proposto → aceito + tokens + voice-and-tone + screen spec de STORY-008 em `ready`.

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

## Compromisso visível ao fim do sprint

Ao fim do sprint, **nada novo é visível ao usuário externo** — esta sprint é deliberação documental. O que estará observável:

- **Em `docs/project-state/decisions/adr/`**: 9 arquivos de ADR (ADR-000 a ADR-008) em `status: accepted`, cada um com `approved_by: Alexandro` registrado.
- **Em `docs/project-state/decisions/ddr/`**: DDR-001 em `status: accepted` com `approved_by` registrado.
- **Em `docs/project-state/design/system/`**: `tokens.md`, `voice-and-tone.md`, e (se aplicável) `components.md` e `patterns.md` placeholders.
- **Em `docs/project-state/design/screens/`**: `STORY-008-hello-world-webapp.md` em `status: ready`.
- **No `index.json`**: `decisions.adr[]` com 9 entradas aceitas; `decisions.ddr[]` com DDR-001 aceito; `design.system.*` populado; `design.screens[]` com SCREEN-STORY-008-hello-world-webapp; STORY-008 ganha `design_screen_id` apontando para o screen criado.
- **Esta sprint fechada** em `SPRINT-2026-W22.md` com seção "Fechamento" preenchida.

## Decisões pendentes que podem afetar o sprint

- **9 aprovações humanas de ADR** + **1 aprovação humana de DDR** dependem do Alexandro. Cadência sugerida: revisar e aprovar/comentar cada artefato proposto **em até 24h** após o agente marcar `status: in_review`. Sem isso, as estórias dependentes (002, 003, 004) ficam paradas esperando.
- Nenhuma decisão de produto nova prevista para esta sprint — todos os PDRs aplicáveis já estão `accepted`.

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
