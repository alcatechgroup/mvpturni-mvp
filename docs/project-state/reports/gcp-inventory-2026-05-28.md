# Inventário de Recursos GCP — Turni MVP

**Ambiente provisionado:** Homologação (`homolog`)
**Região:** `southamerica-east1` (São Paulo)
**Produção:** scaffolded em código mas **NÃO aplicada** — sem custo.
**Data de referência:** 2026-05-28 (atualizado 2026-05-27)

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
| Domínio customizado | **Sem DNS em homolog** — domain mapping não suportado em `southamerica-east1`; em prod será necessário HTTPS LB |
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
| URL direta | `https://turni-admin-homolog-dnj2tcr2xa-rj.a.run.app` |
| Domínio customizado | **Sem DNS em homolog** — backoffice acessado via URL direta; em prod requer HTTPS LB + IAP |

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
| Agendamento | Desliga seg–sex 22h BRT; liga seg–sex 06h BRT; fim de semana off (ver seção 11) |

**Console:** `https://console.cloud.google.com/sql/instances/turni-homolog/overview?project=[PROJECT_ID]`

**Custo estimado:**
- Instância db-f1-micro Enterprise: ~$12,30/mês (uptime ~48% com scheduler = ~$5,90/mês)
- Storage 10 GB SSD: ~$1,70/mês (storage é cobrado mesmo quando instância está desligada)
- Backups (7 dias): ~$1,70/mês
- **Subtotal: ~$9–11/mês → ~R$ 45–55/mês** (economia de ~$6/mês vs. 24/7)

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
| Agendamento | Para junto com o SQL às 22h BRT; inicia às 06h05 BRT (5 min após o SQL) |

**Console:** `https://console.cloud.google.com/compute/instances?project=[PROJECT_ID]`

**Custo estimado:**
- e2-micro ~48% uptime: ~$0,0084/hora × ~350h/mês = ~$2,94/mês
- Disco 10 GB standard: ~$0,44/mês (cobrado 100% do tempo)
- **Subtotal: ~$3,38/mês → ~R$ 17/mês** (economia de ~$3,20/mês vs. 24/7)

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

**Custo estimado:** Primeiros 0,5 GB gratuitos; ~$0,10/GB após.
**Subtotal: ~$0,10–0,50/mês → praticamente gratuito**

---

## 5. Hosting Estático — Firebase Hosting

### `turni-webapp-homolog`

| Atributo | Valor |
|---|---|
| Conteúdo | Build Flutter web (bundle + assets) |
| URL padrão | `turni-webapp-homolog.web.app` |
| URL customizada | `app.homolog.turni.com.br` (custom domain provisionado; ativo após propagação DNS) |
| CDN | Global (Firebase CDN automático) |
| Certificado HTTPS | Provisionado automaticamente pelo Firebase após verificação DNS |

**Console:** `https://console.firebase.google.com/project/[PROJECT_ID]/hosting/sites`

**Custo estimado:** Free tier cobre 10 GB storage e 360 MB/dia de transferência.
**Subtotal: $0/mês**

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
**Subtotal: ~$0–1/mês**

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

**Custo estimado:** 3 uptime checks = limite exato do free tier. Log-based metrics dentro do free tier de 50 GiB/mês.
**Subtotal: $0/mês**

---

## 10. IAM & Identidade

| Recurso | Detalhes |
|---|---|
| SA `turni-github-ci` | GitHub Actions: push de imagens, deploy Cloud Run, Firebase |
| SA `turni-apps` | Runtime: acesso Cloud SQL, Secret Manager, Cloud Logging |
| SA `turni-sql-sched-homolog` | Cloud Scheduler: start/stop do Cloud SQL e GCE worker |
| WIF Pool `github-pool` | Autenticação OIDC do GitHub Actions — sem chave de longa duração |
| WIF Provider `github-provider` | Restrito ao repositório `alcatechgroup/mvpturni-mvp` |

**Console IAM:** `https://console.cloud.google.com/iam-admin/iam?project=[PROJECT_ID]`
**Console WIF:** `https://console.cloud.google.com/iam-admin/workload-identity-pools?project=[PROJECT_ID]`

**Custo: $0/mês**

---

## 11. Agendamento — Cloud Scheduler

Reduz custo de Cloud SQL e GCE worker desligando-os fora do horário útil.

| Job | Schedule (BRT) | Ação |
|---|---|---|
| `turni-homolog-sql-stop` | seg–sex 22:00 | Para Cloud SQL (`activationPolicy: NEVER`) |
| `turni-homolog-sql-start` | seg–sex 06:00 | Liga Cloud SQL (`activationPolicy: ALWAYS`) |
| `turni-homolog-worker-stop` | seg–sex 22:00 | Para GCE worker (`POST /stop`) |
| `turni-homolog-worker-start` | seg–sex 06:05 | Liga GCE worker (`POST /start`, 5 min após SQL) |

**Uptime efetivo:** ~80h/semana de 168h totais (~48%). Finais de semana completamente desligados.

**Console:** `https://console.cloud.google.com/cloudscheduler?project=[PROJECT_ID]`

**Custo estimado:** Primeiros 3 jobs gratuitos; 4º job = $0,10/mês.
**Subtotal: ~$0,10/mês → praticamente gratuito**

---

## 12. DNS — Cloud DNS

| Recurso | Detalhes |
|---|---|
| Zona | `turni-com-br` (`turni.com.br.`) |
| Tipo | Pública |
| Nameservers | `ns-cloud-e1.googledomains.com`, `ns-cloud-e2.googledomains.com`, `ns-cloud-e3.googledomains.com`, `ns-cloud-e4.googledomains.com` |
| Delegação | NS configurados no registro.br — propagação em andamento |

| Registro | Tipo | Destino | Status |
|---|---|---|---|
| `app.homolog.turni.com.br` | CNAME | `turni-webapp-homolog.web.app` | Ativo (aguardando propagação DNS) |
| `api.homolog.turni.com.br` | — | **Sem registro** — domain mapping não suportado em `southamerica-east1` | Acesso via URL direta do Cloud Run |
| `admin.homolog.turni.com.br` | — | **Sem registro** — decisão deliberada para homolog | Acesso via URL direta do Cloud Run |

**Console:** `https://console.cloud.google.com/net-services/dns/zones?project=[PROJECT_ID]`

**Custo estimado:** 1 zona = $0,20/mês; < 10k queries/mês = $0,40/mês.
**Subtotal: ~$0,60/mês**

---

## Resumo de Custos

| Serviço | USD/mês | BRL/mês* |
|---|---|---|
| **Cloud SQL** (db-f1-micro, ~48% uptime) | **$9–11** | **~R$ 45–55** |
| **GCE Worker** (e2-micro, ~48% uptime) | **$3,38** | **~R$ 17** |
| Cloud Run (api + admin) | $0–2 | ~R$ 0–10 |
| Artifact Registry | $0,10–0,50 | ~R$ 1–3 |
| Cloud DNS | $0,60 | ~R$ 3 |
| Cloud Scheduler | $0,10 | ~R$ 1 |
| Rede/VPC | $0–1 | ~R$ 0–5 |
| Firebase, Secrets, Monitoring, GCS, IAM | $0 | R$ 0 |
| **TOTAL** | **~$13–18/mês** | **~R$ 65–90/mês** |

*Câmbio de referência: USD 1 ≈ BRL 5,00*

> **Economia vs. 24/7:** ~$9–10/mês (~40% de redução) graças ao Cloud Scheduler desligando SQL e worker fora do horário útil.

---

## Observações

**Produção não está ativa.** O ambiente `infra/envs/prod/` está scaffolded mas `terraform apply` nunca foi executado — sem custo de produção.

**DNS em propagação.** NS configurados no registro.br apontando para Cloud DNS. `app.homolog.turni.com.br` terá HTTPS via Firebase assim que propagar. Verificar com: `dig NS turni.com.br +short`.

**API sem domínio customizado em homolog.** Cloud Run domain mapping não é suportado em `southamerica-east1`. Em produção será necessário um HTTPS Global Load Balancer + Serverless NEG (~$18/mês por forwarding rule).

**Admin sem domínio customizado (intencional).** Backoffice acessado via URL direta do Cloud Run em homolog. Em produção: HTTPS LB + IAP.

**GitHub Actions:** O plano Free da organização inclui 2.000 minutos/mês para repositórios privados. Cada ciclo de release (~2 min) + CI (~3 min) consome ~5 min/push. Volume atual está dentro do free tier.
