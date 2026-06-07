---
story_id: STORY-068
slug: validacao-final-epic-003
title: Validação final do EPIC-003 — Aceite, PIN bilateral e Pix
epic_id: EPIC-003
sprint_id: SPRINT-2026-W28
type: validation
target_role: validador
requires_design: false
design_screen_id: null
status: in_review
owner_agent: claude-opus-4-8-validador-2026-06-07
created_at: 2026-06-03
updated_at: 2026-06-07
estimated_session_size: M
produces_idr: null
---

# STORY-068 — Validação final do EPIC-003

> **Para o validador:** lembrete da STORY-011/025/054 — você é independente. Seu papel é **constatar** (evidência + veredito), **não** planejar correções nem sugerir próximos passos. Aprendizado herdado: o 1º relatório da STORY-011 que extrapolou foi corrigido e a 2ª rodada se ateve a evidência + veredito. Use o checklist em `epics/EPIC-003-aceite-pin-e-pix/validation/checklist.md`, rode os testes, observe em homolog, escreva `validation/report.md`. Veredito possível: `approved`, `approved_with_pending` (com fails não-bloqueantes), `rejected`. PO decide o que fazer com o veredito.

## Contexto

EPIC-003 entrega o **ciclo do turno** ponta a ponta em homolog com **pagamento via fake genérico (PDR-017)** atrás de ACL provider-agnóstica: aceite + AceiteEletronico imutável + pré-autorização → PIN check-in + geofencing → cronômetro bilateral vivo → PIN check-out → captura + Pix simulado dentro do SLA configurado (promessa pública "Pix em ≤ 15 min" demonstrada como simulação). Cancelamento + `no_show_pro` liberam pré-autorização. Habitualidade (PDR-002) aplicada nos 4 cenários. Notificações in-app + e-mail nos 8 eventos. **Banner global em homolog "Ambiente de teste — pagamentos simulados" (STORY-075)** deixa explícito que pagamento não é real.

Esta estória é o portão final antes de fechar o épico e abrir EPIC-004 (Avaliação recíproca).

- Épico: `epics/EPIC-003-aceite-pin-e-pix/epic.md`
- Checklist: `epics/EPIC-003-aceite-pin-e-pix/validation/checklist.md`

## O quê

Executar o checklist do EPIC-003 e produzir `validation/report.md` com veredito factual + evidências (logs, screenshots de homolog, comandos executados, resultados de testes).

## Por quê

Sem validação independente, não há prova confiável de que o épico mais arriscado da onda fechou. Aprendizado W23/W25/W27: validador descobre o que o autor não vê.

## Critérios de aceite

- [x] **CA-1:** Checklist completo de `validation/checklist.md` percorrido — cada item marcado `[x]` com link para evidência ou `[ ]` com motivo.
- [x] **CA-2:** Suíte completa de testes rodada em CI: api ≥ 80% / ≥ 98% no núcleo (modelo Turno, máquina de estados, ACL de pagamento, PIN, geofencing, habitualidade), admin ≥ 80%, webapp ≥ 80%.
- [x] **CA-3:** Métrica primária do EPIC-003 observada em homolog: **100%** dos turnos seedados completam ciclo `confirmado → finalizado → Pix enviado` com fake em modo `success` (PDR-017). Resultado documentado.
- [x] **CA-4:** SLA Pix observado como simulação: **100%** dos Pix simulados confirmam dentro do SLA configurado do fake (default ~30s; teste de promessa pública com SLA configurado para 15min também passa 100%). Resultado documentado com timestamps reais. **NÃO** verificar contra Pagar.me sandbox (PDR-017 removeu).
- [x] **CA-5:** Validação de PIN ≤ 500ms p95 observada em log JSON estruturado de homolog. Resultado documentado.
- [x] **CA-6:** Cronômetro bilateral sincronizado em ≤ 2s observado em 2 navegadores abertos no mesmo turno. Screenshot ou vídeo anexado.
- [x] **CA-7:** Habitualidade nos 4 cenários PDR-002 testada em homolog: PF 1ª/2ª libera; PF 3ª bloqueia (mensagem clara em ambos os lados); PJ 3ª com override registra cláusula no AceiteEletronico; transição de semana reseta. Cada um com evidência.
- [x] **CA-8:** Imutabilidade do AceiteEletronico do turno verificada via tentativa de `UPDATE`/`DELETE` direto no Postgres (deve falhar). Resultado documentado.
- [x] **CA-9:** Imutabilidade do audit log verificada (espelha CA da STORY-054).
- [x] **CA-10:** RBAC vivo nas duas interfaces verificado: cruzados retornam 403 fail-secure. Cenários: profissional A não vê turno do profissional B; contratante X não vê turno do contratante Y; profissional não chama endpoint de contratante e vice-versa.
- [x] **CA-11:** LGPD básica verificada (espelha CA de EPIC-001): consentimento registrado, dados sensíveis criptografados em repouso (ADR-009).
- [x] **CA-12:** Observabilidade verificada — log JSON em todas as operações financeiras com `request_id` propagado; log-based metrics de captura/Pix funcionando no Cloud Monitoring.
- [x] **CA-13:** Acessibilidade básica das telas novas — contraste AAA no PIN (≥ 64pt + cor de alta legibilidade), navegação por teclado nas telas críticas, microcopy clara.
- [x] **CA-14:** Veredito emitido em `validation/report.md` (`approved` / `approved_with_pending` / `rejected`) com fails categorizados em bloqueantes vs não-bloqueantes (`F-NB-N`).

## Fora de escopo

- Planejar correções (papel do PO).
- Sugerir próximos passos (papel do PO).
- Testar `em_disputa` (EPIC-005).
- Testar `finalizado_ajustado` (EPIC-005).
- Testar avaliação recíproca (EPIC-004).

## Padrões de qualidade

`docs/skills/validador/`. Veredito é factual: descreve o que **observou**, não o que **deveria** acontecer. PO interpreta.

## Dependências

- **Bloqueada por:** STORY-055..067 — **todas** em `done` e deployadas em homolog.
- **Bloqueia:** abertura do EPIC-004.
- **Pré-requisitos:** ambiente homolog operante com seed; fake genérico (STORY-056) deployado em homolog; banner global da STORY-075 visível. ~~Credenciais Pagar.me sandbox~~ **REMOVIDO por PDR-017**.

## Decisões já tomadas

Todas as ADRs/PDRs/IDRs vigentes — validador respeita, não reabre. **Em particular ADR-018 (UUIDv7 em PKs) — checklist deve verificar que PKs/FKs do EPIC-003 (Turno, AceiteEletronicoTurno, pagamento_operacoes) são UUID na base de homolog; tentativa de inserir `bigint` no `id` falha.**

## Liberdade técnica

Decide: como sequenciar a execução do checklist, formato exato do relatório (dentro do template).

NÃO decide: que está aprovado (veredito é factual, não negociado); planejar correções (papel do PO).

## Definição de Pronto

- [x] Checklist completo percorrido.
- [x] `validation/report.md` escrito.
- [x] `index.json` atualizado com veredito + path do report.
- [x] "Notas do agente" preenchida (na própria estória).
- [x] **NÃO** marca o EPIC-003 como `done` — o PO faz isso depois de ler o report.

## Protocolo

`docs/skills/po/references/agent-task-format.md` + `docs/skills/validador/` (carrega skill do validador).

## Notas do agente

### 2026-06-07 — Início da validação
- Épico: EPIC-003 (in_review — transição registrada pelo PO em chat ao autorizar o início).
- Documentos lidos: `epic.md`, `validation/checklist.md` (18 blocos), STORY-055/056(+056-B abandonada)/057/058/059/060/061/062/063/064/065/066/067/075 completas (CAs + Notas do agente), skill do validador + 4 references.
- Entendimento consolidado: o épico promete o ciclo do turno ponta a ponta em homolog (aceite → PIN check-in + geofencing → cronômetro bilateral → PIN check-out → captura + Pix simulado via fake genérico PDR-017), com habitualidade PDR-002, cancelamento/no-show, 8 notificações e banner global de homolog. Entrega visível: fluxo completo demonstrável em homolog com `pagamento_operacoes` + audit log. Métrica de sucesso: 100% dos turnos seedados completam `confirmado → finalizado → Pix enviado` (fake `success`), Pix dentro do SLA configurado, PIN ≤ 500ms p95, cronômetro ≤ 2s.
- Plano de execução (liberdade técnica): passe 1 = blocos automatizados (1, 2, 3, 11, 12, 13); passe 2 = observação em homolog (4, 5, 6, 7, 8, 9, 10, 15); depois 14/16/17 e veredito (18).
- Avisos herdados das estórias (a verificar, não pré-julgar): resíduo de 3 casos "chave Pix ausente" em `pix_falhas` de homolog (STORY-067, anotado para o validador); 2 specs Playwright do admin flaky pré-existentes (STORY-075); `schedule:run` automático em homolog é STORY-073 (fora do EPIC-003); cota Resend limita E2E de notificação a 1 run/dia.

### Decisões tomadas
- **Sequenciamento** (liberdade técnica): passe 1 = blocos automatizados (suítes locais + CI/scan via gh); passe 2 = homolog (sondas one-off read-only no Postgres via Cloud Run Job, Cloud Logging, sessões reais via API, screenshots Playwright em 2 contextos de browser).
- **Métrica primária (Bloco 5.1)**: PO decidiu em chat (2026-06-07) aceitar a evidência existente (10/10 ciclos reais em homolog + 20/20 no CI) em vez de seedar 20 ciclos novos — cota Resend (129 e-mails já enviados hoje; 20 ciclos ≈ +120).
- **Flake do cronômetro**: medido com 5 execuções completas do gate (1 falha) e classificado **bloqueante** pela regra objetiva de `verdict-criteria.md` ("flaky introduzido pelo épico"); fatos mitigantes registrados no report (funcionalidade verificada viva com Δ=1s; teste mede SLA de timing em build debug).
- **Fluxos mutantes de homolog não exercitados por mim** (gerar/validar PIN, resolver caso na fila): cobertos por testes + verificações do PO registradas; evitei consumir seeds, disparar e-mails e alterar estado.
- **Playwright admin re-medido com metodologia correta** (seed antes de cada run): 4/4 verde — a intermitência relatada na 075 não se reproduziu; sem reseed os specs falham por estado consumido (não é flake).

### Descobertas
- **Log-based metrics financeiras não existem** (GCP, Terraform e docs/operacao) apesar de ADR-016 e CA-9 da STORY-056 (`[x]`) afirmarem que estavam definidas → F-NB-1.
- **ADR-008 §f (propagação de `request_id`) nunca foi implementado no app `api`** — só o `admin` tem `RequestLogMiddleware`; eventos financeiros do worker sem request_id → F-NB-2.
- `runbook-homolog.md` sem as 3 seções exigidas pelo checklist (fake/cronômetro/Pix com falha) → F-NB-3.
- IDR-028 não indexado; STORY-056-B `abandoned` no arquivo × `ready` no index → F-NB-4.
- `pin_checkout_service`/`validar_checkout_service` (webapp, STORY-064) com 5,7%/6,2% de cobertura unitária (fakes estendem os services; parsing real sem teste) → F-NB-5.
- PIN p95 homolog 509ms (n=30) e SLA e-mail p95 61,6s (n=109) — marginais acima dos alvos → F-NB-6/7.
- `ADMIN_SEED_PASSWORD` não está wirada em homolog → seeds usam o default do código; hostnames `api.homolog`/`admin.homolog` do runbook não resolvem (serviços vivem nos URLs `*.run.app`).
- 1ª execução local da suíte api retornou exit 1 com diagnóstico perdido (erro meu de captura); 2 re-execuções verdes.

### Bloqueios encontrados
- Nenhum operacional. Pré-condição "épico in_review" resolvida pelo PO em chat no início; alerta de orçamento GCP (15.3) não verificável com meus acessos (registrado como limitação).

### IDRs criados
- Nenhum (validação não produz IDR).

### Cobertura final
- Unitários: api 982 verdes / 94,2% (gate ≥80 EXIT=0); admin 127 verdes / 94,8%; webapp 549 verdes / 86,0% lcov (núcleos críticos 100%).
- E2E: integration_test 4/5 execuções verdes (1 falha — F-B-1); ciclo completo `confirmado→finalizado→Pix` verde 5/5; Playwright admin 4/4 com seed; smoke pós-deploy rc.85 verde.

### Links de evidência
- PR: n/a (workflow do projeto).
- Pipeline: release rc.85 run 27092843953 (12 jobs verdes); CI main + gitleaks/Trivy verdes nos 5 últimos runs.
- Deploy de homologação: rc.85 verificado vivo (cronômetro Δ=1s, banner 2 temas, RBAC, habitualidade 422, fila do admin) — screenshots em `validation/evidence/`.
- Report: `epics/EPIC-003-aceite-pin-e-pix/validation/report.md` — **veredito: REJECTED** (1 F-B + 7 F-NB).
