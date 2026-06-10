---
story_id: STORY-092
slug: backend-abertura-disputa-transicao-notificacao
title: Backend — abertura de disputa (transição em_disputa + justificativa + pré-autorização mantida + notificação ao profissional)
epic_id: EPIC-005
sprint_id: SPRINT-2026-W31
type: implementation
target_role: programador
requires_design: false
status: done
owner_agent: claude-opus-4-8-programador-2026-06-10
created_at: 2026-06-10
updated_at: 2026-06-10
estimated_session_size: L
---

# STORY-092 — Backend: abertura de disputa

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Ela contém tudo o que você precisa. Se algo estiver ambíguo, registre em "Notas do agente" e pause. **Esta é a estória maior (L) do épico** — se o conjunto (modelo + transição + evento + notificação) não couber numa sessão única, **pare e escale ao PO** para quebrar (sugestão de corte: separar (a) modelo + transição `em_disputa` + justificativa de (b) evento + notificação ao profissional). Não infle a sessão.

## Contexto (por que esta estória existe)

Hoje, em `aguardando_checkout`, o contratante só pode **validar** o check-out (caminho feliz, entregue no EPIC-003). Falta o caminho de exceção: **recusar** com justificativa, o que leva o turno a `em_disputa` e dispara a mediação. Esta estória entrega o lado servidor da **abertura**: a transição de estado, o modelo de disputa, a justificativa obrigatória, a garantia de que a pré-autorização permanece bloqueada (nem captura nem libera) e a notificação ao profissional.

A resolução (`paga_integral`) é a STORY-093. As telas são 094/095/096.

- Épico: `epics/EPIC-005-disputa-minima/epic.md`
- Decisão que rege esta estória: **ADR-020** (STORY-090) — leia antes de codificar.
- Documentos canônicos:
  - `docs/especificacao/domain/disputa.md` (atributos, "quando nasce", justificativa obrigatória)
  - `docs/especificacao/domain/turno.md` (transição `aguardando_checkout → em_disputa`; pré-autorização bloqueada)
  - `docs/especificacao/domain/pagamento.md` (em `em_disputa`, pré-autorização permanece bloqueada)
  - `docs/project-state/decisions/adr/ADR-019-...md` (padrão de evento síncrono + notificação reusado)
  - Código vigente de check-out (EPIC-003): a validação/recusa de check-out já existe — esta estória **estende** o ponto de recusa, não recria.

## O quê (objetivo desta estória)

Expor a operação de **recusar o check-out abrindo disputa**: `aguardando_checkout → em_disputa`, persistindo `justificativa_contratante` (obrigatória) + metadados (`aberta_em`, `aberta_por`), mantendo a pré-autorização bloqueada, emitindo o evento de domínio e notificando o profissional (in-app + e-mail) conforme ADR-020.

## Por quê (valor para o usuário)

Sem esta transição, recusar check-out gera estado fantasma — turno preso, ninguém pago, profissional no escuro. Esta estória elimina o fantasma e dá início ao relógio de 30 min da mediação.

## Critérios de aceite

- [ ] **CA-1:** Dado um turno em `aguardando_checkout` cujo ator é o **contratante dono da vaga**, quando ele recusa o check-out com `justificativa_contratante` não-vazia, então o turno transita para `em_disputa`, persistindo `aberta_em`, `aberta_por` (contratante) e a justificativa, conforme o modelo da ADR-020.
- [ ] **CA-2:** Dado o mesmo cenário com **justificativa vazia/ausente**, quando ele tenta recusar, então a operação é rejeitada (422) com erro acionável e **o estado não muda** — não existe disputa sem justificativa (`disputa.md`).
- [ ] **CA-3:** A pré-autorização de pagamento permanece **bloqueada** na abertura — nenhuma captura nem liberação ocorre ao entrar em `em_disputa` (verificável via ACL de pagamento / fake PDR-017).
- [ ] **CA-4:** A transição só é possível a partir de `aguardando_checkout`. Tentar abrir disputa em qualquer outro estado (`ativo`, `finalizado`, `confirmado`, etc.) retorna 409/422 conforme padrão vigente, sem efeito.
- [ ] **CA-5:** RBAC: apenas o contratante dono da vaga abre a disputa. Profissional, outro contratante ou usuário não autenticado recebem 403, **fail-secure** (na dúvida, bloqueia). Sem vazamento entre contratantes.
- [ ] **CA-6:** Ao abrir, um evento de domínio é emitido **na transação** (padrão ADR-019) e o profissional é notificado in-app **e** por e-mail ("valor em disputa — mediação em até 30 min"), dentro de 30s (assíncrono é aceitável; a emissão do evento é síncrona). Notificação é **idempotente** (reprocesso não duplica).
- [ ] **CA-7:** O turno em `em_disputa` é **consultável como pendência do admin** conforme ADR-020 (derivada do estado, preferencialmente) — a STORY-096 consome isso; aqui basta o estado estar correto e consultável.

## Fora de escopo

- A resolução `paga_integral` (captura/Pix) — é a STORY-093.
- Telas de contratante/profissional/admin — 094/095/096.
- Resoluções `paga_parcial` / `sem_pagamento` (fora do MVP).
- Janela de tempo entre check-out e abertura de disputa — hoje é imediato (no ato da recusa), conforme `disputa.md`.

## Padrões de qualidade exigidos

Segue `docs/skills/po/references/quality-standards.md`. Resumo aplicável:

- Cobertura unitária ≥ 80% no código novo; **≥ 98% no núcleo** (máquina de estados da disputa, regra da justificativa obrigatória, RBAC fail-secure, idempotência da notificação).
- Teste de API cobrindo cada CA, incluindo bordas (justificativa vazia, estado errado, RBAC, idempotência).
- TDD (vermelho → verde por CA), como nas estórias do EPIC-003/004.
- Sem código não testado. Deploy automatizado para homologação verificado.

## Dependências

- **Bloqueada por:** STORY-090 (ADR-020 `accepted`)
- **Bloqueia:** STORY-093 (resolução), STORY-094 (FE contratante), STORY-095 (FE profissional), STORY-097 (validação)
- **Pré-requisitos de ambiente:** homologação operante; ACL de pagamento (fake PDR-017) disponível.

## Decisões já tomadas (não as reabra)

- ADR-020 (modelo de disputa + transições + evento) — base direta desta estória.
- ADR-015 (modelo de Turno), ADR-016 (ACL pagamento + idempotência), ADR-018 (UUID), ADR-019 (eventos/notificação).
- PDR-006 (disputa via admin), PDR-017 (pagamento via fake no MVP).

## Liberdade técnica do agente

Você decide estrutura de código, serviços, estrutura de testes e refatorações locais — dentro das ADRs vigentes. Você **não** decide critério de aceite, modelo de alto nível (ADR-020) nem telas. Se faltar decisão arquitetural não coberta pela ADR-020, **pare e registre** — não decida sozinho; escale ao Arquiteto.

## Definição de Pronto (DoD)

- [x] Todos os CAs passam, com testes cobrindo cada um.
- [x] Coberturas exigidas atingidas (núcleo 100% ≥ 98%; suíte 94,64% ≥ 80%).
- [x] Pipeline CI verde (run 27281018048, todos os jobs success); deploy de homologação verificado (deploy-stage run 27281326138 success: job de migração + Deploy API com gate de health-check passaram).
- [x] OpenAPI/contrato atualizado se um endpoint novo foi exposto — **N/A** (repo não mantém spec OpenAPI; rota documentada em `routes/api.php`).
- [x] IDR registrado se houve decisão de baixo nível com impacto futuro — **N/A** (decisões ficaram dentro da ADR-020 e dos padrões 053/064/067).
- [x] `index.json` atualizado: `status: done`; STORY-093 já `ready`, STORY-094/095 destravadas (blocked→ready).
- [x] "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Ao iniciar: `status: in_progress` no frontmatter e no índice. **Gatilho de quebra** (ver topo): se não couber, marque `blocked`, escale ao PO com a sugestão de corte e não infle a sessão.

## Notas do agente (preenchido durante/após execução)

### Decisões tomadas
- 2026-06-10 — **Sessão única (não quebrei a L).** O conjunto (modelo + transição + justificativa + evento + notificação) coube numa sessão porque é majoritariamente REUSO da infra existente (trigger ADR-015, `transitionTo`, `NotificarEventoTurnoService`/053-067, `CriarNotificacaoService` idempotente). Não houve necessidade de aplicar o gatilho de quebra.
- 2026-06-10 — **Endpoint novo `POST /api/turnos/{turno}/abrir-disputa`** (controller `AbrirDisputaController`), distinto de `/recusar-checkout` (ADR-020 Decisão 2: comandos separados). RBAC fail-secure no controller, espelhando `ValidarCheckoutController` (`user->id === turno->contratante_id && isContratante()`).
- 2026-06-10 — **PIN de check-out é zerado na abertura** (`pin_checkout_hash`/`tentativas` → null/0), por higiene, espelhando `recusar()`/`validar()` — não deixa segredo pendurado num turno que saiu de `aguardando_checkout`. A ADR só listava 3 efeitos; isto é local e consistente.
- 2026-06-10 — **`justificativa` max:2000 na validação HTTP** (texto livre da `disputa.md`); o guard de domínio (`trim` → `DisputaSemJustificativaException`) é a 2ª camada. O middleware `TrimStrings` do Laravel zera entradas só-espaços ANTES da validação, então via HTTP o caso "só espaços" cai no `required` (422 de validação); o guard de domínio cobre chamadas não-HTTP (testado direto no núcleo).
- 2026-06-10 — **Notificação reusa o pipeline 067**: tipo novo `disputa_aberta` (enum nativo via `ALTER TYPE`), assunto "Valor em disputa — mediação em até 30 min", template de e-mail seedado. **A justificativa NÃO entra no payload** (DDR-005 Decisão 2 — o profissional não a vê).

### Descobertas
- 2026-06-10 — A transição `aguardando_checkout → em_disputa` JÁ estava no enum/trigger (ADR-015, modelada na W28) — nenhuma migração de `ALTER TYPE turno_status` necessária. `TurnoStatusTest` segue em 14 transições.
- 2026-06-10 — Não há contrato OpenAPI mantido no repo (endpoints documentados via `routes/api.php` + telas) — item de DoD "OpenAPI" é N/A.

### Bloqueios encontrados
- (nenhum)

### IDRs criados
- (nenhum) — todas as decisões de baixo nível ficaram dentro da ADR-020 e dos padrões vigentes (053/064/067). Os IDRs antecipados pela ADR-020 (canal admin→api, forma da leitura do caso) são de STORY-093/096.

### Cobertura final
- Suíte completa da API: **1100 testes verdes**, cobertura de linhas **94,64%** (gate `--min=80`). Núcleo desta estória **100%**: `AbrirDisputaService` (31/31), `NotificarDisputaAberta` (4/4), `DisputaAberta` (1/1), `DisputaSemJustificativaException` (1/1); `AbrirDisputaController` 11/12 linhas (a linha não-coberta é o `catch` defensivo de `DisputaSemJustificativaException`, inalcançável via HTTP por causa do `TrimStrings`).
- Testes: `tests/Feature/Turno/AbrirDisputaTest.php` (CA-1..5, CA-7, idempotência de abertura) + `tests/Feature/Notificacao/NotificarDisputaAbertaTest.php` (CA-6 + não-vazamento da justificativa + idempotência + fila de e-mail).

### Links de evidência
- Commit em `main`: `6439395` feat(STORY-092). 
- CI (push main): run **27281018048** — todos os jobs success (commit lint, PHP lint api/admin, Flutter analyze, smoke builds, Trivy).
- Deploy homolog: deploy-stage run **27281326138** — success; jobs "Migrar (stage — sem seed)" e "Deploy API → stage" (com health-check 200) verdes → migrações `turnos.disputa` + enum `disputa_aberta` aplicadas e imagem nova no ar. Smoke externo direto não rodou (DNS de `api.stage.turni.com.br` não resolve no sandbox); régua = gate de health da pipeline.
