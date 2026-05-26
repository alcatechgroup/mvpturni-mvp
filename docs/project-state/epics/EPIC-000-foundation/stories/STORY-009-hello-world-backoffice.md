---
story_id: STORY-009
slug: hello-world-backoffice
title: "Hello world" no Backoffice — rota raiz e health-check
epic_id: EPIC-000
sprint_id: null
type: implementation
target_role: programador
requires_design: false
status: ready
owner_agent: null
created_at: 2026-05-26
updated_at: 2026-05-26
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

- [ ] **CA-1:** `GET /` em `admin.homolog.turni.com.br` retorna 200 com página HTML renderizando: "Turni — Backoffice (Admin)" como identificador inequívoco (não pode ser confundida visualmente com a página do WebApp), versão visível (formato `vX.Y.Z-rc.N`), link explícito para `/health`.
- [ ] **CA-2:** A página aplica tokens base de DDR-001 (tipografia, paleta) em nível mínimo, sem layout administrativo. Contraste WCAG 2.1 AA (`quality-standards.md` seção 5).
- [ ] **CA-3:** A página funciona em **desktop** nos navegadores listados em `non-functional.md` (Chrome, Firefox, Safari, Edge nas duas últimas versões major). Não exige experiência mobile (PDR-003: backoffice é desktop-only).

### Rota `/health`

- [ ] **CA-4:** `GET /health` retorna 200 com payload JSON (ou conforme ADR-008) contendo no mínimo: `status: "ok"`, `version: "<tag>"`, `timestamp: "<ISO 8601>"`, `service: "backoffice"`.
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
- Como ler a versão do build em runtime.
- Cenários E2E adicionais opcionais.

Você (agente programador) NÃO decide:
- Misturar WebApp e Backoffice em deploy/build acoplados (PDR-003 trava).
- Aplicar layout administrativo elaborado (fora do escopo).
- Habilitar mobile no Backoffice (PDR-003).
- Suprimir E2E em browser real.

## Definição de Pronto (DoD)

- [ ] CA-1 a CA-11 atendidos.
- [ ] Cobertura unitária ≥ 80% no código novo; ≥ 98% na lógica de `/health`.
- [ ] E2E em browser real escrito, passando contra `admin.homolog.turni.com.br`.
- [ ] Pipeline verde no PR; deploy via tag `-rc.N` em ≤ 10 min.
- [ ] Página visível em `admin.homolog.turni.com.br`; `/health` retorna 200.
- [ ] Independência demonstrada (CA-9).
- [ ] Log de uma requisição rastreável pelo request_id.
- [ ] README do Backoffice atualizado.
- [ ] `index.json` atualizado: `in_review` ao abrir PR; `done` após merge + E2E verde.
- [ ] IDR registrado se houve decisão transversal nova.
- [ ] Esta estória com "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Resumo:

1. **Ao iniciar:** carregue `docs/skills/programador/SKILL.md`. Edite frontmatter desta estória e `index.json`.
2. **Durante:** TaskList interna; TDD; commits pequenos.
3. **Se travar:** `status: blocked`, registre.
4. **Decisões transversais** → IDR.
5. **Ao terminar:** preencha "Notas"; `status: in_review`; abra PR; atualize `index.json`. Após merge + E2E verde, `status: done`.

## Notas do agente (preenchido durante/após execução)

### Decisões tomadas
- <data> — <decisão local>

### Descobertas
- <data> — <surpresa / gotcha>

### Bloqueios encontrados
- <data> — <bloqueio>

### IDRs criados
- IDR-XXX — <título>

### Cobertura final
- Unitários: <%>
- E2E: <cenários, link para evidência>

### Links de evidência
- PR: <url>
- Pipeline / deploy: <url>
- `admin.homolog.turni.com.br`: <link>
- `/health` em verde: <link>
- Log com request_id rastreável: <link>
- Evidência de independência (CA-9): <link>
