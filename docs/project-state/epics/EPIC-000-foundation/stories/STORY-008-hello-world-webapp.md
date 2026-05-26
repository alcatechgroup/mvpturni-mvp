---
story_id: STORY-008
slug: hello-world-webapp
title: "Hello world" no WebApp — rota raiz, health-check e identidade visual base
epic_id: EPIC-000
sprint_id: null
type: implementation
target_role: programador
requires_design: true
design_screen_id: SCREEN-STORY-008-hello-world-webapp
status: ready
owner_agent: null
created_at: 2026-05-26
updated_at: 2026-05-26
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

- [ ] **CA-1:** `GET /` em `app.homolog.turni.com.br` retorna 200 com página HTML renderizando: nome "Turni", subtítulo curto coerente com a landing do protótipo, versão visível (formato `vX.Y.Z-rc.N`, lido da tag de deploy), e link explícito para `/health`.
- [ ] **CA-2:** A página aplica tokens do Design System de DDR-001 (tipografia, paleta, espaçamento) conforme spec do Designer em `design/screens/STORY-008-hello-world-webapp.md` (paths podem variar conforme convenção do Designer — siga o spec).
- [ ] **CA-3:** A página é **mobile-first** e respeita compatibilidade de `non-functional.md`: iOS Safari 15+, Android Chrome 100+ no mínimo; texto base ≥ 14px em mobile.
- [ ] **CA-4:** Contraste atende **WCAG 2.1 AA** (`quality-standards.md` seção 5).
- [ ] **CA-5:** Carregamento inicial em 3G simulado em ≤ 5s para FCP (`non-functional.md` performance). Carrega em ≤ 1.5s em conexão de escritório típica.

### Rota `/health`

- [ ] **CA-6:** `GET /health` retorna 200 com payload JSON (ou conforme ADR-008) contendo no mínimo: `status: "ok"`, `version: "<tag de deploy>"`, `timestamp: "<ISO 8601>"`, `service: "webapp"`.
- [ ] **CA-7:** Quando PostgreSQL está inacessível, `/health` retorna status ≥ 500 com payload descrevendo a dependência indisponível (sem vazar segredo). Verifica isso com teste de integração apontando para PostgreSQL desligado intencionalmente.
- [ ] **CA-8:** `/health` responde em ≤ 500ms p95 em condição normal (mais rápido se possível — é endpoint de probe).

### Observabilidade

- [ ] **CA-9:** Cada requisição produz log estruturado conforme ADR-008, com `request_id` único propagado no header de resposta. Validador / Programador consegue rastrear uma requisição feita em `app.homolog.turni.com.br` no log pelo id retornado.
- [ ] **CA-10:** Health-check externo configurado em STORY-007 vê `/health` verde após o deploy (evidência: log do probe).

### PWA

- [ ] **CA-11:** Manifesto PWA mínimo (`manifest.webmanifest` ou equivalente) servido com nome, ícone, tema, cor de fundo, modo display. Validação `Lighthouse PWA` em modo audit registra "installable" com 0 erros críticos para o nível MVP.
- [ ] **CA-12:** Service worker mínimo cacheando assets estáticos (HTML, CSS, JS, ícones). Estratégia conservadora (network-first para HTML, cache-first para assets) — fora do escopo: cache de dados de API.

### Testes

- [ ] **CA-13:** Teste E2E em **browser real** (ferramenta definida em ADR-001) percorre em homologação: abre `app.homolog.turni.com.br`, vê página inicial carregada, vê versão exibida, clica no link de `/health`, recebe 200. Falha do E2E em homologação bloqueia o épico fechar.
- [ ] **CA-14:** Testes unitários cobrem ≥ 80% do código novo desta estória; lógica que serializa o payload de `/health` ou que monta versão exibida (regra de negócio mínima) tem cobertura ≥ 98%.

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
- Como ler a versão do build em runtime (variável de ambiente, arquivo gerado no build, etc).
- Quais cenários E2E adicionais escrever além do caminho feliz exigido.

Você (agente programador) NÃO decide:
- Substituir framework escolhido em ADR-001.
- Criar tokens ou padrões visuais paralelos ao DDR-001 (escala para Designer se DDR-001 não cobrir caso).
- Alterar o spec da tela sem alinhar com o Designer.
- Suprimir E2E em browser real ("vou fazer com unit que mocka o browser" não passa).
- Trazer escopo de EPIC-001 (login real, navegação interna).
- Suprimir PWA (`non-functional.md` exige).

Se durante a execução você perceber que DDR-001 ou o screen spec não cobrem algum aspecto, **escale para o Designer** via `[ESCALONAMENTO]` em "Notas do agente"; não invente.

## Definição de Pronto (DoD)

- [ ] CA-1 a CA-14 atendidos.
- [ ] Cobertura unitária ≥ 80% no código novo, ≥ 98% na lógica de negócio mínima desta estória.
- [ ] Teste E2E em browser real escrito, passando em homologação contra `app.homolog.turni.com.br`.
- [ ] Pipeline verde no PR; tag `-rc.N` cria deploy verde em ≤ 10 min (parte da métrica primária do épico — evidência em STORY-007 ou nesta estória).
- [ ] Página visível em `app.homolog.turni.com.br`; `/health` retorna 200.
- [ ] Log de uma requisição feita rastreável pelo request_id.
- [ ] Screen spec do Designer em `design.screens[].status: ready` antes do `in_review` desta estória (invariante 9 de `indexing.md`).
- [ ] Lighthouse PWA: "installable" sem erro crítico.
- [ ] README do WebApp atualizado (como rodar local, como acessar `/health`, como ler logs).
- [ ] `index.json` atualizado: `story.status = in_review` ao abrir PR; `done` após merge + deploy + E2E verde.
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
- <data> — <decisão local>

### Descobertas
- <data> — <surpresa / gotcha>

### Bloqueios encontrados
- <data> — <bloqueio>

### IDRs criados
- IDR-XXX — <título>

### Cobertura final
- Unitários: <%>
- E2E: <cenários, link para evidência em homologação>

### Links de evidência
- PR: <url>
- Pipeline / deploy: <url>
- `app.homolog.turni.com.br` (screenshot ou link com timestamp): <link>
- `/health` em verde: <link>
- Lighthouse PWA report: <link>
- Log com request_id rastreável: <link>
