# Domínio · Match

## O que é

Match é o pareamento ranqueado entre profissional e vaga, calculado pelo algoritmo do Turni. Gera um **score de 0 a 100** e um **breakdown explicável**, visível tanto para o profissional (no feed e na vaga) quanto para o contratante (no painel da vaga).

Princípio central: **o cálculo é aberto**. O profissional sabe exatamente por que está em alta ou baixa posição.

## Algoritmo (MVP)

O score é a soma simples de 4 componentes, com cap em 100:

| Componente | Peso máx | Como pontua |
|---|---|---|
| **Função** | 40 | 40 se a função primária bate; 25 se uma função secundária bate; 0 se não bate. |
| **Distância** | 20 | 20 se o estabelecimento está dentro do raio máximo do profissional; 0 caso contrário. Granularidade refinada (decay por distância) fica como evolução. |
| **Histórico de score** | 30 | Linear entre 0 e 30: profissional com `score = 4.0` ganha 0; com `score = 5.0` ganha 30. Profissional sem histórico (0 turnos) ganha 0 nesta dimensão (será reavaliado quando o feed segmentar Iniciante separadamente). |
| **Nível** | 10 | Iniciante 0, Confiável 3, Destaque 6, Elite 10. |

Total cap: 100.

### Bônus de plano (Turni Ads / Turnificado)

Profissionais nos planos pagos do profissional ganham **boost de visibilidade no ranking**, não no score em si. Mecânica:

- **Turni Ads** (R$ 49/mês): aparece antes de profissionais com o mesmo score sem plano. Não muda o score.
- **Turnificado** (R$ 149/mês): mesmo boost + acesso a vagas exclusivas (operações premium do FHP, eventos específicos).

A separação "score vs. boost" é proposital: score reflete fit objetivo; boost reflete escolha comercial. Cabe ao Designer definir como exibir isso para o profissional sem confundir.

### Bônus do plano do contratante

- Contratantes Member e Enterprise têm prioridade no SLA de match (Member-Start: 2h; Enterprise: <1h). Isso afeta **frequência de notificação push** aos profissionais com fit alto, não o cálculo do score.

## Breakdown explicável

Toda vez que um match é apresentado (no feed para o profissional, no painel da vaga para o contratante), o sistema também apresenta o detalhe item a item:

```
Função              ━━━━━━━━━━ 40/40   ✓ Sua função primária bate · Garçom
Distância           ━━━━━━━━━━ 20/20   ✓ Estabelecimento em São Paulo · dentro do raio de 8km
Histórico de score  ━━━━━━━━░░ 27/30   ✓ Sua média 4.9★ em 127 turnos
Nível na trilha     ━━━━━━━━━━ 10/10   ✓ Elite · topo da trilha
                                 ─────
                                 97/100
```

Cada item tem ícone, descrição em prosa curta e estado visual (ok/partial/miss). Detalhe de UI cabe ao Designer.

## Visibilidade

### Para o profissional

- Score visível em **cada card de vaga** no feed.
- Filtro "Alto match (80%+)" disponível.
- Tela de vaga detalha o breakdown ao expandir.

### Para o contratante

- Cada candidato no painel da vaga tem **score de match** visível.
- Ordenação padrão por score decrescente.
- Breakdown disponível ao clicar no candidato.

### Para o admin

- Pode ver match score de todas as combinações ativas; útil para diagnóstico ("por que Diego não está aparecendo em vagas próximas?").

## Eventos disparados

O sistema dispara eventos relacionados ao match (para analytics futura e para o motor de notificação):

- `feed:vaga_apresentada` — vaga apareceu para o profissional com determinado score.
- `feed:vaga_filtrada` — vaga ficou fora pelo filtro (função fora, distância fora, conflito de horário, gate de avaliação).
- `match:candidatura_enviada` — profissional aplicou; match score do momento é registrado.
- `match:candidatura_aprovada` — contratante aceitou; match score do momento é registrado.

Esses eventos alimentam métricas e refinamento futuro do algoritmo.

## Lacunas conhecidas

- Distância como decay (não binária) — evolução.
- Componente de afinidade histórica (profissional já trabalhou bem neste estabelecimento; contratante já contratou bem este profissional) — evolução.
- Penalização por padrões ruins (cancelamento recente, no-show recente) — depende do motor de penalidade (PDR-007).
- Cold start para profissional Iniciante (0 turnos) — hoje recebe 0 no componente de histórico; futuro pode considerar nível Iniciante como bônus pequeno até consolidar histórico.
- A/B testing do algoritmo — fora do MVP.
