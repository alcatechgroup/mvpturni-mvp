---
epic_id: EPIC-002
slug: vaga-feed-e-candidatura
title: Publicação de vaga, feed do profissional e candidatura
wave: WAVE-2026-01
status: draft
owner_role: po
created_at: 2026-05-26
updated_at: 2026-05-26
target_completion: 2026-07-28  # estimativa orientativa
---

# EPIC-002 — Vaga, feed e candidatura

## Por que existimos (problema do usuário)

Com usuários `ativo` no sistema (EPIC-001 concluído), o produto precisa permitir o **encontro**: contratante publica uma vaga aberta, profissional vê a vaga em seu feed ranqueada por score de match transparente, candidata-se com um toque. Contratante vê candidatos ranqueados e pode preparar-se para aceitar. Sem essa peça, há cadastro mas nada acontece — é a primeira validação do pilar **Match IA**.

## Resultado esperado (outcome)

Ao fim deste épico, contratante consegue publicar uma vaga em homologação; profissional vê essa vaga no feed com score de match (0-100) e breakdown explicável; profissional candidata-se em 1 toque; contratante vê os candidatos ranqueados por match. Edição de vaga após candidatura (PDR-009) funciona com notificação aos candidatos.

## Métrica de sucesso (como saberemos que funcionou)

- **Primária**: contratante publica vaga e recebe primeira candidatura em ≤ 2h em homologação (SLA público da landing).
- **Match transparente**: 100% das vagas no feed exibem score de match com breakdown clicável.
- **Performance**: feed do profissional responde em p95 ≤ 800ms com 1k vagas seedadas no banco.
- **Compliance**: gate de avaliação (PDR-005) funciona — profissional com turno por avaliar é bloqueado na candidatura.

## Entregável visível no fim do épico

- [ ] Contratante consegue publicar vaga em `app.homolog.turni.com.br` (formulário com função, data/hora, valor, posições, observações).
- [ ] Vaga aparece em `aberta` na lista de vagas do contratante.
- [ ] Profissional vê a vaga no feed (`/feed`) com score, função, valor, distância, ranking.
- [ ] Profissional clica para ver detalhe e breakdown completo do match.
- [ ] Profissional candidata-se; contratante recebe notificação (in-app + e-mail).
- [ ] Contratante abre a vaga e vê candidatos ranqueados por match.
- [ ] Filtros do feed funcionam: Todas, Minha função, Alto match (80%+), Candidatadas.
- [ ] Edição material da vaga notifica candidatos pendentes (PDR-009).

## Fora de escopo (explicitamente)

- Aceite da candidatura → vira EPIC-003.
- Pré-autorização Pagar.me → vira EPIC-003.
- Vagas recorrentes (publicar uma vez, repetir semanalmente).
- Vagas com múltiplas funções diferentes — força publicar separado.
- Boost via plano Turni Ads / Turnificado — fica para evolução pós-MVP.
- API para Enterprise.
- Bulk publishing (publicar 20 vagas de uma vez para catering grande).

## Referências da especificação

- `docs/especificacao/domain/vaga.md` — atributos, estados, edição.
- `docs/especificacao/domain/candidatura.md` — fluxo, estados, gates.
- `docs/especificacao/domain/match.md` — algoritmo, breakdown, visibilidade.
- `docs/especificacao/flows/publicar-vaga.md` — fluxo do contratante (a escrever).
- `docs/especificacao/flows/feed-e-candidatura.md` — fluxo do profissional (a escrever).
- `docs/especificacao/business-rules.md` — pesos do match (40/20/30/10).
- `docs/project-state/decisions/pdr/PDR-005-avaliacao-reciproca-obrigatoria.md` — gate de avaliação afeta candidatura.
- `docs/project-state/decisions/pdr/PDR-009-edicao-de-vaga-pos-candidatura.md` — edição com notificação.

## Dependências

- **Bloqueia**: EPIC-003 (sem candidatura aprovada, não há turno).
- **Bloqueado por**: EPIC-001 (sem usuários `ativo`).
- **Decisões arquiteturais necessárias**:
  - Modelo de dados de vaga + candidatura (com snapshot/versionamento para PDR-009).
  - Estratégia de cálculo de match em runtime (cache? job pré-computado? cálculo on-demand?).
  - Estratégia de notificação ao candidato (in-app + e-mail no MVP; push é evolução).

## Estórias

> A decompor via Fluxo B quando o épico entrar em sprint.

## Validação final

Critérios em `validation/checklist.md` (a criar). Relatório do validador em `validation/report.md`.

**Definição de épico concluído**: publicar vaga, ver no feed, candidatar-se, ver candidatos ranqueados, e edição com notificação funcionando ponta a ponta em homologação; gate PDR-005 ativo; relatório do validador `approved`.

## Histórico

- 2026-05-26 — criado por PO durante planejamento da WAVE-2026-01.
