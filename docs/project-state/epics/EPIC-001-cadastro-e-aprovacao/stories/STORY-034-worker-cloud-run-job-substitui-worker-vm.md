---
story_id: STORY-034
slug: worker-cloud-run-job-substitui-worker-vm
title: Worker em Cloud Run Job + Cloud Scheduler (substitui GCE worker-vm) + escada A para destravar CA-13 de STORY-021
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

Durante a execução da STORY-021 (e-mails transacionais — `in_progress` em SPRINT-2026-W25), o programador identificou um gap que **antecede** STORY-021 mas é exatamente o que a **CA-13** dela exige (E2E real de aprovação → e-mail entregue): o `infra/modules/worker-vm` hoje sobe `queue:work` no GCE com cloud-init mínimo, passando apenas `APP_ENV=production` e `DB_SOCKET=/cloudsql/<connection_name>` + volume `/cloudsql`. Acontece que:

1. **O socket `/cloudsql/...` nunca é criado dentro da VM.** No Cloud Run a plataforma materializa o socket via `volumes.cloud_sql_instance` (módulo `cloud-run`); no GCE não há essa mágica — precisaria de `cloud-sql-auth-proxy` rodando, que **não existe** no cloud-init. Resultado: o worker não alcança o banco.
2. **Nenhum segredo é carregado.** Não há `APP_KEY`, `DB_PASSWORD` nem `RESEND_API_KEY` no `docker run`. Sem `APP_KEY` o Laravel sequer boota corretamente; sem `DB_PASSWORD` não conecta; sem `RESEND_API_KEY` o e-mail não sai.

Ou seja: **nenhum job da fila funciona em homolog hoje** — não é só e-mail. É pré-condição da CA-13 da STORY-021 (que está bloqueando STORY-022/025 e a métrica primária do EPIC-001).

A descoberta atravessa dois detalhes da infra já provados:

- **Cloud SQL é IP privado** (`ipv4Enabled=false` + `private_network`, `infra/modules/cloud-sql/main.tf`) e a VM do worker está na mesma VPC/subnet. O módulo `cloud-sql` já expõe o output `private_ip`. Conexão por IP privado **sem proxy** é viável.
- **Cloud Run Job + Direct VPC egress + `secret_env_vars`** já está provado pelo job `turni-migrate-homolog` (IDR-007) e pelo Cloud Run da `api` (módulo `cloud-run`). É o caminho idiomático em Cloud Run para conversar com o Cloud SQL privado e consumir Secret Manager — **mesma fiação** que o resto da infra.

A decisão de topologia já está **pré-aprovada no ADR-004**, em duas passagens:

- §Negativas (linha 190): *"Alternativa managed registrada: Cloud Scheduler → Cloud Run job `queue:work --stop-when-empty` por minuto, que troca elegância por até ~1 min de latência de pickup (cabe no SLO de Pix de 15 min). A escolha fina é operacional e cabe à STORY-006/007."*
- §Sinais de revisão (linha 215): *"Se o `worker` na VM se mostrar frágil/oneroso → migrar para o caminho Cloud Scheduler + Cloud Run job."*

A descoberta do programador é exatamente o sinal "frágil". Não é nova ADR — é **IDR** de execução da alternativa pré-aprovada (IDR-016 produzido por esta estória).

A estória adota um padrão **escada A→B no mesmo sprint** para preservar a meta da W25:

- **Fase A (escada — patch destravar CA-13):** endurecer o `module.worker` GCE só o suficiente para conectar (DB por IP privado + 3 segredos via Secret Manager no startup + `MAIL_MAILER=resend`). Reversível, marcada como temporária no commit. Permite que STORY-021 CA-13 feche enquanto B é construído.
- **Fase B (entrega real):** novo `module.worker-job` (Cloud Run Job + Scheduler 1 min, `queue:work --stop-when-empty`), reusando `secret_env_vars` e Direct VPC egress já em uso pelo `cloud_run_api`. Remove `module.worker` do `envs/homolog/main.tf` + ajusta `sql-scheduler` (tira `worker_stop`/`worker_start`/`worker_url` e o `worker_instance_name`).

A estória é **M** (não L) porque tudo é **fiação já provada**: Cloud Run Job foi o mesmo padrão usado por `turni-migrate-homolog` (IDR-007), e os `secret_env_vars` já funcionam no `cloud_run_api`. Nenhuma decisão de produto nova; nenhum SDK novo. A novidade é só `--stop-when-empty` + Cloud Scheduler 1 min disparando o job.

- Épico: `docs/project-state/epics/EPIC-001-cadastro-e-aprovacao/epic.md`
- Documentos canônicos a ler ANTES de codificar:
  - `docs/project-state/decisions/adr/ADR-004-hospedagem-iac-deploy.md` (§Negativas + §Sinais de revisão — caminho B pré-aprovado)
  - `docs/project-state/decisions/adr/ADR-002-topologia.md` (fila `database`, worker como processo)
  - `docs/project-state/decisions/adr/ADR-011-provedor-email-transacional-e-acl.md` (Resend, `RESEND_API_KEY`, alerta em falha persistente)
  - `docs/project-state/decisions/idr/IDR-007-cloud-run-cloud-sql-privado-e-migracao-no-pipeline.md` (Direct VPC egress; migrate-job é o template)
  - `infra/modules/worker-vm/main.tf` (estado atual — escada A vai aqui antes de remover)
  - `infra/modules/cloud-run/main.tf` (modelo de Direct VPC egress + `secret_env_vars` para reusar)
  - `infra/modules/cloud-sql/main.tf` e `outputs.tf` (`private_ip` já exposto)
  - `infra/modules/secrets/main.tf` (segredos já existem: `app_key_api`, `db_password`, `resend_api_key`)
  - `infra/modules/sql-scheduler/main.tf` (parar/iniciar VM — Fase B remove o pedaço da VM)
  - `infra/envs/homolog/main.tf` (uso atual de `module.worker`)
  - `docs/operacao/runbook-homolog.md` (§worker — esta estória atualiza)
  - `docs/skills/programador/SKILL.md`, `docs/skills/po/references/quality-standards.md`

## O quê (objetivo desta estória)

Entregar a transição completa GCE worker-vm → Cloud Run Job em duas fases, **no mesmo sprint**, com IDR-016 registrando a decisão.

### Fase A — escada (patch destravar CA-13 de STORY-021)

1. **DB por IP privado.** `infra/envs/homolog/main.tf` passa para `module.worker` uma nova var `db_host = module.cloud_sql.private_ip` (e remove a dependência do socket). O cloud-init do `module.worker-vm/main.tf` substitui `DB_SOCKET=/cloudsql/...` + volume `/cloudsql` por `DB_HOST=<private_ip>` + `DB_PORT=5432` + `DB_CONNECTION=pgsql`.
2. **Segredos carregados no startup.** Cloud-init adiciona um `runcmd` que: (a) chama `gcloud secrets versions access latest --secret=turni-homolog-app-key-api`, idem para `turni-homolog-db-password` e `turni-homolog-resend-api-key`; (b) escreve `/run/turni/worker.env` em **tmpfs** (`tmpfiles.d` ou mount manual de `tmpfs` em `/run/turni`), 0600, root-only; (c) sistema-d aponta `EnvironmentFile=/run/turni/worker.env`; (d) `docker run` usa `--env-file /run/turni/worker.env`. A SA `apps_service_account` já tem `roles/secretmanager.secretAccessor` (módulo `iam`); verificar e propagar se necessário.
3. **Variáveis de e-mail.** Cloud-init passa `MAIL_MAILER=resend`, `MAIL_FROM_ADDRESS=no-reply@mail.homolog.turni.com.br`, `MAIL_FROM_NAME=Turni` ao `docker run`.
4. **`QUEUE_CONNECTION=database`** e `LOG_CHANNEL=stderr` no env (paridade com `cloud_run_api`).
5. **Commit marcado.** Mensagem do commit começa com `chore(worker-vm): patch temporário A (IDR-016) — remoção em Fase B`. Comentário no `main.tf` aponta para IDR-016.
6. **Smoke E2E:** publicar nova tag `vX.Y.Z-rc.N`, aprovar um cadastro de teste no Backoffice de homolog, observar `aprovacao_concedida` chegar ao destinatário Resend (ou inbox de teste configurado). Log `email.sent` aparece no Cloud Logging com destinatário mascarado.

### Fase B — entrega real (Cloud Run Job + Cloud Scheduler)

7. **Novo módulo `infra/modules/worker-job`.** Espelha o que o `cloud_run_api` faz, mas como `google_cloud_run_v2_job`:
   - Direct VPC egress (`vpc_access` com `egress=PRIVATE_RANGES_ONLY`) apontando para a mesma `vpc_network`/`vpc_subnetwork` de homolog.
   - `volumes.cloud_sql_instance` montando o socket `/cloudsql/<connection_name>` (alinha com `DB_SOCKET=/cloudsql/...`, mesmo padrão do `cloud_run_api` — não precisa de `private_ip` no Job, já tem socket gerenciado).
   - Container: imagem da api (mesmo `var.api_image`), comando `php artisan queue:work database --stop-when-empty --tries=3 --sleep=2 --timeout=60`.
   - `env_vars` com a paridade total do `cloud_run_api` (`APP_ENV`, `DB_*`, `QUEUE_CONNECTION=database`, `MAIL_MAILER=resend`, `MAIL_FROM_ADDRESS`, `MAIL_FROM_NAME`, `LOG_CHANNEL=stderr`).
   - `secret_env_vars`: `APP_KEY` (api), `DB_PASSWORD`, `RESEND_API_KEY` — mesmas referências usadas no `cloud_run_api`.
   - SA: `apps_service_account` (já tem permissões; reusar).
   - `lifecycle.ignore_changes = [template[0].containers[0].image]` (mesmo padrão).
8. **Cloud Scheduler 1 min.** `google_cloud_scheduler_job` (cron `* * * * *`, timezone `America/Sao_Paulo`) com `http_target` chamando a URL de execução do Job (`https://<region>-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/<project>/jobs/<job>:run`) com `oauth_token` da SA dedicada (criar `sql_scheduler` análoga ou reusar). IAM: SA do Scheduler ganha `roles/run.invoker` no Job.
9. **Remoção do worker GCE.** No `infra/envs/homolog/main.tf`:
   - Remove o bloco `module "worker"` (que aponta para `worker-vm`).
   - Adiciona `module "worker_job"` (novo).
   - No `module "sql_scheduler"`: remove `worker_instance_name`, `worker_zone`, e os recursos `google_cloud_scheduler_job.worker_stop`/`worker_start` viram condicionais (`count = var.worker_vm_enabled ? 1 : 0`) com default `false` — alternativa: remover de vez e ajustar o módulo. Decisão do agente, registrada no commit.
10. **Pipeline de release.** O `release.yml` precisa redeploy do Job quando a imagem da `api` muda: adicionar passo `gcloud run jobs update turni-worker-job-homolog --image=<new>` (mesmo padrão do `turni-migrate-homolog`).
11. **IDR-016 redigido** (`decisions/idr/IDR-016-worker-em-cloud-run-job-substitui-gce-vm.md`, `accepted`), referenciando ADR-004 §Negativas/§Sinais de revisão, descrevendo Fase A (escada) e Fase B (entrega), trade-off de latência (até ~60s de pickup, ainda muito dentro do SLO de e-mail e dos 15 min do Pix de ADR-005), e como o caminho herdou IDR-007 (Direct VPC egress + Cloud SQL socket no Cloud Run gerenciado).
12. **Runbook atualizado.** `docs/operacao/runbook-homolog.md` ganha seção "Worker (Cloud Run Job)" substituindo qualquer menção a VM/SSH: como ver execuções (`gcloud run jobs executions list --job=turni-worker-job-homolog`), como rodar manualmente (`gcloud run jobs execute ...`), como ver logs (filtro `resource.type=cloud_run_job` + `resource.labels.job_name=turni-worker-job-homolog`), e como parar a fila em emergência (pausar o Scheduler: `gcloud scheduler jobs pause`).
13. **Smoke E2E Fase B.** Após `terraform apply` da Fase B: confirmar que o GCE worker foi destruído; aprovar um cadastro de teste; observar a execução do Job na próxima janela de 1 min; e-mail chega; log `email.sent` no Cloud Logging com `resource.type=cloud_run_job`.

## Por quê (valor para o usuário)

Direto: **destrava** a CA-13 da STORY-021 (e-mail real em homolog) e portanto destrava STORY-022/025 e a métrica primária do EPIC-001 (aprovação visível ao admin ≤ 30s + funil até `ativo`). Indireto: **paga dívida estrutural** que cresceria com cada novo tipo de job (matches no EPIC-002, candidaturas no EPIC-002, Pix no EPIC-003), reusa fiação já provada (IDR-007), elimina SO bespoke (cloud-init/systemd) do mapa operacional, simplifica o `sql-scheduler` (removendo o ramo de VM) e tira a linha de custo da VM sempre-ligada pós-créditos.

## Critérios de aceite

- [ ] **CA-1 (Fase A — pré-requisito da CA-13 de STORY-021):** worker GCE conecta ao Cloud SQL por IP privado; APP_KEY/DB_PASSWORD/RESEND_API_KEY carregados via Secret Manager em tmpfs; `aprovacao_concedida` despachado em homolog é entregue (chegada confirmada via inbox Resend de teste ou Mailpit-redirect, conforme STORY-021 §pendências). Commit marcado como **temporário até Fase B**.
- [ ] **CA-2 (IDR-016 `accepted`):** `decisions/idr/IDR-016-worker-em-cloud-run-job-substitui-gce-vm.md` registrado, referenciando ADR-004 §Negativas + §Sinais de revisão, descrevendo Fase A e Fase B, trade-off de latência ≤ 60s, e herança de IDR-007.
- [ ] **CA-3 (Fase B — módulo Cloud Run Job):** `infra/modules/worker-job/` provisiona `google_cloud_run_v2_job` com Direct VPC egress, `volumes.cloud_sql_instance`, `secret_env_vars` (APP_KEY/DB_PASSWORD/RESEND_API_KEY), env paridade com `cloud_run_api`, e `ignore_changes = [image]`.
- [ ] **CA-4 (Fase B — Scheduler):** `google_cloud_scheduler_job` dispara o Job a cada 1 min (`* * * * *` `America/Sao_Paulo`) via OIDC; SA do Scheduler tem `roles/run.invoker` no Job; `--stop-when-empty` no comando garante saída quando a fila esvazia.
- [ ] **CA-5 (Fase B — remoção do GCE worker):** `module.worker` removido de `envs/homolog/main.tf`; `module.sql_scheduler` ajustado (sem `worker_instance_name`/`worker_zone`/`worker_url` no fluxo ativo); `terraform apply` destrói a VM `turni-worker-homolog` sem erro; `terraform plan` subsequente = `0 to add, 0 to change, 0 to destroy`.
- [ ] **CA-6 (release.yml):** o pipeline atualiza a imagem do Job na release (`gcloud run jobs update`) — mesmo padrão do `turni-migrate-homolog`.
- [ ] **CA-7 (smoke E2E Fase B):** aprovar cadastro de teste em homolog; execução do Job aparece em `gcloud run jobs executions list --job=turni-worker-job-homolog`; `email.sent` com destinatário mascarado aparece no Cloud Logging com `resource.type=cloud_run_job`; e-mail recebido na inbox de teste em ≤ 90s do clique.
- [ ] **CA-8 (runbook):** `docs/operacao/runbook-homolog.md` seção "Worker" reescrita (executar, listar execuções, ver logs, pausar Scheduler em emergência); seção antiga sobre VM removida.
- [ ] **CA-9 (segurança §4):** nenhum segredo literal nos `.tf` aplicados ou no state (`terraform show` sem valores em claro); SA do Scheduler tem **só** `roles/run.invoker` no Job (princípio menor privilégio); cloud-init da Fase A removido junto com o módulo `worker-vm` ao final.
- [ ] **CA-10 (observabilidade):** logs do Job aparecem no Cloud Logging com `resource.type=cloud_run_job` e `severity` correto; log-based metric de falha de envio (ADR-011 + ADR-008) continua disparando alerta para `alert_email` quando o job falha de forma persistente.
- [ ] **CA-11 (latência aceita):** documentar no IDR-016 que o pickup pode levar até ~60s (Scheduler 1 min); para a UX do EPIC-001 isso significa `aprovacao_concedida` chegando em ~30-90s — dentro do "≤ 30s" da CA-4 de STORY-021 medido **a partir do dispatch do job**, e do "≤ 90s percebido" da métrica primária do EPIC-001 (admin clica → usuário recebe).
- [ ] **CA-12 (recriação do zero):** `terraform destroy` + `terraform apply` em homolog recria o Job + Scheduler + IAM sem intervenção manual; primeira execução pega o job seed da fila.
- [ ] **CA-13 (cobertura — declarativa):** não há código de aplicação alterado nesta estória (só infra). Cobertura permanece dirigida por STORY-021 e demais. Não há testes de unidade aplicáveis — o cenário-prova é a CA-7 (smoke E2E).

## Fora de escopo

- **Migrar `turni-migrate-homolog` para Scheduler.** Continua acionado pelo `release.yml` (IDR-007). Fora desta estória.
- **Cloud Run Job de seed em prod.** Prod ainda não foi aplicado (EPIC-006); quando for, replica o padrão do Job sem `--stop-when-empty`-com-cron — esse `worker_prod` herda a decisão.
- **Substituir provedor de e-mail.** ADR-011 manda; não reabrir.
- **Tunar `--tries`/`--sleep`/`--timeout` além dos padrões de STORY-021.** Mantidos `--tries=3 --sleep=2 --timeout=60`.
- **Métricas de fila (depth, processed/min).** Cobertas em ADR-008 e podem ser adicionadas em estória própria; aqui ficam só os logs.

## Padrões de qualidade exigidos

`quality-standards.md`. Em particular:

- **IaC (§2.3):** todas as mudanças via Terraform; nenhum clique manual no console; `terraform plan` sem drift ao final.
- **Segurança (§4):** segredos por Secret Manager + `secret_env_vars` no Job; SA do Scheduler com **só** `run.invoker`; nenhum segredo no state; gitleaks verde no pré-push.
- **Observabilidade (§3):** logs JSON estruturados em stderr (paridade com `cloud_run_api`); alerta de falha persistente continua ativo via log-based metric (ADR-011 §c + ADR-008).
- **Recriação do zero (§2.3):** `terraform destroy` + `apply` recria sem manual step.
- **Reversibilidade (princípio #7):** a Fase A é deliberadamente reversível (`module.worker` continua até a Fase B remover); a Fase B mantém o módulo `worker-vm` no repo mas **sem ninguém o instanciar** (decisão de excluir o módulo é estória futura — depois de algum tempo sem regressão).

## Dependências

- **Bloqueada por:** nenhuma. Toda a fiação (cloud-run, secrets, cloud-sql privado, IAM) já existe na `main`.
- **Bloqueia (formalmente):** STORY-025 (validador depende de topologia consolidada — sem Fase B aplicada, validador encontraria gambiarra com nota de rodapé).
- **Bloqueia (operacionalmente):** STORY-021 **CA-13** (E2E real). STORY-021 pode estar `in_progress` ao mesmo tempo; CA-13 só passa quando ao menos a **Fase A** desta estória estiver deployada em homolog. STORY-021 `done` exige Fase A no ar.
- **Pré-requisitos:** STORY-006/007 (infra de homolog viva), IDR-007 (Direct VPC egress + migrate-job como template).

## Decisões já tomadas (não as reabra)

- **ADR-004** — provedor GCP, alternativa Cloud Scheduler + Cloud Run Job pré-aprovada (§Negativas + §Sinais de revisão).
- **ADR-002** — fila `database`, worker como processo `queue:work`.
- **ADR-011** — Resend como provedor, `RESEND_API_KEY` no Secret Manager, alerta em falha persistente via ADR-008.
- **IDR-007** — Direct VPC egress + `volumes.cloud_sql_instance` em Cloud Run/Cloud Run Job é o padrão para Cloud SQL privado.

## Liberdade técnica do agente

Você decide:

- Estratégia exata para remover/condicionar `worker_stop`/`worker_start` no módulo `sql-scheduler` (remoção direta vs. flag `worker_vm_enabled`).
- Se a Fase A grava o env-file via `tmpfiles.d` ou `mount -t tmpfs`.
- Se o Cloud Scheduler usa a URL `:run` ou `gcloud beta run jobs execute` via Cloud Tasks (Scheduler `http_target` com OIDC é o caminho idiomático — preferir este, justificar se mudar).
- Nome do módulo (`worker-job` recomendado; outro nome aceitável se justificado).
- Se mantém o módulo `worker-vm` no repo após Fase B (recomendação: manter por um sprint para reversão fácil, remover em estória futura).

Você NÃO decide:

- Trocar provedor de hospedagem (ADR-004).
- Mudar para fila Redis (ADR-002).
- Pular Fase A indo direto para Fase B (decisão PO — Fase A é o desbloqueio da W25).
- Mudar a janela de Scheduler para algo > 1 min sem justificativa (afeta SLO de e-mail).
- Acionar o Job sem `--stop-when-empty` (afeta custo e idempotência da janela).

## Definição de Pronto (DoD)

- [ ] CA-1 a CA-12 passam com evidência (CA-13 declarado n/a).
- [ ] IDR-016 `accepted` (Alexandro aprovou em chat — mesmo padrão dos demais IDRs).
- [ ] `terraform plan` sem drift no estado final.
- [ ] Smoke E2E Fase B verde: aprovação → execução do Job → e-mail recebido.
- [ ] Runbook atualizado e revisado (seção "Worker").
- [ ] PR aberto; suíte completa verde (mesmo que infra-only); cobertura herdada pelos `apps/*` permanece como está.
- [ ] `index.json` atualizado.
- [ ] "Notas" preenchida.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Carregue `docs/skills/programador/SKILL.md`. **Sequência sugerida:** redigir IDR-016 (proposed) e abrir junto da Fase A → aplicar Fase A → smoke + sinal para STORY-021 fechar CA-13 → construir Fase B em commit separado → `terraform apply` Fase B → smoke Fase B → atualizar runbook → marcar IDR-016 `accepted` com OK do PO → marcar `done`.

## Notas do agente (preenchido durante/após execução)

### Entrada inicial

(a preencher na execução)

### Decisões tomadas

(a preencher)

### Descobertas

(a preencher)

### Bloqueios encontrados

(a preencher)

### IDRs criados

- IDR-016 — worker em Cloud Run Job + Cloud Scheduler substitui GCE worker-vm (a redigir).

### Cobertura final

n/a (estória de infra).

### Resultado final / evidência

(a preencher)

### Links de evidência

(a preencher)
