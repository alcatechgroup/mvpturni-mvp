# Runbook — Reestruturação GCP: 3 projetos independentes (homol / stage / prod)

> Status: **proposta executável** (gate humano antes de qualquer `terraform apply` / cutover de DNS).
> Decisão (Alexandro, 2026-06-07): sair de um único `turni-mvp` para **3 projetos GCP
> independentes** — `turni-homol`, `turni-stage`, `turni-prod` — todos na billing
> **Créditos RHHUB** (`016CC2-FEFBB5-8F2968`). homol e stage **ligados**; prod **parado**
> (custo ~zero) até o go-live (EPIC-006). Sem singletons compartilhados.
> Base: ADR-004 (multi-ambiente/IaC), IDR-016 (worker Cloud Run Job), ADR-000 (Cloud SQL).

> ⚠️ ID de projeto GCP é **imutável** — não dá para renomear `turni-mvp`. O homolog é
> **recriado limpo** no `turni-homol` (ambiente de teste, sem dado precioso) e o `turni-mvp`
> é aposentado no fim, depois da validação e da propagação de DNS.

---

## Visão geral

| Projeto | Estado | Zona DNS própria | State bucket (prefix) | Cloud SQL | Cloud Run |
|---|---|---|---|---|---|
| `turni-homol` | ligado | `homolog.turni.com.br` | `turni-homol-tfstate` (`homolog`) | `db-f1-micro` + sql-scheduler | min=0 |
| `turni-stage` | ligado | `stage.turni.com.br` | `turni-stage-tfstate` (`stage`) | `db-f1-micro` + sql-scheduler | min=0 |
| `turni-prod` | **parado** | `turni.com.br` (apex) + delegações | `turni-prod-tfstate` (`prod`) | `activation_policy=NEVER` (STOPPED) | min=0 |

**DNS — delegação por subdomínio.** A zona apex `turni.com.br` vive no `turni-prod`. O
`registro.br` delega `turni.com.br` para os nameservers dessa zona (cutover único). A apex
publica registros **NS de delegação** para os subdomínios das zonas filhas
(`homolog.turni.com.br` → `turni-homol`, `stage.turni.com.br` → `turni-stage`). Custo da apex
parada = uma managed zone (~US$0,20/mês), desprezível.

### O que já está no código (Terraform parametrizado)
- Módulo `dns`: `zone_dns_name` (zona de subdomínio) + `delegations` (NS na apex) + output `name_servers`.
- Módulo `cloud-sql`: var `activation_policy` (`NEVER` no prod parado; `ignore_changes` para o sql-scheduler/patch manual não brigarem com o TF).
- Módulo `worker-job`: var `scheduler_paused` (Cloud Scheduler pausado no prod parado).
- `infra/envs/homolog`: backend `turni-homol-tfstate`; DNS = zona `homolog.turni.com.br`.
- `infra/envs/stage`: **novo**, espelho do homolog (env independente, `iam`+`artifact-registry` próprios), VPC `10.3.0.0/24`.
- `infra/envs/prod`: backend `turni-prod-tfstate`; flag `prod_live_enabled` (default false) governa min_instances/schedulers/monitoring; cloud_sql `NEVER`; zona apex + var `delegations`.

---

## Ordem de execução

### Passo A — Criar os 3 projetos + vincular billing (manual)
```bash
for p in turni-homol turni-stage turni-prod; do
  gcloud projects create "$p" --name="Turni ${p#turni-}"
  gcloud billing projects link "$p" --billing-account=016CC2-FEFBB5-8F2968
done
```

### Passo B — Um state bucket por projeto (manual)
```bash
for p in turni-homol turni-stage turni-prod; do
  gcloud storage buckets create "gs://$p-tfstate" --project="$p" \
    --location=southamerica-east1 --uniform-bucket-level-access
  gcloud storage buckets update "gs://$p-tfstate" --versioning
done
```
Garanta `roles/storage.objectAdmin` da sua identidade em cada bucket.

### Passo C — tfvars de cada env
```bash
cp infra/envs/homolog/terraform.tfvars.example infra/envs/homolog/terraform.tfvars
cp infra/envs/stage/terraform.tfvars.example   infra/envs/stage/terraform.tfvars
cp infra/envs/prod/terraform.tfvars.example    infra/envs/prod/terraform.tfvars
```
Preencha cada um (project_id já vem certo nos exemplos). Gere `app_key_*`
(`php artisan key:generate --show`), `db_password`, e os segredos de pagamento/Pix
(`openssl rand -hex 24`, `php -r "echo 'base64:'.base64_encode(random_bytes(32));"`).
**Nunca commitar** (gitignored).

### Passo D — Aplicar o `turni-prod` (1ª passada: cria a zona apex)
```bash
cd infra/envs/prod && terraform init && terraform plan && terraform apply   # gate humano
terraform output dns_name_servers   # nameservers da apex turni.com.br
```
Com `prod_live_enabled=false`: Cloud Run min=0, schedulers pausados, monitoring off, SQL `NEVER`
(sobe STOPPED). Custo ~zero. Confirme:
```bash
gcloud sql instances describe turni-prod --project=turni-prod --format='value(state)'  # STOPPED
```

### Passo E — Cutover de DNS no registro.br (manual, único)
Aponte os NS de `turni.com.br` para os nameservers do passo D.
⚠️ **Não destrua o `turni-mvp` antes da propagação** — o homolog atual continua resolvendo
enquanto o registro.br ainda apontar para ele.

### Passo F — Aplicar `turni-homol` e `turni-stage`
```bash
cd infra/envs/homolog && terraform init && terraform plan && terraform apply
terraform output dns_name_servers   # NS da zona homolog.turni.com.br

cd ../stage && terraform init && terraform plan && terraform apply
terraform output dns_name_servers   # NS da zona stage.turni.com.br
```

### Passo G — Delegação na apex (2ª passada do prod)
Preencha `delegations` no `infra/envs/prod/terraform.tfvars` com os outputs do passo F:
```hcl
delegations = {
  "homolog.turni.com.br" = ["ns-cloud-XX.googledomains.com.", ...]   # do turni-homol
  "stage.turni.com.br"   = ["ns-cloud-YY.googledomains.com.", ...]   # do turni-stage
}
```
`cd infra/envs/prod && terraform apply` → cria os registros NS de delegação.

### Passo H — GitHub Environments (secrets WIF por ambiente)
Crie os Environments `homolog`, `stage`, `prod` (e `landing-prod`), cada um com os secrets
(de `terraform output` do projeto correspondente):

| Secret | homolog | stage | prod / landing-prod |
|---|---|---|---|
| `GCP_PROJECT_ID` | `turni-homol` | `turni-stage` | `turni-prod` |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | `wif_provider` | idem | idem |
| `GCP_SERVICE_ACCOUNT` | `ci_service_account` | idem | idem |

O deploy do Firebase Hosting é **keyless** (o `firebase` CLI usa a credencial WIF como
ADC) — **não** há `FIREBASE_SERVICE_ACCOUNT`. A SA `turni-github-ci` já tem
`roles/firebasehosting.admin` (módulo `iam`). O Environment `landing-prod` também precisa
das 3 secrets WIF (= valores do `turni-prod`).

- `prod` → marcar **required reviewer** (gate humano do `release.yml`).
- O WIF de cada projeto restringe ao repo `alcatechgroup/mvpturni-mvp` (módulo `iam`).

### Passo I — Reconstruir o homolog (CI) e validar
- Disparar um release `-rc.N` (tags `v*-rc.*`) → `release.yml` builda, empurra para o AR do
  `turni-homol`, roda `migrate --force && seed --force` e faz deploy de api/admin/webapp/mock.
- **Two-phase do fake de pagamento**: após o api subir, `terraform output api_url` no homolog,
  pôr em `api_public_url` no tfvars e `terraform apply` (corrige o `PAGARME_WEBHOOK_TARGET`).
- Validar **no browser** (`app.homolog.turni.com.br`), não só teste verde (cota Resend: máx 1 run/dia).

### Passo J — Stage (deploy manual)
`gh workflow run deploy-stage.yml -f ref=<tag-ou-branch>` (Actions → Deploy Stage). Builda,
migra (sem seed de teste), deploya api/admin/mock/webapp no `turni-stage`. Two-phase do
`api_public_url` igual ao homolog. Validar em `app.stage.turni.com.br`.

### Passo K — Aposentar o `turni-mvp` (só após tudo verde + DNS propagado)
```bash
gcloud billing projects unlink turni-mvp          # corta faturamento já
# opcional, 30 dias de carência:
gcloud projects delete turni-mvp
```

---

## Go-live de produção (EPIC-006, fora deste runbook)
1. `prod_live_enabled = true` no tfvars do prod → `terraform apply` (min_instances=1, schedulers
   ativos, monitoring ligado).
2. Ligar o Cloud SQL manualmente (o `activation_policy` tem `ignore_changes`):
   `gcloud sql instances patch turni-prod --project=turni-prod --activation-policy=ALWAYS`.
3. Release de tag final (`vX.Y.Z`, sem `-rc`) → gate do Environment `prod` → deploy.
4. DNS dos hosts de prod (`app./api./admin.turni.com.br`) e landing apex/www: `landing_prod_enabled`
   + registros na zona apex (já no `turni-prod`).

## Custo — resumo honesto
- **homol / stage:** Cloud SQL `db-f1-micro` com sql-scheduler (desliga noites/fins de semana) +
  Cloud Run min=0. Baixo, dentro dos créditos.
- **prod parado:** Cloud Run min=0 = zero; schedulers pausados = zero; **Cloud SQL STOPPED ainda
  cobra disco (10GB) + IP** (piso pequeno) + a managed zone apex (~US$0,20/mês). Para zero
  absoluto, não aplicar o `cloud-sql` do prod até o go-live (mas aí não é "tudo aplicado, parado").

## Riscos
- **Cutover de DNS no registro.br** (passo E) é o de maior risco: propagação + janela de transição.
  Por isso o `turni-mvp` só é aposentado depois (passo K). TTLs de registro são baixos (300s).
- **WIF/secrets por Environment** (passo H): erro aqui quebra deploy (não prod em si). Validar com
  um release de homolog antes de mexer em prod.
