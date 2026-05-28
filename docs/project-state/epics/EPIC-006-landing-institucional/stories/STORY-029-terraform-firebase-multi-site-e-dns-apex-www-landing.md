---
story_id: STORY-029
slug: terraform-firebase-multi-site-e-dns-apex-www-landing
title: Terraform — Firebase Hosting multi-site e DNS apex/www/landing.homolog
epic_id: EPIC-006
sprint_id: SPRINT-2026-W24-LANDING
type: implementation
target_role: programador
requires_design: false
status: done
owner_agent: claude-opus-4-8-programador-029-2026-05-28
created_at: 2026-05-28
updated_at: 2026-05-28
estimated_session_size: M
---

# STORY-029 — Terraform: Firebase Hosting multi-site + DNS apex/www/landing.homolog

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Ela contém tudo o que você precisa. Se algo estiver ambíguo, registre a dúvida na seção "Notas do agente" no final e pause em vez de adivinhar.

## Contexto (por que esta estória existe)

O EPIC-000 (`done`) provisionou Firebase Hosting para um único site (o WebApp) por ambiente, e Cloud DNS com a zona `turni.com.br` e apenas o subdomínio `app.homolog`. O EPIC-006 precisa:

1. **Mais sites Firebase Hosting** — pelo menos `turni-landing-homolog` (e provavelmente `turni-landing-prod`, definido em código mas aplicado apenas no go-public segundo PDR-015). Possivelmente um terceiro, se ADR-012 decidiu "dois sites separados" (apex/Em breve em um, landing em outro via subdomínio).
2. **Novos registros DNS** — apex `turni.com.br` (A/AAAA apontando para Firebase Hosting do site da landing prod), `www.turni.com.br` (redirect 301 para apex — mecânica decidida em ADR-012), `landing.homolog.turni.com.br` (CNAME para Firebase Hosting do site da landing homolog).

A topologia exata depende de ADR-012 (STORY-026 deve estar `done` antes desta estória entrar em sprint). Esta estória estende os módulos Terraform `infra/modules/firebase` e `infra/modules/dns` para suportar a topologia decidida, e aplica em homolog. Prod fica codificado mas com `count = var.enabled ? 1 : 0` ou equivalente, para aplicar apenas no go-public.

A estória é **M** (não L) porque o trabalho é mecânico: adaptar módulos Terraform existentes, adicionar variables, aplicar em homolog, validar com `terraform plan` + `terraform apply` + `dig`. Nenhuma decisão de produto/arquitetura nova — tudo já está decidido em ADR-012.

- Épico: `docs/project-state/epics/EPIC-006-landing-institucional/epic.md`
- Documentos canônicos a ler ANTES de codificar:
  - `docs/project-state/decisions/adr/ADR-012-landing-gate-em-breve-path-secreto.md` (topologia decidida — quantos sites, como o redirect www funciona)
  - `docs/project-state/decisions/adr/ADR-004-hospedagem-iac-deploy.md` (Firebase + Terraform + multi-ambiente)
  - `infra/modules/firebase/main.tf`, `variables.tf`, `outputs.tf` (módulo atual — aceita 1 site)
  - `infra/modules/dns/main.tf`, `variables.tf` (módulo atual — apex e www não estão cobertos)
  - `infra/envs/homolog/main.tf` (uso atual do módulo firebase para o WebApp)
  - `infra/envs/prod/main.tf` (uso futuro — mesmo padrão)
  - `docs/operacao/runbook-homolog.md` (procedimento de `terraform apply` em homolog)
  - `docs/skills/programador/SKILL.md`

## O quê (objetivo desta estória)

Entregar os módulos Terraform estendidos + plano aplicado em homolog:

1. **Extensão do módulo `infra/modules/firebase`** para suportar múltiplos sites no mesmo projeto GCP:
   - Opção A — adicionar `var.additional_sites` (lista de `{ site_id, custom_domain }`) ao módulo existente; cria N+1 sites na mesma chamada.
   - Opção B — chamar o módulo N vezes do `envs/homolog/main.tf`, uma por site (WebApp, landing, possivelmente apex-Em-breve se ADR-012 escolheu "dois sites").
   - Decisão: a que ADR-012 indicar; se ADR-012 não fixar, escolher B (mais explícito, menos lógica condicional no módulo) e justificar em IDR.
2. **Extensão do módulo `infra/modules/dns`** para suportar:
   - Registros **A/AAAA do apex** (`turni.com.br`) → IPs do Firebase Hosting do site prod da landing (recuperados via output do módulo firebase ou hardcoded segundo a doc do Firebase Hosting — verificar).
   - Registro **CNAME para `www`** (`www.turni.com.br` → mecânica de redirect decidida em ADR-012; pode ser um CNAME para outro site Firebase que serve apenas a regra de redirect, ou um registro tratado fora do Cloud DNS via servidor de redirect).
   - Registro **CNAME `landing.homolog`** (`landing.homolog.turni.com.br` → CNAME para `turni-landing-homolog.web.app` ou conforme output do módulo firebase).
   - Manter compatibilidade com os registros existentes (`app.homolog`, `api.homolog`).
3. **Configurar `apps/landing/firebase.json` mínimo** (só o suficiente para o `terraform apply` reconhecer o site; o `firebase.json` completo com rotas explícitas é STORY-031). Pode ser um stub com `{"public": "apps/landing/public"}`.
4. **`.firebaserc` estendido** com novos targets `landing-homolog` (e `landing-prod` se aplicável) mapeando para os sites criados.
5. **Aplicar em homolog**: `terraform plan` revisado pelo PO; `terraform apply` executado; `dig turni.com.br`, `dig www.turni.com.br`, `dig landing.homolog.turni.com.br` verificados; site Firebase de homolog acessível na URL default `turni-landing-homolog.web.app` (com conteúdo placeholder vazio até STORY-030 importar a landing).
6. **Não aplicar em prod**: registros e site prod ficam codificados mas com `count = var.landing_prod_enabled ? 1 : 0` (default `false`) — go-public futuro vira flip de variável + `terraform apply`. Documentar no runbook (STORY-032).
7. **`terraform destroy` exercitado em homolog** (criar e destruir o novo site Firebase + registros DNS para confirmar reversibilidade) — opcional, mas alinhado com `quality-standards.md` 2.3 (recriação do zero).

## Por quê (valor para o usuário)

Indireto: destrava STORY-031 (firebase.json + workflow) que precisa dos sites Firebase já criados para deployar; destrava STORY-032 (runbook) que documenta a infra resultante; destrava STORY-033 (validador) que verifica DNS resolvendo. Sem esta estória, a página "Em breve" da STORY-028 fica num site sem domínio customizado, sem CDN com SSL no domínio do Turni, sem caminho de release.

## Critérios de aceite

- [ ] **CA-1:** Módulo `infra/modules/firebase` suporta múltiplos sites no mesmo projeto GCP (mecânica decidida em ADR-012 ou em IDR justificado por esta estória). `terraform plan` no `envs/homolog` mostra criação do site `turni-landing-homolog`.
- [ ] **CA-2:** Módulo `infra/modules/dns` suporta apex A/AAAA, redirect www (conforme ADR-012), e CNAME para `landing.homolog`. `terraform plan` mostra os 3 registros novos.
- [ ] **CA-3:** Site Firebase `turni-landing-homolog` criado e visível no console Firebase (output do módulo retorna `site_id` e `cname_target`).
- [ ] **CA-4:** Domínio customizado `landing.homolog.turni.com.br` associado ao site Firebase `turni-landing-homolog` via `google_firebase_hosting_custom_domain`. Status na console Firebase eventualmente "connected" (pode levar alguns minutos para validar via CNAME no Cloud DNS).
- [ ] **CA-5:** `dig +short turni.com.br A` retorna IPs do Firebase Hosting (ou os IPs decididos em ADR-012 se for outro mecanismo). Mesmo para AAAA se aplicável.
- [ ] **CA-6:** `dig +short www.turni.com.br` retorna o destino conforme ADR-012 (CNAME para outro site Firebase de redirect, ou destino do servidor de redirect externo).
- [ ] **CA-7:** `dig +short landing.homolog.turni.com.br CNAME` retorna `turni-landing-homolog.web.app` (ou o target equivalente conforme output do módulo firebase).
- [ ] **CA-8:** `https://turni-landing-homolog.web.app/` responde 200 (página default do Firebase Hosting "Welcome" até STORY-030 importar conteúdo — aceitável neste momento).
- [ ] **CA-9:** Site prod (`turni-landing-prod`) e registros DNS prod codificados mas **não aplicados** (gate via variable `landing_prod_enabled = false`). `terraform plan` em `envs/prod` mostra 0 changes referentes a landing.
- [ ] **CA-10:** Compatibilidade preservada: WebApp em `app.homolog.turni.com.br` continua acessível pós-apply; `dig app.homolog.turni.com.br` continua resolvendo; site `turni-webapp-homolog` continua intocado.
- [ ] **CA-11:** Terraform state em GCS atualizado; nenhum recurso órfão (verificar com `terraform state list`).
- [ ] **CA-12:** PR aprovado pelo PO antes do `terraform apply` em homolog (gate humano — princípio de IaC com `apply` revisado). `terraform plan` anexado ao PR.

## Fora de escopo

- `firebase.json` com rotas explícitas (gate em si) — STORY-031.
- Workflow GitHub Actions de deploy — STORY-031.
- Conteúdo da landing AS IS — STORY-030.
- Página "Em breve" — STORY-028 (mas pode estar entregue já; se sim, é o que o site vai servir após STORY-031).
- Aplicar Terraform em prod (go-public) — fora do EPIC-006.
- Basic-auth / IP allowlist — fora do EPIC-006.

## Padrões de qualidade exigidos

Esta estória segue `docs/skills/po/references/quality-standards.md`:

- **IaC (§2.3):** toda mudança via Terraform; zero clique no console Firebase ou Cloud DNS além da revisão visual.
- **Plan antes de apply:** `terraform plan` anexado ao PR; revisão humana antes de `apply`. Espelha o gate humano de prod (ADR-004).
- **Reversibilidade:** módulos novos passam por `terraform destroy` dry-run (`terraform plan -destroy`) sem erros; idealmente exercer destroy real em homolog (CA-7 do "O quê").
- **Sem segredo em código:** se algum valor sensível for necessário (improvável), via Secret Manager.
- **State limpo:** `terraform state list` revisado pós-apply; nenhum recurso fora do controle do Terraform.

## Dependências

- **Bloqueada por:** STORY-026 (ADR-012 decide topologia — sem ela, esta estória não sabe quantos sites criar nem como o redirect www funciona).
- **Bloqueia:** STORY-031 (workflow precisa dos sites Firebase para deployar), STORY-032 (runbook documenta a infra resultante), STORY-033 (validador testa DNS).
- **Pré-requisitos de ambiente:** EPIC-000 `done` (state Terraform GCS existe, módulos `firebase` e `dns` em uso para o WebApp). Credencial GCP do operador (WIF ou local — conforme runbook-homolog.md).

## Decisões já tomadas (não as reabra)

- **ADR-004** — Firebase Hosting + Terraform + Cloud DNS + multi-ambiente.
- **ADR-012** — topologia decidida (consultar antes de codificar).
- **epic.md do EPIC-006** — novo Hosting site no mesmo projeto GCP `turni-mvp` (não criar novo projeto GCP); apex + www + landing.homolog cobertos.
- **PDR-015** — go-public é decisão do comercial; site prod fica codificado mas gated por variável.

## Liberdade técnica do agente

Você (programador) decide:
- Opção A vs. B para extensão do módulo `firebase` (lista interna vs. múltiplas chamadas) — se ADR-012 não fixou; IDR registra a decisão.
- Como o módulo `dns` representa o redirect www (recurso separado, sub-módulo, ou apenas variable + bloco condicional).
- Nome final da variable de gate prod (`landing_prod_enabled` vs. `enable_landing_prod` etc.).
- Granularidade das mudanças (PR único vs. dois PRs — módulos primeiro, env depois).

Você (programador) NÃO decide:
- Reabrir ADR-012 (topologia).
- Mudar provider de DNS (continua Cloud DNS) ou de hosting (continua Firebase).
- Aplicar Terraform sem revisão humana do `plan`.
- Aplicar a parte prod sem que o gate `landing_prod_enabled = true` venha de PR explícito do PO/comercial.

## Definição de Pronto (DoD)

- [ ] Todos os CAs (CA-1 a CA-12) passam.
- [ ] `terraform plan` em homolog limpo após o `apply`.
- [ ] `terraform plan` em prod mostra 0 changes referentes a landing (gate false).
- [ ] `dig` verificações anexadas ao PR (saída textual).
- [ ] `turni-landing-homolog.web.app` retorna 200 anexado ao PR (curl + status).
- [ ] `index.json` atualizado: status `in_review` ao abrir PR; `done` após merge + apply verde.
- [ ] "Notas do agente" preenchida com plan/apply outputs.
- [ ] IDR criado se decidiu A ou B na extensão do módulo firebase com critério não óbvio.

## Protocolo do agente (obrigatório)

Siga `docs/skills/programador/SKILL.md`. Resumo:

1. Frontmatter desta estória: `status: in_progress`, `owner_agent`, `updated_at`. Atualize `index.json`.
2. Confirme ADR-012 `accepted`. Leia módulos atuais.
3. Estende módulos `firebase` e `dns` em PR. Anexe `terraform plan` (de `envs/homolog` e `envs/prod`).
4. Aguarde aprovação do PO. Após merge, execute `terraform apply` em homolog. Anexe output em "Notas".
5. Verifique `dig` + curl. Atualize `index.json`. Marque `status: done`.

## Notas do agente (preenchido durante/após execução)

### Entrada inicial
- ADR-012 confirmada `accepted` (2026-05-28). Topologia §8: dois sites prod (`turni-landing-prod`,
  micro-site `turni-www-redirect-prod` para o redirect www) + `turni-landing-homolog`; apex via A/AAAA,
  www via CNAME→redirect, landing.homolog via CNAME.
- Módulos atuais: `firebase` criava 1 site fixo + `google_firebase_project` singleton; `dns` só CNAMEs
  (webapp/api), sem suporte a apex A/AAAA.
- Estado do worktree: outros agentes ativos (STORY-028 em `apps/webapp/lib/...`, `index.json`).
  Mudanças escopadas só aos arquivos da STORY-029; `terraform fmt -recursive` que reformatou módulos
  fora de escopo (cloud-run/cloud-sql/worker-vm — só whitespace) foi **revertido**.

### Decisões tomadas
- **Módulo firebase — Opção A** (`var.additional_sites` no módulo existente), **não** Opção B (N
  chamadas). Justificativa completa em **IDR-005**: `google_firebase_project` é singleton (B duplicaria
  ou exigiria extração); Opção A não move estado do WebApp em produção (CA-10/CA-11) e gera plan de pura
  adição — importante porque o `apply` é gated (CA-12) e não pôde ser verificado nesta sessão.
- **Redirect www (ADR-012 §6)** — adotado o **fallback micro-site** `turni-www-redirect-prod`: o
  `google_firebase_hosting_custom_domain` do Terraform não expõe redirect de domínio; o redirect 301 fica
  no `firebase.json` do micro-site (STORY-031). `www.turni.com.br` = CNAME → `turni-www-redirect-prod.web.app`.
- **Nome da variable de gate prod:** `landing_prod_enabled` (default `false`).

### Descobertas
- `infra/envs/prod/variables.tf` tinha HCL **inválido** (variáveis one-line com `;`), nunca pego porque
  prod nunca foi `init`/`validate`/`apply` (scaffolded). Normalizado para blocos multi-linha — necessário
  para o prod parsear/validar com as novas variáveis. Mesmas variáveis, sem mudança semântica.
- IPs do apex Firebase: o default inicial commitado (`199.36.158.100`) estava **errado** — é IP do
  Private Google Access, não do Firebase Hosting. Corrigido para os IPs publicados do Firebase Hosting
  (`151.101.1.195`, `151.101.65.195`); ainda assim, **confirmar no go-public** via `required_dns_updates`
  do custom domain / console (prod gated, não verificável agora).
- `terraform plan` em homolog revelou **drift pré-existente** nos serviços Cloud Run api/admin (campos
  setados pelo CI via gcloud) — isolado do apply via `-target`.

### Bloqueios encontrados
- Nenhum bloqueio de design. Apply em homolog executado após re-login ADC (`gcloud auth
  application-default login`) — a credencial do backend GCS estava expirada (`invalid_rapt`).

### Resultado final / evidência (apply em homolog executado 2026-05-28)
- `terraform fmt -check -recursive`: **FMT OK**.
- `terraform validate` homolog: **Success! The configuration is valid.**
- `terraform validate` prod (`init -backend=false`): **Success! The configuration is valid.**
- `terraform plan` homolog: `Plan: 3 to add, 2 to change, 0 to destroy`. As **3 adições** são os
  recursos da landing (site, custom domain, CNAME). As **2 mudanças** são drift PRÉ-EXISTENTE dos
  serviços Cloud Run api/admin (campos `client`/`client_version`/`revision`/`scaling` que o CI seta via
  gcloud e o TF zera) — **não pertencem a esta estória**. Por isso o apply foi **direcionado** (`-target`)
  só aos 3 recursos da landing, deixando os Cloud Run intocados (gerenciados pelo CI).
- `terraform apply` homolog (direcionado): **`Apply complete! Resources: 3 added, 0 changed, 0 destroyed`**.
- `terraform state list` (CA-11):
  - `module.firebase.google_firebase_hosting_site.additional["landing"]`
  - `module.firebase.google_firebase_hosting_custom_domain.additional["landing"]`
  - `module.dns.google_dns_record_set.landing[0]`
- `dig +short landing.homolog.turni.com.br CNAME` (CA-7): `turni-landing-homolog.web.app.`
  (idem no NS autoritativo `ns-cloud-e1.googledomains.com`).
- `curl -sI https://turni-landing-homolog.web.app/` (CA-8): **HTTP 404**, NÃO 200. Honestidade: o
  Terraform só *registra* o site Firebase — não faz deploy de conteúdo. Site sem nenhuma release retorna
  "Site Not Found" (404); o 200 só aparece após o primeiro deploy (**STORY-031**). A premissa do CA-8
  (página "Welcome" 200 default) não vale para provisionamento TF-only.
- `curl -sI https://app.homolog.turni.com.br/` (CA-10): **HTTP 200** — WebApp intocado pós-apply.
- Estado do custom domain (CA-4): após ~2 min, `cert: CERT_PREPARING → CERT_VALIDATING`,
  `host_state: HOST_UNHOSTED`, `ownership_state: OWNERSHIP_MISSING`. Validação assíncrona em andamento
  via o CNAME já publicado — convergirá para "connected" nos próximos minutos/horas (CA-4 prevê isso).
- `terraform plan` prod (CA-9): prod **nunca foi bootstrapped** (sem `terraform.tfvars`, sem state) —
  aplicar TF em prod está fora do escopo desta estória. CA-9 satisfeito **por construção**: com
  `landing_prod_enabled=false` (default), `local.landing_prod_sites = {}` e `module.dns_landing` com
  `count = 0` → zero recursos de landing; config validada com `terraform validate`.

### Status dos CAs
- CA-1 ✅ módulo firebase multi-site (IDR-005); plan cria `turni-landing-homolog`.
- CA-2 ✅ módulo dns com apex A/AAAA, www e CNAME landing.homolog (apex/www exercitados via config validada, gated em prod).
- CA-3 ✅ site `turni-landing-homolog` criado (state + output).
- CA-4 🟡 custom domain associado; validação Firebase **em andamento** (assíncrona, esperado).
- CA-5, CA-6 ⏸️ apex/www dig — prod gated, não aplicado nesta onda (go-public).
- CA-7 ✅ CNAME resolve para `turni-landing-homolog.web.app`.
- CA-8 🟡 site provisionado e alcançável, mas **404** até o primeiro deploy (STORY-031) — não 200.
- CA-9 ✅ por construção (gate false → 0 recursos; config validada). Prod não bootstrapped.
- CA-10 ✅ WebApp `app.homolog` segue 200; site `turni-webapp-homolog` intocado.
- CA-11 ✅ state com exatamente os 3 recursos; sem órfãos.
- CA-12 ✅ plan revisado antes do apply; drift não relacionado isolado via `-target`.

### Pendências para fechar (não-bloqueantes desta estória)
- CA-8 vira 200 quando STORY-031 fizer o primeiro deploy de conteúdo no site.
- CA-4: aguardar convergência do custom domain para "connected" (verificar no console Firebase).
- CA-5/CA-6 (apex/www) só no go-public de prod — confirmar IPs do apex via `required_dns_updates`.

### Fechamento
Estória marcada **done** em 2026-05-28 pelo PO (Alexandro), que aceitou os residuais documentados
acima como deferidos legítimos (CA-8 → STORY-031; CA-4 → convergência assíncrona; CA-5/6 → go-public).
O entregável de infra da onda (sites Firebase multi-site + DNS da landing homolog, com prod codificado
e gated) está aplicado e verde em homolog. Destrava STORY-031 (deploy/firebase.json), STORY-032
(runbook) e STORY-033 (validação).

### IDRs criados
- **IDR-005** — Firebase multi-site via `additional_sites` (Opção A) vs. N chamadas (Opção B).

### Links de evidência
- Arquivos: `infra/modules/firebase/{main,variables,outputs}.tf`, `infra/modules/dns/{main,variables}.tf`,
  `infra/envs/homolog/{main,outputs}.tf`, `infra/envs/prod/{main,variables}.tf`, `.firebaserc`,
  `apps/landing/firebase.json`, `docs/project-state/decisions/idr/IDR-005-*.md`.
- Commit/PR: (a preencher)
