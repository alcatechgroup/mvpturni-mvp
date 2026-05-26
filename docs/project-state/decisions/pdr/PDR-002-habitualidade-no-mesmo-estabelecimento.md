---
pdr_id: PDR-002
slug: habitualidade-no-mesmo-estabelecimento
title: Habitualidade limitada a 2 alocações por semana no mesmo estabelecimento, com regra distinta para PF e PJ
status: accepted
decided_at: 2026-05-26
decided_by: PO (Alexandro / Claude)
supersedes: null
superseded_by: null
related_epics: []
related_adrs: []
---

# PDR-002 — Habitualidade limitada a 2 alocações por semana no mesmo estabelecimento

## Contexto

O risco central da operação do Turni é caracterização de vínculo trabalhista por habitualidade — quando o mesmo profissional opera com frequência alta no mesmo estabelecimento, a Justiça do Trabalho pode reconhecer relação de emprego, mesmo com contrato B2B PJ↔PJ ou de autônomo eventual. A jurisprudência trata o tema com pesos diferentes para PF (mais sensível, vínculo se caracteriza com frequência menor) e PJ (mais protegida pelo contrato comercial). O protótipo já demonstrou a ideia de "zona verde/amarela/vermelha", mas sem regra numérica explícita.

Com PDR-001 abrindo PF como tipo aceito, a regra de habitualidade precisa ser duplamente clara: limite numérico fixo e tratamento distinto por tipo de pessoa.

## Opções consideradas

### Opção 1 — Limite único de 2 alocações/semana, mesma regra para PF e PJ
- Descrição: Bloqueia a 3ª alocação na semana, independente do tipo de pessoa.
- Prós: Simplicidade conceitual; uma só regra para auditar.
- Contras: Trata PF e PJ como iguais quando a jurisprudência os trata diferente; pode ser conservador demais para PJ (perde volume) e potencialmente arriscado para PF se a 2ª alocação semanal já sinalizar habitualidade.

### Opção 2 — Limite de 2 alocações/semana com tratamento distinto: alerta + override para PJ, bloqueio duro para PF
- Descrição: Ao tentar a 3ª alocação na semana no mesmo estabelecimento:
  - **PJ (MEI ou PJ pura)**: plataforma alerta visualmente ambos os lados; contratante pode liberar com **aceite explícito de risco** registrado no aceite eletrônico do turno.
  - **PF**: plataforma bloqueia a alocação. Sem override possível. Profissional precisa atuar em outro estabelecimento naquela semana ou aguardar a próxima.
- Prós: Reflete a diferença real de risco entre os dois tipos; preserva volume para PJ; protege PF (e contratante de PF) ativamente; força conversa difícil ("paga mais de 2x na mesma semana = sinal claro de tentativa de vínculo CLT").
- Contras: Duas regras para manter; UX precisa ser cuidadosa para o contratante entender por que com Carlos pode liberar e com Diego não.

### Opção 3 — Não bloquear, apenas alertar
- Descrição: Plataforma só registra e alerta, não interfere.
- Prós: Volume máximo; UX mais leve.
- Contras: Expõe Turni, contratante e profissional ao risco real; não cumpre a promessa de "governança documentada" da landing.

## Decisão

> **Optamos pela Opção 2.**

A regra é: máximo de **2 alocações por semana** no mesmo estabelecimento para o mesmo profissional. Ao tentar a 3ª:

- Se o profissional é **PJ (MEI ou PJ pura)**: alerta visível para ambos; contratante pode liberar com aceite explícito de risco no contrato do turno.
- Se o profissional é **PF**: bloqueio duro, sem override.

A "semana" é definida como **semana corrida iniciando na segunda-feira** (07 dias móveis a partir de cada alocação não traz boa visibilidade ao contratante). Detalhes operacionais (timezone, fuso, lógica de virada de semana) ficam para o spike técnico do compliance.

## Justificativa

A regra de 2x/semana é defensável juridicamente porque caracteriza claramente uso pontual/eventual — não recorrente. O tratamento distinto reflete a realidade da jurisprudência sem inventar pesos novos: PJ tem proteção contratual; PF não tem, e a plataforma precisa proteger ativamente. O override para PJ obriga o contratante a registrar a justificativa, criando trilha de auditoria — se vier processo, o documento existe.

## Consequências

### Positivas
- Reduz risco trabalhista material; cumpre a promessa de governança documentada.
- Protege ativamente o profissional PF iniciante.
- Cria trilha de auditoria com aceite explícito quando PJ excede o padrão.

### Negativas / trade-offs aceitos
- Volume bloqueado para PF iniciante que poderia trabalhar mais no mesmo lugar (aceitamos esse custo para proteger a relação).
- UX de bloqueio + override + alerta exige design cuidadoso (cabe ao Designer no épico de compliance).
- O contratante pode estranhar a regra inicialmente (precisa de copy claro explicando o porquê).
- Implementação exige consulta de histórico de alocações por par (profissional × estabelecimento) por semana — não trivial em performance se a base crescer.

### Para o time técnico
- ADRs prováveis: estratégia de consulta de histórico de alocações por semana (caching? materialized view? on-demand?); modelo de aceite eletrônico variável por tipo de pessoa.
- Impacto em épicos: EPIC de compliance é dependência forte do EPIC de candidatura/aceite; spike pode ser necessário no Foundation para definir como a consulta vai performar.

## Sinais de revisão

- Se a taxa de tentativas de override por PJ ultrapassar 20% das alocações (sinal de que a regra está virando ritual e não controle), reavaliar limite ou semântica.
- Se vier processo trabalhista contra contratante ou Turni com base em padrão observado pela plataforma, reabrir.
- Se assessoria jurídica especializada recomendar regra diferente após análise da operação real (spike jurídico), atualizar e registrar PDR de superseção.
