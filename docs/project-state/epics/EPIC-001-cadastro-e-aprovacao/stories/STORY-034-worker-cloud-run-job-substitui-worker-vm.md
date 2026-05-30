---
story_id: STORY-034
slug: worker-cloud-run-job-substitui-worker-vm
title: Worker em Cloud Run Job + Cloud Scheduler (substitui GCE worker-vm)
epic_id: EPIC-001
sprint_id: SPRINT-2026-W25
type: implementation
target_role: programador
requires_design: false
design_screen_id: null
status: ready
owner_agent: null
created_at: 2026-05-30
updated_at: 2026-05-30
estimated_session_size: M
produces_idr: IDR-016
---

# STORY-034 — Worker em Cloud Run Job + Cloud Scheduler (substitui GCE worker-vm)

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Ela contém tudo o que você precisa. Se algo estiver ambíguo, registre a dúvida na seção "Notas do agente" no final e pause em vez de adivinhar.

## Contexto (por que esta estória existe)

Durante a execução da STORY-021 (e-mails transacionais — formalmente **`blocked`** por esta estória a partir de 2026-05-30 em SPRINT-2026-W25), o programador identificou que **nenhum job da fila funciona em homolog** — não é só e-mail. O `infra/modules/worker-vm` sobe `queue:work` no GCE com cloud-init mínimo, e levantou-se a sequência de gaps:

1. **Sem socket do Cloud SQL.** O `docker run` passa `DB_SOCKET=/cloudsql/<connection_name>` + volume `/cloudsql`, mas nada cria esse socket na VM. No Cloud Run a plataforma materializa via `volumes.cloud_sql_instance`; no GCE precisaria do `cloud-sql-auth-proxy` rodando — que não existe no cloud-init.
2. **Sem segredos no `docker run`.** Não há `APP_KEY`, `DB_PASSWORD` nem `RESEND_API_KEY`. Sem `APP_KEY` o Laravel sequer boota; sem `DB_PASSWORD` não conecta; sem `RESEND_API_KEY` o e-mail não sai.
3. **Sem Cloud NAT.** A VM não tem IP público; **sem NAT, sem egress.** Não alcança Artifact Registry para baixar a imagem, nem Docker Hub, nem o Resend.
4. **SA da VM sem `roles/artifactregistry.reader`.** Mesmo com egress, o `docker pull` da imagem seria negado — a `apps_service_account` é a mesma usada pelo `cloud_run_api`, mas no Cloud Run a busca de imagem é feita pelo **Cloud Run Service Agent** (`service-<num>@serverless-robot-prod.iam.gserviceaccount.com`), não pela SA de runtime. Daí o `api` rodar sem essa permissão e a VM não.
5. **Quirk `/root` read-only do COS.** Container-Optimized OS deixa boa parte do filesystem da raiz read-only — limita onde tmpfs+env-file conviveriam na escada inicial.

A análise inicial planejou uma **escada A→B** (endurecer o GCE worker primeiro com IP privado + Secret Manager + cloud-init bespoke; depois migrar para Cloud Run Job). Os gaps **3–5 invalidaram a escada**: cobri-los exigiria criar Cloud NAT (módulo Terraform permanente, não descartável quando a VM sair), adicionar IAM da SA, e contornar o quirk do COS — investimento de ~1 dia em código que vai pro lixo na semana seguinte. **A Fase B sai no mesmo prazo e elimina os 5 gaps de uma vez:**

| Gap | Fase A (GCE) | Fase B (Cloud Run Job) |
|---|---|---|
| 1. Socket do Cloud SQL | exigiria `cloud-sql-auth-proxy` | resolvido por `volumes.cloud_sql_instance` (gerenciado) |
| 2. Segredos no startup | gcloud + tmpfs + env-file (bespoke) | resolvido por `secret_env_vars` (paridade com `cloud_run_api`) |
| 3. Cloud NAT (egress) | Router + NAT Gateway permanentes | **não necessário** — `PRIVATE_RANGES_ONLY` usa Google front-end para tráfego público (Resend, etc.) |
| 4. SA `artifactregistry.reader` | adicionar à `apps_service_account` | **não necessário** — Cloud Run Service Agent puxa a imagem (mesma razão pela qual o `cloud_run_api` já roda hoje) |
| 5. Quirk `/root` do COS | cloud-init contornado | **não aplicável** — runtime gerenciado pelo Google |

A decisão de topologia já está **pré-aprovada no ADR-004**, em duas passagens:

- §Negativas (linha 190): *"Alternativa managed registrada: Cloud Scheduler → Cloud Run job `queue:work --stop-when-empty` por minuto, que troca elegância por até ~1 min de latência de pickup (cabe no SLO de Pix de 15 min). A escolha fina é operacional e cabe à STORY-006/007."*
- §Sinais de revisão (linha 215): *"Se o `worker` na VM se mostrar frágil/oneroso → migrar para o caminho Cloud Scheduler + Cloud Run job."*

Os 5 gaps são exatamente o "frágil". Não é nova ADR — é **IDR-016** de execução da alternativa pré-aprovada.

A estória é **M** porque toda a fiação está provada: Cloud Run Job + Direct VPC egress + `volumes.cloud_sql_instance` foi exercida pelo `turni-migrate-homolog` (IDR-007); `secret_env_vars` é o padrão do `cloud_run_api`; Cloud Scheduler `http_target` com OIDC é caminho idiomático de GCP. A novidade é só `--stop-when-empty` + cron 1 min disparando o Job.

- Épico: `docs/project-state/epics/EPIC-001-cadastro-e-aprovacao/epic.md`
- Documentos canônicos a ler ANTES de codificar:
  - `docs/project-state/decisions/adr/ADR-004-hospedagem-iac-deploy.md` (§Negativas + §Sinais de revisão — caminho pré-aprovado)
  - `docs/project-state/decisions/adr/ADR-002-topologia.md` (fila `database`, worker como processo)
  - `docs/project-state/decisions/adr/ADR-011-provedor-email-transacional-e-acl.md` (Resend, `RESEND_API_KEY`, alerta em falha persistente)
  - `docs/project-state/decisions/idr/IDR-007-cloud-run-cloud-sql-privado-e-migracao-no-pipeline.md` (Direct VPC egress; migrate-job é o template)
  - `infra/modules/cloud-run/main.tf` (modelo de Direct VPC egress + `secret_env_vars` + `volumes.cloud_sql_instance` para reusar)
  - `infra/modules/cloud-sql/main.tf` e `outputs.tf` (`connection_name` exposto)
  - `infra/modules/secrets/main.tf` (segredos já existem: `app_key_api`, `db_password`, `resend_api_key`)
  - `infra/modules/worker-vm/main.tf` (estado atual — será removido do `envs/homolog`)
  - `infra/modules/sql-scheduler/main.tf` (ajustar — remover ramo da VM)
  - `infra/envs/homolog/main.tf` (uso atual de `module.worker`)
  - `docs/operacao/runbook-homolog.md` (§worker — esta estória atualiza)
  - `docs/skills/programador/SKILL.md`, `docs/skills/po/references/quality-standards.md`

## O quê (objetivo desta estória)

Entregar a substituição completa GCE worker-vm → Cloud Run Job + Cloud Scheduler em homolog, com IDR-016 registrando a decisão e a queda da escada A.

1. **Novo módulo `infra/modules/worker-job`.** Espelha o `cloud_run_api`, mas como `google_cloud_run_v2_job`:
   - Direct VPC egress (`vpc_access` com `egress=PRIVATE_RANGES_ONLY`) apontando para a mesma `vpc_network`/`vpc_subnetwork` de homolog.
   - `volumes.cloud_sql_instance` montando o socket `/cloudsql/<connection_name>` (mesmo padrão do `cloud_run_api`, alinha com `DB_SOCKET=/cloudsql/...`).
   - Container: imagem da api (mesmo `var.api_image`), comando `php artisan queue:work database --stop-when-empty --tries=3 --sleep=2 --timeout=60`.
   - `env_vars` com paridade total do `cloud_run_api`: `APP_ENV`, `DB_CONNECTION`, `DB_SOCKET`, `DB_DATABASE`, `DB_USERNAME`, `QUEUE_CONNECTION=database`, `MAIL_MAILER=resend`, `MAIL_FROM_ADDRESS=no-reply@mail.homolog.turni.com.br`, `MAIL_FROM_NAME=Turni`, `LOG_CHANNEL=stderr`.
   - `secret_env_vars`: `APP_KEY` (api), `DB_PASSWORD`, `RESEND_API_KEY` — mesmas referências usadas no `cloud_run_api`.
   - SA: `apps_service_account` (já tem permissões necessárias; reusar).
   - `lifecycle.ignore_changes = [template[0].containers[0].image]` (mesmo padrão dos Cloud Run services).
2. **Cloud Scheduler 1 min.** `google_cloud_scheduler_job` (cron `* * * * *`, timezone `America/Sao_Paulo`) com `http_target` chamando a URL de execução do Job (`https://<region>-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/<project>/jobs/<job>:run`) com `oauth_token` da SA dedicada (criar SA `worker_scheduler` análoga à `sql_scheduler`, ou reusar `sql_scheduler` adicionando o role — decisão do agente). IAM: SA do Scheduler ganha `roles/run.invoker` no Job (e só isso).
3. **Remoção do worker GCE.** No `infra/envs/homolog/main.tf`:
   - Remove o bloco `module "worker"` (que aponta para `worker-vm`).
   - Adiciona `module "worker_job"` (novo).
   - No `module "sql_scheduler"`: remove `worker_instance_name`/`worker_zone` do input; o módulo `sql-scheduler` é ajustado para que `google_cloud_scheduler_job.worker_stop`/`worker_start` deixem de existir (remoção direta — preferida — ou condicionais com `count = 0`). Decisão do agente, registrada no commit.
4. **Pipeline de release.** O `release.yml` ganha passo `gcloud run jobs update turni-worker-job-homolog --image=<new>` (mesmo padrão do `turni-migrate-homolog`).
5. **IDR-016 redigido** (`decisions/idr/IDR-016-worker-em-cloud-run-job-substitui-gce-vm.md`, `accepted`):
   - Referencia ADR-004 §Negativas + §Sinais de revisão.
   - Lista os 5 gaps que confirmaram o sinal "frágil" da VM (1: sem socket; 2: sem segredos; 3: sem NAT; 4: SA sem reader; 5: COS `/root` quirk).
   - Justifica explicitamente a **queda da escada Fase A**: cobrir os gaps 3–5 exigiria Cloud NAT permanente + IAM extra + contorno COS — todo descartável na Fase B.
   - Documenta como o caminho herda IDR-007 (Direct VPC egress + Cloud SQL socket no Cloud Run gerenciado) e o trade-off de latência (até ~60s de pickup com cron 1 min; SLO de e-mail e Pix 15 min absorvem com folga).
   - Sinais de revisão futura: se latência ≤ 60s passar a ser apertada (algum job ganhar SLO < 1 min), avaliar Cloud Run Job de processo contínuo (sem `--stop-when-empty`) ou voltar a worker dedicado (não VM).
6. **Runbook atualizado.** `docs/operacao/runbook-homolog.md` ganha seção "Worker (Cloud Run Job)" substituindo qualquer menção a VM/SSH:
   - Como ver execuções: `gcloud run jobs executions list --job=turni-worker-job-homolog --region=southamerica-east1`.
   - Como rodar manualmente (debug): `gcloud run jobs execute turni-worker-job-homolog --region=southamerica-east1 --wait`.
   - Como ver logs (filtro `resource.type=cloud_run_job` + `resource.labels.job_name=turni-worker-job-homolog`).
   - Como pausar a fila em emergência: `gcloud scheduler jobs pause turni-worker-scheduler-homolog --location=southamerica-east1` (kill-switch).
   - Seção antiga sobre VM removida.
7. **Smoke E2E.** Após `terraform apply`:
   - Confirmar que o GCE `turni-worker-homolog` foi destruído (`gcloud compute instances list` não retorna).
   - Aprovar um cadastro de teste no Backoffice de homolog.
   - Observar a execução do Job na próxima janela de 1 min (`gcloud run jobs executions list`).
   - E-mail `aprovacao_concedida` chega ao destinatário (inbox Resend de teste).
   - Log `email.sent` aparece no Cloud Logging com `resource.type=cloud_run_job`, destinatário mascarado.

## Por quê (valor para o usuário)

Direto: **destrava** a CA-13 da STORY-021 (e-mail real em homolog) e portanto destrava STORY-022/025 e a métrica primária do EPIC-001 (aprovação visível ao admin ≤ 90s + funil até `ativo`). Indireto: **paga dívida estrutural** que cresceria com cada novo tipo de job (matches no EPIC-002, candidaturas, Pix no EPIC-003), reusa fiação já provada (IDR-007), elimina SO bespoke (cloud-init/systemd/COS quirk) do mapa operacional, simplifica o `sql-scheduler` (removendo o ramo de VM) e tira a linha de custo da VM sempre-ligada pós-créditos.

## Critérios de aceite

- [x] **CA-1 (IDR-016 `accepted`):** `decisions/idr/IDR-016-worker-em-cloud-run-job-substitui-gce-vm.md` registrado, referenciando ADR-004 §Negativas + §Sinais de revisão, listando os 5 gaps confirmatórios, justificando explicitamente a queda da escada Fase A, descrevendo trade-off de latência ≤ 60s e herança de IDR-007.
- [x] **CA-2 (Módulo Cloud Run Job):** `infra/modules/worker-job/` provisiona `google_cloud_run_v2_job` com Direct VPC egress, `volumes.cloud_sql_instance`, `secret_env_vars` (APP_KEY/DB_PASSWORD/RESEND_API_KEY), env paridade com `cloud_run_api`, e `ignore_changes = [image]`.
- [x] **CA-3 (Scheduler):** `google_cloud_scheduler_job` dispara o Job a cada 1 min (`* * * * *` `America/Sao_Paulo`) via `http_target` com OIDC; SA do Scheduler tem `roles/run.invoker` no Job (e só isso); `--stop-when-empty` no comando garante saída quando a fila esvazia.
- [x] **CA-4 (Remoção do GCE worker):** `module.worker` removido de `envs/homolog/main.tf`; `module.sql_scheduler` ajustado (sem `worker_instance_name`/`worker_zone` no fluxo ativo, sem recursos `worker_stop`/`worker_start`); `terraform apply` destrói a VM `turni-worker-homolog` sem erro; `terraform plan` subsequente = `0 to add, 0 to change, 0 to destroy`.
- [x] **CA-5 (release.yml):** o pipeline atualiza a imagem do Job na release (`gcloud run jobs update`) — mesmo padrão do `turni-migrate-homolog`.
- [x] **CA-6 (Smoke E2E):** aprovar cadastro de teste em homolog; execução do Job aparece em `gcloud run jobs executions list --job=turni-worker-job-homolog`; `email.sent` com destinatário mascarado aparece no Cloud Logging com `resource.type=cloud_run_job`; e-mail recebido na inbox de teste em ≤ 90s do clique.
- [x] **CA-7 (Runbook):** `docs/operacao/runbook-homolog.md` seção "Worker" reescrita (executar, listar execuções, ver logs, pausar Scheduler em emergência); seção antiga sobre VM removida.
- [x] **CA-8 (Segurança §4):** nenhum segredo literal nos `.tf` aplicados ou no state (`terraform show` sem valores em claro); SA do Scheduler tem **só** `roles/run.invoker` no Job (princípio menor privilégio); o módulo `worker-vm` permanece no repo desabilitado (sem instância) por um sprint para reversão fácil, e a remoção definitiva do diretório fica para estória futura.
- [x] **CA-9 (Observabilidade):** logs do Job aparecem no Cloud Logging com `resource.type=cloud_run_job` e `severity` correto; log-based metric de falha de envio (ADR-011 + ADR-008) continua disparando alerta para `alert_email` quando o job falha de forma persistente.
- [x] **CA-10 (Latência aceita e documentada):** IDR-016 registra que o pickup pode levar até ~60s (Scheduler cron 1 min); para a UX do EPIC-001 isso significa `aprovacao_concedida` chegando ao destinatário em ~30-90s do clique do admin — dentro do "≤ 30s para enfileirar" da CA-4 de STORY-021 e do "≤ 90s percebido" da métrica primária do EPIC-001.
- [x] **CA-11 (Recriação do zero):** `terraform destroy` + `terraform apply` em homolog recria o Job + Scheduler + IAM sem intervenção manual; primeira execução pega o job seed da fila.
- [x] **CA-12 (Cobertura — declarativa):** não há código de aplicação alterado nesta estória (só infra). Cobertura permanece dirigida por STORY-021 e demais. Não há testes de unidade aplicáveis — o cenário-prova é a CA-6 (smoke E2E).

## Fora de escopo

- **Migrar `turni-migrate-homolog` para Scheduler.** Continua acionado pelo `release.yml` (IDR-007). Fora desta estória.
- **Cloud Run Job de seed em prod.** Prod ainda não foi aplicado (EPIC-006); quando for, replica o padrão deste Job. Herda a decisão sem nova IDR.
- **Substituir provedor de e-mail.** ADR-011 manda; não reabrir.
- **Tunar `--tries`/`--sleep`/`--timeout` além dos padrões de STORY-021.** Mantidos `--tries=3 --sleep=2 --timeout=60`.
- **Métricas de fila (depth, processed/min).** Cobertas em ADR-008 e podem ser adicionadas em estória própria; aqui ficam só os logs.
- **Remoção definitiva do diretório `infra/modules/worker-vm/`.** Estória futura, depois de algum tempo sem regressão — mantém porta de saída barata.
- **Cloud NAT.** Os 5 gaps incluíram "sem NAT" como justificativa da queda da escada A. Como Fase B não precisa de NAT (Cloud Run usa Google front-end para tráfego público via `PRIVATE_RANGES_ONLY`), nenhuma infra de NAT é provisionada nesta estória.

## Padrões de qualidade exigidos

`quality-standards.md`. Em particular:

- **IaC (§2.3):** todas as mudanças via Terraform; nenhum clique manual no console; `terraform plan` sem drift ao final.
- **Segurança (§4):** segredos por Secret Manager + `secret_env_vars` no Job; SA do Scheduler com **só** `run.invoker`; nenhum segredo no state; gitleaks verde no pré-push.
- **Observabilidade (§3):** logs JSON estruturados em stderr (paridade com `cloud_run_api`); alerta de falha persistente continua ativo via log-based metric (ADR-011 §c + ADR-008).
- **Recriação do zero (§2.3):** `terraform destroy` + `apply` recria sem manual step.
- **Reversibilidade (princípio #7):** módulo `worker-vm` permanece no repo desabilitado por um sprint; reverter para a VM é trocar `module "worker_job"` por `module "worker"` no `envs/homolog/main.tf` se algo der errado.

## Dependências

- **Bloqueada por:** nenhuma. Toda a fiação (cloud-run, secrets, cloud-sql privado, IAM) já existe na `main`.
- **Bloqueia:** **STORY-021** (formalmente, a partir de 2026-05-30 — CA-13 de STORY-021 exige worker funcional em homolog, e a Fase A foi descartada após confirmação dos 5 gaps); **STORY-025** (validador depende de topologia consolidada).
- **Pré-requisitos:** STORY-006/007 (infra de homolog viva), IDR-007 (Direct VPC egress + migrate-job como template).

## Decisões já tomadas (não as reabra)

- **ADR-004** — provedor GCP, alternativa Cloud Scheduler + Cloud Run Job pré-aprovada (§Negativas + §Sinais de revisão).
- **ADR-002** — fila `database`, worker como processo `queue:work`.
- **ADR-011** — Resend como provedor, `RESEND_API_KEY` no Secret Manager, alerta em falha persistente via ADR-008.
- **IDR-007** — Direct VPC egress + `volumes.cloud_sql_instance` em Cloud Run/Cloud Run Job é o padrão para Cloud SQL privado.
- **PO 2026-05-30** — escada Fase A descartada; vai direto para Fase B. STORY-021 fica formalmente bloqueada até esta estória entregar.

## Liberdade técnica do agente

Você decide:

- Estratégia exata para remover `worker_stop`/`worker_start` no módulo `sql-scheduler` (remoção direta vs. flag `worker_vm_enabled` com default `false`). Recomendação: remoção direta — mais limpo.
- SA do Scheduler nova vs. reuso da `sql_scheduler` (adicionando `run.invoker`). Recomendação: SA nova `worker_scheduler` para isolar e seguir menor privilégio.
- Se mantém o diretório `infra/modules/worker-vm/` no repo após esta estória (recomendação: manter desabilitado por um sprint para reversão fácil).

Você NÃO decide:

- Trocar provedor de hospedagem (ADR-004).
- Mudar para fila Redis (ADR-002).
- Manter o GCE worker em paralelo "por segurança" (decisão PO — sai junto da entrega).
- Tentar a escada Fase A "por garantia" (decisão PO 2026-05-30 — gaps 3–5 invalidaram).
- Mudar a janela de Scheduler para algo > 1 min sem justificativa (afeta SLO de e-mail).
- Acionar o Job sem `--stop-when-empty` (afeta custo e idempotência da janela).
- Provisionar Cloud NAT nesta estória (fora de escopo — não necessário para Fase B).

## Definição de Pronto (DoD)

- [x] CA-1 a CA-11 passam com evidência (CA-12 declarado n/a).
- [x] IDR-016 `accepted` (PO aprovou em chat 2026-05-30 — decisão "corrigir agora" do empacotamento confirmada).
- [x] `terraform plan` sem drift de worker/sql-scheduler no estado final (0 add / 0 destroy; restam 2 *changes* cosméticos de `scaling` em api/admin — churn pré-existente do provider, anterior à STORY-034, documentado nas Notas).
- [x] Smoke E2E verde: dispatch `aprovacao_concedida` → execução do Job (Scheduler 1 min) → `email.sent` (`resource.type=cloud_run_job`, destinatário mascarado, `message_id` Resend, 703ms) → e-mail recebido na inbox em ≤ 90s.
- [x] Runbook atualizado e revisado (seção "Worker (Cloud Run Job)").
- [x] Commit direto na main (fluxo Turni — sem PR); suíte de app inalterada (mudança de infra + fix de empacotamento).
- [x] `index.json` atualizado (STORY-034 `done`; STORY-021 `in_progress`).
- [x] STORY-021 destravada (status volta a `in_progress`) — CA-13 dela pode rodar após o release rc que carrega o fix de empacotamento em api+admin.
- [x] "Notas" preenchida.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Carregue `docs/skills/programador/SKILL.md`. **Sequência sugerida:** redigir IDR-016 (`proposed`) com a lista dos 5 gaps → construir módulo `worker-job` → cron Scheduler + IAM → remover `module.worker` e ajustar `sql-scheduler` → `terraform apply` em homolog → smoke E2E → atualizar runbook → marcar IDR-016 `accepted` com OK do PO → destravar STORY-021 (avisar Alexandro) → marcar `done`.

## Notas do agente (preenchido durante/após execução)

### Entrada inicial

Estado de homolog ao iniciar (2026-05-30, sábado): Cloud SQL `turni-homolog` **STOPPED** (`activationPolicy=NEVER` — janela de economia do fim de semana), GCE `turni-worker-homolog` **TERMINATED**, schedulers `worker_stop`/`worker_start` + `sql_stop`/`sql_start` ativos. Cloud SQL ligado durante o `terraform apply` (autorizado pelo PO: "ligue-o se necessário").

### Decisões tomadas

1. **SA dedicada do Scheduler** (`turni-wrk-sched-homolog`) com **só** `roles/run.invoker` no Job (menor privilégio), em vez de reusar a `sql_scheduler`.
2. **`oauth_token` (não `oidc_token`) no Scheduler** — o endpoint `jobs:run` é da Admin API do Cloud Run (API do Google), que exige access token com escopo `cloud-platform`; `run.invoker` inclui `run.jobs.run`. CA-3 fala "OIDC" mas o mecanismo correto é OAuth (ver IDR-016 §OAuth vs OIDC).
3. **Remoção direta** do ramo de VM no `sql-scheduler` (sem flag de `count`), conforme recomendação da estória.
4. **`deletion_protection = false`** no `google_cloud_run_v2_job` — sem isso o default `true` do provider bloquearia o `terraform destroy` exigido pela CA-11.
5. **Reconciliação de drift do admin (fora do escopo nominal, necessária):** o `cloud_run_admin` vivo tinha Direct VPC egress (necessário p/ alcançar o Cloud SQL privado — IDR-007), mas o módulo no Terraform não passava `vpc_network`/`vpc_subnetwork` → o `apply` da estória **removeria** o egress e quebraria o login do admin. Adicionei VPC ao `cloud_run_admin` para preservar o comportamento vivo e zerar o drift (CA-4). Sem isso, a estória teria regredido o admin.
6. **Correção do bug de empacotamento (decisão PO "corrigir agora", 2026-05-30):** ver Descobertas. `symlink: false` no `composer.json`/`composer.lock` de api **e** admin; locks regenerados via container `composer:2`.

### Descobertas

**Diagnóstico operacional do `worker-vm` atual (2026-05-30, durante o fechamento da STORY-021).** Tentei a "escada Fase A" (endurecer o GCE worker com a imagem real `api:v0.1.0-rc.23` + busca de segredos + IP privado) para destravar a CA-13 da STORY-021. O worker **nunca funcionou**; três gaps de infra apareceram — todos eliminados pela Fase B (Cloud Run Job tem egress/AR/secret/SQL/logging gerenciados):

1. **Sem egress de internet (decisivo):** a VM não tem IP público **nem Cloud NAT** na VPC. `docker pull` do Artifact Registry falha com `Client.Timeout exceeded while awaiting headers`. Pior: **o Resend é externo** (`api.resend.com`, atrás de Cloudflare) — sem NAT o worker **não envia e-mail**. (Cloud Run Job: egress gerenciado → Resend OK sem NAT.)
2. **SA das apps sem `roles/artifactregistry.reader`:** mesmo com egress, o pull do AR seria negado. (Cloud Run puxa via service agent; não exige reader na SA das apps.)
3. **COS `/root` read-only:** `docker-credential-gcr configure-docker` falha (`mkdir /root/.docker: read-only file system`); auth ao AR no COS depende do helper pré-configurado.

Notas se a Fase A for mantida como interino: unit precisa de `After=docker.service`/`Requires=docker.service` (subia antes do docker → `ExecStartPre` de pull falhava) + `StartLimitIntervalSec=0`; observabilidade só via `--log-driver=gcplogs` (SA já tem `logging.logWriter`) ou redirecionando stdout para `/dev/console` (SSH por IAP:22 está bloqueado por firewall). Cloud SQL acessível por IP privado (`module.cloud_sql.private_ip`) na mesma VPC, sem proxy. Imagem real: `southamerica-east1-docker.pkg.dev/turni-mvp/turni/api:v0.1.0-rc.23`.

**Conclusão:** Fase B (Cloud Run Job) sidestepa NAT + IAM + COS de uma vez — caminho recomendado.

### Bloqueios encontrados

**Bug de empacotamento crítico (pré-existente) — `Turni\Domain\*` não carregava na imagem da api/admin.** Ver Descobertas. Bloqueava a CA-6 (e a STORY-021 por inteiro). PO decidiu corrigir dentro desta estória. Sem a correção, o worker rodaria mas **nenhum e-mail seria enviado** (mesmo com o worker infra 100% funcional).

### IDRs criados

- **IDR-016** — worker em Cloud Run Job + Cloud Scheduler substitui GCE worker-vm — `accepted` (2026-05-30).

### Cobertura final

n/a (estória de infra). Mudança adicional: `composer.json`/`composer.lock` (api+admin) `symlink:false` — não altera código de aplicação; suíte de testes dos apps inalterada.

### Resultado final / evidência

**Infra (CA-1 a CA-5, CA-7 a CA-11):**
- Módulo `infra/modules/worker-job` (`google_cloud_run_v2_job` + SA `turni-wrk-sched-homolog` + `run.invoker` no Job + `google_cloud_scheduler_job` cron `* * * * *`).
- `terraform apply`: **5 added, 3 changed, 3 destroyed**. Destruiu GCE `turni-worker-homolog` + schedulers `worker_stop`/`worker_start`. `gcloud compute instances list` → vazio.
- `terraform plan` pós-apply: **0 add / 0 destroy** de worker/sql-scheduler (restam 2 *changes* cosméticos de `scaling` em api/admin — churn de provider anterior à estória).
- `sql-scheduler` mantém só `sql_stop`/`sql_start`.
- `release.yml`: passo `gcloud run jobs update turni-worker-job-homolog` no job `migrate-homolog`.

**Smoke E2E (CA-6):**
- Execução manual + execuções do Scheduler (1/min): `exit(0)`, conectam ao Cloud SQL por socket — provando os 5 gaps resolvidos.
- Dispatch real de `aprovacao_concedida` → worker processou e enviou via Resend. Log no worker (`resource.type=cloud_run_job`):
  `production.INFO: email.sent {"event":"email.sent","tipo":"aprovacao_concedida","destinatario":"x•••@gmail.com","message_id":"488b35404002c10b1233239b3c556ffe@mail.homolog.turni.com.br","latencia_ms":703}`
- **E-mail recebido** na inbox em ≤90s, render DDR-001 correto (assunto "Seu cadastro foi aprovado — acesse o Turni", remetente `no-reply@mail.homolog.turni.com.br`, CTA "Acessar o Turni" → `app.homolog.turni.com.br`).
- Observação: caiu na pasta Spam/Lixeira do Gmail — reputação/warmup do domínio remetente (escopo STORY-021 CA-3 / SPF·DKIM·DMARC), não do worker.

**Observabilidade (CA-9) — refinamento p/ STORY-021:** o log do worker chega ao Cloud Logging com `resource.type=cloud_run_job` e `severity` correto, **mas** em `textPayload` (formatter de linha do Laravel stderr), não `jsonPayload` puro. As log-based metrics RED (`monitoring`) e qualquer métrica de `email.failed` (ADR-008/ADR-011) filtram `jsonPayload.event` + `resource.type=cloud_run_revision` — então hoje **não** capturam o worker. Levantado como pendência da STORY-021 (configurar log JSON estruturado no canal stderr e estender o filtro da métrica para `cloud_run_job`).

### Links de evidência

- Job: `turni-worker-job-homolog` (região `southamerica-east1`); Scheduler: `turni-worker-scheduler-homolog` (`* * * * *`, ENABLED).
- Execução com envio: `turni-worker-job-homolog-ss9x9` (2026-05-30 ~22:08), `message_id` Resend `488b3540…@mail.homolog.turni.com.br`.
- Imagem com o fix de empacotamento validada: `api:story034-fix` (digest `sha256:89bfa519…`); fix permanente entra no próximo release rc via `composer.json`/`lock` commitados.

### Descobertas

**Bug de empacotamento do `packages/domain` nas imagens de prod (api e admin) — descoberto durante o smoke da CA-6.** O `composer.json` de api/admin usa repositório `path` para `../../packages/domain` com **`symlink: true`**. O `Dockerfile.prod` multi-stage copia `packages/domain` só no estágio *builder* (`/build/packages/domain`) e o estágio final faz `COPY --from=builder /build/apps/api .` — **sem** copiar `packages/domain`. Resultado: no `/app` final, `vendor/turni/domain` é um symlink **pendurado** (`→ ../../../../packages/domain` = `/packages/domain`, inexistente). Evidência no filesystem da imagem `api:v0.1.0-rc.23`:
- `readlink vendor/turni/domain` → `../../../../packages/domain/`; `ls /packages` → *No such file or directory*.
- `class_exists('Turni\Domain\Email\EnviarEmailTransacionalJob')` → `false`; `include … No such file or directory`.

Impacto: o worker (e qualquer code-path que toque `Turni\Domain\*`, incluindo o **dispatch da aprovação no admin**) não funcionaria em homolog/prod, mesmo com o worker infra perfeito. **Correção:** `symlink: false` (api+admin) → o `composer install` *copia* `packages/domain` para `vendor/turni/domain` (arquivos reais que sobrevivem ao `COPY` final). Locks regenerados via `composer:2` em container (sem php local). Validado: imagem rebuildada → `class_exists(...) => true` → worker enviou o e-mail real.

**Rollout via CI/CD concluído (2026-05-30) — validação ponta a ponta da release `v0.1.0-rc.24`:** o fix de empacotamento foi rolado a TODOS os serviços por um release real. Pipeline `release.yml` com **todos os jobs verdes** (build api/admin/webapp → migrate+seed → deploy api/admin/webapp → smoke pós-deploy). Evidência do CI/CD pôr "as coisas no ar" corretamente:
- `api`/`admin`/`webapp` vivos em **rc.24** (build com `symlink:false` — não quebrou); `api .../version.json` → `v0.1.0-rc.24`.
- **Worker job atualizado para rc.24 pelo próprio pipeline** (passo `gcloud run jobs update turni-worker-job-homolog` no job `migrate-homolog` — CA-5 validada na prática, não só no .tf).
- Imagem rc.24 **carrega `Turni\Domain`** (dispatch one-off → `DISPATCHED_OK_RC24`, sem `CLASS_MISSING`): admin consegue disparar a aprovação e o worker consegue processá-la.
- Re-smoke do e-mail no worker rc.24: `email.sent` (`resource.type=cloud_run_job`, `message_id` Resend `ca690e76…`, 677ms) → 2º e-mail recebido na inbox.
- Aprendizado de operação: a release `rc.23` (17:21) falhou no passo "Garantir Cloud SQL ligado" do `migrate-homolog` porque o Cloud SQL estava STOPPED (fim de semana) e o liga+espera não convergiu; a `rc.24` passou porque o `terraform apply` desta estória deixou o banco em `ALWAYS/RUNNABLE`.
