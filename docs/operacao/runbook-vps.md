# Runbook — VPS do Turni (ADR-021)

> Substitui os runbooks de homolog, stage, prod e landing, que descreviam a topologia
> Cloud Run + Cloud SQL + Firebase Hosting (ADR-004, superseded). Cobre os três
> ambientes: só o que muda entre eles é o prefixo `turni-<env>` e o host.

## Mapa mental

Cada ambiente é **uma VM** no projeto GCP **FoodHub** (`foodhub-87e0c`), rodando a
stack inteira em containers:

```
Internet ──► Cloudflare (proxy, WAF)
                │  só as faixas da Cloudflare passam no firewall
                ▼
          [ turni-<env>-vm ]  IP estático, 80/443
                │
              Caddy  (TLS via DNS-01, roteia por host)
                ├─ app-<env>.turni.com.br    → webapp (estático) + /api,/sanctum → api
                ├─ admin-<env>.turni.com.br  → admin
                ├─ api-<env>.turni.com.br    → api
                └─ <env>.turni.com.br        → landing
                │
          api · admin · worker · scheduler · postgres · pagarme-mock
                │
          /var/lib/turni  (disco de dados: postgres, uploads, logs, certificados)
```

SSH **não tem porta aberta**: entra pelo túnel do IAP, autorizado por IAM.

## Convenção de nomes

O projeto FoodHub hospeda outras aplicações. Tudo do Turni carrega o prefixo da
aplicação e, quando é por ambiente, também o ambiente:

| Recurso | Nome | Escopo |
|---|---|---|
| VPC / subnet | `turni-<env>-vpc` / `turni-<env>-subnet` | ambiente |
| Firewall | `turni-<env>-fw-web`, `-fw-ssh-iap`, `-fw-deny-ingress` | ambiente |
| VM / IP / disco | `turni-<env>-vm` / `turni-<env>-ip` / `turni-<env>-data` | ambiente |
| SA da VM | `turni-<env>-vm@foodhub-87e0c.iam.gserviceaccount.com` | ambiente |
| Segredos | `turni-<env>-<papel>` | ambiente |
| Buckets | `turni-<env>-config-foodhub-87e0c`, `turni-<env>-backups-foodhub-87e0c` | ambiente |
| Artifact Registry | `turni` | **compartilhado** |
| SA do CI / WIF | `turni-ci@…`, pool `turni-github` | **compartilhado** |
| State do Terraform | `turni-tfstate-foodhub-87e0c` (prefixo por camada) | **compartilhado** |

Além do nome, todo recurso que suporta leva as labels `app=turni`, `env=<env>`,
`managed-by=terraform` — é o que permite filtrar custo e inventário por aplicação
num projeto compartilhado.

## Bootstrap de um ambiente do zero

Pré-requisitos: `gcloud` autenticado com direito no projeto, `terraform >= 1.9`,
e o `.env` da raiz com `CLOUDFLARE_TOKEN` (token com **Zone:DNS:Edit** em
`turni.com.br`).

```bash
# 0. Bucket do state (uma vez por projeto)
gcloud storage buckets create gs://turni-tfstate-foodhub-87e0c \
  --project=foodhub-87e0c --location=southamerica-east1 --uniform-bucket-level-access
gcloud storage buckets update gs://turni-tfstate-foodhub-87e0c --versioning

# 1. Token da Cloudflare no ambiente do Terraform
set -a && . .env && set +a && export TF_VAR_cloudflare_token="$CLOUDFLARE_TOKEN"

# 2. Camada compartilhada (APIs, Artifact Registry, WIF do CI) — antes dos ambientes
terraform -chdir=infra/envs/shared init
terraform -chdir=infra/envs/shared apply

# 3. O ambiente
cd infra/envs/homolog
cp terraform.tfvars.example terraform.tfvars   # preencher os segredos
terraform init && terraform apply
```

O `apply` sobe a VM; o `startup-script` faz o resto sozinho (monta o disco, instala
Docker e Ops Agent, sincroniza o runtime do bucket de config, escreve o `.env` a
partir do Secret Manager e liga o `turni.service`). Acompanhar:

```bash
gcloud compute ssh turni-homolog-vm --zone southamerica-east1-c \
  --project foodhub-87e0c --tunnel-through-iap \
  --command "sudo journalctl -u google-startup-scripts -f"
```

No primeiro boot ainda não existe imagem publicada: a stack só fica saudável depois
do primeiro `release.yml`. Publique uma tag `vX.Y.Z-rc.N` e acompanhe.

### Depois do primeiro apply

1. **Segredos do GitHub** (Environments `homolog` e `prod`):
   `GCP_PROJECT_ID`, `GCP_WORKLOAD_IDENTITY_PROVIDER`, `GCP_SERVICE_ACCOUNT`
   (os dois últimos saem de `terraform -chdir=infra/envs/shared output`),
   e `LANDING_SECRET_PATH`.
2. **Resend**: criar o domínio `mail-<env>.turni.com.br`, copiar o DKIM para
   `mail_dkim_value` no tfvars e reaplicar.
3. **Cloudflare**: confirmar a zona em **SSL/TLS → Full (strict)**. O Caddy emite
   certificado público válido por DNS-01, então `Full (strict)` funciona — e é o
   único modo que impede alguém de forjar o hop até o origin.

## Operação do dia a dia

```bash
# Abrir shell (sem porta 22 exposta)
gcloud compute ssh turni-homolog-vm --zone southamerica-east1-c \
  --project foodhub-87e0c --tunnel-through-iap

# Na VPS
sudo systemctl status turni                       # estado da stack
cd /opt/turni && sudo docker compose ps           # estado dos containers
sudo docker compose logs -f api                   # log ao vivo de um serviço
sudo docker compose exec api php artisan tinker   # console da aplicação
sudo docker compose exec postgres psql -U turni -d turni
```

Logs também vão para o Cloud Logging, um log name por serviço:

```
logName="projects/foodhub-87e0c/logs/turni-homolog-api"      # ou -admin, -worker, -scheduler, -caddy
```

## Antes de criar tag rc.N — checklist obrigatório (IDR-004)

E2E em browser real é gate **local**. O pipeline pós-deploy faz apenas smoke HTTP,
então quem cria a tag carrega a responsabilidade de ter rodado o E2E contra o
ambiente local:

```bash
# 1. Ambiente local de pé (containers + WebApp + seed)
make up
docker compose exec api php artisan migrate --force && \
  docker compose exec api php artisan db:seed --force   # usuários de teste do CA-13

# 2. E2E contra localhost:8002 + localhost:8003
make e2e
# Falha aqui = NÃO crie a tag. Corrija e re-rode.
```

Quem pula este passo está mandando regressão visual para homolog sem rede de
proteção. O smoke do pipeline pega 5xx e versão errada, mas não pega CSS quebrado
nem label faltando.

## Deploy

O caminho normal é a tag: `vX.Y.Z-rc.N` → homolog automático; `vX.Y.Z` → produção
com gate humano no GitHub Environment. O workflow builda as imagens, faz um **dump
do banco antes de migrar** e roda um comando na VPS.

Manualmente, se preciso:

```bash
sudo /opt/turni/scripts/deploy.sh v1.2.3   # aplica uma tag
sudo /opt/turni/scripts/deploy.sh --sync   # só reler config/segredos e recarregar
sudo /opt/turni/scripts/deploy.sh --rollback
```

**O rollback devolve o código, não o schema.** Migração é forward-only
(`quality-standards` 2.4): reverter schema é migração nova de correção. Se a migração
da release destruiu dado, o caminho é o restore (abaixo), não o rollback.

## Backup e restore

Dump diário às 03:00 BRT (`turni-backup.timer`) para
`gs://turni-<env>-backups-foodhub-87e0c/postgres/<env>/`, com retenção pela lifecycle
rule do bucket (30 dias em homolog, 90 em produção). O deploy também dispara um dump
rotulado `pre-<tag>`.

```bash
sudo /opt/turni/scripts/backup.sh manual    # dump sob demanda
sudo /opt/turni/scripts/restore.sh          # lista os dumps disponíveis
sudo /opt/turni/scripts/restore.sh gs://…/turni-homolog-….sql.gz
```

O restore é destrutivo e pede confirmação digitada.

## Mudar a configuração da VPS (compose, Caddyfile, scripts)

Esses arquivos vivem em `infra/vps/` **no repositório** e são publicados no bucket de
config pelo Terraform. Não edite na máquina — o próximo boot ou deploy sobrescreve.

```bash
# 1. editar infra/vps/...
terraform -chdir=infra/envs/homolog apply     # republica no bucket
gcloud compute ssh turni-homolog-vm ... --command "sudo /opt/turni/scripts/deploy.sh --sync"
```

## Diagnóstico

| Sintoma | Causa provável | Verificação |
|---|---|---|
| 5xx em todos os hosts | stack no chão ou Caddy sem certificado | `systemctl status turni`; `docker compose logs caddy` |
| 5xx só depois de um deploy | release quebrada | `deploy.sh --rollback` |
| Erro de certificado | token da Cloudflare sem `Zone:DNS:Edit`, ou expirado | `docker compose logs caddy \| grep acme` |
| 522/523 na Cloudflare | firewall bloqueando, ou faixas da Cloudflare mudaram | comparar `curl -s https://api.cloudflare.com/client/v4/ips` com `cloudflare_ipv4_ranges` |
| Tudo lento, OOM | e2-small no limite | alerta de memória; `docker stats`; subir `machine_type` |
| Disco cheio | imagens antigas ou crescimento do banco | `docker system prune -af`; aumentar `data_disk_size_gb` |
| Métrica de negócio vazia | pipeline de log do Ops Agent | Logs Explorer com `log_id("turni-<env>-worker")`; conferir se `jsonPayload.message` aparece |

> **Ponto a validar no primeiro bring-up:** que as linhas do Laravel chegam ao Cloud
> Logging já parseadas (`jsonPayload.message`, `jsonPayload.context.*`). Todas as
> métricas de negócio do `infra/modules/monitoring` dependem disso, e a falha é
> silenciosa — a métrica simplesmente fica sem dado. Se não aparecer, o suspeito é o
> processor `parse_json` em `infra/vps/ops-agent.yaml`.

## Custo aproximado (homolog)

| Item | ~US$/mês |
|---|---|
| e2-small (southamerica-east1) | 13 |
| IP externo estático em uso | 3 |
| Discos (20 GB boot + 20 GB dados, pd-balanced) | 4 |
| Buckets (config + backups) | < 1 |
| **Total** | **~20** |

Sem Cloud SQL (que era o maior item da conta anterior) e sem taxa de load balancer.
Uptime checks ficam **desligados** por padrão — foram a fonte de custo inesperado do
Cloud Monitoring antes.
