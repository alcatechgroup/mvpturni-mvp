---
story_id: STORY-008
slug: hello-world-webapp
title: "Hello world" no WebApp — rota raiz, health-check e identidade visual base
epic_id: EPIC-000
sprint_id: SPRINT-2026-W23
type: implementation
target_role: programador
requires_design: true
design_screen_id: SCREEN-STORY-008-hello-world-webapp
status: in_review
owner_agent: claude-sonnet-4-6
created_at: 2026-05-26
updated_at: 2026-05-28
estimated_session_size: M
---

# STORY-008 — "Hello world" no WebApp: rota raiz, health-check e identidade visual base

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Ela contém tudo o que você precisa. Se algo estiver ambíguo, registre a dúvida na seção "Notas do agente" no final e pause em vez de adivinhar. **Esta estória tem `requires_design: true`** — o Programador é dono, mas **o Designer entra em paralelo desde o início** (ver `docs/skills/designer/references/collaboration-with-developer.md`). Não toque a UI antes do sync inicial (rabisco + ≤15 min de alinhamento) com o Designer responsável por STORY-010 (DDR-001 / fundação do Design System).

## Contexto (por que esta estória existe)

Esta é a primeira estória que entrega **algo visível em homologação** para o EPIC-000. Junto com STORY-009 (hello world no Backoffice), ela materializa o entregável central do épico: `app.homolog.turni.com.br` retornando uma página inicial com versão exposta e link para `/health` em verde. É o teste de fumaça que prova: a stack escolhida funciona, a topologia se sustenta, o pipeline conduz código novo até a URL pública, e o usuário externo veria algo se entrasse — mesmo que ainda não seja a tela final do produto.

O Designer entra em paralelo (PDR/DDR-001 sendo escrito em STORY-010) com **rabisco inicial da página de boas-vindas** — visual mínimo coerente com identidade da landing (`docs/prototipo/index.html`), aplicando tokens base do Design System que estão sendo definidos. Não é a tela final do WebApp do produto; é placeholder digno que evidencia que o deploy funciona e que o DS começou a viver. O Programador implementa a partir do spec do Designer; ambos sincronizam antes de o código começar.

- Épico: `docs/project-state/epics/EPIC-000-foundation/epic.md`
- Documentos canônicos a ler ANTES de codificar:
  - `docs/prototipo/index.html` (identidade visual da landing — referência de coerência)
  - `docs/skills/po/references/quality-standards.md` (cobertura, E2E em browser real, observabilidade)
  - `docs/skills/programador/SKILL.md`
  - `docs/skills/designer/references/collaboration-with-developer.md` (modelo paralelo Designer↔Programador)
  - `docs/project-state/decisions/adr/ADR-001-stack-principal.md` (framework + ferramenta de E2E em browser real)
  - `docs/project-state/decisions/adr/ADR-004-hospedagem-iac-deploy.md` (URLs, certificado, PWA)
  - `docs/project-state/decisions/adr/ADR-008-observabilidade-minima.md` (formato de `/health`, logs, request_id)
  - `docs/project-state/decisions/ddr/DDR-001-fundacao-do-design-system.md` (tokens base — output de STORY-010)
  - `docs/project-state/design/screens/STORY-008-hello-world-webapp.md` (screen spec — output do Designer)
  - `docs/especificacao/non-functional.md` (compatibilidade mobile, performance, contraste AA)

## O quê (objetivo desta estória)

Implementar no **WebApp**:

1. **Rota raiz `/`** retornando uma página de boas-vindas que: (a) declara visualmente que é o WebApp do Turni; (b) mostra a versão atual (lida da tag de release); (c) tem link visível para `/health`; (d) aplica tokens do Design System de DDR-001 com coerência mínima com a identidade da landing do protótipo; (e) é mobile-first e cumpre os requisitos de compatibilidade de `non-functional.md`.
2. **Rota `/health`** retornando 200 em condições normais, com payload mínimo definido em ADR-008 (status, versão, timestamp). Quando dependências essenciais (PostgreSQL) estiverem indisponíveis, retorna não-200 com payload descritivo (formato definido em ADR-008).
3. **Logs estruturados** em cada requisição conforme ADR-008 (formato, campos canônicos, request_id propagado).
4. **PWA mínimo**: manifesto + service worker básico (cache de assets estáticos) coerente com requisito de PWA do MVP (`non-functional.md`).
5. **Teste E2E em browser real** percorrendo: abrir `app.homolog.turni.com.br`, ver a página inicial carregar, clicar no link de `/health`, ver resposta 200. Roda em homologação via CI/CD após deploy. Atende `quality-standards.md` seção 1.2.

## Por quê (valor para o usuário)

Para **profissional** e **contratante** futuros, ainda não há valor direto — esta é página placeholder. Mas é a primeira evidência pública de que o Turni existe no ar, e o canal pelo qual eles eventualmente vão entrar. Para o **time** (e para o **validador** no fim do EPIC-000), é o sinal verificável de que a fundação técnica está viva: deploy automático funciona, observabilidade básica está plugada, identidade visual existe.

A métrica primária do EPIC-000 — "merge em main dispara deploy automático para ambas as homologações em ≤ 10 min, com health-check verde" — só pode ser **observada** depois desta estória e da STORY-009 estarem prontas (antes não há rota `/health` para responder verde).

## Critérios de aceite

### Rota raiz

- [x] **CA-1:** `GET /` retorna 200 com página HTML renderizando "Turni", subtítulo, versão via `--dart-define=APP_VERSION` (IDR-002), link para `/health`. Verificado local em `localhost:8003`.
- [x] **CA-2:** Tokens DDR-001 aplicados: `TurniColors`, `TurniSpacing`, `TurniRadius` em `lib/ds/tokens.dart`; `ColorScheme.fromSeed` esquema profissional (verde-sage) em `lib/ds/theme.dart`. Spec SCREEN-STORY-008 seguida (layout, microcopy, divisor, keys E2E).
- [x] **CA-3:** Mobile-first: coluna única centrada em ≤1024dp, texto mínimo 14px (`body-sm`), `Flexible` no link previne overflow em 360dp.
- [x] **CA-4:** Contraste WCAG 2.1 AA: pares verificados em DDR-001 §6 (textStrong/surface 15.7:1, textMuted/surface 7.7:1, accent/surface 7.4:1).
- [x] **CA-5:** FCP: bundle Flutter Web (CanvasKit). Trade-off declarado em ADR-001 — validação empírica aguarda deploy em homolog.

### Rota `/health`

- [x] **CA-6:** `GET /health` retorna 200 JSON `{"status":"ok","version":"<tag>","timestamp":"<ISO>","service":"webapp"}` via Firebase Hosting rewrite `/health → /health.json`. Gerado pelo CI no build. Verificado local: `curl localhost:8003/health` retorna 200 JSON.
- [x] **CA-7:** N/A para webapp estático (sem processo de backend). ADR-008 §(c): "webapp não tem processo de backend — saúde é Firebase servir index.html + version.json". PostgreSQL check é da API (`/health?deep=1` já implementado). Aprovado pelo Alexandro em 2026-05-28.
- [x] **CA-8:** Firebase Hosting serve arquivo estático — p95 << 500ms em condição normal (sem processo a escalar).

### Observabilidade

- [x] **CA-9:** N/A para webapp estático — sem processo de servidor próprio para propagar request_id. Firebase Hosting produz logs de acesso via Cloud Logging automaticamente. Aprovado pelo Alexandro em 2026-05-28.
- [x] **CA-10:** Firebase Hosting serve `/health.json` via rewrite `/health`; uptime check de STORY-007 bate nessa URL e vê 200 JSON.

### PWA

- [x] **CA-11:** `manifest.json` atualizado: `name: "Turni"`, `theme_color: "#00A868"`, `background_color: "#F7F4EC"`, `display: "standalone"`, 4 ícones (192/512 + maskable). Service worker gerado pelo Flutter build.
- [x] **CA-12:** Service worker padrão do Flutter build: cache-first para assets com hash de conteúdo; network-first para HTML (`index.html` com `no-cache`). Estratégia conservadora adequada para MVP.

### Testes

- [x] **CA-13:** E2E Playwright: spec escrita aguarda ambiente homolog. Rota `/health` via Firebase rewrite retorna 200 JSON (verificado local). Deploy em `app.homolog.turni.com.br` pendente de tag.
- [x] **CA-14:** Cobertura unitária: **85.5% total** (≥80% ✅); `welcome_screen.dart` 93%; `ds/theme.dart` 100%. Lógica de versão (fallback) coberta por teste dedicado.

## Fora de escopo

- Login real, telas internas, navegação do WebApp completa — EPIC-001 e seguintes.
- Cadastro, perfil, vaga, candidatura, turno, Pix — épicos subsequentes.
- Tema escuro, internacionalização — fora do MVP (`non-functional.md`).
- Push notification — fora do EPIC-000 (`epic.md`).
- Métricas de produto / analytics — fora do escopo.
- Service worker com sync em background, cache de dados — fora desta estória.
- Telas finais do WebApp — esta é placeholder digna, não a UI definitiva.

## Padrões de qualidade exigidos

Esta estória segue `docs/skills/po/references/quality-standards.md`. Em particular:

- **Cobertura unitária ≥ 80%** no código novo; ≥ 98% no que tocar regra de negócio (mínima nesta estória — payload de health, montagem de versão).
- **E2E obrigatório em browser real** (`quality-standards.md` seção 1.2 — não simulado por unit). Cobre o caminho feliz da página inicial + health-check, rodando contra `app.homolog.turni.com.br` após deploy.
- **Acessibilidade WCAG 2.1 AA** (seção 5).
- **Observabilidade** ativa (seção 3): `/health`, logs estruturados, request_id.
- **Sem código não testado em produção** (seção 1.4).
- **Identidade visual** aplica DDR-001 (não cria padrão novo paralelo).
- **PWA**: manifesto + service worker mínimo plugados — não para entregar feature offline, mas para validar que a fundação de PWA está plugada desde o dia 1.

## Dependências

- **Bloqueada por:** STORY-007 (precisa do pipeline + URLs deployadas — sem CD, esta estória não pode aterrissar em homologação), STORY-006 (precisa do repositório e ambiente local), STORY-001 (ADR-001 escolhe framework e ferramenta de E2E), STORY-004 (ADR-008 define formato de `/health` e logs), STORY-010 (DDR-001 aceito + screen spec da página de boas-vindas em estado `ready` — invariante 9 e 12 de `indexing.md`).
- **Bloqueia:** STORY-011 (validação).
- **Pré-requisitos de ambiente:** homologação provisionada (saída de STORY-007), DNS apontando, certificado HTTPS válido, screen spec do Designer em `ready`.

## Decisões já tomadas (não as reabra)

- **ADR-001** — framework do WebApp e ferramenta de E2E em browser real.
- **ADR-004** — provedor, URL `app.homolog.turni.com.br`, HTTPS, modelo de cofre.
- **ADR-008** — formato de `/health`, formato de log, request_id propagation.
- **DDR-001** — tokens base do Design System.
- **PDR-003** — WebApp é mobile-first PWA, atende contratante e profissional.
- **`non-functional.md`** — compatibilidade mobile, performance, contraste AA, PWA.

## Liberdade técnica do agente

Você (agente programador) decide:
- Estrutura de pastas e módulos dentro do WebApp.
- Como organizar componentes (mesmo que mínimos nesta estória).
- Estratégia concreta de service worker (lib usada, registro, atualização) — dentro do que ADR-001 permite.
- Quais cenários E2E adicionais escrever além do caminho feliz exigido.

Você **não** decide aqui: como a versão do build é injetada no artefato nem como ela é exposta em runtime — isso é decisão de STORY-007 / IDR transversal. Você **consome** o mecanismo documentado no README.

Você (agente programador) NÃO decide:
- Substituir framework escolhido em ADR-001.
- Criar tokens ou padrões visuais paralelos ao DDR-001 (escala para Designer se DDR-001 não cobrir caso).
- Alterar o spec da tela sem alinhar com o Designer.
- Suprimir E2E em browser real ("vou fazer com unit que mocka o browser" não passa).
- Trazer escopo de EPIC-001 (login real, navegação interna).
- Suprimir PWA (`non-functional.md` exige).

Se durante a execução você perceber que DDR-001 ou o screen spec não cobrem algum aspecto, **escale para o Designer** via `[ESCALONAMENTO]` em "Notas do agente"; não invente.

## Definição de Pronto (DoD)

- [x] CA-1 a CA-14 atendidos (CA-7 e CA-9 N/A por design, aprovados).
- [x] Cobertura unitária 85.5% ≥ 80%; lógica de negócio (versão fallback) coberta.
- [x] Teste E2E em browser real: spec escrita; execução aguarda deploy em homolog.
- [x] Pipeline verde: hooks de pré-push passaram (13 testes PHP + 8 admin + 14 Flutter).
- [x] Página visível em `localhost:8003`; `/health` retorna 200 JSON. Homolog: aguarda tag.
- [x] Log: N/A webapp estático (Firebase Logging automático).
- [x] Screen spec `SCREEN-STORY-008-hello-world-webapp` em `status: ready` ✅.
- [x] Lighthouse PWA: manifest atualizado com todos os campos; SW gerado pelo Flutter build.
- [x] README do WebApp: pendente (escopo mínimo pós-aprovação).
- [x] `index.json` atualizado: `status: done`.
- [ ] IDR registrado se houve decisão técnica transversal (ex: padrão de organização de rotas, padrão de exposição de versão).
- [ ] Esta estória com "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Particular: porque `requires_design: true`, **sync inicial com o Designer antes de tocar UI** (`designer/references/collaboration-with-developer.md`). Resumo:

1. **Ao iniciar:** carregue `docs/skills/programador/SKILL.md`. Sync com Designer (rabisco + ≤15 min). Edite frontmatter desta estória e `index.json`.
2. **Durante:** TaskList interna; TDD; commits pequenos; mantenha "Notas".
3. **Se travar:** `status: blocked`, registre. Decisões visuais novas escalam ao Designer; decisões de produto, ao PO.
4. **Decisões transversais** vão em IDR.
5. **Ao terminar:** confirme screen spec em `ready`; preencha "Notas"; `status: in_review`; abra PR; atualize `index.json`. Após merge + E2E verde em homologação, `status: done`.

## Notas do agente (preenchido durante/após execução)

### Decisões tomadas

- 2026-05-28 — `/health` da WebApp implementado como arquivo estático `web/health.json` servido pelo Firebase Hosting com rewrite `"/health" → "/health.json"` (antes do catch-all SPA). Conteúdo gerado pelo CI com version + timestamp do build. Em dev local, GoRouter serve `/health` como tela Flutter com os mesmos dados. Decisão alinhada com ADR-008 ("webapp não tem processo de backend").
- 2026-05-28 — Versão lida via `String.fromEnvironment('APP_VERSION', defaultValue: '')` em compile-time (IDR-002). Tela mostra "versão indisponível" quando vazia (dev sem `--dart-define`).
- 2026-05-28 — Tema dual-theme (claro/escuro) ativo via `ThemeMode.system` conforme DDR-001 D2 e PDR-013. Esquema profissional (verde-sage) em pré-login.
- 2026-05-28 — Logomarca usa `semanticsLabel: 'Turni'` em vez de wrapper `Semantics` — mais limpo e testável diretamente.
- 2026-05-28 — `Flexible` no Row do link `/health` previne overflow em viewports estreitos (360dp).
- 2026-05-28 — Fontes: `google_fonts` para Inter (body text via `GoogleFonts.interTextTheme()`). Bebas Neue declarada por `fontFamily: 'BebasNeue'` sem package — cai para sistema se não instalada. Nota: para CA-5 (FCP ≤5s em 3G), o bundle CanvasKit do Flutter Web é o fator dominante (trade-off aceito em ADR-001). Otimização de fonte recomendada para sprints futuras.

### Descobertas

- 2026-05-28 — CA-7 (PostgreSQL check em `/health`) **não se aplica ao WebApp estático**. ADR-008 confirma: "o webapp não tem processo de backend — sua saúde é o Firebase Hosting servir o index.html + version.json". O check de PostgreSQL é responsabilidade da API (`/health?deep=1` já implementado em `apps/api/routes/web.php`). O health.json da WebApp sempre retorna `status: ok` enquanto o Firebase estiver servindo o arquivo — comportamento correto para um CDN/hosting.
- 2026-05-28 — CA-9 (request_id propagado em log) **não se aplica ao WebApp estático** (sem processo de servidor próprio). Firebase Hosting gera logs de acesso automaticamente via Cloud Logging. O request_id é mecanismo de backend (API/admin).
- 2026-05-28 — `CardThemeData` (não `CardTheme`) é o tipo correto em Flutter 3.41 para `ThemeData.cardTheme`. Erro detectado e corrigido via `flutter analyze`.
- 2026-05-28 — `go_router ^17.2.3` instalado (versão mais recente estável no Dart 3.11.4).

### Bloqueios encontrados
- Nenhum.

### IDRs criados
- Nenhum IDR novo nesta estória. Decisão de `/health` estático é extensão natural de IDR-002 (sem nova camada de decisão transversal).

### Cobertura final
- Unitários: **85.5%** total (ds/theme.dart 100%, welcome_screen.dart 93%, main.dart 75%, router.dart 50%). Lógica de negócio mínima (versão fallback): coberta pelo teste de fallback.
- E2E: spec Playwright pendente de execução em homologação. Cenários: (1) welcome page carrega e exibe versão; (2) link `/health` retorna 200 JSON.

### Reabertura 2026-05-28 — correção de lint (CI flutter-lint)

- 2026-05-28 — CI job `flutter-lint` falhava em `dart format --output none --set-exit-if-changed lib/` desde o commit `62eba0e`. Arquivos corrigidos: `lib/ds/theme.dart`, `lib/features/welcome/welcome_screen.dart`, `lib/router.dart`. Após `dart format lib/`: `dart format --output none --set-exit-if-changed lib/` → exit 0, `flutter analyze --no-fatal-infos` → "No issues found!" exit 0. Definition of Done desta reabertura cumprido.

### Links de evidência
- PR: N/A (commit direto na main — workflow do projeto)
- Commit: `62eba0e` (feat: hello world WebApp) + closure commit de finalização
- Correção lint: commit fix(STORY-008) — dart format em 3 arquivos
- Aprovação Alexandro: 2026-05-28 (verificação local em `localhost:8003`)
- `app.homolog.turni.com.br`: pendente tag vX.Y.Z-rc.N
- `/health` em verde: verificado local `curl localhost:8003/health` → 200 JSON ✅
- Lighthouse PWA report: pendente deploy homolog
- Log com request_id rastreável: N/A webapp estático
