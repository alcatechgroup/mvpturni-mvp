---
story_id: STORY-063
slug: cronometro-bilateral-tempo-real
title: Cronômetro bilateral vivo em tempo real (latência ≤ 2s)
epic_id: EPIC-003
sprint_id: SPRINT-2026-W28
type: implementation
target_role: programador
requires_design: true
design_screen_id: SCREEN-STORY-063-cronometro
status: ready
owner_agent: null
created_at: 2026-06-03
updated_at: 2026-06-03
estimated_session_size: L  # gatilho de quebra documentado abaixo
produces_idr: null
---

# STORY-063 — Cronômetro bilateral vivo

> **Para o agente programador:** esta é uma das **duas estórias L** desta sprint. Tempo real em 2 lados é tecnicamente novo. Se durante a execução perceber que o escopo não cabe em uma sessão, **pare e escale ao PO** com a proposta de quebra (backend de eventos + canal em uma; UI bilateral consumindo em outra). Está documentado nos riscos do sprint como exceção válida.

## Contexto

Turno entrou em `ativo` (STORY-062). Ambos os lados precisam ver o **mesmo tempo decorrido** em tempo real (latência ≤ 2s entre o que o profissional vê e o que o contratante vê). ADR-017 (STORY-057) já decidiu o canal de tempo real e fixou "servidor é fonte de verdade do tempo decorrido — clientes só consomem".

- Épico: `epics/EPIC-003-aceite-pin-e-pix/epic.md`
- Documentos: `domain/turno.md` (cronômetro), ADR-017 (canal de tempo real), IDR-026 (TurniDateTime).

## O quê

Componente de cronômetro vivo no detalhe do turno (STORY-060) que aparece quando estado é `ativo`. Backend emite tick periódico via canal escolhido em ADR-017; clientes consomem e renderizam tempo decorrido (HH:MM:SS) ou formato similar. Mostra também `data_inicio` e tempo previsto (`data_fim - data_inicio`).

## Por quê

Cronômetro vivo é a peça que faz o turno **parecer vivo** para os dois lados — sem ele, profissional e contratante ficam adivinhando o tempo. Sincronia bilateral é o que evita disputa antes do check-out ("ah, eu achei que era menos tempo").

## Critérios de aceite

- [ ] **CA-1:** Backend emite tick com tempo decorrido por canal de ADR-017 (1 emissão a cada 1s, configurável; OK começar em 2s e reduzir se a carga permitir).
- [ ] **CA-2:** Componente Flutter consome o canal e renderiza tempo decorrido (HH:MM:SS para turnos > 1h; MM:SS para curtos). Microcopy mostra também "Início previsto: HH:MM" e "Duração prevista: Xh".
- [ ] **CA-3:** Sincronia bilateral verificada: em 2 navegadores abertos no mesmo turno em `ativo`, a diferença entre os 2 cronômetros não passa de **2s** em janela contínua de 5min (teste E2E em CI roda essa verificação).
- [ ] **CA-4:** Servidor é fonte de verdade — clientes nunca calculam tempo decorrido localmente (mitiga clocks divergentes; aprendizado da W27 STORY-052 / IDR-026).
- [ ] **CA-5:** Quando turno sai de `ativo` (transita para `aguardando_checkout` em STORY-064), componente para de receber tick e mostra "Aguardando check-out — duração final: HH:MM:SS".
- [ ] **CA-6:** Reconexão básica — se o cliente perde a conexão por < 30s, reconecta automático sem perder a contagem (servidor é fonte de verdade; a UI só re-sincroniza). > 30s: mostra "Reconectando..." e retoma quando voltar.
- [ ] **CA-7:** Performance — canal aguenta pelo menos **50 turnos `ativo` simultâneos** em homolog sem latência > 2s (teste de carga no CI; ajustar tick rate se necessário).
- [ ] **CA-8:** Cobertura ≥ 80% no código novo, ≥ 98% no cálculo de tempo (helper compartilhado entre tela e teste — reuso de `TurniDateTime`).

## Gatilho de quebra (estória L)

Se durante a execução não couber em 1 sessão, escalar ao PO com proposta:

- **STORY-063-A** — Backend: canal escolhido em ADR-017 implementado, emissão de tick, persistência mínima (CA-1, 4, 7). Tamanho M.
- **STORY-063-B** — UI Flutter consumindo o canal + sincronia bilateral + reconexão (CA-2, 3, 5, 6, 8). Tamanho M.

Quebra registrada em "Mudanças no escopo do sprint" no W28. **Não inflar** a sessão.

## Fora de escopo

- Pausa de cronômetro (sem requisito de UX no MVP).
- Horas extras / cálculo de tempo além de `data_fim` (registrar como follow-up).
- Notificação "passou da duração prevista" (registrar como follow-up).

## Padrões de qualidade

≥ 80% / ≥ 98% no cálculo de tempo. E2E `integration_test` cobre sincronia bilateral. Teste de carga em CI.

## Dependências

- **Bloqueada por:** STORY-057 (canal decidido), STORY-062 (transição para `ativo` é o gatilho).
- **Bloqueia:** STORY-064 (check-out só faz sentido com cronômetro vivo).
- **Pré-requisitos:** SCREEN-STORY-063 entregue.

## Decisões já tomadas

ADR-015, ADR-017, **ADR-018 (UUIDv7 em PKs — canal de tempo real publica em tópico/channel identificado por `turno_id` UUID string; payload do tick referencia entidades por UUID)**, IDR-026.

## Liberdade técnica

Decide: tick rate exato, formato de payload do canal, formato HH:MM:SS vs MM:SS, estilo visual do componente.

NÃO decide: canal de tempo real (vive em ADR-017); que servidor é fonte de verdade (ADR-017 fixa).

## Definição de Pronto

- [ ] CAs marcados; deploy verificado.
- [ ] SCREEN-STORY-063 `shipped`.
- [ ] Alexandro testa em homolog (2 navegadores, cronômetro sincronizado).
- [ ] Teste de carga 50 turnos passou em CI.
- [ ] `index.json` atualizado.
- [ ] "Notas do agente" preenchida.

## Protocolo

`docs/skills/po/references/agent-task-format.md`.

## Notas do agente

### Decisões tomadas
### Descobertas
### Bloqueios encontrados
### IDRs criados
### Cobertura final
- Unitários:
- E2E:
### Links de evidência
- PR:
- Pipeline:
- Deploy de homologação:
