---
id: IDR-007
title: Cloud Run ↔ Cloud SQL de IP privado (Direct VPC egress) + migração/seed via Cloud Run Job no pipeline
status: accepted
decided_at: 2026-05-29
decided_by: programador
source_story: STORY-016
supersedes: nada
superseded_by: nada
---

# IDR-007 — Conectividade Cloud Run → Cloud SQL privado + migração no pipeline

## Contexto

Ao empurrar a STORY-016 para homologação, o deploy subia (versão correta nas 3
interfaces, smoke verde), mas **login dava 500** e `/health?deep=1` retornava 503.
A investigação revelou uma cadeia de problemas — nenhum pego pelos testes (que
rodam local com Postgres por TCP) e nenhum exercido no EPIC-000 (homolog só servia
hello-world público, sem endpoint dependente de banco):

1. `config/database.php` (pgsql) lia só `DB_HOST` (default `127.0.0.1`) e
   **ignorava `DB_SOCKET`** — o env que o Terraform passa para o Cloud SQL.
2. A imagem de runtime da `api` instalava só `php84-fpm`, **sem o `php` CLI** —
   impossível rodar `artisan` (migração) a partir dela.
3. **O fundamental:** a instância Cloud SQL é **IP privado** (`ipv4Enabled=false`)
   e os serviços/jobs Cloud Run **não tinham VPC egress** — o connector
   `cloudsql-instances` dava **timeout** no socket. A `api` nunca havia conectado.
4. O `release.yml` **não tinha passo de migração**; e mesmo que tivesse, o SA do CI
   não tinha permissão de Cloud SQL.
5. Sessão Sanctum SPA exigia store persistente: `SESSION_DRIVER` estava `array`.

## Decisão

1. **pgsql host = `DB_SOCKET`** quando presente:
   `'host' => env('DB_SOCKET', env('DB_HOST', '127.0.0.1'))` (api e admin). O
   PostgreSQL trata host iniciado por `/` como diretório de socket Unix. Local e
   testes (sem `DB_SOCKET`) seguem em `DB_HOST`.
2. **`php` CLI no runtime** da imagem da api (`php84` + symlink `/usr/bin/php`),
   para `artisan` rodar no Cloud Run Job.
3. **Direct VPC egress** (`PRIVATE_RANGES_ONLY`) nas Cloud Run services (api/admin)
   e no job de migração, apontando para o subnet de homolog — é o que destrava o
   acesso ao Cloud SQL de IP privado. Parametrizado no módulo `cloud-run`
   (`vpc_network`/`vpc_subnetwork`); `enable_private_path_for_google_cloud_services`
   ligado no Cloud SQL como hardening.
4. **Migração/seed via Cloud Run Job** no `release.yml` (`migrate-homolog`): usa a
   imagem da release, garante o Cloud SQL ligado (o scheduler de economia pode
   desligá-lo), roda `migrate --force && db:seed --force` **antes** dos deploys
   fliparem tráfego. **Seed só em homolog** (dados de teste do CA-12 não vão a prod;
   prod terá job `migrate`-only). SA do CI ganha `roles/cloudsql.admin`.
5. **`SESSION_DRIVER=database`** na api (Sanctum SPA precisa de sessão persistente).

## Justificativa

- Cloud SQL de IP privado é a postura segura (sem IP público); o custo é exigir
  VPC egress no Cloud Run — solução canônica do GCP, não gambiarra.
- Migração como Cloud Run Job roda **na mesma imagem/rede da app**, sem proxy
  externo nem migrate-on-boot (que serializa cold starts e arrisca corrida).
- Rodar antes do flip de tráfego garante schema pronto para o código novo.

## Consequências

- Homolog passou a conectar: `/health?deep=1` → 200, `POST /api/login` → 200.
  Validado fim-a-fim na `rc.17`/`rc.18`.
- **Risco aceito:** o scheduler liga/desliga o Cloud SQL (economia). Se um release
  rodar com o banco desligado, o job o liga (e o scheduler o desliga depois). Fora
  de horário/fim de semana, o login em homolog dá 500 até o banco voltar — documentado
  no runbook.
- **Drift:** as mudanças foram aplicadas via `gcloud` nas services/job vivos **e**
  declaradas no Terraform (módulos cloud-run/cloud-sql, env homolog) — sem drift.
- Prod herda o módulo: quando o deploy de produção for usado, replicar o job de
  migração (sem seed) e o VPC egress no env de prod.

## Relação com outras decisões

- Refina **ADR-004** (hospedagem/IaC) — topologia de rede Cloud Run↔Cloud SQL.
- Complementa **IDR-006** (que destravou o WebApp local) levando a STORY-016 a homolog.
- Anda junto da emenda 2026-05-29 do **ADR-007** (API same-origin via Firebase rewrite).
