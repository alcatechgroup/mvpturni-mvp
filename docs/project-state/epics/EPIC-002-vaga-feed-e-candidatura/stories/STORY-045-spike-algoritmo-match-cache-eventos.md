---
story_id: STORY-045
slug: spike-algoritmo-match-cache-eventos
title: Spike Arquiteto — algoritmo de Match (40/20/30/10), estratégia de cálculo/cache e eventos de telemetria
epic_id: EPIC-002
sprint_id: SPRINT-2026-W27
type: spike
target_role: arquiteto
requires_design: false
design_screen_id: null
status: ready
owner_agent: null
created_at: 2026-06-01
updated_at: 2026-06-01
estimated_session_size: M
produces_idr: null  # produz ADR-014
---

# STORY-045 — Spike Arquiteto: algoritmo de Match + cache + eventos

> **Para o agente:** o cálculo do score é simples (4 componentes, cap 100); o difícil é decidir **onde** ele roda (on-demand × pré-computado) sem estourar o p95 de 800ms do feed com 1k vagas. Leia `domain/match.md` e `business-rules.md` por completo. Entregável é **ADR + função pura testada** — sem UI, sem endpoint público.

## Contexto

PDR e domínio já fixam o algoritmo: Função 40 + Distância 20 + Histórico 30 + Nível 10, cap 100. O que falta decidir é (a) estratégia de cálculo (on-demand a cada `GET /feed` × pré-computado em job × híbrido); (b) onde mora o breakdown (computado a cada request × persistido em cache com TTL); (c) eventos de telemetria que `domain/match.md` lista (`feed:vaga_apresentada`, `feed:vaga_filtrada`, `match:candidatura_enviada`, `match:candidatura_aprovada`). Decisão errada aqui se manifesta como feed lento ou como inconsistência entre score visto pelo profissional e score visto pelo contratante.

- Épico: `epics/EPIC-002-vaga-feed-e-candidatura/epic.md`
- Documentos canônicos a ler ANTES de codificar:
  - `docs/especificacao/domain/match.md` (inteiro)
  - `docs/especificacao/business-rules.md` (seção Match)
  - `docs/especificacao/domain/vaga.md` (seção Visibilidade)
  - `docs/project-state/decisions/adr/ADR-008-observabilidade-minima.md` (eventos vão por log estruturado)

## O quê

Produzir **ADR-014** que fixa: estratégia de cálculo do score, política de cache (se houver), shape canônico do payload `MatchBreakdown`, lista exata de eventos com payload e nome. Materializar a **função pura `calcular_match(profissional, vaga): MatchScore`** em PHP (módulo `app/Domain/Match/`) com testes unitários cobrindo 100% dos cenários da tabela (função primária bate / secundária bate / não bate; dentro/fora do raio; histórico nos 3 patamares; cada nível da trilha).

## Por quê

O algoritmo é o **pilar Match IA** prometido na landing. Score errado quebra a tese central. Performance ruim mata o feed. Falta de eventos mata a refinabilidade do algoritmo na onda 2.

## Critérios de aceite

- [ ] **CA-1:** ADR-014 fixa a estratégia: para o MVP, score é calculado **on-demand** no momento da consulta (feed do profissional + painel do contratante); breakdown é serializado no mesmo response (não há tabela de cache). Justificar com base em volume (1k vagas, ~100 profissionais ativos em homolog).
- [ ] **CA-2:** Função pura `calcular_match(profissional, vaga): MatchScore` em PHP — entrada são entidades de domínio, saída é um value object com `total: int`, `componentes: { funcao: int, distancia: int, historico: int, nivel: int }`, `breakdown: { funcao: BreakdownItem, ... }` onde cada item tem `pontos`, `pontos_max`, `estado: 'ok'|'partial'|'miss'`, `descricao: string`.
- [ ] **CA-3:** Testes unitários cobrem 100% dos ramos da tabela `business-rules.md` Match. Pelo menos: função primária bate, secundária bate, nenhuma bate; dentro do raio, fora do raio; histórico 4.0★/4.5★/5.0★/sem histórico; nível Iniciante/Confiável/Destaque/Elite; cap em 100 (testar combinação que somaria 110). Cobertura do módulo `Match` ≥ 98% (núcleo de regras de negócio per `quality-standards.md`).
- [ ] **CA-4:** Função é **determinística e pura** — sem leitura de banco, sem clock. Entradas explícitas; clock e raio são parâmetros do profissional (já em entidade).
- [ ] **CA-5:** Boost de plano (Turni Ads / Turnificado) **não** afeta `total` — afeta **ordenação** no feed (ordem secundária após score). ADR registra: boost é aplicado na camada de query, não no cálculo do score. Stub em modelo Profissional pode retornar `null` (planos ainda não modelados) — feed trata `null` como "sem boost".
- [ ] **CA-6:** Eventos de telemetria implementados como log JSON estruturado (ADR-008) — não há tabela própria no MVP. Nomes exatos: `feed.vaga_apresentada`, `feed.vaga_filtrada`, `match.candidatura_enviada`, `match.candidatura_aprovada`. Payload mínimo cada um, fixado na ADR. Helper `app/Support/Telemetry/MatchEvents.php` expõe os 4 métodos.
- [ ] **CA-7:** Benchmark micro: `calcular_match` executando para 1k vagas em loop entrega ≤ 200ms no CI (não é o tempo do feed inteiro, mas garante que a função em si não vira gargalo). Teste de performance em `tests/Performance/MatchBenchmarkTest.php` marcado para rodar no CI (não no pré-commit). Falha o CI se > 500ms — folga 2.5×.
- [ ] **CA-8:** ADR-014 lista o que **não** entra agora: distância como decay contínuo, afinidade histórica, penalização por padrões ruins (PDR-007), cold start para Iniciante — todos referenciados como "Lacunas conhecidas" de `domain/match.md`, fora do MVP.
- [ ] **CA-9:** ADR-014 termina `accepted` após revisão do PO. Antes disso, fica `proposed`.

## Fora de escopo

- Query SQL do feed → STORY-048.
- UI do breakdown → STORY-049 (Designer + Programador).
- Aplicação dos eventos a métricas reais no Cloud Monitoring → fica como log-based metric definida em estória posterior do EPIC-003+.
- Persistir score por candidatura aprovada → STORY-050 (registra `score_no_momento` na linha de candidatura ao aprovar/candidatar).

## Padrões de qualidade exigidos

- Cobertura ≥ 98% no módulo Match (núcleo).
- Função pura, determinística, sem efeito colateral.
- ADR seguindo `docs/skills/arquiteto/templates/adr.md`.

## Dependências

- **Bloqueada por:** STORY-044 (modelos Profissional/Vaga precisam existir para a função receber as entidades).
- **Bloqueia:** STORY-048 (feed consome a função), STORY-049 (detalhe usa o breakdown), STORY-051 (painel do contratante ordena por score).
- **Pré-requisitos:** banco homolog com modelos Vaga/Candidatura prontos (STORY-044 done).

## Decisões já tomadas

- `domain/match.md` — algoritmo e visibilidade.
- `business-rules.md` Match — pesos canônicos.
- ADR-008 — log JSON estruturado é o canal de eventos no MVP.

## Liberdade técnica do agente

Você (arquiteto) decide:
- Estrutura interna do módulo `app/Domain/Match/` (classes, value objects, factories).
- Shape exato dos payloads dos eventos (campos mínimos sugeridos: `vaga_id`, `profissional_id`, `score_total`, `componentes`, `motivo_filtro` quando aplicável).
- Como expor a função para o controller do feed (injeção, contract, etc.).

Você NÃO decide:
- Pesos (vêm de `business-rules.md`).
- Cap em 100 (vem de `domain/match.md`).
- Se boost altera score (não altera — decisão do PO acima).

## Definição de Pronto (DoD)

- [ ] ADR-014 `accepted`.
- [ ] Módulo Match implementado, cobertura ≥ 98%.
- [ ] Helper de eventos implementado, integração testada (log capturado).
- [ ] Benchmark verde no CI.
- [ ] `index.json` atualizado.
- [ ] "Notas do agente" preenchida.

## Notas do agente

### Decisões tomadas
- 

### Descobertas
- 

### Bloqueios encontrados
- 

### IDRs criados
- 

### Cobertura final
- Unitários: 
- E2E: n/a

### Links de evidência
- PR: 
- Pipeline: 
- Deploy de homologação: 
