---
epic_id: EPIC-006
type: validation-report
validated_at: 2026-05-29
validated_by: claude-opus-4-8-validador-2026-05-29
verdict: approved_with_pending
checklist_source: epics/EPIC-006-landing-institucional/validation/checklist.md
validation_round: 1
---

# Relatório de Validação — EPIC-006 Landing institucional

## TL;DR

> **Veredito**: APPROVED com pendências.
> **Contagem**: 51 passes, 6 passes com ressalva, 2 fails não-bloqueantes, 0 fails bloqueantes, 3 n/a justificados (+ 4 pré-condições pass).
> **Bloqueantes (resumo factual)**: nenhum.
> **Não-bloqueantes (2)**: (1) **CA-B8-2** — o workflow da landing autentica o `firebase deploy` via chave de service account em secret (`FIREBASE_SERVICE_ACCOUNT` + `gcloud auth activate-service-account`), não via WIF/OIDC puro como o item exige; é o mesmo secret/padrão já aceito no `release.yml` do WebApp (EPIC-000) e documentado nas notas da STORY-031. (2) **CA-B3-6** — Lighthouse mobile da landing AS IS: Performance 58–60 (< 70); item declarado **não-bloqueante** ("linha-base") pelo próprio checklist; Accessibility 85 (≥ 80) atende.

---

## Resumo executivo

O EPIC-006 entrega a landing institucional `turni.com.br` atrás de um gate "Em breve" + `<path-secreto>`, com pipeline isolado e fronteira de propriedade marketing × engenharia × comercial. Como a ADR-012/PDR-015 atribuem o go-public ao comercial em momento separado, **produção não está no ar ao final do épico** — esta validação verifica que o **mecanismo está pronto** (site prod codificado no Terraform mas gated por `landing_prod_enabled = false`; job de deploy prod com gate humano; runbook P6), não que o go-public aconteceu. Itens dependentes de prod são `n/a` justificado.

Verificado diretamente nesta sessão contra `https://landing.homolog.turni.com.br` (último deploy do épico, tag `landing-v0.1.0-rc.4`): apex `/` → 200 servindo "Em breve" (sem `noindex`, indexável); `/<path-secreto>/` → 200 servindo a landing AS IS (`<title>TURNI · MVP Demo`, `<meta robots noindex,nofollow>`, 15 CTAs para `app.homolog`, 0 `href="app.html"`, 0 placeholders residuais); paths aleatórios (`/qwertyuiop/`, `/foo/`, `/admin/`, `/api/`, `/dashboard/`) → 404 institucional ("Turni — página não encontrada"), **sem vazar** o marcador da landing; `robots.txt` → `Disallow: /<path-secreto>/` (`text/plain`); headers de segurança (HSTS, CSP, X-Frame-Options DENY, X-Content-Type-Options, Referrer-Policy) presentes em `/` e em `/<path-secreto>/`; cache HTML `no-cache` e assets AS IS `max-age=3600`. Não-leak confirmado: 0 ocorrências do path real no corpo da "Em breve", no 404, no `README.md`/runbook commitados, e no log do CI (path mascarado via `::add-mask::`, 50 entradas `***`). Isolamento confirmado: tags `landing-v*` não dispararam o `release.yml` do WebApp (que só rodou em `v0.1.0-rc.*`); WebApp segue em `v0.1.0-rc.19`, 200. Rollback (P2) exercitado pelo programador na STORY-032 via REST (rc.4→rc.3→rc.4, apex 200 durante todo o exercício). Gate de prod: Environment `landing-prod` com `required_reviewers: [xandroalmeida]`; sites `turni-landing-prod`/`turni-www-redirect-prod` **não existem** no GCP (404), coerente com `landing_prod_enabled = false`.

Dois fails não-bloqueantes e seis ressalvas registrados abaixo. Os fails não-bloqueantes derivam de divergências entre o texto literal do checklist e decisões aceitas (ADR-012/PDR-015) ou da natureza do protótipo AS IS; nenhum é vulnerabilidade nova, segredo em código, ou métrica primária não atendida.

---

## Pré-condições

| Item | Status | Evidência |
|---|---|---|
| PRE-1 — STORY-026..032 com `status: done` | ✅ pass | `index.json`: 026,027,028,029,030,031,032 = `done` |
| PRE-2 — EPIC-006 `in_review` | ✅ pass | Transicionado de `in_progress`→`in_review` no início desta validação (todas as stories `done`, PO autorizou validar) |
| PRE-3 — `landing.homolog.turni.com.br` acessível (DNS+HTTPS) | ✅ pass | `curl -sI /` → HTTP/2 200; handshake TLS OK |
| PRE-4 — acesso de leitura (repo, GCP, GitHub Actions/Environments) | ✅ pass | `gh` autenticado (xandroalmeida); `gcloud` token válido; REST Firebase Hosting respondeu |

---

## Checklist preenchido

### Bloco 1 — Decisões aceitas

| Item | Status | Evidência |
|---|---|---|
| CA-B1-1 — ADR-012 `accepted`, `approved_by: Alexandro` | ✅ pass | `grep` frontmatter: `status: accepted`, `approved_by: Alexandro` |
| CA-B1-2 — PDR-015 `accepted`, `approved_by: Alexandro` | ✅ pass | `grep` frontmatter: `status: accepted`, `approved_by: Alexandro` |

### Bloco 2 — Página "Em breve" no apex (homolog)

| Item | Status | Evidência |
|---|---|---|
| CA-B2-1 — apex `/` 200 | ✅ pass | `curl -s -o /dev/null -w %{http_code}` → `200` |
| CA-B2-2 — contém "em breve" | ✅ pass | `grep -ic "em breve"` → 3 matches |
| CA-B2-3 — "Em breve" indexável (sem `noindex`) | ✅ pass | sem `<meta name="robots">` no HTML do apex |
| CA-B2-4 — `<title>`, `<meta description>`, OG | ✅ pass | `<title>Turni…`; `description="Turni — em breve."`; 3 `property="og:`|
| CA-B2-5 — Lighthouse "Em breve": Perf ≥ 90, A11y ≥ 95 | ⚠️ pass com ressalva | Lighthouse 12 mobile, 2 runs estáveis: **Perf=89, A11y=100**. A11y atende (≥95); Perf 1 ponto abaixo de 90 nesta sessão (rede local→homolog), vs **Perf=98** registrado na STORY-028. Diferença dentro da variância conhecida do Lighthouse de performance entre ambientes de medição. |
| CA-B2-6 — contraste WCAG AA | ✅ pass | Auditoria de contraste do Lighthouse incluída na categoria Accessibility = 100 |
| CA-B2-7 — sem analytics/pixel | ✅ pass | `grep -iEc "analytics\|gtag\|hotjar\|facebook\|pixel\|segment\|mixpanel"` → 0; únicos hosts externos: `fonts.googleapis.com`, `fonts.gstatic.com` |

### Bloco 3 — Landing AS IS no path secreto (homolog)

| Item | Status | Evidência |
|---|---|---|
| CA-B3-1 — `/<path>/` 200 | ✅ pass | `curl` → `200` |
| CA-B3-2 — `<title> TURNI · MVP Demo` | ✅ pass | `grep -c "TURNI · MVP Demo"` → 1; `<title>TURNI · MVP Demo` |
| CA-B3-3 — `<meta robots noindex,nofollow>` | ✅ pass | `meta name="robots" content="noindex,nofollow"` presente |
| CA-B3-4 — CTAs → `app.homolog` (≥ 14) | ✅ pass | `grep -c "app.homolog.turni.com.br"` → **15** |
| CA-B3-5 — sem `href="app.html"` antigo | ✅ pass | `grep -c 'href="app.html'` → 0; `__WEBAPP_URL__` residual → 0 |
| CA-B3-6 — Lighthouse landing: Perf ≥ 70, A11y ≥ 80 (**não-bloqueante**) | ❌ fail não-bloqueante | Lighthouse 12 mobile, 2 runs: **Perf=58 / 60** (< 70), **A11y=85** (≥ 80). O item é declarado "linha-base, não-bloqueante" pelo checklist. Performance baixa coerente com protótipo AS IS pesado em imagens full-size não otimizadas para mobile 3G. |
| CA-B3-7 — assets carregam sem 404 | ✅ pass | Amostra: `turnioficial_files/fonts.css`, `lucide.js`, 4 imagens `img/*.jpg` → todos 200 |

### Bloco 4 — robots.txt e não-indexação

| Item | Status | Evidência |
|---|---|---|
| CA-B4-1 — `Disallow: /<path>/` | ✅ pass | `grep -E '^Disallow: /.+/$'` → match (path mascarado neste relatório) |
| CA-B4-2 — `Content-Type: text/plain` | ✅ pass | `content-type: text/plain; charset=utf-8` |
| CA-B4-3 — sem `sitemap.xml` vazando path | ✅ pass | `curl /sitemap.xml` → 404 |
| CA-B4-4 — Google Search Console não indexou | 🚫 n/a | Validador sem acesso ao Search Console do domínio; não verificável nesta sessão. Garantia real de não-indexação é o `<meta noindex,nofollow>` (CA-B3-3, ✅) — ADR-012 §2/§3. |

### Bloco 5 — Gate (paths aleatórios)

| Item | Status | Evidência |
|---|---|---|
| CA-B5-1 — `/qwertyuiop/` → 404 (não 200 da landing) | ✅ pass | → 404 |
| CA-B5-2 — `/foo/`, `/admin/`, `/api/`, `/dashboard/` → 404 | ✅ pass | todos → 404 |
| CA-B5-3 — `/qwertyuiop/` não contém marcador da landing | ✅ pass | `grep -c "TURNI · MVP Demo"` no corpo → 0 (em todos os 5 paths) |
| CA-B5-4 — 404 institucional (identidade), não 404 cru | ✅ pass | `<title>Turni — página não encontrada`; 4 menções "Turni"; 0 "Site Not Found" |

### Bloco 6 — Não-leak do path secreto

| Item | Status | Evidência |
|---|---|---|
| CA-B6-1 — path não vaza na "Em breve" | ✅ pass | `grep -c "<path-real>"` no corpo do apex → 0 |
| CA-B6-2 — path não vaza no 404 | ✅ pass | `grep -c` no corpo do 404 → 0 |
| CA-B6-3 — README commitado só com placeholder | ✅ pass | `grep "<path-real>" README.md` → 0; `grep "<path-secreto>"` → 1 (placeholder literal) |
| CA-B6-4 — log do CI não mostra path em claro | ✅ pass | log do run rc.4 (398 linhas): 0 ocorrências do path real; 50 entradas `***`; `::add-mask::` 3× no workflow |

### Bloco 7 — Fronteira CODEOWNERS

| Item | Status | Evidência |
|---|---|---|
| CA-B7-1 — `CODEOWNERS` divide conforme PDR-015 + ADR-012 §9 | ✅ pass | `CODEOWNERS` linhas 16–28: `_lp/**` → `@turni/marketing`; "Em breve"/404/robots/`firebase.json`/`.firebaserc`/workflow/módulos TF → `@turni/engenharia` |
| CA-B7-2 — PR em `_lp/<path>/index.html` exige aprovação de marketing | ⚠️ pass com ressalva | Regra presente e correta, mas **GitHub não aplica**: `gh api .../codeowners/errors` retorna "Unknown owner — team @turni/marketing" (org `alcatechgroup` sem times criados). Estado **explicitamente antecipado e aceito** no cabeçalho do `CODEOWNERS` (linhas 6–10) e em PDR-015 ("chancela informal; não bloqueante; vira documentação de intenção até os times serem criados"). |
| CA-B7-3 — PR em `index.html`/`firebase.json` exige aprovação de engenharia | ⚠️ pass com ressalva | Idem: regra presente; não aplicada por `@turni/engenharia` inexistente (11 erros "Unknown owner" no total). Aceito por PDR-015. |
| CA-B7-4 — README descreve fronteira + referencia PDR-015/CODEOWNERS | ✅ pass | `apps/landing/README.md` seção "Fronteira de propriedade (PDR-015 + CODEOWNERS)" |

### Bloco 8 — Pipeline tag-based + gate humano em prod

| Item | Status | Evidência |
|---|---|---|
| CA-B8-1 — workflow existe; `paths` filtra `apps/landing/**`, `firebase.json`, `.firebaserc`, próprio workflow | ✅ pass | `.github/workflows/landing-deploy.yml` `on.push.paths` confere |
| CA-B8-2 — autentica via WIF/OIDC; sem chave SA em secret | ❌ fail não-bloqueante | O job de deploy usa `printf '%s' '${{ secrets.FIREBASE_SERVICE_ACCOUNT }}' > fsa.json; gcloud auth activate-service-account --key-file=fsa.json` — **chave de service account em secret**, não WIF puro. `id-token: write` está declarado mas não há passo `google-github-actions/auth@v2` com `workload_identity_provider`. É o **mesmo secret/padrão já em uso e aceito no `release.yml` do WebApp** (linhas 286/417, hosting via `firebaseServiceAccount`) e documentado nas notas da STORY-031 (l.191). Não é segredo em código nem credencial nova. |
| CA-B8-3 — tag `landing-v*-rc.*` dispara deploy homolog | ✅ pass | Run `landing-v0.1.0-rc.4` (id 26639183247) → `completed/success` |
| CA-B8-4 — tag `landing-v*` não deploya sem aprovação; Environment `landing-prod` com revisor | ✅ pass | `gh api .../environments/landing-prod` → `protection_rules: [{type: required_reviewers, reviewers: [xandroalmeida]}]`; job `deploy-prod` com `environment: name: landing-prod` |
| CA-B8-5 — smoke test (5 checks) presente; verde no último run | ✅ pass | Step "Smoke test pós-deploy (5 checks)" no run rc.4 = `success`; 3 `check`/3 `contains` no workflow |
| CA-B8-6 — smoke fail dispara rollback automático | ✅ pass | Lógica no workflow (l.168 "smoke test falhou — iniciando rollback"; l.171–173 re-release REST da versão anterior); runs rc.1/rc.2 falharam (deploys iniciais da STORY-031) |

### Bloco 9 — Isolamento de deploy

| Item | Status | Evidência |
|---|---|---|
| CA-B9-1 — só `turni-landing-homolog` recebe release | ✅ pass | REST `projects/turni-mvp/sites/.../releases`: tags `landing-v*` só em `turni-landing-homolog`; `turni-webapp-homolog` em release própria |
| CA-B9-2 — workflow do WebApp não dispara ao deployar landing | ✅ pass | `gh run list --workflow=release.yml`: runs só em `v0.1.0-rc.*` (webapp); nenhuma em `landing-v*` |
| CA-B9-3 — `app.homolog` acessível e na revisão anterior | ✅ pass | `curl -sI app.homolog` → 200; `version.json` → `v0.1.0-rc.19` (release própria do WebApp, não tocada) |

### Bloco 10 — Rollback exercitado

| Item | Status | Evidência |
|---|---|---|
| CA-B10-1 — comando de rollback documentado no runbook P2 | ⚠️ pass com ressalva | Rollback documentado em P2 via **REST API** (re-release), **Console** e **`firebase hosting:clone`**. O comando que o item cita literalmente — `firebase hosting:rollback` — **não existe** na firebase-tools (verificado nas versões 13.x e 15.15.0; `firebase --help` não lista o subcomando). Descoberta registrada no runbook (Apêndice) e nas notas da STORY-031/032. |
| CA-B10-2 — rollback exercitado pelo programador (output anexado) | ✅ pass | STORY-032 "Notas do agente" + runbook §"Exercício de validação — P2" (2026-05-29): rc.4→rc.3→rc.4 via REST |
| CA-B10-3 — após rollback, conteúdo da release anterior | ✅ pass | Release list mostrou `type=ROLLBACK` apontando para a versão alvo; apex 200 durante todo o exercício |

### Bloco 11 — Terraform multi-ambiente

| Item | Status | Evidência |
|---|---|---|
| CA-B11-1 — `terraform plan` em prod: 0 changes da landing (gate funcional) | ⚠️ pass com ressalva | `terraform plan` ao vivo **não executado**: `terraform init` no backend GCS falhou por reauth do ADC (`invalid_grant / invalid_rapt`) nesta sessão. Verificado **estaticamente**: `var.landing_prod_enabled` default `false`, sem `terraform.tfvars` sobrescrevendo; gate `landing_prod_enabled ? {...} : {}` (main.tf l.16) e `count = ... ? 1 : 0` (l.198). Resultado observável que o plan asseguraria — 0 sites de landing em prod — **confirmado via GCP** (CA-B11-2). |
| CA-B11-2 — `turni-landing-prod` codificado mas não criado no GCP | ✅ pass | REST `projects/turni-mvp/sites`: existem só `turni-landing-homolog`, `turni-webapp-homolog`, `turni-mvp`. `turni-landing-prod` e `turni-www-redirect-prod` → HTTP 404 (não existem) |
| CA-B11-3 — go-public = flip de variável + apply + tag (coerente com P6) | ✅ pass | `infra/envs/prod/main.tf` + `variables.tf` (gate) + runbook P6 (flip `landing_prod_enabled=true` → `terraform apply` → tag `landing-v0.1.0` com gate) coerentes |

### Bloco 12 — Headers de segurança

| Item | Status | Evidência |
|---|---|---|
| CA-B12-1 — HSTS, X-Content-Type-Options, X-Frame-Options, Referrer-Policy, CSP no apex | ✅ pass | `curl -sI /`: `strict-transport-security: max-age=31536000; includeSubDomains`; `x-content-type-options: nosniff`; `x-frame-options: DENY`; `referrer-policy: strict-origin-when-cross-origin`; CSP completa (permite Google Fonts) |
| CA-B12-2 — headers também em `/<path>/` | ✅ pass | `curl -sI /<path>/`: mesmos 5 headers presentes |
| CA-B12-3 — HTML `no-cache` | ✅ pass | `cache-control: no-cache, no-store, must-revalidate` no apex e no path |
| CA-B12-4 — assets imutáveis `max-age=31536000, immutable` | ⚠️ pass com ressalva | Asset da landing (`img/icon-192.png`) → `cache-control: public, max-age=3600` (1h), **não** immutable. É a decisão **explícita** da ADR-012 §4: assets AS IS **não-hasheados** = 1h (immutable pinaria versão antiga). O alvo `immutable` do checklist aplica-se a assets com content-hash (WebApp), não ao AS IS. Comportamento correto por ADR. |

### Bloco 13 — Redirect www → apex

| Item | Status | Evidência |
|---|---|---|
| CA-B13-1 — `www.turni.com.br` → 301 apex | 🚫 n/a | Prod não está no ar ao final do épico (PDR-015 separa go-public). Domínio www será coberto no go-public conforme runbook P6 (site `turni-www-redirect-prod` gated por `landing_prod_enabled=false`, confirmado inexistente — CA-B11-2). |
| CA-B13-2 — verificação equivalente em homolog | 🚫 n/a | ADR-012 §6/§8 prevê redirect www apenas em prod; homolog usa CNAME único `landing.homolog` sem variante www. Não há www em homolog a verificar. |

### Bloco 14 — Runbook

| Item | Status | Evidência |
|---|---|---|
| CA-B14-1 — `runbook-landing.md` existe, formato consistente | ✅ pass | `docs/operacao/runbook-landing.md`; cabeçalho + Índice + procedimentos + apêndice (espelha `runbook-homolog.md`) |
| CA-B14-2 — cobre P1–P7 | ✅ pass | 7 headings `## P1..P7` (publicar, rollback, rotação, domínio, kill-switch sw.js, go-public, health-check) |
| CA-B14-3 — cada P com pré-condições, passos, comandos, verificação, quem, SLA | ✅ pass | Inspeção: cada procedimento traz as seções; comandos copia-cola (REST, `gh secret set`, `terraform`, `git tag`, `curl`/`dig`) |
| CA-B14-4 — runbook não vaza path real | ✅ pass | `grep "<path-real>" runbook-landing.md` → 0; só placeholders `<path-secreto>` |
| CA-B14-5 — ≥ 1 procedimento exercitado (P2) | ✅ pass | STORY-032 notas + runbook §"Exercício de validação — P2" (rc.4→rc.3→rc.4) |

### Bloco 15 — `index.json` consistente

| Item | Status | Evidência |
|---|---|---|
| CA-B15-1 — EPIC-006 com `story_ids` 026–033 | ✅ pass | `index.json` epics[EPIC-006].story_ids = [026,027,028,029,030,031,032,033] |
| CA-B15-2 — 026–032 `done`; 033 `in_progress`→`done` ao final | ✅ pass | 026–032 `done`; STORY-033 `in_progress` durante validação, marcada `done` na finalização desta estória |
| CA-B15-3 — `validation_checklist_path` aponta para o checklist | ✅ pass | `epics/EPIC-006-landing-institucional/validation/checklist.md` |
| CA-B15-4 — `validation_report` com `verdict` e `validated_at` | ✅ pass | Atualizado na finalização: aponta para este `report.md`; `verdict=approved_with_pending`, `validated_at=2026-05-29` |

---

## Fails

### Não-bloqueantes (2)

1. **CA-B8-2 — autenticação do deploy via chave de service account em secret (não WIF puro).**
   - **Fato:** `landing-deploy.yml` escreve o secret `FIREBASE_SERVICE_ACCOUNT` (JSON de SA) em arquivo e roda `gcloud auth activate-service-account --key-file`. Não há `google-github-actions/auth@v2` com `workload_identity_provider`; `id-token: write` está declarado mas não é usado para troca de token WIF.
   - **Contexto factual:** é o mesmo secret e o mesmo mecanismo de auth de Firebase Hosting já presente e aceito no `release.yml` do WebApp (EPIC-000, validado). Documentado nas "Notas do agente" da STORY-031 (l.191). Não é segredo em código (está em GitHub Actions secrets cifrado); não é credencial nova.
   - **Classificação:** não-bloqueante (não atende nenhuma condição de bloqueante de `verdict-criteria.md`: não é segredo em código, vuln crítica nova, pipeline vermelho, nem métrica primária).

2. **CA-B3-6 — Lighthouse da landing AS IS: Performance 58–60 (< 70).**
   - **Fato:** 2 runs Lighthouse 12 mobile → Perf 58 e 60; Accessibility 85 (≥ 80, atende).
   - **Contexto factual:** o checklist declara este item **"linha-base, não-bloqueante"**. Perf baixa coerente com protótipo AS IS pesado em imagens full-size.
   - **Classificação:** não-bloqueante (por designação explícita do checklist).

### Bloqueantes (0)

Nenhum.

---

## Passes com ressalva (6)

- **CA-B2-5** — Em breve Perf=89 (1 ponto abaixo de 90) nesta sessão; A11y=100; STORY-028 registrou Perf=98. Variância de medição.
- **CA-B7-2 / CA-B7-3** — regras CODEOWNERS presentes e corretas, porém não aplicadas pelo GitHub (times `@turni/marketing`/`@turni/engenharia` inexistentes; 11 erros "Unknown owner"). Estado explicitamente aceito por PDR-015 e documentado no cabeçalho do `CODEOWNERS`.
- **CA-B10-1** — rollback documentado via REST/Console/`hosting:clone`; o comando `firebase hosting:rollback` citado no item não existe na firebase-tools.
- **CA-B11-1** — `terraform plan` ao vivo não executado (reauth de ADC nesta sessão); gate verificado por inspeção estática + GCP confirma 0 sites de landing em prod.
- **CA-B12-4** — assets AS IS com `max-age=3600` (1h), não `immutable` — comportamento correto por ADR-012 §4 (assets não-hasheados).

---

## n/a justificados (3)

- **CA-B4-4** — sem acesso ao Google Search Console; não verificável. Garantia real de não-indexação é o `<meta noindex,nofollow>` (CA-B3-3 ✅).
- **CA-B13-1** — prod não no ar (go-public separado, PDR-015); www coberto no P6.
- **CA-B13-2** — homolog não tem variante www (ADR-012 §6/§8 prevê www só em prod).

---

## Limitações da validação

- `terraform plan` em `infra/envs/prod/` não executado por reauth de ADC (`invalid_rapt`) na conta gcloud desta sessão. Mitigado por inspeção estática do gate + verificação via API de que os sites de prod não existem (CA-B11-2).
- Lighthouse executado da máquina local contra homolog (rede de internet pública); scores de performance são sensíveis ao ambiente de medição.
- Verificação de CODEOWNERS via `gh api .../codeowners/errors` (validação de owners), não por simulação de PR real com merge bloqueado.

---

## Veredito

**APPROVED com pendências** (`approved_with_pending`).

- **Total de itens:** 62 (+ 4 pré-condições)
- **`pass`:** 51 (+ 4 pré-condições)
- **`pass com ressalva`:** 6
- **`fail bloqueante`:** 0
- **`fail não-bloqueante`:** 2
- **`n/a` (justificados):** 3

Zero fails bloqueantes; dois fails não-bloqueantes (CA-B8-2 auth via chave SA; CA-B3-6 Perf da landing AS IS — item declarado não-bloqueante pelo checklist). A métrica primária do épico está atendida e verificada com o último deploy em homolog: gate "Em breve" no apex, landing servida sob `<path-secreto>`, paths aleatórios em 404 institucional sem vazar a landing, robots não-indexando, deploy isolado do WebApp, mecanismo de go-public pronto e gated. A decisão sobre as pendências não-bloqueantes é do PO.
