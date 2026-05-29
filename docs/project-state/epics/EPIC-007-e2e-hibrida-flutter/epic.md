---
epic_id: EPIC-007
slug: e2e-hibrida-flutter
title: E2E híbrida do WebApp — integration_test (UI) + Playwright (smoke HTTP) + Patrol (nativo)
wave: WAVE-2026-01
status: draft
owner_role: po
created_at: 2026-05-29
updated_at: 2026-05-29
target_completion: 2026-08-15  # estimativa orientativa — sem sprint alvo
---

# EPIC-007 — E2E híbrida do WebApp Flutter

## Por que existimos (problema do time)

Hoje o E2E do WebApp é 100% Playwright. Funciona, mas depende de um truque registrado em IDR-006 §b: ativar o `flt-semantics-placeholder` do CanvasKit, digitar com `keyboard.type()` real para sincronizar com `TextEditingController`, e rodar com `workers: 1` porque CanvasKit paralelo briga por CPU. É testável, mas frágil — o padrão existe porque não havia ferramenta nativa Flutter quando a STORY-016 fechou.

Agora dois fatos mudam o contexto:

1. **O WebApp vai virar nativo** (Android e iOS estão no roadmap, decisão do PO em 2026-05-29). Playwright não roda em Android nem iOS — ele só testa browser. Cada cenário que continuar sendo escrito em Playwright vai precisar ser reescrito quando o native chegar, ou perderá cobertura nos novos alvos.
2. **`integration_test` existe e é a ferramenta nativa do Flutter para isso** — acessa a árvore de widgets direto, sem semantics, com `pumpAndSettle()` determinístico. O mesmo arquivo Dart roda em Web, Android e iOS. Para os fluxos de UI que `integration_test` não alcança (diálogos do SO, deep link externo, push, biometria, image_picker no native), existe **Patrol**, que estende `integration_test` com automação nativa de UIAutomator/XCUITest.

Este épico não entrega valor direto a profissional nem contratante. Entrega ao **time**: testes determinísticos, prontos para mobile, e um padrão claro do que escrever em qual ferramenta a partir da STORY-022+.

## Resultado esperado (outcome)

Ao fim deste épico, o WebApp tem um modelo de E2E híbrido em vigor:

- **`integration_test`** cobre a interação com a UI Flutter (login, RBAC, funnel, futuros fluxos de cadastro/agenda/perfil), com o mesmo código rodando em Web, Android e iOS.
- **Playwright** fica reduzido a smoke HTTP do build deployado: raiz com título, `/version.json`, `/health` (homolog), erros de console, deep link via URL real do browser. É a única camada que testa o produto servido pelo Firebase Hosting de verdade.
- **Patrol** está adotado e pronto para cobrir cenários nativos quando precisar — permission dialogs, deep link externo (universal/app links), image_picker no native (IDR-009), push notifications, biometria. No fim do épico há ao menos 1 cenário Patrol funcionando localmente como prova de conceito.
- **IDR-010** registra o modelo híbrido (quem cobre o quê), supersede parcial de IDR-006 §b, refina IDR-004.
- **IDR-011** documenta o padrão de teste Flutter que toda STORY-022+ deve seguir (Keys, mocks vs API real, helpers compartilhados, naming).

A IDR-006 §a (path strategy) e §c (build fresco no gate) continuam vigentes. Apenas §b (Playwright/semantics como padrão de interação) é parcialmente superseded — fica histórico para os 2 cenários de smoke que continuarem em Playwright.

## Métrica de sucesso (como saberemos que funcionou)

- **Primária — paridade de cobertura sem regressão:** os 7 cenários de RBAC/funnel hoje em Playwright (`tests/e2e/rbac-login.spec.ts`) estão reescritos em `integration_test` e passam 100% em Chrome headless. `make e2e-webapp` continua verde, sem o truque de semantics.
- **Determinismo:** após 5 execuções consecutivas locais do `make e2e-webapp`, 0 flakes. Hoje a suíte está verde, mas o padrão de semantics + `waitForTimeout` é flake-suspeito sob carga — o ganho qualitativo é mensurável.
- **Tempo de gate:** wall-time de `make e2e-webapp` ≤ tempo atual (~tempo do report 2026-05-29 01:27 UTC). Se passar, justificar.
- **Decisões registradas:** IDR-010 e IDR-011 em `status: accepted`, aprovadas pelo PO. IDR-006 atualizada marcando §b como parcialmente superseded.
- **Patrol vivo:** ao menos 1 cenário Patrol roda em Android emulator local com sucesso (smoke do framework — não precisa ser cenário de produto).
- **Pronto para mobile:** quando a primeira story do native chegar, o esforço de cobertura E2E é "adicionar target Android/iOS aos integration_test existentes", não "reescrever a suíte".

## Entregável visível no fim do épico

- [ ] `apps/webapp/integration_test/` contém os 7 cenários de RBAC/funnel reescritos, mais helpers compartilhados (`pumpApp`, `loginAs`, `assertOnRoute`).
- [ ] `apps/webapp/tests/e2e/` reduzido a smoke HTTP (raiz, `/version.json`, `/health` homolog-only, console limpo, deep link `/login`).
- [ ] `make e2e-webapp` orquestra integration_test (Chrome headless) + smoke Playwright. Roda verde 5x consecutivos sem flake.
- [ ] `apps/webapp/pubspec.yaml` tem `integration_test` e `patrol` em `dev_dependencies`.
- [ ] Cenário Patrol de smoke (1 cenário; sugestão: permissão de notificação ou `image_picker` abrindo sheet do SO) roda em Android emulator local via `make e2e-webapp-patrol-android`.
- [ ] IDR-010 e IDR-011 em `decisions/idr/`, aceitas pelo PO.
- [ ] IDR-006 atualizada (header anotando supersede parcial de §b por IDR-010).
- [ ] README do WebApp (`apps/webapp/README.md`) tem seção "Testes E2E" descrevendo o modelo híbrido e quando usar cada ferramenta.

## Fora de escopo (explicitamente)

- **Migrar Backoffice de Playwright** — o admin é HTML server-rendered, Playwright continua sendo a ferramenta certa. Não tocar.
- **Suíte E2E rodando em CI** — gate continua **local** (IDR-004). Se a decisão mudar (suite ficar lenta demais, gate virar argumento de qualidade pré-tag inconsistente), abrir IDR separada — não nesta onda.
- **Firebase Test Lab / BrowserStack** — fora do MVP. Decisão fica para quando STORY-XXX (primeira release mobile) chegar.
- **Reescrever cenários que ainda não existem** — só os 7 do `rbac-login.spec.ts` migram nesta onda. Cenários futuros (STORY-017/018/019/020/022+) já nascem em `integration_test` seguindo IDR-011.
- **Patrol Web** — está experimental, fora do escopo. Smoke do Web continua em Playwright.
- **Cenários Patrol "de produto"** — esta onda entrega o framework + 1 cenário de smoke. Cobertura nativa real (image_picker em IDR-009, deep link via e-mail de recuperação, push) entra com as stories que as exigem.

## Referências da especificação

- `docs/project-state/decisions/idr/IDR-004-e2e-local-pipeline-smoke-curl.md` — gate local pré-tag, refinado por este épico.
- `docs/project-state/decisions/idr/IDR-006-flutter-web-path-strategy-e-e2e-via-semantics.md` — §a/§c mantidos; §b parcialmente superseded por IDR-010.
- `docs/project-state/decisions/idr/IDR-009-image-picker-para-upload-de-foto.md` — `filechooser` no Web (Playwright cobre), sheet do SO no native (Patrol cobrirá).
- `docs/skills/po/references/quality-standards.md` §1.2 — E2E em browser/device real continua obrigatório.
- `apps/webapp/playwright.config.ts`, `apps/webapp/tests/e2e/` — estado atual a migrar.
- `apps/webapp/test/` — widget tests existentes (`login_screen_test.dart`, etc.) — referência de estilo Dart.

## Dependências

- **Bloqueia**: nenhuma story do EPIC-001 atual (cobertura existente continua via Playwright até a migração completar). Bloqueia a estratégia de teste das stories STORY-022+ que ainda não foram escritas — quanto antes IDR-011 estiver de pé, menos retrabalho.
- **Bloqueado por**: aprovação do PO no escopo deste épico e nas duas IDRs.
- **Decisões transversais necessárias** (cada uma vira IDR):
  - **IDR-010** — Modelo E2E híbrido: integration_test (UI Flutter) + Playwright (smoke HTTP) + Patrol (nativo).
  - **IDR-011** — Padrão de teste Flutter: Keys, mocks vs API real, helpers compartilhados, naming.

## Estórias

> Stories são placeholders detalhados; ficam em `status: draft` aguardando aprovação do PO antes de irem para `ready` e serem puxadas para uma sprint. Sequência sugerida: STORY-034 entrega o miolo (integration_test no Web); STORY-035 e STORY-036 são parcialmente paralelizáveis e dependem só do scaffolding entregue por STORY-034.

- [ ] **STORY-034** — Adotar `integration_test` no WebApp Flutter Web e migrar os 7 cenários de RBAC/funnel
  - `type: enablement`, `target_role: programador`, `status: draft`
  - Path: `stories/STORY-034-adotar-integration-test-no-webapp.md`
  - Entregável: 7 cenários reescritos em `integration_test`, Playwright reduzido a smoke HTTP, `make e2e-webapp` verde, IDR-010 e IDR-011 propostos. Sem bloqueio.

- [ ] **STORY-035** — Adotar Patrol para cenários nativos (smoke do framework)
  - `type: enablement`, `target_role: programador`, `status: draft`
  - Path: `stories/STORY-035-adotar-patrol-cenarios-nativos.md`
  - Entregável: dependência `patrol` + `patrol_cli` instalados, Android e iOS configurados, 1 cenário de smoke rodando em emulator local. Bloqueada por STORY-034 (precisa do scaffolding de `integration_test` e do IDR-010 aceito).

- [ ] **STORY-036** — Gate E2E mobile local (Android emulator + iOS simulator)
  - `type: enablement`, `target_role: programador`, `status: draft`
  - Path: `stories/STORY-036-gate-e2e-mobile-android-ios.md`
  - Entregável: targets no Makefile (`make e2e-webapp-android`, `make e2e-webapp-ios`), runbook de setup local, política documentada (gate mobile opcional no MVP; obrigatório quando 1ª release mobile chegar). Bloqueada por STORY-034 e STORY-035.

## Validação final

Critérios em `validation/checklist.md` (a escrever junto com o detalhamento das stories quando o PO aprovar). Relatório do validador em `validation/report.md`.

**Definição de épico concluído**: STORY-034/035/036 em `done` + IDR-010 e IDR-011 aceitas + IDR-006 atualizada com nota de supersede parcial de §b + 5 execuções consecutivas verdes de `make e2e-webapp` + 1 cenário Patrol verde em Android emulator local + relatório de validação `approved`.

## Histórico

- 2026-05-29 — Criado por PO (Alexandro / Claude) após análise do estado dos E2E e decisão de adotar modelo híbrido em preparação para a migração do WebApp para nativo (Android/iOS).
