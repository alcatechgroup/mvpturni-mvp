---
wave_id: WAVE-2026-01
title: Ciclo completo do turno em homologação
status: active
start_date: 2026-05-26
target_completion: 2026-08-31  # estimativa orientativa, não compromisso rígido
hipotese_central: "Os três pilares da promessa de valor — Match IA + PIN Bilateral + Pix em 15 min — funcionam ponta a ponta no caminho feliz, em homologação, com Pagar.me em sandbox e usuários reais (PO + equipe Turni operando como personas)."
metrica_alvo_da_onda: "Pelo menos 1 turno executado ponta a ponta em homologação por dia útil ao final da onda, com check-in PIN validado, check-out PIN validado, Pix sandbox confirmado e avaliação recíproca registrada."
---

# WAVE-2026-01 — Ciclo completo do turno em homologação

## Objetivo de negócio

A primeira onda valida que o produto **funciona como prometido na landing**: o contratante consegue publicar uma vaga, recebe candidato qualificado por match transparente, aceita, o profissional executa o turno com PIN bilateral, e o pagamento sai via Pix em até 15 minutos no ambiente de homologação (sandbox Pagar.me). Sem isso, a tese central do Turni — *"Match IA + PIN Bilateral + Pix em 15 minutos"* — não está demonstrada.

Não estamos validando volume, retenção, conversão de marketing nem economia unitária. Estamos validando que **o caminho feliz existe e é defensável**. Casos de borda graves (disputa) entram no MVP em versão mínima; casos avançados (motor de penalidade, antecipação de turnos, planos Enterprise) ficam para ondas seguintes.

## Hipótese central

> Os 3 pilares (Match IA + PIN Bilateral + Pix 15 min) funcionam ponta a ponta no caminho feliz, em homologação, com Pagar.me em sandbox.

Se a hipótese se confirmar, abrimos a segunda onda focada em endurecer arestas (disputa completa, motor de penalidade, observabilidade séria) e começar a operar com usuários reais externos. Se não se confirmar, identificamos qual pilar quebra e replanejamos.

## Métrica-alvo da onda

> **Pelo menos 1 turno executado ponta a ponta em homologação por dia útil ao final da onda**, com check-in PIN validado, check-out PIN validado, Pix sandbox confirmado e avaliação recíproca registrada por ambos os lados.

Esta é uma meta operacional — não comercial. Demonstra que o sistema sustenta o fluxo central de forma repetível.

Métricas de qualidade secundárias:

- Latência p95 do feed do profissional ≤ 800ms com 1k vagas seedadas.
- Validação de PIN executa em ≤ 500ms p95 (operação em pé, contexto de rua).
- Pix sandbox cai em ≤ 15 min em 95% dos turnos completados.
- Cobertura unitária ≥ 80% no projeto, ≥ 98% no núcleo de regras de negócio (PDR-005, PDR-002, PDR-008, cálculo de match, cálculo de pagamento).
- E2E cobrindo todo fluxo de usuário do MVP.

## Sequência de épicos (com justificativa de ordem)

```
EPIC-000 ─► EPIC-001 ─► EPIC-002 ─► EPIC-003 ─► EPIC-004 ─► EPIC-005
Foundation  Cadastro    Vaga e      Aceite,     Avaliação   Disputa
            e aprovação candidatura PIN, Pix    recíproca   mínima
```

### EPIC-000 — Foundation

- **Outcome**: stack escolhida em ADRs vigentes; pipelines automáticos em verde; "hello world" deployado em ambas as URLs públicas.
- **Entregável**: `app.homolog.turni.com.br` e `admin.homolog.turni.com.br` respondendo com página inicial e health-check.
- **Por que vem primeiro**: sem fundação, nenhum épico de funcionalidade tem onde rodar. PDR-003 exige duas interfaces desde o início.
- **Composição (decidido com Alexandro)**: spike Arquiteto + hello world. Spike jurídico/contábil **não** entra aqui — vira a primeira estória do EPIC-001.

### EPIC-001 — Cadastro e aprovação

- **Outcome**: profissional (PF, MEI ou PJ) e contratante completam o funil cadastro → aprovação manual da equipe Turni → welcome → completar cadastro → estado `ativo`.
- **Entregável**: usuário leigo consegue se cadastrar pelo webapp; admin vê na fila do backoffice; aprova; usuário completa cadastro e fica `ativo`.
- **Por que vem segundo**: sem usuários `ativo`, nada do resto acontece. Backoffice mínimo nasce aqui (fila de aprovação — PDR-003).
- **Primeira estória obrigatória**: **spike jurídico/contábil** (templates de contrato eletrônico PF autônomo eventual + B2B PJ↔PJ, validação da regra de 2x/semana de PDR-002 com advogado trabalhista, mapa tributário do contratante ao contratar PF). Sem essa estória, o cadastro segue com contrato genérico que cria dívida.

### EPIC-002 — Vaga, feed e candidatura

- **Outcome**: contratante publica vaga; profissional vê no feed com match score e breakdown transparente; profissional candidata-se; contratante vê candidatos ranqueados por score.
- **Entregável**: contratante consegue publicar uma vaga em homologação e ver candidato real ranqueado.
- **Por que vem terceiro**: sem oferta e demanda, não há aceite. Algoritmo de match (4 componentes, cap 100, breakdown explicável) entra aqui.

### EPIC-003 — Aceite, PIN bilateral e Pix

- **Outcome**: contratante aceita candidatura (pré-autorização Pagar.me + turno em `confirmado`); profissional faz check-in com PIN bilateral + geofencing alerta-e-registra; cronômetro bilateral roda; profissional faz check-out com PIN; contratante valida; captura Pagar.me; Pix sai em sandbox.
- **Entregável**: ciclo do turno completo executável ponta a ponta em homologação.
- **Por que vem quarto**: é o coração da promessa. Sem isso, o produto não existe.
- **Dependência crítica**: ADR de integração Pagar.me deve estar aceita no EPIC-000 ou produzida via spike no início deste épico. Estratégia de habitualidade (PDR-002) também precisa estar implementada antes do aceite — alternativa: estória própria de habitualidade dentro deste épico.

### EPIC-004 — Avaliação recíproca e fechamento do ciclo

- **Outcome**: após turno `finalizado`, ambos os lados avaliam; gate bloqueante (PDR-005) impede nova candidatura/publicação sem avaliar; XP atualiza; trilha de níveis sobe quando atinge limite.
- **Entregável**: o ciclo se fecha — profissional avalia, contratante avalia, próxima ação é destravada, score recíproco visível no perfil público.
- **Por que vem quinto**: alimenta a métrica de norte (turno completo = avaliado) e fecha o ciclo. Sem isso, o produto funciona mas a trilha não anda.

### EPIC-005 — Disputa mínima via backoffice

- **Outcome**: contratante consegue recusar check-out com justificativa textual; turno transita para `em_disputa`; admin vê na fila do backoffice; resolve com **"pagar integral"** (única resolução do MVP — captura parcial e sem_pagamento ficam para a próxima onda).
- **Entregável**: caminho de exceção do check-out tratado em homologação sem estado fantasma.
- **Por que vem por último**: PDR-006 (disputa) e PDR-003 (backoffice mínimo) exigem **alguma** versão da disputa para a primeira onda fechar. Versão mínima evita estado inconsistente quando contratante recusa, sem expandir escopo.
- **O que fica para a próxima onda**: resoluções `paga_parcial` e `sem_pagamento`; UI elaborada de mediação no backoffice; comunicação automatizada entre as partes durante disputa.

## Estimativa de tamanho (orientativa)

| Épico | Tamanho | Sprints típicos |
|---|---|---|
| EPIC-000 | M (curto) | 1 sprint |
| EPIC-001 | L | 2 sprints |
| EPIC-002 | L | 2 sprints |
| EPIC-003 | XL | 2-3 sprints |
| EPIC-004 | M | 1 sprint |
| EPIC-005 | M | 1 sprint |

Total: ~9-10 sprints semanais (≈ 2,5 meses), com folga para spike inicial e retrabalho típico de Foundation. Estimativa orientativa — não compromisso de prazo.

## Restrições herdadas que afetam esta onda

- **TDD + E2E** obrigatórios desde a primeira estória do EPIC-000 (não "vamos colocar depois").
- **Cobertura**: ≥ 80% geral, ≥ 98% em núcleo (PDR-005 gate, PDR-002 habitualidade, PDR-008 geofencing, cálculo de match, cálculo de pagamento).
- **Entrega em produção desde o dia 1**: homologação no dia 1 (entregável do EPIC-000), produção no fim do EPIC-001 ou EPIC-002.
- **Estado registrado, sempre**: cada decisão arquitetural durante a onda vira ADR; cada decisão de implementação relevante vira IDR; cada decisão de design durável vira DDR.
- **Designer entra em paralelo** com Programador desde a primeira estória de UI (EPIC-001).

## Riscos abertos nesta onda

1. **Integração Pagar.me em sandbox** — variabilidade do provedor pode atrasar EPIC-003. Mitigação: spike de Arquiteto deve cobrir Pagar.me antes do início do EPIC-001 (não esperar EPIC-003).
2. **Templates de contrato eletrônico** — dependência externa (advogado + contador). Mitigação: spike é primeira estória do EPIC-001, executável em paralelo com setup técnico restante de EPIC-000.
3. **Performance da consulta de habitualidade** (PDR-002) — pode virar gargalo. Mitigação: ADR específico no spike do EPIC-000 ou estória própria no início do EPIC-003.
4. **Designer e Arquiteto compartilhando a mesma pessoa (Alexandro)** — risco de gargalo cognitivo. Mitigação: separação clara por sessão; ADR e DDR registrados explicitamente para preservar disciplina de papéis.

## Fora de escopo desta onda (vai para WAVE-2026-02 ou depois)

- Backoffice completo (gestão de usuários, intervenção em turnos, dashboards, métricas operacionais avançadas).
- Resoluções avançadas de disputa (parcial, sem_pagamento, mediação rica).
- Motor de penalidade automática (PDR-007).
- Notificações push web (PWA) — apenas in-app e e-mail no MVP.
- API pública para Enterprise.
- Multi-unidade para contratante.
- Validação automática contra Receita.
- Antecipação de turnos (plano Turnificado).
- Cartão Turni e ecossistema FHP avançado.

## Próximo passo imediato

Abrir o **EPIC-000 — Foundation** com a primeira estória de spike do Arquiteto. Designer também pode iniciar a fundação do Design System (DDR-001) em paralelo, já que a primeira estória de UI virá no EPIC-001.
