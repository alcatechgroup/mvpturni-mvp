# Domínio · Candidatura

Decisão de referência: **PDR-005** (avaliação bloqueante), **PDR-009** (edição de vaga).

## O que é

Candidatura é a manifestação de interesse de um profissional por uma vaga aberta. Não é compromisso bilateral — o contratante ainda decide aceitar ou não. Quando aceita, vira **Turno** em estado `confirmado` (ver `domain/turno.md`).

## Pré-condições para candidatar-se

O profissional só pode candidatar-se se:

1. Está `ativo` (passou pelo funil de aprovação).
2. Não tem turno finalizado pendente de avaliação (gate PDR-005).
3. A vaga está `aberta`.
4. Não está candidatado a outra vaga com **conflito de horário** (sobreposição de `data_inicio` e `data_fim`).
5. A regra de habitualidade permite (ver `domain/compliance.md`): para PF, bloqueio na 3ª alocação semanal no mesmo estabelecimento; para PJ/MEI, alerta + override do contratante.

## Estados

| Estado | Significa |
|---|---|
| `pendente` | Profissional enviou; contratante ainda não decidiu. |
| `aprovada` | Contratante aceitou. Vira Turno em estado `confirmado`. |
| `retirada` | Profissional retirou voluntariamente. |
| `pendente_revisao_apos_edicao` | Vaga foi editada materialmente; profissional precisa confirmar manutenção (24h ou início do turno). |
| `retirada_por_edicao` | Profissional não confirmou após edição material ou pediu retirada explícita. |
| `recusada` | Contratante recusou explicitamente (futuro — ver lacunas). |

## Fluxo padrão

```
[ profissional encontra vaga no feed ]
         │
         ▼
  [ envia candidatura ] ──► estado: pendente
         │
         ▼
  [ contratante vê candidatura no painel da vaga ]
         │
   ┌─────┴──────┐
   │            │
   ▼            ▼
[ aprova ]   [ ignora ou recusa ]
   │            │
   ▼            ▼
[ vira Turno ] [ vaga fica aberta para outros, candidatura permanece pendente até vaga fechar ]
```

No MVP, o contratante **não precisa recusar explicitamente**. Quando a vaga é preenchida (todas as posições aprovadas) ou cancelada, candidaturas pendentes são automaticamente encerradas (não há campo `recusada` no MVP; a candidatura simplesmente perde efeito).

## Retirada voluntária

Profissional pode retirar a candidatura enquanto `pendente`. Após aprovação (já virou Turno), o caminho é **cancelar o turno** (ver `domain/turno.md`).

## Conflito de horário

O sistema impede o profissional de candidatar-se a uma vaga que tem sobreposição de horário com:

- Outra candidatura pendente do mesmo profissional.
- Um turno já confirmado/ativo do mesmo profissional.

Mensagem clara é apresentada com o conflito identificado.

## Aprovação pelo contratante

- Contratante vê todos os candidatos no painel da vaga, com **score de match** (0-100) e breakdown (ver `domain/match.md`).
- Aprova quem quiser, na ordem que quiser, até a vaga fechar.
- Aprovar dispara: criação do Turno em `confirmado` + pré-autorização Pagar.me do valor + Taxa Turni (PDR-004) + notificação ao profissional + decremento de posição na vaga.

Se a vaga tem múltiplas posições, o contratante pode aprovar múltiplos candidatos sequencialmente até preencher.

## Edição material da vaga (PDR-009)

Quando o contratante edita material em uma vaga com candidaturas pendentes:

1. Todas as candidaturas `pendente` transitam para `pendente_revisao_apos_edicao`.
2. Cada profissional recebe notificação com diff.
3. Profissional confirma manutenção (volta a `pendente`) ou retira (vai para `retirada_por_edicao`).
4. Sem ação em 24h ou até início do turno → automaticamente `retirada_por_edicao`.

## Lacunas conhecidas

- Estado `recusada` explícita pelo contratante (com motivo opcional) — futuro.
- Limite de candidaturas pendentes simultâneas por profissional — futuro, conforme observação de padrão.
- Mensagem do profissional ao se candidatar (texto livre explicando motivo) — futuro.
