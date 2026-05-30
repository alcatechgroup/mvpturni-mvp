---
id: IDR-016
title: Worker em Cloud Run Job + Cloud Scheduler substitui GCE worker-vm
status: accepted
decided_at: 2026-05-30
decided_by: programador
source_story: STORY-034
supersedes: nada
superseded_by: nada
---

# IDR-016 — Worker em Cloud Run Job + Cloud Scheduler (substitui GCE worker-vm)

## Contexto

Durante o fechamento da STORY-021 (e-mails transacionais), tentou-se destravar a
CA-13 (E2E de e-mail real em homolog) endurecendo o worker GCE existente
(`infra/modules/worker-vm` — uma `e2-micro` rodando `php artisan queue:work` via
cloud-init no Container-Optimized OS). **Nenhum job da fila jamais funcionou em
homolog** — não é só e-mail. A investigação confirmou **5 gaps de infra** no
caminho GCE:

1. **Sem socket do Cloud SQL.** O `docker run` referencia
   `DB_SOCKET=/cloudsql/<connection_name>` + volume `/cloudsql`, mas nada na VM
   cria esse socket. No Cloud Run a plataforma o materializa via
   `volumes.cloud_sql_instance`; no GCE precisaria do `cloud-sql-auth-proxy`
   rodando — ausente do cloud-init.
2. **Sem segredos no startup.** Não havia `APP_KEY` (sem ele o Laravel nem boota),
   `DB_PASSWORD` nem `RESEND_API_KEY` chegando ao container de forma confiável.
3. **Sem egress de internet (decisivo).** A VM não tem IP público **nem Cloud
   NAT** na VPC. `docker pull` do Artifact Registry falha com
   `Client.Timeout exceeded while awaiting headers`; pior, o **Resend é externo**
   (`api.resend.com`, atrás de Cloudflare) — sem NAT o worker **não envia e-mail**.
4. **SA das apps sem `roles/artifactregistry.reader`.** Mesmo com egress, o
   `docker pull` do AR seria negado. A `turni-apps` é a mesma SA do
   `cloud_run_api`, mas no Cloud Run quem puxa a imagem é o **Cloud Run Service
   Agent** (`service-<num>@serverless-robot-prod.iam.gserviceaccount.com`), não a
   SA de runtime — por isso o `api` roda hoje sem esse role e a VM não rodaria.
5. **Quirk `/root` read-only do COS.** O Container-Optimized OS deixa boa parte do
   filesystem da raiz read-only; `docker-credential-gcr configure-docker` falha
   (`mkdir /root/.docker: read-only file system`), e a auth ao AR no COS depende
   desse helper.

A análise inicial planejou uma **escada A→B**: Fase A endurecia o GCE worker
(IP privado + Secret Manager + cloud-init bespoke) para destravar a CA-13; Fase B
migrava para Cloud Run Job. **Os gaps 3–5 invalidaram a escada A.** Cobri-los
exigiria:

- **Cloud NAT permanente** (Router + NAT Gateway — módulo Terraform que **não
  desaparece** quando a VM sair);
- **IAM extra** (`artifactregistry.reader` na SA das apps);
- **contorno do quirk COS** (helper pré-configurado / `--log-driver=gcplogs`).

Tudo investimento de ~1 dia em código descartável na semana seguinte. A Fase B sai
no mesmo prazo e **elimina os 5 gaps de uma vez**:

| Gap | Fase A (GCE) | Fase B (Cloud Run Job) |
|---|---|---|
| 1. Socket Cloud SQL | exigiria `cloud-sql-auth-proxy` | `volumes.cloud_sql_instance` (gerenciado) |
| 2. Segredos no startup | gcloud + tmpfs + env-file (bespoke) | `secret_env_vars` (paridade com `cloud_run_api`) |
| 3. Cloud NAT (egress) | Router + NAT permanentes | **não necessário** — `PRIVATE_RANGES_ONLY` usa o Google front-end p/ tráfego público (Resend) |
| 4. SA `artifactregistry.reader` | adicionar à `turni-apps` | **não necessário** — Service Agent puxa a imagem |
| 5. Quirk `/root` do COS | cloud-init contornado | **não aplicável** — runtime gerenciado |

## Decisão

Substituir o GCE worker-vm por **Cloud Run Job (`queue:work --stop-when-empty`)
acionado por Cloud Scheduler a cada 1 minuto** em homolog.

1. **Módulo `infra/modules/worker-job`** provisiona um `google_cloud_run_v2_job`
   espelhando o `cloud_run_api`: Direct VPC egress (`PRIVATE_RANGES_ONLY`),
   `volumes.cloud_sql_instance` montando `/cloudsql/<connection_name>`,
   `secret_env_vars` (`APP_KEY`/`DB_PASSWORD`/`RESEND_API_KEY`), `env_vars` com
   paridade do `cloud_run_api`, SA `turni-apps`, comando
   `php artisan queue:work database --stop-when-empty --tries=3 --sleep=2
   --timeout=60` e `ignore_changes = [image]` (o pipeline gerencia a imagem).
2. **Cloud Scheduler** (`* * * * *`, `America/Sao_Paulo`) chama o endpoint
   `…run.googleapis.com/…/jobs/<job>:run` da Admin API com **`oauth_token`**
   (escopo `cloud-platform`) de uma SA dedicada `worker_scheduler`, que tem
   **apenas** `roles/run.invoker` no Job (menor privilégio).
3. **Remoção do GCE worker** do `envs/homolog` e do ramo de VM no
   módulo `sql-scheduler` (os jobs `worker_stop`/`worker_start` e o
   `compute_instance_iam_member` saem; o liga/desliga do Cloud SQL permanece).
4. O `release.yml` atualiza a imagem do Job a cada release
   (`gcloud run jobs update turni-worker-job-homolog --image=<nova>`), mesmo padrão
   do `turni-migrate-homolog`.

## Justificativa

- **Herda IDR-007 integralmente.** Direct VPC egress + `volumes.cloud_sql_instance`
   no Cloud Run gerenciado já foi exercido pelo `turni-migrate-homolog`; o
   `secret_env_vars` é o padrão vivo do `cloud_run_api`. A única novidade é
   `--stop-when-empty` + cron de 1 min.
- **Os 5 gaps são exatamente o "frágil/oneroso"** que o **ADR-004** previu como
  sinal de revisão. Não é nova ADR — é execução da alternativa **pré-aprovada**:
  - §Negativas: *"Alternativa managed registrada: Cloud Scheduler → Cloud Run job
    `queue:work --stop-when-empty` por minuto, que troca elegância por até ~1 min
    de latência de pickup (cabe no SLO de Pix de 15 min)."*
  - §Sinais de revisão: *"Se o `worker` na VM se mostrar frágil/oneroso → migrar
    para o caminho Cloud Scheduler + Cloud Run job."*
- **Paga dívida estrutural.** Elimina SO bespoke (cloud-init/systemd/COS),
  simplifica o `sql-scheduler` (sem ramo de VM) e remove a linha de custo da VM
  sempre-ligada pós-créditos. Cada novo tipo de job (matches no EPIC-002, Pix no
  EPIC-003) herda o caminho sem reabrir a discussão.

## Consequências

- **Latência de pickup ≤ ~60s** (cron de 1 min): `aprovacao_concedida` chega ao
  destinatário em ~30–90s do clique do admin — dentro do "≤ 30s para enfileirar"
  (CA-4 de STORY-021) e do "≤ 90s percebido" da métrica primária do EPIC-001. O
  SLO de e-mail e o de Pix (15 min) absorvem com folga.
- **`--stop-when-empty`** garante que o Job termina quando a fila esvazia — janela
  idempotente e custo só quando há trabalho.
- **Observabilidade:** logs do Job aparecem no Cloud Logging com
  `resource.type=cloud_run_job` (não `cloud_run_revision`). Métricas/alertas de
  envio de e-mail (ADR-011 §c + ADR-008) que filtrem por tipo de recurso devem
  incluir `cloud_run_job` — responsabilidade da STORY-021 ao redigir a métrica de
  `email.failed`, agora que o worker é um Job e não uma revision.
- **Reversibilidade:** o módulo `worker-vm` permanece no repo **desabilitado** por
  um sprint. Reverter é trocar `module "worker_job"` por `module "worker"` no
  `envs/homolog/main.tf`. Remoção definitiva do diretório fica para estória futura.
- **Sem Cloud NAT.** Como a Fase B não precisa de NAT, nenhuma infra de NAT é
  provisionada (evita módulo permanente que a escada A teria criado).

## Nota de implementação — OAuth vs. OIDC no Scheduler

A CA-3 da STORY-034 menciona "OIDC". O endpoint `jobs:run` é da **Admin API do
Cloud Run** (`run.googleapis.com`), uma API do Google — e APIs do Google exigem
**`oauth_token`** (access token, escopo `cloud-platform`), não `oidc_token` (este
último serve para invocar *serviços* Cloud Run com audiência customizada). Adotou-se
`oauth_token`, mesmo mecanismo já usado pelo `sql-scheduler` para `sqladmin`/
`compute`. A autorização efetiva vem de `roles/run.invoker` no Job (que inclui a
permissão `run.jobs.run`) — o requisito de menor privilégio da CA-3 é atendido
integralmente.

## Sinais de revisão futura

- Se algum job ganhar SLO **< 1 min**, a latência de pickup do cron passa a apertar
  → avaliar Cloud Run Job de **processo contínuo** (sem `--stop-when-empty`) ou
  worker dedicado (não VM).
- Se o volume de jobs crescer a ponto de execuções de 1 min se sobreporem com
  frequência → tunar `--max-retries`/concorrência ou mover para processo contínuo.

## Relação com outras decisões

- Executa a alternativa pré-aprovada do **ADR-004** (§Negativas + §Sinais de
  revisão) — sem reabrir a ADR.
- Herda **IDR-007** (Direct VPC egress + Cloud SQL socket no Cloud Run gerenciado).
- Mantém **ADR-002** (fila `database`, worker como processo `queue:work`).
- Serve a **ADR-011** (Resend; egress gerenciado entrega o e-mail sem NAT) e a
  **ADR-008** (logs estruturados em stderr; alerta de falha persistente).
