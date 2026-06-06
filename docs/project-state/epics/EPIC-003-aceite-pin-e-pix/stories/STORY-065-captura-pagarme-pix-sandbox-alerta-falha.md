---
story_id: STORY-065
slug: captura-pagarme-pix-sandbox-alerta-falha
title: Captura + Pix via gateway (fake genérico — PDR-017) + alerta admin em falha (PDR-010)
epic_id: EPIC-003
sprint_id: SPRINT-2026-W28
type: implementation
target_role: programador
requires_design: true  # [2026-06-06] Alexandro pediu fluxo designer→programador em chat; era false ("admin reusa fila padrão") — o spec formaliza o card de valor (CA-4) e a aba "Pix com falha" (CA-5/8)
design_screen_id: SCREEN-STORY-065-pix-enviado-e-fila-falhas
status: in_review  # aguardando teste manual do Alexandro em homolog (rc.77)
owner_agent: claude-opus-4-8-2026-06-06
created_at: 2026-06-03
updated_at: 2026-06-06
estimated_session_size: M
produces_idr: null
---

# STORY-065 — Captura + Pix via gateway (fake genérico) + alerta admin em falha

> **Nota PDR-017 (2026-06-04):** o gateway implementador no MVP é o **fake genérico** (STORY-056), não o Pagar.me real. O ciclo do domínio (captura → Pix → audit log → fila de Pix com falha) **é idêntico** ao que seria com Pagar.me real — o fake responde com os mesmos formatos de payload (Pagar.me-compatível) e emite o webhook por dentro. **Promessa pública "Pix em 15 min" mantida como simulação**: fake confirma em ~30s, produto mostra "Pix enviado", banner global em homolog (STORY-075) deixa explícito que é simulação. Quando Pagar.me real entrar na próxima wave, esta estória **não muda**.

## Contexto

Turno em `finalizado` (STORY-064). Esta estória **consome o evento `TurnoFinalizado`** e dispara: (a) `capturar` via ACL de pagamento (idempotente — STORY-056), (b) `transferirPix` para a chave Pix do profissional, (c) registra `pix_enviado` no audit log; em caso de falha de Pix: alerta destacado na fila operacional do admin (PDR-010 — **uma tentativa, sem retry automático**).

Esta é a estória que **demonstra o ciclo financeiro do turno fim a fim** em homolog. A promessa pública "Pix em ≤ 15 min" é exercida como **simulação** pelo fake (confirma em ~30s); o banner global em homolog (STORY-075) garante que ninguém confunda com pagamento real. Pagar.me real entra na próxima wave atrás da mesma ACL — esta estória não muda.

- Épico: `epics/EPIC-003-aceite-pin-e-pix/epic.md`
- Documentos: `domain/pagamento.md` (ciclo completo), PDR-004, PDR-010, **PDR-017 (pagamento via fake)**, ADR-005, ADR-016.

## O quê

Listener `TurnoFinalizadoListener` consome o evento, executa `capturar` + `transferirPix` via ACL com idempotência. Sucesso: emite `PagamentoCapturado` + `PixEnviado` (consumido por STORY-067 notificação "Pix enviado"). Falha de Pix: emite `PixFalhou` → fila operacional do admin destaca o turno com badge "Pix falhou — tratamento manual" + dados do erro retornado pelo gateway (formato Pagar.me-compatível, emitido pelo fake configurado para esse cenário).

## Por quê

Sem captura, o contratante não paga e o profissional não recebe. Sem Pix em ≤ 15 min (mesmo como simulação no MVP), a promessa pública do Turni não fica demonstrada. Sem alerta em falha, a operação fica cega — e o fake configurável é exatamente o que torna o teste do caminho de falha **determinístico** (sem depender da variabilidade externa do sandbox real).

## Critérios de aceite

- [ ] **CA-1:** Listener `TurnoFinalizadoListener` consome o evento da STORY-064 e executa `capturar(turno_id)` via ACL de pagamento com chave de idempotência `captura:{turno_id}`. Em job na fila `database` (ADR-002 — worker assíncrono).
- [ ] **CA-2:** Sucesso da captura: emite `PagamentoCapturado` com `charge_id` retornado pelo gateway (formato Pagar.me-compatível — fake mantém o contrato), valor capturado, timestamp; audit log captura `pagamento.capturado`.
- [ ] **CA-3:** Em sequência, executa `transferirPix(turno_id, valor)` para a chave Pix do profissional (lida do perfil — EPIC-001). Idempotência `pix:{turno_id}`.
- [ ] **CA-4:** Sucesso do Pix: emite `PixEnviado` com `transferencia_id` retornado pelo gateway, valor, timestamp; audit log captura `pix.enviado`. Detalhe do turno mostra "Pix enviado em HH:MM" no card de valor (visível ao profissional).
- [ ] **CA-5:** Falha de Pix (PDR-010 — **uma tentativa**): emite `PixFalhou` com motivo retornado pelo gateway, timestamp; audit log `pix.falhou`. Fila operacional do admin destaca: badge vermelho + microcopy "Pix falhou — tratamento manual" + valor + chave Pix do profissional + razão. **Cenário exercitado em homolog via configuração do fake** (`PAGAMENTO_FAKE_FORCE_PIX_FAILURE=true` ou similar — agente decide nome) para validar o caminho determinísticamente.
- [ ] **CA-6:** Webhook entrante (STORY-056) é a **fonte de verdade** da confirmação do gateway — listener inicial dispara a captura/Pix, mas o estado final do pagamento vem do webhook (assíncrono). Se webhook reportar falha após sucesso aparente, alerta é atualizado. **No MVP, o webhook é emitido pelo próprio fake** (com HMAC assinado pelo mesmo segredo) — contrato mantido para troca futura por Pagar.me real.
- [ ] **CA-7:** Métrica primária verificada em CI: em 20 turnos seedados percorrendo o ciclo completo, **100%** completam `confirmado → finalizado → Pix enviado` com o fake em modo `success` (PDR-017 — fake confirma em ~30s ou conforme SLA configurado). Resultado anexado à estória. **Métrica de promessa pública "Pix em ≤ 15 min"** é demonstrada como simulação: SLA do fake é configurável (default ~30s, máximo 15min para fins de teste de promessa); em 20 turnos seedados com SLA 15min, 100% confirmam dentro da janela. Resultado anexado.
- [ ] **CA-8:** Fila operacional do admin tem aba "Pix com falha" — lista paginada de turnos com `pix.falhou`, ordenado por timestamp desc; admin pode marcar "Resolvido manualmente" com nota (audit log). **Cenário exercitado em homolog** com fake configurado para falhar.
- [ ] **CA-9:** Em cancelamento (STORY-066) ou caminho onde turno não chega a `finalizado`, captura **não** é disparada (pré-autorização é liberada em vez disso).
- [ ] **CA-10:** Cobertura ≥ 98% no núcleo (listener + parsing de webhook + lógica de fallback do alerta); ≥ 80% no resto.

## Fora de escopo

- Retry automático de Pix (PDR-010 — fora MVP).
- Captura parcial (`finalizado_ajustado` — EPIC-005).
- Comunicação automatizada ao profissional em falha (PDR-010 — manual).
- UI fina da aba "Pix com falha" do admin — fila padrão da operação serve; melhoria é wishlist.

## Padrões de qualidade

≥ 80% / ≥ 98% no núcleo. Métrica primária 95% em ≤ 15 min com 20 turnos seedados. Log JSON em todas as operações financeiras (request_id propagado).

## Dependências

- **Bloqueada por:** STORY-064 (evento `TurnoFinalizado`), STORY-056 (ACL de pagamento + fake).
- **Bloqueia:** STORY-068 (validador verifica métrica primária — Pix simulado dentro da janela de promessa).
- **Pré-requisitos:** fake genérico (STORY-056) operante em homolog; chave Pix do profissional registrada (EPIC-001). ~~Pagar.me sandbox~~ **REMOVIDO por PDR-017**.

## Decisões já tomadas

ADR-005 / ADR-008 / ADR-015 / ADR-016 / **ADR-018 (UUIDv7 em PKs — `external_reference` carrega `turno_id` UUID string; chave de idempotência da captura/Pix usa UUID; eventos `PagamentoCapturado`/`PixEnviado`/`PixFalhou` referenciam entidades por UUID)** / **PDR-017 (gateway é fake genérico no MVP; contrato Pagar.me-compatível; SLA de Pix configurável no fake)** — PDR-004 / PDR-010.

## Liberdade técnica

Decide: tamanho/cor exatos do badge, formato da nota de "resolvido manualmente", estrutura interna do listener.

NÃO decide: 1 tentativa de Pix (PDR-010); que webhook é fonte de verdade (ADR-005/016); imutabilidade do audit log (herdado).

## Definição de Pronto

- [ ] CAs marcados; deploy verificado.
- [ ] Alexandro testa em homolog (1 turno completo: captura + Pix visíveis no painel sandbox Pagar.me).
- [ ] 20 turnos seedados com ≥ 95% em ≤ 15 min.
- [ ] `index.json` atualizado.
- [ ] "Notas do agente" preenchida.

## Protocolo

`docs/skills/po/references/agent-task-format.md`.

## Notas do agente

### Plano inicial (2026-06-06, antes de codar)

**Documentos lidos:** estória inteira; PDR-017/PDR-010/PDR-004 (via estória + pagamento.md);
ADR-016 + `integrations/pagarme/contract.md`; `domain/pagamento.md`; STORY-056 (notas completas
— fake, idempotência, webhook, achado do fake stateless); STORY-064 (evento `TurnoFinalizado`);
SCREEN-STORY-065 (spec aprovado 2026-06-06); código existente: `GatewayPagamento`,
`OperacaoIdempotente`, `PagarmeGateway`, `ProcessarWebhookPagarmeJob`, `PreAutorizarTurnoJob`
(template), eventos `Pagamento/*`, `TurnoDetalheController` (whitelist da timeline JÁ tem
`pagamento.capturado`/`pix.enviado`), `pagarme-mock/index.php`, `ProfissionalProfile`
(`chave_pix_encrypted`), shell do admin + FilaAprovacao.

**Entendimento consolidado:** a 056 deixou pronta a ACL (capturar/transferirPix), a
idempotência e o pipeline de webhook (fake → HMAC → `ProcessarWebhookPagarmeJob` → eventos de
domínio `CapturaConfirmada`/`PixEnviado`/`PixFalhou`). A 065 liga as pontas: (1) consumir
`TurnoFinalizado` e disparar captura+Pix em job; (2) materializar os webhooks em audit log
(fonte de verdade — CA-6) e na fila de falhas do admin; (3) expor o status do Pix ao
profissional no detalhe; (4) tornar o fake configurável (SLA + falha determinística).

**Plano:**
1. `TurnoFinalizadoListener` (thin) → `CapturarEPagarTurnoJob` (fila database): guard
   estado `finalizado` (CA-9) → `capturar` idempotente → audit `pagamento.capturado` +
   evento `PagamentoCapturado` (novo, com charge_id/valor/timestamp — CA-2) → em sequência
   `transferirPix` (chave do perfil; PDR-010 1 tentativa).
2. Webhook (CA-6): `HandlePixEnviado` → audit `pix.enviado` (é o que liga timeline + card —
   o timestamp do "Pix enviado em HH:MM" é o do webhook, não o da resposta síncrona);
   `HandlePixFalhou` → audit `pix.falhou` + linha em `pix_falhas` (alerta admin; cobre
   também falha reportada após sucesso aparente).
3. Tabela `pix_falhas` (api é dono — ownership do banco): UUIDv7 PK, `turno_id` FK,
   razão (código+mensagem do gateway), `falhou_em`, resolução (`resolvido_em/por/nota`).
4. Fake: `PAGARME_MOCK_PIX_RESULTADO=sucesso|falha` + `PAGARME_MOCK_PIX_SLA_SEGUNDOS`
   (default 0; atraso sem bloquear a resposta). contract.md atualizado junto.
5. Detalhe (CA-4): payload `pix { status, enviado_em }` p/ profissional em `finalizado`
   (decisão SCREEN-065 §A.4: `pix_falhou` chega como `a_caminho`).
6. WebApp: linha no card de valor + polling vivo em `finalizado` enquanto `a_caminho`
   (ajuste consciente sobre a 064 §4.11 "polling morto" — sem isso o CA-4 não atualiza
   sem refresh; registrado também no histórico da SCREEN-064 na implementação).
7. Admin: Livewire `PixFalhas` (rota `/pix-falhas`, AdminOnly) conforme SCREEN-065 §B.
8. E2E + métrica CA-7 + fechamento.

**Dúvidas/ambiguidade:** nomenclatura do evento síncrono de captura — a estória pede
`PagamentoCapturado`; a 056 já criou `CapturaConfirmada` (webhook). Decisão local: manter
os DOIS com papéis distintos (síncrono = iniciativa; webhook = confirmação/fonte de
verdade), documentado nos docblocks. Não é ambiguidade de produto — não bloqueia.

**Mapeamento CA → testes planejados (api Pest, webapp widget/integration, admin Pest):**
- CA-1: `test_listener_turno_finalizado_enfileira_job` (feliz);
  `test_job_nao_captura_turno_nao_finalizado` (CA-9/inválido);
  `test_job_idempotente_em_redispatch_nao_duplica_captura` (borda, clique-duplo);
  `test_job_retenta_em_gateway_indisponivel` (exceção).
- CA-2: `test_captura_sucesso_emite_pagamento_capturado_e_audita` (feliz);
  `test_captura_falha_fatal_audita_sem_pix` (exceção).
- CA-3: `test_pix_disparado_em_sequencia_com_chave_do_perfil` (feliz);
  `test_pix_falha_sem_chave_pix_no_perfil_vira_alerta` (inválido).
- CA-4: `test_webhook_pix_enviado_audita_pix_enviado` + payload `pix{}` no detalhe
  (3 testes: a_caminho/enviado/contratante-sem-pix) + widget tests da linha no card.
- CA-5: `test_webhook_pix_falhou_cria_caso_na_fila_com_razao` (feliz);
  `test_pix_falhou_apos_sucesso_aparente_atualiza_alerta` (CA-6/borda);
  fake: teste de container coberto pelo E2E local (`CicloPagamentoLocalTest` estendido).
- CA-6: `test_audit_pix_enviado_vem_do_webhook_nao_da_resposta_sincrona`.
- CA-8: admin Pest: lista desc, paginação, resolver com nota (feliz), nota vazia
  (inválido), race entre admins (exceção), fila vazia (borda) + E2E Playwright.
- CA-7: métrica 20 turnos (teste dedicado, resultado anexado aqui).
- CA-9: coberto no guard do job + teste de cancelamento não dispara captura.
- CA-10: gate de cobertura ≥98% núcleo / ≥80% geral no `make test-api`.

### Decisões tomadas
- **Dois eventos de captura com papéis distintos:** `PagamentoCapturado` (novo — desfecho
  síncrono da iniciativa do job, com charge_id/valor/timestamp, CA-2) ≠ `CapturaConfirmada`
  (056 — webhook, fonte de verdade assíncrona, CA-6). Documentado nos docblocks.
- **`pix.enviado` NASCE do webhook, nunca da resposta síncrona** (CA-6): o timestamp do
  "Pix enviado em HH:MM" é o da confirmação do gateway. A resposta síncrona de `/transfers`
  passou a `processing` no contrato (fake atualizado junto — regra do projeto).
- **Snapshot operacional em `pix_falhas`** (aprovado por Alexandro em chat): o caso carrega
  profissional/função/estabelecimento/valor/chave do INSTANTE da falha → o Backoffice lê
  uma tabela, sem replicar turnos/vagas nos testes do admin; registro arquivístico.
- **Chave Pix cifrada com segredo dedicado compartilhado api+admin (IDR-028)**: as
  APP_KEYs são distintas (correto) e o Backoffice precisa LER a chave (CA-5). Gap da
  ADR-009 5A (chave dedicada nunca implementada em EPIC-001) apontado ao Arquiteto no IDR.
- **Falha de Pix para o profissional = "Pix a caminho"** (SCREEN-065 §A.4, confirmado por
  Alexandro): PDR-010 define comunicação manual; o payload nem distingue.
- **Polling silencioso do detalhe em `finalizado`** enquanto `pix.status == a_caminho`
  (10s; morre na confirmação) — ajuste consciente sobre a 064 §4.11, registrado nos
  históricos das SCREEN-064/065. Refresh sem skeleton (erro de tick mantém a verdade
  anterior).
- **Resolução humana é final**: `PixEnviado` tardio NÃO fecha caso aberto; `PixFalhou`
  tardio NÃO reabre caso resolvido. Nota obrigatória (CA-8 — audit conta a história).
- **Fake:** `PAGARME_MOCK_PIX_RESULTADO=sucesso|falha` + `PAGARME_MOCK_PIX_SLA_SEGUNDOS`
  (CA-5: nome decidido aqui). SLA via resposta-antecipada + sleep; em Cloud Run exige
  `cpu_idle=false` (senão o throttle congela o webhook atrasado).

### Descobertas
- **Gap ADR-009 5A:** a "chave de criptografia distinta da APP_KEY em Secret Manager"
  decidida na ADR nunca foi implementada — EPIC-001 usou o cast `encrypted` nativo
  (APP_KEY). Pendência formal ao Arquiteto registrada no IDR-028.
- **Turnos do seed não têm pré-autorização** (TurnosSeeder cria o turno direto, pulando a
  058) → a captura falhava ("não tem pré-autorização com charge_id para correlacionar") e
  o E2E do ciclo nunca via o Pix. Fix: pré-auth SINTÉTICA no seeder (sem rede; webhook de
  captura degrada sem external_reference — inócuo; Pix sai normal).
- Turnos `finalizado` ANTIGOS (consumidos antes da 065 existir) ficam "Pix a caminho" para
  sempre no detalhe — sem evento, sem job, honesto e esperado; não confundir com bug.
- Worker `queue:work` precisa de restart para enxergar classe de Job nova (gotcha da 056,
  reconfirmado).
- **(rc.77 → rc.78)** O job de migração de homolog (`turni-migrate-homolog`) é deployado
  pelo **release.yml** com secrets PRÓPRIOS — Terraform não o cobre. O seeder rodou sem
  `PIX_FALHA_CHAVE_KEY`, cifrou a chave do caso com o default de dev e o admin (com o
  secret real) dava **500 na fila inteira** (DecryptException no render). Fix duplo:
  secret no release.yml + casts espelhados degradam linha indecifrável para "chave não
  cadastrada" com warning `pix_falha.chave_indecifravel` (uma linha ruim não cega a
  operação). Regra geral: **env nova de runtime tem 4 pontos de wiring** — compose (dev),
  Terraform (api/worker/admin) E release.yml (migrate job) E .env.example.

### Bloqueios encontrados
- Nenhum bloqueante. A decisão da chave compartilhada (acima) foi escalada a Alexandro em
  chat e resolvida na hora (sem `blocked`).

### IDRs criados
- **IDR-028** — chave Pix do snapshot de `pix_falhas` cifrada com segredo dedicado
  compartilhado api+admin (`accepted` — aprovado em chat).

### Cobertura final
- Suítes completas locais (CA-10): **api 916 verdes** (gate `--min=80` EXIT 0);
  **admin 114 verdes**; **webapp 516 verdes**. Núcleo da 065: `CapturarEPagarTurnoJob`
  **100%**, `HandlePixEnviado`/`HandlePixFalhou`/`TurnoFinalizadoListener` **100%**,
  `ChavePixCompartilhada` **100%**, `PixFalha` 96,55% linhas (única linha descoberta:
  a relação declarativa `turno()` — Eloquent puro, sem lógica; justificada aqui).
- E2E (browser real): webapp integration_test **All tests passed** — ciclo
  `confirmado → finalizado → Pix enviado` ponta a ponta contra api+worker+fake reais
  (fase 4 nova: linha do card troca por polling silencioso + trilha); smoke Playwright
  verde; admin Playwright **14/14** (inclui os 2 cenários novos da pix-falhas).
- Flake observado e diagnosticado: sincronia bilateral do cronômetro (063) estourou 2s
  numa execução COM a máquina sob carga (3 processos paralelos meus); verde nas execuções
  em repouso. Não relacionado à 065; registrado para ciência do PO (sem skip).
- CA-7 (métrica anexada): **20/20 turnos com ciclo completo** (pix.enviado + 3 operações
  concluídas) e **20/20 dentro da janela de 15 min** — pipeline max 23ms / média 9ms no CI
  (simulação PDR-017; SLA real do fake em homolog: ~30s via env).

### Mapeamento CA → teste (nominal)
- CA-1: `CA-1: evento TurnoFinalizado enfileira CapturarEPagarTurnoJob na fila database`
  + `CA-1: job roda na fila database (ADR-002)` (CapturarEPagarTurnoJobTest).
- CA-2: `CA-2/CA-3: sucesso → captura + Pix em sequência, audit pagamento.capturado +
  evento PagamentoCapturado`; falha: `captura falha fatal (CapturaFalhou) → …`.
- CA-3: idem CA-2 (valor integral + chave do perfil) + `CA-3: perfil SEM chave Pix → …`.
- CA-4: `CA-4/CA-6: webhook PixEnviado grava audit pix.enviado…` (WebhookPixHandlersTest);
  payload: 5 testes `CA-4 (065): …` (TurnoDetalheTest); UI: 8 widget tests
  (turno_detalhe_pix_test.dart); E2E fase 4 do ciclo (checkout_test.dart).
- CA-5: `CA-5: webhook PixFalhou cria caso na fila com a razão do gateway…`,
  `PDR-010: Pix falha fatal…`, snapshot (2 testes); admin: 14 testes (PixFalhasTest) +
  E2E Playwright (pix-falhas.spec.ts); fake `falha` verificado em container real.
- CA-6: `CA-6: a resposta síncrona do Pix NÃO grava pix.enviado…`, `CA-6: PixFalhou após
  pix.enviado (sucesso aparente)…`, `CA-6: PixEnviado redelivery…`.
- CA-7: `CA-7: 20 turnos seedados — 100% completam…` (MetricaPixPromessaTest).
- CA-8: PixFalhasTest (lista desc/resolução/nota/race/vazios/paginação/contador) +
  pix-falhas.spec.ts.
- CA-9: `CA-9: turno fora de finalizado NÃO dispara captura` (3 datasets).
- CA-10: gate `--min=80` da suíte + cobertura do módulo (fechamento).

### Links de evidência
- PR: n/a (workflow Turni — commits TDD direto na `main`; design `2ecf26a` → ciclo
  red/green por CA até `bba8961`)
- Pipeline: release.yml run **27064489299** (tag `v0.1.0-rc.77`) — build api/admin/
  pagarme-mock/webapp + migrate&seed + 4 deploys + smoke pós-deploy, tudo verde
- Deploy de homologação: **rc.78** (rc.77 + fix do 500 da fila — ver Descobertas) —
  migração `create_pix_falhas_table` DONE; `PixFalhaSeeder` com caso aberto na fila;
  `TurnosSeeder` recriou o par de checkout (chave Pix + pré-auth sintética); fake com
  `PIX_RESULTADO=sucesso`, `SLA_SEGUNDOS=30`, `cpu-throttling=false`; infra IDR-028
  aplicada por Terraform; **/pix-falhas verificada em browser real contra homolog**
  (caso visível com chave decifrada, badge, valor, razão, contador)
