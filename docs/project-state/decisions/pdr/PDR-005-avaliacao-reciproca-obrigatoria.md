---
pdr_id: PDR-005
slug: avaliacao-reciproca-obrigatoria
title: Avaliação recíproca é obrigatória e bloqueante para nova candidatura
status: accepted
decided_at: 2026-05-26
decided_by: PO (Alexandro / Claude)
supersedes: null
superseded_by: null
related_epics: []
related_adrs: []
---

# PDR-005 — Avaliação recíproca obrigatória e bloqueante

## Contexto

A trilha de níveis e o algoritmo de match dependem do score histórico — score só existe se os turnos terminarem com avaliação. Avaliação opcional, na prática, vira avaliação esquecida: o profissional sai do turno, o contratante já está fechando o caixa, e ninguém volta para deixar nota. Sem nota, sem trilha. Sem trilha, sem motor do produto.

## Decisão

> **Avaliação recíproca é obrigatória. Profissional só consegue se candidatar a nova vaga após avaliar o último turno finalizado pendente. Contratante só consegue publicar nova vaga após avaliar turnos finalizados pendentes.**

O protótipo já implementa o gate do lado do profissional. Espelhamos a regra para o contratante.

## Justificativa

A obrigatoriedade força o ciclo de feedback que alimenta a métrica de norte (turno completo = avaliado). Bloquear ações subsequentes é mais efetivo que recompensar — recompensar requer que o usuário enxergue a recompensa antes de agir; bloquear cria o gatilho na hora certa.

## Consequências

### Positivas
- Score recíproco sempre alimentado.
- Trilha de níveis confiável.
- Sinal de saúde de cada lado limpo desde o início.

### Negativas / trade-offs aceitos
- Fricção real para o usuário ocasional ("queria só publicar uma vaga rápido"); aceita-se em troca da integridade do sistema.
- Avaliações forçadas podem ter qualidade menor que voluntárias — mitigado por permitir nota sem comentário obrigatório (estrelas + opcional texto).

## Sinais de revisão

- Se mais de 30% das avaliações forem genéricas/sem comentário (sinal de avaliação só para destravar), reavaliar UX da avaliação (perguntas mais específicas, microcopy).
- Se houver evasão de usuário consistente (abandono após turno por causa do gate), reabrir.
