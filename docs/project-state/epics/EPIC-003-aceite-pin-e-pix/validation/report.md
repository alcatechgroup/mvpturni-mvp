---
epic_id: EPIC-003
type: validation-report
validated_at: 2026-06-07
validated_by: validador (claude-opus-4-8-validador-2026-06-07)
verdict: rejected
checklist_source: epics/EPIC-003-aceite-pin-e-pix/validation/checklist.md
---

# Relatório de Validação — EPIC-003 (Aceite, PIN bilateral e Pix via fake genérico — PDR-017)

## TL;DR

> **Veredito**: REJECTED.
> **Contagem**: 58 passes, 9 passes com ressalva, 8 fails (1 bloqueante, 7 não-bloqueantes), 3 n/a justificados.
> **Bloqueante (resumo factual)**: o teste E2E de sincronia bilateral do cronômetro (`cronometro_test.dart`, introduzido pela STORY-063) é intermitente — falhou 1 de 5 execuções completas do gate nesta validação (display 2s atrás da âncora do servidor; limite 1s/lado), com 1 ocorrência anterior documentada na STORY-065. Regra objetiva de `verdict-criteria.md`: flaky introduzido pelo épico = bloqueante.
> **Importante**: a funcionalidade de produto correspondente (sincronia ≤ 2s) foi verificada **viva em homolog** com 2 navegadores e está dentro do alvo (Δ=1s em 2 amostras; screenshots anexados). O fail bloqueante é sobre a confiabilidade do gate de teste, não sobre a funcionalidade observada.

---

## Resumo executivo

O EPIC-003 promete o ciclo do turno ponta a ponta em homolog com pagamento via fake genérico (PDR-017): aceite com habitualidade (PDR-002) + AceiteEletronico imutável + pré-autorização → PIN check-in com geofencing (PDR-008) → cronômetro bilateral → PIN check-out → captura + Pix simulado, com cancelamento/no-show liberando a pré-autorização, 8 notificações e banner global de ambiente de teste (STORY-075).

O essencial está entregue e foi observado funcionando: suítes locais verdes no commit `c8f8f3c` (api **982 testes / 94,2%**, admin **127 / 94,8%**, webapp **549 / 86,0%**, núcleos críticos 100%), 14ª transição e triggers de máquina de estados barrando SQL cru **em homolog**, imutabilidade de `aceites_eletronicos_turno` e `audit_logs` provada por sonda direta no Postgres de homolog (REVOKE/trigger), PKs/FKs UUID (ADR-018) confirmadas na base de homolog, **10/10 ciclos reais em homolog completando `pix.enviado`** (Δ captura→Pix 54s–7min, todos ≪ 15 min) + **20/20 no CI**, habitualidade PF 3ª devolvendo 422 com a mensagem do PDR-002 **ao vivo em homolog**, RBAC cruzado fail-secure vivo (403/404/401), cronômetro bilateral com Δ=1s em 2 navegadores (screenshots), banner legível nos 2 temas no WebApp e no Backoffice, 8 tipos de notificação com 0 falhas de envio e fila vazia, e 27 `no_show_pro` transitados pelo cron real.

O veredito é REJECTED por um único fail bloqueante de classificação objetiva: o teste E2E de sincronia do cronômetro, novo neste épico, é intermitente (1/5 nas minhas execuções + 1 ocorrência documentada). Os 7 fails não-bloqueantes concentram-se em observabilidade financeira não-wirada (log-based metrics e `request_id` prometidos por ADR-016/ADR-008 §f), documentação (runbook, índice) e duas métricas marginais (PIN p95 509ms; SLA e-mail p95 61,6s).

---

## Checklist preenchido (blocos 1–18 do checklist do épico)

### Bloco 1 — Critérios de aceite das estórias

| Item | Status | Evidência |
|---|---|---|
| 1.1 — STORY-055..067 `done` no index.json | ✅ | index.json em `c8f8f3c`: 13 estórias `done` (+ STORY-075 `done`; STORY-056-B abandonada — ver F-NB-4 sobre divergência de índice) |
| 1.2 — Cada CA exercido por teste ou verificação manual | ✅ | Mapeamentos CA→teste nominais nas 14 estórias, cruzados com a suíte verde (A.1); spot-checks: HMAC 401, clique-duplo, 4 cenários PDR-002, 20-turnos, benchmarks p95 — todos presentes e verdes na execução local |
| 1.3 — Nenhuma estória `done` com CA `[ ]` | ✅ | Leitura integral das 14 estórias: todos os CAs `[x]`; única exceção `[~]` = CA-8 da STORY-056 removido por PDR-017 (justificado em prosa na estória) |

### Bloco 2 — Modelo + máquina de estados (STORY-055 / ADR-015)

| Item | Status | Evidência |
|---|---|---|
| 2.1 — Transições válidas aceitas; inválidas barradas | ✅ | 37 testes de transição verdes (13 da ADR-015 + 14ª `confirmado → no_show_pro` da STORY-066, documentada em `domain/turno.md`); sonda SQL cru em homolog: `confirmado → finalizado` → `ERROR: transição de turno inválida` (A.2) |
| 2.2 — AceiteEletronicoTurno imutável (UPDATE/DELETE falham) | ✅ | Local: trigger `prevent_aceite_turno_mutation` barrou UPDATE e DELETE; homolog: `SQLSTATE[42501] permission denied` (REVOKE — runtime sem privilégio). Saídas em A.2 |
| 2.3 — Aceite aponta TemplateVersao vigente; mudança posterior não altera | ✅ | `conteudo_renderizado` embutido + FK `template_versao_id`; homolog: 61 aceites referenciam 2 versões; teste de fidelidade SHA-256 (STORY-058 CA-8) verde |
| 2.4 — Índice de habitualidade existe e é usado | ✅ | `idx_turnos_habitualidade` presente; `EXPLAIN ANALYZE` com Index Only Scan, heap fetches 0, 0,078ms (tabela dev pequena exige `enable_seqscan=off` p/ demonstrar; `HabitualidadeIndexTest` guarda o plano com 20 linhas-lastro no CI) (A.3) |

### Bloco 3 — ACL de pagamento + fake genérico (STORY-056 / ADR-016)

| Item | Status | Evidência |
|---|---|---|
| 3.1 — Fake em container roda local sem internet | ✅ | 7 containers de pé; `CicloPagamentoLocalTest` com `Http::preventStrayRequests` verde; workflow agendado "Setup local test" (roda `make setup` em runner limpo) verde 3 dias seguidos (05–07/06) |
| 3.2 — ~~Contract test sandbox real~~ | 🚫 n/a | Removido por PDR-017; STORY-056-B abandonada (frontmatter `abandoned`, motivo registrado) |
| 3.3 — Idempotência: 2× `preAutorizar` = 1 pré-autorização | ✅ | Testes de clique-duplo verdes (suíte local); UNIQUE `(turno_id, tipo_operacao)` confirmado no schema de homolog; 47 `pre_autorizacao concluida` em homolog sem duplicatas |
| 3.4 — Webhook valida HMAC; inválida → 401 | ✅ | Testes "assinatura HMAC errada é rejeitada" e "webhook com assinatura inválida responde 401 e não enfileira" verdes na execução local |
| 3.5 — Modos `success`, `fail_capture`, `fail_pix`, `delay_pix` exercitados | ⚠️ | `sucesso`/`falha` (fail_pix) / `PAGARME_MOCK_PIX_SLA_SEGUNDOS` (delay) existem no container e são exercitados; **`fail_capture` não existe como modo do fake** — falha de captura é exercitada em teste só via `Http::fake` (`captura falha fatal (CapturaFalhou)` verde). Caminho de exceção do PDR-010 (Pix) é determinístico ✅ |

### Bloco 4 — Tempo real + geolocalização (STORY-057 / ADR-017)

| Item | Status | Evidência |
|---|---|---|
| 4.1 — PoC/cronômetro vivo em homolog, 2 navegadores | ✅ | Verificado vivo por mim em 2026-06-07: turno `ativo` `019e9979-…`, 2 contextos de browser, displays **04:45:19 × 04:45:18** (Δ=1s) e **04:45:34 × 04:45:33** 15s depois; âncora idêntica (`iniciado_em 12:07:00`) nos 2 papéis via API (A.4 + screenshots) |
| 4.2 — Haversine reusa `Support\Geo` (sem duplicação) | ✅ | `Geofencing` compõe `Haversine` da STORY-049 (código + 100% cobertura); nenhuma 2ª implementação encontrada |

### Bloco 5 — Caminho feliz ponta a ponta — métrica primária

| Item | Status | Evidência |
|---|---|---|
| 5.1 — 20 turnos seedados percorrendo o ciclo em homolog | ⚠️ | **N=10 em homolog** (ciclos reais 06-03→06-07, todos completando `pix.enviado`) + **20/20 determinístico no CI** (`MetricaPixPromessaTest`). Rodar 20 ciclos novos hoje estouraria a cota Resend (~120 e-mails; 129 já enviados hoje) — **PO decidiu em chat (2026-06-07) aceitar a evidência existente** (A.5) |
| 5.2 — ≥ 95% completam o ciclo | ✅ | Homolog: 10/10 dos ciclos executados pós-fix do seeder (100%); CI: 20/20. (3 `pix.falhou` históricos em homolog = resíduo documentado da STORY-067 — seeder sem chave Pix, corrigido) |
| 5.3 — ≥ 95% dos Pix em ≤ 15 min | ✅ | 10/10 ≤ 15 min — Δ captura→pix: 54–60s nos 8 ciclos recentes (SLA do fake 30s + tick 1min do worker); 7 min nos 2 ciclos de 06-03 (rc.68). Timestamps reais em A.5 |
| 5.4 — Validação de PIN ≤ 500ms p95 (log JSON homolog) | ❌ | **p95 = 509ms** (n=30, 7 dias, log JSON nginx `$request_time` full-request; p50 450ms, max 578ms). Benchmark de CI (app-level) ≤ 500ms verde. Ver F-NB-6 |
| 5.5 — Cronômetro bilateral ≤ 2s, 2 navegadores, screenshot | ✅ | Δ=1s em 2 amostras simultâneas (screenshots anexados em `evidence/`); ver também F-B-1 sobre a intermitência do TESTE que mede isso |

### Bloco 6 — Habitualidade (PDR-002) nos 4 cenários

| Item | Status | Evidência |
|---|---|---|
| 6.1 — PF 1ª alocação libera | ✅ | `HabitualidadeAceiteTest` (12 cenários) verde + 61 turnos criados em homolog ao longo da sprint via aprovação real |
| 6.2 — PF 2ª libera | ✅ | Idem (teste explícito verde) |
| 6.3 — PF 3ª bloqueia com mensagem clara | ✅ | **Exercitado vivo em homolog por mim (2026-06-07)**: POST aprovar no cenário Copeiro → `422 {"erro":"habitualidade_bloqueio","mensagem":"este profissional é PF e já tem 2 alocações nesta semana neste estabelecimento; bloqueado por PDR-002"}`; modal D2 coberto por E2E browser real (`aprovar_bloqueio_pf_test`) (A.6) |
| 6.4 — PJ 3ª com override registra cláusula no aceite | ✅ | Homolog: **9 aceites com `habitualidade_override=true`**; E2E `aprovar_override_pj_test` verde; teste do renderer (cláusula 10 condicional) verde |
| 6.5 — Transição de semana reseta (travel) | ✅ | Testes de borda seg/dom com `CarbonInterface::MONDAY` explícito + virada de semana verdes (backend; sem UI própria — regra de banco) |

### Bloco 7 — Geofencing (PDR-008)

| Item | Status | Evidência |
|---|---|---|
| 7.1 — Dentro do raio: flag true, distância < 100m, sem aviso | ⚠️ | Coberto por teste de feature + E2E local (geo concedida); **não observado em homolog** (nenhum check-in real a <100m do estabelecimento seed; snapshots de homolog: 6× `fora_do_raio` com distância, 9× `indisponivel`) |
| 7.2 — Fora do raio: flag false + distância + aviso, pode validar | ✅ | Homolog: 6 snapshots `ok:false` com `distancia_metros` (ex.: 71.799,4m — PoC STORY-057 verificada pelo PO); teste "fora do raio → ok:false e PIN gerado mesmo assim" verde; card de aviso coberto por E2E da 062 |
| 7.3 — Geo negada: flag false, razão, distância null, pode validar | ✅ | Homolog: 9 snapshots `{ok:false, razao:indisponivel, distancia_metros:null}` de E2E reais; razões `permissao_negada|timeout|indisponivel` testadas nos 3 caminhos de geo (E2E da 061) |

### Bloco 8 — Cancelamento + no_show (STORY-066 / PDR-007 / PDR-010)

| Item | Status | Evidência |
|---|---|---|
| 8.1 — Cancel. profissional → `cancelado_pro` + liberação | ✅ | Homolog: 1 `cancelado_pro`; 35 ops `liberacao concluida` + 35 audit `pagamento.liberado`; testes verdes (CancelarTurnoService 100%) |
| 8.2 — Cancel. contratante → `cancelado_emp` + liberação | ✅ | Homolog: 11 `cancelado_emp`; mesmos mecanismos; E2E dos 2 lados verde no gate local |
| 8.3 — `no_show_pro` automático após 2h via cron | ✅ | Homolog: **27 turnos em `no_show_pro`** transitados pelo cron real (`turni-scheduler` 1/min — STORY-073 `done`); teste `travel(2h+1m)` verde; X=2h em `config/turno.php` |
| 8.4 — Cancelar em estados não permitidos → 422 | ✅ | Testes `estado_invalido` (422) verdes para `ativo`/`aguardando_*`/`finalizado` |

### Bloco 9 — Captura + Pix + alerta de falha (STORY-065 / PDR-010)

| Item | Status | Evidência |
|---|---|---|
| 9.1 — Captura: `pagamento_operacoes` + audit + evento | ✅ | Homolog: 11 `captura concluida`, 13 audit `pagamento.capturado`, eventos `pagamento.operacao_concluida` no log JSON do worker (Cloud Logging, 2026-06-07) |
| 9.2 — Pix: ops + audit `pix.enviado` + card "Pix enviado em HH:MM" | ✅ | Homolog: 8 `pix concluida`, 10 audit `pix.enviado`; detalhe vivo (turno `019e90a6-9724`): `pix {status: enviado, enviado_em: 2026-06-03T15:18:18}` + timeline com os 9 eventos do ciclo (A.7) |
| 9.3 — Falha simulada → audit `pix.falhou` + fila destaca + sem retry | ✅ | Homolog: 3 audit `pix.falhou` + fila "Falhas de pagamento" com 6 casos abertos, badges e razões (screenshot); PDR-010 sem retry coberto por teste |
| 9.4 — Admin "Resolvido manualmente" com nota → audit | ✅ | `PixFalhasTest` (resolução, nota obrigatória, race entre admins) verde + Playwright `pix-falhas.spec` "(a) resolver com nota → Resolvidos" verde 4/4 com seed correto. Não exercitei resolução em homolog (mutação desnecessária; casos abertos preservados para o PO) |

### Bloco 10 — Notificações (STORY-067)

| Item | Status | Evidência |
|---|---|---|
| 10.1 — 8 templates ativos (categoria email) | ✅ | Homolog: 13 templates `email` com versão ativa (8 do turno + 5 herdados) — consulta direta (A.8) |
| 10.2 — 8 listeners → destinatário certo | ✅ | Núcleo da 067 100% de cobertura; homolog: envios reais nos 8 tipos (20+18+9+9+9+6+10+28), 0 falhas |
| 10.3 — SLA p95 ≤ 60s (última semana) | ❌ | E-mail criada→enviada no banco de homolog: **p95 = 61,6s** (n=109, max 81s). In-app é síncrono ao evento (≤ 60s trivialmente). STORY-067 mediu p95=60,0s (n=72) no fechamento. Ver F-NB-7 |
| 10.4 — E2E em homolog, 3 cenários, 0 flake em 3 runs | ✅ | Executado pela STORY-067 (3 runs × 3 cenários, 0 flake; asserção via in-app + banco — premissa Mailpit revista: homolog usa Resend). Não re-executei (cota Resend — máx 1 run/dia, padrão do projeto); banco confirma 33/33 + fila vazia |
| 10.5 — Idempotência: re-emitir evento não duplica | ✅ | Testes de idempotência (chave `{tipo}:{turno_id}` + variantes) verdes; UNIQUE por linha no banco |

### Bloco 11 — Cobertura de testes

| Item | Status | Evidência |
|---|---|---|
| 11.1 — api ≥ 80% geral / ≥ 98% núcleo | ✅ | **94,2% total; 982 testes (6.246 asserções); gate `--min=80` EXIT=0** (local, commit `c8f8f3c`); núcleos: TurnoStatus/PIN/ACL/Geofencing/Haversine/habitualidade/listeners 100% (declarado nas estórias e consistente com a saída da suíte) (A.1) |
| 11.2 — admin ≥ 80% | ✅ | **94,8% total; 127 testes** com `--coverage --min=80` EXIT=0 |
| 11.3 — webapp ≥ 80%; 98% regras críticas | ⚠️ | **86,0% global** (7186/8358 linhas, lcov); críticos: `cronometro_ancora` 100%, telas de PIN check-in 100%. Ressalva → ver F-NB-5: `pin_checkout_service` **5,7%**, `validar_checkout_service` **6,2%** (parsing HTTP sem teste unitário), `pin_checkout_screen` 78,1% |
| 11.4 — E2E ciclo completo em Chrome headless | ✅ | `checkout_test.dart` (ciclo `confirmado → finalizado → Pix enviado` contra api+worker+fake reais) passou nas **5/5** execuções do gate local hoje |
| 11.5 — Playwright smoke verde no build deployado | ✅ | Job "Smoke pós-deploy (homolog)" `success` no release rc.85 (run 27092843953); smoke local verde no gate |

### Bloco 12 — Automação + deploy

| Item | Status | Evidência |
|---|---|---|
| 12.1 — `make setup` em máquina limpa, offline | ✅ | Workflow "Setup local test (scheduled)" (executa `make setup` em runner limpo): verde 05/06, 06/06 e 07/06; fake genérico em container (princípio #6 preservado pós-PDR-017) |
| 12.2 — CI verde nos últimos 5 deploys | ✅ | 8 últimos runs do release.yml todos `success` (rc.78→rc.85). Único CI `failure` recente (run 27081702381) = job "Commit lint" sobre mensagem de commit docs; código/scans verdes; CI seguinte verde |
| 12.3 — Deploy automático por tag ≥ 3× no sprint | ✅ | ≥ 8 deploys por tag durante a W28 (rc.63…rc.85), todos verdes |
| 12.4 — Provisionamento via Terraform | ⚠️ | Fake (Cloud Run), secrets (HMAC/Bearer/IDR-028), `TURNI_ENV` no Terraform (`infra/envs/homolog/main.tf`; STORY-075: plan pós-apply sem drift). Exceção documentada (STORY-065): o job `turni-migrate-homolog` é gerido pelo release.yml, não pelo Terraform |

### Bloco 13 — RBAC + segurança

| Item | Status | Evidência |
|---|---|---|
| 13.1 — Profissional A não vê turno do B → 403 | ✅ | Teste `profissional de OUTRO turno → 403 (cruzado)` verde + **vivo em homolog**: GET detalhe de turno alheio → 403; cronômetro alheio → 404 (A.9) |
| 13.2 — Contratante X não vê turno do Y → 403 | ✅ | Teste verde + vivo em homolog: 403 (A.9) |
| 13.3 — Endpoints cruzados de papel → 403 | ✅ | Vivo em homolog: profissional → `/api/contratante/turnos` 403; contratante → `/api/profissional/turnos` 403; sem sessão → 401 |
| 13.4 — Admin acessa tudo no Backoffice | ✅ | Login admin em homolog OK; dashboard + fila "Falhas de pagamento" + templates acessíveis (screenshots) |
| 13.5 — Trivy / gitleaks limpos nos últimos 5 | ✅ | 5 últimos runs de CI na main: gitleaks + Trivy (api e admin) todos `success` (sem PRs — fluxo de commit direto) |

### Bloco 14 — LGPD + segurança de dados

| Item | Status | Evidência |
|---|---|---|
| 14.1 — Criptografia em repouso (chave Pix, CPF/CNPJ) | ✅ | Homolog e local: `chave_pix_encrypted` e `pix_falhas.chave_pix` com ciphertext Laravel (`eyJpdiI6…`); local: `documento_encrypted` idem; IDR-028 (segredo dedicado api+admin) aplicado por Terraform |
| 14.2 — PIN hasheado server-side, nunca plaintext em log | ✅ | Homolog: `pin_*_hash` com prefixo bcrypt `$2y$12$`; teste "audit payload não contém pin" verde; chave Pix nunca logada (teste da 056 verde) |
| 14.3 — AceiteEletronico imutável | ✅ | Ver 2.2 (sondas local + homolog) |
| 14.4 — Audit log imutável | ✅ | Sondas UPDATE/DELETE em `audit_logs`: local trigger `prevent_audit_logs_mutation`; homolog `permission denied` (REVOKE) (A.2) |

### Bloco 15 — Observabilidade

| Item | Status | Evidência |
|---|---|---|
| 15.1 — Log JSON financeiro com `request_id` propagado | ❌ | Log JSON estruturado dos eventos financeiros **existe e está vivo** (Cloud Logging: `pagamento.operacao_concluida` com operação/latência/turno_id; `pagamento.webhook_processado`), mas **sem `request_id`** — o mecanismo de propagação do ADR-008 §f não existe no app `api` (nenhum middleware/processor; nginx loga `request_id` vazio). Ver F-NB-2 |
| 15.2 — Log-based metrics financeiras (erro ≤ 1%, p95 captura, p95 webhook) | ❌ | **Não existem**: ausentes no GCP (`gcloud logging metrics list` — só requests/5xx/duration/email/cadastro/notificação), no Terraform (`infra/modules/monitoring`) e em `docs/operacao/` (onde ADR-016 §Observabilidade afirma estarem definidas). Ver F-NB-1 |
| 15.3 — Alerta de orçamento GCP operante | 🚫 n/a (não verificável) | 6 alert policies de saúde ativas (uptime, 5xx, e-mail, SLA notificação); a Billing Budget API está desabilitada no projeto e habilitá-la seria modificação fora do meu papel — item não verificável com meus acessos (ver Limitações) |

### Bloco 16 — Acessibilidade

| Item | Status | Evidência |
|---|---|---|
| 16.1 — PIN ≥ 64pt + contraste AAA | ⚠️ | Widget tests "PIN ≥64pt + microcopy fixa" verdes; `pin_checkin_screen` 100% cobertura; mono 72/96pt na SCREEN-061 (shipped). Não observei o PIN renderizado em homolog (gerar PIN mutaria estado + dispararia e-mail — cota); evidência é de teste + verificação do PO registrada na 061 |
| 16.2 — Navegação por teclado nas telas críticas | ✅ | **Login 100% via teclado verificado vivo em homolog** (autofoco no e-mail → digitar → Tab → senha → Enter → feed logado; screenshot); traversal de foco visível nos demais elementos (anel de foco). Detalhe/ação de PIN via teclado: coberto por semântica dos widgets (testes verdes), não exercitado vivo |
| 16.3 — Microcopy clara em pt-BR (DDR-002) | ✅ | Visível em todos os screenshots (datas `Dom, 07/06 · 09:05–15:05` 24h pt-BR; mensagens de erro do PDR-002 em pt-BR; microcopy do banner) |

### Bloco 17 — Documentação

| Item | Status | Evidência |
|---|---|---|
| 17.1 — README atualizado onde relevante | ✅ | Contrato versionado `integrations/pagarme/contract.md` atualizado com modos do fake; docs de domínio (`domain/turno.md` com a 14ª transição e X=2h) atualizados |
| 17.2 — ADRs 015/016/017 `accepted` no index | ✅ | index.json: ADR-015 `accepted`, ADR-016 `accepted`, ADR-017 `accepted` (+ PDR-017 `accepted`) |
| 17.3 — IDRs indexados | ❌ | **IDR-028** (arquivo `accepted`, decidido na STORY-065) **não está no index.json**; STORY-056-B está `abandoned` no arquivo mas `ready` no index. Ver F-NB-4 |
| 17.4 — Notas do agente preenchidas | ✅ | As 14 estórias têm Notas completas (decisões, descobertas, cobertura, evidências) — verificado na leitura integral |
| 17.5 — `runbook-homolog.md` com seção do fake + reset cronômetro + Pix com falha | ❌ | O runbook (476 linhas) **não contém** nenhuma das 3 seções exigidas — grep por fake/pagamento/pix/cronômetro sem ocorrências relevantes. Ver F-NB-3 |
| 17.6 — Banner global visível (WebApp + Backoffice) | ✅ | Verificado vivo em homolog (rc.85): WebApp claro e escuro (legível pós-fix rc.85), Backoffice (`data-testid="env-banner"` com a microcopy exata), ausente pré-auth nos 2 temas — screenshots em `evidence/` |

### Bloco 18 — Veredito

Compilação abaixo (Fails identificados) → **REJECTED** (1 fail bloqueante).

---

## Fails identificados

### Bloqueantes

#### F-B-1 — Teste E2E de sincronia do cronômetro (STORY-063) é intermitente

- **Bloco**: 11.4 / CA-3 da STORY-063 / CA-2 da STORY-068 (suíte confiável).
- **Critério esperado**: gate E2E local (IDR-004) determinístico; CA-3 da 063 verificado por E2E estável.
- **O que verifiquei**: 5 execuções completas do `make e2e-webapp-integration` no mesmo commit (`c8f8f3c`), com seed correto a cada run. Run 1 **falhou** no teste "cronômetro bilateral vivo … (≤ 2s, ≥ 12 amostras em ≥ 60s — CA-2/3/4)": `[profissional] amostra 2: display 2222s × servidor 2224s` (2s de desvio; limite 1s/lado). Runs 2–5 verdes. Ocorrência anterior documentada nas notas da STORY-065 ("estourou 2s numa execução COM a máquina sob carga; verde em repouso", sem skip). Taxa observada por mim: 1/5 (20%).
- **Fatos de contexto (sem atenuar a classificação)**: (a) a funcionalidade de produto foi verificada viva em homolog dentro do alvo — Δ=1s entre 2 navegadores em 2 amostras (screenshots), âncora única de servidor para os 2 lados (estrutural, ADR-017); (b) o teste mede um SLA de timing num build Flutter **debug** (flutter drive/DDC) em Chrome headless — ambiente mais lento que produção; (c) a falha é do épico: o teste nasceu na STORY-063.
- **Classificação**: bloqueante — regra objetiva de `verdict-criteria.md` §"Lidando com flaky": *"Flaky introduzido pelo épico (… foi mexido nessa estória): fail bloqueante."*
- **Evidência**: A.10; logs `/tmp/validacao-068-e2e*.log` resumidos em `evidence/suites-locais-resumo-2026-06-07.txt`.

### Não-bloqueantes

#### F-NB-1 — Log-based metrics de operações financeiras não existem

- **Bloco**: 15.2 / CA-12 da STORY-068 / CA-9 da STORY-056.
- **Critério esperado**: "Log-based metrics no Cloud Monitoring: taxa de erro de operações financeiras (SLO ≤ 1%), latência p95 captura, latência p95 webhook" funcionando.
- **O que verifiquei**: `gcloud logging metrics list` não tem nenhuma métrica de pagamento; `infra/modules/monitoring/main.tf` não declara; `docs/operacao/` não contém a definição que a ADR-016 (§Observabilidade) e o CA-9 da STORY-056 (marcado `[x]`) afirmam existir ("definidas em docs/operacao/ para o Terraform da STORY-007 wirar"). Os **eventos de log** que alimentariam as métricas existem e estão vivos em homolog.
- **Classificação**: não-bloqueante — `verdict-criteria.md`: "convenção de log ou métrica não totalmente seguida". Registro factual adicional: a STORY-056 está `done` com esse componente do CA-9 não cumprido.
- **Evidência**: A.11.

#### F-NB-2 — `request_id` não é propagado api→fila→worker (ADR-008 §f não implementado no `api`)

- **Bloco**: 15.1 / CA-12 da STORY-068.
- **Critério esperado**: "log JSON em todas as operações financeiras com `request_id` propagado api→fila→worker" (ADR-008 §f; reafirmado em ADR-016 e no CA-9 da 056).
- **O que verifiquei**: nenhum middleware/processor de `request_id` existe em `apps/api` (grep em app/, config/, bootstrap/ — só o comentário em `PagamentoEvents`); os logs financeiros do worker em homolog não carregam `request_id`; o access-log nginx do api loga `request_id: ""`. O `RequestLogMiddleware` existe apenas no `admin` (EPIC-000/STORY-009). Correlação hoje é possível por `turno_id` (presente nos eventos).
- **Classificação**: não-bloqueante — mesma regra de convenção de log. Registro: o CA-9 da 056 (`[x]`) cita propagação "pelo mecanismo do ADR-008", mecanismo que não existe no `api`.
- **Evidência**: A.11.

#### F-NB-3 — `runbook-homolog.md` sem as seções exigidas pelo checklist

- **Bloco**: 17.5.
- **Critério esperado**: runbook atualizado com fake de pagamento em homolog (deploy + modos + segredo HMAC), reset de cronômetro travado e tratamento manual de Pix com falha.
- **O que verifiquei**: nenhuma das 3 seções existe no arquivo (índice de headings + greps case-insensitive por fake/pagamento/pix/cronômetro). As informações existem dispersas (contract.md, notas das estórias, Terraform), não no runbook.
- **Classificação**: não-bloqueante — "documentação desatualizada em ponto não-crítico".
- **Evidência**: A.12.

#### F-NB-4 — Índice (`index.json`) divergente: IDR-028 ausente; STORY-056-B com status errado

- **Bloco**: 17.3 / Etapa 2 do workflow (estado do índice).
- **Critério esperado**: IDRs do épico indexados; index espelha o estado das estórias.
- **O que verifiquei**: IDR-028 (`accepted`, STORY-065, arquivo existe) não consta na lista de IDRs do index.json (termina em IDR-027). STORY-056-B: frontmatter `status: abandoned` (2026-06-04, com motivo), index diz `ready`.
- **Classificação**: não-bloqueante — inconsistência de documentação/índice.
- **Evidência**: A.13.

#### F-NB-5 — Código novo da STORY-064 (webapp) com cobertura unitária ~6% sem justificativa registrada

- **Bloco**: 11.3 / CA-8 da STORY-064 ("≥ 80% no resto").
- **Critério esperado**: linhas descobertas no código novo com justificativa concreta (quality-standards / workflow Bloco 2).
- **O que verifiquei**: lcov da suíte webapp: `pin_checkout_service.dart` **5,7%** (2/35) e `validar_checkout_service.dart` **6,2%** (2/32); `pin_checkout_screen.dart` 78,1%. Os widget tests da 064 usam fakes que **estendem** os services (a camada real de parsing HTTP→resultado selado não é exercida por teste unitário); os espelhos da 061/062 têm testes de service dedicados (95,7%/96,9%). O caminho feliz real é coberto apenas pelo E2E (`checkout_test.dart`); os caminhos de erro do parsing (422/403/rede) não são exercidos em lugar nenhum. Gates globais atendidos (86,0% webapp; críticos 100%). Nenhuma justificativa nas Notas da 064.
- **Classificação**: não-bloqueante — gates definidos no checklist atendidos; lacuna é de linhas descobertas sem justificativa em código novo não-núcleo.
- **Evidência**: A.14.

#### F-NB-6 — Validação de PIN p95 em homolog = 509ms (alvo ≤ 500ms)

- **Bloco**: 5.4 / CA-5 da STORY-068 / NFR do épico.
- **Critério esperado**: "Validação de PIN ≤ 500ms p95 observada em log JSON estruturado de homolog".
- **O que verifiquei**: 30 requisições `validar-checkin|checkout` nos últimos 7 dias (log JSON nginx do Cloud Run, campo `$request_time` — full-request incl. TLS/proxy): **p95 = 509ms**, p50 = 450ms, max = 578ms. O benchmark de CI (app-level) está ≤ 500ms (gate 750ms) verde. A medição disponível em homolog excede o alvo em 9ms (1,8%) numa amostra pequena dominada por execuções de E2E.
- **Classificação**: não-bloqueante — desvio marginal de NFR em amostra n=30; não há cenário de funcionalidade quebrada.
- **Evidência**: A.15 + `evidence/pin-validacao-latencias-homolog-7d.txt`.

#### F-NB-7 — SLA de e-mail de notificação p95 = 61,6s (alvo ≤ 60s)

- **Bloco**: 10.3 / CA-4 da STORY-067 (parte e-mail).
- **Critério esperado**: "SLA p95 ≤ 60s observado" (última semana).
- **O que verifiquei**: no banco de homolog (régua canônica do projeto), criada→enviada dos 8 tipos do turno: **p95 = 61,6s**, max = 81s (n=109; por tipo: `checkout_solicitado` 65,4s e `no_show_pro` 62,0s acima; demais ≤ 43,1s). STORY-067 mediu p95 = 60,0s (n=72) no fechamento. O worker roda 1/min — o p95 fica estruturalmente colado no teto. In-app (o alvo primário do CA-4) é síncrono ao evento. O alert policy "SLA de e-mail > 60s p95" existe e está `enabled`.
- **Classificação**: não-bloqueante — desvio marginal (1,6s) em métrica operacional com alerta ativo.
- **Evidência**: A.8.

> **Nota**: nenhum fail inclui sugestão, estória de correção, próximo passo ou estimativa — planejamento é do PO.

---

## Passes com ressalva

- **Bloco 3.5** — modos do fake: `fail_capture` não existe como modo do container; falha de captura é exercitada só via `Http::fake` no teste do adapter.
- **Bloco 5.1** — métrica primária com N=10 em homolog (não 20); decisão do PO em chat (2026-06-07) aceitando a evidência existente por causa da cota Resend (129 e-mails já enviados hoje; 20 ciclos ≈ +120).
- **Bloco 7.1** — cenário "dentro do raio" não observado em homolog (coberto por teste + E2E local).
- **Bloco 11.x / CA-2 da STORY-068** — "suíte completa rodada em CI": o CI remoto cobre lint/audit/scans/smoke-builds; a suíte PHP+Flutter com cobertura é gate de pré-push local (IDR-004) — executei-a localmente (mesmo tratamento dado pelo validador do EPIC-002).
- **Suíte api local** — a 1ª de 3 execuções retornou exit 1 com diagnóstico **perdido** (captura truncada por erro meu de coleta); execuções 2 e 3 verdes (982/982). Fica registrado como possível intermitência não diagnosticada na suíte api.
- **Bloco 12.4** — `turni-migrate-homolog` é gerido pelo release.yml, não pelo Terraform (exceção descoberta e documentada na STORY-065).
- **Bloco 16.1** — tipografia/contraste do PIN evidenciados por widget test + spec shipped + verificação do PO na 061; não re-observado vivo (geração de PIN mutaria estado e dispararia notificação).
- **Playwright admin** — a intermitência relatada na STORY-075 (fila-aprovacao/pix-falhas, retry verde) **não se reproduziu**: 4/4 execuções verdes com seed correto. Sem reseed entre execuções os specs falham por estado consumido (aprovação/resolução são mutações) — característica do harness, não flake.
- **Hostnames do runbook** — `api.homolog.turni.com.br` e `admin.homolog.turni.com.br` citados no runbook não resolvem em DNS; os serviços respondem pelos URLs `*.run.app` (e o WebApp por `app.homolog.turni.com.br`).

---

## Limitações da validação

- **Alerta de orçamento GCP (15.3)**: não verificável — a Billing Budget API está desabilitada no projeto e habilitá-la seria modificação fora do papel do validador. As 6 alert policies de saúde estão ativas.
- **Diagnóstico do exit 1 da 1ª execução da suíte api**: perdido por truncamento da minha captura (`tail -40`); não reproduzido em 2 re-execuções.
- **Métrica primária em homolog**: validada sobre os 10 ciclos reais existentes + 20/20 no CI, não sobre 20 ciclos novos (cota Resend; decisão do PO em chat 2026-06-07).
- **Fluxos mutantes em homolog** (gerar/validar PIN ao vivo, resolver caso na fila): não exercitados por mim para não consumir cenários seed, não disparar e-mails (cota) e não alterar estado que pertence ao PO; cobertos por testes automatizados + verificações manuais do PO registradas nas estórias (061/062/064/065/066 — todas com aprovação em chat datada).
- **Leituras one-off no Postgres de homolog** via Cloud Run Job (`turni-migrate-homolog` com override por execução) — saída lida pelo Cloud Logging; linhas longas íntegras no momento da coleta.

---

## Apêndice A — Evidências detalhadas

**Reprodução geral**: commit `c8f8f3c52c29d32109ec39f1c9f1b7c8e41b2020` (main), 2026-06-07; homolog rc.85 (`version.json` conferido nos 3 serviços).

### A.1 — Suítes locais (Blocos 1, 11)
- `make test-api` (pest `--coverage --min=80`): **982 passed (6.246 asserções), Total 94,2%, EXIT=0** (execuções 2 e 3; execução 1 exit 1 — ver Ressalvas).
- `docker compose run admin pest --coverage --min=80`: **127 passed (316 asserções), Total 94,8%, EXIT=0**.
- `flutter test --coverage` (webapp): **549 passed**; lcov 86,0% (7186/8358). Arquivos críticos: `cronometro_ancora.dart` 20/20 (100%), `pin_checkin_screen.dart` 93/93 (100%), `turnos_lista_screen.dart` 98,1%, `env_banner.dart` 24/24 (100%).
- Spot-checks na saída da suíte api: 37 testes de transição (datasets nominais), HMAC (3), idempotência/clique-duplo, `[CA-7] 20 turnos: 20/20 … 20/20 dentro da janela de 15 min` (`MetricaPixPromessaTest`), `p95 da validação do PIN ≤ 500ms (gate 750ms)`, `CronometroCargaTest` PASS.

### A.2 — Imutabilidade + máquina de estados no Postgres (Blocos 2, 14)
- **Local** (`docker compose exec postgres psql -U turni -d turni`): UPDATE/DELETE em `aceites_eletronicos_turno` → `ERROR: … é imutável após criação` (trigger `prevent_aceite_turno_mutation`); UPDATE/DELETE em `audit_logs` → `ERROR: … append-only` (trigger); `UPDATE turnos SET status='finalizado'` (de `confirmado`) → `ERROR: transição de turno inválida`.
- **Homolog** (job one-off, execução `turni-migrate-homolog-r9275`): mesmas 4 sondas → `SQLSTATE[42501] permission denied` (REVOKE de runtime); transição inválida → `SQLSTATE[P0001] transição de turno inválida: confirmado → finalizado`; `INSERT … id=12345` → `SQLSTATE[42804] column "id" is of type uuid` (ADR-018). PKs/FKs `uuid` confirmadas via information_schema. Saída bruta: `evidence/homolog-db-sondas-2026-06-07.txt`.

### A.3 — Índice de habitualidade (Bloco 2.4)
- `\di idx_turnos_habitualidade` presente; `EXPLAIN ANALYZE` (com `enable_seqscan=off` para forçar numa tabela de 32 linhas): `Index Only Scan using idx_turnos_habitualidade … Heap Fetches: 0 … Execution Time: 0.078 ms`. Em volume real o plano é guardado por `HabitualidadeIndexTest` (CI) e pelo microbenchmark da ADR-015 (0,050ms).

### A.4 — Cronômetro bilateral vivo em homolog (Blocos 4, 5.5 / CA-6)
- Turno `ativo` `019e9979-2f12-7322-942d-e90ccab05409` (par `*.cronometro.seed`).
- API âncora (mesmo turno, 2 sessões): profissional `{iniciado_em: 2026-06-07T12:07:00+00:00, sou_profissional: true}`; contratante idem com `sou_profissional: false` — âncora única (ADR-017).
- 2 contextos Chromium (claro/escuro), screenshots simultâneos (Δ disparo 21ms): **04:45:19 × 04:45:18**; 15s depois: **04:45:34 × 04:45:33** — Δ=1s ≤ 2s. Arquivos `evidence/cronometro-*.png`.

### A.5 — Métrica primária + SLA Pix em homolog (Bloco 5)
- `audit_logs` de homolog: 61 `pagamento.pre_autorizado`, 13 `pagamento.capturado`, 10 `pix.enviado`, 3 `pix.falhou` (resíduo documentado da 067), 35 `pagamento.liberado`, 1 `pagamento.liberacao_falhou` (caso seed da fila).
- `pagamento_operacoes`: 47 pré-auth / 11 capturas / 8 pix / 35 liberações `concluida` + 1 liberação `falhou`.
- 10 ciclos com `pix.enviado` (Δ captura→pix): 06-07: 54s, 56s, 58s, 57s, 59s, 60s; 06-06: 58s, 59s; 06-03: 7min, 7min. **10/10 ≪ 15 min**; consistente com SLA do fake (30s) + tick 1/min do worker.
- CI: `MetricaPixPromessaTest` — 20/20 ciclo completo; 20/20 na janela de 15 min.

### A.6 — Habitualidade viva (Bloco 6)
- POST `/api/candidaturas/019e97a4-d6d6-…/aprovar` (sessão `contratante.teste`, cenário Copeiro/bloqueio): **HTTP 422** `{"erro":"habitualidade_bloqueio","mensagem":"este profissional é PF e já tem 2 alocações nesta semana neste estabelecimento; bloqueado por PDR-002"}`.
- Homolog: 9 aceites com `habitualidade_override=true` (cenário PJ exercitado na sprint); 61 aceites totais referenciam 2 `template_versao_id`.

### A.7 — Captura/Pix observáveis (Bloco 9)
- Cloud Logging (worker, 2026-06-07): `pagamento.operacao_concluida {operacao: liberacao, turno_id: 019ea209-…, latencia_ms: 258, resultado: ok}`; `pagamento.webhook_processado {evento_dominio: PreAutorizacaoLiberada, pagarme_event_id: evt_…, resultado: ok}`.
- Detalhe vivo (sessão do profissional dono): turno `019e90a6-9724-…` → `pix: {status: enviado, enviado_em: 2026-06-03T15:18:18+00:00}`; timeline com `pix_enviado, pagamento_capturado, checkout_validado, checkout_solicitado, checkin_validado, checkin_solicitado, pagamento_pre_autorizado, aceite_eletronico_emitido, turno_criado`.
- Fila do admin em homolog: 6 casos abertos com badge/razão/valor/ação (screenshot `evidence/backoffice-fila-falhas-pagamento-2026-06-07.png`).

### A.8 — Notificações (Bloco 10)
- Banco de homolog, 8 tipos do turno: 109 notificações, **109 enviadas, 0 falhas, fila vazia**. Por tipo (n / p95s): turno_confirmado 20/43,1 · checkin_solicitado 18/43,0 · turno_ativo 9/42,6 · checkout_solicitado 9/**65,4** · turno_finalizado 9/41,2 · pix_enviado 6/1,0 · turno_cancelado 10/41,1 · no_show_pro 28/**62,0**. Geral: p95 **61,6s**, max 81s.
- 13 templates categoria `email` com versão ativa (8 do turno + 5 herdados).
- Alert policy "Turni SLA de e-mail de notificação > 60s p95 (homolog)" `enabled`.

### A.9 — RBAC vivo em homolog (Bloco 13)
- Sessões reais (cookies Sanctum): terceiro → detalhe de turno alheio **403**; cronômetro alheio **404**; profissional → `/api/contratante/turnos` **403**; contratante → `/api/profissional/turnos` **403**; sem sessão **401**; contratante → turno de outro contratante **403**.

### A.10 — F-B-1 (flake do gate E2E do cronômetro)
- 5 execuções `make e2e-webapp-integration` (cada uma com `_e2e-seed`), commit `c8f8f3c`: run 1 **falha** ("Expected ≤ 1, Actual 2 — [profissional] amostra 2: display 2222s × servidor 2224s"); runs 2–5 "All tests passed".
- Histórico: STORY-065 registra a mesma falha sob carga (2026-06-06, sem skip); gates das STORY-063/066/067/075 verdes.

### A.11 — F-NB-1/F-NB-2 (observabilidade financeira)
- `gcloud logging metrics list` → 8 métricas (requests, errors_5xx, request_duration, email_failures, cadastro×2, notificacao×2); **nenhuma** de pagamento.
- `grep -rn "logging_metric" infra/` → nenhuma métrica de pagamento; `grep -ri "p95|pagamento" docs/operacao/` → sem definição.
- ADR-016 §Observabilidade: "As log-based metrics … são **definidas** em `docs/operacao/` para o Terraform da STORY-007 wirar" — afirmação não materializada.
- `grep -rln "request_id|X-Cloud-Trace" apps/api/app apps/api/config apps/api/bootstrap` → apenas comentário em `PagamentoEvents.php`; eventos do worker em homolog sem `request_id`; nginx do api com `request_id: ""`. `RequestLogMiddleware` existe só em `apps/admin`.

### A.12 — F-NB-3 (runbook)
- Headings do `docs/operacao/runbook-homolog.md` (476 linhas) listados — nenhuma seção de fake de pagamento, reset de cronômetro ou tratamento de Pix com falha; greps case-insensitive confirmam.

### A.13 — F-NB-4 (índice)
- index.json: lista de IDRs termina em IDR-027; arquivo `decisions/idr/IDR-028-….md` existe com `status: accepted` (2026-06-06).
- STORY-056-B: arquivo `status: abandoned` + `abandoned_reason` (2026-06-04); index.json `status: ready`.

### A.14 — F-NB-5 (cobertura webapp 064)
- lcov: `pin_checkout_service.dart` 2/35 (5,7%); `validar_checkout_service.dart` 2/32 (6,2%); `pin_checkout_screen.dart` 50/64 (78,1%). Comparativos da 061/062: `pin_checkin_service` 45/47 (95,7%), `validar_checkin_service` 31/32 (96,9%).
- `pin_checkout_area_test.dart` usa `_FakePinCheckoutService extends PinCheckoutService` (override dos métodos HTTP) — parsing real não exercido em unidade; nenhum arquivo de teste dedicado aos 2 services.

### A.15 — F-NB-6 (PIN p95 homolog)
- 30 requisições `POST …/validar-check(in|out)` (7 dias; 2 em 06-05, 8 em 06-06, 20 em 06-07; status 200 e 422): p50 450ms, **p95 509ms**, max 578ms (log JSON nginx, `$request_time`). Dados brutos em `evidence/pin-validacao-latencias-homolog-7d.txt`.

---

## Apêndice B — Arquivos anexados (`validation/evidence/`)

- `cronometro-profissional-claro-2026-06-07T165220Z.png` / `cronometro-contratante-escuro-2026-06-07T165220Z.png` — amostra 1 simultânea (04:45:19 × 04:45:18).
- `cronometro-profissional-t2-2026-06-07T165235Z.png` / `cronometro-contratante-t2-2026-06-07T165235Z.png` — amostra 2 (04:45:34 × 04:45:33).
- `banner-webapp-claro-pos-login-2026-06-07.png` / `banner-webapp-escuro-pos-login-2026-06-07.png` / `banner-backoffice-dashboard-2026-06-07.png` / `login-pre-auth-sem-banner-claro-2026-06-07.png` — STORY-075 / Bloco 17.6.
- `backoffice-fila-falhas-pagamento-2026-06-07.png` — fila com 6 casos (Bloco 9.3).
- `teclado-login-so-teclado-feed-2026-06-07.png` — login 100% teclado (Bloco 16.2).
- `pin-validacao-latencias-homolog-7d.txt` — latências cruas (F-NB-6).
- `homolog-db-sondas-2026-06-07.txt` — saída bruta das sondas no Postgres de homolog (A.2 + dados dos blocos 5/6/8/9/10).
- `suites-locais-resumo-2026-06-07.txt` — resumo das execuções de suíte e E2E.

---

## Histórico

- 2026-06-07 — relatório inicial submetido por validador (claude-opus-4-8-validador-2026-06-07).
- 2026-06-07 — **decisão do PO (Alexandro, chat)** sobre o veredito: **F-B-1 aceito como OK** (funcionalidade de sincronia verificada viva dentro do alvo; intermitência do teste assumida); correções determinadas para **F-NB-1, F-NB-2, F-NB-3 e F-NB-5**; F-NB-4, F-NB-6 e F-NB-7 permanecem como pendências registradas.
- 2026-06-07 — no fechamento da SPRINT-2026-W28, o PO quitou também o **F-NB-4** (housekeeping de índice, baixo risco): `index.json` passou STORY-056-B `ready → abandoned` (espelha o frontmatter) e indexou o IDR-028. Carry-forward restante: **F-NB-6** (PIN p95 509ms) e **F-NB-7** (SLA e-mail p95 61,6s).
- 2026-06-07 — correções aplicadas (programador, mesma sessão): **F-NB-1** → 4 log-based metrics financeiras + alert policy "Turni falha de operação financeira (homolog)" criadas por Terraform (`infra/modules/monitoring`) e verificadas vivas no GCP; definição operacional em `docs/operacao/observabilidade-financeira.md`. **F-NB-2** → `RequestContextMiddleware` no `api` (X-Cloud-Trace-Context → fallback ULID; `Context` do Laravel propaga aos jobs da fila — 4 testes novos em `tests/Feature/Observabilidade/RequestContextTest.php`, incluindo job financeiro processado pelo worker logando o request_id de origem); access log do nginx ganhou o campo `trace`. **F-NB-3** → runbook-homolog com as 3 seções (`#fake-pagamento`, `#reset-cronometro`, `#pix-com-falha`). **F-NB-5** → testes de service `pin_checkout_service_test.dart` (100% no service) e `validar_checkout_service_test.dart` (96,9%) espelhando 061/062.
