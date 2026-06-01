---
story_id: STORY-038
slug: adotar-integration-test-no-webapp
title: Adotar integration_test no WebApp Flutter Web e migrar os 7 cenários de RBAC/funnel
epic_id: EPIC-007
sprint_id: SPRINT-2026-W26
type: enablement
target_role: programador
requires_design: false
status: done
owner_agent: claude-opus-4-8-programador-2026-06-01
created_at: 2026-05-29
updated_at: 2026-06-01
estimated_session_size: L
renamed_from: STORY-034 (EPIC-007 original; renomeada em 2026-05-31 por colisão com EPIC-001 STORY-034)
---

# STORY-038 — Adotar integration_test no WebApp e migrar cenários de RBAC/funnel

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

- [x] **CA-1:** `apps/webapp/pubspec.yaml` tem `integration_test` (SDK) em `dev_dependencies`. `flutter pub get` roda sem erro. `flutter pub deps` mostra `integration_test` resolvido.
- [x] **CA-2:** `apps/webapp/integration_test/helpers/` existe com `pump_app.dart`, `login_helper.dart`, `route_helper.dart`. Cada helper tem ao menos 1 docstring de uso. Convenções seguem IDR-011 (proposto nesta story).
- [x] **CA-3:** Keys padronizadas adicionadas nos widgets (`ValueKey('login:email')`, etc.). Convenção `<feature>:<element>` documentada em IDR-011. Widgets antigos sem Key continuam funcionando (zero regressão visual).

### Migração dos cenários

- [x] **CA-4:** Cenário "exibe campos e-mail, senha, link de recuperação e botão Entrar" (CA-5 da IDR-006/STORY-016) migrado para `integration_test/auth/login_structure_test.dart` e passa via `flutter test integration_test/auth/login_structure_test.dart -d chrome --headless`.
- [x] **CA-5:** Cenário "validação: submeter vazio exibe erro de campo obrigatório" migrado para `integration_test/auth/login_validation_test.dart` e passa.
- [x] **CA-6:** Cenário "credencial inválida não autentica — permanece em /login" migrado para `integration_test/auth/login_validation_test.dart` e passa.
- [x] **CA-7:** Cenário "profissional ativo loga e é roteado para /app" (CA-13b) migrado para `integration_test/auth/rbac_profissional_test.dart` e passa. Roda contra docker-compose + seed (mesmo modelo do Playwright atual).
- [x] **CA-8:** Cenário "admin não loga no WebApp — vê banner de redirecionamento" (CA-13c) migrado para `integration_test/auth/rbac_admin_rejected_test.dart` e passa.
- [x] **CA-9:** Cenários de funnel guard "/welcome sem auth → /login" e "/completar-cadastro sem auth → /login" (CA-10/CA-11) migrados para `integration_test/auth/funnel_guard_test.dart` e passam.
- [x] **CA-10:** `apps/webapp/tests/e2e/rbac-login.spec.ts` removido do repositório (todos os 7 cenários ficam cobertos por `integration_test`).

### Smoke Playwright preservado

- [x] **CA-11:** `apps/webapp/tests/e2e/webapp-hello-world.spec.ts` continua intocado (4 cenários, 1 `test.fixme` em `/health`).
- [x] **CA-12:** Novo cenário "deep link `/login` direto na URL não cai em WelcomeScreen" adicionado a `webapp-hello-world.spec.ts` — proteção contra regressão da IDR-006 §a. Passa contra `localhost:8003`.

### Gate

- [x] **CA-13:** `make e2e-webapp` roda (a) `webapp-build` (b) `flutter test integration_test -d chrome --headless` (c) `npx playwright test`, nesta ordem. Sai 0 quando todos passam. Sai não-zero ao primeiro fail.
- [x] **CA-14:** `make e2e-webapp-integration` e `make e2e-webapp-smoke` existem como targets isolados para iteração em dev. Documentados em comentário no Makefile.
- [x] **CA-15:** 5 execuções consecutivas locais de `make e2e-webapp` verdes, sem flake. Evidência (logs ou hash de relatórios) em "Notas do agente".
- [x] **CA-16:** Wall-time de `make e2e-webapp` documentado em "Notas do agente" e comparado ao baseline atual (~tempo do report 2026-05-29 01:27 UTC). Se aumentar, justificar; se aumentar >30%, escalar para PO.

### Decisões

- [x] **CA-17:** IDR-010 (modelo híbrido) escrita em `decisions/idr/IDR-010-e2e-hibrida-integration-test-playwright-patrol.md`, `status: proposed`. Inclui supersede parcial de IDR-006 §b.
- [x] **CA-18:** IDR-011 (padrão de teste Flutter) escrita em `decisions/idr/IDR-011-padrao-teste-flutter-keys-mocks-helpers.md`, `status: proposed`. Cobre Keys, mocks vs API real, helpers, naming.
- [x] **CA-19:** IDR-006 atualizada: header anota "§b parcialmente superseded por IDR-010 em 2026-XX-XX"; §b ganha nota inline. §a e §c intocados.

### Documentação

- [x] **CA-20:** `apps/webapp/README.md` tem seção "Testes E2E" com: o que cada ferramenta cobre, comandos (`make e2e-webapp*`), como rodar 1 cenário isolado, como debugar.

### Pendência herdada

- [x] **CA-21:** Nenhuma. EPIC-000 F-NB-1 (migrate:rollback) é responsabilidade da STORY-016, não desta.

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

- [x] CA-1 a CA-20 atendidos (CA-21 N/A).
- [x] `make e2e-webapp` verde 5x consecutivos local; logs/evidência em "Notas".
- [~] Cobertura unitária do WebApp ≥ 80% — **NÃO atingida (74%)**. **Não regredida** por esta story (enablement, zero lógica de produção nova — só renomeia Keys + adiciona testes; 97 widget tests verdes). Débito pré-existente. **PO aceitou na aprovação (2026-06-01) com ação separada para endereçar o gap** (ver "CAs — situação final" e Decisões).
- [x] IDR-010 e IDR-011 — superam o pedido: já `accepted` (não só `proposed`); IDR-006 anotada com supersede parcial de §b.
- [x] README do WebApp atualizado (seção "Testes E2E").
- [x] `tests/e2e/rbac-login.spec.ts` removido.
- [x] `index.json` atualizado: `status: done`.
- [x] Hooks de pré-push verdes em todos os pushes (workflow Turni: commit direto na main, sem PR — `feedback_git_workflow`).
- [x] "Notas do agente" preenchidas com decisões, bloqueios, comparativo de tempo.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Particular:

1. **Ao iniciar:** carregue `docs/skills/programador/SKILL.md`. Edite frontmatter desta estória (`status: in_progress`, `owner_agent: <seu id>`) e `index.json`. Confirme com PO se IDR-010/IDR-011 rascunhos cobrem o que você acha que precisa antes de codificar a suíte inteira — refatorar testes depois de escrever 7 deles é caro.
2. **Durante:** TaskList interna. TDD aplicado quando possível (escrever cenário de `integration_test` que falha, ajustar Keys, ver passar). Commits pequenos: scaffolding, helpers, 1 grupo de cenários por commit.
3. **Se travar:** `status: blocked`. Decisão de produto → PO. Decisão visual (alguma Key exigiu refator de tela) → Designer.
4. **Decisões transversais** vão em IDR. Esta story já prevê IDR-010 e IDR-011 — qualquer terceira IDR escala ao PO antes de escrever.
5. **Ao terminar:** confirme `make e2e-webapp` verde 5x, atualize "Notas", `status: in_review`, abra PR. Após merge + revisão das IDRs pelo PO + execução de validação do epic, `status: done`.

## Notas do agente (preenchido durante/após execução)

### Plano inicial (registrado antes de codar — 2026-06-01)

**Documentos lidos:** esta estória inteira; `epic.md` do EPIC-007; IDR-004, IDR-006 (header + §a/§b/§c),
IDR-009; **IDR-010 e IDR-011 (já `accepted` no repositório — ver Descobertas)**; `rbac-login.spec.ts`,
`webapp-hello-world.spec.ts`, `playwright.config.ts`; `test/login_screen_test.dart` (estilo Dart + Keys
referenciadas); `lib/features/auth/login_screen.dart`; `lib/router.dart`; `Makefile` targets `e2e*`/`_e2e-seed`;
`docs/skills/programador/SKILL.md`.

**Entendimento consolidado:** instalar o pé de `integration_test` no WebApp e migrar os 7 cenários de
RBAC/funnel do Playwright (`rbac-login.spec.ts`) para Dart nativo, rodando contra a stack real
(docker-compose + seed). Playwright fica reduzido a smoke HTTP. Gate `make e2e-webapp` passa a rodar
build → integration_test (Chrome headless) → smoke Playwright. As decisões transversais (IDR-010 modelo
híbrido, IDR-011 padrão de teste Flutter) **já foram aceitas pelo PO** em sessão dedicada (2026-06-01),
então não há gate de aprovação pendente — implemento seguindo IDR-011 à risca.

**Dúvidas:** nenhuma bloqueante. Pontos resolvidos localmente registrados em "Decisões tomadas".

**Plano (commits pequenos):**
1. Spike de toolchain: `integration_test` no `pubspec` + chromedriver + 1 teste trivial verde contra a stack
   viva (de-risca o Web antes de escrever os 7).
2. Keys `login:*` na LoginScreen (renomeia `input-email`→`login:email` etc.) + atualiza `login_screen_test.dart`.
3. Helpers `pump_app.dart`, `login_helper.dart`, `route_helper.dart` (IDR-011 §c).
4. Migração por grupo: `login_structure` → `login_validation` → `rbac_profissional` → `rbac_admin_rejected`
   → `funnel_guard` (+ navegação extra: root→/login e links criar-conta, ver Decisões).
5. Smoke Playwright: deep link `/login` em `webapp-hello-world.spec.ts`; remover `rbac-login.spec.ts`.
6. Makefile (`e2e-webapp`, `e2e-webapp-integration`, `e2e-webapp-smoke`) + README §"Testes E2E".
7. 5x `make e2e-webapp` verde + wall-time; finalizar Notas; `in_review`.

**Mapeamento CA → teste (planejado):**
- CA-4 (estrutura login) → `integration_test/auth/login_structure_test.dart` :: "exibe e-mail, senha, link recuperação, botão Entrar".
- CA-5 (validação vazio) → `auth/login_validation_test.dart` :: "submeter vazio → erro de campo obrigatório".
- CA-6 (credencial inválida) → `auth/login_validation_test.dart` :: "credencial inválida → permanece em /login".
- CA-7 (profissional ativo) → `auth/rbac_profissional_test.dart` :: "profissional ativo loga → sai de /login".
- CA-8 (admin rejeitado) → `auth/rbac_admin_rejected_test.dart` :: "admin → banner 'acessa o Backoffice' + fica em /login".
- CA-9 (funnel guard) → `auth/funnel_guard_test.dart` :: "/welcome sem auth → /login" e "/completar-cadastro sem auth → /login".
- Navegação extra (sem CA próprio, preserva cobertura) → `auth/funnel_guard_test.dart` ou `auth/navigation_test.dart` :: "root / sem auth → /login", "link criar conta profissional → /cadastro/profissional", "link criar conta estabelecimento → /cadastro/contratante".
- CA-12 (deep link smoke) → `tests/e2e/webapp-hello-world.spec.ts` :: "deep link /login direto na URL não cai em WelcomeScreen".

### Decisões tomadas
- **Frontmatter corrigido:** `story_id` estava `STORY-034` (resíduo da renomeação de 2026-05-31). Corrigido para
  `STORY-038` + H1; `status: in_progress`, `owner_agent`, `sprint_id: SPRINT-2026-W26`, `renamed_from` adicionado.
  Referências em prosa a "STORY-034/035/036" no corpo são do épico original e não bloqueiam — não reescritas.
- **Convenção de Keys (IDR-011 §a):** a LoginScreen é tocada por esta story, então migra para `login:*`
  (`input-email`→`login:email`, `input-password`→`login:password`, `btn-submit-login`→`login:submit`,
  `link-forgot-password`→`login:forgot-password`, banner de erro genérico ganha `login:error-banner`). Como Key é
  contrato (IDR-011 §a regra 4), atualizo todos os usos em `test/login_screen_test.dart` no mesmo commit.
- **Cenários extras do `rbac-login.spec.ts`:** além dos 7 listados, o arquivo tem um grupo "navegação"
  (root `/`→/login, links criar-conta, `/info`). Como CA-10 manda remover o arquivo inteiro, migro também
  root-redirect e os 2 links criar-conta para `integration_test` (navegação interna, tabela IDR-010) para não
  regredir cobertura (quality-standards §1.4). `/info` (load de rota pública) é candidato a smoke Playwright.

### Descobertas
- **IDR-010 e IDR-011 já existem e estão `accepted`** (`decided_at: 2026-06-01`, `decided_by: Alexandro`,
  `source_story: STORY-038`). O PO as aceitou ANTES da execução, em sessão dedicada ("regra 7 da SPRINT-2026-W26").
  Logo CA-17/CA-18 superam o exigido (a story pedia `proposed`; estão `accepted`). Não recriar.
- **IDR-006 já anotada (CA-19 parcial):** header tem `superseded_partial_by: IDR-010 (§b — desde 2026-06-01)`.
  Falta confirmar/garantir a nota inline na §b.
- **chromedriver ausente** no ambiente — pré-requisito para integration_test no Web. Resolvido no spike:
  brew instala 149 (≠ Chrome 148 → mismatch de major); baixei o chromedriver 148.0.7778.178 do Chrome for
  Testing (mac-arm64) e coloquei no PATH, de-quarentinado. Documentar no Makefile/README (pin de major do Chrome).
- **⚠️ Discrepância com a IDR-010 (aceita) sobre o comando de gate — escala leve ao PO:** a IDR-010 §a/§d
  especifica `flutter test integration_test -d chrome --headless`. **Esse comando não funciona:** o Flutter
  responde "Web devices are not supported for integration tests yet" e `--headless` não é flag de `flutter test`.
  O caminho suportado para Web é `flutter drive` + chromedriver:
  ```
  chromedriver --port=4444 &
  flutter drive --driver=test_driver/integration_test.dart \
    --target=integration_test/<arquivo>_test.dart \
    -d web-server --browser-name=chrome --headless
  ```
  **Spike validado**: rodou um teste trivial via esse comando → "All tests passed". O Makefile do CA-13 vai
  orquestrar exatamente assim (subir chromedriver → drive → derrubar). Implicação: `flutter drive` roda **um
  target por vez**; para a suíte inteira o Makefile fará loop sobre `integration_test/**/*_test.dart` OU usará
  um arquivo agregador. Proposta: anexar nota de correção à IDR-010 (comando real) — não muda a decisão, só a
  sintaxe. Decidir com PO se vira "Atualização" na IDR-010 ou nota na STORY.
- **Artefatos do spike commitados como scaffolding permanente:** `test_driver/integration_test.dart` (driver do
  Web, fica) + `integration_test/` (pasta criada). `integration_test/spike_test.dart` foi removido (cumpriu o papel).

- **Constraint de import no `flutter drive` Web:** o `org-dartlang-app:/` é enraizado no **diretório do
  `--target`**, e `..` não escapa dele. Um target em `integration_test/auth/login_structure_test.dart` que
  importa `../helpers/...` **não compila** ("File not found"). Solução validada: o `--target` é um **entrypoint
  agregador no topo** (`integration_test/auth_test.dart`) que encadeia os `main()` dos arquivos de `auth/`;
  com a raiz em `integration_test/`, os arquivos de `auth/` resolvem `../helpers/` normalmente. Os cenários
  continuam 1-por-arquivo em `auth/` (IDR-011 §d intacto); o agregador é só o ponto de entrada do drive no Web.
  Em Android/iOS o agregador é dispensável (`flutter test integration_test/auth -d <device>` roda a pasta).
- **Escopo do rename de Keys:** só a **LoginScreen** migrou para `login:*`. As keys `input-email`/`input-password`
  em `pre_cadastro_*` e `password_reset` são de **outras telas** (não tocadas) — ficam legadas (IDR-011 §a:
  sem refator retroativo obrigatório). Tive de corrigir `test/widget_test.dart` (testava `screen-login-webapp`
  e `btn-submit-login` do login) que eu havia esquecido — pegou na suíte completa.

### Progresso — Fatia 1 (2026-06-01): CA-1, CA-2, CA-3, CA-4 ✅

- **CA-1 ✅** — `integration_test` (SDK) em `dev_dependencies`; `flutter pub get` ok; `flutter pub deps` mostra resolvido.
- **CA-2 ✅** — `integration_test/helpers/` com `pump_app.dart`, `login_helper.dart`, `route_helper.dart`, cada um com
  docstring de uso. (`login_helper` será exercitado na fatia 2, junto dos cenários que batem na API.)
- **CA-3 ✅** — Keys `login:*` na LoginScreen (`login:email/password/submit/toggle-password/forgot-password/screen`,
  `login:create-professional`, `login:create-establishment`, banners `login:*-banner`). `test/login_screen_test.dart`
  e `test/widget_test.dart` atualizados. **Suíte completa de widget tests verde: 97/97.** `flutter analyze` limpo.
- **CA-4 ✅** — `integration_test/auth/login_structure_test.dart` passa via
  `flutter drive --driver=test_driver/integration_test.dart --target=integration_test/auth_test.dart -d web-server --browser-name=chrome --headless`
  → "All tests passed". (No Web o target é o agregador; o cenário vive em `auth/`.)

**Pré-requisito de ambiente documentado:** chromedriver com major casando o Chrome local, rodando em `:4444`
antes do `flutter drive`. Spike usou Chrome 148 + chromedriver 148.0.7778.178 (mac-arm64, baixado do Chrome for Testing
porque o brew traz só o 149). A automação disso (subir/derrubar chromedriver, pin de versão) entra no Makefile (CA-13/CA-14).

**Risco mapeado p/ fatia 2 (cenários que batem na API — CA-6/CA-7/CA-8):** `_apiBase` faz default a same-origin.
No `flutter drive -d web-server` o app é servido de `localhost:<porta-efêmera>`, **sem o proxy `/api`** do container `:8003`.
Vou precisar resolver base-URL (provável `--dart-define=API_BASE_URL=...`) + CORS + cookie Sanctum cross-origin, ou outra
estratégia. Spike dedicado no início da fatia 2 antes de migrar os cenários de login com rede.

### Progresso — Fatia 2 (2026-06-01): spike de API + CA-5..CA-9 ✅ (7 cenários migrados)

**Spike de base-URL da API — RESOLVIDO sem mudar código de produção nem desabilitar segurança do browser:**
- `/api/login` **não exige CSRF** (curl direto a `:8001/api/login` sem csrf-cookie → 200/403). Logo o cookie
  Sanctum não precisa persistir no browser do teste.
- **CORS está aberto**: `:8001` e `:8003` respondem `Access-Control-Allow-Origin: *` (e o preflight OPTIONS →
  204 com `Allow-Methods: POST`, `Allow-Headers: content-type`). Então o app servido na porta efêmera **lê** as
  respostas de login cross-origin.
- Como o desfecho dos cenários (redirect / banner) vem do **corpo da resposta**, não de um cookie persistido,
  basta rodar com `--dart-define=API_BASE_URL=http://localhost:8001`. Sem `--disable-web-security`, sem
  `withCredentials`, sem tocar `AuthService`. Esse dart-define entra no target `make e2e-webapp-integration`.
- Detalhe de timing: durante o login em voo o botão mostra `CircularProgressIndicator` (animação contínua) →
  `pumpAndSettle()` nunca quiesce. Helpers novos: `awaitRouteLeaves` e `pumpUntilFound` (pump curto até a
  condição), em vez de pumpAndSettle pós-submit. `loginAs` termina com um único `pump()` e devolve o controle.

**Cenários migrados e verdes (via `flutter drive ... --dart-define=API_BASE_URL=http://localhost:8001`):**
- **CA-5 ✅** `auth/login_validation_test.dart` — submeter vazio → "Este campo é obrigatório." (client-side).
- **CA-6 ✅** `auth/login_validation_test.dart` — credencial inexistente → banner `login:error-banner` + fica em /login.
- **CA-7 ✅** `auth/rbac_profissional_test.dart` — `profissional.teste@turni.local` loga → sai de /login (`awaitRouteLeaves`).
- **CA-8 ✅** `auth/rbac_admin_rejected_test.dart` — `admin@turni.local` → 403 → banner `login:admin-banner`
  ("Este usuário acessa o Backoffice.") + fica em /login.
- **CA-9 ✅** `auth/funnel_guard_test.dart` — root `/`, `/welcome`, `/completar-cadastro` sem sessão → /login.
- **Navegação (preserva cobertura, sem CA próprio) ✅** `auth/navigation_test.dart` — links criar-conta →
  `/cadastro/profissional` e `/cadastro/contratante` (telas fazem fetch ao montar; passam com o dart-define).

Suíte completa de integração verde no Web (`integration_test/auth_test.dart`) → "All tests passed". `flutter analyze`
limpo. Widget suite continua 97/97. **Falta** (fatia 3): remover `rbac-login.spec.ts` (CA-10), deep-link no smoke
Playwright (CA-12), Makefile (CA-13/14), nota inline IDR-006 §b (CA-19), README (CA-20), 5x verde + wall-time (CA-15/16),
cobertura ≥80%.

### Progresso — Fatia 3 (2026-06-01): Makefile + smoke + remoção + README

- **CA-10 ✅** — `tests/e2e/rbac-login.spec.ts` removido (`git rm`).
- **CA-11 ✅** — `webapp-hello-world.spec.ts` intocado nos 4 cenários + 1 fixme.
- **CA-12 ✅** — cenário "deep link /login direto na URL permanece em /login" adicionado ao
  `webapp-hello-world.spec.ts`; **passa** contra :8003 (verificado 2x).
- **CA-13 ✅** — `make e2e-webapp`: `webapp-build` → `_e2e-seed` → `e2e-webapp-integration` (flutter drive +
  chromedriver, --dart-define API) → `e2e-webapp-smoke` (Playwright). Sai !=0 no 1º fail.
- **CA-14 ✅** — `make e2e-webapp-integration` e `make e2e-webapp-smoke` como targets isolados, documentados
  em comentário no Makefile. `CHROMEDRIVER_PORT` parametrizável.
- **CA-19 ✅** — IDR-006 §b já tinha a nota inline de supersede parcial (header + §b), aplicada na sessão do PO.
- **CA-20 ✅** — README do WebApp ganhou seção "Testes E2E" (tabela de camadas, comandos, pré-requisito
  chromedriver, como rodar 1 cenário/debugar, ponteiros para IDR-010/011).

### Bloqueio — CA-15/CA-16 (5x verde + wall-time): flake pré-existente no Playwright [ESCALONAMENTO-PO]

`make e2e-webapp` **completa a fase de integration_test verde** e o smoke do `webapp-hello-world` (incl. meu
deep-link CA-12) passa. Mas o `npx playwright test` roda **todo** `tests/e2e/`, que inclui specs de UICanvasKit
**fora do escopo desta story** — `pre-cadastro-contratante.spec.ts`, `welcome.spec.ts` (e `pre-cadastro`,
`app-update`) — que usam o truque de semantics da IDR-006 §b e são **flaky**:
- run 1: 1 falha (`pre-cadastro-contratante` em `field.focus()`).
- run 2: 2 falhas (`pre-cadastro-contratante` + `welcome` em `toHaveURL` pós-login).
- Intermitente, no `field.focus()`/digitação em `<input>` de semantics — a exata fragilidade que o EPIC-007 quer
  matar. **Não os toquei** (a story migra só os 7 de rbac/funnel). Wall-time de `make e2e-webapp`: ~3m35s.

Não dá para alegar CA-15 (5x verde) com flake na suíte (disciplina: proibido marcar done com teste flaky).
**Decisão de escopo do PO necessária** — opções levadas ao Alexandro:
1. **(recomendada)** `e2e-webapp-smoke` roda só o smoke HTTP (`webapp-hello-world.spec.ts`), alinhado à IDR-010
   ("Playwright reduzido a smoke HTTP ≈5 cenários"). Os specs de UI flaky (pre-cadastro/welcome/app-update) saem
   do gate e migram para integration_test nas suas próprias stories (STORY-017/018/022). Cobertura desses fluxos
   continua em widget tests; E2E-real deles fica pendente da migração. Mantê-los num target não-gating opcional.
2. Migrar pre-cadastro/welcome/app-update para integration_test agora (expande escopo da STORY-038 — grande).
3. Aceitar como bug de flake pré-existente, registrar story de bug, e CA-15 fica pendente até estabilizar.

Aguardando decisão antes de fechar CA-15/16 e marcar `in_review`.

### Resolução do bloqueio CA-15/16 (decisão do PO — 2026-06-01)

PO optou pela **solução de raiz** como direção, com gate determinístico agora:
- **Gate smoke-only** (CA-15/16): `e2e-webapp-smoke` roda **só** `webapp-hello-world.spec.ts` (smoke HTTP
  determinístico). Specs de UI legados flaky (`pre-cadastro`, `pre-cadastro-contratante`, `welcome`, `app-update`)
  saíram do gate para `make e2e-webapp-playwright-legacy` (não-gating), até migrarem.
- **image_picker (muro 2):** PO decidiu **não** mockar; o happy-path de cadastro com foto foi **desativado**
  (`test.fixme` com justificativa) em ambos os `pre-cadastro*` — recolocado na story de enabling com a ferramenta
  certa (Patrol/IDR-009).
- **Harness same-origin (muro 1):** migrar fluxos com chamada autenticada pós-login (welcome → `welcome-visto`,
  e toda STORY-022+) e os `pre-cadastro` exige um harness same-origin sob `flutter drive` (reverse-proxy +
  `--use-existing-app`, ou `withCredentials` + CORS/Sanctum em dev). **Recomendado: story de enabling dedicada**
  (toca IDR-014/009; maior que STORY-038). A abordagem cross-origin desta story cobre só o que se decide pela
  **resposta do login** (CA-6/7/8), não chamadas autenticadas subsequentes.

### Progresso — Fatia 3 concluída (2026-06-01): CA-15/16 ✅ — gate determinístico

- **CA-15 ✅** — `make e2e-webapp` rodado **5x consecutivos: PASS, PASS, PASS, PASS, PASS** (zero flake).
  integration_test "All tests passed" nas 5; smoke "4 passed (~8.7s)" nas 5.
- **CA-16 ✅** — wall-time por run: 50s, 51s, 50s, 48s, 47s (média **~49s**). Baseline anterior do gate (Playwright
  rodando todos os specs) ~**3m35s** com flake → **redução grande** (~4x mais rápido) e determinístico. Ganho vem de:
  (a) integration_test rápido/determinístico no lugar da interação via semantics; (b) smoke reduzido ao HTTP.

**Cobertura (DoD):** `flutter test --coverage` → **74,0% (1150/1555 linhas)**, **abaixo do piso de 80%**.
**Não é regressão da STORY-038** — esta story não adiciona lógica de produção (só renomeia strings de Key e adiciona
testes; os 97 widget tests seguem verdes). É débito **pré-existente** (provável código web-interop de stories anteriores
sem cobertura). **[SINALIZAÇÃO-PO]** decidir se o piso de 80% bloqueia esta enablement ou vira ação separada.

### CAs — situação final

CA-1..CA-9 ✅ · CA-10 ✅ · CA-11 ✅ · CA-12 ✅ · CA-13 ✅ (smoke escopado a hello-world por decisão do PO/IDR-010)
· CA-14 ✅ · CA-15 ✅ · CA-16 ✅ · CA-17/18 ✅ (IDRs já accepted) · CA-19 ✅ · CA-20 ✅ · CA-21 N/A.
**Todos os CAs da STORY-038 atendidos.** Pendências fora dos CAs desta story: migração de welcome/pre-cadastro/
app-update (story de enabling do harness) e cobertura pré-existente <80% (sinalização ao PO).

### Aprovação do PO — 2026-06-01

PO (Alexandro) **aprovou** a STORY-038: `in_review` → `done`. Todos os CA-1..CA-20 `[x]` (CA-21 N/A).

- **Cobertura 74% (<80%):** aceita com justificativa — esta é uma story de **enablement** que não adiciona lógica
  de produção (só renomeia strings de Key + adiciona testes); a cobertura **não regrediu**. O gap de 80% é débito
  pré-existente e será endereçado em **ação separada** (não bloqueia esta story).
- **Solução de raiz para a área logada:** o muro descoberto (chamadas autenticadas pós-login exigem harness
  same-origin) foi promovido a **STORY-043** (criada e incluída na SPRINT-2026-W26), com o Caminho 1 já provado
  por spike. A migração de welcome/pre-cadastro/app-update acontece lá.
- **Specs Playwright legados flaky** seguem em `make e2e-webapp-playwright-legacy` (não-gating) até a STORY-043 migrá-los.

EPIC-007 avança: STORY-038 `done`, IDR-010/011 `accepted`, IDR-006 §b anotada. Faltam STORY-039 (Patrol),
STORY-040 (gate mobile) e STORY-043 (harness same-origin) para fechar o épico.

### Bloqueios encontrados
- **Resolvidos/encaminhados:** CA-15/16 (decisão do PO acima); sintaxe IDR-010 (corrigida na própria IDR);
  base-URL da API (resolvida na fatia 2). **Sinalização ao PO:** cobertura pré-existente 74% (<80%).

### IDRs criados
- IDR-010 (proposto nesta story).
- IDR-011 (proposto nesta story).

### Cobertura final
- E2E `integration_test`: 7 cenários migrados (CA-4 a CA-9).
- Smoke Playwright: 4 cenários (3 ativos + 1 fixme) + 1 novo (deep link).
- _Wall-time comparado: a preencher._

### Links de evidência
- _PR, commits, evidência das 5 execuções verdes: a preencher._
