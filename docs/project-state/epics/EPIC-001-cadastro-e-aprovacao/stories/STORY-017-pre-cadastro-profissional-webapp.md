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
status: ready
owner_agent: null
created_at: 2026-05-28
updated_at: 2026-05-28
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

- [ ] CA-1 a CA-14 passam com evidência.
- [ ] Cobertura unitária medida no PR.
- [ ] E2E verde na pipeline de homolog.
- [ ] LGPD: lista de campos coletados registrada.
- [ ] Sync Designer↔Programador registrado em "Notas".
- [ ] `index.json` atualizado.
- [ ] "Notas" preenchida.
- [ ] IDR se houve decisão técnica com impacto futuro.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Carregue `docs/skills/programador/SKILL.md`. Confirme screen spec do Designer em `ready` antes da UI. TDD nas regras. PR com evidência. `done` após deploy verde em homolog.

## Notas do agente (preenchido durante/após execução)

### Entrada inicial
(a preencher)

### Sync Designer↔Programador
(a preencher)

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
(a preencher — URL de homolog, screenshots, E2E run)

### Pendências para fechar
(a preencher)

### Links de evidência
(a preencher)
