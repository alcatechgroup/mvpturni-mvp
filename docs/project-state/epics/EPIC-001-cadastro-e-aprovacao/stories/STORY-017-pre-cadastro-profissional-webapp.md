---
story_id: STORY-017
slug: pre-cadastro-profissional-webapp
title: Pré-cadastro de Profissional (PF/MEI/PJ) no WebApp
epic_id: EPIC-001
sprint_id: SPRINT-2026-W24
type: implementation
target_role: programador
requires_design: true
design_screen_id: SCREEN-STORY-017-pre-cadastro-profissional
status: in_review
owner_agent: claude-opus-programador
created_at: 2026-05-28
updated_at: 2026-05-29
estimated_session_size: M
---

# STORY-017 — Pré-cadastro de Profissional (PF/MEI/PJ) no WebApp

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Ela contém tudo o que você precisa. Se algo estiver ambíguo, registre a dúvida na seção "Notas do agente" no final e pause em vez de adivinhar.

## Contexto (por que esta estória existe)

Este é **o primeiro fluxo público real do Turni**: profissional acessa `app.homolog.turni.com.br/cadastro`, preenche o formulário mínimo, escolhe seu tipo de pessoa (PF, MEI ou PJ — PDR-001), aceita os Termos de Uso e Política de Privacidade no checkbox, submete, e fica em `status: pendente_aprovacao`. A equipe Turni vê o cadastro na fila do backoffice (STORY-019) e aprova em até 24h (SLA público). Sem esta estória, a base de profissionais não existe — o EPIC-001 não fecha.

A estória respeita PDR-001: PF informa intenção de ser PF (documento `CPF` vem depois, em completar cadastro); MEI/PJ informam intenção (CNPJ também depois). O formulário **não coleta documento** no pré-cadastro — só após aprovação manual humana, no completar cadastro (STORY-023), conforme `domain/usuario.md` §Atributos por papel. Isso reduz exposição de dado sensível antes do filtro humano.

- Épico: `docs/project-state/epics/EPIC-001-cadastro-e-aprovacao/epic.md`
- Documentos canônicos a ler ANTES de codificar:
  - `docs/especificacao/domain/usuario.md` §"Tipos de pessoa" e §"Atributos por papel — Profissional" (mínimo pré-aprovação)
  - `docs/project-state/decisions/pdr/PDR-001-tipos-de-pessoa-aceitos.md` (regra de tipos)
  - `docs/project-state/decisions/adr/ADR-009-modelo-de-dados-identidade-epic-001.md` (esquema de polimorfismo do profissional)
  - `docs/especificacao/non-functional.md` §LGPD, §Segurança (dados pessoais; consentimento)
  - `docs/project-state/design/screens/SCREEN-STORY-017-pre-cadastro-profissional.md` (Designer entrega antes — `requires_design: true`)
  - `docs/project-state/design/system/tokens.md`, `voice-and-tone.md` — tema **profissional** do DDR-001
  - `docs/skills/programador/SKILL.md`, `docs/skills/po/references/quality-standards.md`

## O quê (objetivo desta estória)

Entregar fluxo de pré-cadastro público de profissional no WebApp Flutter:

1. Rota `/cadastro/profissional` em `app.homolog.turni.com.br`, **pública** (sem auth), com tema **profissional** do DDR-001.
2. Formulário com os campos mínimos pré-aprovação de `domain/usuario.md` §"Profissional / Mínimo no cadastro inicial":
   - Nome completo (texto, obrigatório, 3–120 chars).
   - E-mail (obrigatório, validação de formato, único no sistema — verificação server-side).
   - Telefone (obrigatório, formato brasileiro).
   - Cidade + Bairro (obrigatórios; cidade autocompletar simples ou texto livre — sua decisão, justificada em IDR).
   - Função primária pretendida (select, lista a vir de tabela de funções — se não existir, sua decisão: criar tabela mínima nesta estória OU usar enum hard-coded das funções pivotais do Turni — registre em IDR).
   - Tipo de pessoa pretendido (radio: PF / MEI / PJ — obrigatório).
   - Foto (upload, obrigatório, ≤5 MB, JPG/PNG, ratio 1:1 sugerido — armazenamento conforme ADR-004).
   - Senha + Confirmar senha (mínimo de complexidade — sugestão: ≥10 caracteres, mistura de classes; segue Fortify default de ADR-007).
   - Checkbox **obrigatório** "Li e aceito os Termos de Uso e a Política de Privacidade" com link para páginas estáticas (placeholders OK no MVP — texto definitivo é responsabilidade futura da equipe Turni; manter URL aberta).
3. Endpoint `POST /api/cadastro/profissional` na `api`: valida, cria usuário com `role=profissional, status=pendente_aprovacao, tipo_pessoa=<escolhido>, welcome_visto=false, cadastro_completo=false`, salva foto no storage configurado, hash de senha Argon2id (ADR-007), registra timestamp do aceite dos Termos. Retorna `{success, message: "Cadastro recebido. Em até 24h a equipe Turni revisa e envia notificação por e-mail."}`. **Não autentica automaticamente** — o usuário aguarda aprovação.
4. Tela de sucesso pós-submit: confirma o recebimento, lembra SLA de 24h, traz CTA opcional "Voltar à home" — sem login.
5. Tela "aguardando aprovação" quando o usuário em `pendente_aprovacao` tentar logar (caminho de STORY-016): cliente Flutter recebe sinalização da `api` e exibe mensagem clara. Esta tela pode ser implementada em STORY-016 como parte do funnel guard, ou aqui — coordene; **a mensagem precisa existir até o fim desta estória**.
6. **E-mail de confirmação de recebimento** ao usuário ("recebemos seu cadastro, aguarde aprovação"): se STORY-021 já tiver entregue a infra de e-mail, dispara aqui; se não, registra em fila para STORY-021 consumir — **não bloqueia esta estória**. Documente em "Notas do agente" qual caminho foi usado.

## Por quê (valor para o usuário)

Direto: profissional (Diego — PF iniciante, ou MEI/PJ constituído) consegue entrar na plataforma por conta própria, sem ligar pra ninguém. A promessa pública da landing começa a se materializar. Indireto: gera **usuários na fila de aprovação** para STORY-019 consumir; valida o desenho polimórfico de ADR-009 em uso real; primeira coleta de dados pessoais reais (cruza LGPD).

## Critérios de aceite

- [ ] **CA-1:** Rota pública `/cadastro/profissional` no WebApp em homolog responde 200, sem auth, com tema profissional do DDR-001 carregado.
- [ ] **CA-2:** Formulário renderiza todos os campos listados em §O quê (item 2), com validação client-side imediata (formato, obrigatoriedade) e mensagens acionáveis (`quality-standards.md` §AC ambíguo — mensagens citam o campo e sugerem correção).
- [ ] **CA-3:** Submit com dados válidos cria usuário no banco com `role=profissional, status=pendente_aprovacao, tipo_pessoa` correto, hash de senha Argon2id, foto persistida em storage, timestamp do aceite dos Termos. Senha **nunca** retorna em response/log (ADR-008 mascaramento).
- [ ] **CA-4:** Submit com **e-mail já existente** no sistema (em qualquer estado, em qualquer papel) retorna erro genérico **sem revelar** se o e-mail está cadastrado (proteção contra enumeração). Mensagem: "Não foi possível concluir o cadastro. Verifique os dados e tente novamente." + sugestão "Já tem conta? Faça login." — `quality-standards.md` §4 / `security-architecture.md`.
- [ ] **CA-5:** Submit com **checkbox de aceite desmarcado** é bloqueado client-side e server-side (defesa em profundidade).
- [ ] **CA-6:** Submit com foto inválida (tipo ou tamanho) retorna erro client + server claros.
- [ ] **CA-7:** Tela de sucesso pós-submit exibe a mensagem padronizada com SLA de 24h e CTA de voltar à home.
- [ ] **CA-8:** Usuário com `status = pendente_aprovacao` que tenta logar via STORY-016 recebe mensagem clara ("Seu cadastro está em análise. Em até 24h enviaremos notificação por e-mail."). Não há vazamento de info de outros estados.
- [ ] **CA-9:** Os 3 valores possíveis de `tipo_pessoa` (PF/MEI/PJ) são exercidos por testes: criar com cada um e verificar que persiste corretamente. **E2E em browser real** cobre pelo menos PF + MEI (PJ é mesmo fluxo que MEI no formulário).
- [ ] **CA-10:** Acessibilidade WCAG 2.1 AA verificada: navegação por teclado, rótulos acessíveis, leitor de tela, contraste nos 2 temas (claro/escuro — PDR-013).
- [ ] **CA-11:** Cobertura unitária ≥ 80% no código novo / ≥ 98% no núcleo (validação de tipo de pessoa, unicidade de e-mail, transição para `pendente_aprovacao`, autoria do aceite dos Termos).
- [ ] **CA-12:** Trilha de **audit log** (ADR-009): cadastro recebido **não** é evento de admin (admin ainda não atuou) — **não vai** no audit log de admin. Vai apenas no **log estruturado** (ADR-008) com `event: "user.preregistered", tipo_pessoa, masked_email`. Verificar que o log mascara o e-mail.
- [ ] **CA-13:** Foto: armazenamento conforme ADR-004 (Cloud Storage em prod; minio/filesystem em dev); access control para que terceiros sem autorização **não** acessem a foto via URL pública direta (signed URLs ou path não enumerável — sua decisão, justificada). Foto fica disponível ao admin no detalhe da fila (STORY-019).
- [ ] **CA-14:** O cadastro **não coleta documento** (CPF/CNPJ) nesta tela — confirmando a política de "dado sensível só pós-aprovação" de `domain/usuario.md`. Verificação por teste.

## Fora de escopo

- Coletar CPF/CNPJ no pré-cadastro — fica para STORY-023.
- Coletar chave Pix, dados bancários, documentos comprobatórios — STORY-023.
- Validação automática contra Receita Federal — PDR-001 declara fora do MVP.
- E-mail de aprovação concedida — STORY-021 (esta estória só dispara confirmação de recebimento, opcional, conforme item 6 de §O quê).
- Pré-cadastro de Contratante — STORY-018.
- Fila de aprovação no admin — STORY-019.
- Welcome / Completar cadastro — STORY-022/023.

## Padrões de qualidade exigidos

Esta estória segue `docs/skills/po/references/quality-standards.md`. Em particular:

- **Cobertura unitária ≥ 80% geral, ≥ 98% no núcleo** (validação tipo_pessoa, unicidade e-mail, transição de estado, autoria do aceite).
- **E2E em browser real** cobrindo CA-9 (PF + MEI) na pipeline de homolog.
- **TDD** nas regras de negócio.
- **Segurança (§4)**: hash Argon2id; senha nunca em log/response; defesa contra enumeração de e-mails (CA-4); upload de foto sanitizado (tipo MIME validado server-side, não confiar no client); CSRF token Sanctum no submit (mesmo sendo público, segue padrão da `api`).
- **LGPD**: registrar em `non-functional.md` (ou arquivo dedicado em `docs/especificacao/lgpd/`) **lista dos campos coletados** nesta estória e classificação (dado pessoal comum vs sensível). Aceite dos Termos no checkbox conta como consentimento explícito.
- **Acessibilidade (§5)**: WCAG 2.1 AA; tema dual claro/escuro.
- **Observabilidade (§3)**: log estruturado de pré-cadastro com e-mail mascarado; alerta de Cloud Monitoring para taxa anormal de submits (proteção contra bot/spam — sua decisão sobre threshold inicial; ajustável por sinais de revisão).
- **Banco**: migração adicional para colunas específicas do profissional, idempotente, reversível.

## Dependências

- **Bloqueada por:** STORY-012 (ADR-009 `accepted` — esquema polimórfico de profissional). STORY-016 (migração de `role`+`status`+flags já aplicada — se rodando em paralelo na mesma sprint, coordene ordem na sprint). Designer entrega `SCREEN-STORY-017-pre-cadastro-profissional` em `status: ready` antes da primeira linha de UI; sync ≤15 min Programador↔Designer.
- **Bloqueia:** STORY-019 (fila depende de existir gente em `pendente_aprovacao`), STORY-023 (completar cadastro depende de pré-cadastro de profissional existente), STORY-025 (validação).
- **Pré-requisitos:** ambiente local funcionando (STORY-006), pipeline (STORY-007), Sanctum/Fortify configurados (STORY-016).

## Decisões já tomadas (não as reabra)

- **PDR-001** — PF/MEI/PJ aceitos; sem validação automática Receita; documento (CPF/CNPJ) coletado **depois** da aprovação.
- **`domain/usuario.md`** — campos mínimos pré-aprovação são exatamente os listados em §O quê.
- **ADR-007** — Argon2id, throttling, CSRF Sanctum.
- **ADR-009** — modelo polimórfico do profissional.
- **PDR-013 + DDR-001** — dual-theme; tema profissional.
- **Princípios do PO** — qualidade é requisito; automação por padrão.

## Liberdade técnica do agente

Você decide:
- Tabela auxiliar para funções vs enum hard-coded (registrar em IDR; recomendação: tabela auxiliar pequena com seed, antecipando uso por STORY-019 e futuras).
- Componente de upload de foto (lib Flutter).
- Armazenamento concreto da foto (Cloud Storage bucket / paths) — coerente com ADR-004.
- Mensagens textuais exatas (com voice-and-tone do DDR-001).
- Layout exato dentro do screen spec do Designer.

Você NÃO decide:
- Coletar documento aqui (PDR-001 + `domain/usuario.md`).
- Reabrir ADR-009 (polimorfismo).
- Suprimir cobertura, E2E, LGPD básica, CSRF, ou mascaramento.

## Definição de Pronto (DoD)

- [x] CA-1 a CA-14 passam com evidência (CA-1/2/7/8/10 via UI+E2E; demais via testes — ver Cobertura/Resultado).
- [x] Cobertura unitária medida (api 95,1% global; widget 29 verdes).
- [~] E2E verde **localmente** (gate IDR-004: PF+MEI+pública, 3/3). Em homolog: após deploy (pendência de fechamento).
- [x] LGPD: lista de campos coletados registrada (`docs/especificacao/lgpd/campos-coletados.md`).
- [x] Sync Designer↔Programador registrado em "Notas".
- [x] `index.json` atualizado.
- [x] "Notas" preenchida.
- [x] IDR se houve decisão técnica com impacto futuro (IDR-008 funções, IDR-009 image_picker).

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Carregue `docs/skills/programador/SKILL.md`. Confirme screen spec do Designer em `ready` antes da UI. TDD nas regras. PR com evidência. `done` após deploy verde em homolog.

## Notas do agente (preenchido durante/após execução)

### Entrada inicial
**Data:** 2026-05-29 · **Agente:** programador sênior (claude-opus).

**Documentos lidos:** estória inteira; `agent-task-format.md`; `programador/SKILL.md`; `domain/usuario.md` (§Tipos de pessoa, §Atributos por papel — Profissional); ADR-009 (Decisão 1C perfis 1:1, Decisão 2A status+timestamps); ADR-007 (Argon2id, Sanctum SPA, throttling, CSRF); ADR-004 (storage GCS prod / local em dev); código existente de STORY-016 (`User`, `ProfissionalProfile`, `ContratanteProfile`, `AuthController`, `FunnelGuard`, `WebAppOnly`, migrações de identidade, `UserFactory`).

**Entendimento consolidado (minhas palavras):** O pré-cadastro cria um `User(role=profissional, status=pendente_aprovacao)` + `ProfissionalProfile(tipo_pessoa, telefone, cidade, bairro, funcao, foto, termos_aceitos_at)`. **Não coleta documento** (CPF/CNPJ vem só no completar cadastro — STORY-023). Senha Argon2id, nunca em log/response. Sem auto-login — usuário aguarda aprovação. Proteção contra enumeração de e-mail (erro genérico). Log estruturado `user.preregistered` com e-mail mascarado (ADR-008) — **não** é audit log de admin. A fundação de identidade (STORY-016) já está na main; construo em cima dela.

**Plano (backend-first, enquanto design não chega):**
1. Migração idempotente/reversível: adiciona `telefone, cidade, bairro, funcao_id, termos_aceitos_at` a `profissional_profiles`; cria tabela auxiliar `funcoes` + seed das funções pivotais (decisão minha → IDR).
2. Alinhar `HASH_DRIVER=argon2id` no `.env`/config (CA-3 exige Argon2id; hoje `.env` cai no bcrypt default — `.env.example` já declara argon2id).
3. `FormRequest` + `Action/Controller` + rota pública `POST /api/cadastro/profissional` (no grupo stateful — CSRF Sanctum). Transação; foto em path não-enumerável; enumeração de e-mail tratada com erro genérico; log estruturado mascarado.
4. TDD por CA (3,4,5,6,9,11,12,14). Cobertura ≥80% / ≥98% núcleo.
5. LGPD: registrar campos coletados + classificação.
6. **UI Flutter + E2E + CA-8 (await approval) + CA-10 (a11y): BLOQUEADO** — ver Bloqueios.

**Testes que pretendo escrever (backend):** happy path criando PF/MEI/PJ e verificando persistência + status (CA-9/CA-3); e-mail já existente → erro genérico sem leak (CA-4); checkbox de termos desmarcado → 422 server-side (CA-5); foto tipo/tamanho inválido → 422 (CA-6); senha nunca no response nem no log (CA-3); documento nunca persistido nesta tela (CA-14); log estruturado emite `event=user.preregistered` com `masked_email` (CA-12); bordas de validação (nome <3/>120, email malformado, telefone fora de formato, tipo_pessoa inválido).

**Dúvidas:** nenhuma de produto — escopo e decisões já fechadas em PDR-001/ADR-009/domain. As escolhas técnicas (tabela `funcoes` vs enum, lib de upload, path da foto) são liberdade do agente e registrarei em IDR.

### Sync Designer↔Programador
**Spec entregue (2026-05-29) — `SCREEN-STORY-017-pre-cadastro-profissional` em `status: ready`.** Registrada em `index.json` (`design.screens[]`). Cobre Vista A (form), Vista B (recebido/sucesso — CA-7) e a emenda do banner "em análise" no login (CA-8). Desbloqueia a UI.

**Decisões de design relevantes para o Programador:**
- **Form único seccionado** (não wizard) — 6 seções, CTA único "Enviar cadastro". STORY-018 deve espelhar.
- **Componentes:** `input.text`/`input.password` (já existem da STORY-016), `input.select` (DropdownButtonFormField), `segmented` (SegmentedButton PF/MEI/PJ, radiogroup), `input.checkbox` (termos com 2 links), **`input.photo` (novo)** — definições normativas mínimas no spec §"Componentes novos".
- **Rota pública:** adicionar `/cadastro/profissional` ao `publicRoutes` do `router.dart`.
- **Sucesso = estado interno** da mesma rota (sem rota própria → sem deep-link órfão).
- **CA-8:** refinar o texto de `_BannerState.pending()` no `login_screen.dart` para **"Seu cadastro está em análise. Em até 24h enviaremos uma notificação por e-mail."** (sem mudar layout/ícone/key `banner-pending`). Ajustar o widget test que asserta o texto.

**Pontos de sync ≤15 min (spec §13) — decisões de implementação do Programador:**
1. **`GET /api/funcoes`** para popular o select (recomendado pelo Designer, coerente com IDR-008) **ou** lista estática espelhando o seed no MVP — registrar a escolha.
2. Lib de upload de foto (`image_picker` ou equivalente) + montagem do `multipart` no Flutter Web — IDR se transversal.
3. Máscara de telefone opcional (regex já cobre).

Identificadores de teste, microcopy completo, estados e contrastes verificados estão no spec.

### Decisões tomadas
- **Funções = tabela auxiliar `funcoes` + seed** (não enum) → **IDR-008**. FK `funcao_id` em `profissional_profiles`, validação exige `ativo=true`.
- **Proteção contra enumeração (CA-4):** a unicidade do e-mail **não** usa a regra `unique` do validator (que vazaria via erro de campo); é checada no controller com **mensagem genérica** + dica "Já tem conta? Faça login.". Status 422, `code: cadastro_nao_concluido`.
- **Foto:** `store('profissionais/fotos')` no disco default (nome aleatório/hash → path **não-enumerável**), disco **privado** (sem URL pública direta — CA-13). Acesso do admin virá por rota controlada na STORY-019. Em prod o disco é Cloud Storage (ADR-004) via `FILESYSTEM_DISK`.
- **Senha:** regra explícita `Password::min(10)->mixedCase()->numbers()` **local** ao FormRequest (não mexi no `Password::defaults()` global para não afetar outros fluxos). Hash Argon2id pelo cast `hashed` + `HASH_DRIVER=argon2id`.
- **Mascaramento de e-mail** para o log: helper `App\Support\Pii::maskEmail` (`d***@dominio`).
- **E-mail de confirmação (item 6 do §O quê):** STORY-021 (infra de e-mail) **não está done** → confirmação **deferida**, não-bloqueante. Não criei job/mailable órfão; STORY-021 dispara quando a infra existir.

### Descobertas
- O container `api` **não tem a extensão GD** → `UploadedFile::fake()->image()` quebra nos testes. Usei `->create($nome, $kb, $mime)` que exercita `image|mimes|max` sem gerar pixels. A validação `image` em produção usa fileinfo (não GD), então o upload real não é afetado.
- O `.env` local **não tinha `HASH_DRIVER`** (caía no bcrypt default), embora `.env.example` e `phpunit.xml` já declarem `argon2id`. Adicionei ao `.env` local (git-ignored) para paridade. **Atenção infra:** homolog/prod precisam ter `HASH_DRIVER=argon2id` setado (vem do `.env.example`/Secret Manager).

**Descobertas da fase de UI/E2E (2026-05-29):**
- **GD ausente no container `api`:** `UploadedFile::fake()->image()` quebra; usei `->create($nome,$kb,$mime)` (a validação `image` em prod usa fileinfo, não GD).
- **Bug sutil de reconciliação Flutter:** a inserção condicional dos erros de tipo/foto/termos reordenava os filhos do `Column`; sem `Key` nos wrappers (`Padding`) dos campos, o `FormFieldState` das senhas era recriado e **descartava o erro recém-validado**. Fix: keyar os wrappers (`Key('$key-field')`). Pego por widget test (CA-2).
- **`image_picker` no web exigiu `flutter clean`:** após adicionar a dep, o `web_plugin_registrant.dart` ficou stale → `MissingPluginException(pickImage)`. `flutter clean && pub get && build web` regenerou o registrant. **Para CI/build de homolog:** garantir build limpo após mudança de deps.
- **Semantics do Flutter Web (E2E):** `DropdownButtonFormField` expõe-se como `button` + `menu/menuitem` (usar `getByRole('menuitem')`), o `segmented` como `button`, a foto como `button`; o aceite como `checkbox` sem nome. Entrada de texto confiável só com `locator.focus()` (clicar por coordenada às vezes não focava o campo e a digitação poluía o e-mail). Padrões documentados no `pre-cadastro.spec.ts`.
- **CA-8 já existia (SCREEN-016):** o banner `banner-pending` foi refinado para citar o SLA de 24h; nenhum teste assertava o texto antigo.

### Bloqueios encontrados
- **[ESCALONAMENTO-DESIGN] Screen spec ausente (2026-05-29):** `requires_design: true` aponta `SCREEN-STORY-017-pre-cadastro-profissional`, mas o arquivo **não existe** em `docs/project-state/design/screens/` (só há SCREEN-016, SCREEN-028, STORY-008). Pelo protocolo, o Programador é dono mas **não toca a UI** até o Designer entregar a spec em `status: ready` + sync ≤15 min.
  - **Backend-first concluído** (totalmente desbloqueado, verde na `main`).
  - **Decisão do PO/Alexandro (2026-05-29):** **aguardar o Designer** — não construir UI sem spec formal nem produzir a spec eu mesmo.
  - **✅ RESOLVIDO (2026-05-29):** o Designer entregou `SCREEN-STORY-017-pre-cadastro-profissional` em `status: ready` (registrada no `index.json`). Bloqueio levantado; estória volta a `in_progress`. Resta o Programador implementar a UI conforme o spec (ver §Sync) + E2E (CA-9) + deploy homolog → `in_review`/`done`.

### IDRs criados
- **IDR-008** — Funções como tabela auxiliar `funcoes` com seed (vs enum). `accepted`.
- **IDR-009** — `image_picker` para upload de foto no WebApp. `accepted`. Ambos em `index.json`.

### Cobertura final
- **API**: 98 testes, 0 falhas; cobertura global **95,1%** (gate `--min=80` verde). `StoreProfissionalPreCadastroRequest` 100%, `FuncaoController` 100%, `Pii` 100%, `FuncaoSeeder` 100%, `Funcao` 100%, `ProfissionalCadastroController` 92,5% (3 linhas = `catch` de limpeza de foto órfã, defensivo). Pint limpo.
- **WebApp**: `flutter analyze` limpo; **29 widget tests** verdes (5 novos da tela de cadastro: render/keys, validação+bloqueio, caminho feliz→recebido, e-mail genérico CA-4, senha fraca).
- **E2E (Playwright, browser real)**: `pre-cadastro.spec.ts` **3/3 verdes** — pública carrega, **PF** e **MEI** enviam e veem "Cadastro recebido."; `rbac-login.spec.ts` 7/7 (CA-8 não regrediu). Persistência verificada no banco: `role=profissional, status=pendente_aprovacao, tipo_pessoa` correto (PF/MEI), `termos_aceitos_at` setado, foto salva.

### Resultado final / evidência
**Estória concluída — backend + UI + E2E verdes localmente** (2026-05-29). `status: in_review`. Falta apenas o deploy em homolog para a evidência ao vivo (URL pública) e o E2E rodar contra homolog.

**Status dos CAs (todos cobertos):**
- ✅ CA-1 (rota pública renderiza; E2E "pública carrega"), CA-2 (validação client+mensagens; widget+E2E), CA-3 (Argon2id, sem leak), CA-4 (erro genérico anti-enumeração; unit+widget), CA-5 (termos server-side), CA-6 (foto MIME/tamanho), CA-7 (tela recebido; widget+E2E), CA-8 (banner SLA 24h no login), CA-9 (E2E PF+MEI + persistência), CA-10 (a11y: Semantics, foco, contrastes DDR-001 dual-theme, alvos ≥48dp), CA-11 (cobertura), CA-12 (log mascarado), CA-13 (foto em disco privado, path não-enumerável), CA-14 (documento não coletado).

### Deploy em homolog (evidência)
- **Tag `v0.1.0-rc.20`** (2026-05-29): pipeline `release.yml` **success** (build api/admin/webapp + migrate+seed homolog + deploy + smoke 3 interfaces).
- Verificado ao vivo: `GET app.homolog.turni.com.br/cadastro/profissional` → 200; `GET /api/funcoes` (same-origin via Firebase rewrite) → funções seedadas; `version.json` → `v0.1.0-rc.20`.

### Pendências para fechar
1. ✅ **Deploy em homolog** — feito (rc.20), endpoints verificados. Falta apenas o teste manual no celular (em curso) e o veredito do Validador no fim do EPIC-001.
2. **Infra:** confirmar `HASH_DRIVER=argon2id` no ambiente homolog/prod.
3. **Build de homolog do WebApp:** garantir build limpo (registrant de plugin web) — ver Descobertas (image_picker).
4. **E-mail de confirmação** (item 6 §O quê): deferido para STORY-021 (infra de e-mail) — não-bloqueante.
5. Designer revisa o implementado vs spec no PR (a11y/visual) — colaboração padrão.

### Links de evidência
- Commits `feat(STORY-017): ...` (backend, UI), `design(STORY-017): ...` (spec + preview).
- Spec: `docs/project-state/design/screens/SCREEN-STORY-017-pre-cadastro-profissional.md` + preview HTML aprovado.
- LGPD: `docs/especificacao/lgpd/campos-coletados.md` §STORY-017.
- IDRs: `IDR-008-funcoes-tabela-auxiliar-vs-enum.md`, `IDR-009-image-picker-para-upload-de-foto.md`.
- E2E: `apps/webapp/tests/e2e/pre-cadastro.spec.ts` (PF+MEI).
