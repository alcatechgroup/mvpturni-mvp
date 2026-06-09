---
idr_id: IDR-021
slug: harness-same-origin-integration-test-web
title: Harness same-origin para integration_test no Web (proxy reverso + --web-launch-url)
status: accepted
decided_at: 2026-06-01
decided_by: programador
approved_by: Alexandro
owner_agent: claude-opus-4-8-programador-2026-06-01
related_story: STORY-043
related_adrs: [ADR-007]
related_idrs: [IDR-010, IDR-011, IDR-014, IDR-006]
supersedes: null
superseded_by: null
created_at: 2026-06-01
updated_at: 2026-06-01
---

# IDR-021 — Harness same-origin para integration_test no Web

> **O que é um IDR.** Decisão técnica local com impacto em outras estórias/agentes. Toda story futura da área logada (STORY-022+) herda este harness; sem registrá-lo, cada uma reinventaria seu próprio contorno (ou cairia no Playwright/semantics flaky).

## Contexto

A STORY-038 trouxe `integration_test` para o WebApp e, no Web, roda via `flutter drive -d web-server` + chromedriver (IDR-010 §correção). Sob esse comando, o app é servido numa porta do dev-server do Flutter (`--web-port`, default 7357) **diferente** da API (`localhost:8001`). Origens diferentes ⇒ o cookie de sessão do Sanctum (`SameSite=Lax`) **não trafega cross-origin**. A STORY-038 contornou com `--dart-define=API_BASE_URL=http://localhost:8001`, o que cobre só os fluxos cujo desfecho vem da **resposta do login** (RBAC/funnel guard) — porque o login não exige cookie persistido. Mas **chamadas autenticadas pós-login** (ex.: `POST /api/usuarios/me/welcome-visto` da tela de welcome, e toda a área logada da STORY-022+) **falham** cross-origin: sem o cookie, o servidor não reconhece a sessão.

Produção **já é same-origin** (IDR-014): o Firebase Hosting reescreve `/api` e `/sanctum` para o Cloud Run, e o dev local espelha isso com `router.php`. O gate precisava espelhar a mesma topologia para testar a área logada como ela roda de verdade — sem tocar produção.

## Decisão

> **Decidi rodar o `integration_test` do Web SAME-ORIGIN, via um proxy reverso (Node puro, `scripts/e2e-webapp-proxy.js`) numa origem única já stateful no Sanctum (`localhost:3000`), apontando o browser para o proxy com `--web-launch-url`.**

O harness (`make e2e-webapp-integration`) sobe, numa única origem `:3000`:
- `/api/*` e `/sanctum/*` → API real (`localhost:8001`);
- todo o resto → dev-server do `flutter drive` (`localhost:7357`).

A flag-chave é **`--web-launch-url=http://localhost:3000`**, que desacopla a URL que o browser abre do servidor do Flutter. App e API aparecem na **mesma origem** para o browser ⇒ o cookie Sanctum é guardado e reenviado sozinho, e **nem CORS é acionado** (same-origin). O `--dart-define=API_BASE_URL` cross-origin da STORY-038 é **removido** (o app volta ao default same-origin, `_apiBase=''`).

`localhost:3000` já consta em `SANCTUM_STATEFUL_DOMAINS` (default de `config/sanctum.php`), então **nada de produção muda**: sem CORS novo, sem `withCredentials`, sem mock, sem alterar `AuthService`.

## Por quê

- **Espelha produção (IDR-014).** O gate passa a testar a área logada na mesma topologia same-origin que roda em produção/dev — o cookie funciona igual. Menos divergência teste↔produção.
- **Mata o flake na raiz (EPIC-007).** Welcome e validações de pré-cadastro saem do Playwright/semantics flaky (IDR-006 §b) para `integration_test` determinístico.
- **Zero toque em produção.** A origem stateful (`:3000`) já existe; o proxy é artefato de teste (host), análogo ao `router.php` de dev. Nenhum código de produção (CORS, `AuthService`, `withCredentials`) muda — exatamente o que a STORY-043 exigia evitar.
- **Node puro, sem dependência.** ~90 linhas, sem caddy/nginx/lib — menos uma coisa para o time manter (disciplina de bibliotecas).

## Alternativas consideradas

- **Caminho 2 — `withCredentials` + CORS + Sanctum stateful em dev (cross-origin):** descartado. Exigiria tocar `AuthService`/config de produção (credenciais/CORS) e diverge da topologia same-origin de produção (IDR-014). Era o fallback do spike, só se o Caminho 1 travasse — não travou.
- **`--dart-define=API_BASE_URL` (status quo da STORY-038):** insuficiente — cobre só o desfecho da resposta do login, não chamadas autenticadas pós-login (o cookie não persiste cross-origin).
- **Proxy via caddy/nginx:** descartado por trazer dependência/binário externo para um proxy de ~90 linhas que o Node da própria toolchain (já presente p/ Playwright) resolve.

## Consequências

### Para outros agentes
- **Toda story da área logada (STORY-022+) roda neste harness.** Não introduza `--dart-define=API_BASE_URL` cross-origin para fluxos autenticados, nem CORS/`withCredentials` em produção — use o proxy same-origin.
- O entrypoint único do gate no Web é `integration_test/web_test.dart` (compõe `auth_test.dart` + `cadastro_test.dart`). Novas features adicionam seu agregador de feature e o encadeiam ali.
- A origem do proxy **deve** ser stateful no Sanctum. Se mudar de `:3000`, ajuste `SANCTUM_STATEFUL_DOMAINS` no env de **dev** (não produção) e documente.

### Para o projeto
- +1 artefato de teste versionado (`scripts/e2e-webapp-proxy.js`, Node puro, sem deps).
- Wall-time do gate: ver "Notas do agente" da STORY-043 (comparado ao baseline ~49s da STORY-038).
- Workaround documentado: o proxy existe porque `flutter drive -d web-server` serve o app numa origem própria. Se o Flutter passar a suportar same-origin nativo para integration_test no Web, esta IDR pode ser revista.

### Trade-offs aceitos
- O gate depende de `node` no host (já requerido pelo smoke Playwright) e de 2 portas livres (`:3000` proxy, `:7357` dev-server) além da `:4444` do chromedriver.
- Mais um processo (proxy) para subir/derrubar — mitigado por `trap` de limpeza no Makefile.

## Como verificar (se aplicável)

- **Prova positiva:** `integration_test/auth/welcome_test.dart` (chamada autenticada `welcome-visto`) passa via `make e2e-webapp-integration`.
- **Prova do contraste:** o mesmo cenário sob `--dart-define=API_BASE_URL=:8001` sem proxy (cross-origin) **trava em /welcome** no passo autenticado — registrado nas Notas da STORY-043 (evidência do spike).
- Se um fluxo autenticado novo falhar só no gate, conferir: proxy no ar (`/tmp/turni-e2e-proxy.log`), origem stateful no Sanctum, `--web-launch-url` apontando para o proxy.

### Gotcha do binding de integração — vai no LEAF, não no entrypoint (recorrente)

No Web, cada suíte tem **dois arquivos**: o **leaf** (`integration_test/<feature>/<algo>_test.dart`, com os `testWidgets`) e o **entrypoint top-level** (`integration_test/<feature>_test.dart`, que só encadeia os `main()` dos leaves — ele fica no topo para `../helpers` resolver). **Regra:** quem chama `IntegrationTestWidgetsFlutterBinding.ensureInitialized()` (importando `package:integration_test/integration_test.dart`) é o **leaf**, como 1ª linha do `main()` — é o que TODOS os leaves do repo fazem (`auth/*`, `app_shell/navegacao_test`, `feed/feed_test`, `env_banner/*`, `perfil/reputacao_e_gate_test`). O entrypoint é **encadeamento puro**: `import '<feature>/x_test.dart' as x; void main() { x.main(); }` — NÃO chama `ensureInitialized`.

Duas assinaturas de falha (ambas já custaram um ciclo de gate — minutos por run):

1. **Nem leaf nem entrypoint inicializam** → o build compila, o Chrome abre, e o `flutter drive` trava com **`Timed out receiving message from renderer: 30.000`** (chromedriver) → `Application exited before the test started`. (Cai no binding FakeAsync, e o HTTP real do login nunca completa.)
2. **Só o entrypoint inicializa, e o leaf não** → falha **rápida** (logo após o launch, sem rodar nenhum teste) com:
   ```
   DriverError: Error while reading FlutterDriver result for command:
   window.$flutterDriver('{"command":"request_data", ...}')
   Original error: Expected: not null
     Actual: <null>
   ...
   Application finished.
   ```
   Os resultados nunca são reportados porque o binding ativo não é o de integração. **Não** reescreva o teste — mova o `ensureInitialized()` para o `main()` do leaf (e deixe o entrypoint só encadeando).

**Enforcement automatizado (2026-06-09).** O gotcha era recorrente porque nada o impedia em silêncio: a suíte `turnos/` nasceu (STORY-059+) com **todos os 8 leaves sem** `ensureInitialized` — funcionava só dentro de `web_test.dart` (onde `auth` inicializa o binding antes) e **travava** ao rodar `E2E_TARGET=integration_test/turnos_test.dart` isolado. Corrigido: os 8 leaves de `turnos/` passaram a inicializar o binding como os demais. Para **não voltar a acontecer**, há um guard em `apps/webapp/test/integration_test_binding_guard_test.dart` que varre todo leaf `integration_test/<feature>/*_test.dart` e **falha** se algum não chamar `ensureInitialized()`. Roda no `flutter test` → `make test` → hook de pré-push. Assim, um leaf novo sem binding quebra o pré-push imediatamente, em vez de custar um ciclo inteiro de E2E para diagnosticar.

### Gotcha de IPv6/IPv4 (não óbvio — custou ~horas no diagnóstico)

No macOS, `flutter drive --web-hostname=localhost` binda o dev-server em **`::1` (IPv6) apenas**, e um proxy que conecta em `127.0.0.1` (IPv4) recebe **ECONNREFUSED** → o browser leva 502, o bundle JS não carrega, o app não boota e o `flutter drive` **pendura ~11 min** (timeout do `pumpAndSettle`) sem reportar. **Por isso o harness usa `--web-hostname=127.0.0.1`** (bind IPv4) e o proxy conecta em `127.0.0.1`. Se algum dia o dev-server ou o proxy mudar de família de endereço, casar as duas pontas (ambas IPv4 ou ambas IPv6). Sintoma diagnóstico: `E2E_PROXY_DEBUG=1` no proxy mostra só `GET /` repetido (sem requests `.js`).

## Tipo

- [ ] **Padrão transversal**
- [x] **Workaround**: contorna a origem cruzada do `flutter drive -d web-server` para habilitar cookie Sanctum same-origin no gate.
- [x] **Convenção interna**: harness de gate da área logada que a STORY-022+ herda.
- [ ] **Otimização**
- [ ] **Refatoração estrutural**

---

## Histórico

- 2026-06-01 — criada como `proposed` por programador (sessão claude-opus-4-8-programador-2026-06-01) durante STORY-043, a partir do Caminho 1 provado por spike (2026-06-01).
- 2026-06-01 — `accepted` pelo PO (Alexandro) junto com a aprovação da STORY-043.
- 2026-06-09 — adicionado o "Gotcha do binding de integração (leaf × entrypoint)" com as duas assinaturas de falha (STORY-088, a pedido do PO para valer ao time, não só na memória pessoal do agente).
- 2026-06-09 — corrigida a suíte `turnos/` (8 leaves passaram a inicializar o binding) e adicionado o **guard automatizado** (`integration_test_binding_guard_test.dart`) que falha o pré-push se um leaf não chamar `ensureInitialized()`. Fecha o ciclo recorrente apontado na validação do EPIC-004 (STORY-089).
