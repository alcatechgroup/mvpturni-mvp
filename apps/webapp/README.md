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
| **UI Flutter** | `integration_test` | login, validação, RBAC, funnel guard, navegação, **área logada** (welcome → chamada autenticada), **validações de pré-cadastro** PF/MEI/contratante, futuros fluxos | `integration_test/` |
| **Smoke HTTP** | Playwright | status/título da raiz, `/version.json`, `/health` (homolog), erros de console JS, **deep link por path** | `tests/e2e/webapp-hello-world.spec.ts` |
| **Web-platform** | Playwright (não-gating) | auto-update: service worker, polling de `/version.json`, banner de nova versão (`make e2e-webapp-app-update`) | `tests/e2e/app-update.spec.ts` |
| **Nativo (SO)** | Patrol | permissão, file picker, deep link externo, push, biometria (STORY-039) | `integration_test/native/` |

Quando escrever em qual: **interação com a UI → `integration_test`**; **produto servido / comportamento web-platform (HTTP, service worker, hosting) → Playwright**; **diálogo nativo do SO → Patrol**. Padrão de teste (Keys `feature:elemento`, helpers, API real vs mock, naming) em **IDR-011**.

A UI roda **same-origin** sob `flutter drive` (proxy reverso + `--web-launch-url` — **IDR-021**), espelhando a topologia same-origin de produção (IDR-014). Isso faz o cookie de sessão Sanctum trafegar, habilitando os fluxos **autenticados pós-login** (welcome, e toda a área logada da STORY-022+) — sem CORS, sem `withCredentials`, sem mock, sem tocar produção. O **upload de foto** dos pré-cadastros (file picker do browser) **não** roda em `integration_test` (IDR-009): fica em Patrol no nativo (STORY-039); o happy-path correspondente segue `test.fixme` no Playwright.

### Comandos

```bash
# Gate completo do WebApp (build fresco → integration_test → smoke Playwright):
make e2e-webapp

# Iteração em dev — camadas isoladas:
make e2e-webapp-integration   # só os cenários de UI same-origin (Chrome headless via flutter drive)
make e2e-webapp-smoke         # só o smoke HTTP (Playwright contra :8003)

# Não-gating, sob demanda:
make e2e-webapp-app-update    # smoke web-platform de auto-update (Playwright) — IDR-017
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

O `make e2e-webapp-integration` monta o **harness same-origin** (IDR-021): sobe o chromedriver (porta `CHROMEDRIVER_PORT`, default 4444), um **proxy reverso** (`scripts/e2e-webapp-proxy.js`, Node puro, porta `E2E_PROXY_PORT`, default 3000) e o dev-server do `flutter drive` (porta `E2E_APP_PORT`, default 7357), e aponta o browser para o **proxy** via `--web-launch-url`. O proxy roteia `/api`+`/sanctum` → API (`:8001`) e o resto → dev-server, numa **origem única** `localhost:3000` (já stateful no Sanctum). Assim app e API são same-origin para o browser → o cookie de sessão é guardado e reenviado sozinho, como em produção. **Sem `--dart-define`, sem CORS, sem `withCredentials`.** Sobe e derruba tudo com `trap` de limpeza.

### Rodar 1 cenário isolado / debugar

```bash
cd apps/webapp
chromedriver --port=4444 &
PROXY_PORT=3000 APP_PORT=7357 API_PORT=8001 node ../../scripts/e2e-webapp-proxy.js &
# Em dev, foque um agregador de feature (auth_test.dart / cadastro_test.dart) em vez do
# gate inteiro (web_test.dart). Para focar 1 cenário, comente os outros main() no agregador.
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/auth_test.dart \
  -d web-server --browser-name=chrome --headless \
  --web-hostname=localhost --web-port=7357 \
  --web-launch-url=http://localhost:3000
kill %1 %2
# debug visual: troque `-d web-server --browser-name=chrome --headless` por `-d chrome` (sem headless).
```

Os arquivos de cenário vivem em `integration_test/<feature>/<feature>_test.dart` (IDR-011 §d); no Web o `flutter drive` enraíza imports no diretório do `--target`, então os entrypoints ficam no topo (`auth_test.dart`, `cadastro_test.dart`, e o gate `web_test.dart` que os compõe) encadeando os `main()` — assim os leaves resolvem `../helpers/`.

## Notas

- Pré-requisito: Flutter SDK ≥ 3.41 no host.
- E2E híbrido (integration_test + Playwright + Patrol) decidido em **IDR-010**; padrão de teste em **IDR-011**. Patrol entra na STORY-039.
