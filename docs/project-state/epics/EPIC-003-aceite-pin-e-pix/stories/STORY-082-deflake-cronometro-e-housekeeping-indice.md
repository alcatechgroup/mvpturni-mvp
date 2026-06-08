---
story_id: STORY-082
slug: deflake-cronometro-e-housekeeping-indice
title: "Deflake do E2E de sincronia do cronômetro (F-B-1) + housekeeping do índice (F-NB-4)"
epic_id: EPIC-003
sprint_id: SPRINT-2026-W29
type: bugfix
target_role: programador
requires_design: false
design_screen_id: null
status: ready
owner_agent: null
created_at: 2026-06-08
updated_at: 2026-06-08
estimated_session_size: S
produces_idr: null
---

# STORY-082 — Deflake do cronômetro + housekeeping do índice

> **Para o agente que vai executar:** leia esta estória por inteiro. É ortogonal ao EPIC-012 — pode iniciar a qualquer momento da sprint.

## Contexto (por que esta estória existe)

No fechamento da SPRINT-2026-W28, o validador (STORY-068) emitiu veredito `rejected` com **F-B-1** (flake do teste E2E de sincronia do cronômetro — 3 falhas em 7 execuções no dia do fechamento; funcionalidade verificada viva; re-run sempre verde) **aceito pelo PO com dívida explícita**, e **F-NB-4** (housekeeping do `index.json`: IDR-028 fora do índice + STORY-056-B marcada `abandoned` no arquivo × `ready`/`abandoned` divergente). Os "Ajustes para o próximo sprint" da W28 mandam: "na abertura da próxima sprint, 1 estória S de dívidas do veredito — deflake/re-especificação do teste de sincronia do cronômetro (prioridade — é gate de release e flakeou 3× no dia do fechamento) + housekeeping F-NB-4".

- Sprint origem: `sprints/SPRINT-2026-W28.md` (seção "Fechamento" → "Ajustes para o próximo sprint", itens 2 e 3).
- Veredito: `epics/EPIC-003-aceite-pin-e-pix/validation/report.md` (F-B-1, F-NB-4).
- Aprendizado de processo W28: "asserção de SLA de timing em build debug (flutter drive/DDC) é fonte estrutural de flake".

## O quê (objetivo desta estória)

Eliminar o flake do teste E2E de sincronia do cronômetro bilateral — por deflake (estabilizar a medição com margem de ambiente) ou re-especificação da forma de medir a sincronia ≤2s — de modo que o gate de release pare de falhar de forma intermitente; e reconciliar o `index.json` com a realidade dos arquivos (F-NB-4).

## Por quê (valor para o usuário)

Um gate de release que flakea mina a confiança no pipeline e atrasa entregas — incluindo as do próprio EPIC-012. Estabilizá-lo cedo protege o ritmo da W29. O housekeeping do índice mantém a fonte de verdade queryable coerente (princípio #5 do PO).

## Critérios de aceite

- [ ] **CA-1:** O teste E2E de sincronia do cronômetro passa de forma **estável** (ex.: ≥20 execuções consecutivas verdes, ou critério equivalente definido na execução) — sem mascarar regressão real da funcionalidade ≤2s.
- [ ] **CA-2:** A nova forma de asserção de timing **não** depende de SLA de build debug sensível a carga (aprendizado W28); a medição reflete a sincronia funcional, não a lentidão do ambiente de teste.
- [ ] **CA-3:** Se a abordagem mudar a forma de medir, fica registrada em IDR (decisão de baixo nível com impacto futuro nos CAs de timing).
- [ ] **CA-4 (F-NB-4):** `index.json` reconciliado com os arquivos: IDR-028 indexado; STORY-056-B com status coerente entre arquivo e índice; varredura de divergências arquivo↔índice das entradas do EPIC-003 sem pendência.
- [ ] **CA-5:** Pipeline CI verde; a estabilização é verificável no histórico de execuções.

## Fora de escopo

- F-NB-6 (PIN p95 = 509ms) e F-NB-7 (e-mail p95 = 61,6s) — só endereçar se a medição contínua confirmar (alertas já ativos — decisão W28). Não entram nesta estória.
- Qualquer mudança funcional do cronômetro (ele está validado vivo).

## Padrões de qualidade exigidos

`docs/skills/po/references/quality-standards.md`. Não reduzir cobertura; o E2E continua sendo gate.

## Dependências

- **Bloqueada por:** nenhuma (ortogonal — pode iniciar imediatamente).
- **Bloqueia:** nenhuma.

## Decisões já tomadas (não as reabra)

- ADR-017 (tempo real do cronômetro — servidor é fonte de verdade do tempo decorrido; clientes consomem), IDR-026 (`TurniDateTime`), IDR-010/011 (modelo E2E).

## Liberdade técnica do agente

Decide: a estratégia de deflake/re-especificação, o critério de estabilidade, refatoração local do teste.

NÃO decide: relaxar o requisito funcional de sincronia ≤2s (é critério de produto do EPIC-003).

## Definição de Pronto (DoD)

- [ ] CAs passam; estabilidade demonstrada; índice reconciliado.
- [ ] IDR registrado se a medição mudou de forma.
- [ ] Pipeline verde; `index.json` atualizado: status = `done`. "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

`docs/skills/po/references/agent-task-format.md`.

## Notas do agente (preenchido durante/após execução)

### Decisões tomadas
- 

### Descobertas
- **Dado pré-semeado (2026-06-08, durante a STORY-077):** a suíte E2E `integration_test/turnos/checkout_test.dart` (`ciclo completo… cronômetro… check-out… Pix`) também flakeia no mesmo domínio do F-B-1 — no gate completo falhou com "Multiple exceptions (2)"; **isolada em banco limpo PENDURA ~8–9 min sem produzir resultado**. Confirmado **pré-existente** (mesma pendura tanto no shell da 077 quanto no commit pré-shell `c3c9b9d`), logo **não é regressão do shell**. Hipótese: asserção/polling de timing (Pix/worker + `pumpAndSettle` sobre cronômetro/estado assíncrono) em build debug (DDC) — o mesmo aprendizado estrutural do F-B-1. Vale incluir o `checkout_test` no escopo do deflake.

### IDRs criados
- 

### Links de evidência
- PR / Pipeline: 
