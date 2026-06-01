---
story_id: STORY-049
slug: detalhe-vaga-breakdown-match
title: Detalhe da vaga no WebApp + breakdown explicável do match
epic_id: EPIC-002
sprint_id: SPRINT-2026-W27
type: implementation
target_role: programador
requires_design: true
design_screen_id: SCREEN-STORY-049-detalhe-vaga
status: ready
owner_agent: null
created_at: 2026-06-01
updated_at: 2026-06-01
estimated_session_size: M
produces_idr: null
---

# STORY-049 — Detalhe da vaga + breakdown do match

> **Para o agente:** materializa o princípio "cálculo do match é aberto" — o profissional sabe exatamente por que está em 97/100 ou em 45/100. Sem esta tela, o feed da STORY-048 é uma caixa preta. Designer entrega o layout do breakdown (4 linhas, ícone, barra, descrição em prosa).

## Contexto

O feed (STORY-048) mostra score numérico em cada card. Quando o profissional toca, abre o detalhe — tudo da vaga + breakdown item a item. É a peça que torna o Match defensável: "Sua função primária bate · Garçom", "Estabelecimento em São Paulo · dentro do raio de 8km", "Sua média 4.9★ em 127 turnos", "Elite · topo da trilha".

- Épico: `epics/EPIC-002-vaga-feed-e-candidatura/epic.md`
- Documentos: `domain/match.md` (seções Breakdown explicável + Visibilidade), `domain/vaga.md` (Atributos), STORY-045 (shape do payload `MatchBreakdown`), SCREEN-STORY-049.

## O quê

Tela `/feed/vaga/{id}` no WebApp Flutter exibindo: cabeçalho da vaga (função, estabelecimento, data/hora, valor, distância), bloco "Por que estou vendo esta vaga" com os 4 componentes do match (ícone, barra, descrição), CTA "Candidatar-se" (chama STORY-050) ou "Você já se candidatou" (estado).

## Por quê

Transparência do algoritmo (princípio central de `domain/match.md`). Sem o breakdown, o profissional não confia no ranqueamento e tampouco aprende como subir de posição.

## Critérios de aceite

- [ ] **CA-1:** `GET /api/vagas/{id}/detalhe` autenticado retorna shape unificado: dados da vaga + `score_breakdown` no formato de STORY-045 (`{ total, componentes, breakdown: { funcao: {pontos, pontos_max, estado, descricao}, ... } }`) + `pode_candidatar: bool` + `ja_candidatou: bool` + `motivo_bloqueio: string|null`.
- [ ] **CA-2:** Tela renderiza cabeçalho com 5 campos (função, estabelecimento curto, data/hora formatada PT-BR, valor R$, distância km) e o bloco "Por que estou vendo esta vaga" com 4 linhas de breakdown (uma por componente). Cada linha: ícone (`ok` ✓ / `partial` ◐ / `miss` ✕), barra preenchida proporcional, label, valor `X/Y`, descrição em prosa curta.
- [ ] **CA-3:** Estado da linha de breakdown: `ok` quando `pontos == pontos_max`; `partial` quando `0 < pontos < pontos_max`; `miss` quando `pontos == 0`. Cores conforme DDR-001.
- [ ] **CA-4:** Total geral `XX/100` exibido em destaque com a barra agregada.
- [ ] **CA-5:** CTA "Candidatar-se": habilitado quando `pode_candidatar == true` e `ja_candidatou == false`; texto + estado seguem `motivo_bloqueio` se aplicável ("Avalie seu último turno", "Você já tem turno neste horário", "Habitualidade — 2 alocações desta semana neste local"). Clique chama o endpoint da STORY-050 (até STORY-050 estar done, o botão pode ser placeholder log + toast "em construção").
- [ ] **CA-6:** Quando `ja_candidatou == true`, CTA vira badge "Você já se candidatou" com data/hora; opção "Retirar candidatura" se candidatura `pendente` (chama endpoint STORY-050).
- [ ] **CA-7:** RBAC: contratante na rota recebe 403; profissional não-`ativo` recebe 403 ou redireciona para tela de completar cadastro.
- [ ] **CA-8:** Acessibilidade: barras de progresso têm `Semantics` de leitor de tela ("Função: 40 de 40 pontos · Sua função primária bate"); ícones têm `label` semântico.
- [ ] **CA-9:** Cobertura backend (controller + serializer) ≥ 95%; widget Flutter do breakdown ≥ 90%. Testes cobrem: vaga existente / inexistente / RBAC errado / cada estado de breakdown (ok/partial/miss em cada componente).
- [ ] **CA-10:** E2E em `integration_test`: profissional seed loga → abre feed → toca em uma vaga → vê breakdown completo com os 4 componentes corretos. 0 flake em 3 runs.

## Fora de escopo

- Implementação da candidatura → STORY-050.
- Histórico de score por candidatura → vive em STORY-050 (registra `score_no_momento`).
- Compartilhar vaga / favoritar / abrir em mapa.

## Padrões de qualidade

≥ 95% backend, ≥ 90% widget, E2E verde, acessibilidade testada.

## Dependências

- **Bloqueada por:** STORY-044, STORY-045, STORY-048 (rota chega daqui).
- **Bloqueia:** STORY-050 (botão "Candidatar-se" mora aqui), STORY-051 (mesmo padrão de breakdown reusado no lado do contratante).
- **Pré-req:** mesmo seed do feed.

## Decisões já tomadas

- ADR-014: shape do `MatchBreakdown`.
- DDR-001: tokens visuais.
- `domain/match.md`: princípio "cálculo é aberto" + estados ok/partial/miss.

## Liberdade técnica

Decide: widget reutilizável (`BreakdownRow`) que serve aqui e em STORY-051; animação da barra. NÃO decide: ordem dos componentes (segue a tabela de `domain/match.md`), estados de cor (DDR-001).

## DoD

- [ ] CAs checados.
- [ ] Cobertura + E2E verdes.
- [ ] Deploy de homolog renderiza para profissional seed.
- [ ] `index.json` atualizado.
- [ ] "Notas do agente" preenchida.

## Notas do agente

### Decisões / Descobertas / Bloqueios / IDRs
- 
### Cobertura final
- Unitários: 
- E2E: 
### Links
- PR / Pipeline / Deploy
