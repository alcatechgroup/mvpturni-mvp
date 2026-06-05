# Inventário de Recursos GCP — Turni MVP

**Ambiente provisionado:** Homologação (`homolog`)
**Região:** `southamerica-east1` (São Paulo)
**Produção:** scaffolded em código mas **NÃO aplicada** — sem custo.
**Data de referência:** 2026-06-04 (rc.68; substitui `gcp-inventory-2026-05-28.md`)

**Mudanças desde 2026-05-28:**
- **Worker GCE `e2-micro` APOSENTADA** → substituída por **Cloud Run Job** disparado a cada 1 min (IDR-016). Zero instâncias GCE no projeto.
- **Novo serviço Cloud Run `turni-pagarme-mock-homolog`** — fake genérico de pagamento (PDR-017 / ADR-016 d), gateway efetivo do MVP em homolog.
- **+3 secrets** (Resend, Bearer e HMAC do fake de pagamento).
- **Monitoring expandido:** 8 log-based metrics e 6 alert policies (e-mail crítico, SLA de notificação, cadastro).
- **DNS:** registros novos de `landing.homolog` e do subdomínio de e-mail `mail.homolog` (DKIM/DMARC/SPF — STORY-021).
- **Artifact Registry:** 3 imagens e **5,37 GB** acumulados (~68 RCs) — ver observação de housekeeping.

---

## 1. Compute — Cloud Run (serviços)

### `turni-api-homolog`

| Atributo | Valor |
|---|---|
| CPU / Memória | 1 vCPU / 512 Mi |
| Instâncias mín/máx | 0 / 3 |
| Ingress | público (`INGRESS_TRAFFIC_ALL`) |
| URL direta | `https://turni-api-homolog-dnj2tcr2xa-rj.a.run.app` |
| Envs novas | `PAGARME_DRIVER=mock`, `PAGARME_BASE_URL` → fake; Bearer/HMAC via Secret Manager |
| Health | `/health`, `/version.json` |

### `turni-admin-homolog`

| Atributo | Valor |
|---|---|
| CPU / Memória | 1 vCPU / 512 Mi |
| Instâncias mín/máx | 0 / 3 |
| Ingress | público em homolog (E2E no CI — IDR-003); prod será interno + IAP |
| URL direta | `https://turni-admin-homolog-dnj2tcr2xa-rj.a.run.app` |

### `turni-pagarme-mock-homolog` *(novo — PDR-017 / ADR-016 d)*

| Atributo | Valor |
|---|---|
| CPU / Memória | 1 vCPU / 512 Mi (Cloud Run v2 não aceita <512Mi com CPU always-allocated) |
| Instâncias mín/máx | 0 / 1 |
| Ingress | público; POST exige `Authorization: Bearer` (segredo no Secret Manager) — anônimo → 401 |
| URL direta | `https://turni-pagarme-mock-homolog-dnj2tcr2xa-rj.a.run.app` |
| Função | Fake genérico de pagamento: orders/capture/cancel/transfers no contrato Pagar.me + webhook HMAC de volta ao api |
| Ciclo de vida | **Sai quando o PSP real entrar** (épico da próxima wave); `deletion_protection=false` |

**Console:** `https://console.cloud.google.com/run?project=[PROJECT_ID]`

**Custo estimado (3 serviços):** todos com `min_instances=0`; tráfego = health checks (60s) + uso humano leve + smokes. Majoritariamente dentro do free tier de requests/vCPU-s.
**Subtotal: ~$0–3/mês → ~R$ 0–15**

---

## 2. Banco de Dados — Cloud SQL

### `turni-homolog` (PostgreSQL 17) — inalterado

| Atributo | Valor |
|---|---|
| Tier | `db-f1-micro` (vCPU compartilhada, 614 MB RAM), Edition ENTERPRISE, ZONAL |
| Disco | 10 GB SSD, autoresize |
| IP público | Não — Cloud SQL connector (socket) via Direct VPC egress |
| Backups | Diário 03h, 7 dias + PITR |
| Agendamento | Desliga seg–sex 22h BRT; liga seg–sex 06h BRT; fim de semana off |

**Custo estimado:**
- Instância (~48% uptime com scheduler): ~$5,90/mês
- Storage 10 GB SSD: ~$1,70/mês (cobrado mesmo desligada)
- Backups (7 dias + PITR): ~$1,70/mês
- **Subtotal: ~$9–11/mês → ~R$ 45–55/mês**

---

## 3. Worker — Cloud Run Job *(substituiu a GCE `e2-micro` — IDR-016)*

### `turni-worker-job-homolog`

| Atributo | Valor |
|---|---|
| Especificação | 1 vCPU / 512 Mi (mesma imagem do api) |
| Disparo | Cloud Scheduler `turni-worker-scheduler-homolog` — **a cada 1 min, 24/7** |
| Execução | `queue:work --stop-when-empty` — medido: ~13–27s por execução (fila vazia ≈ 13s) |
| Fora do horário do SQL | Execuções **falham rápido** (~13s, SQL desligado 22h–06h + fds) — ruído de log sem custo extra relevante |

**Custo estimado (estimativa de tarifa Tier 2, validar no billing):**
- ~43.200 execuções/mês × ~17s ≈ ~730k vCPU-s/mês; free tier cobre 240k vCPU-s
- **Subtotal: ~$9–13/mês → ~R$ 45–65/mês**

> ⚠️ **O worker virou o 2º maior custo** (a GCE antiga custava ~$3,4/mês). O IDR-016 comprou confiabilidade (a VM nunca funcionou: 5 gaps de infra), mas o modelo 1/min 24/7 cobra por execução. **Otimização barata disponível:** pausar o scheduler do worker na janela em que o SQL está desligado (22h–06h + fins de semana, ~52% do tempo) — economia estimada de ~$5–7/mês e elimina as execuções falhando à noite. Registrar como melhoria de infra quando oportuno.

### Jobs auxiliares (sem custo recorrente relevante)

| Job | Função |
|---|---|
| `turni-migrate-homolog` | `migrate --force` + seed — roda 1× por deploy (release.yml) |
| `turni-ca13-setup` | Smoke do `make setup` agendado (scheduled-setup-test.yml) — criado manualmente |

---

## 4. Armazenamento de Imagens — Artifact Registry

| Atributo | Valor |
|---|---|
| Repositório | `turni` (Docker), `southamerica-east1` |
| Imagens | `api`, `admin`, **`pagarme-mock`** *(nova)* |
| Tamanho atual | **5,37 GB** (~68 tags de RC acumuladas desde rc.1) |

**Custo estimado:** (5,37 − 0,5 free) × $0,10/GB ≈ **$0,49/mês → ~R$ 2,50**

> 🧹 **Housekeeping recomendado:** o repositório cresce ~80 MB por RC. Uma *cleanup policy* nativa do Artifact Registry (ex.: manter últimas 10 tags + `latest`) congelaria o custo. Hoje é barato, mas a tendência é linear com o número de releases.

---

## 5. Hosting Estático — Firebase Hosting

| Atributo | Valor |
|---|---|
| Site principal | `turni-webapp-homolog` → `app.homolog.turni.com.br` (Flutter web) |
| Site adicional | landing institucional → `landing.homolog.turni.com.br` (ADR-012; gate "em breve" + path secreto) |
| CDN / HTTPS | Automáticos (Firebase) |

**Custo estimado:** dentro do free tier (10 GB storage, 360 MB/dia).
**Subtotal: $0/mês**

---

## 6. Segredos — Secret Manager

| Segredo | Uso | Desde |
|---|---|---|
| `turni-homolog-app-key-api` | `APP_KEY` Laravel (api) | base |
| `turni-homolog-app-key-admin` | `APP_KEY` Laravel (admin) | base |
| `turni-homolog-db-password` | Senha PostgreSQL | base |
| `turni-homolog-resend-api-key` | E-mail transacional Resend (ADR-011) | STORY-021 |
| `turni-homolog-pagarme-secret-key` | Bearer do fake de pagamento (contract.md §auth) | STORY-056 / PDR-017 |
| `turni-homolog-pagarme-webhook-secret` | HMAC do webhook do fake (ADR-016 e) | STORY-056 / PDR-017 |

**Custo estimado:** 6 versões ativas = limite exato do free tier; acessos mínimos.
**Subtotal: ~$0–0,40/mês** (versões antigas acumuladas podem passar do free — desabilitar versões obsoletas se aparecer custo)

---

## 7. Rede — VPC e Conectividade (inalterado)

| Recurso | Detalhes |
|---|---|
| VPC / Subnet | `turni-homolog` / `10.1.0.0/24` |
| PSC Range | `/16` para Cloud SQL privado |
| Direct VPC egress | api, admin e worker job (`PRIVATE_RANGES_ONLY`) — o fake **não** usa VPC |

**Subtotal: ~$0–1/mês**

---

## 8. Estado da Infraestrutura — GCS (inalterado)

Bucket `turni-terraform-state` (prefix `envs/homolog`). **Subtotal: < $0,01/mês**

---

## 9. Observabilidade — Cloud Monitoring

| Recurso | Detalhes |
|---|---|
| Uptime checks (3) | API, Admin, WebApp — a cada 60s (limite exato do free tier) |
| Alert policies (6) | indisponibilidade; taxa 5xx; **falha de e-mail crítico**; **falha de e-mail de notificação**; **SLA e-mail notificação >60s p95**; **completar cadastro falhando (template indisponível)** |
| Log-based metrics (8) | `requests`, `errors_5xx`, `request_duration_ms`, `email_failures`, `notificacao_email_failures`, `notificacao_email_sla_ms`, `cadastros_completados`, `cadastro_completar_falhou` |

> As log-based metrics financeiras do ADR-016 (erro de transação ≤1%, p95 captura, p95 webhook) estão **definidas em `docs/operacao/`** aguardando wiring no Terraform (STORY-007/STORY-065).

**Custo estimado:** ingestão de logs ≪ 50 GiB free.
**Subtotal: $0/mês**

---

## 10. IAM & Identidade (inalterado)

SAs `turni-github-ci` (WIF/OIDC, restrito ao repo), `turni-apps` (runtime: SQL, secrets, logging — também usado pelo fake), `turni-sql-sched-homolog` (scheduler SQL). **Custo: $0/mês**

---

## 11. Agendamento — Cloud Scheduler

| Job | Schedule (BRT) | Ação |
|---|---|---|
| `turni-homolog-sql-start` | seg–sex 06:00 | Liga Cloud SQL |
| `turni-homolog-sql-stop` | seg–sex 22:00 | Desliga Cloud SQL |
| `turni-worker-scheduler-homolog` | **a cada 1 min (24/7)** | Dispara o Cloud Run Job do worker (IDR-016) |

> Os jobs `worker-start/stop` da GCE **saíram** com a VM (IDR-016). Hoje: 3 jobs = exatamente o free tier (3 gratuitos).

**Subtotal: $0/mês**

---

## 12. DNS — Cloud DNS

Zona pública `turni-com-br` (delegada no registro.br — propagada).

| Registro | Tipo | Destino |
|---|---|---|
| `app.homolog.turni.com.br` | CNAME | Firebase Hosting (WebApp) — ativo |
| `landing.homolog.turni.com.br` | CNAME | Firebase Hosting (landing) — ativo |
| `mail.homolog.turni.com.br` | TXT/MX | DKIM (`resend._domainkey`), DMARC, SPF/MX (`send`) — Resend (STORY-021) |
| `api.homolog` / `admin.homolog` | — | Sem registro (domain mapping não suportado em `southamerica-east1`); acesso via URL direta |

**Custo estimado:** 1 zona ($0,20) + queries (~$0,40).
**Subtotal: ~$0,60/mês**

---

## Resumo de Custos

| Serviço | USD/mês | BRL/mês* |
|---|---|---|
| **Cloud SQL** (db-f1-micro, ~48% uptime) | **$9–11** | **~R$ 45–55** |
| **Worker — Cloud Run Job** (1/min, 24/7) | **$9–13** | **~R$ 45–65** |
| Cloud Run services (api + admin + fake) | $0–3 | ~R$ 0–15 |
| Artifact Registry (5,37 GB) | $0,50 | ~R$ 2,50 |
| Cloud DNS | $0,60 | ~R$ 3 |
| Secret Manager | $0–0,40 | ~R$ 0–2 |
| Rede/VPC | $0–1 | ~R$ 0–5 |
| Firebase, Monitoring, GCS, Scheduler, IAM | $0 | R$ 0 |
| **TOTAL** | **~$20–29/mês** | **~R$ 100–145/mês** |

*Câmbio de referência: USD 1 ≈ BRL 5,00 (mesmo critério do inventário anterior).*

**Vs. inventário de 2026-05-28 (~$13–18/mês):** o aumento (~$7–11/mês) vem da troca GCE→Cloud Run Job no worker (IDR-016: +$6–10, comprou confiabilidade — a VM nunca processou a fila em homolog) e marginalmente do fake de pagamento + crescimento do Artifact Registry.

---

## Observações

1. **Worker é a alavanca de economia nº 1.** Pausar o `turni-worker-scheduler-homolog` na janela em que o SQL está desligado (22h–06h + fds) corta ~52% das execuções: ~**$5–7/mês** de economia e zera as execuções falhando à noite. Mudança pequena no módulo `worker-job` (schedule alinhado ao `sql-scheduler`).
2. **Artifact Registry crescendo linearmente** (~80 MB/RC, 5,37 GB já). Cleanup policy nativa (manter N tags recentes + `latest`) congela o custo.
3. **Estimativa do worker job é a de maior incerteza** (tarifa por vCPU-s em região Tier 2 + free tier). Validar contra o billing real no console: `https://console.cloud.google.com/billing` → relatório por serviço "Cloud Run".
4. **Fake de pagamento é descartável** (PDR-017): o serviço, os 2 secrets e o job de deploy saem quando o PSP real entrar (próxima wave) — remover o bloco "Fake de pagamento" de `infra/envs/homolog/main.tf` e a entrada da matrix do release.yml.
5. **Produção continua sem custo** — `infra/envs/prod/` nunca aplicado.
6. **GitHub Actions** dentro do free tier (2.000 min/mês), mas o ciclo cresceu: release (~4 min) + CI por push; acompanhar se o volume de pushes aumentar.
