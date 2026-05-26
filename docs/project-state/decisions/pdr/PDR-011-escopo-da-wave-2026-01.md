---
pdr_id: PDR-011
slug: escopo-da-wave-2026-01
title: Escopo da WAVE-2026-01 — ciclo completo do turno em homologação
status: accepted
decided_at: 2026-05-26
decided_by: PO (Alexandro / Claude)
supersedes: null
superseded_by: null
related_epics: [EPIC-000, EPIC-001, EPIC-002, EPIC-003, EPIC-004, EPIC-005]
related_adrs: []
---

# PDR-011 — Escopo da WAVE-2026-01

## Contexto

Concluída a fundação de produto (visão, personas, north-star, 10 PDRs aceitos, especificação inicial e skills alinhadas), o projeto entra na primeira onda de execução. A pergunta crítica é: **qual hipótese esta primeira onda valida, e quais épicos são necessários e suficientes para essa validação**.

A landing do Turni promete três pilares operacionais — **Match IA + PIN Bilateral + Pix em 15 min**. A WAVE-2026-01 precisa demonstrar que esses três pilares funcionam juntos no caminho feliz, em ambiente de homologação, com Pagar.me em sandbox. Sem essa demonstração, o produto é só protótipo navegável; com ela, está pronto para começar a operar com piloto externo na onda seguinte.

## Opções consideradas

### Opção 1 — Ciclo completo ponta a ponta
- Descrição: 6 épicos cobrindo Foundation, Cadastro, Vaga/Candidatura, Aceite/PIN/Pix, Avaliação, Disputa mínima. Onda densa, ~9-10 sprints semanais (≈ 2,5 meses).
- Prós: Valida hipótese central completa em uma onda; produto fica demonstrável de ponta a ponta; risco maior fica concentrado e visível.
- Contras: Onda longa para padrão "3-7 épicos curtos"; alguma estória pode estourar e empurrar o cronograma; depende de Pagar.me sandbox estar disponível na janela do EPIC-003.

### Opção 2 — Encontro mínimo (sem turno executado)
- Descrição: 3-4 épicos cobrindo Foundation, Cadastro, Vaga/Candidatura. PIN, turno, Pix ficam para a segunda onda.
- Prós: Onda curta, baixo risco; entrega rápido para revisão da hipótese; permite pivot mais cedo se algo não estiver casando com a visão.
- Contras: Não valida os pilares "PIN Bilateral" nem "Pix 15 min"; a tese central fica não-demonstrada por mais ~2 meses; risco de descobrir tarde que o pilar de pagamento tem problema arquitetural sério.

### Opção 3 — Foco no lado profissional primeiro
- Descrição: Cadastro de profissional + feed + candidatura, com vagas seedadas pelo admin. Lado contratante em ferramenta provisória do backoffice.
- Prós: Onda curta; valida atratividade do lado oferta; expõe rapidamente problemas de match.
- Contras: Quebra a tese de marketplace de dois lados; postergaria a demonstração do ciclo completo; cria UI provisória que vira débito.

## Decisão

> **Optamos pela Opção 1 — ciclo completo ponta a ponta.**

A WAVE-2026-01 é composta por 6 épicos sequenciais (EPIC-000 a EPIC-005) e tem como meta operacional **pelo menos 1 turno executado ponta a ponta em homologação por dia útil ao final da onda**, com check-in PIN validado, check-out PIN validado, Pix sandbox confirmado e avaliação recíproca registrada por ambos os lados.

A hipótese central a validar é: *"Os três pilares (Match IA + PIN Bilateral + Pix em 15 min) funcionam ponta a ponta no caminho feliz, em homologação."*

Decisão associada sobre composição do **EPIC-000 Foundation**: **só spike Arquiteto + hello world**. O spike jurídico/contábil **não** entra no Foundation — vira a primeira estória do EPIC-001 (cadastro), com execução em paralelo ao setup técnico restante de EPIC-000.

Sequência dos épicos detalhada em `docs/project-state/roadmap/current-wave.md`.

## Justificativa

Validar os 3 pilares juntos é o que diferencia o Turni de qualquer marketplace genérico — sem PIN bilateral e Pix em 15 min, o produto é "publicar vaga em app". A Opção 2 (encontro mínimo) deixa essa validação para a segunda onda, criando risco de descobrir tarde que algum pilar tem problema estrutural. A Opção 3 quebra a tese de marketplace de dois lados.

A escolha de manter o spike jurídico no EPIC-001 (em vez de EPIC-000) reflete uma decisão pragmática: o setup técnico do Foundation pode rodar em paralelo enquanto Alexandro contrata advogado/contador; misturar trabalhos com naturezas diferentes (calendário externo vs sprint técnico) no mesmo épico atrapalha a leitura de progresso.

A onda excede ligeiramente a diretriz "3-7 épicos curtos" (ficou em 6 épicos, alguns L/XL), mas é exceção legítima descrita em `agile-workflow.md`: "Primeira onda pode ter menos pelo viés de fundação", **e** alguns épicos de Foundation/Cadastro são naturalmente densos. Não vamos artificialmente quebrar em 10 épicos só para caber na régua.

## Consequências

### Positivas
- Hipótese central validada em uma onda — risco do produto fica visível.
- Pagar.me entra cedo (EPIC-003), com tempo para tratar variabilidade do provedor.
- Templates de contrato eletrônico ficam definidos durante o EPIC-001, antes do primeiro turno real — proteção jurídica desde o início.
- Backoffice nasce mínimo desde EPIC-001 (fila de aprovação), evoluindo gradualmente para incluir disputa em EPIC-005.

### Negativas / trade-offs aceitos
- Onda longa (~2,5 meses) com risco maior de retrabalho acumulado.
- Estimativa de prazo orientativa — não-compromisso — pode irritar se houver compromisso comercial externo.
- Designer e Arquiteto compartilhando Alexandro cria gargalo cognitivo.
- Disputa mínima (EPIC-005) deixa débito para a próxima onda — UI provisória pode incomodar.

### Para o time técnico
- ADRs prováveis durante a onda: stack (linguagem + framework), hospedagem, monorepo vs polirepo, autenticação, integração Pagar.me, estratégia de habitualidade (cache vs view vs query), modelo de notificação, geo (PostGIS vs Haversine), formato de aceite eletrônico.
- Impacto em épicos: detalhe em `current-wave.md`.

## Sinais de revisão

- **Se EPIC-000 ou EPIC-001 atrasar mais de 50% do estimado**: pausa para retro, possível replanejamento da onda (talvez cortar EPIC-005 para a próxima).
- **Se sandbox Pagar.me se mostrar instável** na janela do EPIC-003: avaliar usar mock dedicado em vez de sandbox no MVP, com sandbox apenas em smoke E2E noturno.
- **Se métricas de cobertura cair abaixo do mínimo** (PDR não-negociável): pausa para correção antes de seguir para próximo épico.
- **Se a hipótese central for confirmada antes do EPIC-005**: avaliar acelerar transição para WAVE-2026-02 com piloto externo, ainda completando EPIC-005 em paralelo.
