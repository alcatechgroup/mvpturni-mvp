---
epic_id: EPIC-006
type: validation-checklist
created_at: 2026-05-28
created_by: PO (Alexandro / Claude)
status: empty  # empty → in_progress (validador trabalhando) → filled
---

# Checklist de validação — EPIC-006 Landing institucional

> **Para o Validador da STORY-033**: preencha cada item com status (`pass` | `pass com ressalva` | `fail bloqueante` | `fail não-bloqueante` | `n/a`) e **evidência observável** (comando + saída, log, screenshot, query, URL testada). Não proponha estórias de correção; não sugira próximos passos; apenas fato + veredito. Aprendizado da rodada 1 da STORY-011 (EPIC-000) e da STORY-025 (EPIC-001).

> **Particularidade deste épico**: prod **não** está no ar ao final do EPIC-006 (PDR-015 atribui go-public ao comercial em momento separado). Itens que dependem de prod (apex respondendo, www→apex efetivo) são `n/a` justificado neste relatório — viram validação separada quando comercial autorizar.

---

## Pré-condições de início

- [ ] **PRE-1:** STORY-026 a STORY-032 com `status: done` no `index.json`.
- [ ] **PRE-2:** EPIC-006 com `status: in_review` no `index.json`.
- [ ] **PRE-3:** `landing.homolog.turni.com.br` acessível (DNS resolvendo, HTTPS válido).
- [ ] **PRE-4:** Acesso de leitura ao repositório, ao GCP `turni-mvp` (Cloud Console + Firebase), ao GitHub Actions runs e Environments.

---

## Bloco 1 — Decisões aceitas (artefatos)

- [ ] **CA-B1-1:** ADR-012 existe em `decisions/adr/ADR-012-landing-gate-em-breve-path-secreto.md`, `status: accepted`, `approved_by: Alexandro` preenchido. `index.json` reflete.
- [ ] **CA-B1-2:** PDR-015 existe em `decisions/pdr/PDR-015-fronteira-marketing-engenharia-comercial-landing.md`, `status: accepted`, `approved_by: Alexandro` preenchido. `index.json` reflete.

---

## Bloco 2 — Página "Em breve" no apex (homolog)

- [ ] **CA-B2-1:** `curl -sI https://landing.homolog.turni.com.br/` retorna `200 OK`.
- [ ] **CA-B2-2:** `curl -s https://landing.homolog.turni.com.br/ | grep -i "em breve"` retorna match (ou marcador único decidido em STORY-028).
- [ ] **CA-B2-3:** `curl -s https://landing.homolog.turni.com.br/ | grep -i 'meta name="robots"'` **não** contém `noindex` (Em breve é indexável).
- [ ] **CA-B2-4:** Página "Em breve" tem `<title>`, `<meta name="description">` e Open Graph mínimo presente.
- [ ] **CA-B2-5:** Lighthouse mobile na Em breve: Performance ≥ 90, Accessibility ≥ 95. Anexar screenshot do relatório.
- [ ] **CA-B2-6:** Contraste WCAG AA verificado nos elementos de texto da Em breve.
- [ ] **CA-B2-7:** Em breve **não** carrega scripts de analytics/pixel — verificar com DevTools → Network (apenas fontes do Google Fonts e assets locais).

---

## Bloco 3 — Landing AS IS no path secreto (homolog)

- [ ] **CA-B3-1:** `curl -sI https://landing.homolog.turni.com.br/<path-secreto>/` retorna `200 OK`.
- [ ] **CA-B3-2:** `curl -s https://landing.homolog.turni.com.br/<path-secreto>/ | grep -i "TURNI · MVP Demo"` retorna match (ou marcador único do `<title>` da landing AS IS).
- [ ] **CA-B3-3:** `curl -s https://landing.homolog.turni.com.br/<path-secreto>/ | grep 'meta name="robots"'` retorna `<meta name="robots" content="noindex,nofollow">`.
- [ ] **CA-B3-4:** CTAs da landing apontam para `app.homolog.turni.com.br` (ou destino decidido em ADR-012). `grep -c 'href="https://app.homolog' index.html` ≥ 14 ocorrências (ou número equivalente).
- [ ] **CA-B3-5:** Nenhum CTA aponta para `app.html#/...` antigo (`grep 'href="app.html'` retorna 0 matches).
- [ ] **CA-B3-6:** Lighthouse mobile na landing AS IS: Performance ≥ 70, Accessibility ≥ 80. Anexar screenshot.
- [ ] **CA-B3-7:** Assets referenciados pelo HTML (img/, turnioficial_files/, manifest, tour.css/js, sw.js se mantido) carregam sem 404 — DevTools Network limpo.

---

## Bloco 4 — robots.txt e não-indexação

- [ ] **CA-B4-1:** `curl -s https://landing.homolog.turni.com.br/robots.txt` retorna conteúdo contendo `Disallow: /<path-secreto>/`.
- [ ] **CA-B4-2:** `curl -sI https://landing.homolog.turni.com.br/robots.txt` retorna `Content-Type: text/plain`.
- [ ] **CA-B4-3:** Nenhum `sitemap.xml` exposto que mencione o path secreto. `curl -s https://landing.homolog.turni.com.br/sitemap.xml` retorna 404 ou sitemap que **não** contém o `<path-secreto>`.
- [ ] **CA-B4-4 (`n/a` se sem acesso ao Search Console):** Google Search Console não indexou o path secreto (verificar via "Coverage" se acesso disponível).

---

## Bloco 5 — Gate (paths aleatórios não vazam landing)

- [ ] **CA-B5-1:** `curl -s -o /dev/null -w "%{http_code}\n" https://landing.homolog.turni.com.br/qwertyuiop/` retorna 404 (ou 302 conforme decisão de ADR-012) — **NÃO** 200 da landing.
- [ ] **CA-B5-2:** Mesmo teste para `/foo/`, `/admin/`, `/api/`, `/dashboard/` — todos retornam 404 ou 302.
- [ ] **CA-B5-3:** `curl -s https://landing.homolog.turni.com.br/qwertyuiop/` **não** contém marcador da landing AS IS (`grep -i "TURNI · MVP Demo"` → 0 matches).
- [ ] **CA-B5-4:** Página 404 servida está na identidade visual da landing (logo, cor) — não é 404 cru do Firebase Hosting. (Apenas se ADR-012 escolheu 404 institucional; se escolheu redirect para apex, verificar 302 e Location.)

---

## Bloco 6 — Não-leak do path secreto

- [ ] **CA-B6-1:** `curl -s https://landing.homolog.turni.com.br/ | grep -i "<valor-real-do-path-secreto>"` retorna 0 matches (Em breve não vaza).
- [ ] **CA-B6-2:** `curl -s https://landing.homolog.turni.com.br/404` (ou path que gera 404) | grep do path secreto → 0 matches.
- [ ] **CA-B6-3:** `apps/landing/README.md` no repo (commitado) contém apenas placeholder literal `<path-secreto>`, não o valor real. `grep -i "<valor-real>" apps/landing/README.md` → 0 matches.
- [ ] **CA-B6-4:** Workflow log do GitHub Actions (último run de deploy homolog) **não** mostra o `<valor-real-do-path-secreto>` em claro (masked via `::add-mask::` se aplicável).

---

## Bloco 7 — Fronteira CODEOWNERS

- [ ] **CA-B7-1:** `CODEOWNERS` da raiz contém regras para `apps/landing/` divididas conforme PDR-015 + ADR-012 (marketing dono do path secreto; engenharia dona da Em breve/infra/workflow).
- [ ] **CA-B7-2:** Simular PR tocando `apps/landing/public/<path-secreto>/index.html` → CODEOWNERS exige aprovação de marketing (verificar via `gh api repos/{owner}/{repo}/codeowners` ou simulação real de PR).
- [ ] **CA-B7-3:** Simular PR tocando `apps/landing/public/index.html` (Em breve) ou `firebase.json` → CODEOWNERS exige aprovação de engenharia.
- [ ] **CA-B7-4:** `apps/landing/README.md` existe e descreve fronteira, referencia PDR-015 e CODEOWNERS.

---

## Bloco 8 — Pipeline tag-based + gate humano em prod

- [ ] **CA-B8-1:** `.github/workflows/landing-deploy.yml` existe; `paths` filtra para `apps/landing/**`, `firebase.json`, `.firebaserc`, próprio workflow.
- [ ] **CA-B8-2:** Workflow autentica via Workload Identity Federation (OIDC) — não há chave de service account em secret.
- [ ] **CA-B8-3:** Tag `landing-v*-rc.*` dispara deploy homolog automaticamente. Verificar último run.
- [ ] **CA-B8-4:** Tag `landing-v*` (sem `-rc`) **NÃO** deploya sem aprovação manual. Verificar configuração do GitHub Environment `landing-prod` — revisor obrigatório presente.
- [ ] **CA-B8-5:** Smoke test pós-deploy presente no workflow (5 checks). Verificar último run mostra smoke test verde.
- [ ] **CA-B8-6:** Smoke test failure dispara rollback automático para release anterior — verificar lógica no workflow (ou exercitar artificialmente quebrando algo).

---

## Bloco 9 — Isolamento de deploy

- [ ] **CA-B9-1:** Disparar deploy da landing (tag rc) → verificar no Firebase Hosting console que apenas `turni-landing-homolog` recebeu nova release. `turni-webapp-homolog` permanece na mesma revisão.
- [ ] **CA-B9-2:** Workflow do WebApp (`.github/workflows/webapp-deploy.yml` ou equivalente) **NÃO** disparou ao deployar landing. Verificar GitHub Actions run history.
- [ ] **CA-B9-3:** `app.homolog.turni.com.br` continua acessível e na revisão anterior durante e após o deploy da landing. `curl -sI app.homolog.turni.com.br` retorna 200 e headers consistentes com a revisão anterior.

---

## Bloco 10 — Rollback exercitado

- [ ] **CA-B10-1:** Comando `firebase hosting:rollback --site turni-landing-homolog` documentado no runbook P2.
- [ ] **CA-B10-2:** Rollback exercitado pelo programador (evidência em "Notas do agente" da STORY-031 ou STORY-032). Output anexado.
- [ ] **CA-B10-3:** Após rollback, `curl` retorna conteúdo da release anterior — verificável por diff de hash ou marcador único.

---

## Bloco 11 — Terraform multi-ambiente

- [ ] **CA-B11-1:** `terraform plan` em `infra/envs/prod/` mostra 0 changes referentes à landing (`landing_prod_enabled = false` funcionando como gate). Anexar saída.
- [ ] **CA-B11-2:** Sites `turni-landing-prod` codificado em Terraform mas não criado no GCP. Verificar via Cloud Console.
- [ ] **CA-B11-3:** Mecanismo de go-public é flip de variável + apply + tag conforme runbook P6 — verificável por inspeção do Terraform + runbook.

---

## Bloco 12 — Headers de segurança

- [ ] **CA-B12-1:** `curl -sI https://landing.homolog.turni.com.br/` mostra:
  - `Strict-Transport-Security: max-age=31536000; includeSubDomains` (ou equivalente decidido em ADR-012).
  - `X-Content-Type-Options: nosniff`.
  - `X-Frame-Options: DENY` (ou `SAMEORIGIN` se justificado).
  - `Referrer-Policy: strict-origin-when-cross-origin` (ou equivalente).
  - `Content-Security-Policy` presente (permitindo Google Fonts e assets locais).
- [ ] **CA-B12-2:** Headers presentes também em `/<path-secreto>/` (verificar via `curl -sI`).
- [ ] **CA-B12-3:** `index.html` (Em breve e landing) tem `Cache-Control: no-cache, no-store, must-revalidate` para garantir propagação rápida.
- [ ] **CA-B12-4:** Assets imutáveis (JS/CSS/imagens) têm `Cache-Control: public, max-age=31536000, immutable`.

---

## Bloco 13 — Redirect www → apex

- [ ] **CA-B13-1 (`n/a` se prod não está no ar):** `curl -sI https://www.turni.com.br/` retorna `301 Moved Permanently` com `Location: https://turni.com.br/` (ou equivalente decidido em ADR-012). **Justificar `n/a`** se prod não está no ar: "domínio www será coberto quando go-public for executado conforme runbook P6".
- [ ] **CA-B13-2:** Verificação equivalente em homolog se aplicável (ex.: `www.landing.homolog.turni.com.br`) — depende de ADR-012 ter contemplado.

---

## Bloco 14 — Runbook

- [ ] **CA-B14-1:** `docs/operacao/runbook-landing.md` existe, formato consistente com `runbook-homolog.md`.
- [ ] **CA-B14-2:** Cobre os 7 procedimentos: P1 publicar, P2 rollback, P3 rotacionar path, P4 trocar domínio, P5 remover sw.js, P6 go-public, P7 verificações periódicas.
- [ ] **CA-B14-3:** Cada procedimento tem: pré-condições, passos numerados, comandos exatos copia-cola, verificações pós-execução, quem pode executar, SLA quando aplicável.
- [ ] **CA-B14-4:** Runbook não vaza `<valor-real-do-path-secreto>`. `grep "<valor-real>"` no arquivo commitado → 0 matches.
- [ ] **CA-B14-5:** Pelo menos um procedimento exercitado pelo programador (evidência em "Notas" da STORY-032). P2 rollback é o esperado.

---

## Bloco 15 — `index.json` consistente

- [ ] **CA-B15-1:** EPIC-006 em `index.json` com `story_ids: [STORY-026, STORY-027, STORY-028, STORY-029, STORY-030, STORY-031, STORY-032, STORY-033]`.
- [ ] **CA-B15-2:** Cada STORY-026 a STORY-032 com `status: done`. STORY-033 com `status: in_progress` durante esta validação; `done` ao final.
- [ ] **CA-B15-3:** `validation_checklist_path` apontando para este arquivo.
- [ ] **CA-B15-4:** Ao final, `validation_report` apontando para `validation/report.md` com `verdict` e `validated_at` preenchidos.

---

## Veredito final

Após percorrer todos os blocos, validador escreve em `validation/report.md`:

- **Total de itens**: __
- **`pass`**: __
- **`pass com ressalva`**: __
- **`fail bloqueante`**: __
- **`fail não-bloqueante`**: __
- **`n/a`** (justificados): __

**Veredito**:
- `approved` se 0 fails (bloqueantes ou não-bloqueantes).
- `approved_with_pending` se 0 fails bloqueantes e ≥ 1 não-bloqueante.
- `rejected` se ≥ 1 fail bloqueante.

Anexar:
- Lista de fails (bloqueantes e não-bloqueantes) com evidência.
- Justificativa de cada `n/a`.
- Recomendações **NÃO** entram no relatório (papel do PO).
