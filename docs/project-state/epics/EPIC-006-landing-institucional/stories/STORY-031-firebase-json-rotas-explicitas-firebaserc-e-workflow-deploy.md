---
story_id: STORY-031
slug: firebase-json-rotas-explicitas-firebaserc-e-workflow-deploy
title: firebase.json com rotas explícitas (gate) + .firebaserc + workflow GitHub Actions tag-based
epic_id: EPIC-006
sprint_id: SPRINT-2026-W24-LANDING
type: implementation
target_role: programador
requires_design: false
status: ready
owner_agent: null
created_at: 2026-05-28
updated_at: 2026-05-28
estimated_session_size: M
---

# STORY-031 — firebase.json (gate) + .firebaserc + workflow GitHub Actions

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Ela contém tudo o que você precisa. Se algo estiver ambíguo, registre a dúvida na seção "Notas do agente" no final e pause em vez de adivinhar.

## Contexto (por que esta estória existe)

Esta é a estória em que o **gate "Em breve" + path secreto vai ao ar pela primeira vez**. STORY-026 decidiu a mecânica em ADR-012; STORY-029 criou os sites Firebase e os registros DNS; STORY-030 colocou os arquivos certos nas pastas certas. Falta o `firebase.json` com as rotas explícitas que efetivam o gate (sem rewrite genérico — qualquer path desconhecido cairia na landing), o `.firebaserc` apontando para os targets corretos, e o workflow GitHub Actions que deploya em homolog por tag `landing-vX.Y.Z-rc.N` e em prod por tag `landing-vX.Y.Z` com gate humano (herdando ADR-004).

A estória atravessa: `firebase.json` (mecânica de routing + headers de cache + headers de segurança), `.firebaserc` (mapeamento target → site), `.github/workflows/landing-deploy.yml` (CI/CD), e configuração de **GitHub Environments** (`landing-prod` com revisor obrigatório para o gate humano).

A estória é **M** (não L) porque a mecânica é simples — Firebase Hosting + GitHub Actions são bem conhecidos do EPIC-000 (STORY-007). O risco vive em duas pontas: (1) **routing do gate** — uma regra mal escrita transforma qualquer 404 em landing, vazando o conteúdo que deveria estar atrás do path secreto; (2) **tag-based + gate humano em prod** — workflow tem que herdar exatamente o padrão da ADR-004 sem improvisar atalhos. Mitigado por CAs observáveis e por um "smoke test" pós-deploy automatizado no workflow.

- Épico: `docs/project-state/epics/EPIC-006-landing-institucional/epic.md`
- Documentos canônicos a ler ANTES de codificar:
  - `epic.md` do EPIC-006 (seção "Entregável visível" — descreve o que `firebase.json` precisa fazer)
  - `docs/project-state/decisions/adr/ADR-012-landing-gate-em-breve-path-secreto.md` (mecânica decidida — rotas explícitas, política de cache, política de 404)
  - `docs/project-state/decisions/adr/ADR-004-hospedagem-iac-deploy.md` (padrão tag-based + gate humano em prod via GitHub Environments)
  - `firebase.json` atual (raiz do monorepo — padrão do WebApp para herdar estrutura)
  - `.firebaserc` atual (targets `homolog` e `prod` para WebApp — estender)
  - `.github/workflows/` (workflows existentes do EPIC-000 — padrão de path filter, OIDC/WIF, gate humano)
  - `apps/landing/` (estrutura criada por STORY-030 — onde o workflow vai apontar)
  - `docs/skills/programador/SKILL.md`

## O quê (objetivo desta estória)

Entregar o gate efetivo em homolog (e codificado para prod, gated por variável):

1. **`firebase.json` estendido com configuração do site da landing** (no array `hosting`, conforme padrão atual do monorepo que já tem `homolog` e `prod` para o WebApp). Para o site da landing, configurar:
   - `target`: `landing-homolog` (e `landing-prod` codificado).
   - `public`: `apps/landing/public`.
   - `ignore`: padrão (firebase.json, .*, node_modules).
   - **Sem** `rewrites: [{"source": "**", "destination": "/index.html"}]` — esta linha é a fonte de leak; substituir por rotas explícitas:
     - `redirects`: `www.turni.com.br` → `https://turni.com.br/` 301 (se ADR-012 escolheu essa mecânica; caso contrário omitir).
     - `headers` para `/index.html` (Em breve): `Cache-Control: no-cache, no-store, must-revalidate` (push aparece em ≤ 5 min).
     - `headers` para `/<path-secreto>/index.html` (landing): `Cache-Control: no-cache, no-store, must-revalidate`.
     - `headers` para `**/*.@(js|css|wasm|png|jpg|svg|woff2)`: `Cache-Control: public, max-age=31536000, immutable` (assets imutáveis).
     - `headers` para `/robots.txt`: `Cache-Control: no-cache, no-store, must-revalidate` + `Content-Type: text/plain`.
     - Headers de segurança em todas as respostas: `Strict-Transport-Security: max-age=31536000; includeSubDomains`, `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: strict-origin-when-cross-origin`, `Content-Security-Policy` mínima (decisão sua justificada — base deve permitir Google Fonts pois landing AS IS usa).
   - **`appAssociation: NONE`** (Firebase Hosting deixa de tentar adivinhar deep links — não temos app iOS/Android no escopo).
   - **`cleanUrls: false`** e **`trailingSlash: false`** (ou os defaults que ADR-012 decidir; documentar).
2. **`.firebaserc` estendido** com `landing-homolog` (mapeando para `turni-landing-homolog`) e `landing-prod` (mapeando para `turni-landing-prod`):
   ```json
   "targets": {
     "turni-mvp": {
       "hosting": {
         "homolog":         ["turni-webapp-homolog"],
         "prod":            ["turni-webapp-prod"],
         "landing-homolog": ["turni-landing-homolog"],
         "landing-prod":    ["turni-landing-prod"]
       }
     }
   }
   ```
3. **Workflow `.github/workflows/landing-deploy.yml`** com:
   - **Trigger por path filter:** `paths: ['apps/landing/**', 'firebase.json', '.firebaserc', '.github/workflows/landing-deploy.yml']` em `push` para branch `main`.
   - **Trigger por tag:** tags `landing-v*-rc*` → deploy homolog; tags `landing-v*` (sem `-rc`) → deploy prod com gate humano.
   - **Job de CI** (em qualquer push): lint mínimo do HTML (htmlhint ou validador W3C; warnings só nas partes AS IS, documentado), `firebase hosting:channel:deploy` num canal preview do Firebase Hosting (homolog tem canais de preview gratuitos) para revisão visual do PR.
   - **Job de deploy homolog** (em tag `landing-v*-rc*`): autenticação via Workload Identity Federation (OIDC GitHub↔GCP — herda ADR-004), `firebase deploy --only hosting:landing-homolog`.
   - **Job de deploy prod** (em tag `landing-v*` sem `-rc`): **gate humano de 1 clique** via GitHub Environment `landing-prod` (revisor obrigatório). Após aprovação, `firebase deploy --only hosting:landing-prod`. Variável de gate `landing_prod_enabled` da STORY-029 deve estar `true` (caso contrário Terraform não tem o site criado e o deploy falha — comportamento esperado).
   - **Smoke test pós-deploy**: para o site de homolog após cada deploy: `curl -s -o /dev/null -w "%{http_code}" https://landing.homolog.turni.com.br/` retorna `200`; `curl -s https://landing.homolog.turni.com.br/ | grep -q "Em breve"` (ou marcador único da Em breve definido em STORY-028); `curl -s -o /dev/null -w "%{http_code}" https://landing.homolog.turni.com.br/<path-secreto>/` retorna `200`; `curl -s https://landing.homolog.turni.com.br/<path-secreto>/ | grep -q "TURNI · MVP Demo"` (marcador único da landing); `curl -s https://landing.homolog.turni.com.br/robots.txt | grep -q "Disallow: /<path-secreto>/"`. Falha em qualquer smoke test = falha do workflow = rollback automático para release anterior via `firebase hosting:rollback`.
   - **Isolamento**: workflow **não toca** os jobs do WebApp/API/Admin. Outros workflows existentes (do EPIC-000) **não toca** o site da landing (verificar; ajustar `paths` se necessário).
4. **GitHub Environment `landing-prod`** criado com revisor obrigatório (Alexandro como default; lead de engenharia como fallback). Sem `landing-homolog` Environment (deploy automático).
5. **Secret/variável de ambiente do `<path-secreto>`** no GitHub Actions (se ADR-012 decidiu por path injetado em build-time, não commitado). Nome sugerido: `LANDING_SECRET_PATH`. Used apenas no workflow; nunca em logs (`echo "::add-mask::$LANDING_SECRET_PATH"` ou equivalente).
6. **Headers de segurança em produção testados**: `curl -sI` em homolog mostra `Strict-Transport-Security`, `X-Content-Type-Options`, etc. presentes.

## Por quê (valor para o usuário)

Direto: `https://landing.homolog.turni.com.br/` responde "Em breve"; `https://landing.homolog.turni.com.br/<path-secreto>/` responde a landing completa; marketing pode fazer PR no conteúdo e ver no ar via tag de release em minutos; comercial pode pedir rotação do path via PR alterando o secret no GitHub Actions. Cutover de prod fica a 1 clique humano + 1 PR no Terraform (flip `landing_prod_enabled = true`).

Indireto: estabelece o padrão de "site estático em Firebase Hosting com pipeline tag-based isolado" que pode ser replicado para blog/docs públicas/status page futuras.

## Critérios de aceite

- [ ] **CA-1:** `firebase.json` da raiz inclui configuração para `target: landing-homolog` e `target: landing-prod`, **sem rewrite genérico**, com rotas explícitas conforme §1 do "O quê". Espelhar estrutura JSON do `homolog`/`prod` do WebApp existente.
- [ ] **CA-2:** `.firebaserc` estendido conforme §2; comando `firebase target` (local com auth) lista os 4 targets.
- [ ] **CA-3:** `.github/workflows/landing-deploy.yml` existe e:
  - Tem `paths` filtrados (CA-3.1).
  - Job CI executa em qualquer push tocando o path filter.
  - Job deploy homolog dispara em tag `landing-v*-rc*` (CA-3.2).
  - Job deploy prod dispara em tag `landing-v*` (sem `-rc`) e exige aprovação via GitHub Environment `landing-prod` (CA-3.3).
  - Autenticação via WIF (não chave de service account).
- [ ] **CA-4:** Smoke test pós-deploy no workflow cobre os 5 checks listados em §3 ("Smoke test"); falha qualquer um → rollback automático + workflow vermelho.
- [ ] **CA-5:** GitHub Environment `landing-prod` criado, com revisor obrigatório (Alexandro).
- [ ] **CA-6:** Se ADR-012 escolheu path injetado em build-time, secret `LANDING_SECRET_PATH` configurado no repo; workflow consome com mask; valor não aparece em log de nenhum step (verificar logs do CI).
- [ ] **CA-7:** **Deploy em homolog executado e verde**: `https://landing.homolog.turni.com.br/` responde 200 com "Em breve" (ou marcador único decidido em STORY-028); `https://landing.homolog.turni.com.br/<path-secreto>/` responde 200 com landing AS IS (verificável por `<title>` ou marcador). `curl` outputs anexados ao PR.
- [ ] **CA-8:** **Redirect www→apex**: `curl -sI https://www.turni.com.br/` (após domínio configurado em prod; em homolog testar equivalente se ADR-012 contemplou `www.landing.homolog` ou similar — possivelmente fora do teste se DNS não cobre) retorna `301` para apex. Se prod não estiver no ar, registrar como verificação adiada e linkar ao runbook de go-public.
- [ ] **CA-9:** `https://landing.homolog.turni.com.br/robots.txt` retorna `Disallow: /<path-secreto>/`.
- [ ] **CA-10:** **Isolamento testado**: tag `landing-v0.1.0-rc.1` deployada → site da landing atualiza; site do WebApp em `app.homolog.turni.com.br` **não muda** (mesma revisão/release que estava antes); workflow do WebApp não dispara.
- [ ] **CA-11:** **Rollback exercitado em homolog**: `firebase hosting:rollback --site turni-landing-homolog` executado, site volta à release anterior; verificado por `curl` mostrando o conteúdo anterior. Comando documentado para o runbook (STORY-032).
- [ ] **CA-12:** **Headers de segurança presentes**: `curl -sI https://landing.homolog.turni.com.br/` mostra `Strict-Transport-Security`, `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY` (ou equivalente decidido).
- [ ] **CA-13:** **Verificação 404**: `curl -s -o /dev/null -w "%{http_code}" https://landing.homolog.turni.com.br/qualquer-path-aleatorio-zxzxzx/` retorna o código decidido em ADR-012 (404 com página institucional ou 302 para apex). Não retorna o conteúdo da landing.
- [ ] **CA-14:** PR aprovado pelo PO antes do merge; tag `landing-v0.1.0-rc.1` criada após merge para deploy efetivo em homolog.

## Fora de escopo

- Conteúdo da landing — STORY-030.
- Página "Em breve" — STORY-028.
- Sites Firebase / DNS — STORY-029.
- Runbook — STORY-032.
- Deploy em prod (go-public) — fora do EPIC-006; código está pronto, comercial autoriza, runbook documenta.
- Basic-auth ou IP allowlist — fora do EPIC-006.
- Monitoramento/alertas específicos da landing (uptime, latência) — fora; o monitoring básico do ADR-008 cobre via Cloud Monitoring uptime check (sugerir adicionar como story futura, mas fora desta).

## Padrões de qualidade exigidos

Esta estória segue `docs/skills/po/references/quality-standards.md`:

- **Promoção tag-based + gate humano em prod (§2.2):** não-negociável. Workflow espelha o padrão ADR-004 com namespace `landing-`.
- **Sem chave de service account no repo (§4):** OIDC/WIF apenas. Mesmo padrão dos workflows do EPIC-000.
- **Rollback scriptado (CA-5 do ADR-004):** `firebase hosting:rollback` documentado e exercitado.
- **Observabilidade:** workflow emite log estruturado em cada step; smoke test failure dispara rollback + workflow vermelho (notificação para o canal acordado).
- **Segurança:** headers de segurança não-negociáveis (HSTS, CSP, X-Frame-Options); CSP permite Google Fonts pois landing AS IS usa.
- **Testes E2E mínimos:** smoke test pós-deploy é o equivalente de E2E para esta estória (não há browser test necessário — é HTML estático).

## Dependências

- **Bloqueada por:** STORY-026 (ADR-012 decide mecânica), STORY-029 (sites Firebase + DNS), STORY-030 (conteúdo em `apps/landing/public/`).
- **Bloqueia:** STORY-032 (runbook documenta o workflow), STORY-033 (validador testa o resultado).

## Decisões já tomadas (não as reabra)

- **ADR-004** — pipeline tag-based + gate humano em prod via GitHub Environments + WIF.
- **ADR-012** — mecânica do gate, política de cache, política de 404, mecânica do path secreto.
- **epic.md do EPIC-006** — namespace `landing-vX.Y.Z`; gate humano em prod; deploy isolado.
- **PDR-015** — fronteira de quem pode trigger release (marketing pode mergear/taggear conforme acordo).

## Liberdade técnica do agente

Você (programador) decide:
- Implementação concreta do smoke test (bash inline no workflow vs. script em `scripts/landing-smoke-test.sh`).
- Estrutura de jobs do workflow (1 job ou N jobs encadeados).
- Versão exata do CLI do Firebase + Node (espelhar workflows existentes para consistência).
- Conteúdo concreto da CSP (base mínima para permitir Google Fonts + assets locais).
- Nome do GitHub Environment (`landing-prod` é padrão; pode mudar se houver razão).

Você (programador) NÃO decide:
- Reabrir ADR-012 ou ADR-004.
- Eliminar gate humano em prod.
- Usar chave de service account em vez de WIF.
- Suprimir smoke test pós-deploy.
- Suprimir rollback automático em smoke test failure.
- Decidir valor do `<path-secreto>` (comercial define; workflow apenas consome o secret).

## Definição de Pronto (DoD)

- [ ] Todos os CAs (CA-1 a CA-14) passam.
- [ ] Workflow rodou verde pelo menos uma vez em homolog após merge.
- [ ] Smoke test verde anexado em "Notas" (log do workflow).
- [ ] Rollback exercitado em homolog (CA-11), comando + output anexado.
- [ ] Curl headers anexado (CA-12).
- [ ] `index.json` atualizado: `in_review` ao abrir PR; `done` após merge + smoke test verde.
- [ ] "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

Siga `docs/skills/programador/SKILL.md`. Resumo:

1. Frontmatter desta estória: `status: in_progress`, `owner_agent`, `updated_at`. Atualize `index.json`.
2. Confirme dependências (026/029/030) `done`.
3. Implemente `firebase.json` + `.firebaserc` + workflow + GitHub Environment + secret (se aplicável).
4. Abra PR; revisão do PO; ajustes.
5. Após merge, crie tag `landing-v0.1.0-rc.1` para disparar deploy homolog.
6. Verifique smoke tests; exercite rollback; anexe evidências.
7. Atualize `index.json`. Marque `status: done`.

## Notas do agente (preenchido durante/após execução)

### Entrada inicial
(a preencher)

### Decisões tomadas
(a preencher — ex: estrutura de jobs, conteúdo da CSP, nome do Environment)

### Descobertas
(a preencher)

### Bloqueios encontrados
(a preencher)

### Resultado final / evidência
- Workflow run ID (homolog deploy): (link)
- Smoke test log: (texto)
- `curl -sI https://landing.homolog.turni.com.br/`: (output)
- `curl -sI https://landing.homolog.turni.com.br/<path-secreto>/`: (output)
- `curl -s https://landing.homolog.turni.com.br/robots.txt`: (output)
- Rollback exercitado: (comando + output)
- Isolamento verificado (CA-10): (timestamp do site WebApp inalterado)

### Pendências para fechar
(a preencher)

### Links de evidência
(a preencher — commits, PR, workflow runs, GitHub Environment)
