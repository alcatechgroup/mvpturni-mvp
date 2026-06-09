---
idr_id: IDR-030
slug: gate-a11y-meetsguideline-flutter
title: Gate de acessibilidade via meetsGuideline nativo do Flutter (não axe/lighthouse)
status: accepted
decided_at: 2026-06-09
decided_by: programador
owner_agent: claude-opus-programador-2026-06-09
related_story: STORY-080
related_adrs: []
related_idrs: [IDR-029]
supersedes: null
superseded_by: null
created_at: 2026-06-09
updated_at: 2026-06-09
---

# IDR-030 — Gate de acessibilidade via `meetsGuideline` nativo do Flutter

> **O que é um IDR.** Registra uma decisão técnica local com impacto em outras estórias/agentes. Aqui: como o WebApp gateia acessibilidade automaticamente daqui pra frente.

## Contexto

A STORY-080 exige um **gate automatizado de acessibilidade** rodando no CI (CA-5), com a estória citando "axe/lighthouse" entre parênteses. O WebApp é **Flutter Web renderizado em canvas** (CanvasKit): o DOM é basicamente um `<canvas>` mais uma *árvore de semântica* que o Flutter monta sob demanda. Ferramentas de a11y baseadas em DOM (axe-core, Lighthouse) inspecionam marcação HTML — contra um app canvas elas veem quase nada e **dão verde falso**, exatamente o pior resultado para um gate.

Além disso, o gate precisa rodar **offline no CI** (sem rede): o tema do DS usa Google Fonts, que busca os `.ttf` em runtime, e o matcher de contraste rasteriza texto dentro de `runAsync` — sem rede o fetch estoura e derruba o teste.

## Decisão

> **Decidi gatear acessibilidade com os matchers nativos do Flutter (`meetsGuideline`) rodando em `flutter test`, não com axe/lighthouse.**

Três guidelines por tela autenticada, nos dois temas:
- `textContrastGuideline` → contraste WCAG AA (4.5:1 normal / 3:1 grande) — **CA-1**;
- `androidTapTargetGuideline` → alvo de toque ≥48dp (superfícies de toque/conteúdo) — **CA-3**;
- `labeledTapTargetGuideline` → todo alvo de toque tem label acessível — **CA-3**.

Harness reutilizável em `apps/webapp/test/a11y/a11y_harness.dart` (`pumpA11y` + `expectScreenMeetsA11y`). O gate roda como step próprio no CI (`flutter test test/a11y/`), além de fazer parte da suíte local de pré-push.

Para rodar offline, um **seam de tipografia** (`lib/ds/typography.dart`: `dsTextTheme`/`dsMono`) usa a fonte do sistema em teste, ligado para toda a suíte por `test/flutter_test_config.dart`. A família da fonte não afeta contraste WCAG (depende de cor + tamanho).

## Por quê

- Os matchers operam sobre a **árvore de Semântica** que o Flutter exporta — que é exatamente o que vira ARIA no DOM em produção e o que leitores de tela consomem. É o sinal certo para um app canvas.
- `quality-standards.md` §5/§6 deixa explícito que a **ferramenta** de a11y é decisão do time; o PO exige o **resultado** (gate verde, regressão pega). O "(axe/lighthouse)" da CA-5 é exemplo parentético, não requisito.
- É `flutter test` puro: sem browser, sem emulador, sem banco → cabe na CI leve (`quality-standards.md` §2.2) e é rápido.

## Alternativas consideradas

- **axe-core / Lighthouse contra o Flutter Web buildado**: descartado — canvas-rendered → enxergam um `<canvas>` quase vazio e dão verde falso; e exigiriam subir browser no runner (contra a CI leve).
- **Auditoria manual com DevTools/Accessibility Inspector**: descartado como gate — não é automatizável, não pega regressão por PR.
- **Bundlar as fontes como asset (em vez do seam)**: resolveria o offline, mas exige baixar/versionar os `.ttf` e não estava ao alcance na sessão (sem rede); o seam é mais leve e ainda deixa a suíte inteira determinística.

## Consequências

### Para outros agentes
- **Toda tela autenticada nova/alterada ganha um teste em `test/a11y/`** usando `pumpA11y` + `expectScreenMeetsA11y`. É o gate de a11y do WebApp — não introduzir axe/lighthouse paralelo.
- CTA pintado com o accent do perfil usa `TurniColors.onAccentFor(brightness)` no `foregroundColor` (nunca `Colors.white` fixo — reprova AA no escuro). Texto/ícone de erro sobre superfície usa `errorInk{Light,Dark}` (os tons de FUNDO reprovam como texto).
- Em teste, não chamar Google Fonts direto: usar `dsTextTheme`/`dsMono` (seam) para a suíte continuar offline.

### Para o projeto
- +1 step rápido na CI (`flutter test test/a11y/`).
- A suíte de teste inteira passou a rodar offline/determinística (efeito colateral positivo do seam).

### Trade-offs aceitos
- O matcher de contraste estima a cor de fundo amostrando pixels — pode ter cantos cegos em gradientes/sobreposições; é um piso forte, não prova completa (complementar com amostragem manual, como pede a CA-1).
- **NavigationRail (desktop)**: o destino do rail Material fica em 44dp e o widget não expõe knob de altura. O gate usa `iOSTapTargetGuideline` (≥44dp, aceito em WCAG 2.1 AA) **só** para o breakpoint de rail; bottom bar (toque) e conteúdo mantêm 48dp. A ratificar pelo Designer.

## Como verificar

- O step "Gate de acessibilidade (a11y)" no `ci.yml` precisa estar verde em todo PR.
- Se uma tela autenticada nova não tiver teste em `test/a11y/`, o gate não a cobre — revisar no PR.

## Tipo

- [x] **Padrão transversal**: a11y gateada por `meetsGuideline` vira o default do WebApp.
- [x] **Convenção interna**: `onAccentFor`/`errorInk*` + seam de tipografia em teste.

---

## Histórico

- 2026-06-09 — criada como `accepted` por programador (sessão claude-opus-programador-2026-06-09) durante STORY-080.
