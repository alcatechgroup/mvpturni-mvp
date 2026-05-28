---
id: IDR-006
title: WebApp Flutter — usePathUrlStrategy + padrão de E2E via árvore de semantics
status: accepted
decided_at: 2026-05-28
decided_by: programador
source_story: STORY-016
supersedes: nada
superseded_by: nada
---

# IDR-006 — Flutter Web: path strategy + E2E via semantics

## Contexto

Durante a verificação da STORY-016 em browser real, dois problemas reais
apareceram no WebApp (nenhum deles pego pelos testes de widget, que passavam):

1. **Roteamento por hash.** O WebApp não chamava `usePathUrlStrategy()`, então o
   Flutter Web usava o default *hash strategy*. Abrir `http://localhost:8003/login`
   (path) bootava o app em `initialLocation: '/'` → caía sempre na `WelcomeScreen`.
   A tela de login só era alcançável via `/#/login`. Isso quebra deep links, o
   funnel guard (que redireciona para `/welcome`, `/completar-cadastro`, `/app`
   como **paths**) e os links de e-mail (recuperação de senha, futuro).

2. **E2E do WebApp dado como "intestável".** Um diagnóstico anterior (registrado
   por engano em comentários e no runbook) afirmava que Flutter Web/CanvasKit
   "não expõe a UI como DOM" e marcava os cenários de login como `test.fixme`.
   **Era falso.** O CanvasKit não constrói a árvore acessível *por padrão*, mas
   ela é construída ao ativar o placeholder "Enable accessibility" — a partir daí
   `getByLabel`/`getByRole`/`getByText` enxergam os widgets normalmente.

## Decisão

### a) Path strategy
`main.dart` chama `usePathUrlStrategy()` (de `package:flutter_web_plugins`). Rotas
passam a ser paths reais (`/login`, `/welcome`, `/completar-cadastro`, `/app`). O
servidor (php -S em dev; Firebase Hosting em homolog/prod com rewrite SPA) faz
fallback para `index.html`, e o `go_router` resolve a rota no cliente.

### b) Padrão de E2E do Flutter Web (Playwright)
Para os cenários de **interação** (login, RBAC, funnel) no WebApp:

1. Após `page.goto(rota)`, **ativar a árvore de semantics** clicando no
   `flt-semantics-placeholder` via `page.evaluate` (com retry até `flt-semantics`
   existir — o placeholder só responde depois do boot do CanvasKit).
2. **Digitar com teclado real** (`locator.click()` + `page.keyboard.type()`), não
   `fill()`. O `fill()` seta o valor do `<input>` de semantics mas **não**
   sincroniza com o `TextEditingController` do Flutter → o submit ia vazio.
3. Asserções por `getByLabel`/`getByRole`/`getByText` (campos `TextFormField`
   viram `<input>` com `aria-label`; botões e textos viram nós semânticos).
   Usar `{ exact: true }` quando o rótulo for prefixo de outro (ex.: "Senha" vs
   "Mostrar senha").
4. **`workers: 1`** no `playwright.config.ts` do WebApp — instâncias paralelas de
   CanvasKit contendem CPU no boot e deixam a ativação de semantics flaky.

### c) Build sempre fresco no gate
`make e2e` passa a (i) `webapp-build` antes do `e2e-webapp` e (ii) rodar o seed,
eliminando a classe de bug "E2E rodou contra build velho / banco sem usuário"
(que foi exatamente o que mascarou os problemas acima por horas).

## Consequências

- WebApp testável de ponta a ponta em browser real: `make e2e` cobre Backoffice
  (HTML) **e** WebApp (Flutter) — login, RBAC e funnel. CA-13 (a–e) verde local.
- Padrão reutilizável para todo E2E de Flutter Web do projeto (STORY-022+).
- Reversão da política errada: os cenários do WebApp saem de `test.fixme` e
  passam de verdade. Único `skip` legítimo: `/health` JSON do WebApp, que é
  artefato de build servido pelo Firebase em homolog (não existe no dev local).
- Firebase Hosting precisa do rewrite SPA (`** → /index.html`) para path strategy
  funcionar em reload de deep link — verificar na config de hosting do WebApp em
  homolog (a checar no primeiro deploy pós-esta-decisão).

## Nota de processo

O diagnóstico errado ("CanvasKit intestável") foi consequência de **não abrir o
app no browser** e confiar em suíte verde + numa evidência inventada. A correção
veio de dirigir o browser de verdade (screenshots) — registrado aqui para não se
repetir: validação de UI exige olhar a UI.
