---
story_id: STORY-022
slug: welcome-pos-aprovacao-webapp
title: Tela de welcome pós-aprovação no WebApp
epic_id: EPIC-001
sprint_id: SPRINT-2026-W24
type: implementation
target_role: programador
requires_design: true
design_screen_id: SCREEN-STORY-022-welcome
status: done
owner_agent: claude-opus-4-8
created_at: 2026-05-28
updated_at: 2026-05-29
estimated_session_size: S
---

# STORY-022 — Tela de welcome pós-aprovação no WebApp

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Ela contém tudo o que você precisa. Se algo estiver ambíguo, registre a dúvida na seção "Notas do agente" no final e pause em vez de adivinhar.

## Contexto (por que esta estória existe)

O funil pós-aprovação descrito em `domain/usuario.md` exige que o usuário aprovado **veja a tela de welcome uma vez** antes de ir para completar cadastro. STORY-016 deixou a rota `/welcome` como placeholder funcional para o funnel guard. Esta estória substitui o placeholder pela tela real: boas-vindas com nome do usuário, explicação curta do que vem a seguir (completar cadastro = ~5 min, listar dados sensíveis a coletar), CTA primário "Vamos lá" que marca `welcome_visto = true` e leva a `/completar-cadastro`. É a primeira tela que o usuário recém-aprovado vê — primeira impressão "dentro do produto" — então merece cuidado de voice-and-tone.

Esta é uma estória S porque é uma tela simples, mas com lógica importante de transição de funil + diferenciação de tema por papel (profissional ou contratante).

- Épico: `docs/project-state/epics/EPIC-001-cadastro-e-aprovacao/epic.md`
- Documentos canônicos a ler ANTES de codificar:
  - `docs/especificacao/domain/usuario.md` §"Estados do usuário" (`welcome_visto` flag) e §"Atributos por papel"
  - `docs/project-state/decisions/adr/ADR-009-modelo-de-dados-identidade-epic-001.md`
  - STORY-016 (funnel guard + rota placeholder)
  - `docs/project-state/design/screens/SCREEN-STORY-022-welcome.md` (Designer entrega)
  - `docs/project-state/design/system/voice-and-tone.md`, `tokens.md`
  - `docs/skills/programador/SKILL.md`, `docs/skills/po/references/quality-standards.md`

## O quê (objetivo desta estória)

Entregar tela de welcome real:

1. Rota `/welcome` no WebApp Flutter substitui o placeholder de STORY-016.
2. **Conteúdo**:
   - Headline com nome do usuário ("Bem-vindo(a), {{nome}}!").
   - Parágrafo curto explicando o próximo passo ("Falta só completar seu cadastro — vai levar uns 5 minutos. Vamos pedir CPF/CNPJ, endereço, e [dados específicos do papel]").
   - Lista breve do que será pedido (3–5 bullets adaptados ao papel — profissional: documento, chave Pix, foto de comprovante; contratante: CNPJ, endereço, cultura, contatos).
   - CTA primário: "Vamos lá".
   - Link secundário discreto: "Fazer depois" → faz logout sem marcar `welcome_visto` (usuário vê welcome novamente no próximo login). **Não** é "skip" para `/completar-cadastro` — quer **forçar consciência** do checkpoint.
3. Tema aplicado por papel (profissional/contratante) via DDR-001. Voice-and-tone do Designer.
4. **Lógica de transição**:
   - Clique em "Vamos lá": chama `POST /api/usuarios/me/welcome-visto` (sua rota — sua decisão de naming, registrado em IDR se introduzir padrão); request marca `welcome_visto = true`; resposta inclui novo estado; cliente Flutter atualiza router para `/completar-cadastro`.
   - Acesso direto a `/welcome` por usuário `ativo` mostra mensagem "Você já está com cadastro completo. [link para home]".
   - Acesso direto a `/welcome` por usuário `pendente_aprovacao` ou não-autenticado: 403/redirect a login (já garantido pelo funnel guard de STORY-016, mas teste cobre).
5. **Idempotência**: tentar marcar `welcome_visto = true` quando já está `true` é no-op silencioso (não erra).

## Por quê (valor para o usuário)

Direto: primeira impressão "dentro do produto" — momento de afirmar tom e propósito (autonomia, suporte). Lista do que será pedido reduz fricção mental do completar cadastro. Indireto: marca `welcome_visto = true` que destrava `/completar-cadastro` no funnel guard; primeira mudança de estado **autodirigida pelo usuário** (até aqui, todas as transições foram triggered por admin).

## Critérios de aceite

- [ ] **CA-1:** Rota `/welcome` em homolog renderiza tela real (não placeholder) para usuário `liberado, welcome_visto=false` autenticado.
- [ ] **CA-2:** Headline personalizada com nome do usuário; bullets do que será pedido adaptados ao papel.
- [ ] **CA-3:** Tema aplicado conforme papel (profissional / contratante) seguindo DDR-001 + PDR-013 (claro/escuro).
- [ ] **CA-4:** CTA "Vamos lá" chama API correta, marca `welcome_visto = true`, redireciona a `/completar-cadastro` (que ainda é placeholder até STORY-023/024 fecharem — após elas, leva à tela real).
- [ ] **CA-5:** Link "Fazer depois" faz logout limpo, retorna a `/login`, **não** marca `welcome_visto`. Próximo login mostra `/welcome` de novo (testar).
- [ ] **CA-6:** Acesso a `/welcome` por usuário `ativo` mostra mensagem informativa com link para home.
- [ ] **CA-7:** Acesso a `/welcome` por não-autenticado redireciona ao login.
- [ ] **CA-8:** Idempotência da marcação: chamar 2× não erra (no-op no servidor).
- [ ] **CA-9:** Acessibilidade WCAG 2.1 AA; tema dual.
- [ ] **CA-10:** Cobertura ≥ 80% / ≥ 98% núcleo (transição de funil, mensagem por papel, idempotência).
- [ ] **CA-11:** **E2E em browser real**: seed cria usuário de teste `role=profissional, status=liberado, welcome_visto=false`; usuário loga no WebApp → cai em `/welcome` → clica "Vamos lá" → redireciona a `/completar-cadastro`; segundo login no mesmo usuário (já com `welcome_visto=true, cadastro_completo=false`) → cai direto em `/completar-cadastro` (sem passar pelo welcome).
- [ ] **CA-12:** Log estruturado: evento `user.welcome_seen` com `user_id, role, timestamp` (sem dado pessoal claro).

## Fora de escopo

- Tela de completar cadastro — STORY-023/024.
- Onboarding multi-passo / tutorial interativo — fora do MVP.
- Personalização avançada do welcome (dicas por persona) — fora do MVP.

## Padrões de qualidade exigidos

`quality-standards.md`. Em particular:

- **Cobertura ≥ 80% / ≥ 98% núcleo** (transição de funil, mensagens por papel, idempotência).
- **E2E em browser real** cobrindo CA-11.
- **TDD** nas regras.
- **Segurança (§4)**: rota protegida pelo funnel guard; CSRF Sanctum.
- **Acessibilidade (§5)**: WCAG 2.1 AA; tema dual.

## Dependências

- **Bloqueada por:** STORY-016 (funnel guard + auth). STORY-012 (ADR-009 — estado e flag). Designer entrega `SCREEN-STORY-022-welcome` em `ready`.
- **Bloqueia:** STORY-023/024 (a tela de completar cadastro precisa que welcome esteja real para o E2E completo do funil), STORY-025 (validação).
- **Pré-requisitos:** STORY-006, STORY-007.

## Decisões já tomadas (não as reabra)

- **`domain/usuario.md`** — funil obrigatório welcome → completar cadastro.
- **ADR-009** — flag `welcome_visto`.
- **DDR-001 + PDR-013** — tema dual, cor por perfil.
- **STORY-016** — funnel guard infra.

## Liberdade técnica do agente

Você decide:
- Endpoint exato (`POST /api/usuarios/me/welcome-visto` vs equivalente).
- Estrutura concreta da tela Flutter (componentes do DDR-001).
- Texto exato dos bullets (com Designer).
- Como detectar papel para escolher bullets (do estado de sessão já carregado pelo router).

Você NÃO decide:
- Suprimir o link "Fazer depois" (PO quer manter controle do usuário).
- Reabrir esquema de funil.

## Definição de Pronto (DoD)

- [ ] CA-1 a CA-12 passam.
- [ ] Cobertura medida.
- [ ] E2E verde.
- [ ] Sync Designer↔Programador registrado.
- [ ] `index.json` atualizado.
- [ ] "Notas" preenchida.
- [ ] IDR se houve decisão técnica relevante.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Carregue `docs/skills/programador/SKILL.md`. Confirme screen spec em `ready`. TDD. PR com evidência. `done` após deploy verde.

## Notas do agente (preenchido durante/após execução)

### Entrada inicial

**Sessão 2026-05-29 — claude-opus-4-8 (atuando como Designer + Programador em paralelo).**

Documentos lidos: estória inteira; `domain/usuario.md` §"Atributos por papel" (bullets do completar cadastro por papel) e §"Estados do usuário"; ADR-009 (flag `welcome_seen_at`); STORY-016 (funnel guard + rota placeholder `/welcome`); `router.dart`, `auth_service.dart`, `login_screen.dart`, `welcome_placeholder_screen.dart`; `AuthController`, `routes/api.php`, `User` model, `FunnelGuard` middleware, `ProfissionalCadastroController` (padrão de log estruturado + `Pii`); `UserFactory` (states `liberado`/`liberadoWelcomeVisto`), `AdminUserSeeder`; specs SCREEN-017/018, `voice-and-tone.md`, `tokens.dart`.

Entendimento consolidado:
- O placeholder `/welcome` (STORY-016) já é destino do funnel guard para `liberado, welcome_seen_at=null`. Esta estória troca o placeholder pela tela real.
- Backend: o login já devolve `welcome_visto`/`cadastro_completo`, mas **não** devolve `name` — a headline personalizada exige adicionar `name` ao payload de login e à `UserSession`. Endpoint novo: `POST /api/usuarios/me/welcome-visto` (protegido por sessão; **fora** do `FunnelGuard`, que bloqueia não-ativos com 423 — a rota precisa ser acessível justamente por quem está em `await_welcome`).
- Front: `AuthService.markWelcomeSeen()` chama o endpoint, atualiza a sessão local (`welcomeVisto=true`) e o `notifyListeners`; a tela redireciona a `/completar-cadastro`.
- Tema por papel: profissional = verde (`accentLight/Dark`), contratante = mostarda (`contratanteAccent*`) — já em `tokens.dart`.

Plano (5 bullets):
1. **Designer**: spec `SCREEN-STORY-022-welcome.md` + protótipo HTML fiel (mobile/desktop, estados: padrão por papel, loading, erro, já-ativo).
2. **Backend**: endpoint idempotente `welcome-visto` + log `user.welcome_seen` (sem PII) + `name` no login; testes Pest (happy, idempotência, não-autenticado, papel).
3. **Front**: `WelcomeScreen` real (headline+bullets por papel, CTA "Vamos lá", link "Fazer depois"=logout), `AuthService.markWelcomeSeen`, `name` na sessão, rota troca placeholder; widget tests.
4. **E2E**: seed usuário `profissional, liberado, welcome_visto=false`; Playwright cobrindo CA-11.
5. Suíte completa, cobertura, IDR (endpoint `/me/*`), Notas, index.json, roteiro manual.

Dúvidas: nenhuma bloqueante. Decisão de naming do endpoint e de adicionar `name` ao login são liberdade técnica do agente (CA permite).

### Sync Designer↔Programador

Designer e Programador (mesma sessão, atos separados) alinharam antes do código:

1. **`name` no payload de login + sessão:** o login não devolvia `name`; foi adicionado ao `AuthController@login`, ao `/api/user` (já tinha) e à `UserSession` do Flutter (com `firstName` para a saudação). Headline usa o **primeiro nome**.
2. **Endpoint fora do `FunnelGuard`:** `POST /api/usuarios/me/welcome-visto` usa `auth:web` + `WebAppOnly` + `StartSession`, **sem** `FunnelGuard` — quem marca welcome está em `await_welcome` e o guard (423) o bloquearia. Registrado em IDR-014.
3. **Idempotência:** marcar 2× = 200 no-op, sem regravar timestamp; UI nunca mostra erro por re-marcação (CA-8).
4. **"Fazer depois" = logout sem marcar** (CA-5) — não é atalho para `/completar-cadastro`.
5. **Bullets por papel** conforme §4/§7 do spec (profissional: documento/Pix/comprovante; contratante: CNPJ/endereço/cultura).
6. **Tema por papel** via tokens já existentes (`accent*` verde / `contratanteAccent*` mostarda) — sem token novo.
7. **Seed E2E:** criado `bemvindo.profissional@turni.local` (`liberado, welcome_visto=false`) no `AdminUserSeeder` (dev/homolog).

Spec entregue em `ready`: `docs/project-state/design/screens/SCREEN-STORY-022-welcome.md` + protótipo HTML fiel (`.../SCREEN-STORY-022-welcome/index.html`, estados padrão/loading/erro/já-ativo, mobile/desktop, toggle de tema, papel selecionável).

### Decisões tomadas

- **IDR-014** — (a) **proxy same-origin no dev** (`apps/webapp/router.php` + `docker-compose` reescreve `/api` e `/sanctum` para o container `api`) espelhando o rewrite do Firebase em produção, e (b) convenção de endpoint `/api/usuarios/me/*` fora do `FunnelGuard`. Motivação: STORY-022 é a **primeira chamada autenticada** do WebApp pós-login; o cookie de sessão Sanctum (`SameSite=lax`) só trafega same-origin. Default de `API_BASE_URL` mudou para `''` (mesma origem), unificando dev e release.
- Log estruturado `user.welcome_seen` (`user_id`, `role`, `timestamp`; **sem** PII) — segue o padrão `user.preregistered` da STORY-017 (CA-12).
- Tela real em `lib/features/funnel/welcome_screen.dart`; placeholder de STORY-016 removido; router aponta para a tela real (import com alias `funnel` para não colidir com a `WelcomeScreen` informativa de `/info`).

### Cobertura final

- **API (Pest):** suíte completa verde; **cobertura total 95,7%** (gate ≥80%). `WelcomeController` **100%**, `User` 100%, `AuthController` coberto. 10 testes novos em `WelcomeSeenTest` (happy, idempotência ×2, 401, 403 admin, fora-do-guard, log sem PII, name no login).
- **WebApp (flutter test):** suíte completa verde (48 → 60 testes). 12 testes novos em `welcome_funnel_screen_test.dart` (headline por papel, fallback de nome, bullets por papel, tema por papel, já-ativo CA-6, "Fazer depois" CA-5, erro ao marcar §5.3).
- **E2E (Playwright, browser real):** `welcome.spec.ts` cobrindo CA-11 — **verde**. Revalidados same-origin e verdes: `rbac-login.spec.ts` (todo o fluxo de login/RBAC/funnel guard) e `webapp-hello-world.spec.ts`. **15 passed, 1 skipped** (`/health`, dev).
  - **Flake pré-existente (não introduzido por esta estória):** `pre-cadastro.spec.ts` e `pre-cadastro-contratante.spec.ts`, no passo **cadastro → login pós-cadastro**, falham na ativação da árvore de semantics do Flutter Web na **2ª navegação** no mesmo tab (`getByRole('textbox', {name:'E-mail'})` expira 60s). **Confirmado por teste decisivo:** reconstruí o build em **cross-origin** (runtime pré-STORY-022) e o **mesmo** teste falha igual — logo, é fragilidade pré-existente das STORY-017/018 (IDR-006, semantics), não regressão do proxy same-origin. O submit multipart em si funciona via proxy (verificado: `POST /api/cadastro/{profissional,contratante}` → 201). **Recomendação ao PO/dono da STORY-018:** endurecer o helper `gotoApp` para esperar a re-ativação de semantics na 2ª navegação. Fora do escopo desta estória; não toquei nos testes de outra estória.

### Resultado final / evidência

Todos os CAs (CA-1 a CA-12) cobertos por testes verdes. Fluxo validado em browser real no ambiente local same-origin (`localhost:8003`), espelhando produção (Firebase rewrites). Análise estática (`flutter analyze`) e `dart format` limpos; `pint` limpo na API.

### Links de evidência

- Spec: `docs/project-state/design/screens/SCREEN-STORY-022-welcome.md`
- Protótipo: `docs/project-state/design/screens/SCREEN-STORY-022-welcome/index.html`
- Backend: `apps/api/app/Http/Controllers/Usuario/WelcomeController.php`, `routes/api.php`, `AuthController.php`
- Frontend: `apps/webapp/lib/features/funnel/welcome_screen.dart`, `lib/features/auth/auth_service.dart`, `lib/router.dart`
- Infra dev: `apps/webapp/router.php`, `docker-compose.yml` (serviço `webapp`)
- Testes: `apps/api/tests/Feature/Identity/WelcomeSeenTest.php`, `apps/webapp/test/welcome_funnel_screen_test.dart`, `apps/webapp/tests/e2e/welcome.spec.ts`
- IDR: `docs/project-state/decisions/idr/IDR-014-dev-same-origin-proxy-e-endpoint-me.md`
