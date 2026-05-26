---
epic_id: EPIC-004
slug: avaliacao-reciproca
title: Avaliação recíproca e fechamento do ciclo
wave: WAVE-2026-01
status: draft
owner_role: po
created_at: 2026-05-26
updated_at: 2026-05-26
target_completion: 2026-08-25  # estimativa orientativa
---

# EPIC-004 — Avaliação recíproca e fechamento do ciclo

## Por que existimos (problema do usuário)

Sem avaliação, a trilha de níveis não anda, o score recíproco não acumula, e o algoritmo de match perde sua principal entrada de qualidade. Além disso, a avaliação obrigatória (PDR-005) é o mecanismo que **fecha o ciclo** — quem termina um turno é forçado a refletir antes de iniciar outro, e isso alimenta a confiança bilateral.

Este épico não é só "interface de avaliação"; é o **gatilho que faz o produto evoluir** com cada turno que passa.

## Resultado esperado (outcome)

Ao fim deste épico, após cada turno `finalizado`, ambos os lados são bloqueados em qualquer ação futura (nova candidatura ou nova publicação de vaga) até avaliarem o turno anterior com estrelas (obrigatórias) e comentário (opcional). O XP do profissional atualiza; a trilha de níveis (Iniciante → Confiável → Destaque → Elite) sobe quando atinge o limite. O score público fica atualizado no perfil.

## Métrica de sucesso (como saberemos que funcionou)

- **Primária**: 100% dos turnos finalizados em homologação geram avaliação recíproca em ≤ 7 dias (PO + equipe Turni operando como personas).
- **Gate funciona**: tentativa de nova ação sem avaliar pendente é bloqueada com mensagem clara.
- **XP e nível**: profissional que atinge limite de XP sobe de nível automaticamente; mudança visível no perfil em ≤ 1s.
- **Score recíproco**: contratante e profissional veem score atualizado no perfil público após avaliação.

## Entregável visível no fim do épico

- [ ] Após turno `finalizado`, profissional vê tela de avaliação do contratante (estrelas obrigatórias + comentário opcional).
- [ ] Contratante vê tela de avaliação do profissional (idem).
- [ ] Profissional tenta candidatar-se sem avaliar → bloqueado com mensagem + link para turno pendente.
- [ ] Contratante tenta publicar vaga sem avaliar → bloqueado com mensagem + link para turno pendente.
- [ ] XP do profissional atualiza após avaliação recebida (+30 turno + bônus por estrelas).
- [ ] Nível sobe quando XP cruza limite (500, 1000, 3000).
- [ ] Score público visível no perfil do profissional (4.9★ em 127 turnos) e do contratante (média das avaliações recebidas).
- [ ] Depoimentos comentados aparecem no perfil (até 3 mais recentes).

## Fora de escopo (explicitamente)

- Decay de score / XP ao longo do tempo — fora do MVP.
- Penalização automática por avaliação 1-2★ (placeholder no modelo, sem motor — PDR-007).
- Moderação de avaliações abusivas — tratado caso a caso pelo admin, sem UI.
- Visibilidade granular de qual autor escreveu cada depoimento — decisão de DDR durante este épico.
- Nível para contratante (Confiável/Destaque do lado contratante) — fora do MVP.
- Notificação push de "você foi avaliado" — apenas in-app + e-mail.

## Referências da especificação

- `docs/especificacao/domain/niveis-e-score.md` — XP, trilha, perks.
- `docs/especificacao/domain/turno.md` — avaliação dentro do ciclo.
- `docs/especificacao/flows/avaliacao-reciproca.md` — fluxo (a escrever).
- `docs/especificacao/business-rules.md` — XP por evento, limites de nível.
- `docs/project-state/decisions/pdr/PDR-005-avaliacao-reciproca-obrigatoria.md` — base do épico.
- `docs/project-state/decisions/pdr/PDR-007-cancelamento-permitido-com-penalidade-futura.md` — motor de penalidade fora do MVP.

## Dependências

- **Bloqueia**: nada nesta onda. Mas alimenta dados para evolução do algoritmo de match (próxima onda).
- **Bloqueado por**: EPIC-003 (sem turno `finalizado`, não há avaliação).
- **Decisões arquiteturais necessárias**:
  - Eventos de domínio (`turno_finalizado` → dispara fluxo de avaliação; `avaliacao_recebida` → atualiza XP).
  - Modelo de dados de avaliação (estrelas + comentário + timestamps + linkage com turno).
  - Onde aplicar gate bloqueante (middleware, decorator, service layer — decisão de Arquiteto).

## Estórias

> A decompor via Fluxo B quando o épico entrar em sprint.

## Validação final

Critérios em `validation/checklist.md`. Relatório do validador em `validation/report.md`.

**Definição de épico concluído**: ciclo completo turno → avaliação dupla → atualização de XP/nível/score funcionando em homologação; gate bloqueante ativo; relatório do validador `approved`.

## Histórico

- 2026-05-26 — criado por PO durante planejamento da WAVE-2026-01.
