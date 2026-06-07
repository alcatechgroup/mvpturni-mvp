# Runbook — Homologação Turni (GCP)

> Versão: STORY-007. Ambiente: `app.homolog.turni.com.br` / `admin.homolog.turni.com.br` / `api.homolog.turni.com.br`.
>
> **Modelo de 3 projetos independentes** (ver `runbook-setup-prod-e-stage.md`): o homolog
> vive no projeto GCP **`turni-homol`** (billing Créditos RHHUB), state em
> `gs://turni-homol-tfstate` (prefix `homolog`), e a zona DNS é o **subdomínio
> `homolog.turni.com.br`** (zona própria, delegada pela apex `turni.com.br` que mora no
> `turni-prod`) — não mais a zona apex.

## Pré-requisitos (1x, feitos pelo Alexandro)

1. **Projeto GCP `turni-homol`** criado e vinculado ao billing Créditos RHHUB
   (`016CC2-FEFBB5-8F2968`) — ver bootstrap em `runbook-setup-prod-e-stage.md`.
2. **Terraform CLI ≥ 1.9** instalado localmente.
3. **gcloud CLI** autenticado: `gcloud auth application-default login`.
4. **Registro do domínio `turni.com.br`** — delegação de DNS será para o Cloud DNS.
5. **Firebase CLI**: `npm install -g firebase-tools && firebase login`.

---

## Bootstrap (rodar 1 vez antes do primeiro `terraform apply`)

```bash
# 1. Crie o bucket do Terraform state (nome único global)
gcloud storage buckets create gs://turni-homol-tfstate \
  --project=SEU_PROJECT_ID \
  --location=southamerica-east1 \
  --uniform-bucket-level-access

# 2. Habilite o versionamento (segurança do state)
gcloud storage buckets update gs://turni-homol-tfstate \
  --versioning

# 3. Copie o exemplo de vars e preencha
cp infra/envs/homolog/terraform.tfvars.example infra/envs/homolog/terraform.tfvars
# Edite infra/envs/homolog/terraform.tfvars com os valores reais
```

---

## Provisionar homologação do zero (CA-8 / CA-9)

```bash
cd infra/envs/homolog

terraform init
terraform plan   # revisar antes de aplicar
terraform apply  # ~10-15 min na primeira vez (Cloud SQL demora)
```

**Após o apply**, o Terraform exibe os outputs. Anote:
- `wif_provider` → GitHub secret `GCP_WORKLOAD_IDENTITY_PROVIDER`
- `ci_service_account` → GitHub secret `GCP_SERVICE_ACCOUNT`
- `firebase_site_id` → atualizar `.firebaserc` com o project_id real

### Configurar GitHub secrets (1x) — por GitHub Environment

Modelo de 3 projetos: os secrets são do **GitHub Environment `homolog`** (não do repositório),
para não colidir com `stage`/`prod`. Em Settings → Environments → `homolog`:

| Secret | Valor (do terraform output) |
|--------|-----------------------------|
| `GCP_PROJECT_ID` | `turni-homol` |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | `wif_provider` output |
| `GCP_SERVICE_ACCOUNT` | `ci_service_account` output |

> Deploy do Firebase é **keyless** (firebase CLI usa a credencial WIF como ADC) — sem
> `FIREBASE_SERVICE_ACCOUNT`. A SA CI já tem `roles/firebasehosting.admin`.

### Configurar DNS (1x) — subdomínio delegado

O Cloud DNS cria a zona **`homolog.turni.com.br`** (zona própria do `turni-homol`). Após o apply:
```bash
gcloud dns managed-zones describe homolog-turni-com-br \
  --project=turni-homol \
  --format='value(nameServers)'   # = output `dns_name_servers`
```
Esses nameservers **NÃO** vão para o registro.br. Eles entram na var `delegations` do env
`prod` (zona apex `turni.com.br` no `turni-prod`), que publica o registro NS de delegação
`homolog.turni.com.br NS …`. Reaplique o `turni-prod` para criar a delegação. Detalhes em
`runbook-setup-prod-e-stage.md`.

### Configurar Firebase targets (1x)

Edite `.firebaserc` com o project ID real e os site IDs do Terraform output.

---

## Fazer deploy manual (sem criar tag)

**Não use.** Deploys são sempre via tag `vX.Y.Z-rc.N` (ADR-004 / CA-6). Deploy manual
viola a rastreabilidade. Se precisar de emergência, crie uma nova tag.

---

## Antes de criar tag rc.N — checklist obrigatório (IDR-004)

E2E em browser real é gate **local**. O pipeline pós-deploy faz apenas smoke curl,
então quem cria a tag carrega a responsabilidade de ter rodado Playwright contra
o ambiente local:

```bash
# 1. Ambiente local de pé (containers + WebApp + seed)
make up
docker compose exec api php artisan migrate --force && \
  docker compose exec api php artisan db:seed --force   # usuários de teste do CA-13

# 2. E2E Playwright contra localhost:8002 + localhost:8003
make e2e
# Falha aqui = NÃO crie a tag. Corrija e re-rode.
```

Quem pula este passo está deployando regressão visual / interação para homolog
sem rede de proteção automatizada. O smoke curl no pipeline pega 5xx/404, mas
não pega CSS quebrado nem label faltando.

> **Cobertura do `make e2e`:** Backoffice (HTML real) + WebApp Flutter completos —
> login, RBAC e funnel guard rodam em browser real. O WebApp ativa a árvore de
> semantics do Flutter (`gotoApp` clica no placeholder "Enable accessibility") e
> usa `usePathUrlStrategy()`, então `/login`, `/welcome` e `/app` funcionam como
> paths reais. Único `skipped`: `/health` JSON do WebApp, que é artefato de build
> (Firebase serve `health.json` em homolog) e não existe no dev local.
> `make e2e` rebuilda o WebApp e roda o seed automaticamente antes dos testes.

---

## Deploy de release (fluxo normal, CA-4)

```bash
# 1. Merge o PR na main (CI leve deve estar verde)
# 2. `make e2e` local verde (ver checklist acima)
# 3. Na sua máquina local, a partir do commit na main:
git tag v0.1.0-rc.1
git push origin v0.1.0-rc.1
# 4. O GitHub Actions release.yml dispara automaticamente
# 5. Acompanhe em: https://github.com/SEU_REPO/actions
```

O pipeline: build → push Artifact Registry → deploy Cloud Run (api + admin) →
deploy Firebase Hosting (webapp) → health checks → **smoke curl** (`/health` +
`/version.json` nas 3 interfaces) → verde.

Tempo esperado: ≤ 10 min (CA-4). Smoke curl substitui o antigo job de E2E
Playwright pós-deploy (IDR-004) — pipeline ganha minutos de volta a cada release.

---

## Verificar versão deployada (CA-7d)

```bash
TAG="v0.1.0-rc.1"

curl -s https://api.homolog.turni.com.br/version.json
# {"version":"v0.1.0-rc.1"}

curl -s https://admin.homolog.turni.com.br/version.json
# {"version":"v0.1.0-rc.1"}

curl -s https://app.homolog.turni.com.br/version.json
# {"version":"v0.1.0-rc.1"}
```

Se qualquer resposta for `{"version":"dev"}` ou diferente do `$TAG`, o stamping falhou.

---

## Rollback (CA-10)

### Cloud Run (api ou admin) — instantâneo

```bash
# Listar revisions disponíveis
gcloud run revisions list \
  --service=turni-api-homolog \
  --region=southamerica-east1 \
  --project=SEU_PROJECT_ID \
  --sort-by=~DEPLOYED

# Redirecionar tráfego para a revision anterior
PREV_REVISION="turni-api-homolog-XXXXXXXX"   # ajustar
gcloud run services update-traffic turni-api-homolog \
  --to-revisions="${PREV_REVISION}=100" \
  --region=southamerica-east1 \
  --project=SEU_PROJECT_ID
```

### Firebase Hosting (webapp)

**Via Firebase CLI** (se autenticado com conta com acesso ao projeto):
```bash
firebase hosting:rollback --site=turni-webapp-homolog --project=turni-homol
```

**Via REST API** (sempre disponível com `gcloud auth`):
```bash
# 1. Listar releases para identificar a versão anterior
ACCESS_TOKEN=$(gcloud auth print-access-token)
curl -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "x-goog-user-project: turni-homol" \
  "https://firebasehosting.googleapis.com/v1beta1/projects/turni-homol/sites/turni-webapp-homolog/releases?pageSize=5"

# 2. Criar nova release apontando para a versão anterior
PREV_VERSION="projects/turni-homol/sites/turni-webapp-homolog/versions/XXXXXXXXXXXXXXXXX"
curl -X POST \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "x-goog-user-project: turni-homol" \
  -H "Content-Type: application/json" \
  -d '{}' \
  "https://firebasehosting.googleapis.com/v1beta1/projects/turni-homol/sites/turni-webapp-homolog/releases?versionName=${PREV_VERSION}"
```

### Evidência de execução — 2026-05-28

**Cloud Run admin:**
- **Revisão N** (boa): `turni-admin-homolog-00025-yuh` (v0.1.0-rc.9, curl /health → 200)
- **Revisão N+1** (regressão simulada): `turni-admin-homolog-00017-tb2` (v0.1.0-rc.9-bad-deploy, versão incorreta no ar)
- **Rollback executado** (2026-05-28 ~13:52 UTC):
  ```
  gcloud run services update-traffic turni-admin-homolog \
    --to-revisions=turni-admin-homolog-00025-yuh=100 \
    --region=southamerica-east1 --project=turni-homol
  ```
- **Resultado**: curl /health → 200, `{"version":"v0.1.0-rc.9","service":"backoffice"}` ✅

**Firebase Hosting webapp:**
- **Antes do rollback**: versão `933d13e5bdcccc75` (v0.1.0-rc.9)
- **Rollback para**: versão `1f7779c648c347d9` (v0.1.0-rc.8), release `1779976471313000` (type: ROLLBACK)
- **Verificado** (2026-05-28 13:54 UTC): curl /health → `{"version":"v0.1.0-rc.8"}` ✅
- **Restaurado** para rc.9 após teste: release `1779976494676000` (type: ROLLBACK, volta a rc.9)

### Banco de dados

Sem rollback de schema em produção — política forward-only (ADR-004 seção Rollback).
Para dados corrompidos: point-in-time recovery via Cloud SQL (backup automático habilitado).

```bash
gcloud sql backups list --instance=turni-homolog --project=SEU_PROJECT_ID
```

---

## Migrações em homologação (Cloud Run Job — IDR-007)

O `release.yml` roda um **Cloud Run Job** (`turni-migrate-homolog`, imagem da release)
que faz `migrate --force && db:seed --force` antes dos deploys fliparem tráfego. O job
tem **Direct VPC egress** (Cloud SQL é IP privado) e liga a instância se o scheduler a
desligou. Executar manualmente:

```bash
gcloud run jobs execute turni-migrate-homolog --region=southamerica-east1 --wait
```

> ⚠️ **Scheduler de economia:** o Cloud SQL `turni-homolog` desliga seg–sex 22h BRT e
> fica desligado no fim de semana. Se o login der **500/502** ou `/health?deep=1` der
> **503**, o banco provavelmente está desligado. Ligue:
> `gcloud sql instances patch turni-homolog --activation-policy=ALWAYS` (o scheduler
> volta a desligá-lo no próximo ciclo).

### Rollback de migração — evidência F-NB-1 / CA-2 {#rollback-migracoes}

`migrate:rollback`/`reset` exercido em homolog. Bug pego e corrigido aqui: o `down()` de
`add_identity_columns_to_users_table` chamava `dropConstrainedForeignId` numa CHECK
constraint e abortava o rollback (commit `806ce03`).

**Evidência — 2026-05-29** (execução `turni-migrate-homolog-x476q`, imagem `v0.1.0-rc.19`):

```
>>> RESET (reverte TODAS as migracoes)
   INFO  Rolling back migrations.
  …add_identity_columns_to_users_table … DONE   # antes dava FAIL
  …create_admin_audit_log_table … DONE
  (todas as 10 migrações revertidas, 0 FAIL)
>>> REPLAY
   INFO  Running migrations.
  (todas as 10 re-aplicadas, 0 FAIL)
>>> SEED
  AdminUserSeeder … DONE
```

Comando: `php artisan migrate:reset --force && php artisan migrate --force && php artisan db:seed --force` (via Cloud Run Job). `down()` reversível e replay sem erro confirmados.

### Rollback das migrações do Turno — evidência STORY-055 / ADR-015 (CA-6) {#rollback-turnos}

As duas migrações do EPIC-003 (`2026_06_03_150000_create_turnos_table`,
`2026_06_03_150001_create_aceites_eletronicos_turno_table`) carregam lógica de negócio real
(CHECK financeiro, trigger `enforce_turno_transition` da máquina de estados, trigger de
imutabilidade do aceite + REVOKE). `down()` simétrico: drop trigger → drop function → drop
table → drop type (`turno_status`).

**Evidência local (Postgres 18, `turni_test`) — 2026-06-03:**

```
>>> migrate:rollback --step=2
  2026_06_03_150001_create_aceites_eletronicos_turno_table … DONE
  2026_06_03_150000_create_turnos_table … DONE
>>> migrate (replay)
  2026_06_03_150000_create_turnos_table … DONE
  2026_06_03_150001_create_aceites_eletronicos_turno_table … DONE
```

**Procedimento em homolog (no deploy do EPIC-003):** o CD roda `migrate --force` (forward-only,
ADR-004). Para exercer o rollback como evidência F-NB-1, executar pelo Cloud Run Job de
migração: `php artisan migrate:rollback --step=2 --force && php artisan migrate --force`.
Como `turno_status` é um tipo nativo, em `migrate:fresh` use `--drop-types` (mesma nota da
STORY-070). Nenhuma FK externa aponta para `aceites_eletronicos_turno`; o REVOKE de UPDATE/
DELETE nela é seguro (não é tabela-pai — ver ADR-015 Decisão 4).

### Imutabilidade do audit log — evidência CA-15

`admin_audit_log` é append-only (trigger `prevent_admin_audit_log_mutation` BEFORE
UPDATE/DELETE + REVOKE — ADR-009 Decisão 4A). Tentativa de mutação em homolog:

**Evidência — 2026-05-29** (execução `turni-migrate-homolog-6ksds`):

```
CA15_RESULT update=BLOQUEADO delete=BLOQUEADO id=1
```

INSERT permitido (append-only); UPDATE e DELETE **bloqueados** pelo trigger. Teste:
inserir uma linha em `admin_audit_log` e tentar `update`/`delete` nela — ambos lançam
exceção "Audit log is immutable".

---

## Worker (Cloud Run Job — IDR-016)

O worker da fila (`queue:work`) é um **Cloud Run Job** (`turni-worker-job-homolog`),
**não** mais uma VM GCE. Um **Cloud Scheduler** (`turni-worker-scheduler-homolog`,
cron `* * * * *`, BRT) dispara o Job a cada 1 min; o Job roda
`php artisan queue:work database --stop-when-empty` e **termina quando a fila
esvazia**. A definição (env, segredos, Direct VPC egress, socket Cloud SQL) é do
Terraform (`infra/modules/worker-job`); o `release.yml` só atualiza a imagem a cada
release (`gcloud run jobs update`, mesmo contrato do api/admin). Latência de pickup:
até ~60s (cabe nos SLOs de e-mail e Pix — ver IDR-016).

```bash
P=turni-homol; R=southamerica-east1

# Listar execuções do worker
gcloud run jobs executions list --job=turni-worker-job-homolog --region=$R --project=$P

# Rodar manualmente (debug — não espera o tick do Scheduler)
gcloud run jobs execute turni-worker-job-homolog --region=$R --project=$P --wait

# Ver logs do Job (JSON estruturado em stderr)
gcloud logging read \
  'resource.type="cloud_run_job" AND resource.labels.job_name="turni-worker-job-homolog"' \
  --project=$P --limit=50 --format=json | jq '.[] | .jsonPayload'
```

> 🔴 **Kill-switch (pausar a fila em emergência):**
> ```bash
> gcloud scheduler jobs pause turni-worker-scheduler-homolog --location=$R --project=$P
> # retomar:
> gcloud scheduler jobs resume turni-worker-scheduler-homolog --location=$R --project=$P
> ```
> Pausar o Scheduler interrompe novos disparos; execuções em andamento drenam a fila e saem.

> ⚠️ **Cloud SQL desligado:** o worker conecta no Cloud SQL por socket (Direct VPC
> egress). Se o banco estiver desligado (seg–sex 22h BRT / fim de semana), as execuções
> falham até o banco voltar — mesma janela de economia documentada na seção de migração.

> ↩️ **Reversão de emergência (IDR-016):** o módulo `worker-vm` permanece no repo
> desabilitado por um sprint. Reverter = trocar `module "worker_job"` por
> `module "worker"` em `infra/envs/homolog/main.tf` e `terraform apply`.

---

## Scheduler do Laravel (Cloud Run Job — STORY-073)

O Scheduler do Laravel (`php artisan schedule:run`) roda como um **segundo Cloud Run
Job** (`turni-scheduler-job-homolog`), disparado por um **Cloud Scheduler** próprio
(`turni-scheduler-scheduler-homolog`, cron `* * * * *`, BRT). É **separado do worker
da fila de propósito**: kill-switch independente — pausar a fila não desliga o cron e
vice-versa. Cada tick avalia os `Schedule::command(...)` de `apps/api/routes/console.php`
e executa o que estiver "due" no minuto (auto-retirada pós-edição PDR-009, lembretes de
cadastro 09:00 BRT, sweeper de e-mail, detecção de no-show). Mesma fiação do worker
(módulo `infra/modules/worker-job` parametrizado; `release.yml` atualiza a imagem a
cada release; mesma imagem da api).

**Verificar que está rodando:**

```bash
P=turni-homol; R=southamerica-east1

# Execuções do tick (deve haver ~1/min, estado Succeeded)
gcloud run jobs executions list --job=turni-scheduler-job-homolog --region=$R --project=$P

# Logs (JSON em stderr): comandos disparados nos últimos 60 min
gcloud logging read \
  'resource.type="cloud_run_job" AND resource.labels.job_name="turni-scheduler-job-homolog"' \
  --project=$P --freshness=1h --limit=100 --format=json | jq -r '.[] | .textPayload // .jsonPayload.message'

# Rodar manualmente (debug — não espera o tick)
gcloud run jobs execute turni-scheduler-job-homolog --region=$R --project=$P --wait
```

> 🔴 **Kill-switch (pausar o cron em emergência):**
> ```bash
> gcloud scheduler jobs pause turni-scheduler-scheduler-homolog --location=$R --project=$P
> # retomar:
> gcloud scheduler jobs resume turni-scheduler-scheduler-homolog --location=$R --project=$P
> ```
> Pausar interrompe novos ticks; o tick em andamento termina o que está executando.
> Agendamentos perdidos durante a pausa **não são reexecutados** retroativamente
> (`dailyAt` perdido só roda no dia seguinte; `everyMinute` retoma no próximo tick).

> ⚠️ **Cloud SQL desligado** (seg–sex 22h BRT / fim de semana): os ticks falham até o
> banco voltar — mesmo comportamento e mesma janela de economia do worker. Sem efeito
> colateral: o tick seguinte ao religamento processa normalmente.

> 🏭 **Produção:** o espelho exato existe em `infra/envs/prod/main.tf`
> (`module "scheduler_job"` → `turni-scheduler-job-prod`), **gated** como todo o
> ambiente prod — só entra com a aprovação manual do go-live (EPIC-006); nomes dos
> comandos acima trocam `homolog` por `prod`.

---

## Fake de pagamento em homolog (PDR-017 / ADR-016 / STORY-056+065) {#fake-pagamento}

O gateway de pagamento **efetivo** do MVP em homolog é o fake genérico
(`turni-pagarme-mock-homolog`, Cloud Run, imagem `pagarme-mock` na matrix do
`release.yml`). Ele processa pré-auth/captura/Pix no contrato Pagar.me-compatível
(`docs/project-state/integrations/pagarme/contract.md`) e devolve o **webhook
assinado** ao `api`. Este bloco inteiro sai quando o PSP real entrar (próxima wave).

**Deploy:** automático pela tag (`release.yml` → job "Deploy fake Pagar.me → homolog");
o serviço em si é provisionado por Terraform (`infra/envs/homolog/main.tf`,
resource `google_cloud_run_v2_service.pagarme_mock` — sem Cloud SQL/VPC).

**Segredos (Secret Manager, ADR-004), compartilhados com api/worker:**

- `turni-homolog-pagarme-secret-key` — Bearer; barra POST anônimo no fake (`401`).
- `turni-homolog-pagarme-webhook-secret` — HMAC do webhook; o `api` valida a
  assinatura em `POST /api/webhooks/pagarme` (assinatura inválida → 401).

Rotacionar = nova `secret_version` via `terraform apply` (os 3 consumidores leem
`latest`; forçar nova revisão dos serviços para recarregar).

**Modos configuráveis** (variáveis Terraform → env do serviço):

| Env | Valores | Efeito |
|---|---|---|
| `PAGARME_MOCK_PIX_RESULTADO` | `sucesso` (default) \| `falha` | `falha` emite `transfer.failed` determinístico → exercita a fila "Falhas de pagamento" do admin |
| `PAGARME_MOCK_PIX_SLA_SEGUNDOS` | `30` em homolog | atraso do webhook do Pix (simula a promessa "Pix ≤ 15 min"); a resposta HTTP não espera |

Mudar modo: editar `pagarme_mock_pix_resultado`/`pagarme_mock_pix_sla_segundos` em
`terraform.tfvars` + `terraform apply`. Para um teste rápido vale
`gcloud run services update turni-pagarme-mock-homolog --region=southamerica-east1 --update-env-vars=PAGARME_MOCK_PIX_RESULTADO=falha`,
mas o próximo `apply`/deploy **restaura o tfvars** — não esquecer de voltar.

> ⚠️ O sleep do SLA exige **CPU always-allocated** (`cpu_idle=false`) — com throttle o
> webhook atrasado congela. Já configurado no Terraform; não "otimizar" de volta.

## Cronômetro travado — diagnóstico e reset {#reset-cronometro}

O cronômetro **não tem estado próprio**: é uma duração derivada da âncora
(`GET /api/turnos/{id}/cronometro` → `iniciado_em` = `check_in_at` + `servidor_agora`;
ADR-017). "Travado" portanto é sempre um destes casos:

1. **Display congelado no browser** — perda de polling. O card mostra "Reconectando…
   O tempo continua valendo." após 30s e se recupera sozinho no primeiro polling que
   volta; hard-refresh resolve na hora. Sem ação de servidor.
2. **Turno seed do E2E/demonstração envelheceu** (par `*.cronometro.seed` com
   `check_in_at` antigo → duração gigante): re-executar o seed, que renova a âncora
   (~35min decorridos):

   ```bash
   gcloud run jobs execute turni-migrate-homolog --region=southamerica-east1 --wait
   ```

   ⚠️ o reseed **derruba sessões abertas** no browser (relogar em `/login`).
3. **Turno real preso em `ativo`** (check-out nunca aconteceu): o caminho correto é o
   produto — profissional gera PIN de check-out e contratante valida (ou recusa).
   Não force `UPDATE turnos SET status=…`: o trigger `enforce_turno_transition` barra
   transições inválidas e o estado deve nascer das ações (PIN + audit). Se as partes
   não puderem agir, escale ao PO — decisão de produto, não de operação.

## Pix com falha — tratamento manual (PDR-010 / STORY-065) {#pix-com-falha}

PDR-010: **uma tentativa de Pix, sem retry automático** — falha vira caso operacional.

1. **Simular o cenário** (determinístico): fake com `PAGARME_MOCK_PIX_RESULTADO=falha`
   (ver seção acima) e percorrer um ciclo até `finalizado`. O webhook `transfer.failed`
   gera audit `pix.falhou` + caso aberto em `pix_falhas`.
2. **Tratar**: Backoffice → **Falhas de pagamento** (`/pix-falhas`, contador vermelho na
   sidebar). Cada caso traz badge (`Pix falhou` / `Liberação falhou`), valor, chave Pix
   decifrada (IDR-028 — segredo `turni-homolog-pix-falha-chave-key`) e razão do gateway.
   Resolver exige **nota obrigatória** → audit `pix_falha.resolvida` no
   `admin_audit_log`; o caso migra para a aba "Resolvidos".
3. **Regras**: `PixEnviado` tardio **não** fecha caso aberto; `PixFalhou` tardio **não**
   reabre caso resolvido — resolução humana é final. Linha com chave indecifrável
   degrada para "chave não cadastrada" (warning `pix_falha.chave_indecifravel`) sem
   derrubar a fila.
4. **Restaurar** o fake para `sucesso` ao terminar (tfvars + apply).

---

## E-mail transacional — verificação do remetente (STORY-021 CA-3)

Remetente: `no-reply@mail.homolog.turni.com.br` (Resend — ADR-011). SPF/DKIM/DMARC
aplicados via Terraform (`infra/modules/dns` + `infra/envs/homolog`) e domínio
**verificado no painel Resend** ("ready to send"). Verificação externa por `dig`:

```bash
dig +short TXT  send.mail.homolog.turni.com.br        # SPF
dig +short TXT  resend._domainkey.mail.homolog.turni.com.br  # DKIM (chave pública)
dig +short TXT  _dmarc.mail.homolog.turni.com.br       # DMARC
dig +short MX   send.mail.homolog.turni.com.br         # MX (bounces)
```

**Evidência — 2026-05-30** (resolvendo no NS autoritativo):

```
SPF   → "v=spf1 include:amazonses.com ~all"
DKIM  → "p=MIGfMA0GCSqGSIb3DQEB...QAB"  (RSA pública gerada pelo Resend)
DMARC → "v=DMARC1; p=none;"             (escopado no subdomínio, não toca o apex)
MX    → 10 feedback-smtp.sa-east-1.amazonses.com.
```

Envios reais confirmados com DKIM assinado (`message_id` `…@mail.homolog.turni.com.br`):
`aprovacao_concedida` (aprovação real no Backoffice) e `recuperacao_senha` (reset E2E),
ambos entregues à inbox de teste. **Pendência de reputação:** o e-mail caiu em
Spam/Lixeira no Gmail — esperado para subdomínio remetente novo (warmup). Mitigações
(p=quarantine no DMARC após warmup, aquecimento de volume, eventual IP dedicado) ficam
para acompanhamento operacional pós go-live, não bloqueiam o EPIC-001.

---

## Acessar logs (CA-12, CA-13)

```bash
# Últimas 100 linhas do api (JSON estruturado)
gcloud logging read \
  'resource.type="cloud_run_revision" AND resource.labels.service_name="turni-api-homolog"' \
  --project=SEU_PROJECT_ID \
  --limit=100 \
  --format=json | jq '.[] | .jsonPayload'

# Rastrear por request_id
REQUEST_ID="01J9ZXXXXXXXX"
gcloud logging read \
  "jsonPayload.request_id=\"${REQUEST_ID}\"" \
  --project=SEU_PROJECT_ID \
  --format=json | jq '.[] | {service: .jsonPayload.service, event: .jsonPayload.event, status: .jsonPayload.status_code}'
```

---

## Destruir homologação (reset completo)

```bash
cd infra/envs/homolog
terraform destroy
# ⚠ irreversível — apaga Cloud SQL (dados perdidos), Cloud Run, Firebase site, DNS
```

---

## Alertas de saúde

Cloud Monitoring faz uptime check a cada 60s em `/health` de api e admin, e `/` do
webapp. Falha sustentada por 120s dispara e-mail para `xandroalmeida@gmail.com`.

Para ver alertas ativos:
```bash
gcloud alpha monitoring incidents list --project=SEU_PROJECT_ID
```
