# Regras de negócio — números e parâmetros

Concentração dos números que mudam por decisão de produto e precisam ser localizáveis. Sempre que um número aqui mudar, deve haver PDR correspondente.

## Modelo financeiro (PDR-004)

| Parâmetro | Valor MVP |
|---|---|
| **Taxa Turni** | **15%** sobre `valor` do turno, cobrada do contratante |
| **Profissional recebe** | `valor` integral (sem desconto) |
| **Contratante paga** | `valor + taxa_turni` |
| **PSP único** | Pagar.me |
| **Forma de pagamento ao profissional** | Pix |
| **SLA de Pix** | ≤ 15 min após captura do check-out validado (promessa pública) |

## Habitualidade (PDR-002)

| Parâmetro | Valor MVP |
|---|---|
| **Limite semanal** | 2 alocações por semana corrida (segunda a domingo) no mesmo estabelecimento |
| **Comportamento PF na 3ª** | Bloqueio duro |
| **Comportamento MEI/PJ na 3ª** | Alerta + override do contratante |
| **Zona vermelha (heurística)** | 3+ semanas consecutivas com 2 alocações no mesmo estabelecimento |

## Match (algoritmo MVP)

| Componente | Peso máximo |
|---|---|
| Função primária | 40 |
| Distância no raio | 20 |
| Histórico de score | 30 (linear entre 4.0★→0 e 5.0★→30) |
| Nível na trilha | 10 (Iniciante 0, Confiável 3, Destaque 6, Elite 10) |
| **Cap total** | 100 |

## Trilha de níveis

| Nível | Pontos (XP) |
|---|---|
| Iniciante | 0 – 499 |
| Confiável | 500 – 999 |
| Destaque | 1.000 – 2.999 |
| Elite | 3.000+ |

## XP (Experience Points)

| Evento | XP |
|---|---|
| Turno finalizado | +30 |
| Tarefa do checklist concluída | +1 a +5 (varia por função) |
| Avaliação 5★ recebida | +10 |
| Avaliação 4★ recebida | +3 |
| Avaliação 3★ recebida | 0 |
| Avaliação 1-2★ recebida | -5 |
| Cancelamento pelo profissional | -10 (placeholder) |
| No-show do profissional | -30 (placeholder) |

## Geofencing (PDR-008)

| Parâmetro | Valor MVP |
|---|---|
| **Raio de tolerância** | 100m no check-in |
| **Comportamento fora do raio** | Alerta + registro, sem bloqueio |

## Disputa (PDR-006)

| Parâmetro | Valor MVP |
|---|---|
| **SLA público de resolução** | 30 minutos |
| **Quem abre** | Apenas contratante, no momento da recusa do check-out |
| **Justificativa** | Texto obrigatório |
| **Resoluções possíveis** | `paga_integral`, `paga_parcial`, `sem_pagamento` |

## Cadastro e aprovação

| Parâmetro | Valor MVP |
|---|---|
| **SLA público de análise** | 24 horas |
| **Validação automática Receita** | Não no MVP (PDR-001) |
| **Funil obrigatório pós-aprovação** | welcome → completar cadastro → uso normal |

## Planos do contratante

| Plano | Preço | Capacidades-chave |
|---|---|---|
| **Member Start** | Grátis | Publicação ilimitada, match básico, checklist Core FHP padrão |
| **Member Turni** | R$ 399/mês/unidade | + Checklist personalizado, prioridade no match, analytics por unidade |
| **Enterprise** | R$ 799/mês | + Multi-unidade, SLA match < 1h, API, dashboard executivo |

> Enterprise e Member Turni com preços listados aqui são **referência da landing**; o detalhe contratual real será firmado no épico de monetização, fora do MVP inicial.

## Planos do profissional

| Plano | Preço | Capacidades-chave |
|---|---|---|
| **Profissional Turni** | Grátis | Cadastro completo, match por score + proximidade, Pix em 15 min |
| **Turni Ads** | R$ 49/mês | Boost de visibilidade no ranking, badge Ads |
| **Turnificado** | R$ 149/mês | Antecipação de turnos, prioridade premium, dashboard de carreira |

## Avaliação recíproca (PDR-005)

| Parâmetro | Valor MVP |
|---|---|
| **Obrigatória** | Sim, ambos os lados |
| **Bloqueante** | Sim, impede candidatura nova / publicação de vaga nova |
| **Componentes** | Estrelas (1-5) obrigatórias; comentário opcional |

## Cancelamento (PDR-007)

| Parâmetro | Valor MVP |
|---|---|
| **Permitido** | Sim, antes do estado `ativo` |
| **Penalidade automática** | Não no MVP; placeholder de XP negativo registrado |
| **Pré-autorização Pagar.me** | Liberada no cancelamento |

## Pix com falha (PDR-010)

| Parâmetro | Valor MVP |
|---|---|
| **Retry automático** | Não no MVP |
| **Tratamento** | Alerta no backoffice; resolução manual |

## Observações sobre alteração destes números

Todo número aqui é resultado de uma decisão de produto registrada em PDR. Mudar um número sem mudar o PDR correspondente quebra a regra de "estado registrado, sempre". Quando precisar mudar:

1. Abra PDR de revisão (status `proposed`).
2. Discuta com Alexandro.
3. Marque PDR anterior como `superseded`; novo como `accepted`.
4. Atualize este arquivo na mesma operação.
5. Atualize o `index.json`.
