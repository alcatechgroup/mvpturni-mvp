# Plano — novo ambiente `stage` (pré-produção) no GCP

> Status: **proposta** (aguarda aprovação humana antes de qualquer `terraform apply`).
> Base documental: ADR-004 (hospedagem/IaC/multi-ambiente), IDR-016 (worker Cloud Run Job),
> ADR-016 / PDR-017 (gateway de pagamento), ADR-011 (e-mail transacional), ADR-012 (landing).
> Decisões do Alexandro (2026-06-05): **mesmo projeto `turni-mvp`**, **espelhar produção**,
> **deploy por disparo manual** (`workflow_dispatch`).

## 1. Por que isto é barato de fazer

A infra já nasceu multi-ambiente (ADR-004 §c): `infra/envs/{homolog,prod}` compartilham os
módulos de `infra/modules/`, tudo parametrizado por `local.env` + `var.project_id`. Recursos são
sufixados pelo ambiente (`turni-${env}`, `turni-api-${env}`, secrets `turni-${env}-*`,
hosts `*.${env}.turni.com.br`). O state remoto vive num único bucket GCS `turni-terraform-state`
com prefixo por env. **Adicionar `stage` é seguir o padrão**, não inventar estrutura nova:
um diretório `infra/envs/stage/` + novo prefixo de state + valores próprios.

## 2. Decisão de fundo: o `prod` é um SCAFFOLD, não clone cego

`infra/envs/prod/main.tf` está marcado "SCAFFOLDED — NÃO aplicar antes do EPIC-006". Espelhar
produção fielmente significa copiar a **topologia** do prod, mas reconciliando 4 lacunas que o
scaffold ainda carrega. Cada reconciliação abaixo tem uma decisão e um default recomendado.

### 2.1 Worker — usar Cloud Run Job, não a VM
O `prod/main.tf` ainda referencia `module "worker"` (`worker-vm`, GCE). O **IDR-016** já trocou o
homolog para `module "worker_job"` (Cloud Run Job + Cloud Scheduler a cada 1 min) porque a VM
"nunca funcionou em homolog (5 gaps de infra)". → **Stage usa `worker-job`** (o caminho vivo e
testado), não a VM stale do scaffold prod.

### 2.2 Gateway de pagamento — o PSP real ainda não existe
ADR-016 / PDR-017: o `pagarme-mock` é o **gateway efetivo do MVP**; o PSP real é "épico da próxima
wave". Um pré-prod fiel a prod *não* teria mock — mas hoje não há PSP real para apontar. Para o
stage exercitar o fluxo de pagamento ponta-a-ponta, **mantém-se o `pagarme-mock` no stage** (igual
homolog), com nota de que ele sai quando o PSP real entrar. Sem isso, todo o caminho de
pré-auth/captura/Pix fica sem backend no stage.
**Decisão aberta A:** manter `pagarme-mock` no stage (recomendado) **ou** subir stage sem caminho
de pagamento.

### 2.3 Admin — ingress interno + IAP exige LB que ainda não está escrito
`prod` define o admin com `ingress=INTERNAL_LOAD_BALANCER` + `allow_unauthenticated=false`, mas os
recursos de **HTTPS Load Balancer + Serverless NEG + IAP não estão implementados** em nenhum env (o
comentário do módulo `dns` confirma: "Em prod: provisionar HTTPS LB + Serverless NEG"). Ou seja, com
`ingress=internal_load_balancer` e sem LB, o admin do stage fica **inacessível**.
**Decisão aberta B:**
- (B1) **Implementar LB + NEG + IAP agora** no stage — pré-prod mais fiel, mas é o maior esforço
  (módulo novo, ainda inexistente no repo).
- (B2) **Stage com `ingress=all`** como o homolog (admin público) — entrega o ambiente rápido e
  deixa o LB/IAP para quando o EPIC-006 implementá-lo em prod, e então o stage herda. **Recomendado**
  para destravar agora, com TODO explícito.

### 2.4 E-mail transacional — prod scaffold não fia o Resend
O `prod/secrets` não passa `resend_api_key` (o de homolog passa). Para o stage testar e-mail
(aprovação, etc. — ADR-011), **fia-se o Resend no stage** com subdomínio remetente próprio
`mail.stage.turni.com.br` (DKIM próprio gerado no painel Resend).

## 3. Custo (ADR-004 marca como sinal de revisão)

Cada ambiente carrega o piso do Cloud SQL. O `homolog` usa `module "sql_scheduler"` (desliga
seg–sex 22h BRT + fins de semana); o `prod` é always-on. Como stage é pré-prod e não precisa de
disponibilidade 24/7, **recomendo manter o `sql-scheduler` no stage** (e `db_tier` pequeno, default
do módulo, não o `db-g1-small` do prod) para conter custo. Roda dentro dos créditos US$2K hoje, mas
é a linha a observar.
**Decisão aberta C:** stage com `sql-scheduler` + tier pequeno (recomendado) **ou** always-on tipo prod.

## 4. Arquivos a criar (`infra/envs/stage/`)

Copiar de `infra/envs/prod/` e ajustar; estrutura idêntica a homolog/prod.

| Arquivo | Conteúdo / ajustes-chave |
|---|---|
| `backend.tf` | Igual ao de prod, **`prefix = "envs/stage"`** (mesmo bucket `turni-terraform-state`). |
| `variables.tf` | Copiar; incluir `resend_api_key`, `mail_dkim_value`, `pagarme_*` (como homolog) se A/2.2 for "manter mock". |
| `outputs.tf` | Copiar de homolog (URLs/hosts do stage). |
| `main.tf` | Base = `prod/main.tf` com: `env="stage"`; hosts `*.stage.turni.com.br`; **CIDR `10.3.0.0/24`** (homolog=10.1, prod=10.2); `worker_job` no lugar de `worker-vm` (§2.1); `pagarme-mock` (§2.2); `firebase` com `landing` `turni-landing-stage`; `dns` com **`create_zone=false`** (a zona `turni-com-br` pertence ao homolog) só adicionando CNAMEs `*.stage`; `sql_scheduler` (§3); admin `ingress=all` se B2. |
| `terraform.tfvars` | `project_id="turni-mvp"`, `github_repo="alcatechgroup/mvpturni-mvp"`, `alert_email`, **novos** `app_key_api`/`app_key_admin` (gerar), **nova** `db_password`, imagens bootstrap `hello:latest`, secrets do mock + `resend_api_key` + `mail_dkim_value` próprios do stage. **gitignored** (segredos). |

### Pontos de atenção que quebram se ignorados
- **Zona DNS:** `create_zone=false` no stage. Só o homolog cria a zona; duplicar dá conflito.
- **CIDR único:** `10.3.0.0/24` para não colidir com homolog/prod no mesmo projeto.
- **Secrets por env:** o módulo `secrets` já sufixa por `env` → `turni-stage-*`, sem colisão.
- **Firebase site ids:** `turni-webapp-stage` / `turni-landing-stage` (novos targets no `.firebaserc`).

## 5. Mudanças fora do `infra/envs/stage/`

1. **`.firebaserc`** — adicionar targets `hosting.stage` → `["turni-webapp-stage"]` e
   `hosting.landing-stage` → `["turni-landing-stage"]`.
2. **IAM / WIF** — o módulo `iam` já concede ao SA `turni-apps@turni-mvp` os papéis no projeto;
   como stage fica no mesmo projeto, o WIF do GitHub já cobre. Validar que o `github_repo` do WIF
   permite os novos jobs (mesmo repo → ok).
3. **`.github/workflows/`** — novo workflow `deploy-stage.yml` com **`workflow_dispatch`** (input:
   tag/imagem a promover). Não mexer no `detect-env` do `release.yml` (que só conhece rc→homolog,
   limpa→prod). O job de stage: autentica via WIF, roda migração (sem o seed de teste do homolog —
   pré-prod não recebe os usuários de teste do CA-12), faz `gcloud run deploy turni-{api,admin}-stage`
   + `turni-worker-job-stage` + Firebase target `stage`, com health-check. Espelha os jobs
   `deploy-*-homolog` trocando o sufixo e a origem da imagem (promove a imagem já buildada, não
   rebuilda).

## 6. Ordem de execução (runbook)

1. Bootstrap manual mínimo: confirmar bucket de state `turni-terraform-state` (já existe) e gerar
   `app_key_*` (`php artisan key:generate --show`) + `db_password` forte + secrets do mock + chave
   Resend do stage. Criar subdomínio remetente no painel Resend → obter DKIM.
2. Criar `infra/envs/stage/` (§4) e `terraform.tfvars` (gitignored).
3. `cd infra/envs/stage && terraform init && terraform plan` — revisar (esperado: 0 surpresas;
   conferir que não tenta recriar a zona DNS).
4. `terraform apply` (gate humano).
5. Adicionar targets no `.firebaserc`; primeiro deploy via novo `deploy-stage.yml` (workflow_dispatch).
6. Configurar CNAMEs `*.stage` no registro/zona (saem do `terraform apply` se o módulo `dns` os criar).
7. Health-checks verdes em `api/admin/app.stage.turni.com.br`.

## 7. Decisões abertas (resumo para aprovar)

- **A (pagamento):** manter `pagarme-mock` no stage? — *recomendado: sim*.
- **B (admin):** `ingress=all` agora (B2, rápido) ou implementar LB+IAP já (B1, fiel)? — *recomendado: B2 com TODO*.
- **C (custo):** `sql-scheduler` + tier pequeno (recomendado) ou always-on como prod?

Aprovadas essas três, o passo seguinte é gerar os arquivos de `infra/envs/stage/` e o
`deploy-stage.yml`.
