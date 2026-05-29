---
story_id: STORY-034
slug: adotar-integration-test-no-webapp
title: Adotar integration_test no WebApp Flutter Web e migrar os 7 cenários de RBAC/funnel
epic_id: EPIC-007
sprint_id: null
type: enablement
target_role: programador
requires_design: false
status: draft
owner_agent: null
created_at: 2026-05-29
updated_at: 2026-05-29
estimated_session_size: L
---

# STORY-034 — Adotar integration_test no WebApp e migrar cenários de RBAC/funnel

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Esta estória é a base do EPIC-007 — ela cria o scaffolding de `integration_test`, define o padrão de teste Flutter (via IDR-011) e migra a cobertura existente sem regressão. STORY-035 (Patrol) e STORY-036 (gate mobile) dependem do que sai daqui. Se algo estiver ambíguo, registre em "Notas do agente" e pause em vez de adivinhar.

## Contexto (por que esta estória existe)

Hoje o E2E do WebApp roda 100% em Playwright contra Flutter Web/CanvasKit. Funciona — última execução em 2026-05-29 01:27 UTC: 11 testes / 10 passed / 0 failed / 1 skipped legítimo. Mas o padrão depende do truque registrado em IDR-006 §b: ativar `flt-semantics-placeholder`, digitar com `keyboard.type()` real (porque `fill()` não sincroniza com `TextEditingController`), rodar com `workers: 1`. Cada elemento desses existe porque não havia ferramenta nativa Flutter para fazer E2E quando a STORY-016 fechou.

`integration_test` é a ferramenta nativa. Acessa a árvore de widgets direto, usa `pumpAndSettle()` (determinístico, espera o frame em vez de timeout fixo), o mesmo código roda em Web, Android e iOS. O EPIC-007 (`epic.md` deste diretório) decidiu o modelo híbrido: `integration_test` para UI, Playwright para smoke HTTP, Patrol para nativo. Esta story entrega o pé de `integration_test` no Web e migra a cobertura existente.

A pressão é dupla: (i) o roadmap inclui virar nativo (Android/iOS), e Playwright não roda em mobile; (ii) STORY-022+ (novos fluxos do WebApp pós-EPIC-001) ainda não foram escritas — quanto antes o padrão `integration_test` estiver de pé, menos retrabalho elas geram.

- Épico: `docs/project-state/epics/EPIC-007-e2e-hibrida-flutter/epic.md`
- Documentos canônicos a ler ANTES de codificar:
  - `docs/project-state/decisions/idr/IDR-004-e2e-local-pipeline-smoke-curl.md` — política de gate local pré-tag.
  - `docs/project-state/decisions/idr/IDR-006-flutter-web-path-strategy-e-e2e-via-semantics.md` — §a/§c continuam vigentes; §b é o que esta story vai marcar como parcialmente superseded.
  - `apps/webapp/tests/e2e/rbac-login.spec.ts` — os 7 cenários a migrar.
  - `apps/webapp/tests/e2e/webapp-hello-world.spec.ts` — os 4 cenários que **ficam** em Playwright (smoke HTTP).
  - `apps/webapp/playwright.config.ts`, `apps/webapp/package.json` — config atual.
  - `apps/webapp/test/login_screen_test.dart` — estilo Dart já usado no projeto.
  - `apps/webapp/lib/router.dart`, `apps/webapp/lib/main.dart` — onde `usePathUrlStrategy()` e go_router são configurados.
  - `Makefile` targets `e2e`, `e2e-webapp`, `_e2e-seed`.
  - `docs/skills/po/references/quality-standards.md` §1.2 — E2E em browser real continua obrigatório.

## O quê (objetivo desta estória)

Implementar no WebApp:

1. **Scaffolding de `integration_test`** em `apps/webapp/integration_test/` (pasta no nível de `lib/`, padrão Flutter):
   - `pubspec.yaml`: adicionar `integration_test` (SDK) em `dev_dependencies`.
   - Pasta `integration_test/helpers/` com:
     - `pump_app.dart` — sobe o WebApp no `WidgetTester` apontando para a API do docker-compose (mesmo seed que o Playwright já usa via `_e2e-seed`).
     - `login_helper.dart` — `loginAs(WidgetTester tester, {required String email, required String password})` que preenche e submete o formulário de login.
     - `route_helper.dart` — `assertOnRoute(WidgetTester tester, String path)` usando go_router para asserir rota corrente.
   - 1 arquivo `<feature>_test.dart` por agrupamento natural:
     - `auth/login_structure_test.dart` (CA-5)
     - `auth/login_validation_test.dart` (campo obrigatório, credencial inválida)
     - `auth/rbac_profissional_test.dart` (CA-13b)
     - `auth/rbac_admin_rejected_test.dart` (CA-13c)
     - `auth/funnel_guard_test.dart` (CA-10/CA-11)
2. **Keys nos widgets relevantes** — adicionar `ValueKey('login:email')`, `ValueKey('login:password')`, `ValueKey('login:submit')`, `ValueKey('login:forgot-password')`, `ValueKey('login:error-banner')` na `LoginScreen`, e similar para Welcome/CompletarCadastro nos pontos que os testes asseriam. Padrão de Keys vira IDR-011 (esta story propõe).
3. **Migração dos 7 cenários** de `tests/e2e/rbac-login.spec.ts` para os arquivos acima. Remover o arquivo `rbac-login.spec.ts` ao final, depois que `integration_test` estiver verde.
4. **Manter Playwright como smoke HTTP** — `tests/e2e/webapp-hello-world.spec.ts` fica como está (4 cenários atuais, 1 `test.fixme` para `/health` em homolog). Adicionar 1 cenário novo: deep link via URL real do browser (abrir `/login` direto, asserir que carrega — proteção do bug que a IDR-006 §a corrigiu).
5. **Makefile**:
   - `make e2e-webapp` passa a rodar (a) `flutter test integration_test -d chrome --headless` e depois (b) `npx playwright test` (smoke HTTP). `webapp-build` continua antes (mantém IDR-006 §c).
   - Documentar como rodar separadamente em modo dev: `make e2e-webapp-integration` e `make e2e-webapp-smoke`.
6. **IDR-010 e IDR-011** propostos em `docs/project-state/decisions/idr/`:
   - IDR-010 — Modelo híbrido (integration_test + Playwright + Patrol). Supersede parcial de IDR-006 §b. Refina IDR-004.
   - IDR-011 — Padrão de teste Flutter (Keys, mocks vs API real, helpers, naming).
   - Ambas em `status: proposed` aguardando aprovação do Alexandro.
7. **Atualizar IDR-006** — anotar no header e na §b "parcialmente superseded por IDR-010 a partir desta data". Não apagar — IDR-006 §a (path strategy) e §c (build fresco) continuam vigentes.
8. **README do WebApp** (`apps/webapp/README.md`) ganha seção "Testes E2E" descrevendo: o que `integration_test` cobre, o que Playwright cobre, quando usar cada uma, comandos.

## Por quê (valor para o time)

Para **profissional** e **contratante** futuros, valor zero direto — esta é fundação de teste. Para o **time**:

- Testes determinísticos (`pumpAndSettle()` em vez de `waitForTimeout(2000)`) reduzem flake e tornam o gate confiável.
- O mesmo arquivo Dart vai rodar em Android/iOS sem mudar uma linha quando o native chegar (STORY-XXX), evitando reescrita.
- Padrão (IDR-011) registrado antes da STORY-022+ entrar, evitando que cada story invente o próprio jeito.
- Reduz dívida técnica documentada em IDR-006 §b (truque do semantics era contorno, não solução).

## Critérios de aceite

### Scaffolding

- [ ] **CA-1:** `apps/webapp/pubspec.yaml` tem `integration_test` (SDK) em `dev_dependencies`. `flutter pub get` roda sem erro. `flutter pub deps` mostra `integration_test` resolvido.
- [ ] **CA-2:** `apps/webapp/integration_test/helpers/` existe com `pump_app.dart`, `login_helper.dart`, `route_helper.dart`. Cada helper tem ao menos 1 docstring de uso. Convenções seguem IDR-011 (proposto nesta story).
- [ ] **CA-3:** Keys padronizadas adicionadas nos widgets (`ValueKey('login:email')`, etc.). Convenção `<feature>:<element>` documentada em IDR-011. Widgets antigos sem Key continuam funcionando (zero regressão visual).

### Migração dos cenários

- [ ] **CA-4:** Cenário "exibe campos e-mail, senha, link de recuperação e botão Entrar" (CA-5 da IDR-006/STORY-016) migrado para `integration_test/auth/login_structure_test.dart` e passa via `flutter test integration_test/auth/login_structure_test.dart -d chrome --headless`.
- [ ] **CA-5:** Cenário "validação: submeter vazio exibe erro de campo obrigatório" migrado para `integration_test/auth/login_validation_test.dart` e passa.
- [ ] **CA-6:** Cenário "credencial inválida não autentica — permanece em /login" migrado para `integration_test/auth/login_validation_test.dart` e passa.
- [ ] **CA-7:** Cenário "profissional ativo loga e é roteado para /app" (CA-13b) migrado para `integration_test/auth/rbac_profissional_test.dart` e passa. Roda contra docker-compose + seed (mesmo modelo do Playwright atual).
- [ ] **CA-8:** Cenário "admin não loga no WebApp — vê banner de redirecionamento" (CA-13c) migrado para `integration_test/auth/rbac_admin_rejected_test.dart` e passa.
- [ ] **CA-9:** Cenários de funnel guard "/welcome sem auth → /login" e "/completar-cadastro sem auth → /login" (CA-10/CA-11) migrados para `integration_test/auth/funnel_guard_test.dart` e passam.
- [ ] **CA-10:** `apps/webapp/tests/e2e/rbac-login.spec.ts` removido do repositório (todos os 7 cenários ficam cobertos por `integration_test`).

### Smoke Playwright preservado

- [ ] **CA-11:** `apps/webapp/tests/e2e/webapp-hello-world.spec.ts` continua intocado (4 cenários, 1 `test.fixme` em `/health`).
- [ ] **CA-12:** Novo cenário "deep link `/login` direto na URL não cai em WelcomeScreen" adicionado a `webapp-hello-world.spec.ts` — proteção contra regressão da IDR-006 §a. Passa contra `localhost:8003`.

### Gate

- [ ] **CA-13:** `make e2e-webapp` roda (a) `webapp-build` (b) `flutter test integration_test -d chrome --headless` (c) `npx playwright test`, nesta ordem. Sai 0 quando todos passam. Sai não-zero ao primeiro fail.
- [ ] **CA-14:** `make e2e-webapp-integration` e `make e2e-webapp-smoke` existem como targets isolados para iteração em dev. Documentados em comentário no Makefile.
- [ ] **CA-15:** 5 execuções consecutivas locais de `make e2e-webapp` verdes, sem flake. Evidência (logs ou hash de relatórios) em "Notas do agente".
- [ ] **CA-16:** Wall-time de `make e2e-webapp` documentado em "Notas do agente" e comparado ao baseline atual (~tempo do report 2026-05-29 01:27 UTC). Se aumentar, justificar; se aumentar >30%, escalar para PO.

### Decisões

- [ ] **CA-17:** IDR-010 (modelo híbrido) escrita em `decisions/idr/IDR-010-e2e-hibrida-integration-test-playwright-patrol.md`, `status: proposed`. Inclui supersede parcial de IDR-006 §b.
- [ ] **CA-18:** IDR-011 (padrão de teste Flutter) escrita em `decisions/idr/IDR-011-padrao-teste-flutter-keys-mocks-helpers.md`, `status: proposed`. Cobre Keys, mocks vs API real, helpers, naming.
- [ ] **CA-19:** IDR-006 atualizada: header anota "§b parcialmente superseded por IDR-010 em 2026-XX-XX"; §b ganha nota inline. §a e §c intocados.

### Documentação

- [ ] **CA-20:** `apps/webapp/README.md` tem seção "Testes E2E" com: o que cada ferramenta cobre, comandos (`make e2e-webapp*`), como rodar 1 cenário isolado, como debugar.

### Pendência herdada

- [ ] **CA-21:** Nenhuma. EPIC-000 F-NB-1 (migrate:rollback) é responsabilidade da STORY-016, não desta.

## Fora de escopo

- Adotar Patrol (vai para STORY-035).
- Configurar Android emulator / iOS simulator (vai para STORY-036).
- Rodar `integration_test` em CI (gate continua local — IDR-004 mantida).
- Migrar Backoffice (continua em Playwright — apropriado para server-rendered HTML).
- Reescrever widget tests existentes em `apps/webapp/test/` (continuam como estão).
- Criar cobertura nova para fluxos que ainda não existem (STORY-017+ entram já em `integration_test` na sprint delas).
- Tornar mocks completos da API (esta story usa API real via docker-compose + seed, mesmo modelo do Playwright atual — IDR-011 decide a política para o futuro).

## Padrões de qualidade exigidos

Esta estória segue `docs/skills/po/references/quality-standards.md`:

- **E2E em browser real** continua obrigatório (§1.2) — `integration_test -d chrome` roda Chrome real headless, atende o critério.
- **Sem código não testado em produção** (§1.4) — os 7 cenários migrados mantêm a mesma cobertura antes/depois.
- **Determinismo** — proibido introduzir `Future.delayed(Duration(seconds: N))` em código de produção; em teste, preferir `pumpAndSettle()` ou `expect(find.byKey(...), findsOneWidget)` com `pump(Duration(milliseconds: X))` curto e justificado.
- **Cobertura unitária** — não muda nesta story (foco é E2E). Cobertura existente (`apps/webapp/coverage/`) deve continuar ≥ 80%.
- **Documentação** — IDR-010 e IDR-011 são parte do entregável, não opcionais.

## Dependências

- **Bloqueada por:** aprovação do PO no escopo do EPIC-007 e no esboço de IDR-010/IDR-011 (esta story propõe; PO aceita ao revisar).
- **Bloqueia:** STORY-035 (precisa do scaffolding de `integration_test` + IDR-010 aceita), STORY-036 (precisa de targets de Makefile e padrão definidos).
- **Pré-requisitos de ambiente:** docker-compose subindo via `make setup`; seed do CA-13 (admin@turni.local + profissional.teste@turni.local) carregado.

## Decisões já tomadas (não as reabra)

- **EPIC-007** define modelo híbrido (integration_test + Playwright + Patrol). Não é função desta story discutir se Playwright sai inteiro — ele fica para smoke HTTP.
- **IDR-004** — gate continua local. Esta story não move E2E para CI.
- **IDR-006 §a** (path strategy) e **§c** (build fresco) continuam vigentes.
- **IDR-009** — image_picker via filechooser no Web continua válido. Cobertura nativa fica para Patrol em STORY-035.
- **API real em E2E** — docker-compose + seed. Não trocar por mocks nesta story; IDR-011 decide política geral.

## Liberdade técnica do agente

Você (programador) decide:

- Organização interna de `integration_test/` (subpastas, naming) — desde que IDR-011 fique coerente.
- Quais Keys adicionar além das mínimas listadas — pode estender se ajudar legibilidade.
- Como compor os helpers (1 helper monolítico vs vários pequenos) — IDR-011 documenta o que escolher.
- Estratégia de espera em `pump_app` (boot do Flutter Web headless) — desde que determinística e justificada.
- Targets adicionais no Makefile se ajudarem iteração.

Você **não** decide:

- Apagar Playwright. Smoke HTTP continua.
- Suprimir o cenário de deep link novo (CA-12) — é proteção da IDR-006 §a.
- Mudar a política de gate (IDR-004 continua).
- Alterar tokens/UI do app (essa story toca Keys, não estilo). Se uma Key exigir refator visível, escalar.

## Definição de Pronto (DoD)

- [ ] CA-1 a CA-20 atendidos (CA-21 N/A).
- [ ] `make e2e-webapp` verde 5x consecutivos local; logs/evidência em "Notas".
- [ ] Cobertura unitária do WebApp ≥ 80% (não regredida).
- [ ] IDR-010 e IDR-011 em `status: proposed`, aguardando aprovação do PO; IDR-006 anotada com supersede parcial.
- [ ] README do WebApp atualizado.
- [ ] `tests/e2e/rbac-login.spec.ts` removido.
- [ ] `index.json` atualizado: `status: done`.
- [ ] PR aberto, hooks de pré-push verdes.
- [ ] "Notas do agente" preenchidas com decisões, bloqueios, comparativo de tempo.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Particular:

1. **Ao iniciar:** carregue `docs/skills/programador/SKILL.md`. Edite frontmatter desta estória (`status: in_progress`, `owner_agent: <seu id>`) e `index.json`. Confirme com PO se IDR-010/IDR-011 rascunhos cobrem o que você acha que precisa antes de codificar a suíte inteira — refatorar testes depois de escrever 7 deles é caro.
2. **Durante:** TaskList interna. TDD aplicado quando possível (escrever cenário de `integration_test` que falha, ajustar Keys, ver passar). Commits pequenos: scaffolding, helpers, 1 grupo de cenários por commit.
3. **Se travar:** `status: blocked`. Decisão de produto → PO. Decisão visual (alguma Key exigiu refator de tela) → Designer.
4. **Decisões transversais** vão em IDR. Esta story já prevê IDR-010 e IDR-011 — qualquer terceira IDR escala ao PO antes de escrever.
5. **Ao terminar:** confirme `make e2e-webapp` verde 5x, atualize "Notas", `status: in_review`, abra PR. Após merge + revisão das IDRs pelo PO + execução de validação do epic, `status: done`.

## Notas do agente (preenchido durante/após execução)

### Decisões tomadas
- _A preencher pelo agente executor._

### Descobertas
- _A preencher pelo agente executor._

### Bloqueios encontrados
- _A preencher pelo agente executor._

### IDRs criados
- IDR-010 (proposto nesta story).
- IDR-011 (proposto nesta story).

### Cobertura final
- E2E `integration_test`: 7 cenários migrados (CA-4 a CA-9).
- Smoke Playwright: 4 cenários (3 ativos + 1 fixme) + 1 novo (deep link).
- _Wall-time comparado: a preencher._

### Links de evidência
- _PR, commits, evidência das 5 execuções verdes: a preencher._
