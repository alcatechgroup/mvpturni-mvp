---
idr_id: IDR-029
slug: shell-statefulshellroute-e-composicao-adaptativa
title: Shell de navegação com StatefulShellRoute.indexedStack + composição adaptativa manual
status: accepted
decided_at: 2026-06-08
decided_by: programador
owner_agent: claude-opus-4-8
related_story: STORY-077
related_adrs: [ADR-001, ADR-007]
related_idrs: [IDR-011, IDR-021]
supersedes: null
superseded_by: null
created_at: 2026-06-08
updated_at: 2026-06-08
---

# IDR-029 — Shell de navegação com StatefulShellRoute.indexedStack + composição adaptativa manual

## Contexto

A STORY-077 implementa o shell de navegação global decidido em DDR-003 (bottom bar → rail → drawer, pintado por perfil). O DDR-003 fixa o **padrão** e os **destinos**, mas deixa ao Programador a configuração de baixo nível do roteamento aninhado e a escolha do widget adaptativo — e pede explicitamente um IDR se essa configuração trouxer decisão não óbvia. Trouxe três.

O WebApp já usava `go_router` com rotas planas e um `_funnelGuard` (ADR-009). Plugar um shell persistente que preserve o estado de cada aba e empilhe drill-downs exige reestruturar essas rotas sem quebrar deep-links, funnel guard nem os E2E existentes.

## Decisão

> **Decidi (1) envolver as rotas autenticadas num `StatefulShellRoute.indexedStack` com 3 branches (Vagas/Turnos/Perfil); (2) compor a superfície adaptativa manualmente (`NavigationBar` + `NavigationRail` nativos + sidebar custom) em vez de `NavigationSuiteScaffold`; (3) o shell entrega só a navegação — as telas internas mantêm sua `AppBar`/sino nesta estória.**

Detalhes load-bearing para quem mexer depois:

- **Branches por destino.** Branch 0 (Vagas) tem a home `/` (role-dispatch feed/minhas vagas) + drill-downs de vaga. Branch 1 (Turnos) tem uma rota **canônica `/turnos`** (role-dispatch) como `initialLocation` — é o alvo do destino "Turnos" via `goBranch`; os paths por papel (`/profissional/turnos`, `/contratante/turnos`) e `/turnos/:id` continuam válidos **dentro do mesmo branch** (deep-links e botões já existentes não quebram). Branch 2 (Perfil) só tem `/perfil`.
- **Navegação por `goBranch(index, initialLocation: index == currentIndex)`** — tocar o destino ativo volta ao topo do branch; tocar outro restaura onde o usuário estava (comportamento M3). O `IndexedStack` preserva o estado de cada aba.
- **Rotas públicas/funil ficam FORA do shell** (sem barra de navegação): `/login`, `/welcome`, `/completar-cadastro`, etc. O `_funnelGuard` segue como `redirect` de topo, inalterado.
- **Camadas:** `AppShellView` (apresentacional, sem router, 100% testável em widget test por breakpoint) + `AppShell` (glue que lê o papel da sessão e traduz para `goBranch`).

## Por quê

- **`StatefulShellRoute.indexedStack`** é o mecanismo nativo do go_router (stack vigente, ADR-001) para shell persistente com estado por aba — exatamente o que o DDR-003 pede ("scroll do feed não reseta ao ir e voltar de Turnos"). Não é dependência nova.
- **Composição manual > `NavigationSuiteScaffold`** porque as três formas têm chrome materialmente diferente: a sidebar (large) carrega marca + tag de papel + usuário + ação "Nova vaga" + Sair, o rail carrega marca + ação + Sair, e a bottom bar é só os 3 destinos. O `NavigationSuiteScaffold` usa a MESMA lista de destinos nas três formas e não acomoda esses slots sem lutar contra o widget. Uso os widgets nativos `NavigationBar`/`NavigationRail` onde encaixam (a11y M3 de graça) e componho só a sidebar.
- **Shell só-navegação nesta estória** evita `AppBar` dupla: as telas internas já têm `AppBar` + sino; removê-las é a STORY-078. O shell adiciona a superfície de navegação ao redor.

## Alternativas consideradas

- **`NavigationSuiteScaffold` (sugerido no DDR-003 como opção):** descartado — não acomoda os slots distintos por forma (marca/usuário/ação/Sair) sem ginástica; a composição manual deu fidelidade ao protótipo aprovado com menos luta contra o framework.
- **Branch de Turnos com `initialLocation` por papel:** impossível — `initialLocation` é estático; um contratante cairia em `/profissional/turnos` (403). Daí a rota canônica `/turnos` role-dispatch.
- **FAB global "Nova vaga" no mobile (compact):** adiado para a STORY-078 — `MinhasVagasScreen` já tem o seu FAB; dois FABs se sobreporiam. No rail/sidebar a ação não conflita e já entra nesta estória.

## Consequências

### Para outros agentes
- **STORY-078** (migração das telas) deve: remover as `AppBar`/sino/FAB próprios das telas internas e usar o header do shell; ao remover o FAB de `MinhasVagasScreen`, promover o FAB global do contratante no compact.
- **Novo destino** = acrescentar item em `shell_destinations.dart` + um `StatefulShellBranch`. Não redesenha o shell.
- **Drill-down** novo deve entrar **dentro** do branch do seu destino (não como rota de topo) para o shell continuar visível e o "voltar" retornar ao destino.
- A rota canônica `/turnos` é a entrada role-neutra de Turnos; prefira-a a `/profissional|contratante/turnos` em links novos.

### Para o projeto
- Sem dependência nova (go_router já era a stack).
- `router.dart` passa de rotas planas para aninhadas no shell; o `_funnelGuard` e os deep-links foram preservados (603 testes de widget + E2E verdes).

### Trade-offs aceitos
- A sidebar (large) é composta à mão (não é `NavigationDrawer` puro) — custo de manutenção localizado em `app_shell_view.dart`, em troca de fidelidade ao protótipo. Itens da sidebar têm `Semantics(selected/label)` para suprir a a11y que o widget nativo daria.
- `AppBar` dupla transitória no desktop até a STORY-078 (aceito pela própria estória).

## Como verificar

- Os widget tests de `app_shell_view_test.dart` fixam a forma por breakpoint e o chrome por perfil; o E2E `app_shell/navegacao_test.dart` prova a navegação real (goBranch + ativo) nos 2 papéis × 2 viewports.
- Se um dia o shell virar `NavigationSuiteScaffold` ou a sidebar virar `NavigationDrawer` nativo, este IDR está obsoleto — atualize/superseda.
