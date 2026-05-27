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

## Deploy de release (fluxo normal, CA-4)

```bash
# 1. Merge o PR na main (CI leve deve estar verde)
# 2. Na sua máquina local, a partir do commit na main:
git tag v0.1.0-rc.1
git push origin v0.1.0-rc.1
# 3. O GitHub Actions release.yml dispara automaticamente
# 4. Acompanhe em: https://github.com/SEU_REPO/actions
```

O pipeline: build → push Artifact Registry → deploy Cloud Run (api + admin) →
deploy Firebase Hosting (webapp) → health checks → verde.

Tempo esperado: ≤ 10 min (CA-4).

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

```bash
# Ver deployments anteriores
firebase hosting:releases:list --site=turni-webapp-homolog

# Rollback para o release anterior
firebase hosting:rollback --site=turni-webapp-homolog
```

### Banco de dados

Sem rollback de schema — política forward-only (ADR-004 seção Rollback).
Para dados corrompidos: point-in-time recovery via Cloud SQL (backup automático habilitado).

```bash
gcloud sql backups list --instance=turni-homolog --project=SEU_PROJECT_ID
```

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
