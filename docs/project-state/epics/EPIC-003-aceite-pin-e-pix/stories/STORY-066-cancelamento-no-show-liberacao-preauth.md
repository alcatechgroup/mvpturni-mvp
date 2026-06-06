---
story_id: STORY-066
slug: cancelamento-no-show-liberacao-preauth
title: Cancelamento antes do check-in + `no_show_pro` + liberação da pré-autorização
epic_id: EPIC-003
sprint_id: SPRINT-2026-W28
type: implementation
target_role: programador
requires_design: true
design_screen_id: SCREEN-STORY-066-cancelamento
status: in_progress
owner_agent: claude-opus-4-8-2026-06-06
created_at: 2026-06-03
updated_at: 2026-06-06
estimated_session_size: M
produces_idr: null
---

# STORY-066 — Cancelamento + `no_show_pro` + liberação da pré-autorização

## Contexto

Caminho de exceção do caminho feliz. PDR-007 permite cancelamento **antes** do check-in (estados `confirmado` para `cancelado_pro` ou `cancelado_emp`) sem motor de penalidade no MVP. `no_show_pro` é a transição automática quando profissional não faz check-in até X horas após o início previsto (definição numérica de X resolvida pelo spike STORY-055 ou aqui — registrar como descoberta).

Esta estória é **ortogonal ao caminho feliz** — pode iniciar a partir de quando STORY-058 fechar.

- Épico: `epics/EPIC-003-aceite-pin-e-pix/epic.md`
- Documentos: `domain/turno.md` (transições `confirmado → cancelado_*` e `confirmado/aguardando_checkin → no_show_pro`), `domain/pagamento.md` (liberação), PDR-007.

## O quê

Botão "Cancelar turno" no detalhe do turno (STORY-060) para profissional e contratante quando estado é `confirmado`. Modal de confirmação com textarea opcional de motivo. Sucesso: transita para `cancelado_pro` ou `cancelado_emp` conforme o lado, grava `cancelamento: { lado, motivo, antecedencia_horas, em }`, dispara `liberar` via ACL de pagamento (fake genérico — PDR-017). Cron job (reusa worker da STORY-034 — `everyMinute`) detecta turnos `confirmado` ou `aguardando_checkin` cujo `data_inicio + X horas < now()` e transita para `no_show_pro`, também liberando a pré-autorização.

## Por quê

Sem cancelamento, a pré-autorização do contratante fica ativa consumindo limite reservado no gateway (no MVP: registro de operação `concluida` em `pagamento_operacoes` sem liberar; comportamento mantido para quando Pagar.me real entrar). Sem `no_show_pro`, turno em que profissional sumiu fica em `confirmado` para sempre, distorcendo métricas e poluindo listas.

## Critérios de aceite

- [x] **CA-1:** Botão "Cancelar turno" no detalhe quando estado é `confirmado` (gatilho de baixa ênfase destrutiva, ambos os papéis — SCREEN-066 §A.3). Modal `dialog.confirm` com consequência explícita ("A reserva do pagamento será liberada e o {outro lado} será avisado. Essa ação não pode ser desfeita.") + textarea opcional de motivo (≤280).
- [x] **CA-2:** `POST /api/turnos/{id}/cancelar` recebe `{ motivo?: string }`, valida estado `confirmado` (outros → 422 `estado_invalido`), transita para `cancelado_pro`/`cancelado_emp` conforme RBAC (403 cruzado fail-secure), grava `cancelamento { lado, motivo, antecedencia_horas, em }`, dispara `liberar(turno_id)` via ACL com idempotência **`liberacao:{turno_id}`** (chave da convenção `{tipo}:{turno_id}` do TipoOperacaoPagamento da 056 — semanticamente o `liberar:{turno_id}` do CA).
- [x] **CA-3:** Sucesso da liberação: audit `pagamento.liberado` (com motivo `cancelamento|no_show`, charge_id e total) UMA vez (curto-circuito idempotente não duplica); evento `TurnoCancelado` (turno_id UUID string, lado, motivo) emitido pós-commit para a STORY-067.
- [x] **CA-4:** Falha da liberação: audit `pagamento.liberacao_falhou` com motivo; caso tipo `liberacao` na MESMA fila da 065, generalizada para "Falhas de pagamento" (rename validado pelo PO; rota `/pix-falhas` e testids preservados) com badge "Liberação falhou — tratamento manual", valor = total reservado, sem chave Pix.
- [x] **CA-5:** Cron `turnos:detectar-no-show` em `everyMinute` (worker da STORY-034) detecta `data_inicio + X < now() AND status IN (confirmado, aguardando_checkin)` → `no_show_pro`. **X = 2 horas** (decidido por Alexandro em chat 2026-06-06; config `turno.no_show_horas` / env `TURNI_NO_SHOW_HORAS`). Lock por linha (corrida com validação de PIN re-verificada); evento `TurnoNoShow` para a 067. Exigiu a **14ª transição** `confirmado → no_show_pro` (enum + trigger — `domain/turno.md` atualizado).
- [x] **CA-6:** `no_show_pro` libera igual cancelamento (mesmo job, audit `pagamento.liberado` com `motivo: 'no_show'`).
- [x] **CA-7:** Lista (059) e detalhe (060) mostram terminais com badge (`⊘ Cancelado` / `⊘ Não realizado` — já existiam) e timeline completa: `cancelado` (voz de quem lê + motivo visível aos 2 lados — decisão PO), `no_show_pro` (copy com o X real via `limite_horas` do payload) e `pagamento_liberado` (novo na whitelist; valor para o contratante).
- [x] **CA-8:** Núcleo: CancelarTurnoService/Controller/TurnoStatus/DetectarNoShowCommand 100%, LiberarPreAutorizacaoJob 98% linhas; api total 93,9% (≥80). E2E: cancelamento dos 2 lados + no-show com turno vencido no seed + cron real no gate (`_e2e-seed` roda o comando); travel coberto no Pest (`travel(Xh+1m)` + X configurável).

## Fora de escopo

- Motor de penalidade (PDR-007 — placeholder no modelo; cálculo pós-MVP).
- Cancelamento depois de `ativo` (não permitido — `domain/turno.md`).
- UI de "Por que cancelei" → vai para wishlist se aparecer demanda.

## Padrões de qualidade

≥ 80% / ≥ 98% no núcleo. E2E cobre cancelamento + no-show. Cron exercitado em CI via `travel(Xh + 1m)`.

## Dependências

- **Bloqueada por:** STORY-058 (modelo + turnos em `confirmado`), STORY-056 (ACL `liberar`), STORY-060 (detalhe é onde o botão fica).
- **Bloqueia:** nenhuma direta; STORY-068 verifica que os caminhos terminais aparecem.
- **Pré-requisitos:** SCREEN-STORY-066 entregue (modal + estado terminal).

## Decisões já tomadas

ADR-015 / ADR-016 / **ADR-018 (UUIDv7 em PKs — URL `/turnos/{uuid}/cancelar` aceita UUID; chave de idempotência da liberação usa UUID; evento `TurnoCancelado`/`TurnoNoShow` carrega `turno_id` UUID string)** / **PDR-017 (gateway é fake genérico — `liberar` é chamada via ACL e o fake responde sem efeito externo)**, PDR-007.

## Liberdade técnica

Decide: estrutura interna do listener de cron, formato da nota de motivo, microcopy do modal.

NÃO decide: motor de penalidade (PDR-007 — fora MVP); que cancelamento depois de `ativo` não é permitido (`domain/turno.md`).

## Definição de Pronto

- [ ] CAs marcados; deploy verificado.
- [ ] SCREEN-STORY-066 `shipped`.
- [ ] Alexandro decide X de no-show em chat antes do código fechar.
- [ ] Alexandro testa em homolog (cancelamento + no-show forçado via travel).
- [ ] `index.json` atualizado.
- [ ] "Notas do agente" preenchida.

## Protocolo

`docs/skills/po/references/agent-task-format.md`.

## Notas do agente

### Decisões tomadas
- **X do no-show = 2h** — decidido por Alexandro em chat (2026-06-06) ANTES do código, como a DoD pedia. Documentado aqui + `config/turno.php` (`TURNI_NO_SHOW_HORAS`) + `domain/turno.md` (lacuna resolvida). Sem IDR: é parâmetro de produto configurável, não decisão técnica transversal.
- **14ª transição** `confirmado → no_show_pro` (enum TurnoStatus + trigger `enforce_turno_transition` mudados JUNTOS, migration própria): o CA-5 detecta turnos vencidos também em `confirmado` (PIN nunca gerado), e a máquina da STORY-055 só previa no-show a partir de `aguardando_checkin`. `domain/turno.md` atualizado.
- **Chave de idempotência `liberacao:{turno_id}`** (não `liberar:` do texto do CA): segue a convenção `{tipo}:{turno_id}` do TipoOperacaoPagamento (STORY-056/ADR-016) — `Liberacao` já existia no enum desde a 056.
- **Fila do admin generalizada** ("Pix com falha" → "Falhas de pagamento") — validada por Alexandro junto com o protótipo; rota e testids preservados (Playwright da 065 intacto); casos distinguidos por coluna `tipo` (`pix|liberacao`).
- **Motivo do cancelamento visível aos 2 lados** na timeline (decisão de Alexandro na validação do spec); timeline fala na voz de quem lê ("Você cancelou este turno.").
- **Falha de liberação invisível ao usuário final** (espelho da decisão §A.4 da 065): o turno cancela normalmente; o tratamento é operacional (fila). Sem evento `pagamento_liberado` na timeline até resolver.
- Cancelamento sucede MESMO se a liberação falhar depois (liberação é assíncrona no worker, pós-commit) — o estado do turno nunca fica refém do gateway.

### Descobertas
- **[BUG pré-existente corrigido] Listeners registrados em DOBRO**: o auto-discovery de eventos do Laravel estava ativo junto com o registro explícito do AppServiceProvider (cujo comentário prometia "sem event discovery"). TODO listener rodava 2× por evento — `HandlePixFalhou` da 065 duplicava o audit `pix.falhou`; `TurnoFinalizadoListener` enfileirava 2 `CapturarEPagarTurnoJob` (a idempotência da 056 mascarava o dano financeiro). Fix: `withEvents(discover: false)` em `bootstrap/app.php`. Pego pelo teste de lote do cron (4 jobs em vez de 2).
- O teste de corrida do cron pegou um bug real do meu próprio comando: o evento `TurnoNoShow` disparava mesmo quando o guard re-verificado abortava a transição — corrigido (dispatch condicionado ao commit da transição).
- `schedule:run` NÃO roda em homolog/prod (gap da STORY-073, ainda `ready`): o cron de no-show está agendado mas não dispara sozinho lá. Para o teste de homolog, executar `php artisan turnos:detectar-no-show` manualmente (job one-off no Cloud Run). Registrado no agendamento (routes/console.php).
- Gate E2E: o `_e2e-seed` do Makefile agora roda o cron real após o seed — o par `noshow.seed` nasce vencido (início −3h) e o E2E encontra o turno já transitado com a liberação processada pelo worker contra o fake.

### Bloqueios encontrados
- Nenhum.

### IDRs criados
- Nenhum (decisões locais; X do no-show é config de produto documentada na estória + domain doc).

### Cobertura final
- Unitários/integração (api): **957→987 testes verdes** (suíte completa), total **93,9%**; núcleo da estória: CancelarTurnoService 100%, CancelarTurnoController 100%, TurnoStatus 100%, DetectarNoShowCommand 100%, LiberarPreAutorizacaoJob 98% (linhas), PixFalha 94%.
- Admin: 118 testes verdes (fila generalizada + 3 cenários novos de liberação).
- WebApp: 533 widget tests verdes (17 novos da 066: gatilho por papel/estado, dialog, erro/422, timeline dos terminais, service HTTP).
- E2E: cancelamento dos 2 lados + no-show (cron real + worker + fake) — ver evidência abaixo.

### Links de evidência
- PR: commit direto na main (workflow do projeto) — d897315 (design), f4860df (api), 21b54b5 (admin), 8414b85 (webapp/E2E).
- Pipeline: (preencher após push)
- Deploy de homologação: (preencher após rc)
