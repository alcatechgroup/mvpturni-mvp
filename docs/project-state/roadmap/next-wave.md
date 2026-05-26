---
wave_id: WAVE-2026-02
title: Endurecimento operacional e usuários reais (rascunho)
status: planned
draft: true
prerequisite: "WAVE-2026-01 fechada com a hipótese central confirmada (≥ 1 turno completo/dia útil em homologação)."
---

# WAVE-2026-02 — Endurecimento operacional e usuários reais (rascunho)

> **Este é rascunho.** Não detalhe estórias agora. Só revisitar e fechar quando a WAVE-2026-01 estiver no fim e a hipótese central tiver sido validada (ou recalibrada).

## Direção provável

Assumindo que a WAVE-2026-01 confirma a hipótese central (ciclo completo ponta a ponta funciona em homologação), a próxima onda foca em:

1. **Operar com primeiros usuários reais externos** (sair de homologação para produção com 2-3 contratantes piloto do Grupo Noiz e 5-10 profissionais convidados).
2. **Endurecer arestas** do ciclo central (disputa completa, observabilidade séria, recuperação de falhas).
3. **Reduzir trabalho manual** da equipe Turni que vira gargalo de crescimento.

## Épicos esboçados (apenas título e outcome)

### EPIC-006 — Produção operacional

- **Outcome**: ambiente de produção provisionado e o caminho feliz do MVP roda em produção com Pagar.me real (não sandbox). Backup e disaster recovery testados.
- **Por que importa**: sem produção, a tese não é validada com usuários reais.

### EPIC-007 — Disputa completa

- **Outcome**: resoluções `paga_parcial` e `sem_pagamento` implementadas; captura parcial e estorno parcial Pagar.me em produção; UI rica de mediação no backoffice; comunicação automatizada do admin com as partes durante disputa.
- **Por que importa**: o MVP fecha o caminho de exceção apenas em versão mínima — quando o volume começar, os casos não cabem só em "paga integral".

### EPIC-008 — Observabilidade séria

- **Outcome**: logs estruturados, métricas RED, traces, dashboards operacionais consolidados; alertas funcionando para Pix com falha, geofencing fora do raio acima do esperado, disputas abertas, latência degradando.
- **Por que importa**: PDR-010 deixou tratamento de falha de Pix manual no MVP. Para escalar, precisamos enxergar problema antes do usuário reclamar.

### EPIC-009 — Backoffice estendido

- **Outcome**: backoffice ganha gestão completa de usuários (busca, edição, suspensão); intervenção excepcional em turnos; dashboards operacionais; relatórios fiscais.
- **Por que importa**: PDR-003 deixou backoffice mínimo viável no MVP. Equipe Turni cresceu? Volume cresceu? Esta é a hora.

### EPIC-010 — Motor de penalidade

- **Outcome**: motor de penalidade automática para cancelamentos e no-show implementado, calibrado com dados observados na WAVE-2026-01.
- **Por que importa**: PDR-007 deixou motor previsto mas não construído. Sem dado, calibragem era arbitrária — agora temos dado.

## Hipóteses prováveis a serem validadas

(Depende de aprendizado da WAVE-2026-01.)

- Contratantes reais conseguem operar sem hand-holding semanal da equipe Turni?
- Profissionais voltam para uma segunda candidatura sem precisar de re-engajamento manual?
- O modelo financeiro (taxa 15% do contratante) gera receita unitária defensável?

## O que ainda não está esboçado

- Notificações push web (PWA) — fica para esta onda ou a seguinte.
- API pública para Enterprise — provavelmente terceira onda.
- Multi-unidade para contratante — terceira onda.
- Antecipação de turnos / plano Turnificado / Cartão Turni — terceira onda ou depois.

## Quando este rascunho ganha detalhe

- Quando a WAVE-2026-01 fechar com retro completa.
- Quando a métrica de norte tiver baseline real (mesmo que pequena).
- Quando o time tiver decidido se mantém só Alexandro nos 5 papéis ou amplia.

Antes disso, este arquivo serve apenas como **bússola direcional**.
