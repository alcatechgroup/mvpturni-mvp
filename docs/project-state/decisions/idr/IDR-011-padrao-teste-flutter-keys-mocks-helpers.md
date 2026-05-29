---
id: IDR-011
title: Padrão de teste Flutter — Keys namespaced, mocks vs API real, helpers compartilhados, naming
status: proposed
decided_at: null
decided_by: null
source_story: STORY-034
supersedes: nada
refines: IDR-010
superseded_by: nada
---

# IDR-011 — Padrão de teste Flutter (integration_test + Patrol)

## Contexto

IDR-010 decidiu o modelo E2E híbrido (integration_test + Playwright + Patrol). Falta o **como**: convenção de Keys nos widgets, política de mock vs API real, organização de helpers, naming de arquivos. Sem padrão registrado, cada story do EPIC-001 pós-EPIC-007 (STORY-022+) inventaria o próprio jeito — o que já aconteceu com Playwright (cada spec resolvendo semantics de um jeito ligeiramente diferente até IDR-006 §b ser registrada).

Esta IDR registra o padrão **a partir de STORY-034**: tudo que for escrito daqui em diante segue. Widget tests existentes em `apps/webapp/test/` (login_screen_test, welcome_screen_test, etc.) ficam como estão — não há refator obrigatório retroativo, mas qualquer alteração neles deve passar a seguir IDR-011.

## Decisão

### a) Keys namespaced por feature:elemento

Padrão: `ValueKey('<feature>:<element>')`, sempre em snake-case ou lower-kebab para a feature, com `:` como separador.

Exemplos:

- `ValueKey('login:email')` — campo de e-mail na LoginScreen
- `ValueKey('login:password')` — campo de senha
- `ValueKey('login:submit')` — botão Entrar
- `ValueKey('login:forgot-password')` — link "Esqueci minha senha"
- `ValueKey('login:error-banner')` — banner de erro genérico (credencial inválida, admin rejeitado)
- `ValueKey('welcome:logout')` — botão de logout na Welcome
- `ValueKey('completar-cadastro:cpf')` — campo CPF no fluxo de completar cadastro

Regras:

1. **Toda feature nova** adiciona Keys nos pontos que um E2E asseriaria — campos de input, botões primários, banners de erro/sucesso, links críticos de navegação.
2. **Não adicionar Key por adicionar** — só onde teste vai bater. Excesso de Keys vira ruído.
3. **`exact` no finder Dart** — `find.byKey(const ValueKey('login:email'))` é match exato; sem necessidade de regex/parcial.
4. **Refator de tela mantém Keys estáveis** — Key é contrato. Se uma feature inteira for renomeada (ex.: "completar-cadastro" → "onboarding"), atualizar em massa, com PR explícito. Não trocar Key isoladamente sem atualizar todos os usos.

Keys aparecem só onde fazem sentido — não substituem semantic labels, accessibility hints ou tooltips. Coexistem: Key serve teste, semantic serve acessibilidade.

### b) Mocks vs API real

**Política padrão: API real via docker-compose + seed.**

- `integration_test` roda contra a stack subida por `make setup` (mesmo modelo que Playwright usa hoje).
- Seed `_e2e-seed` (Makefile) garante usuários de teste (admin@turni.local, profissional.teste@turni.local) com `ADMIN_SEED_PASSWORD`.
- Vantagem: cenários exercitam o caminho real (HTTP, validação, RBAC do backend, mapeamento de erro). Não dá falsa segurança.

**Exceções, com mock explícito** (cada exceção justificada no arquivo de teste e em "Notas do agente" da story que a introduz):

1. **Serviços externos não-determinísticos** — Pagar.me, provedor de e-mail transacional, FCM/APNs. Já existe `pagarme-mock` no docker-compose. Para novos serviços, criar mock ao lado.
2. **Cenários de erro raros** — timeout de rede, 503 do backend, race condition específica. Mockar via `HttpOverrides` ou injeção de cliente HTTP fake só no teste. Documentar por quê.
3. **Cenários de produto que exigem estado controlado** — saldo zerado, vaga com >N candidatos, profissional com gate de avaliação bloqueado. Preferir construir via seed/fixture parametrizável em vez de mock — mais perto do real.

**Proibido por padrão:**

- Mock global do cliente HTTP — esconde regressões reais.
- Mock de `go_router` — testar redirects via API real é o ponto.
- Stub do `TextEditingController` ou de validators — defeitam o teste de validação.

### c) Helpers compartilhados em `integration_test/helpers/`

Cada helper resolve um problema específico, com docstring de uso:

- **`pump_app.dart`** — `pumpApp(WidgetTester tester, {String? initialRoute})` sobe o WebApp completo apontando para a API do docker-compose. Lida com boot do Flutter Web (Chrome) ou device nativo, espera primeira pintura, retorna controle ao teste.
- **`login_helper.dart`** — `loginAs(WidgetTester tester, {required String email, required String password})` navega para `/login`, preenche, submete, espera redirect/erro. Retorna o estado final ou lança.
  - Também: `loginAsProfissional(WidgetTester tester)` e `loginAsAdmin(WidgetTester tester)` como atalhos para os usuários de seed.
- **`route_helper.dart`** — `assertOnRoute(WidgetTester tester, String path)` lê estado do go_router e asseria rota corrente. `awaitRouteChange(tester, path, {Duration timeout})` espera transição.
- **`seed_helper.dart`** (futuro, quando precisar) — `seedVaga(...)`, `seedCandidatura(...)` chamando endpoints internos de seed do backend. Não criar até primeira story que exigir.

Regras de helper:

1. Helpers vivem em `integration_test/helpers/`, não em `lib/`.
2. Cada função pública tem docstring (`///`) com 1 exemplo de uso.
3. Helpers não escondem o cenário — o arquivo de teste deve ser legível sem ler o helper. Helpers eliminam boilerplate, não lógica.
4. Helper que falha lança `Exception` com mensagem acionável (não silencia).

### d) Naming e organização de arquivos

Estrutura:

```
apps/webapp/integration_test/
├── helpers/
│   ├── pump_app.dart
│   ├── login_helper.dart
│   └── route_helper.dart
├── auth/
│   ├── login_structure_test.dart
│   ├── login_validation_test.dart
│   ├── rbac_profissional_test.dart
│   ├── rbac_admin_rejected_test.dart
│   └── funnel_guard_test.dart
├── <feature>/
│   └── <feature>_<cenario>_test.dart
└── native/                          # cenários Patrol
    └── patrol_smoke_test.dart       # exemplo da STORY-035
```

Regras:

1. **1 arquivo de teste por cenário ou grupo coeso de cenários** (ex.: `login_validation_test.dart` agrupa "campo obrigatório" e "credencial inválida" — mesmo fluxo, asserções diferentes).
2. **Naming: `<feature>_<cenario>_test.dart`** — snake_case. Feature plural só se a tela for plural (`vagas_filtro_test.dart`).
3. **Cenários Patrol** ficam em `integration_test/native/`. Não misturar com `integration_test/auth/` mesmo que toquem a mesma tela — categoria de teste é Patrol vs integration_test puro.
4. **Top-level de cada arquivo** tem comentário curto declarando: o que cobre, quais CAs/stories referencia, se é Patrol (`// Patrol — exige device nativo`).
5. **`flutter test integration_test`** roda tudo. **`flutter test integration_test/auth/`** roda só auth. Não criar runner customizado.

### e) Determinismo e timing

1. **Preferir `pumpAndSettle()`** — espera todos os timers e animações até quiescência. Determinístico.
2. **`pump(Duration(milliseconds: N))`** só quando o cenário envolver animação intencional (snackbar timer, loading com duração mínima) e o N é justificado em comentário inline.
3. **Proibido `Future.delayed`** dentro do teste — usar `await tester.pump(...)` ou `pumpAndSettle()`.
4. **Esperar por widget, não por tempo:**
   ```dart
   await tester.pumpAndSettle();
   expect(find.byKey(const ValueKey('login:error-banner')), findsOneWidget);
   ```
   Em vez de `await tester.pumpAndSettle(Duration(seconds: 5))` torcendo para o banner aparecer.
5. **Timeout default razoável** — `flutter test integration_test --timeout=2x` se algum cenário precisar. Justificar caso a caso.

### f) Cobertura e CI

- `integration_test` não substitui widget test. Widget tests (`apps/webapp/test/`) continuam cobrindo lógica isolada e devem manter ≥ 80% de cobertura.
- `integration_test` mede caminho feliz e variações críticas, não exhaustivamente todos os ramos.
- Mobile em CI fica fora (IDR-004 vigente, IDR-010 §e).

## Consequências

- **STORY-034** instala o scaffolding e migra os 7 cenários seguindo este padrão. Esta IDR sai como `accepted` quando STORY-034 fechar com PO aprovando.
- **STORY-035** (Patrol) e **STORY-036** (gate mobile) herdam este padrão — Patrol só estende a organização (pasta `native/`) e o naming (mesma convenção).
- **STORY-022+** (todas as stories de feature nova do WebApp pós-EPIC-001) seguem este padrão. PO inclui referência a IDR-011 nas stories que escrever a partir da aceitação.
- **Widget tests legados** (`apps/webapp/test/*.dart`) ficam como estão. Refator retroativo não é obrigatório, mas qualquer edição passa a alinhar com IDR-011 quando aplicável (e.g., adicionar Key seguindo convenção).
- **Padrão evoluível.** Se uma exceção virar regra (e.g., mock global de algum subsistema), refinar IDR-011 com nota — não dispersar em comentários soltos.

## Tabela de decisão rápida

| Pergunta | Resposta |
|---|---|
| Onde colocar este teste novo? | `integration_test/<feature>/<feature>_<cenario>_test.dart` |
| Vou criar Key? | Sim, se o teste asseriar essa parte. `ValueKey('<feature>:<element>')`. |
| Vou mockar a API? | Não. Use docker-compose + seed. Mock só para serviço externo não-determinístico ou erro raro, justificado. |
| Como esperar a tela renderizar? | `await tester.pumpAndSettle()`. Tempo fixo só com motivo no comentário. |
| Vou criar um helper novo? | Só se a sequência for usada em ≥ 2 testes e estiver eclipsando legibilidade. Senão, deixar inline. |
| Helper deve ter teste próprio? | Não. Helpers são exercitados pelos próprios cenários. |

## Atualização — quando esta decisão for aceita

- STORY-034 referencia IDR-011 nos CAs.
- Adicionar referência a IDR-011 nas stories STORY-022+ que ainda forem ser detalhadas pelo PO.
- README do WebApp aponta para IDR-011 na seção "Testes E2E".
