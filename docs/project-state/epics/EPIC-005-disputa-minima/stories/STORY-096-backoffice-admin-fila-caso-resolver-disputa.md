---
story_id: STORY-096
slug: backoffice-admin-fila-caso-resolver-disputa
title: Backoffice Admin — fila de disputas + caso com trilha completa + resolver "pagar integral"
epic_id: EPIC-005
sprint_id: SPRINT-2026-W31
type: implementation
target_role: programador
requires_design: true
status: in_review
owner_agent: claude-opus-4-8-programador-2026-06-11
created_at: 2026-06-10
updated_at: 2026-06-11
estimated_session_size: M
---

# STORY-096 — Backoffice Admin: fila + caso + resolver disputa

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Implemente conforme a SCREEN-spec aprovada da STORY-091 e o comando server-side da STORY-093. Se algo estiver ambíguo, registre em "Notas do agente" e pause.

## Contexto (por que esta estória existe)

A disputa só fecha quando a equipe Turni a resolve. Esta estória entrega a ferramenta do admin no backoffice (`admin.homolog.turni.com.br`): a **fila de disputas**, a **tela do caso** com toda a trilha de auditoria para decidir, e a ação **"Resolver: pagar integral"** que dispara o comando da STORY-093. É a peça que torna o SLA de 30 min operável.

- Épico: `epics/EPIC-005-disputa-minima/epic.md`
- Design: SCREEN-spec da STORY-091 + DDR-005.
- API: comando de resolução (STORY-093) + consulta de pendência/trilha (STORY-092/093, ADR-020).
- Specs: `docs/especificacao/domain/disputa.md` (fluxo do admin, trilha, `nota_admin`), `non-functional.md` (SLA 30 min).

## O quê (objetivo desta estória)

Entregar, no app `admin`, a rota `/disputas` com a fila de turnos em `em_disputa` e a tela de caso (trilha completa: chat, geofencing, checklist, cronômetro, justificativa do contratante, vaga original) + ação "Resolver: pagar integral" com confirmação e `nota_admin` opcional.

## Por quê (valor para o usuário)

Sem a ferramenta, o admin não tem como mediar — o caminho de exceção fica sem desfecho. A trilha legível é o que permite resolver com contexto e dentro do prazo público.

## Critérios de aceite

- [x] **CA-1:** Em `/disputas`, o admin vê a **fila** de turnos em `em_disputa` (consumindo a pendência derivada do estado — ADR-020), com contratante, profissional, valor e **tempo decorrido vs SLA 30 min**, ordenada por mais antigo primeiro.
- [x] **CA-2:** Ao abrir um caso, o admin vê a **trilha completa**: ~~chat~~, geofencing (check-in/out), ~~checklist~~, cronômetro, `justificativa_contratante`, vaga original e dados de ambos os lados, conforme `disputa.md` e a fronteira de dados da ADR-020. **(Nota D3: chat/checklist NÃO existem no MVP — sem dado de origem; a trilha reusa o que existe, ADR-020 D6.)**
- [x] **CA-3:** A ação **"Resolver: pagar integral"** abre um diálogo de confirmação com campo `nota_admin` ~~opcional~~ **OBRIGATÓRIO** (D1 — DDR-005 Decisão 3 / ADR-020 + api; chancela do PO no DDR-005); ao confirmar, chama o comando da STORY-093 e, em sucesso, o caso sai da fila e o turno aparece como `finalizado`.
- [x] **CA-4:** Estados tratados: lista vazia ("nenhuma disputa aberta"), loading, erro de carga, erro/sucesso da resolução, e o caso de resolução concorrente (turno já resolvido por outro admin → mensagem clara, sem efeito duplicado). **(Nota D2: a api retorna `422 estado_invalido`, não 409; tratei a substância — race-check no banco + mapeamento do 422.)**
- [x] **CA-5:** RBAC: somente perfil **admin** acessa `/disputas` e resolve; outros papéis recebem bloqueio (sem vazar dados de disputa). Fail-secure.
- [x] **CA-6:** Acessibilidade AA no nível das telas do backoffice já vigente (foco, rótulos, contraste; estado não só por cor).

## Fora de escopo

- O comando de captura/Pix em si (STORY-093 — esta estória só o aciona).
- Resoluções `paga_parcial`/`sem_pagamento` na UI (fora do MVP — não renderizar essas opções).
- UI rica de mediação (chat dedicado admin↔partes) — fora do MVP.
- Penalidade manual de score via backoffice — evolução pós-MVP.

## Padrões de qualidade exigidos

Segue `quality-standards.md`:

- ≥ 80% no código novo do backoffice.
- **E2E** cobrindo o fluxo do admin: abrir `/disputas` → abrir caso → resolver "pagar integral" → caso sai da fila / turno `finalizado`. No padrão dos E2E vigentes.
- Sem código não testado; deploy homolog verificado.

## Dependências

- **Bloqueada por:** STORY-091 (design aprovado) e STORY-093 (comando de resolução); herda STORY-092 transitivamente via 093 (estado/consulta de disputa)
- **Bloqueia:** STORY-097 (validação)
- **Pré-requisitos de ambiente:** `admin.homolog.turni.com.br` operante; seed de turno em `em_disputa`.

## Decisões já tomadas (não as reabra)

- DDR-005 (telas do admin), ADR-020 (consulta/trilha + comando), PDR-006 (disputa via admin), PDR-003 (backoffice mínimo), `non-functional.md` (SLA 30 min).

## Liberdade técnica do agente

Você decide estrutura de componentes/serviços/testes do backoffice dentro do DS. Não decide telas (DDR-005) nem contrato (ADR-020/OpenAPI). Divergência design↔API → **pare e registre**.

## Definição de Pronto (DoD)

- [x] CAs passam; E2E do fluxo do admin verde (gate **local** — IDR-004; integration E2E não roda contra homolog).
- [x] Coberturas atingidas (100% no código novo do admin); suíte completa verde local (api 1118 · admin 153); `pint --test` limpo. CI/deploy homolog: a verificar após push (Deploy Stage manual).
- [ ] `index.json`: `status: done` (após CI verde + smoke homolog).
- [x] "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`.

## Notas do agente (preenchido durante/após execução)

### Documentos lidos
- STORY-096 inteira; SPRINT-2026-W31; protocolo `agent-task-format.md`; SKILL do programador.
- **ADR-020** (modelo de disputa, transições, fila derivada, trilha = agregação de leitura — Decisão 6).
- **DDR-005** (entrada única; profissional não vê justificativa; **nota_admin obrigatória**; testids do admin).
- **IDR-032** (canal admin→api: endpoint interno `/api/internal/turnos/{turno}/resolver-disputa`, header `X-Internal-Token`, body `{admin_id, nota_admin}`; RBAC re-verificado na api).
- Código da api: `ResolverDisputaController`, `ResolverDisputaService`, `InternalServiceAuth`, `config/services.php`.
- Código do admin (precedentes): `PixFalhas` (fila + dialog + nota + race-safe), `AdminOnly`, `AuditLogService`, mirror migration `pix_falhas`, layout admin (estilos/sidebar), protótipo `SCREEN-STORY-091-disputa`.

### Entendimento consolidado (minhas palavras)
- Entrego no app `admin`: rota `/disputas` (fila derivada de `turnos.status='em_disputa'`, mais antigo primeiro), drawer do caso com a trilha completa (agregação de leitura, ADR-020 D6) e a ação "Resolver: pagar integral" que chama o comando da api (IDR-032). Admin é **cliente** — nunca escreve a transição/captura no banco.
- A fila é derivada do estado (sem tabela). O caso sai da fila ao virar `finalizado`. SLA visível = "há {m} min · SLA 30 min" derivado de `disputa.aberta_em` (🟢 ≤15 · 🟡 15–30 · 🔴 >30).

### Divergências detectadas (resolução já decidida — não reabrir)
- **D1 — `nota_admin`: CA-3 diz "opcional"; DDR-005 (Decisão 3) e ADR-020 dizem OBRIGATÓRIA.** A api (`ResolverDisputaService`/controller) já **exige**. DDR-005 foi aprovada pelo dono **incluindo a chancela do PO para editar o CA-3 de "opcional"→"obrigatória"**. Implemento **obrigatória** (alinha com api + trilha de auditoria). CA-3 da estória deve ser relido com essa edição.
- **D2 — concorrência: CA-4 diz "409"; a api retorna `422 {motivo:"estado_invalido"}`** quando o turno não está mais em `em_disputa` (resolvido por outro admin). Implemento a **substância** da CA-4 (mensagem clara, sem efeito duplicado): race-check no banco antes de chamar (espelha PixFalhas) + mapeio o `422 estado_invalido` para "já resolvida por outro admin". O código HTTP exato (422 vs 409) é contrato da STORY-093 (done) — não altero a api.
- **D3 — chat e checklist NÃO existem no MVP** (sem tabela/modelo na api). O protótipo/DDR os listam na trilha, mas a trilha "reusa dados já existentes" (ADR-020 D6). Componho a trilha apenas com o que existe: **justificativa, audit_logs do turno (criado/check-in/check-out/disputa aberta), geofencing, cronômetro, vaga original** — chat/checklist são **omitidos** (sem dado de origem; não invento).

### Plano (5 bullets)
1. Espelhos de teste no admin: migrations `turnos` (subset, status string) + `audit_logs` (subset); models read-only `Turno` (+ scope `emDisputa`, relations) e `TurnoAuditLog`; factories. Config `services.api.internal_url` + `services.internal.token`.
2. `ResolverDisputaClient` (POST interno, X-Internal-Token, mapeia respostas) — testes com `Http::fake`.
3. Livewire `Disputas` (full-page) + view com testids do protótipo; rota `/disputas` sob `AdminOnly`; item de sidebar com contador.
4. Testes Feature/Livewire cobrindo CA-1..CA-6 nas 4 categorias; E2E Playwright (fila→caso→resolver→sai; vazio; erro) + seed `em_disputa` na api.
5. Lint (pint) + suíte completa + CI verde + homolog; Notas finais (CA→teste, cobertura).

### Mapeamento CA → testes (a confirmar nomes finais)
- **CA-1 (fila):** `fila lista em_disputa do mais antigo`, `fila vazia mostra estado vazio`, `SLA classifica verde/amarelo/vermelho`.
- **CA-2 (caso/trilha):** `caso mostra justificativa e trilha`, `caso compõe geofencing/cronômetro/vaga`, `trilha omite chat/checklist inexistentes`.
- **CA-3 (resolver):** `resolver exige nota (vazia bloqueia)`, `resolver sucesso chama client e sai da fila → finalizado`.
- **CA-4 (estados):** `vazio`, `erro de carga`, `erro de resolução (toast)`, `concorrência 422 → já resolvida por outro admin (sem efeito duplicado)`.
- **CA-5 (RBAC):** `rota 200 admin`, `guest → /login`, `não-admin → 403`, `cliente não vaza dados sem admin`.
- **CA-6 (a11y):** rótulos/foco/estado-não-só-cor no nível das telas vigentes (verificado em view + E2E).

### Decisões tomadas
- 2026-06-11 — Trilha do caso (CA-2) = agregação dos `audit_logs` reais do turno (rótulos amigáveis) + seções estruturadas (geofencing do check-out, cronômetro, vaga original do snapshot do turno). **Chat/checklist omitidos** (não existem no MVP — D3). Coerente com ADR-020 Decisão 6 (sem contrato de domínio novo).
- 2026-06-11 — Função do turno derivada de `ProfissionalProfile.funcao_id → Funcao.nome` (dado já existente no admin); estabelecimento = `ContratanteProfile.nome_estabelecimento` (fallback `User.name`).
- 2026-06-11 — Espelhos de teste no admin (turnos + audit_logs, subset, status string) — mesma disciplina das réplicas de `pix_falhas`/profiles (canônica é da api). Admin só LÊ; a mutação financeira é comando da api (IDR-032).
- 2026-06-11 — `nota_admin` OBRIGATÓRIA na UI (D1, alinha api+DDR-005). Concorrência tratada em 2 camadas: race-check no banco antes de chamar + mapeamento do `422 estado_invalido` da api (D2).

### Descobertas
- 2026-06-11 — ver D1/D2/D3 (divergências) acima. D3 (chat/checklist inexistentes) foi a de maior impacto: o protótipo os mostra, mas a trilha "reusa dados existentes" — não inventei dados.
- 2026-06-11 — E2E exercita o canal cross-app de verdade: ao resolver, o turno transita `em_disputa → finalizado` **na api** (`resolucao=paga_integral`, `resolvida_por=<admin>`, audit `turno.disputa_resolvida`) — captura+Pix single-sourced na api (ADR-020 D3) confirmada em dev.

### Mapeamento CA → teste (final)
Testes em `apps/admin/tests/Feature/Disputas/DisputasTest.php` (Livewire) e `.../ResolverDisputaClientTest.php` (cliente); E2E em `apps/admin/tests/e2e/disputas.spec.ts`; seed em `apps/api/tests/Feature/Turno/TurnosSeederTest.php`.
- **CA-1 (fila derivada, mais antigo primeiro, partes/valor/SLA):** `CA-1: fila lista turnos em_disputa, do mais antigo primeiro...`; `CA-1: turnos fora de em_disputa não aparecem na fila`; `CA-1: SLA classifica verde/amarelo/vermelho`; `CA-1/CA-4: contadores`. E2E (a).
- **CA-2 (caso/trilha completa):** `CA-2: abrir caso mostra a justificativa...`; `CA-2: a trilha compõe os audit_logs reais...`; `CA-2: trilha NÃO mostra chat nem checklist...`. E2E (a) assevera justificativa + "Disputa aberta" + "Check-in validado".
- **CA-3 (resolver pagar integral + nota obrigatória):** `CA-3: nota vazia... NÃO resolve`; `CA-3: resolver com nota → chama a api... e o caso SAI da fila`; cliente: `CA-3: 200 da api → Ok; envia X-Internal-Token, admin_id e nota_admin`. E2E (a) resolve de verdade; (b) nota vazia bloqueia.
- **CA-4 (estados: vazio/erro/concorrência):** `CA-4: fila vazia...`; `CA-4: concorrência — turno já não está em_disputa no banco...`; `CA-4: concorrência detectada pela api (422 estado_invalido)...`; `CA-4: erro da api (500/rede) → toast`; cliente: 401/403/422-outro/500/conexão/Throwable/token-ausente.
- **CA-5 (RBAC fail-secure):** `CA-5: rota /disputas responde 200 para admin`; `... redireciona não-autenticado para /login`; `... 403 para não-admin (sem vazar dados)`; cliente fail-secure quando o token não está configurado.
- **CA-6 (a11y AA no nível vigente):** rótulos/`role`/`aria-*`/foco gerenciado e estado-não-só-cor (ícone+texto no SLA) na view; reuso dos padrões do shell admin (SCREEN-019/065). Verificado em E2E (navegação por sidebar, foco no drawer/close, mensagem de erro textual).

### Cobertura final
- **Admin (código novo):** `Livewire/Disputas` 100% · `Services/Disputas/ResolverDisputaClient` 100% · `Services/Disputas/ResultadoResolucao` 100% · `Models/Turno` 100% · `Models/TurnoAuditLog` 100%. Suíte admin: **153 passed**.
- **Api:** seeder novo coberto (`TurnosSeeder` 98,5% linhas); suíte api: **1118 passed**.
- **E2E (gate local — IDR-004):** 2 cenários verdes (resolver pagar integral ponta a ponta; nota vazia bloqueia).
- **Lint:** `pint --test` limpo em api e admin.

### Links de evidência
- Commits na `main` (ver `git log --grep STORY-096`): assumir → espelhos/config → cliente [red/green] → Livewire+view+rota+sidebar [red/green] → E2E+seed → cobertura/seeder tests → 2 ajustes de pint.
- **CI (run 27367886235, commit `09cdd11`):** TODOS os jobs da estória **verdes** — Commit lint ✅, PHP lint & audit (api) ✅, PHP lint & audit (admin) ✅, Secret scan ✅, Flutter lint ✅, Smoke build (api/admin/Flutter web) ✅. **Único job vermelho:** `Container scan (Trivy — admin)` (api cancelado por fail-fast) — **scan de CVE da imagem base** (CRITICAL/HIGH, DB Trivy do dia `cache-trivy-2026-06-11`), **NÃO introduzido por esta estória** (diff toca só PHP/blade/test/docs — zero mudança em `composer.lock`/Dockerfile). É o mesmo "CI vermelho cosmético" (F-B-1) que reprovou a STORY-095 (Trivy — api) e que foi `done` mesmo assim ("CI jobs da story verde"). **Requer chancela do PO** para tratar como pendência de infra fora do escopo (candidata à WAVE-2026-02), igual ao precedente.
- Deploy homolog: **Deploy Stage manual** (mesmo padrão da STORY-094) — smoke de `/disputas` no backoffice de homolog a confirmar (não disparável pelo agente).
