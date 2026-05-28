---
story_id: STORY-016
slug: rbac-vivo-login-roteamento-por-papel
title: RBAC vivo — login + roteamento por papel (Sanctum SPA no WebApp + guard web no Backoffice) + funnel guard
epic_id: EPIC-001
sprint_id: SPRINT-2026-W24
type: implementation
target_role: programador
requires_design: true
design_screen_id: SCREEN-STORY-016-login-e-rbac
status: in_progress
owner_agent: claude-sonnet-4-6-programador-2026-05-28
created_at: 2026-05-28
updated_at: 2026-05-28
estimated_session_size: L
---

# STORY-016 — RBAC vivo: login + roteamento por papel + funnel guard

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Ela contém tudo o que você precisa. Se algo estiver ambíguo, registre a dúvida na seção "Notas do agente" no final e pause em vez de adivinhar.

## Contexto (por que esta estória existe)

Esta é a estória em que **RBAC fica vivo pela primeira vez no Turni**. Até EPIC-000 fechar, o WebApp e o Backoffice servem páginas hello world públicas. Existe `users` com um admin de teste seedado (STORY-006), Sanctum/Fortify instalados (ADR-007), mas **ninguém consegue logar** e **a separação `admin vê backoffice / contratante+profissional veem WebApp`** descrita em PDR-003 e ADR-007 ainda é só documento. Esta estória entrega o pedaço **vertical** que torna a separação real: telas de login em ambas as interfaces, sessão funcionando, roteamento por papel pós-login, middleware/guard fail-secure, **funnel guard** para o estado `liberado` (welcome/completar cadastro) — com rotas-placeholder para os destinos que ainda não existem (welcome em STORY-022, completar cadastro em STORY-023/024).

A estória é **vertical** mesmo sendo grande: atravessa banco (migração `role` + `status` + flags do funil), domínio (`packages/domain`: máquina de estado do usuário, política de papel), api (login/logout endpoints + guards), admin (login Livewire + middleware `role=admin`), webapp (telas login + roteamento por `role` e `status`/flags) — e entrega um resultado observável: **admin se loga no Backoffice; profissional ou contratante seedados manualmente como `liberado` se logam no WebApp; usuário com papel errado tentando entrar na interface errada é bloqueado fail-secure**. É a primeira vez que o produto deixa de ser hello world e vira sistema com identidade real.

Por que é **L** e não dividida: dividir em "login + RBAC" e "funnel guard" deixa um middle state ("login funciona mas funnel guard não" — confunde teste E2E, dupla pista de erro). Dividir em "WebApp" e "Backoffice" deixa metade da segregação inacabada num PR só. O risco do L é mitigado pela suite de testes que cada CA exige — o agente que executar tem critérios observáveis o suficiente para saber quando cada peça funciona.

- Épico: `docs/project-state/epics/EPIC-001-cadastro-e-aprovacao/epic.md`
- Documentos canônicos a ler ANTES de codificar:
  - `docs/especificacao/domain/usuario.md` (estados, funil, regras de login)
  - `docs/project-state/decisions/pdr/PDR-003-duas-interfaces-webapp-e-backoffice.md` (segregação)
  - `docs/project-state/decisions/adr/ADR-007-auth-base-e-roteamento.md` inteira (mecanismo, cookie/domínio, hash, throttling, fail-secure, audit log de admin)
  - `docs/project-state/decisions/adr/ADR-009-modelo-de-dados-identidade-epic-001.md` (STORY-012 — ownership, funil, audit log)
  - `docs/project-state/decisions/adr/ADR-004-hospedagem-iac-deploy.md` §domínios homolog
  - `docs/project-state/design/screens/SCREEN-STORY-016-login-e-rbac.md` (a ser criado pelo Designer — ver nota abaixo)
  - `docs/project-state/design/system/tokens.md` e `voice-and-tone.md` (DDR-001)
  - `docs/skills/programador/SKILL.md`
  - `docs/skills/po/references/quality-standards.md`

## O quê (objetivo desta estória)

Entregar **identidade real** no WebApp e Backoffice em homolog:

1. **Migração** que aplica a coluna `role` (`admin | contratante | profissional`) e `status` (`pendente_aprovacao | liberado | ativo`) + flags do funil (`welcome_visto`, `cadastro_completo`) à tabela `users`, conforme ADR-009. **Esta é a primeira migração com lógica de negócio do projeto** — leia §"Padrões de qualidade exigidos" abaixo (critério herdado de EPIC-000: exercer `php artisan migrate:rollback` em homolog e registrar evidência).
2. **Login no WebApp** (Flutter): tela `/login` consumindo `POST /api/login` da `api` Laravel; sucesso emite cookie de sessão Sanctum SPA conforme ADR-007 §b; falha exibe erro acionável; campos: e-mail + senha; link "Esqueci minha senha" leva a rota Fortify de reset por e-mail (a tela e o envio reais ficam para STORY-021/cobre as 3 cartas, mas o link já tem que **existir** e levar a um stub funcional ou ao endpoint Fortify default — sua escolha, justificada em IDR).
3. **Login no Backoffice** (Livewire): tela `/login` do admin com guard `web`, sessão escopada **apenas** ao host do admin, cookie distinto do WebApp (ADR-007 §b).
4. **Logout funcional** em ambas as interfaces (invalida sessão no servidor — não só apaga cookie).
5. **Roteamento por papel pós-login** (ADR-007 §d):
   - Login na `api`: usuário `admin` autenticado pelo endpoint público do WebApp → **rejeitado** (resposta da API indica papel inválido para WebApp; cliente Flutter mostra "este usuário usa o backoffice" + link para o admin).
   - Login no Backoffice: usuário não-`admin` → **403 fail-secure**.
   - Requisição entre hosts cruzados (cookie do WebApp chega no admin ou vice-versa) → **bloqueio fail-secure**.
6. **Funnel guard no WebApp** (`domain/usuario.md`): usuário com `status = liberado` é redirecionado a `/welcome` se `welcome_visto = false`; a `/completar-cadastro` se `welcome_visto = true && cadastro_completo = false`; ao acesso normal se `status = ativo`. Rotas `/welcome` e `/completar-cadastro` no WebApp são **placeholders** — texto mínimo "esta tela chega em STORY-022" — para o guard ter destino e o teste E2E completar o redirecionamento. As telas reais vêm em STORY-022/023/024.
7. **Seed atualizado**: além do admin de teste (já existente desde STORY-006), seed cria 1 contratante `ativo` e 1 profissional `ativo` (com `role`, `status`, flags do funil) para o E2E testar os 3 redirecionamentos. **Esses seeds são só de teste/homolog — não vão para prod.**
8. **Audit log do admin** (ADR-009): evento `admin.login` (sucesso e falha) é gravado na tabela de audit log conforme ADR-009. Esta é a **primeira escrita real no audit log** — confirma que o mecanismo funciona.

## Por quê (valor para o usuário)

Direto: Alexandro consegue logar no backoffice em homolog e ver-se reconhecido como admin; um profissional manualmente seedado como `ativo` consegue logar no WebApp e ser roteado pra rota interna. Indireto: **destrava todas as estórias seguintes do EPIC-001** que dependem de "estar logado" — fila de aprovação (STORY-019), editor de templates (STORY-020), e-mails transacionais (STORY-021), welcome (STORY-022), completar cadastro (STORY-023/024). Sem esta estória, o épico não pode entregar nenhum fluxo de usuário aprovado.

## Critérios de aceite

Cada item é observável. Caminho feliz + desvios cobertos.

- [ ] **CA-1:** Migração com `role`, `status`, `welcome_visto`, `cadastro_completo` aplicada na tabela `users` conforme ADR-009. Migração é **idempotente** (rodar 2× não quebra), **reversível** (`down()` declarado e exercido) e **sem dado de exemplo** misturado com migração de schema (seeds são separados).
- [ ] **CA-2:** **Critério herdado de EPIC-000 (F-NB-1):** `php artisan migrate:rollback` exercido **em homologação** e evidência registrada no runbook `docs/operacao/runbook-homolog.md#rollback-migracoes`. Inclui: comando exato executado, output observado, estado de schema antes e depois, replay (`migrate` re-aplica sem erro).
- [ ] **CA-3:** Endpoint `POST /api/login` na `api`: aceita `{email, password}`, valida com hash Argon2id, throttle ativo (5 tentativas/min por email+IP — ADR-007 §f), responde com cookie de sessão Sanctum SPA + JSON com `{role, status, welcome_visto, cadastro_completo}`. Senha **nunca** aparece em log/response (cruza ADR-008 §mascaramento).
- [ ] **CA-4:** Endpoint `POST /api/logout`: invalida sessão no servidor (request subsequente com mesmo cookie retorna 401). Audit log NÃO grava logout do não-admin (registra apenas `admin.login`); logout do admin **registra** `admin.logout` (ou marca o evento equivalente — verifique ADR-009 sobre granularidade).
- [ ] **CA-5:** Tela `/login` no WebApp Flutter: campos e-mail + senha + link "Esqueci minha senha"; erro acionável quando credencial inválida (sem leak — não revela se e-mail existe ou não); botão de submit desabilitado durante submissão; visual coerente com DDR-001 (tokens + cor por perfil; perfil "profissional"/"contratante" só conhecido **pós-login**, então a tela de login usa o tema **base/neutral** do DDR-001 — alinhar com Designer no sync).
- [ ] **CA-6:** Tela `/login` no Backoffice Livewire: campos e-mail + senha; throttle ativo; erro acionável; visual desktop-first coerente com `preview-backoffice.html`. Cookie de sessão é distinto do WebApp; `SESSION_LIFETIME` mais curto que o do WebApp (sugestão 120 min com expiração em inatividade — ADR-007 §b). **Audit log grava `admin.login` (sucesso e falha).**
- [ ] **CA-7:** **Roteamento pós-login no WebApp**: API de login rejeita usuário `role=admin` com erro acionável apontando para a URL do admin (`admin.homolog.turni.com.br/` ou a URL do Cloud Run conforme IDR-003); cliente Flutter exibe a mensagem e o link. **Não confunde "este e-mail está no admin" com "este e-mail não existe"** — a recusa diz "este usuário usa o backoffice" apenas após autenticação bem-sucedida; falha de senha é "credenciais inválidas" genérico (sem leak).
- [ ] **CA-8:** **Roteamento pós-login no Backoffice**: usuário não-admin que tenta logar em `/login` do admin recebe **403 fail-secure** após autenticação (ou erro genérico antes — sua decisão, justificada). Audit log registra a tentativa (`admin.login_attempt_non_admin`).
- [ ] **CA-9:** **Fail-secure de host cruzado**: requisição com cookie do WebApp chegando em host do admin (ou vice-versa) é **bloqueada** (não tenta servir; retorna 401/403 conforme padrão de ADR-007 §d). Teste de integração demonstra.
- [ ] **CA-10:** **Funnel guard no WebApp**: usuário `liberado, welcome_visto=false` autenticado é redirecionado a `/welcome` em qualquer rota interna que não seja `/welcome` ou `/logout`; usuário `liberado, welcome_visto=true, cadastro_completo=false` redireciona a `/completar-cadastro` similarmente; usuário `ativo` acessa rotas internas normalmente. Comportamento implementado **no roteador do WebApp** + **dupla camada no backend** (api retorna 423 ou outro código + indicação de estado quando rota interna é chamada por usuário não-`ativo` — fail-secure dupla).
- [ ] **CA-11:** Rotas `/welcome` e `/completar-cadastro` no WebApp existem como **placeholder** (mensagem "STORY-022/023/024 vai entregar aqui" + botão de logout funcional). Acesso direto a essas rotas pelo usuário ativo (`status=ativo`) **não** é bloqueado mas avisa "você já está com cadastro completo".
- [ ] **CA-12:** Seed de homolog cria 3 usuários de teste: `admin@turni.local` (já existente), `contratante.teste@turni.local` (`role: contratante, status: ativo`), `profissional.teste@turni.local` (`role: profissional, status: ativo, tipo_pessoa: MEI`). Senha conhecida e documentada **apenas** no `.env.example`/README de dev — não em código de produção. Seed é idempotente (2× → mesmos 3 usuários).
- [ ] **CA-13:** **E2E em browser real**: cenário (a) admin loga no Backoffice em homolog e vê a tela inicial protegida (mesmo que ainda só texto "bem-vindo, admin"); cenário (b) profissional de teste loga no WebApp em homolog e cai em rota interna placeholder; cenário (c) admin tenta logar no WebApp e é rejeitado com mensagem + link; cenário (d) profissional tenta logar no Backoffice e recebe 403; cenário (e) seed de profissional `liberado, welcome_visto=false` (criado só para este teste) loga e é redirecionado a `/welcome`. Spec dos cenários roda no CI da pipeline de homolog.
- [ ] **CA-14:** Cobertura unitária ≥ 80% no código novo (geral). Núcleo (máquina de estado do usuário, ownership/policies, audit log writer) ≥ 98% — `quality-standards.md` §1.1.
- [ ] **CA-15:** Audit log da tabela criada por ADR-009 está **realmente imutável** em homolog (verificar mecanismo escolhido em ADR-009 — trigger, REVOKE, etc.). Tentativa explícita de UPDATE/DELETE numa linha de audit log via psql falha (registrar evidência no runbook).
- [ ] **CA-16:** **Tema dual (PDR-013)** funciona em ambas as telas de login (claro/escuro), respeitando `prefers-color-scheme` + toggle persistido por usuário onde aplicável (no login, antes de persistir, usa sistema). Contraste WCAG AA verificado nos 2 temas.

## Fora de escopo

- Telas reais de welcome — STORY-022.
- Telas reais de completar cadastro — STORY-023/024.
- Geração de aceite eletrônico ao final do completar cadastro — STORY-023/024.
- Pré-cadastro público — STORY-017/018.
- Fila de aprovação no admin — STORY-019.
- Editor de templates — STORY-020.
- E-mail de recuperação de senha real (Fortify) — stub funcional aqui; conteúdo e envio real em STORY-021.
- Multi-fator de autenticação — ADR-007 declara fora do MVP.
- Login social (Google/Apple) — fora do MVP.
- Recuperação de senha sofisticada — versão simples Fortify cobre.

## Padrões de qualidade exigidos

Esta estória segue `docs/skills/po/references/quality-standards.md`. Em particular:

- **Cobertura unitária ≥ 80% geral, ≥ 98% no núcleo** (máquina de estado do usuário, ownership/policies, audit log writer, mecanismo de funnel guard).
- **Testes E2E em browser real** cobrindo os 5 cenários de CA-13 (Playwright/conforme decisão de ADR-001/ADR-008). Rodam na pipeline de homolog.
- **TDD** — teste antes do código nas peças com regra de negócio. Commit history reflete.
- **Banco** (`quality-standards.md` §2.4): migração idempotente, reversível, exercida `migrate:rollback` em homolog (**critério herdado F-NB-1 do EPIC-000**).
- **Segurança (§4)**: senha nunca em log/response (mascaramento ADR-008); throttling Fortify ativo; segredos via Secret Manager (ADR-004); cookie `httpOnly + Secure + SameSite=Lax` verificado em homolog deployado.
- **LGPD**: e-mail e senha são dados pessoais — registrar em `docs/especificacao/non-functional.md` §LGPD que o login coleta apenas o necessário; nenhum dado novo além de `role`/`status`/flags do funil.
- **Observabilidade (§3)**: login/logout geram log estruturado (ADR-008) com `request_id`; login do admin **adicionalmente** grava na tabela de audit log (ADR-009). Health-check existente (`/health`) **não** quebra; alerta de Cloud Monitoring para 401/403 fora do esperado em homolog (sua decisão sobre threshold).
- **Acessibilidade (§5)**: WCAG 2.1 AA nas telas de login (contraste, rótulos acessíveis, navegação por teclado, leitor de tela).

## Dependências

- **Bloqueada por:** STORY-012 (ADR-009 `accepted`) — modelo de identidade, ownership, audit log. STORY-013 (ADR-010 `accepted`) — não estritamente, mas a migração de tabelas que esta cria precisa coexistir com a estrutura proposta em ADR-010 (Template/TemplateVersao). Designer entrega `SCREEN-STORY-016-login-e-rbac` em `ready` antes da estória entrar em sprint (sync ≤15 min Programador↔Designer antes da primeira linha de UI — `requires_design: true`).
- **Bloqueia:** STORY-017 (pré-cadastro depende do schema `users` polimórfico — pode ser feita em paralelo com STORY-016 desde que a migração da STORY-016 esteja aplicada; coordenação no sprint), STORY-018 (idem), STORY-019 (fila depende do admin logado + status `pendente_aprovacao`), STORY-020 (editor depende do admin logado), STORY-021 (e-mails dependem de `aprovacao_concedida` que parte da STORY-019, e do Fortify ligado nesta estória), STORY-022/023/024 (telas do funil ocupam as rotas placeholder criadas aqui), STORY-025 (validação).
- **Pré-requisitos de ambiente:** STORY-006 (ambiente local 1 comando), STORY-007 (pipeline e homolog).

## Decisões já tomadas (não as reabra)

- **ADR-007** — Sanctum SPA cookie no WebApp + guard web no Backoffice; Argon2id; coluna `role`+`status`; admin nunca via cadastro público; throttling e Fortify ligados.
- **PDR-003** — Duas interfaces; auth compartilhada; roteamento por papel.
- **PDR-001** — `tipo_pessoa` aplicável a profissional (a coluna entra nesta migração com `nullable: true` ou via tabela auxiliar — siga ADR-009).
- **PDR-013 + DDR-001** — Dual-theme claro/escuro; tema padrão claro; tokens do Design System.
- **ADR-009** — modelo de funil, ownership, audit log.
- **Critério herdado F-NB-1** — `migrate:rollback` em homolog é obrigatório nesta estória (primeira migração com lógica de negócio).
- **Princípios não-negociáveis do PO** — entrega em produção desde o dia 1 (sai em homolog), qualidade é requisito, automação por padrão.

## Liberdade técnica do agente

Você (programador) decide:
- Estrutura concreta da migração (quantos arquivos, ordem, índices).
- Implementação concreta da máquina de estado do usuário (enum + transições em código, padrão Strategy, etc.) — segue padrão decidido em ADR-009.
- Implementação concreta do funnel guard no WebApp Flutter (middleware do go_router/conforme stack) e no backend (middleware Laravel).
- Estrutura concreta de telas Flutter (componentes do DDR-001).
- Estrutura concreta do audit log writer (service no domínio compartilhado).
- Como organizar testes (Pest no backend, Flutter test, Playwright para E2E).

Você (programador) NÃO decide:
- Reabrir ADR-007 (Sanctum SPA vs token), ADR-009 (modelo de identidade), PDR-003 (duas interfaces).
- Substituir Argon2id por outro hash (ADR-007).
- Mudar o conjunto de campos da tabela `users` para algo divergente do ADR-009.
- Pular o `migrate:rollback` em homolog (critério herdado, F-NB-1).
- Suprimir audit log ou pular qualquer um dos eventos auditáveis listados em ADR-009.
- Suprimir cobertura ou E2E (`quality-standards.md`).

Se durante a execução você perceber que ADR-009 ou ADR-007 está com lacuna real, registre em "Notas do agente" com `[ESCALONAMENTO]` e mude `status: blocked`. Não decida sozinho ajustar.

## Definição de Pronto (DoD)

- [ ] Todos os CAs (CA-1 a CA-16) passam, com evidência observável.
- [ ] Cobertura unitária ≥ 80% geral / ≥ 98% no núcleo, medida no PR.
- [ ] E2E em browser real cobrindo CA-13 verde na pipeline de homolog.
- [ ] `migrate:rollback` exercido em homolog e evidência no runbook (CA-2 — F-NB-1).
- [ ] Imutabilidade do audit log verificada em homolog (CA-15).
- [ ] Tema dual (claro/escuro) verificado nas duas telas de login (CA-16).
- [ ] Pipeline CI/CD verde no PR; deploy em homolog verde após merge.
- [ ] Sync Designer↔Programador registrado em "Notas do agente" antes da primeira linha de UI (≤15 min, screen spec `SCREEN-STORY-016-login-e-rbac` em `ready`).
- [ ] `index.json` atualizado: status desta estória `in_review` ao abrir PR; `done` após merge + deploy verde + evidência F-NB-1 anexada.
- [ ] "Notas do agente" preenchida.
- [ ] IDR criado se houve decisão técnica de baixo nível com impacto futuro (ex.: padrão de policies, padrão do audit log writer, padrão do funnel guard).

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Resumo:

1. Carregue `docs/skills/programador/SKILL.md`. Frontmatter desta estória: `status: in_progress`, `owner_agent`, `updated_at`. Atualize `index.json`.
2. Confirme que `SCREEN-STORY-016-login-e-rbac` existe em `docs/project-state/design/screens/` em `status: ready`. Se não, **PARE** e escale ao Designer; não invente UI.
3. Sync ≤15 min com Designer antes da primeira linha de UI.
4. TDD nas peças com regra; commits pequenos.
5. Se decisão arquitetural surgir, `status: blocked`, registre.
6. Ao terminar: "Notas" + `in_review` + PR + atualize `index.json`. Após deploy verde, `done`.

## Notas do agente (preenchido durante/após execução)

### Entrada inicial

**Data:** 2026-05-28  
**Agente:** claude-sonnet-4-6-programador-2026-05-28

**Documentos lidos:**
- STORY-016 inteira (todos os CAs, fora de escopo, DoD, protocolo)
- ADR-007 (Sanctum SPA + guard web, Argon2id, cookies distintos, throttle)
- ADR-009 (schema users, profissional_profiles, contratante_profiles, admin_audit_log, funnel flags, trigger imutabilidade + REVOKE)
- DDR-001 tokens.md (perfil/tema, contraste, componentes)
- voice-and-tone.md
- components.md (roadmap inclui input.text)
- SCREEN-STORY-016-login-e-rbac.md (criado pelo Designer nesta sessão — status: ready)
- quality-standards.md (referência de cobertura 80%/98% núcleo)
- domain/usuario.md (estados funil, máquina de estado)
- PDR-003 (duas interfaces, segregação)

**Entendimento consolidado:**
- Esta estória entrega RBAC real pela primeira vez: login funcional em WebApp (Flutter/Sanctum SPA) e Backoffice (Livewire/guard web), separação de papéis, funnel guard para liberado/ativo, audit log do admin com imutabilidade garantida via trigger+REVOKE no Postgres.
- Blocos centrais: (1) migração users + profissional_profiles + contratante_profiles + admin_audit_log, (2) seed atualizado, (3) endpoint POST /api/login + logout na api, (4) login Backoffice Livewire + middleware role=admin, (5) WebApp Flutter tela /login + funnel guard + placeholders, (6) E2E Playwright cobrindo CA-13.
- F-NB-1 é critério herdado obrigatório — `migrate:rollback` em homolog com evidência no runbook antes de marcar done.
- Funnel guard: `liberado + welcome_seen_at=null → /welcome`; `liberado + welcome_seen_at!=null + cadastro_completed_at=null → /completar-cadastro`; `ativo → acesso normal`. Dupla camada: Flutter + backend retorna 423 para rota interna de usuário não-ativo.
- Audit log: trigger BEFORE UPDATE OR DELETE + REVOKE UPDATE,DELETE ON admin_audit_log FROM turni_app_runtime. Dois usuários de banco: turni_app_migrations (pleno) e turni_app_runtime (sem UPDATE/DELETE no audit log).
- Dúvidas: nenhuma — tudo coberto nas ADRs e no spec.

**Plano (5 bullets):**
1. Migrações: users (role, status, welcome_seen_at, cadastro_completed_at) + profissional_profiles + contratante_profiles + admin_audit_log (trigger + REVOKE). Seeds.
2. Backend api: POST /api/login, POST /api/logout, middleware RBAC, funnel guard backend (middleware + 423 para não-ativo em rota interna).
3. Backend admin: login Livewire, guard web + middleware role=admin, audit log service, logout.
4. WebApp Flutter: tela /login, tela /esqueci-minha-senha stub, placeholders /welcome e /completar-cadastro, funnel guard no router (go_router).
5. Testes: Pest (unitário + integração — cobertura ≥80%/≥98% núcleo), Playwright E2E (CA-13 cenários a–e), suíte completa verde antes de abrir PR.

**Testes previstos (principais):**
- Pest: teste de migração idempotente, rollback + replay sem erro
- Pest: POST /api/login — sucesso (contratante, profissional, admin), credencial inválida (401), throttle (429), admin rejeitado no WebApp
- Pest: POST /api/logout — invalida sessão (401 subsequente)
- Pest: middleware role=admin no Backoffice — não-admin recebe 403
- Pest: fail-secure de host cruzado (cookie WebApp no host admin = bloqueado)
- Pest: funnel guard — liberado+welcome_null→/welcome, liberado+welcome_visto+cadastro_null→/completar-cadastro, ativo→livre
- Pest: audit log imutável — AdminAuditLog::update() lança exceção de banco; SELECT com turni_app_runtime retorna erro de permissão UPDATE
- Pest: ownership policies (fail-secure: usuário sem policy registrada = negado por Gate::denyIfNobodyPoliciesFor)
- Flutter test: tela /login — form valida, botão desabilitado durante submit, banners corretos por estado
- Playwright: cenários CA-13 a–e (admin→backoffice, profissional→webapp, admin→webapp rejeitado, profissional→backoffice 403, liberado→/welcome)

### Sync Designer↔Programador

**Data:** 2026-05-28  
**Duração:** embutido na sessão — spec criado e revisado pelo Programador no mesmo momento (~15 min de leitura e alinhamento).

**Decisões alinhadas:**
- Tema WebApp pré-login = profissional/verde (neutro). Pós-login o WebApp atualiza o ColorScheme para o papel real. ✅
- Tela de login Backoffice sem sidebar (sidebar só pós-autenticação). ✅
- `input.text` e `input.password` definidos no spec — Programador materializa como `TextFormField` filled com os tokens documentados; IDR registrará a decisão. ✅
- URL do admin para o link "Ir para o Backoffice" (estado A.5.4) injeta via env (Cloud Run URL ou DNS). ✅
- Stub de recuperação de senha = chamar endpoint Fortify diretamente (`/forgot-password`), sem layout customizado além do da Tela E. ✅
- Throttle com contador regressivo no botão "Aguardar (Ns)" — Programador decide o mecanismo de timer local em Flutter. ✅
- Tema escuro: implementar a fundação mas ligar via feature flag/env até o PO confirmar que o dark entra no MVP. ✅

### Decisões tomadas
(a preencher)

### Descobertas
(a preencher)

### Bloqueios encontrados
(a preencher)

### IDRs criados
(a preencher)

### Cobertura final
(a preencher)

### Resultado final / evidência
- `migrate:rollback` em homolog: (link/log)
- E2E na pipeline: (run ID)
- Imutabilidade do audit log: (evidência)
- URLs de homolog verificadas: (URLs + screenshots)

### Pendências para fechar (in_review → done)
(a preencher)

### Links de evidência
(a preencher — commit, PR, pipeline)
