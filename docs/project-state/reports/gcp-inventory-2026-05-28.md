# Inventário de Recursos GCP — Turni MVP

**Ambiente provisionado:** Homologação (`homolog`)
**Região:** `southamerica-east1` (São Paulo)
**Produção:** scaffolded em código mas **NÃO aplicada** — sem custo.
**Data de referência:** 2026-05-28

---

## 1. Compute — Cloud Run

### `turni-api-homolog`

| Atributo | Valor |
|---|---|
| CPU | 1 vCPU |
| Memória | 512 Mi |
| Instâncias mín/máx | 0 / 3 |
| Ingress | público (`INGRESS_TRAFFIC_ALL`) |
| URL direta | `https://turni-api-homolog-dnj2tcr2xa-rj.a.run.app` |
| Health | `/health`, `/version.json` |

**Console:** `https://console.cloud.google.com/run/detail/southamerica-east1/turni-api-homolog/metrics?project=[PROJECT_ID]`

---

### `turni-admin-homolog`

| Atributo | Valor |
|---|---|
| CPU | 1 vCPU |
| Memória | 512 Mi |
| Instâncias mín/máx | 0 / 3 |
| Ingress | interno+LB (`INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER`) |
| Acesso | somente via IAP ou Load Balancer interno |

**Console:** `https://console.cloud.google.com/run/detail/southamerica-east1/turni-admin-homolog/metrics?project=[PROJECT_ID]`

**Custo estimado (ambos juntos):** Com `min_instances = 0` e tráfego atual (apenas health checks a cada 60s), praticamente não acumulam custo de compute — Cloud Run escala a zero. Dentro do free tier de 2M requisições/mês e 400.000 GB-seconds.
**Estimativa: ~R$ 0–10/mês**

---

## 2. Banco de Dados — Cloud SQL

### `turni-homolog` (PostgreSQL 17)

| Atributo | Valor |
|---|---|
| Tier | `db-f1-micro` (vCPU compartilhada, 614 MB RAM) |
| Edition | ENTERPRISE |
| Availability | ZONAL (única zona — adequado para homolog) |
| Disco | 10 GB SSD, autoresize ativado |
| IP público | Não — acesso via Cloud SQL connector (socket) |
| Backups | Diário às 03h, 7 dias de retenção + PITR habilitado |
| max_connections | 100 |
| Banco | `turni` (usuário `turni`) |

**Console:** `https://console.cloud.google.com/sql/instances/turni-homolog/overview?project=[PROJECT_ID]`

**Custo estimado:**
- Instância db-f1-micro Enterprise: ~$12,30/mês
- Storage 10 GB SSD: ~$1,70/mês ($0,17/GB)
- Backups (7 dias): ~$1,70/mês (equivale ao armazenamento)
- **Subtotal: ~$15–18/mês → ~R$ 75–90/mês**

> Este é o **maior custo individual** da infraestrutura.

---

## 3. Compute — GCE Worker

### `turni-worker-homolog`

| Atributo | Valor |
|---|---|
| Machine type | `e2-micro` (0,25 vCPU compartilhada, 1 GB RAM) |
| Zona | `southamerica-east1-a` |
| OS | Container-Optimized OS (`cos-stable`) |
| Disco boot | 10 GB standard |
| IP público | Não |
| Função | `php artisan queue:work database` (processo contínuo) |

**Console:** `https://console.cloud.google.com/compute/instances?project=[PROJECT_ID]`

**Custo estimado:**
- e2-micro em southamerica-east1: ~$0,0084/hora × 730h = ~$6,13/mês
- Disco 10 GB standard: ~$0,44/mês
- **Subtotal: ~$6,57/mês → ~R$ 33/mês**

---

## 4. Armazenamento de Imagens — Artifact Registry

### Repositório `turni` (Docker)

| Atributo | Valor |
|---|---|
| Formato | Docker |
| Região | `southamerica-east1` |
| Imagens | `turni/api`, `turni/admin` |
| Tags presentes | `v0.1.0-rc.1`, `v0.1.0-rc.2`, `v0.1.0-rc.3`, `latest` |

**Console:** `https://console.cloud.google.com/artifacts/docker/[PROJECT_ID]/southamerica-east1/turni?project=[PROJECT_ID]`

**Custo estimado:**
- Primeiros 0,5 GB gratuitos; ~$0,10/GB após
- ~6 imagens × ~150 MB comprimidas = ~1 GB total
- **Subtotal: ~$0,10–0,50/mês → praticamente gratuito**

---

## 5. Hosting Estático — Firebase Hosting

### `turni-webapp-homolog`

| Atributo | Valor |
|---|---|
| Conteúdo | Build Flutter web (bundle + assets) |
| URL padrão | `turni-webapp-homolog.web.app` |
| URL customizada | `app.homolog.turni.com.br` (quando DNS apontar) |
| CDN | Global (Firebase CDN automático) |

**Console:** `https://console.firebase.google.com/project/[PROJECT_ID]/hosting/sites`

**Custo estimado:** Free tier cobre 10 GB storage e 360 MB/dia de transferência.
**Subtotal: $0/mês** (dentro do free tier para homolog)

---

## 6. Segredos — Secret Manager

| Segredo | Uso |
|---|---|
| `turni-homolog-app-key-api` | `APP_KEY` do Laravel (api) |
| `turni-homolog-app-key-admin` | `APP_KEY` do Laravel (admin) |
| `turni-homolog-db-password` | Senha do PostgreSQL |

**Console:** `https://console.cloud.google.com/security/secret-manager?project=[PROJECT_ID]`

**Custo estimado:** 6 versões ativas gratuitas/mês; acessos mínimos.
**Subtotal: $0/mês**

---

## 7. Rede — VPC e Conectividade

| Recurso | Detalhes |
|---|---|
| VPC | `turni-homolog` |
| Subnet | `turni-homolog-southamerica-east1` — `10.1.0.0/24` |
| PSC Range | `turni-homolog-psc-range` — `/16` para Cloud SQL privado |
| Service Networking | Peering com `servicenetworking.googleapis.com` |

**Console:** `https://console.cloud.google.com/networking/networks/list?project=[PROJECT_ID]`

**Custo estimado:** Tráfego intra-região gratuito; PSC connection sem taxa de setup.
**Subtotal: ~$0–1/mês** (egress mínimo entre Cloud Run ↔ Cloud SQL)

---

## 8. Estado da Infraestrutura — GCS Bucket

| Recurso | Detalhes |
|---|---|
| Bucket | `turni-terraform-state` |
| Prefix usado | `envs/homolog` |
| Conteúdo | Terraform state files |

**Console:** `https://console.cloud.google.com/storage/browser/turni-terraform-state?project=[PROJECT_ID]`

**Custo estimado:** < 1 MB de state; $0,020/GB.
**Subtotal: < $0,01/mês → gratuito**

---

## 9. Observabilidade — Cloud Monitoring

| Recurso | Detalhes |
|---|---|
| Uptime check: API | `api.homolog.turni.com.br/health` — a cada 60s |
| Uptime check: Admin | `admin.homolog.turni.com.br/health` — a cada 60s |
| Uptime check: WebApp | `app.homolog.turni.com.br/` — a cada 60s |
| Alert: indisponibilidade | Dispara após 120s de falha → e-mail |
| Alert: taxa 5xx | Dispara se >5 erros/min por 5 min → e-mail |
| Log metrics | `turni_homolog_requests`, `turni_homolog_errors_5xx`, `turni_homolog_request_duration_ms` |

**Console:** `https://console.cloud.google.com/monitoring?project=[PROJECT_ID]`
**Logs:** `https://console.cloud.google.com/logs/query?project=[PROJECT_ID]`

**Custo estimado:** 3 uptime checks = limite exato do free tier (3 gratuitos). Log-based metrics dentro do free tier de 50 GiB/mês de ingestão.
**Subtotal: $0/mês**

---

## 10. IAM & Identidade

| Recurso | Detalhes |
|---|---|
| SA `turni-github-ci` | GitHub Actions: push de imagens, deploy Cloud Run, Firebase |
| SA `turni-apps` | Runtime: acesso Cloud SQL, Secret Manager, Cloud Logging |
| WIF Pool `github-pool` | Autenticação OIDC do GitHub Actions — sem chave de longa duração |
| WIF Provider `github-provider` | Restrito ao repositório `alcatechgroup/mvpturni-mvp` |

**Console IAM:** `https://console.cloud.google.com/iam-admin/iam?project=[PROJECT_ID]`
**Console WIF:** `https://console.cloud.google.com/iam-admin/workload-identity-pools?project=[PROJECT_ID]`

**Custo: $0/mês**

---

## Resumo de Custos

| Serviço | USD/mês | BRL/mês* |
|---|---|---|
| **Cloud SQL** (db-f1-micro Enterprise) | **$15–18** | **~R$ 75–90** |
| **GCE Worker** (e2-micro) | **$6,57** | **~R$ 33** |
| Cloud Run (api + admin) | $0–2 | ~R$ 0–10 |
| Artifact Registry | $0,10–0,50 | ~R$ 1–3 |
| Rede/VPC | $0–1 | ~R$ 0–5 |
| Firebase, Secrets, Monitoring, GCS, IAM | $0 | R$ 0 |
| **TOTAL** | **~$22–28/mês** | **~R$ 110–140/mês** |

*Câmbio de referência: USD 1 ≈ BRL 5,00*

---

## Observações

**Produção não está ativa.** O ambiente `infra/envs/prod/` está scaffolded mas `terraform apply` nunca foi executado — sem custo de produção.

**DNS não está provisionado.** O módulo `infra/modules/dns/` existe mas não está referenciado no `main.tf` de homolog. Os subdomínios `*.homolog.turni.com.br` precisam de configuração manual ou via o módulo.

**Maior oportunidade de economia:** O Cloud SQL `db-f1-micro` é o custo dominante (~65% do total). Para reduzir em homolog, uma opção é desligar a instância nos finais de semana via Cloud Scheduler, reduzindo em ~30% (~$4–5/mês de economia).

**GitHub Actions:** O plano Free da organização inclui 2.000 minutos/mês para repositórios privados. Cada ciclo de release (~2 min) + CI (~3 min) consome ~5 min/push. Volume atual está dentro do free tier.
