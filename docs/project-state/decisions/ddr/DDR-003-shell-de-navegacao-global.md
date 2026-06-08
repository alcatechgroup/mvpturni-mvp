---
id: DDR-003
title: Shell de navegação global do WebApp — bottom bar (mobile) → rail (tablet) → drawer (desktop), pintado por perfil
status: accepted   # proposed | accepted | superseded | rejected | deferred
created_at: 2026-06-08
decided_at: 2026-06-08
approved_by: Alexandro
supersedes: ~
superseded_by: ~
related_ddrs: [DDR-001, DDR-002]
related_adrs: [ADR-001, ADR-007]
related_pdrs: [PDR-003, PDR-018]
scope: navegação
affects_screens: [SCREEN-STORY-077-app-shell, SCREEN-STORY-047-minhas-vagas, SCREEN-STORY-048-feed-profissional, SCREEN-STORY-049-detalhe-vaga, SCREEN-STORY-051-painel-candidatos, SCREEN-STORY-059-listas-turnos, SCREEN-STORY-060-detalhe-turno]
---

# DDR-003 — Shell de navegação global do WebApp

## Contexto

A WAVE-2026-01 construiu o WebApp **tela a tela**: cada estória entregou a sua própria porta de entrada (ícone na `AppBar`, rota direta) sem um **shell de navegação global**. A nota da STORY-059 documenta isso ("Meus turnos" entrou como ícone na AppBar "sem introduzir `NavigationBar` — seria DDR") e o `patterns.md` v0.1 confirma que o catálogo de padrões compostos de navegação **não existe**. O resultado é funcionalmente completo, mas o usuário precisa "saber a rota" em vez de "ver o caminho".

O **PDR-018** abriu o EPIC-012 para resolver isso na SPRINT-2026-W29, e delegou explicitamente ao Designer a decisão de **qual widget de navegação, quais destinos por papel e como o shell colapsa entre breakpoints** — registrada aqui como DDR-003. Esta é a estória **STORY-076** (spike de Designer), que bloqueia a implementação (STORY-077/078).

**Documentos lidos:** STORY-076 (inteira), `epic.md` do EPIC-012, PDR-018, PDR-003 (duas interfaces; Contratante desktop-first, Profissional mobile-first; ambos responsivos), DDR-001 (fundação do DS — breakpoints §5.6, esquema de cor por perfil, **chrome por perfil** — a sidebar escura pintada por papel é assinatura do produto, validada em AA nos dois temas), DDR-002 (pt-BR/24h), ADR-007 (RBAC por papel — o shell mostra só os destinos do papel autenticado), `docs/especificacao/screens/README.md` (inventário de telas por papel), `docs/prototipo/app.html` (sidebar pintada por perfil + `bottom-nav` mobile — fonte de verdade visual), e o `apps/webapp/lib/router.dart` vigente (telas **realmente entregues** hoje).

**O que existe hoje no WebApp Flutter (verificado no `router.dart`), para não inventar tela:**

- **Profissional:** Feed de vagas (`/feed`, é a home `/`), Detalhe da vaga (`/vaga/:id`), Turnos (`/profissional/turnos`), Detalhe do turno (`/turnos/:id`). Notificações = **sino** (`notificacoes_sino` + painel), não tela própria.
- **Contratante:** Minhas vagas (`/contratante/vagas`, é a home `/`), Nova vaga (`/contratante/vagas/nova`), Editar vaga, Painel de candidatos, Turnos (`/contratante/turnos`), Detalhe do turno (`/turnos/:id`). Notificações = **sino**.
- **Perfil** ainda não é tela; hoje "perfil" é o conjunto de chrome já presente — identidade do usuário, **alternância de tema** e **Sair** (espelhando `sb-user`/`sb-foot`/`theme-toggle` do protótipo).

Telas do inventário (`screens/README.md`) ainda **não** construídas (Dashboard, Candidaturas, Financeiro, Empresa, Escala, Equipe, Atendimento, Feedbacks) ficam **fora**: o shell não cria destino para tela que não existe (CA-2; "fora de escopo" do épico). O padrão é desenhado para **crescer** quando elas entrarem (EPIC-004+).

## Forças (drivers)

- **Persona não-técnica** (alto): navegação tem que ser **óbvia, não aprendida**. Profissional opera em pé no mobile; Contratante em jornada longa no desktop (PDR-003). "Ver o caminho", não "saber a rota".
- **Princípio #2 — mobile-first com paridade** (alto): a mesma árvore de widgets precisa colapsar entre celular, tablet e desktop sem "mobile esticado" nem "desktop encolhido". Flutter entrega isso com um único shell adaptativo.
- **Princípio #4 — padronização > criatividade** (alto): Material 3 já tem o trio `NavigationBar`/`NavigationRail`/`NavigationDrawer` (e o `NavigationSuiteScaffold` que alterna entre eles). Não há razão para componente custom de navegação.
- **Identidade por perfil é load-bearing** (alto, DDR-001): o **chrome pintado por papel** (verde-sage profissional / mostarda contratante, escuro nos dois temas) é assinatura do produto e dá reconhecimento instantâneo de contexto. O shell tem que carregar essa cor em **todos** os breakpoints.
- **RBAC por papel** (alto, ADR-007): cada papel vê só os seus destinos; o shell nunca mostra destino de outro papel.
- **Princípio #5 — acessibilidade** (alto): AA é critério do épico (axe/lighthouse no gate). Foco visível, teclado, alvos ≥48dp, ícone com label — desde o protótipo.
- **Custo de reversão** (alto): navegação é estrutural; toda tela atual e futura herda. Decidir errado e reverter depois de N telas é caro — daí ser DDR.
- **Pouco volume de destinos hoje** (médio): cada papel tem hoje ~2 destinos de trabalho reais. O padrão precisa **caber bem com poucos** e **crescer sem redesenho** quando o inventário do `screens/README.md` for entregue.

## Opções consideradas

### Opção A — `NavigationDrawer` (gaveta) como navegação primária em todos os tamanhos

Um menu lateral (drawer) é a navegação principal; no mobile ele vira o "hambúrguer" que abre por cima.

```
mobile (≥360)            desktop (≥1200)
+--------------------+   +----------+--------------------------+
| ☰  Minhas vagas  🔔|   | TURNI.   |  Minhas vagas        🔔  |
+--------------------+   | ──────── |                          |
|                    |   | ▸ Vagas  |   [conteúdo]             |
|   [conteúdo]       |   | ▸ Turnos |                          |
|                    |   | ▸ Perfil |                          |
|                    |   |          |                          |
+--------------------+   +----------+--------------------------+
```

- **Prós:** um só widget; o desktop já é o ideal do Contratante (sidebar persistente).
- **Contras:** **viola o Princípio #2** no mobile — a navegação primária some atrás de um hambúrguer (destino "escondido", anti-padrão para não-técnico em pé na rua). O protótipo **não** faz isso: ele tem `bottom-nav` persistente no mobile. Drawer-como-primária no mobile é exatamente o que a skill cita como NÃO fazer.

### Opção B — Shell adaptativo: bottom bar (mobile) → rail (tablet) → drawer (desktop), pintado por perfil (escolhida)

Um **único shell** (`NavigationSuiteScaffold` do Material 3) que troca o widget de navegação pelo breakpoint do DDR-001 §5.6, **sempre com a cor de chrome do perfil**. Os mesmos destinos, a mesma ordem, o mesmo estado ativo — só muda a forma.

```
compact 0–599 (mobile · home do Profissional)
+------------------------------+
| Vagas                    🔔  |  ← AppBar: título + sino
|                              |
|     [ conteúdo da tela ]     |
|                              |
+------------------------------+
| [⊙ Vagas] [ Turnos ] [Perfil]|  ← NavigationBar (chrome do perfil, ≥48dp)
+------------------------------+

medium 600–839 / expanded 840–1199 (tablet)
+------+-----------------------+
| ⊙    | Minhas vagas      🔔  |  ← NavigationRail (ícones+label),
| Vagas|                       |    estende rótulos no expanded
| Turn.|   [ conteúdo ]        |
| Perf.|                       |
| (+)  |                       |  ← Contratante: ação Nova vaga no topo da rail
+------+-----------------------+

large ≥1200 (desktop · home do Contratante)
+-----------+----------------------------------+
| TURNI.    | Minhas vagas               🔔 ☾ ◑|  ← header: título + sino + tema + user
| Contratante|                                  |
| ───────── |                                  |
| ⊙ Vagas   |        [ conteúdo ]              |
| ▸ Turnos  |                                  |
| ▸ Perfil  |                                  |
| ───────── |                                  |
| [+ Nova vaga]                                |  ← ação primária do Contratante
| ⏻ Sair    |                                  |
+-----------+----------------------------------+
```

- **Prós:** respeita Princípio #2 (bottom bar persistente no mobile = ideal do Profissional; drawer persistente no desktop = ideal do Contratante) **com paridade total** — mesmos destinos nos dois; mapeia 1:1 para o `NavigationSuiteScaffold`/`AdaptiveScaffold` do Flutter (Princípio #4); carrega o chrome por perfil em todos os tamanhos (DDR-001); destinos sempre visíveis (nada escondido atrás de hambúrguer); cresce sem redesenho quando o inventário aumentar.
- **Contras:** com **3 destinos** o bottom bar fica enxuto (M3 aceita 3–5; 3 é o piso). Drill-downs (detalhe de vaga/turno, candidatos) **não** são destinos — empilham sobre o destino ativo, exigindo do Programador um shell que preserve o estado por aba (`StatefulShellRoute` — ver notas/IDR).

### Opção C — Status quo: ícones na `AppBar` por tela, sem shell

Cada tela tem a sua porta de entrada ad-hoc (como hoje).

- **Contras:** é exatamente o problema que o PDR-018 abriu para resolver — navegação fragmentada, sem mapa do produto, custo de retrofit crescente a cada tela. Sem visão de desktop para o Contratante, sem barra inferior para o Profissional.

## Avaliação contra os princípios

| Princípio | A (drawer-primária) | **B (adaptativo)** | C (status quo) |
|---|---|---|---|
| 1. Simplicidade radical | ✅ um widget | ✅ destinos enxutos (3), o resto é drill-down | ⚠️ cada tela reinventa a entrada |
| 2. Mobile-first com paridade | ❌ nav primária escondida no mobile | ✅ bottom bar (mobile) ↔ rail ↔ drawer, mesmos destinos | ❌ sem barra inferior no mobile |
| 3. Tom profissional do domínio | ✅ | ✅ chrome por perfil, sóbrio (DDR-001) | ⚠️ inconsistente entre telas |
| 4. Padronização > criatividade | ✅ M3 | ✅ `NavigationSuiteScaffold` puro, sem custom | ❌ padrão de entrada divergente por tela |
| 5. Acessibilidade como hábito | ⚠️ alvo do hambúrguer ok, mas esconde destino | ✅ ≥48dp, teclado, foco, ícone+label; contraste do chrome já AA (DDR-001) | ⚠️ varia por tela |
| 6. Performance percebida | ✅ | ✅ troca de destino mantém estado (IndexedStack); sem reload | ✅ |
| 7. Estados além do feliz | ➖ (não é do shell) | ➖ estados ficam nas telas (STORY-079); o shell só não pode sumir no erro | ➖ |

> O ⚠️ de B em "Simplicidade" virou ✅: 3 destinos é deliberado — mostra só o trabalho real de hoje e cresce sob demanda. O único custo real (drill-down preservando estado por aba) é de implementação, endereçado nas notas ao Programador.

## Decisão

> **Adotada: Opção B — shell adaptativo único, pintado por perfil, que colapsa `NavigationBar` (mobile) → `NavigationRail` (tablet) → `NavigationDrawer` (desktop).**

Força decisiva: **mobile-first com paridade (Princípio #2) + identidade por perfil (DDR-001) + padronização Material 3 (Princípio #4)**. A Opção A perde por esconder a navegação primária no mobile (anti-padrão para o Profissional não-técnico em pé na rua); o status quo perde por ser o problema que o PDR-018 abriu para resolver. A Opção B é a única que dá ao Profissional uma barra inferior persistente **e** ao Contratante uma sidebar de desktop, com o mesmo conjunto de destinos e a cor de cada papel, num único widget que o Flutter já entrega.

### Widget por breakpoint (ancorado em DDR-001 §5.6)

| Breakpoint | Min-width | Widget de navegação | Forma |
|---|---:|---|---|
| `bp.compact` | 0–599 | **`NavigationBar`** (inferior) | 3 destinos, ícone + rótulo, alvo ≥48dp. `AppBar` no topo com título + sino. **Forma primária do Profissional.** |
| `bp.medium` | 600–839 | **`NavigationRail`** (recolhida) | ícone + rótulo curto à esquerda. |
| `bp.expanded` | 840–1199 | **`NavigationRail` estendida** | rótulos visíveis; conteúdo pode ir a 2 colunas. |
| `bp.large` | ≥1200 | **`NavigationDrawer`** (persistente) | sidebar fixa com marca + tag de papel + destinos + ação primária + Sair. Header do conteúdo mostra título + sino + tema + user. **Forma primária do Contratante.** |
| `bp.extraLarge` | ≥1600 | drawer + **largura útil limitada** | conteúdo não estica além do confortável. |

Implementação natural: `NavigationSuiteScaffold` (Material 3) ou `AdaptiveScaffold` — a escolha fina é do Programador (ver notas).

### Inventário de destinos por papel (derivado do `screens/README.md` + telas entregues; sem inventar tela)

| Ordem | Profissional | Rota hoje | Contratante | Rota hoje |
|---:|---|---|---|---|
| 1 (home) | **Vagas** (feed) | `/feed` (`/`) | **Vagas** (minhas vagas) | `/contratante/vagas` (`/`) |
| 2 | **Turnos** | `/profissional/turnos` | **Turnos** | `/contratante/turnos` |
| 3 | **Perfil** | (nova: consolida identidade + tema + Sair) | **Perfil** | (idem) |

- **Drill-downs não são destinos** e mantêm o shell: detalhe da vaga (`/vaga/:id`), candidatos (`/contratante/vagas/:id/candidatos`), editar vaga, detalhe do turno (`/turnos/:id`), candidatura. Empilham sobre o destino ativo (back volta ao destino).
- **Notificações = sino na barra superior** (com badge), em todos os breakpoints — **não** é destino de navegação. É padrão M3 correto (utilitário, não seção) e espelha o `notificacoes_sino` já entregue. Tocar abre o painel/sheet.
- **Perfil** hoje é tela mínima que **consolida chrome já existente** (identidade do usuário, alternância de tema, Sair). **Não** é feature nova — é dar um lar visível ao que hoje está espalhado no chrome. Enriquecer (editar dados, score, depoimentos) é trabalho futuro (EPIC-004+); o destino já fica pronto para receber.
- **Contratante — ação primária "Nova vaga":** **não** é destino; é ação. **FAB** (compact, acima do `NavigationBar`) / botão no topo da rail (medium/expanded) / botão destacado no header do drawer (large). Espelha o `.fab-vaga` do protótipo.

### Responsivo, estado ativo, chrome e toque (CA-3 / CA-4)

- **Colapso:** mesmos destinos e mesma ordem em todos os tamanhos — só muda a forma (bar→rail→drawer). Nunca "mobile esticado" nem "desktop encolhido". Contratante prioriza ≥1200 (drawer), Profissional prioriza ≤599 (bar) — mas **ambos funcionam nos dois extremos**.
- **Chrome por perfil em todos os breakpoints:** a superfície de navegação (bar/rail/drawer) é pintada com o **chrome do perfil**, escuro nos dois temas (DDR-001 §2.2): Profissional `#1B2E1F`, Contratante `#3D2A0E`. É a assinatura do produto.
- **Estado ativo:** indicador M3 (pílula `accent.soft`) atrás do ícone do destino ativo + rótulo em peso maior, na cor do **acento de tema escuro** do perfil (sobre o chrome escuro): Profissional `#5FA37C`, Contratante `#D4A95C`. Itens inativos = rótulo/ícone em neutro claro (`#ECEDE5`, reduzido em opacidade no ícone). O contraste do chrome e dos acentos sobre superfície escura já foi fechado em AA no DDR-001 (§6.2) — reuso, sem nova fundação.
- **Foco visível** (teclado/web): anel `accent` do perfil (default Material, não remover). Destinos navegáveis por `Tab`, ativáveis por `Enter`.
- **Alvos de toque ≥48dp** em todos os destinos e no sino (piso DDR-001 §5.7 / Material).
- **Ícone com label:** todo destino tem rótulo textual visível (não só ícone); o sino tem `Semantics`/`tooltip` ("Notificações").

## Consequências

### Positivas

- Profissional ganha barra inferior persistente; Contratante ganha sidebar de desktop; ambos responsivos, com a cor do seu papel.
- 100% das telas autenticadas entregues passam a ser alcançáveis a partir do shell, sem digitar rota (métrica primária do épico).
- O padrão vira ativo durável: EPIC-004+ nasce dentro do shell; novos destinos entram só acrescentando item à lista, sem redesenho.
- `patterns.md` ganha o padrão de navegação composto (sai o ponteiro nomeado).

### Negativas / trade-offs assumidos

- **3 destinos é o piso do `NavigationBar`** — o produto hoje é enxuto. Aceito conscientemente: melhor 3 destinos honestos do que inflar a barra com telas que não existem. Cresce naturalmente.
- **Perfil é a única superfície nova** introduzida — minimizada a consolidar chrome existente (identidade/tema/Sair), não feature. Declarado para o PO no "vai".
- **Drill-down preservando estado por aba** exige `StatefulShellRoute` no go_router — custo de implementação real (ver notas). Não é decisão arquitetural nova (go_router já é a stack vigente), mas o Programador deve registrar **IDR** se a configuração do shell-route trouxer decisão de baixo nível.

### Impacto no Design System

- **Novo padrão composto** `pattern.navigation` em `patterns.md` (esta operação) referenciando este DDR + sketch.
- **Nenhum token novo:** reusa chrome/acento por perfil (DDR-001 §2.2), breakpoints (§5.6), toque/contraste (§5.7/§6). Os widgets são Material 3 nativos — sem componente custom no `components.md`.

### Impacto em telas existentes

Specs em `affects_screens` precisam, na migração (STORY-078), passar a viver **dentro** do shell (a `AppBar`/ícones ad-hoc de hoje cedem lugar à navegação global; o sino migra para a barra superior do shell). São: feed (048), minhas vagas (047), detalhe vaga (049), candidatos (051), listas de turnos (059), detalhe do turno (060). A revisão é da STORY-078, não deste spike.

## Implementação sugerida (notas para o Programador)

- **Widget:** `NavigationSuiteScaffold` (package `material`/`flutter_adaptive_scaffold`) resolve bar↔rail↔drawer pelos breakpoints do DDR-001 §5.6 sem ginástica. Se preferir `AdaptiveScaffold`, mantenha os mesmos breakpoints.
- **Roteamento:** envolva as rotas autenticadas num `StatefulShellRoute.indexedStack` (go_router) — um branch por destino (Vagas / Turnos / Perfil) — para **preservar o estado de cada aba** ao trocar de destino (ex.: scroll do feed não reseta ao ir e voltar de Turnos). Drill-downs (`/vaga/:id`, `/turnos/:id`, candidatos, editar) empilham **dentro** do branch correspondente. Se a configuração do shell-route exigir decisão de baixo nível não óbvia, **registre IDR**.
- **Identificadores lógicos sugeridos** (viram `Key`/`ValueKey` nos testes): `shell-nav` (raiz), `shell-nav-vagas`, `shell-nav-turnos`, `shell-nav-perfil`, `shell-bell` (sino), `shell-fab-nova-vaga` (contratante), `shell-theme-toggle`, `shell-logout`.
- **Cor:** chrome e acentos vêm do `ThemeData` por perfil×tema já definido (DDR-001) — o shell lê o papel da sessão (ADR-007) e o brilho do tema; não pinta cor crua.
- **Ordem natural:** (1) shell adaptativo com 3 destinos mockados; (2) plugar as telas reais nos branches; (3) sino + FAB; (4) Perfil mínimo (identidade + tema + Sair).

## Critérios para revisitar

- Quando o inventário do `screens/README.md` crescer além de ~5 destinos por papel — reavaliar agrupamento (seções na rail/drawer; o que fica no bottom bar vs. "Mais").
- Se a pesquisa com usuário mostrar que o Profissional procura Notificações como seção (e não como sino) — promover Notificações a destino.
- Se a métrica de uso mostrar Contratante operando majoritariamente no mobile (≤599) — reavaliar prioridade de forma.
- Após EPIC-004 (avaliação) nascer no shell — confirmar que o padrão de drill-down preservou estado sem dor real.

## Aprovação humana

| Campo | Valor |
|---|---|
| Apresentado em | 2026-06-08 |
| Aprovado por | Alexandro |
| Data da aprovação | 2026-06-08 |
| Observações do aprovador | Aprovada a direção após validar o protótipo nos dois papéis e nos três tamanhos. Aval explícito aos 3 destinos (Vagas/Turnos/Perfil) e ao Perfil como destino que consolida chrome existente (identidade + tema + Sair); enriquecer o Perfil fica para EPIC-004+. |

> DDR-003 `accepted`. Protótipo navegável em `design/screens/SCREEN-STORY-077-app-shell/index.html`. STORY-077 (implementação do shell) liberada.
