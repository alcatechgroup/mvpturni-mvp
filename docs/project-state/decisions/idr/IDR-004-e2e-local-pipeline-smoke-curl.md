---
id: IDR-004
title: E2E em browser real é gate LOCAL antes da tag; pipeline pós-deploy faz apenas smoke curl
status: accepted
decided_at: 2026-05-28
decided_by: programador
source_story: EPIC-000 carry-over (rever política instaurada na STORY-011 / IDR-003)
supersedes: nada
superseded_by: nada
---

# IDR-004 — E2E local + smoke curl no pipeline

## Contexto

A política original da STORY-011 (validação do EPIC-000) interpretou "E2E em browser real
deve rodar contra a homologação" como obrigação de **rodar Playwright dentro do pipeline
de release** (`release.yml` job `e2e-homolog`). Isso levou a:

- Job de E2E que faz `npx playwright install chromium --with-deps` em **dois apps**
  (webapp + admin) a cada tag `-rc.N` — duas instalações de Chromium + dois `npm ci`.
- Tempo crescente do pipeline conforme a cobertura de UI cresce. Na rc.12 já consumia
  parcela relevante dos ~4 min de cada release; com EPIC-001/002 entrando, a projeção
  é **dezenas de minutos a horas** de pipeline por release.
- Decisão em cascata (IDR-003) que **abriu o admin homolog** (`INGRESS_TRAFFIC_ALL` +
  `allUsers → run.invoker`) só para o runner do GitHub conseguir alcançar o serviço.
- Contradição direta com `docs/skills/po/references/quality-standards.md` §2.2, que
  **sempre disse**: *"todo push para branch de feature dispara CI leve... **Não** sobe
  banco nem browser/emulador no runner — testes pesados já foram cobrados localmente
  pelo hook."* O E2E no pipeline foi um desvio do padrão escrito.

Pipeline de release inviável de manter em escala é problema operacional crítico: deploy
demorado erode confiança, gera fila e empurra time pra contornar (pular tag, deploy
manual, hot-fix sem release).

## Decisão

**E2E em browser real é gate LOCAL OBRIGATÓRIO** antes de criar tag `vX.Y.Z-rc.N`.

1. **Pre-push hook** (`scripts/hooks/pre-push`) roda lint + unit + integração — **não**
   roda Playwright (Chromium pesado demais para todo push de feature).
2. **`make e2e`** é o gate **manual** disciplinar: roda `docker-compose` local + Playwright
   contra `localhost:8002` (admin) e `localhost:8003` (webapp). Quem cria a tag rc.N tem
   responsabilidade de rodar `make e2e` e ver verde antes do `git push origin v...-rc.N`.
3. **Pipeline `release.yml` faz apenas smoke curl** pós-deploy: `/health` (3 interfaces)
   + `/version.json` (valida que a versão servida bate com a tag deployada). Job
   `smoke-homolog` substitui o antigo `e2e-homolog`. Custa segundos, não minutos.
4. Defaults dos `apps/{webapp,admin}/playwright.config.ts` mudam para `localhost:*`
   (sinalizando explicitamente o uso pretendido — homolog continua acessível via
   `BASE_URL=...` para debug manual).

## Justificativa

- **Alinha com padrão escrito** (`quality-standards.md` §2.2) que sempre tratou E2E
  pesado como responsabilidade de pre-push local, não de CI.
- **Preserva a métrica primária do EPIC-000** ("merge em main dispara deploy para
  ambas as homologações em ≤ 10 min com health-check verde"): o smoke curl é
  health-check + check de versão; deploy verde continua sendo a regra.
- **Custo de risco aceitável para MVP**: o que o E2E pega que o smoke curl não pega
  é regressão visual (CSS, label faltando, foco quebrado). Em MVP de 1 desenvolvedor,
  isso é detectável manualmente em smoke visual. O custo de horas de pipeline é
  estrutural; o custo de regressão visual passando para homolog é circunstancial.
- **Reabre flexibilidade**: quando IAP entrar (EPIC-001), pode revogar IDR-003 e
  fechar o admin homolog para tráfego público novamente — sem precisar de exceção
  para runner externo.

## Consequências

### Imediatas (esta PR)

- `release.yml`: job `e2e-homolog` removido; substituído por `smoke-homolog` (curl
  /health + /version.json nas 3 interfaces).
- `apps/{webapp,admin}/playwright.config.ts`: `baseURL` default → `localhost:{8003,8002}`.
- `Makefile`: novo target `make e2e` (com sub-targets `e2e-webapp` e `e2e-admin`).
- `scripts/hooks/pre-push`: cabeçalho atualizado documentando que E2E roda via
  `make e2e` antes da tag (não no hook).
- `docs/operacao/runbook-homolog.md`: nova seção "Antes de criar tag rc.N"
  cobrando `make e2e` verde como checklist explícito.
- `docs/project-state/epics/EPIC-000-foundation/epic.md`: critério "CI roda... ao
  menos um E2E smoke" reformulado para "CI roda smoke curl pós-deploy + E2E local
  antes da tag".

### Em IDR-003 (admin homolog com ingress=all)

IDR-003 perde a justificativa que o criou (runner externo do CI batendo no admin).
**Não é revogado nesta PR** para evitar bloquear smoke manual do PO em homolog
enquanto IAP não entra. Anotado como **"a revogar quando IAP for configurado em
EPIC-001"** — quando o admin homolog ganhar autenticação real, o ingress volta a
ser `INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER` + `allow_unauthenticated = false` e
o IDR-003 vira `superseded_by: IDR-XXX-iap-admin-homolog`.

### Riscos aceitos

- **Regressão visual de UI escapa para homolog se o dev pular `make e2e`** antes
  da tag. Mitigação: disciplina (`runbook-homolog.md` checklist) + smoke curl no
  pipeline pega 5xx/404 (não pega CSS quebrado, mas pega quebra funcional severa).
- **PO perde "rede de proteção automática" no pipeline**: smoke manual no app
  homolog continua sendo prática recomendada antes do deploy de produção (que tem
  gate humano de 1 clique de qualquer forma).

### Histórico (não regrida)

A validação do EPIC-000 (`validation/report.md`) registrou "E2E ✅ em rc.10/11/12" via
job `e2e-homolog`. Esse registro permanece como evidência histórica do estado
naquela data — refletindo a política vigente até 2026-05-28. **Não reescrever
relatório de validação**: a mudança de política a partir deste IDR é prospectiva.

## Notas de implementação

- O Cloud Monitoring uptime check (provisionado em Terraform, ciclo de 60s)
  continua sendo a malha de segurança contínua independente do pipeline.
- O smoke curl valida `version` exato igual à tag — pega cache stale, deploy
  parcial e roteamento errado em milissegundos.
- Quem quiser executar Playwright contra homolog manualmente (debug pós-deploy)
  continua podendo: `BASE_URL=https://app.homolog.turni.com.br npx playwright test`
  no `apps/webapp`, idem para admin com URL do Cloud Run.
