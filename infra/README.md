# infra/ — Infraestrutura do Turni

Toda a infraestrutura é código (ADR-021, que substitui a ADR-004). Nenhum recurso é
criado pelo console. Operação do dia a dia: [`docs/operacao/runbook-vps.md`](../docs/operacao/runbook-vps.md).

## Onde fica o quê

```
infra/
├── envs/                 um diretório por camada de state
│   ├── shared/           APIs, Artifact Registry, WIF do CI — uma vez por projeto
│   ├── homolog/          ambiente aplicado hoje
│   ├── staging/          escrito, ainda não aplicado
│   └── prod/             escrito, ainda não aplicado
├── modules/
│   ├── environment/      compõe um ambiente inteiro (é o que os envs chamam)
│   ├── network/          VPC, subnet e as duas portas de entrada (Cloudflare, IAP)
│   ├── vps/              instância, IP, disco de dados, buckets, bootstrap
│   ├── cloudflare-dns/   registros A achatados + registros de e-mail do Resend
│   ├── secrets/          Secret Manager
│   ├── artifact-registry/ repositório de imagens (compartilhado)
│   ├── iam/              identidade federada do CI (compartilhada)
│   └── monitoring/       métricas de negócio e alertas de saúde da VPS
├── vps/                  o que roda DENTRO da VPS (compose, Caddyfile, scripts)
└── docker/               Dockerfiles das imagens
```

`infra/vps/` é publicado num bucket pelo Terraform e sincronizado para `/opt/turni`
na máquina. **Editar esses arquivos na VPS não adianta** — o próximo boot ou deploy
sobrescreve com o que está aqui.

## Convenção de nomes

O projeto GCP **FoodHub** (`foodhub-87e0c`) hospeda outras aplicações. Saber de quem
é cada recurso é requisito, não estética:

```
turni-<env>-<recurso>     recursos de um ambiente   (turni-homolog-vm, turni-prod-ip)
turni-<recurso>           recursos compartilhados   (turni-ci, turni-github)
turni                     o repositório de imagens
```

Buckets levam o `project_id` como sufixo, porque o namespace é global:
`turni-homolog-config-foodhub-87e0c`.

Todo recurso que suporta labels leva:

```hcl
app        = "turni"
env        = "homolog" | "staging" | "prod" | "shared"
component  = "vps" | "data" | "config" | "backups" | "secret" | ...
managed-by = "terraform"
```

É o que permite responder "quanto o Turni custa neste projeto" e "o que é do Turni
aqui" sem depender de convenção de nome.

## Ordem de aplicação

`shared` primeiro (os ambientes leem o output dele via `terraform_remote_state`),
depois cada ambiente. State remoto em `gs://turni-tfstate-foodhub-87e0c`, um prefixo
por camada.

```bash
set -a && . ../../.env && set +a && export TF_VAR_cloudflare_token="$CLOUDFLARE_TOKEN"
terraform -chdir=infra/envs/shared apply
terraform -chdir=infra/envs/homolog apply
```

## O que muda entre ambientes

Só valores, nunca estrutura — a estrutura é o módulo `environment`:

| | homolog | staging | prod |
|---|---|---|---|
| Subnet | 10.10.0.0/24 | 10.20.0.0/24 | 10.30.0.0/24 |
| Máquina | e2-small | e2-small | e2-medium |
| Nível de rede | STANDARD | STANDARD | PREMIUM |
| Hosts | `app-homolog.` etc. | `app-staging.` etc. | `app.`, landing no apex |
| Fake de pagamento | ligado | ligado | **desligado** |
| Banner "ambiente de teste" | visível | visível | oculto |
| Retenção de backup | 30 dias | 30 dias | 90 dias |
| Uptime checks | desligados | desligados | ligados |
