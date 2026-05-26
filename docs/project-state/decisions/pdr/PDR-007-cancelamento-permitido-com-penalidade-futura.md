---
pdr_id: PDR-007
slug: cancelamento-permitido-com-penalidade-futura
title: Cancelamento de turno é permitido no MVP; motor de penalidade fica previsto como evolução
status: accepted
decided_at: 2026-05-26
decided_by: PO (Alexandro / Claude)
supersedes: null
superseded_by: null
related_epics: []
related_adrs: []
---

# PDR-007 — Cancelamento permitido com motor de penalidade futuro

## Contexto

O protótipo permite cancelamento de turno por ambos os lados com mensagem genérica ("pode impactar seu score"), sem regra concreta. Para o MVP, queremos permitir cancelamento (a alternativa — bloquear — é pior, força no-show), mas precisamos do espaço arquitetural para uma política real chegar depois sem retrabalho grande.

## Decisão

> **Cancelamento é permitido por ambos os lados no MVP. O modelo de dados e a UI já carregam os campos necessários para um motor de penalidade futuro (motivo, timestamp, lado que cancelou, antecedência em relação ao início do turno), mas a aplicação automática de penalidade não é entregue no MVP.**

No MVP, cancelar:

- **Profissional** cancela turno confirmado → vaga volta a `aberta`, candidatura é removida. Sem penalidade automática. Registro fica para análise futura.
- **Contratante** cancela turno confirmado → profissional é notificado, pré-autorização Pagar.me é liberada. Sem penalidade automática.
- Não é possível cancelar turno em estado `ativo` (já com check-in validado) — só caminho é check-out ou disputa.

## Justificativa

Bloquear cancelamento força no-show, que é pior que cancelamento (no-show prejudica o outro lado sem aviso). Aplicar penalidade automática no MVP é arbitrário sem dados — vamos primeiro coletar padrão observado para depois calibrar regra. Reservar o espaço arquitetural impede que a evolução exija refazer modelo.

## Consequências

### Positivas
- UX clara desde o início (cancelar é uma opção, não um pecado).
- Motor de penalidade pode chegar como evolução incremental, com base em padrão real.
- Trilha de auditoria pronta para análise.

### Negativas / trade-offs aceitos
- No MVP, um profissional pode cancelar muitas vezes sem consequência visível — confiamos que a comunidade pequena e o impacto reputacional (avaliações futuras) compensem inicialmente.
- Risco de abuso enquanto não há penalidade — mitigado por observação ativa pela equipe Turni nos primeiros meses.

### Para o time técnico
- ADRs prováveis: modelo de dados de cancelamento com campos extensíveis (motivo, antecedência, lado, contexto).
- Impacto em épicos: EPIC de turno precisa contemplar o fluxo de cancelamento; spike para o motor de penalidade pode ser proposto na segunda ou terceira onda.

## Sinais de revisão

- Se taxa de cancelamento por turnos confirmados > 15%, antecipar motor de penalidade.
- Se padrão de cancelamento concentrado em poucos usuários (abuso identificado), aplicar penalidade caso a caso via admin antes do motor estar pronto.
- Se motor de penalidade for priorizado, abrir novo PDR detalhando regras (escala de penalidade, prazo, recurso).
