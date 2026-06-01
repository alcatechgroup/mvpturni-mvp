# Turni — WebApp (`apps/webapp`)

WebApp do Turni (Flutter), usado por **Contratante** e **Profissional**. Entregue como **Flutter Web** no MVP, com o mesmo codebase preparado para virar apps nativos Android/iOS no futuro (ADR-001). Liga-se ao backend pelo contrato de API (`contracts/`) e aos design tokens (`packages/design-tokens`) — não compartilha código de runtime com o Backoffice.

## Rodar

O WebApp é servido como build estático pelo comando único do monorepo (raiz):

```bash
make setup   # builda o WebApp e serve em http://localhost:8003
```

Para desenvolvimento iterativo do Flutter, no host:

```bash
cd apps/webapp
flutter pub get
flutter run -d chrome      # hot reload no browser
flutter build web          # gera build/web (servido pelo container `webapp`)
flutter test               # testes de widget
```

## Testes E2E

O E2E do WebApp é **híbrido** (IDR-010). Cada camada cobre uma responsabilidade:

| Camada | Ferramenta | Cobre | Onde |
|---|---|---|---|
| **UI Flutter** | `integration_test` | login, validação, RBAC, funnel guard, navegação interna, futuros fluxos (cadastro/agenda/perfil) | `integration_test/` |
| **Smoke HTTP** | Playwright | status/título da raiz, `/version.json`, `/health` (homolog), erros de console JS, **deep link por path** | `tests/e2e/` |
| **Nativo (SO)** | Patrol | permissão, file picker, deep link externo, push, biometria (STORY-039) | `integration_test/native/` |

Quando escrever em qual: **interação com a UI → `integration_test`**; **produto servido (HTTP/hosting) → Playwright**; **diálogo nativo do SO → Patrol**. Padrão de teste (Keys `feature:elemento`, helpers, API real vs mock, naming) em **IDR-011**.

### Comandos

```bash
# Gate completo do WebApp (build fresco → integration_test → smoke Playwright):
make e2e-webapp

# Iteração em dev — camadas isoladas:
make e2e-webapp-integration   # só os cenários de UI (Chrome headless via flutter drive)
make e2e-webapp-smoke         # só o smoke HTTP (Playwright contra :8003)
```

Pré-condição: stack no ar com seed (`make up` + `make _e2e-seed`, ou rode via `make e2e-webapp`, que semeia).

### integration_test no Web — pré-requisito chromedriver

No Web, `integration_test` roda via `flutter drive` (o `flutter test -d chrome` **não** suporta Web). Isso exige um **chromedriver com o mesmo MAJOR do seu Chrome**, no PATH:

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --version   # descubra o MAJOR
# baixe o chromedriver correspondente em https://googlechromelabs.github.io/chrome-for-testing/
# (o `brew install chromedriver` costuma trazer só o latest — pode não casar com o seu Chrome)
chromedriver --version   # confirme o mesmo MAJOR
```

O `make e2e-webapp-integration` sobe/derruba o chromedriver (porta `CHROMEDRIVER_PORT`, default 4444) e passa `--dart-define=API_BASE_URL=http://localhost:8001`: sob `flutter drive` o app é servido numa porta efêmera sem o proxy `/api` do `:8003`; como o CORS da API é aberto e `/api/login` não exige CSRF, o app lê as respostas cross-origin (ver correção de sintaxe na IDR-010).

### Rodar 1 cenário isolado / debugar

```bash
cd apps/webapp
chromedriver --port=4444 &
# o --target no Web é sempre o agregador do topo (auth_test.dart); para focar 1 cenário,
# comente os outros main() em integration_test/auth_test.dart temporariamente:
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/auth_test.dart \
  -d web-server --browser-name=chrome --headless \
  --dart-define=API_BASE_URL=http://localhost:8001
kill %1
# debug visual: troque `-d web-server --browser-name=chrome --headless` por `-d chrome` (sem headless).
```

Os arquivos de cenário vivem em `integration_test/auth/<feature>_test.dart` (IDR-011 §d); no Web o `flutter drive` enraíza imports no diretório do `--target`, então o entrypoint fica no topo (`auth_test.dart`) encadeando os `main()` — assim os arquivos de `auth/` resolvem `../helpers/`.

## Notas

- Pré-requisito: Flutter SDK ≥ 3.41 no host.
- E2E híbrido (integration_test + Playwright + Patrol) decidido em **IDR-010**; padrão de teste em **IDR-011**. Patrol entra na STORY-039.
