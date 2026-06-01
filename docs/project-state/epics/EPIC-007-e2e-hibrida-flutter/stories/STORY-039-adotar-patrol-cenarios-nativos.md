---
story_id: STORY-035
slug: adotar-patrol-cenarios-nativos
title: Adotar Patrol para cenários nativos — scaffolding + 1 cenário de smoke
epic_id: EPIC-007
sprint_id: null
type: enablement
target_role: programador
requires_design: false
status: draft
owner_agent: null
created_at: 2026-05-29
updated_at: 2026-05-29
estimated_session_size: M
---

# STORY-035 — Adotar Patrol para cenários nativos

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Esta estória **só faz sentido depois da STORY-034** (precisa do `integration_test` instalado e do IDR-010 aceito). O objetivo aqui é colocar Patrol em pé como framework e provar que funciona com 1 cenário de smoke — **não é** entregar cobertura nativa real do produto. Cenários nativos de produto entram com as stories que os exigem (image_picker, deep link de e-mail, push, biometria).

## Contexto (por que esta estória existe)

O EPIC-007 (`epic.md` deste diretório) decidiu o modelo híbrido: `integration_test` cobre UI Flutter, Playwright cobre smoke HTTP, **Patrol** cobre cenários que envolvem o lado nativo do SO — coisas que vivem fora da árvore de widgets Flutter:

- Diálogos de permissão do sistema (câmera, notificação, localização).
- Sheets nativos de file picker / image picker (IDR-009: no Web vira `filechooser`, no native vira sheet do SO).
- Deep links e universal/app links chegando de fora do app (ex.: link de recuperação de senha no e-mail).
- Push notifications.
- Biometria (Face ID / Touch ID / fingerprint).

`integration_test` puro trava nessas situações — não consegue tocar em um diálogo do SO. Patrol resolve rodando um servidor de automação nativo (UIAutomator no Android, XCUITest no iOS) em paralelo ao `integration_test`. O teste Dart fica com duas APIs: a do Flutter (`tester.tap`, `pumpAndSettle`) e a do Patrol (`$.native.tap(Selector(text: 'Allow'))`).

Esta story **não cobre nenhum cenário de produto** — entrega o framework e 1 cenário de smoke do Patrol mesmo (algo simples que prove que a infra funciona). Cenários de produto nascem nas stories que os exigem.

- Épico: `docs/project-state/epics/EPIC-007-e2e-hibrida-flutter/epic.md`
- Documentos canônicos a ler ANTES de codificar:
  - `docs/project-state/decisions/idr/IDR-010-e2e-hibrida-integration-test-playwright-patrol.md` — define o escopo do Patrol no modelo híbrido (saída de STORY-034).
  - `docs/project-state/decisions/idr/IDR-011-padrao-teste-flutter-keys-mocks-helpers.md` — padrões herdados (saída de STORY-034).
  - `docs/project-state/decisions/idr/IDR-009-image-picker-para-upload-de-foto.md` — comportamento `filechooser` (Web) vs sheet do SO (native), explicitamente um caso futuro de Patrol.
  - `apps/webapp/integration_test/` — scaffolding já existente (saída de STORY-034).
  - Documentação oficial do Patrol: `patrol.leancode.co`. Pacotes pub: `patrol`, `patrol_cli`.

## O quê (objetivo desta estória)

1. **Dependências:**
   - `apps/webapp/pubspec.yaml` ganha `patrol` em `dev_dependencies` (versão stable mais recente).
   - Instalar `patrol_cli` global (ou via `dart pub global activate patrol_cli`). Documentar comando no README.
2. **Configuração Android** (`apps/webapp/android/`):
   - `app/build.gradle` ajustado conforme guia oficial do Patrol (test runner, dependências de teste, minSdk se necessário).
   - `AndroidManifest.xml` de teste (se exigido).
   - Confirmar que `flutter build apk --debug` continua funcionando.
3. **Configuração iOS** (`apps/webapp/ios/`):
   - `Podfile` atualizado.
   - Test target configurado conforme guia Patrol.
   - Confirmar que `flutter build ios --debug --no-codesign` continua funcionando.
4. **Cenário de smoke** em `apps/webapp/integration_test/native/patrol_smoke_test.dart`:
   - Cenário sugerido (escolher 1): (a) abrir o app, pedir permissão de notificação simulada, asserir que o diálogo apareceu e foi tratado; OU (b) abrir o app, abrir um `image_picker` (mesmo que com botão de teste oculto atrás de feature flag), asserir que o sheet do SO apareceu e selecionar 1 item mock. Escolha a que for mais simples para o SDK atual.
   - O cenário não precisa testar lógica de produto — só provar que: o `integration_test` sobe, o Patrol controla o lado nativo, asserções passam, suite sai 0.
5. **Makefile:**
   - `make e2e-webapp-patrol-android` — roda `patrol test --target integration_test/native/patrol_smoke_test.dart -d android`.
   - `make e2e-webapp-patrol-ios` — equivalente para iOS (pode ficar como `@echo "Requer macOS com Xcode — ver runbook"` se o ambiente local de execução for Linux/Windows; a configuração do projeto fica pronta).
6. **README do WebApp** (`apps/webapp/README.md`) ganha subseção "Patrol (cenários nativos)" — quando usar, comandos, requisitos (Android Studio + emulador AVD; Xcode + simulator).
7. **IDR-010 atualizada** — anotar que Patrol está **em uso real** (não mais "proposto/futuro"), confirmando o escopo. Não criar IDR nova para Patrol — IDR-010 já é o lugar.

## Por quê (valor para o time)

Para **profissional**/**contratante**, valor zero direto. Para o **time**: tira Patrol da categoria "decisão futura" e bota em "está rodando, vamos usar". Quando STORY-XXX (1ª que exigir cobertura nativa real — provavelmente IDR-009 no fluxo de foto de perfil) chegar, o trabalho não é "decidir framework", é "escrever cenário". Reduz o risco de virada para mobile esbarrar em escolha de ferramenta na hora errada.

## Critérios de aceite

### Dependências e configuração

- [ ] **CA-1:** `apps/webapp/pubspec.yaml` tem `patrol` em `dev_dependencies`. `flutter pub get` resolve sem erro. Versão registrada em "Notas".
- [ ] **CA-2:** `patrol_cli` instalado e disponível no PATH (ou `dart pub global activate patrol_cli` documentado). `patrol --version` responde.
- [ ] **CA-3:** `apps/webapp/android/` configurado conforme guia Patrol (build.gradle, runner, deps de teste). `flutter build apk --debug` continua passando (zero regressão de build).
- [ ] **CA-4:** `apps/webapp/ios/` configurado conforme guia Patrol (Podfile, test target). `flutter build ios --debug --no-codesign` continua passando em ambiente macOS. Em ambiente não-macOS, documentar que o build iOS não é validável localmente (cobertura desse build é responsabilidade da STORY-036 ou de quem tiver macOS).

### Cenário de smoke

- [ ] **CA-5:** `apps/webapp/integration_test/native/patrol_smoke_test.dart` existe, escolhe 1 cenário (permission OU image_picker) e está documentado por quê.
- [ ] **CA-6:** Cenário roda verde em Android emulator local via `make e2e-webapp-patrol-android`. Evidência (logs ou print) em "Notas".
- [ ] **CA-7:** Cenário documenta que **não testa produto** — é smoke do framework. Comentário no topo do arquivo deixa isso explícito para o próximo agente não confundir.

### Makefile e documentação

- [ ] **CA-8:** `make e2e-webapp-patrol-android` existe e roda o cenário. Sai 0 quando passa.
- [ ] **CA-9:** `make e2e-webapp-patrol-ios` existe; se rodando em macOS, executa Patrol em simulator; se Linux/Windows, imprime mensagem orientando o operador.
- [ ] **CA-10:** Patrol **não** entra no `make e2e-webapp` (esse continua sendo o gate de pré-tag local — IDR-004 + IDR-010). Patrol roda sob demanda via targets dedicados.
- [ ] **CA-11:** `apps/webapp/README.md` tem subseção "Patrol (cenários nativos)" com: quando usar, requisitos (Android Studio/emulador, Xcode/simulator), comandos, link para a doc oficial.

### Decisões

- [ ] **CA-12:** IDR-010 atualizada (linha de status ou nota): "Patrol em uso real desde <data>". Não cria IDR nova.
- [ ] **CA-13:** Nenhuma nova IDR transversal a menos que a configuração do Patrol force decisão fora do escopo (e.g., se versão exigir bump de minSdk Android, escalar e abrir IDR separada).

## Fora de escopo

- Cenário nativo de produto (image_picker real, deep link real de recuperação, push real). Cada um desses entra com a story de produto que os exige.
- Setup completo do gate mobile (Android emulator local + CI + Firebase Test Lab) — vai para STORY-036.
- Patrol Web — experimental, fora do escopo. Web continua em Playwright + integration_test.
- Mocks de provider de push, FCM/APNs reais — fora.
- Refatorar Keys/helpers existentes — STORY-034 entrega o padrão, esta apenas o consome.

## Padrões de qualidade exigidos

- O cenário de smoke deve seguir IDR-011 (Keys namespaced, helpers reutilizáveis se aplicável).
- Build Android e iOS não podem regredir (CA-3, CA-4).
- README precisa explicitar que Patrol **não está** no gate `make e2e-webapp` para evitar que devs assumam errado.

## Dependências

- **Bloqueada por:** STORY-034 (precisa de `integration_test` instalado, helpers, IDR-010 aceita, IDR-011 aceita).
- **Bloqueia:** STORY-036 (precisa de Patrol configurado para o gate mobile fazer sentido).
- **Pré-requisitos de ambiente:** Android Studio com SDK + 1 AVD funcional para rodar CA-6 localmente. Xcode + simulator para CA-4/CA-9 em macOS.

## Decisões já tomadas (não as reabra)

- **Patrol é o framework escolhido** para cenários nativos (decisão registrada em IDR-010 via STORY-034). Não reabrir Appium/Maestro nesta story.
- **Cenário de smoke ≠ cenário de produto** — esta story entrega framework + smoke. Não tentar resolver IDR-009/foto de perfil aqui.
- **Patrol fora do gate `make e2e-webapp`** — gate principal continua leve; Patrol roda sob demanda.

## Liberdade técnica do agente

Você decide:

- Versão de Patrol (mais recente stable, registrar em Notas).
- Qual dos 2 cenários de smoke escrever (permission OU image_picker).
- Estrutura dentro de `integration_test/native/` (subpastas se quiser).
- Detalhes de configuração Android/iOS (segue guia oficial).

Você **não** decide:

- Substituir Patrol por outro framework.
- Mover Patrol para dentro do `make e2e-webapp` principal.
- Suprimir build Android ou iOS se um deles "não couber" — escalar.

## Definição de Pronto (DoD)

- [ ] CA-1 a CA-12 atendidos (CA-13 condicional).
- [ ] Cenário smoke verde 3x consecutivos em Android emulator local.
- [ ] `flutter build apk --debug` verde; `flutter build ios --debug --no-codesign` verde em ambiente macOS (ou marcado em Notas como dependente de STORY-036).
- [ ] README atualizado.
- [ ] IDR-010 anotada.
- [ ] `index.json` atualizado: `status: done`.
- [ ] "Notas do agente" preenchidas.

## Protocolo do agente (obrigatório)

Segue `docs/skills/po/references/agent-task-format.md`. Particular:

1. **Ao iniciar:** confirmar que STORY-034 está `done` e IDR-010/IDR-011 estão `accepted`. Se não, parar.
2. **Durante:** seguir guia oficial do Patrol passo-a-passo. Commits pequenos: deps, Android config, iOS config, smoke test, Makefile, README, IDR.
3. **Se travar em Android config:** muito comum bater em mismatch de gradle/Kotlin/Patrol — registrar em "Notas" e escalar se passar de 2h sem solução.
4. **Se Patrol exigir mudança que afete produto** (bump de minSdk, mudança em AndroidManifest de produção) — escalar antes de aplicar.
5. **Ao terminar:** `status: in_review`, abrir PR, atualizar `index.json`. Após merge + validação, `status: done`.

## Notas do agente (preenchido durante/após execução)

### Decisões tomadas
- _A preencher._

### Descobertas
- _A preencher._

### Bloqueios encontrados
- _A preencher._

### IDRs criados
- Nenhuma esperada. IDR-010 atualizada (não nova).

### Cobertura final
- Cenário smoke Patrol Android: verde 3x.
- Build Android debug: ok.
- Build iOS debug: ok (se macOS disponível).

### Links de evidência
- _A preencher._
