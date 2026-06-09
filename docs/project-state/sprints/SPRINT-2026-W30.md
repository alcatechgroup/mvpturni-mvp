---
sprint_id: SPRINT-2026-W30
wave: WAVE-2026-01
status: active  # planned | active | closed
start_date: 2026-06-09
end_date: null  # fechamento por goal-atingido
opened_at: 2026-06-09
opened_by: "PO (Alexandro / Claude)"
activated_at: 2026-06-09
activated_by: "PO (Alexandro / chat)"
soft_cap_date: 2026-07-14  # ~35 dias — épico de feature transacional (mais pesado que a pausa de UX da W29)
closure_rule: "Fechamento por goal-atingido: encerra quando STORY-083..088 estiverem `done` E STORY-089 (validador) emitir veredito em `validation/report.md` aceitável pelo PO (`approved` ou `approved_with_pending` assumido como goal-atingido). STORY-082 (deflake cronômetro + housekeeping de índice) é ortogonal — carry-forward da W29; pode iniciar imediatamente e não bloqueia o goal. A dívida de a11y do EPIC-012 fica FORA desta sprint (decisão do dono em 2026-06-09)."
goal: "Fechar o ciclo do turno com avaliação recíproca obrigatória (EPIC-004): após cada turno `finalizado`, ambos os lados são bloqueados em nova ação até avaliarem (estrelas obrigatórias + comentário opcional); XP/score/nível atualizam automaticamente; score público e depoimentos visíveis no perfil — tudo demonstrável em homologação. Decisões em ADR-019 (modelo/eventos/gate) e DDR-004 (visibilidade de depoimentos). Ortogonal: STORY-082 quita a dívida da W28/W29 (deflake do E2E de sincronia do cronômetro + housekeeping de índice IDR-028/IDR-029 + SCREEN-077)."
---

# SPRINT-2026-W30

## Objetivo do sprint

A SPRINT-2026-W29 fechou o EPIC-012 (shell de navegação + pente fino de UX) por goal-atingido em 2026-06-09 — o WebApp agora é navegavelmente coerente nos dois papéis. Honrada a "pausa de UX" entre épicos transacionais, a W30 retoma a feature de produto que estava reservada para depois: o **EPIC-004 — Avaliação recíproca e fechamento do ciclo**.

O problema que esta sprint resolve: hoje o turno termina em `finalizado` e nada acontece — não há avaliação, o XP/score não acumula, a trilha de níveis não anda e o algoritmo de match perde sua principal entrada de qualidade. A avaliação recíproca obrigatória (PDR-005) é o **gatilho que faz o produto evoluir a cada turno**: força a reflexão antes da próxima ação e alimenta a confiança bilateral. Esta sprint entrega o ciclo completo (avaliação → XP/score/nível → gate bloqueante → reputação visível) dentro do shell entregue na W29.

## Escopo e duração

- **Escopo**: **8 estórias** — EPIC-004 inteiro (2 spikes de decisão + 4 implementação + 1 validação) + STORY-082 (carry-forward W29, ortogonal). Mix: **1 S + 6 M + 1 L**.
  - A **L** (STORY-085, backend modelo+motor) é candidata a quebra de sessão: se modelo+migração+motor+eventos não couber, separar (a) modelo+migração+evento de pendência de (b) motor de XP/score/nível. Escalar ao PO **antes** de inflar (padrão W28/W29).
- **Superfícies**: API (`apps/api`) para modelo/motor/gate; WebApp Contratante (desktop) + Profissional (mobile) para telas de avaliação e perfil. Backoffice fora.
- **Duração**: aberta, **fechamento por goal-atingido**. Soft-cap em **2026-07-14** (~35 dias) como gatilho de reavaliação, não prazo — folga maior por ser feature transacional.

## Estórias incluídas

| ID        | Título                                                                                      | Épico    | Tipo           | Papel       | Tamanho | Status |
| --------- | ------------------------------------------------------------------------------------------- | -------- | -------------- | ----------- | ------- | ------ |
| STORY-083 | Spike Arquiteto — modelo + eventos + ponto do gate (ADR-019) + spec do fluxo                | EPIC-004 | spike          | arquiteto   | M       | done   |
| STORY-084 | Spike Designer — DDR-004 (depoimentos) + telas de avaliação + perfil + protótipo            | EPIC-004 | spike          | designer    | M       | ready  |
| STORY-085 | Backend — modelo de avaliação + motor de XP/score + subida de nível + evento                | EPIC-004 | implementation | programador | L       | ready  |
| STORY-086 | Backend — gate bloqueante (sem candidatar/publicar com avaliação pendente)                  | EPIC-004 | implementation | programador | M       | ready  |
| STORY-087 | Frontend — telas de avaliação recíproca (estrelas + comentário) no shell                    | EPIC-004 | implementation | programador | M       | ready  |
| STORY-088 | Frontend — perfil (score/nível/XP/depoimentos) + UX do gate bloqueante                      | EPIC-004 | implementation | programador | M       | ready  |
| STORY-089 | Validação final do EPIC-004                                                                 | EPIC-004 | validation     | validador   | M       | ready  |
| STORY-082 | Deflake cronômetro (F-B-1) + housekeeping índice (IDR-028/029 + SCREEN-077) — carry-forward | EPIC-003 | bugfix         | programador | S       | ready  |

**Sizing total**: **1 S + 6 M + 1 L (8 estórias)**.

## Ordem de execução obrigatória

```
STORY-083 (Arquiteto — ADR-019: modelo + eventos + ponto do gate + spec do fluxo) ──┐
STORY-084 (Designer — DDR-004 + SCREENs avaliação/perfil + protótipo aprovado) ─────┤ (paralelo; ambos antes da implementação)
    │ ADR-019 accepted                                                               │ DDR-004 + protótipo "vai"
    ▼                                                                                ▼
STORY-085 (BE — modelo + motor XP/score/nível + evento de pendência)        STORY-087 (FE — telas de avaliação no shell)
    │ API viva                                                                       │ (dep 084 + 085)
    ├─► STORY-086 (BE — gate bloqueante)                                             └─► STORY-088 (FE — perfil + UX do gate)
    │                                                                                          │ (dep 087 + 085 + 086)
    └──────────────────────────────► 085..088 done ◄──────────────────────────────────────────┘
                                          ▼
                                   STORY-089 (validador — última)

STORY-082 (deflake cronômetro + housekeeping) — ORTOGONAL TOTAL, inicia a qualquer momento
```

**Por que esta ordem.** A decisão precede a implementação (lição W27/W28): ADR-019 fixa modelo/eventos/gate antes de qualquer código backend; DDR-004 + protótipo aprovado pelo humano antes de qualquer tela. Backend (085) destrava o gate (086) e alimenta o frontend (087/088). O perfil + UX do gate (088) depende das telas de captura (087) e da API (085/086). O validador (089) fecha. STORY-082 não toca nada do EPIC-004 — preenche janelas.

## Compromisso visível ao fim do sprint

**Em `app.homolog.turni.com.br` + API:**

- Após um turno `finalizado`, **profissional** vê a tela de avaliar o contratante (estrelas obrigatórias + comentário opcional) e **contratante** vê a de avaliar o profissional.
- **Profissional** tenta candidatar-se com avaliação pendente → **bloqueado** com mensagem clara + link para o turno pendente. **Contratante** idem ao publicar vaga.
- **XP/score/nível** atualizam após avaliação recebida; nível sobe automaticamente ao cruzar 500/1000/3000, visível no perfil em ≤1s.
- **Score público** (1 casa, ex. 4.9★) e **depoimentos** (até 3 mais recentes, conforme DDR-004) visíveis no perfil de profissional e contratante (reciprocidade).

**Decisões registradas:** ADR-019 (modelo de avaliação + eventos de domínio + ponto do gate), DDR-004 (visibilidade de depoimentos), `flows/avaliacao-reciproca.md`. IDR(s) eventuais de implementação.

**Dívida da W28/W29 quitada (ortogonal):** E2E de sincronia do cronômetro estável + índice reconciliado (IDR-028/IDR-029 indexados; SCREEN-STORY-077 `shipped`).

## Decisões de produto/arquitetura que entram em vigor agora

- **PDR-005** (avaliação recíproca obrigatória) — base do épico.
- **ADR-019** (a produzir na STORY-083), **DDR-004** (a produzir na STORY-084).
- **Vigentes respeitados**: ADR-015 (modelo Turno), ADR-017 (tempo real + geo), ADR-007 (RBAC), ADR-018 (UUID), DDR-001/002/003 (DS, pt-BR/24h, shell), IDR-010/011/021 (E2E).
- **Fora do MVP (do `epic.md`)**: decay de score/XP; motor de penalidade (PDR-007 — placeholder); moderação por UI; nível de contratante; push web.
- **Fora desta sprint (decisão do dono 2026-06-09)**: dívida de a11y do EPIC-012 (gate dedicado das telas pesadas + PIN/cronômetro + navegação por teclado). Permanece parqueada; candidata a estória própria em wave futura.

## Riscos identificados na abertura

| Risco | Probabilidade | Impacto | Mitigação | Owner |
|---|---|---|---|---|
| Spikes (083/084) viram gargalo de entrada — toda a implementação depende deles | alta | alto | São as primeiras e rodam em paralelo; PO prioriza a aprovação de ADR-019 e do protótipo no D1–D3; enquanto não fecham, 085+ ficam `blocked` — STORY-082 (ortogonal) preenche a janela | Arquiteto + Designer + PO |
| STORY-085 (L) estoura sessão única — modelo + migração + motor + eventos é bastante | média | médio | Gatilho de quebra documentado (modelo/evento vs motor XP/score/nível); ADR-019 entrega a decisão antes | Programador + PO |
| Idempotência do motor de XP — reprocesso de evento soma XP em dobro | média | alto | CA-5 de 085 exige idempotência por evento + testes de borda; núcleo ≥98% | Programador + Validador |
| Gate bloqueante regride candidatura/publicação (W26/W28) ou vaza entre papéis | baixa | alto | CA fail-secure + RBAC em 086; E2E cruzado herdado não pode regredir; PO verifica em homolog | Programador + Validador |
| Visibilidade de depoimentos (DDR-004) é decisão sensível (privacidade do autor) | média | médio | Decisão explícita do Designer com aprovação do humano; spec já sugere baseline (estabelecimento sim, autor individual não) | Designer + PO |
| STORY-082 (deflake) não estabiliza — flake estrutural de timing | média | médio | Permite re-especificar a medição (não só repetir o teste); se não estabilizar, PO renova como dívida explícita em vez de bloquear | Programador + PO |

## Acompanhamento contínuo (PO)

- **Diário (~10 min)**: olhar `index.json`; desbloquear sobretudo ADR-019 e o protótipo da STORY-084 (gargalos de entrada).
- **Mid-sprint check**: ADR-019 + DDR-004 fecharam? 085 destravou? Se 085 foi quebrada, avaliar sessão extra.
- **Antes da validação**: PO escreve `epics/EPIC-004-avaliacao-reciproca/validation/checklist.md` para a STORY-089.
- **Soft-cap check em 2026-07-14**: se goal não bateu, abrir "Mudanças no escopo" e decidir.

### Registro de acompanhamento

| Data | Check | Situação |
|---|---|---|
| 2026-06-09 | Abertura da sprint (PO) | W30 aberta logo após o fechamento da W29 (EPIC-012 done). EPIC-004 decomposto em 8 estórias (`draft`→`ready`); STORY-082 carry-forward. Próximo passo: agentes Arquiteto (STORY-083 → ADR-019) e Designer (STORY-084 → DDR-004 + protótipo) executam em paralelo; humano aprova ADR e protótipo antes da implementação. a11y do EPIC-012 fica fora por decisão do dono. |
| 2026-06-09 | STORY-083 done — ADR-019 accepted (Arquiteto) | Primeiro gargalo de entrada resolvido. ADR-019 aprovada pelo dono em chat: tabela `avaliacoes` separada (UNIQUE por direção/turno) divergindo do esboço jsonb de turno.md; pendência derivada do estado; eventos síncronos na transação (reuso de `TurnoFinalizado` p/ notificação + novo `AvaliacaoRegistrada` p/ motor); motor de reputação por recomputação idempotente + nível high-water-mark (`xp`→signed, contratante ganha `score`, enum `NivelProfissional` recomendado); gate no service layer fail-secure reusando as costuras `AvaliacoesPendentes*` (profissional já ligado; falta ligar `PublicarVagaService`). Spec `flows/avaliacao-reciproca.md` escrita. **Destrava STORY-085/086** (que ainda dependem do protótipo da STORY-084). Risco de idempotência (motor) mitigado por construção. Próximo gargalo: aprovação do protótipo da STORY-084. |

## Mudanças no escopo do sprint

> Toda alteração no conjunto de estórias após esta abertura registra aqui, com data e motivo.

| Data | O que mudou | Motivo | Custo |
|---|---|---|---|
| — | — | — | — |

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
