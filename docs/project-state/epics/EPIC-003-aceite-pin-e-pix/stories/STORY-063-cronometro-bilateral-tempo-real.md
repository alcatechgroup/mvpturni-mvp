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
status: in_review
owner_agent: claude-opus-4-8
created_at: 2026-06-03
updated_at: 2026-06-05
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

- [x] **CA-1:** Backend emite tick com tempo decorrido por canal de ADR-017 (1 emissão a cada 1s, configurável; OK começar em 2s e reduzir se a carga permitir). *Pela ADR-017 o "tick" é LOCAL (1s, sem rede): o canal é o endpoint de âncora `GET /turnos/{id}/cronometro`, com janela de reconciliação configurável pelo servidor (`polling_segundos`, default 5s, env `TURNI_CRONOMETRO_POLLING_SEGUNDOS`).*
- [x] **CA-2:** Componente Flutter consome o canal e renderiza tempo decorrido (HH:MM:SS para turnos > 1h; MM:SS para curtos — promove ao cruzar 1h, nunca regride). Microcopy mostra também "Início previsto: HH:MM" e "Duração prevista: Xh".
- [x] **CA-3:** Sincronia bilateral verificada: E2E sobre o mesmo turno `ativo` amostra os 2 papéis contra a âncora do servidor (≥ 12 amostras em ≥ 60s, ≤ 1s por lado ⇒ ≤ 2s entre os lados por transitividade). *Janela ajustada de 5min → ~60s com aprovação do PO (2026-06-05): com âncora comum a sincronia é estrutural; 60s cobrem vários ciclos de polling sem inflar o gate.*
- [x] **CA-4:** Servidor é fonte de verdade — clientes nunca calculam tempo decorrido localmente (derivam de `iniciado_em` + offset contra `servidor_agora`; `CronometroAncora` puro, IDR-026).
- [x] **CA-5:** Quando turno sai de `ativo`, componente para o polling e mostra "Aguardando check-out — duração final: HH:MM:SS" (a duração final vem de `encerrado_em`, derivado do evento `checkout_solicitado` do audit log — bilateralmente idêntica; premissa p/ STORY-064 documentada na SCREEN-063 §10).
- [x] **CA-6:** Reconexão básica — falha de polling < 30s é silêncio (tick local segue, âncora válida); ≥ 30s mostra "Reconectando… O tempo continua valendo." e a linha some no primeiro polling que volta. O display nunca congela em `ativo`.
- [x] **CA-7:** Performance — teste de carga no CI: 50 turnos `ativo` simultâneos, 100 leituras (2 lados), nenhuma > 2s e p95 < 500ms (`CronometroCargaTest`).
- [x] **CA-8:** Cobertura: núcleo de cálculo `CronometroAncora` **100%** (≥ 98% ✓); `cronometro_card.dart` 94,2% e `cronometro_service.dart` 93,8% (≥ 80% ✓); `CronometroController` 100%; API total 93,5%.

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
- **A estória NÃO precisou de quebra (gatilho L não disparou):** a PoC da STORY-057 já tinha entregue o backend de âncora (`CronometroController`) e o núcleo puro (`CronometroAncora`) testados — sobrou integrar a UI final + estados + E2E, que coube na sessão.
- **Janela do E2E do CA-3:** 5min → ~60s (≥ 12 amostras), aprovado pelo PO em chat (2026-06-05). Justificativa: com âncora comum (ADR-017) a sincronia é estrutural; 60s cobrem >10 ciclos de polling.
- **Formato (liberdade técnica):** decisão pelo turno (duração prevista < 1h → MM:SS) com promoção irreversível ao cruzar 1h — nunca "75:30".
- **`encerrado_em` em `aguardando_checkout`:** `check_out_at` só nasce na transição → `finalizado` (ADR-015); o endpoint deriva o encerramento EXIBIDO do evento `turno.checkout_solicitado` do audit log, para a duração final congelar idêntica nos 2 lados. **Premissa para a STORY-064**: gravar esse evento na transição (o seed da 060 já o grava). Degrade sem evento: congela no último decorrido conhecido.
- **Pulso do dot sem `AnimationController.repeat`:** animação contínua nunca aquieta o frame scheduler e travaria os `pumpAndSettle` do harness E2E (a 062 termina com o turno `ativo`, onde o card monta). O pulso é `AnimatedOpacity` dirigida pelo próprio tick de 1s.
- **Aba em background pausa timers** (`AppLifecycleState.hidden/paused` ↔ visibilitychange no Web — ADR-017); o resume re-sincroniza imediatamente.
- **Relógio injetável no card** (`now`): a janela de 30s do CA-6 compara `DateTime.now()` real, que não avança no tempo fake dos widget tests.

### Descobertas
- O par de seed do E2E (`*.cronometro.seed`) pode ser **estável entre execuções** (leitura pura — o cronômetro não muta estado); o reseed só renova `check_in_at` (~35min decorridos) para o cenário não envelhecer em homolog.
- Família visual "número grande em mono" atingiu o 3º uso (pin.display 061, input.pin 062, cronometro.display 063) → registrada como `mono.display` no `components.md` (com a regra de `tabularFigures` obrigatório em display vivo).

### Bloqueios encontrados
- Nenhum.

### IDRs criados
- Nenhum (mecanismo já fixado por ADR-017; nenhuma decisão transversal nova).

### Cobertura final
- Unitários: `CronometroAncora` (núcleo de cálculo) **100%** (CA-8 ≥ 98% ✓); `cronometro_card.dart` 94,2%; `cronometro_service.dart` 93,8%; `CronometroController` 100% (methods+lines); API total 93,5% (840 testes); WebApp 490 testes.
- E2E: `integration_test/turnos/cronometro_test.dart` — fluxo bilateral real (profissional → contratante no MESMO turno `ativo`), ≥ 12 amostras em ≥ 60s, cada lado ≤ 1s da âncora do servidor ⇒ ≤ 2s entre os lados (CA-3); gate completo verde (auth/cadastro/vagas/feed/turnos sem regressão). Carga: `CronometroCargaTest` (50 turnos, 100 leituras, max < 2s, p95 < 500ms) no CI.

### Links de evidência
- PR: commit direto na main (workflow do projeto).
- Pipeline: release.yml dispara na tag `v0.1.0-rc.75`.
- Deploy de homologação: rc.75 — verificação manual do PO (2 navegadores) pendente no DoD.
