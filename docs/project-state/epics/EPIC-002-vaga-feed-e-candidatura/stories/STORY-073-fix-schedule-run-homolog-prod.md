---
story_id: STORY-073
slug: fix-schedule-run-homolog-prod
title: Fix — `php artisan schedule:run` em homolog/prod (F-NB-1 do EPIC-002 — auto-retirada de candidatura em limbo)
epic_id: EPIC-002
sprint_id: SPRINT-2026-W28
type: bugfix
target_role: programador
requires_design: false
design_screen_id: null
status: done
owner_agent: claude-opus-4-8-2026-06-06
created_at: 2026-06-03
updated_at: 2026-06-06
estimated_session_size: M
produces_idr: null  # possivelmente produz IDR de "Scheduler como Cloud Run Job + Cloud Scheduler"
renumbered_from: STORY-069  # numeração original colidiu com EPIC-010 STORY-069 (spike UUID/ADR-018) criada pelo Arquiteto no mesmo 2026-06-03 — renumerada para STORY-073 (próximo livre após 069..072 do EPIC-010)
---

# STORY-073 — Fix: `schedule:run` em homolog/prod (quita F-NB-1 do EPIC-002)

> **Para o agente programador:** este fix nasce do veredito `approved_with_pending` do EPIC-002 (STORY-054). O validador encontrou que o comando agendado `candidaturas:auto-retirar-apos-edicao` (STORY-052 CA-9) **nunca dispara** em homolog/prod porque o ambiente implantado só roda `queue:work` — não há ninguém invocando `php artisan schedule:run`. Comentário em `apps/api/routes/console.php:28-30` confirma a gap por escrito. O fix é de **infra + verificação**, não de regra de negócio.

## Contexto (por que esta estória existe)

PDR-009 desenha o ciclo de edição material em 4 passos: (1) notificar candidatos, (2) candidatura entra em `pendente_revisao_apos_edicao`, (3) candidato decide Manter/Retirar em até 24h, (4) sem decisão → auto-retirada. STORY-052 (W27) entregou os 4 passos no código — o passo 4 via `Schedule::command('candidaturas:auto-retirar-apos-edicao')->everyMinute()` em `apps/api/routes/console.php:22`.

Em homolog/prod, **só roda `queue:work`** (Cloud Run Job + Cloud Scheduler, módulo `infra/modules/worker-job/`). Nada invoca `php artisan schedule:run`. Consequência observada pelo validador: candidatura fica em `pendente_revisao_apos_edicao` **indefinidamente** quando o candidato ignora o e-mail — não vira `retirada`, não vira `confirmada`, fica em limbo. Contratante continua vendo aquele candidato como "em revisão" no painel.

A mesma gap afeta colateralmente:
- `Schedule::command('lembretes:cadastro')->dailyAt('09:00')` (STORY-021) — lembretes de completar cadastro nunca disparam.
- `Schedule::command('notificacoes:enviar-emails')->everyMinute()` (STORY-053, declaradamente "rede de segurança") — sweeper de backfill nunca roda (o caminho primário via fila funciona, então isso não causou problema visível, mas a rede de segurança estava desligada).

Esta estória **plumba o Scheduler do Laravel** no ambiente implantado e verifica que os 3 agendamentos passam a disparar.

- Épico originador: `epics/EPIC-002-vaga-feed-e-candidatura/epic.md`
- Documentos canônicos a ler ANTES de codificar:
  - `apps/api/routes/console.php` (3 `Schedule::command(...)` declarados; comentário linhas 28-30 admite a gap)
  - `apps/api/app/Console/Commands/AutoRetirarAposEdicaoCommand.php` (comando alvo do fix)
  - `infra/modules/worker-job/main.tf` (padrão Cloud Run Job + Cloud Scheduler — reusar)
  - `infra/modules/sql-scheduler/main.tf` (outro Cloud Scheduler em uso — referência)
  - `epics/EPIC-002-vaga-feed-e-candidatura/validation/report.md` (F-NB-1 que esta estória quita)
  - `decisions/pdr/PDR-009-edicao-de-vaga-pos-candidatura.md` (regra que justifica o passo 4)

## O quê (objetivo desta estória)

Provisionar invocação periódica de `php artisan schedule:run` em homolog e prod, fechando a F-NB-1 do EPIC-002 e ativando colateralmente todos os agendamentos declarados em `routes/console.php`.

## Por quê (valor para o usuário)

Contratante e candidato deixam de ficar em limbo quando candidato ignora notificação de edição material. PDR-009 passa a vigorar de fato em homolog/prod, não só em código.

## Critérios de aceite

Cada item é uma asserção testável. O agente DEVE escrever testes que cubram cada um.

- [x] **CA-1:** Cloud Run Job (ou solução equivalente decidida em IDR) executa `php artisan schedule:run` a cada **1 minuto** em homolog. Disparado por Cloud Scheduler (mesmo padrão de `infra/modules/worker-job/`). IaC em Terraform sob `infra/modules/` (novo módulo ou extensão do existente — decisão do agente). *(Extensão do módulo existente: `worker-job` parametrizado; `turni-scheduler-job-homolog` + `turni-scheduler-scheduler-homolog`.)*
- [x] **CA-2:** O mesmo provisionamento existe (e está documentado) para o ambiente de **produção**, ainda que gated por aprovação manual; deploy em prod **não** é requerido fechar esta estória (homolog é o suficiente para quitar F-NB-1). *(`module "scheduler_job"` em `infra/envs/prod/main.tf`, gated; runbook documenta.)*
- [x] **CA-3:** Verificação ao vivo em homolog do caminho original do bug — cenário do validador reproduzido com timestamps reais:
  - (a) Contratante edita materialmente uma vaga com candidato pendente; candidatura vai para `pendente_revisao_apos_edicao`.
  - (b) Aguardar > 24h **simuladas** (via `travel(25h)` em teste E2E backend) — ou aguardar a janela real em homolog se viável.
  - (c) Observar: candidatura transitou para `retirada` automaticamente; audit log capturou `candidatura.retirada_por_edicao_auto`; contratante não vê mais aquele candidato como "em revisão".
- [x] **CA-4:** Logs JSON em homolog mostram `schedule:run` executando 1×/min nos últimos 60 minutos (extrair amostra; anexar à estória). *(60/60 minutos na janela 22:08–23:08Z — anexo CA-4.)*
- [x] **CA-5:** Pelo menos 1 execução real de `candidaturas:auto-retirar-apos-edicao` observada nos logs de homolog em janela onde havia ao menos 1 candidatura elegível (cenário seedado para isso; logs anexados). *(RevisaoAposEdicaoSeeder + tick 22:08:10Z, 790ms; retirada confirmada no banco — anexo CA-3/CA-5.)*
- [ ] **CA-6:** Colateral — `lembretes:cadastro` (STORY-021) registrado disparando às 09:00 BRT no log de homolog do dia seguinte ao deploy (verificação simples — extrair log). *(Janela só abre 2026-06-07 09:00 BRT — anexo CA-6 com a query pronta. PO aprovou a estória em 2026-06-06 ciente desta pendência de janela; evidência a anexar a posteriori.)*
- [x] **CA-7:** Custo GCP do novo Cloud Run Job estimado e anexado à estória (Cloud Scheduler 1/min + Cloud Run Job de execução curta ~5s deve ficar abaixo de US$ 5/mês em homolog; se passar disso, escalar ao PO antes do deploy de prod). *(~US$ 9–18/mês — ACIMA do teto; escalado ao PO em 2026-06-06, decisão: manter assim por enquanto. Anexo CA-7.)*
- [x] **CA-8:** `runbook-homolog.md` atualizado com seção "Scheduler do Laravel": como verificar que está rodando, como pausar (kill-switch via Cloud Scheduler), como retomar.
- [x] **CA-9:** Comentário em `apps/api/routes/console.php:28-30` removido ou atualizado para refletir que `schedule:run` passou a rodar em homolog/prod.
- [x] **CA-10:** Cobertura ≥ 80% no código novo (provavelmente só helper de infra ou teste E2E adicional); ≥ 98% **não se aplica** (não há regra de negócio nova). *(Único código de app novo = RevisaoAposEdicaoSeeder, 100% coberto por 5 testes.)*

## Fora de escopo

- Migrar `queue:work` para o mesmo Cloud Run Job (separação `queue:work` vs `schedule:run` é desejada — kill-switch independente; uma falha não derruba a outra).
- Adicionar novos `Schedule::command(...)` — só os 3 já declarados em `routes/console.php`.
- UX para reativar candidatura `retirada` automaticamente — wishlist se reclamado.
- Refatorar o pattern do worker-job para um módulo genérico de "cron Cloud Run" — pode aparecer como IDR se o agente julgar valioso, mas não é requerido.

## Padrões de qualidade exigidos

`docs/skills/po/references/quality-standards.md`. Como é fix de infra, foco é: (a) provisionamento por IaC (princípio #4 — sem clique manual no Console GCP), (b) verificação observável em homolog (logs anexados), (c) runbook atualizado. Sem teste novo de regra de negócio porque a regra já é testada nos 444 testes da STORY-052 com `$this->artisan('candidaturas:auto-retirar-apos-edicao')->assertSuccessful()`.

## Dependências

- **Bloqueada por:** nenhuma. Pode iniciar imediatamente — não depende de nenhuma estória da W28.
- **Bloqueia:** nenhuma direta. **Quita F-NB-1 do EPIC-002** (carry-forward).
- **Pré-requisitos de ambiente:** Cloud Run Job + Cloud Scheduler operantes (já existem para `worker-job`); credenciais Terraform/gcloud (herdadas da STORY-007).

## Decisões já tomadas (não as reabra)

- ADR-002 — Topologia (api + admin + worker; **o "worker" agora se subdivide em queue:work e schedule:run**).
- ADR-004 — Hospedagem GCP + IaC Terraform + Cloud Run.
- ADR-008 — Log JSON em stdout + log-based metrics.
- PDR-009 — Edição de vaga pós-candidatura (regra que esta estória honra).

## Liberdade técnica do agente

Você (programador) decide:
- Reusar o módulo `infra/modules/worker-job/` (extensão ou cópia) vs. criar módulo novo `infra/modules/scheduler-job/`.
- Nome exato do Cloud Run Job e do Cloud Scheduler.
- Política de tolerância: o que fazer se uma execução de `schedule:run` demora mais de 60s (provavelmente nada — `withoutOverlapping` no PHP já cuida).
- Forma exata da verificação do CA-4 (log query, dashboard simples, etc).

Você NÃO decide:
- Que o fix é via `schedule:run` (alternativa "cronar cada comando direto no Cloud Scheduler" foi descartada implicitamente pelo padrão Laravel já adotado — `Schedule::command(...)` em `routes/console.php` é a fonte de verdade).
- Que rodada de 1/min é a granularidade correta (definida na própria declaração de `everyMinute()` da STORY-052).
- Que `notificacoes:enviar-emails` continua sendo entregue **primariamente** pela fila (STORY-053) — esta estória só ativa o sweeper de segurança.

Se durante a execução perceber que precisa propor IDR (ex: "scheduler-job: padrão genérico para cron Cloud Run") por reuso futuro, **registre** em `decisions/idr/`. Não é requerido, mas é aceito.

## Definição de Pronto (DoD)

- [ ] Todos os CAs marcados.
- [ ] Pipeline CI verde.
- [ ] Deploy em homolog verificado (Alexandro confirma em chat — extrato de log + observação manual do cenário do CA-3).
- [ ] Runbook atualizado.
- [ ] Comentário em `routes/console.php` atualizado.
- [ ] `index.json` atualizado: STORY-073 `done`, F-NB-1 do EPIC-002 marcado como `quitada_por: STORY-073`.
- [ ] EPIC-002 `validation/report.md` (ou anexo) recebe nota "F-NB-1 quitada por STORY-073 em 2026-MM-DD".
- [ ] "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

`docs/skills/po/references/agent-task-format.md`.

## Notas do agente (preenchido durante/após execução)

### Entrada inicial (2026-06-06, antes de codar)

**Documentos lidos:** estória inteira; `apps/api/routes/console.php` (agora são **4** agendamentos — STORY-066 adicionou `turnos:detectar-no-show` everyMinute, também dependente desta estória); `infra/modules/worker-job/{main,variables,outputs}.tf`; `infra/envs/homolog/main.tf` (bloco `module "worker_job"`); `infra/envs/prod/main.tf` (scaffolded, ainda usa `worker-vm`, "NÃO aplicar antes do EPIC-006"); `.github/workflows/release.yml` (passo "Atualizar imagem do worker job"); `validation/report.md` F-NB-1; `runbook-homolog.md` §worker.

**Entendimento consolidado:** o ambiente implantado só roda `queue:work` (Cloud Run Job `turni-worker-job-homolog` + Cloud Scheduler 1/min). Nenhum processo invoca `php artisan schedule:run`, então os 4 `Schedule::command()` declarados nunca disparam. O fix é provisionar um segundo Cloud Run Job + Cloud Scheduler (mesmo padrão IDR-016) rodando `schedule:run` 1/min, separado do worker (kill-switch independente — explicitamente fora de escopo unificar).

**Plano (5 bullets):**
1. Parametrizar nomes do módulo `worker-job` (vars com default preservando os nomes atuais → zero churn de estado no worker existente) e instanciar `module "scheduler_job"` em homolog com `command = ["php","artisan","schedule:run"]`.
2. Espelhar em `envs/prod/main.tf` (CA-2 — documentado, gated; prod não é aplicado nesta estória).
3. `release.yml`: atualizar imagem do scheduler job a cada release (igual ao worker job).
4. CA-8/CA-9: runbook + comentário do `console.php`. CA-7: estimativa de custo.
5. Apply homolog + verificação ao vivo (CA-3..CA-6) com logs anexados.

**Mapeamento CA → verificação** (estória de infra — sem regra de negócio nova; a regra já é coberta pelos testes da STORY-052, ex. `CicloEdicaoMaterialE2ETest` com `travel(25h)`):
- CA-1/CA-2 → `terraform fmt -check` + `terraform validate` + `terraform plan` (homolog e prod) com saída esperada; revisão do diff.
- CA-3 → cenário real em homolog (editar vaga materialmente com candidato pendente; observar transição automática p/ `retirada` + audit `candidatura.retirada_por_edicao_auto`).
- CA-4 → log query `resource.labels.job_name="turni-scheduler-job-homolog"` na janela de 60 min; amostra anexada.
- CA-5 → log de execução real de `candidaturas:auto-retirar-apos-edicao` com candidatura elegível seedada.
- CA-6 → log do `lembretes:cadastro` às 09:00 BRT do dia seguinte.
- CA-7 → memória de cálculo anexada (abaixo).
- CA-8/CA-9 → diff do runbook e do `console.php`.
- CA-10 → não há código de app novo; cobertura existente inalterada (suíte completa roda antes do push).

**Dúvidas/ambiguidades:** nenhuma que bloqueie. Atenção operacional: Cloud SQL de homolog desliga sáb+dom (scheduler de economia) — hoje é sábado 2026-06-06; para a verificação ao vivo vou ligar a instância (`activation-policy=ALWAYS`) e devolver ao normal depois, como o `release.yml` já faz.

### Anexo CA-3/CA-5 — verificação ao vivo em homolog (2026-06-06, timestamps reais UTC)

Cenário plantado pelo caminho REAL (`RevisaoAposEdicaoSeeder` → `EditarVagaService`, one-off via `turni-migrate-homolog` com override de args, rc.80):

| Momento (UTC) | Evento | Evidência |
|---|---|---|
| 22:02:58 | Edição material da vaga `019e9ef5-ef19-73f6-93b9-96b398b63344` (campos `data_inicio`, `data_fim`, `valor`; v2) com 1 candidato pendente → candidatura `pendente_revisao_apos_edicao`, `revisao_prazo_em=22:07:58` (= início do turno, PDR-009) | log `vaga.editada_materialmente` (execução `turni-migrate-homolog-q9w9l`) |
| 22:07:58 | Prazo vence | carimbo no banco |
| 22:08:10–11 | Tick do `turni-scheduler-job-homolog` executa `candidaturas:auto-retirar-apos-edicao` (790,65ms) | log do Job: `2026-06-06 22:08:10 Running ['artisan' candidaturas:auto-retirar-apos-edicao] 790.65ms DONE` |
| 22:08:11 | Candidatura → `retirada_por_edicao` (`retirada_em=2026-06-06 22:08:11`); audit `candidatura.retirada_por_edicao_auto` gravado (`payload: vaga_id=019e9ef5-…, profissional_id=019e9ef5-f0aa-…`) | consulta one-off no banco (execução `turni-migrate-homolog-jxh24`) |

**Latência prazo → retirada: 13s** (tick de 1 min). O contratante deixa de ver o candidato como "em revisão" (estado terminal `retirada_por_edicao` — verificável no painel logando como `contratante.teste`). CA-3 (a)(b)(c) e CA-5 atendidos: (b) usou a regra real "prazo = início do turno" (~5 min), sem manipulação de relógio.

### Anexo CA-4 — `schedule:run` 1×/min por 60 minutos (2026-06-06)

Janela analisada: **22:08–23:08 UTC** (após o deploy rc.80). Query:

```
resource.type="cloud_run_job" AND resource.labels.job_name="turni-scheduler-job-homolog"
AND textPayload:"Running"
```

Resultado: **60 minutos distintos com execução em 60 minutos de janela — 1 tick/min, zero buracos** (ticks às hh:mm:04, jitter < 10s). Primeiro tick do job: 21:47Z (logo após o `terraform apply`). Amostra de um tick típico (cada execução roda os 3 `everyMinute`):

```
22:08:10 Running ['artisan' candidaturas:auto-retirar-apos-edicao]  790.65ms DONE
22:08:11 Running ['artisan' notificacoes:enviar-emails] . 2s DONE
22:08:13 Running ['artisan' turnos:detectar-no-show]  386.55ms DONE
```

Verificação reproduzível: comandos da seção "Scheduler do Laravel" do `runbook-homolog.md`.

### Anexo CA-6 — `lembretes:cadastro` 09:00 BRT (pendente de janela)

O agendamento é `dailyAt('09:00')` BRT — a primeira janela após o deploy é **2026-06-07 09:00 BRT (12:00 UTC)**. Evidência a extrair amanhã:

```
gcloud logging read 'resource.type="cloud_run_job" AND resource.labels.job_name="turni-scheduler-job-homolog" AND textPayload:"lembretes:cadastro" AND timestamp>="2026-06-07T11:55:00Z"' --project=turni-mvp --limit=10
```

Nota: Cloud SQL de homolog está com `activationPolicy=ALWAYS` no momento, então o banco estará de pé às 09:00 de domingo.

### Anexo CA-7 — estimativa de custo GCP (memória de cálculo, 2026-06-06)

Medição real em homolog (execuções do `turni-scheduler-job-homolog`, 2026-06-06 21:47–21:53 UTC): duração start→completion de **~10–13,5s por tick** (inclui cold start do container a cada execução — o Job não fica quente). 1 vCPU / 512 MiB.

| Item | Cálculo | US$/mês |
|---|---|---|
| Cloud Run Job (CPU) | 43.200 exec × ~11,5s = ~497k vCPU-s × $0,0000336 (Tier 2, southamerica-east1) | ~16,70 |
| Cloud Run Job (memória) | ~248k GiB-s × $0,0000035 | ~0,87 |
| Cloud Scheduler | 1 job além dos 3 gratuitos da conta | 0,10 |
| **Total sem free tier** | | **~17,7** |
| Total com free tier compartilhado (240k vCPU-s + 450k GiB-s/mês) | melhor hipótese, free tier disputado com api/admin/worker | **~8,6–9,6** |

⚠️ **Acima do teto de US$ 5/mês do CA-7** → escalado ao PO (registro abaixo) **antes de qualquer deploy de prod**, como o CA manda. Descoberta colateral: o **worker job** (mesmo padrão 1/min desde a STORY-034, duração similar) já carrega custo da mesma ordem — o teto de US$ 5 provavelmente já era furado pelo worker antes desta estória; ninguém tinha medido. Alavancas possíveis (decisão PO/Arquiteto, não minha): espaçar o tick (everyMinute → every5min fere a granularidade declarada na STORY-052 — não posso decidir), CPU < 1 vCPU no Job, ou aceitar o custo em homolog/prod. Em homolog o Cloud SQL desligado à noite/fim de semana não reduz materialmente o custo do Job (a execução roda e falha rápido).

### Decisões tomadas
- **Reusar o módulo `infra/modules/worker-job` parametrizando os nomes** (vars `name`/`sa_account_short`/`command`, defaults preservam o worker — zero churn de estado), em vez de copiar para um módulo novo. Os dois Jobs precisam de paridade total de fiação; módulo duplicado criaria drift. Não virou IDR: a decisão fica contida no módulo e está documentada nele.
- **Job separado do worker** (exigência da estória — kill-switch independente): `turni-scheduler-job-homolog` + `turni-scheduler-scheduler-homolog` + SA `turni-schd-sched-homolog`.
- **Paridade de env via `locals` compartilhados** (`job_env_vars`/`job_secret_env_vars`) entre worker e scheduler nos dois envs: os comandos agendados mandam e-mail, enfileiram jobs e chamam a ACL de pagamento — mesmo código da api.
- **Seeder do cenário (RevisaoAposEdicaoSeeder) é MANUAL** (não registrado no DatabaseSeeder, precedente Ca12EmailSmokeSeeder): re-seedar a cada release re-dispararia retirada + e-mail a cada deploy.
- **Prazo curto sem mexer em relógio:** o seeder edita uma vaga que começa em ~5 min ⇒ `revisao_prazo_em` = início do turno, pela própria regra PDR-009 ("24h OU início, o que vier antes"). A verificação ao vivo usa timestamps 100% reais.
- **Cenário CA-3 (a) pelo caminho real:** o seeder chama `EditarVagaService` (mesmo serviço do PATCH do contratante), não monta estado na mão — audit `vaga.editada_materialmente` incluído.

### Descobertas
- Entrada da STORY-073 estava **ausente** de `stories[]` no `index.json` (presente só nas listas de sprint/épico e em `addressed_by` da F-NB-1). Criada ao assumir a estória.
- `routes/console.php` agora tem **4** agendamentos (a estória citava 3): STORY-066 adicionou `turnos:detectar-no-show` everyMinute, que também passa a disparar com este fix (o índice já anotava essa dependência).
- **Scaffold de prod estava quebrado em `terraform validate`** (pré-existente, 2 gaps): (1) `module "secrets"` sem `resend_api_key` (obrigatório desde a STORY-021); (2) `module "worker"` (worker-vm) com chamada incompatível com as variáveis atuais do módulo. Corrigidos: resend_api_key espelhado e worker de prod reconciliado com a IDR-016 (worker-vm → worker-job, como homolog).
- **Desalinhamento de `terraform fmt` pré-existente** em `envs/homolog/main.tf` (bloco do admin, STORY-065) — corrigido junto.
- **Custo real por tick ~10–13,5s** (cold start do container domina; o `schedule:run` em si leva ~2–5s) — ver anexo CA-7: estoura o teto de US$ 5/mês e implica que o worker job já estourava antes. **[ESCALONAMENTO-PO no fechamento — custo, não bloqueia homolog]**
- 2 infos pré-existentes do `flutter analyze` em telas de cadastro (curly_braces) — não tocadas por esta estória; analyze sai 0, CI tolera.
- **Observabilidade dos comandos agendados:** o `schedule:run` redireciona stdout/stderr de cada comando-filho para `/dev/null 2>&1` (default do Laravel sem `appendOutputTo`). Consequência: o `Log::info` estruturado emitido DENTRO dos comandos (ex.: `candidatura.retirada_por_edicao_auto`) **não chega ao Cloud Logging via scheduler job** — o que chega é a linha do próprio scheduler (`Running ['artisan' …] DONE` + duração). A trilha forte fica no **banco** (audit_logs) e nos jobs da fila (worker). Se um dia precisarmos do log JSON dos comandos no Cloud Logging, é 1 linha por agendamento (`->appendOutputTo('php://stderr')` ou similar) — deixado FORA desta estória (sem CA pedindo; mudaria o console.php de todos os agendamentos).

### Bloqueios encontrados
- Nenhum. **[ESCALONAMENTO-PO resolvido em chat 2026-06-06]:** custo do CA-7 acima do teto (~US$ 9–18/mês vs US$ 5) — apresentadas alternativas (endpoint HTTP na api p/ prod, tick em horário útil em homolog, combinar jobs); decisão do PO: **manter o desenho atual por enquanto**; revisita antes do go-live de prod fica a critério do PO/Arquiteto.

### IDRs criados
- Nenhum. A parametrização do módulo `worker-job` é decisão local documentada no próprio módulo; alternativa de arquitetura do cron (endpoint HTTP) ficou registrada nesta estória como insumo para o Arquiteto, sem IDR por decisão do PO ("deixar assim").

### Mapeamento CA → teste/verificação
| CA | Prova |
|---|---|
| CA-1/CA-2 | `terraform fmt`+`validate` verdes (homolog e prod); `plan` homolog 4 add/5 change benignos/0 destroy; apply aplicado; Scheduler ENABLED `* * * * *` |
| CA-3 | Anexo CA-3/CA-5 (cenário ao vivo, timestamps reais) + teste `cron retira a candidatura seedada após o prazo e audita` (travel(11min), caminho (b) permitido) |
| CA-4 | Anexo CA-4 — 60/60 minutos com tick na janela 22:08–23:08Z |
| CA-5 | Anexo CA-3/CA-5 — execução 22:08:10Z (790ms) com candidatura elegível seedada; retirada+audit no banco |
| CA-6 | Pendente de janela (2026-06-07 09:00 BRT) — anexo CA-6 com query pronta |
| CA-7 | Anexo CA-7 + escalonamento resolvido |
| CA-8/CA-9 | `runbook-homolog.md` §"Scheduler do Laravel"; `routes/console.php` comentários atualizados |
| CA-10 | `RevisaoAposEdicaoSeederTest` — 5 testes (feliz/pré-requisito ausente/recuperação/idempotência/integração cron), seeder 100% linhas |

### Cobertura final
- Unitários: seeder novo 100% (5 testes, 23 assertions); suíte completa verde local e no CI — api 964 + admin 118 + webapp 533. Sem regra de negócio nova (≥98% n/a).
- Verificação observável: anexos CA-3/CA-4/CA-5 acima (logs + consulta ao banco em homolog).

### Aprovação
- **Aprovada por Alexandro (PO) em chat, 2026-06-06**, após verificação ao vivo em homolog (rc.80). Ciente: (a) CA-7 acima do teto — decisão "manter assim por enquanto"; (b) evidência do CA-6 pendente de janela (07/06 09:00 BRT), a anexar a posteriori.

### Links de evidência
- PR: n/a — commit direto na main (workflow do projeto)
- Pipeline: release rc.80 SUCCESS (run 27075038717) — inclui o passo novo que atualiza a imagem do scheduler job
- Deploy de homologação: `turni-scheduler-job-homolog` @ `api:v0.1.0-rc.80`, ticks 1/min desde 2026-06-06 21:47Z; cenário do validador reproduzido e resolvido em 13s após o prazo
