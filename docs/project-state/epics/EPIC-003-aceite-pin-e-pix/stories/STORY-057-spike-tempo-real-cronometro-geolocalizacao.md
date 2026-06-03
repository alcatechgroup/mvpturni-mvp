---
story_id: STORY-057
slug: spike-tempo-real-cronometro-geolocalizacao
title: Spike Arquiteto — tempo real do cronômetro bilateral + geolocalização Haversine no check-in
epic_id: EPIC-003
sprint_id: SPRINT-2026-W28
type: spike
target_role: arquiteto
requires_design: false
design_screen_id: null
status: ready
owner_agent: null
created_at: 2026-06-03
updated_at: 2026-06-03
estimated_session_size: M
produces_idr: null  # produz ADR-017
---

# STORY-057 — Spike Arquiteto: tempo real cronômetro + geolocalização Haversine

> **Para o agente arquiteto:** esta estória decide duas estratégias técnicas de runtime que afetam várias estórias de implementação (063 cronômetro, 061 check-in com geofencing, 062 validação). Não confunda: o **comportamento** (cronômetro bilateral visível em tempo real, geofencing alerta-e-registra) está fixado em `domain/turno.md` e PDR-008 — esta estória escolhe **como tecnicamente** entregar.

## Contexto (por que esta estória existe)

`domain/turno.md` exige cronômetro bilateral vivo enquanto turno `ativo` (latência ≤ 2s entre os 2 lados) e PIN de check-in carregando flag `geofencing_ok` + distância em metros (PDR-008). Sem decisão arquitetural cobrindo esses dois pontos, STORY-061 (check-in) e STORY-063 (cronômetro) não conseguem começar.

As duas decisões cabem na **mesma ADR** porque são "estratégias técnicas de runtime" — escolhas de mecanismo do navegador/servidor — com superfície disjunta mas afinidade de timing (ambas envolvem o evento de check-in).

- Épico: `epics/EPIC-003-aceite-pin-e-pix/epic.md`
- Documentos canônicos:
  - `docs/especificacao/domain/turno.md` (cronômetro bilateral, geofencing como atributo do evento)
  - `decisions/pdr/PDR-008-geofencing-alerta-e-registra.md` (comportamento)
  - `decisions/adr/ADR-001-stack-principal.md` (Laravel + Livewire + Flutter — restringe ferramental)
  - `decisions/adr/ADR-002-topologia.md` (api + admin + worker)
  - `decisions/idr/IDR-026-*` (TurniDateTime — política única de data/hora; cronômetro consome)

## O quê (objetivo desta estória)

Propor **ADR-017** com 2 decisões: (a) canal de tempo real do cronômetro bilateral e (b) estratégia de geolocalização no check-in. Entregar **prova de conceito mínima** rodando em homolog (cronômetro vazio que sobe via canal escolhido; coordenada do navegador chegando ao backend e calculando distância via Haversine).

## Por quê (valor para o usuário)

Cronômetro fora de sincronia entre os 2 lados quebra a confiança no produto (cada um vê um tempo). Geofencing que não funciona em rua quebra PDR-008. As duas precisam estar tecnicamente desenhadas antes da UI ser construída.

## Critérios de aceite

- [ ] **CA-1:** ADR-017 escrita, status `accepted`, aprovação do Alexandro registrada.
- [ ] **CA-2:** Decisão de canal de tempo real fundamentada — comparar pelo menos WebSocket (Laravel Reverb/Pusher), SSE e polling com janela curta. Considerar: latência (≤ 2s requerida), custo em homolog/produção, complexidade de operação, fit com ADR-001/002. Princípio #1 (simplicidade) e princípio #7 (não-antecipação) ponderados explicitamente.
- [ ] **CA-3:** Decisão de geolocalização fundamentada — browser Geolocation API + cálculo Haversine no backend usando o helper `Support\Geo` (criado em STORY-049 EPIC-002, reuso) vs PostGIS. Mesma análise de complexidade × benefício.
- [ ] **CA-4:** Servidor é fonte de verdade do tempo decorrido — clientes só consomem (mitiga risco de clocks divergentes do sprint). ADR-017 fixa essa invariante.
- [ ] **CA-5:** Prova de conceito mínima em homolog: turno seedado em `ativo` mostra cronômetro avançando em 2 navegadores abertos simultaneamente (profissional e contratante), sincronizado em ≤ 2s. Geolocalização do navegador chega ao backend e o backend calcula distância em metros via Haversine.
- [ ] **CA-6:** Cobertura ≥ 80% no código novo, ≥ 98% no cálculo de Haversine (núcleo de regra) — reuso do código já testado em STORY-049 é aceitável e desejável.

## Fora de escopo

- UI do cronômetro propriamente dita (vive em STORY-063).
- UI do PIN de check-in (vive em STORY-061).
- Validação do PIN pelo contratante (vive em STORY-062).
- Política de retry quando o navegador perde conexão por > 5s (registrar como follow-up, não bloqueia esta estória).

## Padrões de qualidade exigidos

`docs/skills/po/references/quality-standards.md`. ≥ 80% geral, ≥ 98% no cálculo de Haversine. Prova de conceito tem evidência observável (vídeo de tela ou screenshot dos 2 navegadores em homolog).

## Dependências

- **Bloqueada por:** nenhuma.
- **Bloqueia:** STORY-061 (geolocalização), STORY-063 (cronômetro bilateral).
- **Pré-requisitos de ambiente:** WebApp e admin operantes em homolog (herdado de EPIC-000); helper `Support\Geo` (criado em STORY-049).

## Decisões já tomadas (não as reabra)

- ADR-001 / ADR-002 / ADR-004 / ADR-008 / IDR-026
- **ADR-018 — UUIDv7 em PKs (EPIC-010/W27.5). Eventos do canal de tempo real carregam `turno_id` como string UUID.**
- PDR-008 — comportamento de geofencing (alerta-e-registra, não bloqueia)

## Liberdade técnica do agente

Você decide: canal de tempo real, formato de payload, política de reconexão básica, estrutura interna do cálculo de distância.

Você NÃO decide: comportamento de geofencing (PDR-008 fixa); comportamento de cronômetro (`domain/turno.md` fixa).

## Definição de Pronto (DoD)

- [ ] ADR-017 escrita, revisada, `accepted`.
- [ ] Prova de conceito rodando em homolog (evidência anexada à estória).
- [ ] Pipeline verde com cobertura exigida.
- [ ] `index.json` atualizado.
- [ ] "Notas do agente" preenchida.

## Protocolo do agente

`docs/skills/po/references/agent-task-format.md`.

## Notas do agente

### Decisões tomadas
- 

### Descobertas
- 

### Bloqueios encontrados
- 

### ADRs/IDRs criados
- ADR-017 — Tempo real cronômetro + geolocalização Haversine — `decisions/adr/ADR-017-<slug>.md`

### Cobertura final
- Unitários: <%>

### Links de evidência
- PR:
- Pipeline:
- Deploy de homologação (PoC):
