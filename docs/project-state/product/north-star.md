# Métrica de norte — Turni

## Métrica de norte

> **Turnos finalizados com check-out validado por PIN bilateral e avaliação recíproca concluída, por mês.**

Notação curta: **Turnos Completos / mês**.

## Por que esta métrica

A métrica de norte tem que capturar **o evento mínimo onde os dois lados extraem valor real**. No Turni, esse evento é o **turno completo**: o profissional foi até o local, executou, recebeu seu Pix; o contratante teve sua escala coberta, pagou, avaliou. Tudo abaixo disso — vaga publicada, candidatura enviada, match feito — é meio. Tudo acima — segundo turno, terceiro, repetição mensal — vem em cima.

A escolha exclui de propósito:

- **Turnos finalizados sem PIN bilateral validado**, porque sinaliza brecha de processo (presença não comprovada, fricção entre as partes).
- **Turnos sem avaliação recíproca**, porque sem o ciclo de feedback a trilha de níveis não funciona e a confiança não se acumula.
- **Vagas publicadas** ou **candidaturas enviadas**, porque são leading indicators (importantes, mas não evento de valor).

## Árvore de métricas de apoio (2-3 que alimentam o norte)

### M1. Match Fill Rate (taxa de preenchimento de vagas)

> **% de vagas publicadas que foram preenchidas no SLA prometido (2h Member, 1h Enterprise).**

Mede a saúde do lado **contratante**: a plataforma cumpre a promessa de match rápido? Se cai, o produto está perdendo a razão de existir. Meta inicial MVP: ≥ 70% das vagas preenchidas no SLA.

### M2. Profissional Activation Rate (ativação de profissional)

> **% de profissionais que completam o primeiro turno até 14 dias após aprovação do cadastro.**

Mede a saúde do lado **profissional**: o profissional aprovado consegue chegar até a primeira renda? Se cai, ou o feed não está mostrando o que ele precisa, ou o cadastro está atrapalhando, ou os filtros não casam com a oferta. Meta inicial MVP: ≥ 50% ativados em 14 dias.

### M3. Dispute Rate (taxa de disputa)

> **% de turnos finalizados que entraram em estado de disputa (contestação no check-out).**

Mede a saúde da **confiança bilateral**: o PIN, o checklist e o cronômetro estão dando às partes razões suficientes para concluírem sem mediação. Se sobe, a infraestrutura de confiança está falhando. Meta inicial MVP: ≤ 3% de disputas sobre turnos finalizados.

## Como usar

- **Status report semanal**: cada relatório carrega o número atual da métrica de norte e o delta vs. semana anterior.
- **Fim de épico**: cada épico declara qual métrica de apoio espera mover, em quanto, em quanto tempo. O validador checa contra a realidade observada.
- **Fim de onda**: retrospectiva grande comparando hipótese de abertura da onda vs. observação real nas três métricas.

## O que não é métrica de norte

- **GMV (volume financeiro transacionado)**: importante para o negócio, mas no MVP sai como consequência do volume de turnos, não como driver.
- **Número de cadastros aprovados**: vaidade. Cadastro que não vira turno é peso, não valor.
- **NPS**: relevante para retenção, mas tarde demais como sinal operacional no MVP (precisa de massa).

## Quando reavaliar

- Quando a métrica de norte estabilizar em volume mensal consistente (provavelmente após 6 meses pós-lançamento), faz sentido evoluir para métricas que capturem **retenção** (turnos por profissional ativo por mês, repetição contratante↔profissional, churn de contratante).
- Antes disso, reabrir só se houver sinal forte de que ela está medindo a coisa errada (ex: número sobe mas churn de contratante sobe junto).
