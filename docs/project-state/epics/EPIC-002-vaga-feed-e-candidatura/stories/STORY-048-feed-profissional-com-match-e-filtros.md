---
story_id: STORY-048
slug: feed-profissional-com-match-e-filtros
title: Feed do profissional — listagem ranqueada por match com filtros e visibilidade (p95 ≤ 800ms)
epic_id: EPIC-002
sprint_id: SPRINT-2026-W27
type: implementation
target_role: programador
requires_design: true
design_screen_id: SCREEN-STORY-048-feed-profissional
status: ready
owner_agent: null
created_at: 2026-06-01
updated_at: 2026-06-01
estimated_session_size: L  # candidata a quebrar se estourar — performance + UI + telemetria
produces_idr: null
---

# STORY-048 — Feed do profissional com match e filtros

> **Para o agente:** estória **L** — única deste sprint marcada como Large. É o coração do "Match IA" prometido. Se sentir que estoura sessão única, escale ao PO antes de inflar. Critério natural de quebra: separar a query+ranqueamento (backend) da UI (frontend) em duas estórias. Leia o spike STORY-045 (algoritmo + eventos) e STORY-044 (modelo) por inteiro antes.

## Contexto

Profissional aprovado precisa ver vagas que se encaixam — ordenadas por score de match, com filtros úteis e visibilidade já filtrada (estado `aberta`, função primária/secundária, dentro do raio, data futura). É o primeiro lugar onde **Match IA** vira experiência real para o profissional. Sem feed, o cadastro do EPIC-001 entrega usuário sem nada para fazer.

- Épico: `epics/EPIC-002-vaga-feed-e-candidatura/epic.md`
- Documentos: `domain/vaga.md` (Visibilidade + Filtros), `domain/match.md` (Visibilidade para o profissional + Eventos), `business-rules.md` (Match), ADR-013 (modelo), ADR-014 (algoritmo), SCREEN-STORY-048.

## O quê

Implementar `GET /api/feed` (backend Laravel) e a tela `/feed` (WebApp Flutter) entregando: lista paginada de vagas visíveis ao profissional autenticado, ordenadas por `score` decrescente (com boost de plano como ordem secundária — STORY-045 CA-5), com 4 filtros (Todas, Minha função, Alto match 80%+, Candidatadas). Cada card mostra função, data/hora, valor, distância, score numérico (0-100) e barra visual. Performance: p95 ≤ 800ms com 1k vagas seedadas.

## Por quê

Métrica de qualidade da onda: "feed do profissional responde em p95 ≤ 800ms com 1k vagas seedadas" (`current-wave.md`). Métrica primária do épico: "100% das vagas no feed exibem score de match com breakdown clicável".

## Critérios de aceite

- [ ] **CA-1:** Endpoint `GET /api/feed?filtro=todas|minha_funcao|alto_match|candidatadas&page=N` autenticado como `profissional` retorna `{ vagas: [...], page, has_next }`. Cada vaga inclui: `id`, `funcao`, `data_inicio`, `data_fim`, `valor`, `distancia_km` (calculada), `score: { total, componentes: { funcao, distancia, historico, nivel } }`, `ja_candidatou: bool`.
- [ ] **CA-2:** Visibilidade conforme `domain/vaga.md`: só vagas `aberta`, com função primária OU secundária do profissional, dentro do raio máximo do profissional, com `data_inicio > now()`. Vagas fora desses critérios **não** aparecem em "Todas".
- [ ] **CA-3:** Ordenação default: `score DESC, boost_plano DESC, data_inicio ASC`. Cap em 100 herdado da função do STORY-045.
- [ ] **CA-4:** Filtro "Minha função" restringe a função primária; "Alto match" restringe a `score >= 80`; "Candidatadas" mostra apenas vagas em que o profissional tem candidatura `pendente` ou `pendente_revisao_apos_edicao` (vagas `fechada`/`cancelada` saem do feed mas continuam acessíveis em uma seção "Histórico" — se sair de orçamento, "Histórico" vira estória própria na próxima sprint).
- [ ] **CA-5:** Tela `/feed` no WebApp lista os cards na ordem do endpoint, mostra score numérico + barra (DDR-001), permite clique no card para abrir o detalhe (STORY-049). Filtros como chips no topo, sem reload de página (re-fetch).
- [ ] **CA-6:** Performance: teste de carga no CI (script `tests/Performance/FeedLatencyTest.php`) com 1k vagas seedadas (reaproveita `VagasStressSeeder` da STORY-044) e 1 profissional seed mede p95 ≤ 800ms para 50 chamadas seguidas. Falha o CI se p95 > 1200ms (folga 1.5×, mas log captura para análise).
- [ ] **CA-7:** Telemetria (STORY-045 helper): a cada request bem-sucedido, dispara `feed.vaga_apresentada` por vaga retornada (com score e componentes) e `feed.vaga_filtrada` por vaga descartada na visibilidade (com `motivo_filtro`: `funcao_fora`, `distancia_fora`, `data_passou`, `gate_avaliacao`, `conflito_horario`). Volume alto é esperado em homolog; log JSON estruturado (ADR-008) absorve.
- [ ] **CA-8:** Gate PDR-005 cruza com o feed: profissional com turno por avaliar **vê** o feed (para não criar tela em branco), mas o botão de "candidatar" no card e no detalhe (STORY-050) fica desabilitado com tooltip "Avalie seu último turno para se candidatar". Endpoint do feed em si **não** bloqueia (apenas marca `pode_candidatar: bool` em cada vaga).
- [ ] **CA-9:** Cold start (profissional sem histórico): score componente "Histórico" = 0 (per `domain/match.md`). Card ainda renderiza, ordenação ainda funciona.
- [ ] **CA-10:** Paginação cursor-based ou page-based — decisão técnica do agente; sugestão: cursor (mais estável quando lista muda durante scroll). Page size = 20.
- [ ] **CA-11:** Cobertura: backend (controller + query builder + visibilidade) ≥ 95%; frontend (widgets do feed) ≥ 80%. E2E em `integration_test`: profissional seed loga, vê feed com pelo menos 3 vagas ranqueadas, troca filtro para "Alto match" e a lista atualiza.

## Fora de escopo

- Detalhe da vaga (breakdown expandido) → STORY-049.
- Candidatar-se → STORY-050.
- Seção "Histórico" (vagas fechadas/canceladas) — se sair de orçamento, vai para wishlist/próxima sprint.
- Push notifications / WebSocket de atualização em tempo real.
- A/B testing de algoritmo, decay contínuo de distância, afinidade histórica (todos referenciados em "Lacunas conhecidas" de `domain/match.md`).

## Padrões de qualidade

- ≥ 95% controller/query.
- ≥ 80% widgets.
- E2E verde.
- Performance test verde.
- RBAC: contratante na rota → 403.

## Dependências

- **Bloqueada por:** STORY-044 (modelo), STORY-045 (algoritmo + eventos).
- **Bloqueia:** STORY-049 (detalhe), STORY-050 (candidatura — botão sai daqui).
- **Pré-req:** profissional seed `ativo` com função primária, vagas seedadas (incluindo stress seed).

## Decisões já tomadas

- ADR-013 (modelo), ADR-014 (algoritmo + eventos), ADR-007 (Sanctum SPA), DDR-001.
- `domain/match.md`: boost vs. score (boost ordena, não soma).
- PDR-005: gate bloqueia ação, não visibilidade.

## Liberdade técnica

Decide: estratégia de paginação (cursor recomendado), nome dos endpoints internos, estrutura do widget. NÃO decide: lista de filtros (fixada acima), payload dos eventos (vem de STORY-045 ADR-014).

## DoD

- [ ] CAs checados.
- [ ] Cobertura + perf test + E2E verdes.
- [ ] Deploy de homolog mostra feed funcional com seed.
- [ ] `index.json` atualizado.
- [ ] "Notas do agente" preenchida com p95 medido em homolog também (não só CI).

## Notas do agente

### Decisões tomadas
- 
### Descobertas
- 
### Bloqueios
- 
### IDRs
- 
### Cobertura final
- Unitários: 
- E2E: 
- Performance p95 (CI / homolog): 
### Links
- PR: 
- Pipeline: 
- Deploy: 
