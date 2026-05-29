---
id: IDR-010
title: E2E híbrida do WebApp — integration_test (UI), Playwright (smoke HTTP), Patrol (nativo)
status: proposed
decided_at: null
decided_by: null
source_story: STORY-034
supersedes_partial: IDR-006 §b
refines: IDR-004
superseded_by: nada
---

# IDR-010 — Modelo E2E híbrido do WebApp Flutter

## Contexto

A IDR-006 §b (2026-05-28) definiu o padrão de E2E do WebApp como Playwright contra Flutter Web/CanvasKit usando o truque de ativar `flt-semantics-placeholder` e digitar com `keyboard.type()` real. Esse padrão funciona — última execução em 2026-05-29 01:27 UTC: 10/10 passed, 0 flaky. Mas é contorno, não solução: existe porque (i) não havia ferramenta nativa Flutter para E2E quando STORY-016 fechou e (ii) o time não tinha alternativa avaliada.

Dois fatos mudam o contexto:

1. **`integration_test` é a ferramenta nativa do Flutter para isso.** Acessa a árvore de widgets direto, sem semantics. Usa `pumpAndSettle()` (determinístico) em vez de `waitForTimeout` fixo. O mesmo arquivo Dart roda em Web, Android e iOS.
2. **O WebApp vai virar nativo** (Android e iOS estão no roadmap, decisão do PO em 2026-05-29). Playwright é browser-only — quando o native chegar, cada cenário Playwright vira retrabalho ou cobertura perdida.

Além disso, `integration_test` não cobre o lado nativo do SO (diálogos de permissão, deep links externos, sheets de file picker, push, biometria). Para isso existe **Patrol** (LeanCode), que estende `integration_test` rodando UIAutomator/XCUITest em paralelo. IDR-009 (image_picker) já antecipou um caso real: `filechooser` cobre o Web (Playwright pega), mas o sheet nativo do SO no Android/iOS não é tocável por `integration_test` puro — Patrol é.

Por outro lado, `integration_test` **não substitui** Playwright para cenários HTTP/hosting: `/version.json`, `/health` (homolog), título da raiz, erros de console JS, deep links via URL real do browser são coisas que vivem fora do app Flutter — Playwright continua sendo a ferramenta certa para esse smoke.

## Decisão

Adotar **modelo E2E híbrido** com três camadas, cada uma cobrindo sua responsabilidade:

### a) integration_test (UI Flutter)

Cobre **interação com a UI** do WebApp: navegação interna via go_router, formulários, validações, RBAC, funnel guards, estados de loading/erro, futuros fluxos de cadastro/agenda/perfil/etc. (STORY-022+).

Roda contra:

- **Web** (Chrome headless) — `flutter test integration_test -d chrome --headless`. Faz parte do gate `make e2e-webapp`.
- **Android emulator** e **iOS simulator** — `flutter test integration_test -d <device>`. Gate opcional no MVP; obrigatório a partir da 1ª release mobile (ver "Política de gate mobile" abaixo).

Padrão técnico em IDR-011 (Keys namespaced, helpers compartilhados, API real via docker-compose + seed).

### b) Playwright (smoke HTTP do build deployado)

Cobre o **produto servido pelo Firebase Hosting / servidor de dev**: status code da raiz, título, `/version.json`, `/health` ADR-008 (homolog-only), erros de console JS, deep link via URL real do browser (proteção da IDR-006 §a — path strategy).

Não cobre interação com widgets — interação migra para `integration_test`. Smoke fica enxuto (≈ 5 cenários).

Roda contra:

- **localhost:8003** (dev local via docker-compose) — gate `make e2e-webapp`.
- **homolog** (debug manual) — `BASE_URL=https://app.homolog.turni.com.br npx playwright test`.

### c) Patrol (cenários nativos)

Cobre cenários que envolvem o **lado nativo do SO**, fora da árvore de widgets Flutter:

- Diálogos de permissão (câmera, notificação, localização).
- Sheets nativos de file/image picker (caso da IDR-009).
- Deep links e universal/app links chegando de fora do app.
- Push notifications.
- Biometria (Face ID/Touch ID/fingerprint).

Roda contra Android emulator e iOS simulator via `patrol_cli`. **Fora** do gate `make e2e-webapp` (que continua leve para pré-tag local). Roda sob demanda em `make e2e-webapp-patrol-android` / `make e2e-webapp-patrol-ios`.

### d) Gate `make e2e-webapp` (pré-tag local, IDR-004)

A partir desta decisão, `make e2e-webapp` executa **em sequência**:

1. `webapp-build` (mantém IDR-006 §c — build fresco).
2. `flutter test integration_test -d chrome --headless` (camada a).
3. `npx playwright test` (camada b, smoke HTTP enxuto).

Sai 0 quando todos passam. Sai não-zero no primeiro fail. Patrol e gate mobile (Android/iOS) ficam fora deste comando.

### e) Política de gate mobile

- **MVP / pré-1ª release mobile:** `make e2e-webapp-android` e `make e2e-webapp-ios` são **opcionais**. Recomendado quando o dev tocar em código mobile-sensível (plugin nativo, viewport mobile específico, deep link, file picker).
- **A partir da 1ª release mobile** (gatilho objetivo: primeira tag `mobile-rc.N` gerada no pipeline, a definir): `make e2e-webapp-android` passa a ser **pré-condição local** antes de tag mobile-rc. iOS condicional à disponibilidade de macOS no ambiente local.
- **CI:** continua fora (IDR-004 vigente). Decisão sobre mobile em CI / Firebase Test Lab fica para IDR separada quando custo de manter gate local virar argumento.

## Consequências

- **IDR-006 §b parcialmente superseded.** O padrão Playwright/semantics fica histórico para os cenários que continuarem em Playwright (smoke HTTP). Cenários novos de interação não nascem mais em Playwright. STORY-034 marca §b com nota inline.
- **IDR-006 §a (path strategy) e §c (build fresco) intocados.** `usePathUrlStrategy()` continua obrigatório; `webapp-build` antes de `e2e-webapp` continua.
- **IDR-004 refinada.** Gate continua local e pré-tag. O conteúdo do gate muda (integration_test + smoke Playwright em vez de só Playwright completo). Smoke curl pós-deploy continua igual.
- **IDR-009 ganha caminho de cobertura nativa.** No native, o sheet do SO do `image_picker` é testável via Patrol — não fica como buraco de cobertura.
- **Patrol vira dependência do projeto.** STORY-035 instala. Adiciona configuração Android (gradle, runner) e iOS (Podfile, test target). Custo de manutenção real, justificado pela ausência de alternativa para cenários nativos.
- **Tempo de gate** pode aumentar. STORY-034 mede e compara. Se passar de +30%, escalar antes de aceitar.
- **Padrão registrado para STORY-022+.** Novos fluxos do WebApp (cadastro, agenda, perfil, etc.) nascem em `integration_test` seguindo IDR-011. Reduz dívida de reescrita quando native chegar.

## Tabela de decisão rápida

| Cenário | Ferramenta |
|---|---|
| Login, formulário, validação, RBAC, funnel, navegação interna | integration_test |
| Estado interno do app (loading/erro/sucesso), interação com widgets | integration_test |
| Título da raiz, status code, `/version.json`, `/health` (homolog) | Playwright |
| Erros de console JS no Web | Playwright |
| Deep link via URL real do browser (proteção IDR-006 §a) | Playwright |
| Diálogo de permissão do SO (câmera, notificação) | Patrol |
| Sheet nativo de file/image picker (IDR-009 no native) | Patrol |
| Deep link externo (universal/app link via e-mail/SMS) | Patrol |
| Push notification recebida e tocada | Patrol |
| Biometria | Patrol |

## Nota de processo

A IDR-006 §b foi a decisão certa para o momento dela — `integration_test` não tinha sido avaliado, Patrol não tinha sido nomeado, native ainda não estava no roadmap. Esta IDR não corrige um erro; ela reconhece que o contexto mudou (decisão de virar nativo + maturidade de ferramentas) e ajusta o desenho. O padrão antigo continua válido para o subconjunto residual (smoke HTTP).

## Atualização — quando esta decisão for aceita

- Atualizar header de IDR-006 com nota inline em §b: "parcialmente superseded por IDR-010 a partir de <data>".
- Atualizar IDR-004 com nota refinando o conteúdo do gate (não a política).
- IDR-011 entra em paralelo com esta para fechar o padrão de teste Flutter.
