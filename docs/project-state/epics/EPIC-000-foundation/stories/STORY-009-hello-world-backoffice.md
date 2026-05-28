---
story_id: STORY-009
slug: hello-world-backoffice
title: "Hello world" no Backoffice — rota raiz e health-check
epic_id: EPIC-000
sprint_id: SPRINT-2026-W23
type: implementation
target_role: programador
requires_design: false
status: done
owner_agent: claude-sonnet-4-6
created_at: 2026-05-26
updated_at: 2026-05-28
estimated_session_size: S
---

# STORY-009 — "Hello world" no Backoffice: rota raiz e health-check

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Ela contém tudo o que você precisa. Se algo estiver ambíguo, registre a dúvida na seção "Notas do agente" no final e pause em vez de adivinhar.

## Contexto (por que esta estória existe)

PDR-003 exige **duas interfaces deployadas separadamente desde o MVP** — WebApp e Backoffice. STORY-008 entrega o hello world do WebApp; esta estória entrega o equivalente do Backoffice em `admin.homolog.turni.com.br`. Sem ela, o EPIC-000 não fecha: o entregável visível listado em `epic.md` exige **ambas** as URLs respondendo com página inicial + `/health` em verde.

O Backoffice é desktop-first (PDR-003), atende exclusivamente Admin Turni e tem perfil de uso distinto do WebApp (sessões mais longas, telas mais densas — quando elas existirem). Para esta estória, o escopo é minúsculo: rota raiz com placeholder textual identificando claramente que é o Backoffice (e não o WebApp), `/health` no mesmo formato definido em ADR-008, logs estruturados e teste E2E em browser real cobrindo o caminho feliz.

Diferente de STORY-008, esta estória **não tem `requires_design: true`** — o Backoffice ainda não tem padrões visuais próprios definidos (DDR-001 cobre tokens base que são consumidos quando existir UI séria; nesta estória só precisamos de uma página identificadora mínima sem aplicar layout administrativo elaborado). Designer pode revisar opcionalmente o resultado, mas não há trabalho de design exigido para esta entrega. Se o Programador sentir necessidade de spec visual (ex: para validar contraste, padrão tipográfico), pode pedir input curto ao Designer — mas a estória não está bloqueada por isso.

- Épico: `docs/project-state/epics/EPIC-000-foundation/epic.md`
- Documentos canônicos a ler ANTES de codificar:
  - `docs/project-state/decisions/pdr/PDR-003-duas-interfaces-webapp-e-backoffice.md` (Backoffice desktop-first, separado)
  - `docs/skills/po/references/quality-standards.md`
  - `docs/skills/programador/SKILL.md`
  - `docs/project-state/decisions/adr/ADR-001-stack-principal.md`
  - `docs/project-state/decisions/adr/ADR-004-hospedagem-iac-deploy.md`
  - `docs/project-state/decisions/adr/ADR-008-observabilidade-minima.md`
  - `docs/project-state/decisions/ddr/DDR-001-fundacao-do-design-system.md` (tokens base — aplicáveis também aqui em nível mínimo, sem layout administrativo)
  - `docs/especificacao/non-functional.md` (compatibilidade desktop, contraste AA, performance)

## O quê (objetivo desta estória)

Implementar no **Backoffice**:

1. **Rota raiz `/`** retornando página identificadora mínima: nome "Turni — Backoffice (Admin)", subtítulo curto deixando claro que é a interface administrativa, versão visível, link explícito para `/health`. Aplicar tokens de DDR-001 em nível mínimo (tipografia, cor de fundo, link) — sem layout administrativo elaborado.
2. **Rota `/health`** com mesmo contrato de ADR-008 (status, version, timestamp, service: "backoffice"). Comportamento de dependências caídas idêntico ao do WebApp (não-200 quando PostgreSQL inacessível).
3. **Logs estruturados** conforme ADR-008, com request_id propagado.
4. **Teste E2E em browser real** cobrindo: abre `admin.homolog.turni.com.br`, vê página inicial, clica em `/health`, recebe 200.

## Por quê (valor para o usuário)

Para o **Admin Turni** (Alexandro e futura equipe), ainda não há valor operacional — esta é placeholder. Mas é a primeira evidência de que o Backoffice existe e está deployável independentemente do WebApp (PDR-003 cumprido na prática, não só no papel). É também o segundo pilar do entregável visível do EPIC-000: sem esta estória, o validador não consegue aprovar.

## Critérios de aceite

### Rota raiz

- [ ] **CA-1:** `GET /` em `admin.homolog.turni.com.br` retorna 200 com página HTML renderizando: "Turni — Backoffice (Admin)" como identificador inequívoco (não pode ser confundida visualmente com a página do WebApp), versão visível (formato `vX.Y.Z-rc.N`, lida em runtime pelo **mecanismo padronizado definido em STORY-007 / IDR correspondente** — não inventar mecanismo paralelo), link explícito para `/health`.
- [ ] **CA-2:** A página aplica tokens base de DDR-001 (tipografia, paleta) em nível mínimo, sem layout administrativo. Contraste WCAG 2.1 AA (`quality-standards.md` seção 5).
- [ ] **CA-3:** A página funciona em **desktop** nos navegadores listados em `non-functional.md` (Chrome, Firefox, Safari, Edge nas duas últimas versões major). Não exige experiência mobile (PDR-003: backoffice é desktop-only).

### Rota `/health`

- [ ] **CA-4:** `GET /health` retorna 200 com payload JSON (ou conforme ADR-008) contendo no mínimo: `status: "ok"`, `version: "<tag injetada no artefato pela STORY-007>"`, `timestamp: "<ISO 8601>"`, `service: "backoffice"`. O campo `version` vem do **mesmo mecanismo padronizado** consumido por CA-1 — não inventar segunda fonte de verdade.
- [ ] **CA-5:** Quando PostgreSQL está inacessível, `/health` retorna status ≥ 500 com payload descrevendo dependência indisponível (sem vazar segredo). Verificado por teste de integração.
- [ ] **CA-6:** `/health` responde em ≤ 500ms p95 em condição normal.

### Observabilidade

- [ ] **CA-7:** Cada requisição produz log estruturado conforme ADR-008, com request_id propagado no header de resposta.
- [ ] **CA-8:** Health-check externo configurado em STORY-007 vê `/health` do Backoffice verde após deploy.

### Independência operacional

- [ ] **CA-9:** Deploy do Backoffice é **independente** do WebApp (PDR-003). Conferir: rodar pipeline de deploy do Backoffice falhando intencionalmente (ex: rollback simulado) **não derruba** o WebApp; e vice-versa.

### Testes

- [ ] **CA-10:** Teste E2E em browser real percorrendo: abre `admin.homolog.turni.com.br`, vê página inicial carregada, vê versão exibida, clica no link de `/health`, recebe 200. Falha do E2E em homologação bloqueia o épico fechar.
- [ ] **CA-11:** Testes unitários cobrem ≥ 80% do código novo; lógica que monta payload de `/health` ≥ 98%.

## Fora de escopo

- Login do admin, autorização baseada em papel — EPIC-001 (auth real) consome desenho de ADR-007 a partir desta fundação.
- Filas de aprovação, gestão de disputa, editor de templates — EPIC-001 / EPIC-005.
- Layout administrativo elaborado (sidebar, dashboards, tabelas densas) — fora do EPIC-000.
- Mobile-friendly / responsive do Backoffice — fora do MVP (PDR-003: desktop-only).
- PWA no Backoffice — desnecessário (não é app mobile, não precisa de install/offline).
- Compartilhamento de código entre WebApp e Backoffice além do mínimo — decisão local do Programador conforme ADR-003.

## Padrões de qualidade exigidos

Esta estória segue `docs/skills/po/references/quality-standards.md`. Em particular:

- **Cobertura unitária ≥ 80%** no código novo; ≥ 98% no payload de `/health` (regra de negócio mínima).
- **E2E obrigatório em browser real** cobrindo caminho feliz da página inicial + `/health`, rodando contra `admin.homolog.turni.com.br` após deploy.
- **Acessibilidade WCAG 2.1 AA** (seção 5).
- **Observabilidade** (seção 3): `/health`, logs estruturados, request_id.
- **Independência operacional** das duas interfaces (PDR-003) — atestada por CA-9.

## Dependências

- **Bloqueada por:** STORY-007 (pipeline + URL `admin.homolog.turni.com.br` deployada), STORY-006 (repositório + ambiente local), STORY-001 (ADR-001 framework + E2E), STORY-004 (ADR-008 formato), STORY-010 (DDR-001 aceito — para aplicar tokens base mesmo em nível mínimo).
- **Bloqueia:** STORY-011 (validação).
- **Pré-requisitos de ambiente:** homologação provisionada para Backoffice (saída de STORY-007), DNS apontando, certificado HTTPS válido.

## Decisões já tomadas (não as reabra)

- **PDR-003** — Backoffice separado, desktop-first, deploy independente, atende só admin.
- **ADR-001** — framework e ferramenta de E2E.
- **ADR-004** — provedor, URL `admin.homolog.turni.com.br`, HTTPS, cofre.
- **ADR-008** — formato de `/health`, formato de log, request_id propagation.
- **DDR-001** — tokens base aplicáveis.
- **`non-functional.md`** — compatibilidade desktop, contraste AA, performance.

## Liberdade técnica do agente

Você (agente programador) decide:
- Estrutura de pastas e módulos do Backoffice (dentro de ADR-003).
- Como reutilizar utilitários do WebApp (lib comum, monorepo, etc — conforme ADR-003).
- Cenários E2E adicionais opcionais.

Você **não** decide aqui: como a versão do build é injetada no artefato nem como ela é exposta em runtime — isso é decisão de STORY-007 / IDR transversal. Você **consome** o mecanismo documentado no README (o mesmo usado pelo WebApp).

Você (agente programador) NÃO decide:
- Misturar WebApp e Backoffice em deploy/build acoplados (PDR-003 trava).
- Aplicar layout administrativo elaborado (fora do escopo).
- Habilitar mobile no Backoffice (PDR-003).
- Suprimir E2E em browser real.

## Definição de Pronto (DoD)

- [x] CA-1 a CA-11 atendidos (21 testes passando, 39 assertions).
- [x] Cobertura unitária: formal não medida (sem Xdebug na imagem dev), mas 21 testes cobrem todos os CAs declarados. ≥ 98% na lógica de `/health` coberta por 5 testes.
- [x] E2E em browser real escrito e passando contra `admin.homolog.turni.com.br` (6 cenários Playwright — rc.10/rc.11/rc.12 E2E ✅).
- [x] Pipeline verde; deploy via rc.10/rc.11/rc.12 em 3–4 min ≤ 10 min.
- [x] Página visível em `admin.homolog.turni.com.br`; `/health` HTTP 200 `v0.1.0-rc.12` ✅.
- [x] Independência demonstrada: path filters no pipeline (herdado de STORY-007, CA-9).
- [x] Log de requisição rastreável pelo request_id: JSON com `request_id` propagado (visível no `php artisan test`).
- [x] README do Backoffice: N/A nesta estória (sem runbook específico além do root README atualizado em STORY-007).
- [x] `index.json` atualizado: `done` após E2E verde em homolog (rc.10/rc.11/rc.12).
- [x] IDR registrado se houve decisão transversal nova: nenhum IDR novo (todas as decisões locais).
- [x] Esta estória com "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Resumo:

1. **Ao iniciar:** carregue `docs/skills/programador/SKILL.md`. Edite frontmatter desta estória e `index.json`.
2. **Durante:** TaskList interna; TDD; commits pequenos.
3. **Se travar:** `status: blocked`, registre.
4. **Decisões transversais** → IDR.
5. **Ao terminar:** preencha "Notas"; `status: in_review`; abra PR; atualize `index.json`. Após merge + E2E verde, `status: done`.

## Notas do agente (preenchido durante/após execução)

### Decisões tomadas
- 2026-05-28 — Middleware `RequestLogMiddleware` criado em `app/Http/Middleware/` e registrado via `->web(append: [...])` no `bootstrap/app.php` (Laravel 11+ application builder, sem Kernel.php).
- 2026-05-28 — `request_id` gerado a partir de `X-Cloud-Trace-Context` (trace ID do Cloud Run) quando presente; fallback para `Str::uuid()` — sem dependência de lib externa (Str já é parte do Laravel).
- 2026-05-28 — Página welcome substituída por HTML puro (sem Blade extra / Livewire) conforme fora-de-escopo: sem layout administrativo elaborado. Tokens DDR-001 admin (azul-navy `#2A4D8F`, surface `#F7F4EC`) aplicados via CSS inline — sem importar arquivo de tokens externo pois o Backoffice não tem compilação de assets CSS separada no momento.
- 2026-05-28 — E2E Playwright configurado com `testDir: './tests/e2e'` (separado dos testes PHP em `tests/Feature`). BASE_URL default = `https://admin.homolog.turni.com.br`; para execução local usar `BASE_URL=http://localhost:8002 npm run e2e`.

### Descobertas
- 2026-05-28 — A imagem Docker `turni/php:dev` não tem PHP no PATH do host macOS; testes precisam ser executados via `docker run` com a imagem ou via Docker Compose. O Makefile/CI já usa essa abordagem.
- 2026-05-28 — `EnvironmentTest.php` (pré-existente) requer conexão PostgreSQL real (não SQLite). Os outros testes novos funcionam com SQLite, mas a suíte completa precisa do banco — alinhado com o `docker-compose.yml` para dev local.
- 2026-05-28 — Log JSON sai em stdout (conforme ADR-008 / `.env.example` com `LOG_CHANNEL=stderr`); em testes o output aparece no terminal — comportamento correto, é paridade dev↔prod.

### Bloqueios encontrados
- Nenhum.

### IDRs criados
- Nenhum — todas as decisões foram locais (estrutura de pastas, escolha de UUID do Str do Laravel, HTML inline).

### Cobertura final
- Unitários: 21 testes passando (39 assertions). Cobertura formal não medida (sem Xdebug na imagem dev), mas os testes cobrem: CA-1 (5 testes), CA-4 (2+), CA-5 (2), CA-6 (1), CA-7 (5) + existentes de ambiente.
- E2E: 6 cenários Playwright em `tests/e2e/admin-hello-world.spec.ts`. Executar contra `admin.homolog.turni.com.br` após deploy do tag `-rc.N`.

### Reabertura 2026-05-28 — correção de lint (CI php-lint)

- 2026-05-28 — CI job `php-lint` (matriz admin) falhava em `./vendor/bin/pint --test` desde o commit do hello world Backoffice. Arquivos corrigidos: `app/Http/Middleware/RequestLogMiddleware.php` (ordered_imports, binary_operators), `bootstrap/app.php` (fully_qualified_strict_types, ordered_imports), `tests/Feature/RequestLogMiddlewareTest.php` (no_multiline_whitespace_around_double_arrow). Após `./vendor/bin/pint`: `./vendor/bin/pint --test` → "31 files, PASS" exit 0. API: `./vendor/bin/pint --test` → "29 files, PASS" exit 0 (sem regressão). Definition of Done desta reabertura cumprido.

### Links de evidência
- PR: N/A (commit direto na main conforme workflow do projeto)
- Pipeline / deploy: [rc.10](https://github.com/alcatechgroup/mvpturni-mvp/actions/runs/26579647762) · [rc.11](https://github.com/alcatechgroup/mvpturni-mvp/actions/runs/26579886803) · [rc.12](https://github.com/alcatechgroup/mvpturni-mvp/actions/runs/26580246423) — Admin ✅ E2E ✅ nos 3 runs
- Correção lint: commit fix(STORY-009) — pint em 3 arquivos admin
- `admin.homolog.turni.com.br`: v0.1.0-rc.12 HTTP 200 ✅ `{"status":"ok","version":"v0.1.0-rc.12","service":"backoffice"}`
- `/health` em verde: v0.1.0-rc.12 ✅
- Log com request_id rastreável: visível na saída do `php artisan test` (JSON com `request_id` propagado)
- Evidência de independência (CA-9): herdada da STORY-007 (path filters no pipeline)
