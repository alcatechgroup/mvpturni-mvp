# Runbook — Homologação Turni (GCP)

> Versão: STORY-007. Ambiente: `app.homolog.turni.com.br` / `admin.homolog.turni.com.br` / `api.homolog.turni.com.br`.

## Pré-requisitos (1x, feitos pelo Alexandro)

1. **Conta GCP com créditos ativos** e projeto criado (ex: `turni-homolog-XXXXXX`).
2. **Terraform CLI ≥ 1.9** instalado localmente.
3. **gcloud CLI** autenticado: `gcloud auth application-default login`.
4. **Registro do domínio `turni.com.br`** — delegação de DNS será para o Cloud DNS.
5. **Firebase CLI**: `npm install -g firebase-tools && firebase login`.

---

## Bootstrap (rodar 1 vez antes do primeiro `terraform apply`)

```bash
# 1. Crie o bucket do Terraform state (nome único global)
gcloud storage buckets create gs://turni-terraform-state \
  --project=SEU_PROJECT_ID \
  --location=southamerica-east1 \
  --uniform-bucket-level-access

# 2. Habilite o versionamento (segurança do state)
gcloud storage buckets update gs://turni-terraform-state \
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

### Configurar GitHub secrets (1x)

No repositório GitHub → Settings → Secrets and variables → Actions:

| Secret | Valor (do terraform output) |
|--------|-----------------------------|
| `GCP_PROJECT_ID` | ID do projeto GCP |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | `wif_provider` output |
| `GCP_SERVICE_ACCOUNT` | `ci_service_account` output |
| `FIREBASE_SERVICE_ACCOUNT` | JSON da service account CI (para firebase deploy) |

### Configurar DNS (1x)

O Cloud DNS cria a zona `turni.com.br`. Após o apply:
```bash
gcloud dns managed-zones describe turni-com-br \
  --project=SEU_PROJECT_ID \
  --format='value(nameServers)'
```
Configure esses name servers no registrador do domínio `turni.com.br`.

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
firebase hosting:rollback --site=turni-webapp-homolog --project=turni-mvp
```

**Via REST API** (sempre disponível com `gcloud auth`):
```bash
# 1. Listar releases para identificar a versão anterior
ACCESS_TOKEN=$(gcloud auth print-access-token)
curl -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "x-goog-user-project: turni-mvp" \
  "https://firebasehosting.googleapis.com/v1beta1/projects/turni-mvp/sites/turni-webapp-homolog/releases?pageSize=5"

# 2. Criar nova release apontando para a versão anterior
PREV_VERSION="projects/turni-mvp/sites/turni-webapp-homolog/versions/XXXXXXXXXXXXXXXXX"
curl -X POST \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "x-goog-user-project: turni-mvp" \
  -H "Content-Type: application/json" \
  -d '{}' \
  "https://firebasehosting.googleapis.com/v1beta1/projects/turni-mvp/sites/turni-webapp-homolog/releases?versionName=${PREV_VERSION}"
```

### Evidência de execução — 2026-05-28

**Cloud Run admin:**
- **Revisão N** (boa): `turni-admin-homolog-00025-yuh` (v0.1.0-rc.9, curl /health → 200)
- **Revisão N+1** (regressão simulada): `turni-admin-homolog-00017-tb2` (v0.1.0-rc.9-bad-deploy, versão incorreta no ar)
- **Rollback executado** (2026-05-28 ~13:52 UTC):
  ```
  gcloud run services update-traffic turni-admin-homolog \
    --to-revisions=turni-admin-homolog-00025-yuh=100 \
    --region=southamerica-east1 --project=turni-mvp
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
