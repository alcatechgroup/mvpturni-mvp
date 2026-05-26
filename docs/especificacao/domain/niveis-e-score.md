# Domínio · Níveis e Score

## Score

Score é a média de avaliações (1-5 estrelas) recebidas pelo profissional ao longo de todos os turnos `finalizado` e `finalizado_ajustado`. Calculado como média ponderada com **leve viés para avaliações recentes** (avaliações dos últimos 30 dias pesam ligeiramente mais; detalhe exato fica para spike).

Visibilidade:

- Profissional vê seu score atual e histórico no perfil.
- Contratante vê o score do candidato na vaga (e o número de turnos completados).
- O score público é exibido com 1 casa decimal (ex.: 4.9★).

## XP (Experience Points)

XP é a moeda de progressão do profissional. Acumula com:

| Evento | XP |
|---|---|
| Turno finalizado | 30 base |
| Tarefa do checklist concluída | 1-5 por tarefa (varia por função) |
| Avaliação 5★ recebida | +10 |
| Avaliação 4★ recebida | +3 |
| Avaliação 3★ recebida | 0 |
| Avaliação 1-2★ recebida | -5 (penalidade) |
| Turno cancelado pelo profissional | -10 (placeholder; ajustar quando motor de penalidade for definido) |
| No-show do profissional | -30 (placeholder) |

Os valores exatos serão ajustados durante a operação. O importante no MVP é que **o motor exista** e o XP seja calculado a cada evento.

## Trilha de níveis

| Nível | Pontos | Perks |
|---|---|---|
| **Iniciante** | 0 – 499 | Acesso a vagas básicas; score público visível. |
| **Confiável** | 500 – 999 | Plantões premium; prioridade no match; badge verificado. |
| **Destaque** | 1.000 – 2.999 | Eventos exclusivos; taxa reduzida (futuro); acesso antecipado. |
| **Elite** | 3.000+ | Operações premium do FHP; renda recorrente prioritária; pode atuar como mentor (futuro). |

A subida de nível é automática quando o XP cruza o limite.

A descida não acontece automaticamente no MVP — XP pode ficar negativo localmente sem rebaixar o profissional. Política de rebaixamento depende do motor de penalidade futuro (PDR-007).

## Avaliação recíproca

Atributo do turno, capturado nas duas direções:

- **Contratante avalia profissional**: estrelas (1-5) obrigatórias + comentário opcional.
- **Profissional avalia contratante**: estrelas (1-5) obrigatórias + comentário opcional.

A avaliação é **obrigatória** para destravar próximas ações (PDR-005):

- Profissional não pode candidatar-se enquanto tiver avaliação pendente.
- Contratante não pode publicar nova vaga enquanto tiver avaliação pendente.

Comentários comentados (com `comment` não-vazio) aparecem como **depoimentos** no perfil público de quem foi avaliado, ordenados do mais recente para o mais antigo.

## Visibilidade

### Profissional vê

- Próprio nível, XP atual, XP até o próximo nível.
- Histórico de avaliações recebidas (estrelas + comentário) — anônimo? Nominal? Decidir em DDR de Design (sugestão: nome do estabelecimento visível, autor individual da avaliação não).
- Próprio score.

### Contratante vê

- Score do candidato.
- Nível do candidato (badge no card).
- Quantidade de turnos completados pelo candidato.
- Depoimentos públicos do candidato (até 3 mais recentes na visão expandida).

### Cruzado (mutuamente)

- O perfil público do contratante (acessível pelo profissional) também tem score (média das avaliações que ele recebeu), nível conceitual (futuro — hoje sem nível), e depoimentos de profissionais que trabalharam ali. Isso reforça a reciprocidade.

## Lacunas conhecidas

- Ajuste fino dos valores de XP (são iniciais; precisam observação real para calibrar).
- Decay de score / XP ao longo do tempo (profissional que não opera por 6 meses perde nível?) — fora do MVP.
- Nível para contratante (Confiável, Destaque, etc. do lado contratante) — fora do MVP; hoje só score.
- Visibilidade individual vs. agregada dos depoimentos — decisão de DDR do Designer.
- Política de moderação de avaliações abusivas — fora do MVP, tratado caso a caso pelo admin.
