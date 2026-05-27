---
adr_id: ADR-001
slug: stack-principal
title: Stack principal — Laravel (backend) + Livewire (backoffice) + Flutter (WebApp)
status: accepted  # proposed | accepted | superseded | rejected | deferred
decided_at: 2026-05-27  # YYYY-MM-DD quando virar accepted
decided_by: arquiteto
approved_by: Alexandro  # ex: "Alexandro" — preenchido na aprovação humana
supersedes: null
superseded_by: null
related_adrs: [ADR-002, ADR-003]
related_pdrs: [PDR-003, PDR-004, PDR-011]
related_epics: [EPIC-000]
created_at: 2026-05-27
updated_at: 2026-05-27
---

# ADR-001 — Stack principal

## Contexto

O Turni está nascendo do protótipo PWA (`docs/prototipo/`). Não há código de produção; linguagem, framework e estratégia de frontend estavam **em aberto**. Esta é a primeira spike do EPIC-000 Foundation: sem stack escolhida, nenhuma estória de implementação (setup local, pipeline, hello world) pode começar. A decisão precisa contemplar **dois deliverables independentes** desde o início (PDR-003): um **WebApp** PWA mobile-first para Contratante + Profissional e um **Backoffice** desktop-first para o Admin Turni.

As restrições duras herdadas são: **PostgreSQL** como banco principal (princípio arquitetural #3; formalização retroativa em ADR-000/STORY-005); **TDD + E2E** como exigência de qualidade não-negociável do PO (cobertura geral 80%, núcleo 98%, E2E em todo fluxo); **funcionamento 100% local em 1 comando** (princípio #6); **time minúsculo** (Alexandro + 1–3 devs, alternando papéis). A integração **Pagar.me** (PDR-004 — pré-autorização no aceite, captura no check-out, Pix em ≤ 15 min) não pode ser tornada impraticável pela stack. Os RNFs (`docs/especificacao/non-functional.md`) impõem alvos sensíveis ao frontend: **FCP ≤ 5s em 3G**, carregamento de feed ≤ 1.5s (p95), validação de PIN ≤ 500ms (p95), PWA instalável mobile-first, WCAG AA e leitor de tela nas principais interações.

A direção de stack foi definida pela liderança técnica (Alexandro, acumulando o papel de Arquiteto) com dois drivers fortes e explícitos: **(a)** maximizar o uso de um **framework opinativo maduro** (princípio #4), seguindo o ecossistema e as práticas idiomáticas dele sempre que possível; **(b)** adotar **Flutter** no app do usuário final para, a partir de um único codebase Dart, entregar **web no MVP** e **apps nativos Android/iOS no futuro** sem reescrever. Este ADR registra a decisão, as alternativas reais consideradas e os trade-offs aceitos — em especial os que tocam RNFs públicos.

## Forças (drivers) da decisão

- **F1 — Framework opinativo / baterias incluídas (princípio #4):** peso **alto**. Time minúsculo não pode gastar orçamento decidindo estrutura de pastas, auth, ORM, migrations, fila, testes caso a caso. Quanto mais o framework decide por nós, melhor.
- **F2 — Postgres-native e idiomático (princípio #3):** peso **alto**. ORM, migrations e fila precisam rodar bem sobre Postgres, idealmente **sem** adicionar outro armazenamento (ex.: Redis) no MVP.
- **F3 — Compatível com TDD + E2E sem heroísmo (princípio #10):** peso **alto**. Ferramentas de teste unitário e de browser/integration maduras e de primeira classe.
- **F4 — Estratégia de mobile nativo futuro a partir de um codebase:** peso **alto**. O WebApp do MVP precisa virar app Android/iOS depois sem reescrita — driver decisivo do lado do frontend do usuário final.
- **F5 — Custo e footprint de operação (princípio #11):** peso **médio**. Hospedagem barata, sem orquestração pesada.
- **F6 — Integração Pagar.me viável (PDR-004):** peso **médio**. Cliente HTTP, webhooks entrantes, idempotência — qualquer stack moderna atende; não é diferenciador.
- **F7 — RNFs de frontend mobile (FCP 3G, a11y) (`non-functional.md`):** peso **alto**. Promessas públicas/SLO — qualquer escolha de FE é medida contra elas.

## Opções consideradas

### Opção A — Laravel (backend) + Livewire (backoffice) + Flutter (WebApp) — **escolhida**
- **Resumo:** Backend em **PHP + Laravel** expondo API JSON para o WebApp e servindo o domínio. **Backoffice** construído com **Livewire** (full-stack reativo, server-rendered, dentro do ecossistema Laravel). **WebApp** do usuário final em **Flutter**, rodando como **Flutter Web** no MVP e evoluindo para apps nativos Android/iOS a partir do mesmo código Dart.
- **Como atende aos princípios** (`references/architecture-principles.md`):
  - ✅ **Simplicidade (1):** Laravel + Livewire concentram backend e admin num único ecossistema coeso; o Flutter concentra todo o frontend do usuário (web e futuro nativo) num só codebase.
  - ✅ **Monolito (2):** Laravel é monolito modular por natureza (ver ADR-002).
  - ✅ **Postgres-first (3):** Eloquent fala Postgres nativamente; **fila no driver `database`** roda sobre Postgres (`FOR UPDATE SKIP LOCKED`), sem Redis no MVP.
  - ✅ **Opinativo (4):** Laravel é dos frameworks mais "baterias incluídas" do mercado — Eloquent, migrations, Sanctum/Fortify (auth), scheduler, fila, Pest (testes), Telescope/Pulse (observabilidade), Dusk (browser tests). Livewire é o caminho idiomático para UI reativa em Laravel.
  - ✅ **Coesão/acoplamento (5):** ver ADR-002 (módulos por razão de mudança) e ADR-003 (domínio compartilhado entre api e admin).
  - ✅ **Funcionamento local (6):** PHP + Postgres sobem em Docker Compose; Flutter Web buildável local; Pagar.me mockado (PDR-004 / STORY-003).
  - ⚠️ **Compat. TDD/E2E (10):** backend excelente (Pest/PHPUnit, Dusk). Flutter tem testes de widget/integration de primeira classe; E2E web via Playwright contra o build servido. Trade-off: duas suítes (PHP e Dart) em vez de uma.
  - ⚠️ **RNF de frontend (7-NFR):** Flutter Web tem carga inicial pesada (CanvasKit/Skwasm) e a11y baseada em canvas — risco contra FCP 3G ≤ 5s e leitor de tela. **Trade-off aceito e declarado** (ver Consequências e Plano de verificação).
- **Prós concretos:** ecossistema único e opinativo no backend+admin; caminho direto para nativo futuro sem reescrita; Postgres-first idiomático; hospedagem PHP barata; comunidade enorme e hireability alta no Brasil para Laravel.
- **Contras concretos:** **duas linguagens** (PHP + Dart); WebApp (Dart) e Backoffice (Blade/Livewire) **não compartilham código de runtime** — só contrato de API + tokens gerados (ver ADR-003); riscos de RNF do Flutter Web (carga 3G, a11y).

### Opção B — TypeScript ponta a ponta (NestJS + React PWA + React Backoffice)
- **Resumo:** Uma única linguagem (TS) no backend (NestJS) e nos dois frontends (React), com domínio/tipos/validação/tokens compartilhados num monorepo TS.
- **Como atende aos princípios:** ✅ uma linguagem só; ✅ máximo reuso entre as duas interfaces; ✅ ótimo ecossistema PWA; ⚠️ NestJS é opinativo na estrutura mas tem **menos baterias** que Laravel (sem admin pronto, auth montada com libs); ⚠️ não oferece caminho unificado para app nativo.
- **Prós:** reuso máximo de domínio entre as duas interfaces; Playwright cobre ambas; uma linguagem para o time todo.
- **Contras:** não atende F4 (sem caminho nativo de codebase único); menos opinativo que Laravel (F1); churn do ecossistema Node.
- **Razão da rejeição:** perde nos dois drivers de maior peso desta decisão — o ecossistema opinativo desejado (Laravel ganha em F1) e a estratégia de nativo futuro a partir de um codebase (Flutter ganha em F4).

### Opção C — Django (Python) + React/TS
- **Resumo:** Backend Django+DRF (muito opinativo, admin pronto, ORM forte) + WebApp React PWA.
- **Como atende aos princípios:** ✅ baterias incluídas comparáveis a Laravel; ⚠️ duas linguagens (Python + TS); ⚠️ sem caminho nativo unificado (F4); reuso FE↔BE fraco.
- **Razão da rejeição:** equivalente ao Laravel em F1, mas sem vantagem sobre ele e sem atender F4; sem razão para preferir Python a Laravel dada a direção da liderança técnica.

### Opção D — Status quo (protótipo HTML/JS estático)
- **Consequência se mantivermos:** o produto continua sendo protótipo navegável; nenhuma estória de implementação do EPIC-000 pode começar.
- **Custo de adiar:** bloqueia todo o EPIC-000 e, em cascata, a WAVE-2026-01 inteira. Descartada de imediato — a decisão é necessária agora.

## Matriz comparativa

| Critério (força) | Peso | A — Laravel+Livewire+Flutter | B — TS (NestJS+React) | C — Django+React |
|---|---|---|---|---|
| F1 — Opinativo / baterias | alto | ✅ Laravel é referência em baterias | ⚠️ opinativo em estrutura, menos baterias | ✅ Django comparável |
| F2 — Postgres-native idiomático | alto | ✅ Eloquent + fila `database` | ✅ Prisma/Drizzle | ✅ ORM Django |
| F3 — TDD + E2E maduros | alto | ⚠️ duas suítes (Pest + flutter_test/Playwright) | ✅ Vitest + Playwright unificados | ⚠️ pytest + Playwright |
| F4 — Nativo futuro de codebase único | alto | ✅ Flutter → web e nativo | ❌ não oferece | ❌ não oferece |
| F5 — Custo / footprint | médio | ✅ hospedagem PHP barata | ⚠️ Node ok | ✅ ok |
| F6 — Pagar.me viável | médio | ✅ Http client + webhooks | ✅ | ✅ |
| F7 — RNF frontend (FCP 3G, a11y) | alto | ❌ risco real (CanvasKit, canvas a11y) | ✅ DOM/SPA otimizável | ✅ DOM/SPA otimizável |

> A Opção A **perde explicitamente em F7** (RNF de frontend) — é o trade-off central desta decisão, aceito conscientemente em troca de F4 (nativo futuro) e F1 (ecossistema opinativo coeso). As Opções B e C ganhariam em F7 mas perderiam em F4, que tem peso alto e é o driver estratégico do lado mobile.

## Decisão proposta

> **Optamos pela Opção A.**

A stack principal do Turni é:

- **Backend:** **PHP 8.4+ (alvo 8.5)** + **Laravel 13.x**. Seguir o ecossistema e as práticas idiomáticas do Laravel sempre que possível: **Eloquent** (ORM, não substituir por ORM de terceiro), **migrations** nativas, **fila no driver `database`** (Postgres, sem Redis no MVP), **Sanctum** para autenticação de API/cliente first-party (detalhe em STORY-004), **Pest** como framework de teste padrão, **Telescope/Pulse** para observabilidade local/dev, **Dusk** para testes de browser quando aplicável.
- **Backoffice (Admin):** **Livewire 4.x** sobre Laravel — server-rendered, full-stack reativo, idiomático ao ecossistema.
- **WebApp (Contratante + Profissional):** **Flutter 3.44+ / Dart 3.12+**, entregue como **Flutter Web** no MVP, com o **mesmo codebase** preparado para virar apps nativos Android/iOS em onda futura.

As versões exatas são fixadas no `pubspec`/`composer.json` durante STORY-006 (setup), sempre nas releases estáveis mais recentes vigentes. Decisões locais dentro do framework (lib pontual de X, padrão idiomático Y) ficam a cargo do Programador via IDR, desde que respeitem "seguir o ecossistema Laravel".

## Justificativa

A Opção A maximiza os dois drivers de maior peso. **F1 (opinativo):** Laravel entrega de graça quase tudo que o EPIC-000 precisa, e Livewire mantém o Backoffice dentro do mesmo ecossistema — zero stack nova para o admin. **F4 (nativo futuro):** o Flutter é a única opção avaliada que entrega web agora e apps nativos depois a partir de um único codebase, eliminando a reescrita que mataria um time pequeno. **F2/F3/F5/F6** são bem atendidos: Eloquent + fila `database` mantêm tudo no Postgres (princípio #3), o backend tem TDD/E2E de primeira classe, PHP é barato de hospedar, e Pagar.me é trivial via cliente HTTP + webhooks.

O preço honesto é **F7**: Flutter Web tende a falhar ou chegar no limite do FCP 3G ≤ 5s (payload CanvasKit/Skwasm) e a acessibilidade baseada em canvas é historicamente mais fraca que DOM. Não escondemos esse trade-off — ele é aceito porque o ganho estratégico (um codebase para web + nativo) supera o risco de RNF **no contexto MVP**, e porque o risco é mensurável e reversível por superfície (o WebApp é deploy isolado — ADR-002/003). A validação empírica acontece no hello-world do WebApp (STORY-008), com sinais de revisão explícitos abaixo. O custo de **duas linguagens** (PHP + Dart) é real, mas contido: a fronteira entre elas é o contrato de API, e o domínio de negócio vive inteiro no backend Laravel (ADR-002), não duplicado no cliente.

## Consequências

### Positivas (o que ganhamos)
- Ecossistema único e opinativo no backend + admin → onboarding e velocidade altos para time pequeno.
- Caminho direto para apps nativos futuros sem reescrever o WebApp.
- Tudo sobre Postgres no MVP (ORM, migrations, fila) — sem segundo armazenamento (princípio #3).
- Hospedagem barata e operação simples (princípio #11).
- Hireability e comunidade fortes (Laravel/Flutter) no Brasil.

### Negativas / trade-offs aceitos
- **RNF de frontend em risco:** FCP 3G ≤ 5s e leitor de tela podem não ser atingidos pelo Flutter Web. Aceito com validação no hello-world (STORY-008) e sinais de revisão.
- **Duas linguagens** (PHP + Dart): dois toolchains, duas suítes de teste, dois conjuntos de skills.
- **Sem compartilhamento de código de runtime** entre WebApp (Dart) e Backoffice (Blade/Livewire): só via contrato de API + design tokens gerados para ambos (ADR-003).
- Carga inicial pesada do Flutter Web exige disciplina de otimização (deferred loading, tree-shaking de ícones, cache do CanvasKit).

### Neutras
- O domínio de negócio concentra-se no backend; o WebApp Flutter é um cliente "fino" sobre a API. Isso é coerente com a estratégia nativa futura (mesmo cliente, mesma API).

### Para o time
- **Impacto em estórias existentes:** destrava STORY-002 (hospedagem agora sabe que precisa servir PHP/Laravel + estático Flutter), STORY-003 (Pagar.me com cliente Laravel), STORY-004 (auth via Sanctum + observabilidade Laravel), STORY-006 (setup com PHP+Postgres+Flutter em Docker/1 comando), STORY-008/009 (hello world nas duas interfaces).
- **ADRs relacionados:** ADR-002 (topologia) e ADR-003 (monorepo) são correlatos e dependem desta escolha. Decisões de auth, deploy/IaC, Pagar.me e observabilidade são outras spikes (STORY-002/003/004).
- **Necessidade de spike de validação:** **não** como pré-condição do accept (decisão registrada na sessão de 2026-05-27 com Alexandro). A validação de RNF do Flutter Web é absorvida pelo hello-world (STORY-008).

## Plano de verificação

- **Como verificar conformidade:**
  - `composer.json` e `pubspec.yaml` fixam as versões estáveis mais recentes; CI falha se versões divergirem do baseline acordado.
  - Convenção arquitetural: nenhuma lib substitui um recurso de primeira classe do Laravel sem IDR justificando (ex.: trocar Eloquent, trocar a fila por Redis) — verificável em revisão de PR e, onde possível, em teste/lint.
- **Auto-atualização do WebApp (preocupação explícita do lead — "app web precisa se atualizar para a última versão publicada"):** padrão obrigatório no WebApp Flutter Web:
  - `index.html` e o service worker servidos com `Cache-Control: no-cache` (sempre revalidam); demais assets com hash de conteúdo, imutáveis. (Mata a causa-raiz clássica de "HTML novo apontando para bundle velho / SW servindo `main.dart.js` em cache".)
  - Endpoint `version.json` (git sha / build id) publicado no deploy; o app compara a versão rodando com a do servidor ao abrir e ao retornar de background; havendo nova, exibe aviso não-bloqueante "Nova versão disponível — atualizar" que dispara `skipWaiting` + reload.
  - **Gate de versão mínima** pela API nos fluxos críticos (PIN/pagamento): a API responde `426 Upgrade Required` a clientes velhos demais, forçando atualização antes de operar dinheiro. (Detalhe fino pode virar um ADR Frontend/PWA dedicado; a diretriz fica registrada aqui.)
- **Sinais de revisão (quando reabrir esta decisão):**
  - Se, no hello-world (STORY-008), o **FCP em 3G > 5s** e a otimização não fechar o gap → reabrir o renderer/abordagem do WebApp (ex.: PWA leve em DOM para web e Flutter só no app nativo futuro).
  - Se a **acessibilidade (leitor de tela / WCAG AA)** for reprovada nas principais interações e não houver mitigação viável na camada de semântica do Flutter → reabrir abordagem do WebApp.
  - Se a operação exigir **Redis/segundo armazenamento** com evidência numérica (fila/cache) → ADR específico (não reabre esta).
  - Se a manutenção de **duas suítes/linguagens** custar > 10% do tempo do time → reavaliar (improvável, registrado por honestidade).
- **Spike de validação proposto:** nenhum como pré-condição do accept; o hello-world STORY-008 cumpre o papel de validação empírica do Flutter Web.

---

## Aprovação humana

> Esta seção é o registro formal do aceite. Não preencher sozinho — preencher quando o humano aprovar no chat ou via PR.

- **Status final:** ✅ aceita
- **Aprovado por:** Alexandro
- **Data:** 2026-05-27
- **Forma do aceite:** aprovado em chat (sessão de 2026-05-27)
- **Condicionantes do aceite:** nenhuma. O trade-off de RNF do Flutter Web fica aceito com validação no hello-world (STORY-008) e os sinais de revisão registrados no Plano de verificação.

---

## Histórico

- 2026-05-27 — criada como `proposed` por Arquiteto, após sessão de deliberação com Alexandro (liderança técnica) que definiu Laravel + Livewire + Flutter como direção e aceitou o trade-off de RNF do Flutter Web com validação no hello-world (STORY-008).
- 2026-05-27 — `accepted` por Alexandro (aprovação em chat, junto de ADR-002 e ADR-003).
