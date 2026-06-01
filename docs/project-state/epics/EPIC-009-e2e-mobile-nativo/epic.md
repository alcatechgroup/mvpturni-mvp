---
epic_id: EPIC-009
slug: e2e-mobile-nativo
title: E2E mobile nativo — Patrol + gate Android/iOS para o WebApp Flutter
wave: WAVE-2026-01
status: backlog
owner_role: po
created_at: 2026-06-01
updated_at: 2026-06-01
target_completion: null  # sem sprint alvo — reativar quando 1ª release mobile entrar no roadmap
spun_out_from: EPIC-007
activation_trigger: "1ª release mobile (Android/iOS) entrar no roadmap do produto. Enquanto o MVP for Web-only, este épico fica em backlog."
---

# EPIC-009 — E2E mobile nativo (Patrol + gate Android/iOS)

> **Backlog — não puxar para sprint sem decisão de PO.** Criado em 2026-06-01 ao re-escopar o **EPIC-007** para Web-only: como o MVP **não terá mobile**, a camada de E2E nativa (Patrol + gate Android/iOS) foi separada para cá. Reativa quando a 1ª release mobile entrar no roadmap.

## Por que existimos (problema do time)

O EPIC-007 entregou o modelo E2E híbrido **na parte Web**: `integration_test` cobre a UI Flutter rodando em Chrome headless (same-origin, área logada inclusa — STORY-038/043), Playwright cobre smoke HTTP do build deployado. Faltou — de propósito — a camada que só faz sentido **quando o app virar nativo**:

- **Patrol** para cenários que vivem **fora da árvore de widgets Flutter**: diálogos de permissão do SO (câmera, notificação, localização), sheets nativos de `image_picker` (IDR-009: no Web vira `filechooser`, no native vira sheet do SO), deep links externos (link de recuperação de senha no e-mail), push notifications, biometria (Face ID / Touch ID / fingerprint).
- **Gate E2E mobile local**: rodar os mesmos `integration_test` da STORY-038 em **Android emulator** e **iOS simulator**, com runbook de setup e política de obrigatoriedade.

`integration_test` puro trava nos cenários de SO — não toca um diálogo nativo. Patrol resolve rodando UIAutomator (Android) / XCUITest (iOS) em paralelo. A decisão de framework **já está tomada** (IDR-010, via STORY-038) — este épico é execução, não escolha.

## Pré-requisito de base ainda não existente

⚠️ Descoberto em 2026-06-01: `apps/webapp/` é **Web-only** — não tem `android/` nem `ios/` (o `.metadata` lista só `root` e `web`). A 1ª story deste épico precisa gerar o scaffolding nativo (`flutter create --org br.com.turni --platforms=android,ios .`) antes de qualquer config de Patrol. Isso **não** é trivial de manter: implica versionar `android/`+`ios/`, decidir `applicationId`/bundle id, signing, minSdk/targetSdk, Podfile — superfície que o MVP Web não carrega hoje. Tratar como item próprio de setup, não como parte "de graça" da config do Patrol.

## Resultado esperado (outcome)

Quando este épico fechar:

- `apps/webapp/{android,ios}/` versionados e com `flutter build apk --debug` / `flutter build ios --debug --no-codesign` verdes.
- `patrol` em `dev_dependencies`, `patrol_cli` documentado, ≥1 cenário de smoke Patrol verde em Android emulator local.
- `make e2e-webapp-android` / `make e2e-webapp-ios` rodando os `integration_test` existentes em emulador/simulador; `make e2e-webapp-patrol-android` / `-ios` para os cenários Patrol.
- Patrol e o gate mobile **fora** do `make e2e-webapp` (gate Web pré-tag continua leve — IDR-004/IDR-010); rodam sob demanda.
- Runbook de setup mobile (`docs/operacao/`) e política de obrigatoriedade documentados.

## Métrica de sucesso

- ≥1 cenário Patrol verde 3x consecutivos em Android emulator local.
- 7 cenários `integration_test` da STORY-038 verdes em Android emulator (paridade Web↔mobile).
- Build Android (e iOS em macOS) sem regressão.

## Fora de escopo

- Cobertura nativa **de produto** real (image_picker no fluxo de foto — IDR-009, deep link via e-mail, push, biometria) — cada uma nasce com a story de produto que a exige; aqui só smoke do framework.
- Suíte mobile em CI / Firebase Test Lab / BrowserStack — fica para IDR futura quando o gate mobile virar argumento.
- Patrol Web (experimental) — Web continua em Playwright + `integration_test` (EPIC-007).

## Estórias

> Transferidas do EPIC-007 em 2026-06-01 (re-escopo Web-only). Mantêm IDs **STORY-039** e **STORY-040** (sem renúmero — só troca de épico).

- [ ] **STORY-039** — Adotar Patrol para cenários nativos — scaffolding + 1 cenário de smoke
  - `type: enablement`, `target_role: programador`, `status: backlog`
  - Path: `stories/STORY-039-adotar-patrol-cenarios-nativos.md`
  - Pré-requisito adicional descoberto: gerar `android/`+`ios/` antes da config Patrol (projeto era Web-only).

- [ ] **STORY-040** — Gate E2E mobile local (Android emulator + iOS simulator, runbook e política)
  - `type: enablement`, `target_role: programador`, `status: backlog`
  - Path: `stories/STORY-040-gate-e2e-mobile-android-ios.md`
  - Bloqueada por STORY-039.

## Referências

- `docs/project-state/decisions/idr/IDR-010-e2e-hibrida-integration-test-playwright-patrol.md` — modelo híbrido; escopo do Patrol já decidido.
- `docs/project-state/decisions/idr/IDR-011-padrao-teste-flutter-keys-mocks-helpers.md` — padrão de teste Flutter a seguir.
- `docs/project-state/decisions/idr/IDR-009-image-picker-para-upload-de-foto.md` — `filechooser` (Web) vs sheet do SO (native).
- `docs/project-state/epics/EPIC-007-e2e-hibrida-flutter/epic.md` — épico de origem (Web-only, `done`).

## Histórico

- 2026-06-01 — Criado por PO (Alexandro / Claude) no re-escopo do EPIC-007. MVP é Web-only; a camada E2E nativa (Patrol + gate mobile) sai do caminho crítico e fica em backlog até a 1ª release mobile. STORY-039 e STORY-040 transferidas do EPIC-007 sem renúmero.
