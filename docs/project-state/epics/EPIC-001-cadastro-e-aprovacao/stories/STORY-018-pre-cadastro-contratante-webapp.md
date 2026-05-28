---
story_id: STORY-018
slug: pre-cadastro-contratante-webapp
title: Pré-cadastro de Contratante no WebApp
epic_id: EPIC-001
sprint_id: SPRINT-2026-W24
type: implementation
target_role: programador
requires_design: true
design_screen_id: SCREEN-STORY-018-pre-cadastro-contratante
status: ready
owner_agent: null
created_at: 2026-05-28
updated_at: 2026-05-28
estimated_session_size: M
---

# STORY-018 — Pré-cadastro de Contratante no WebApp

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Ela contém tudo o que você precisa. Se algo estiver ambíguo, registre a dúvida na seção "Notas do agente" no final e pause em vez de adivinhar.

## Contexto (por que esta estória existe)

Junto com STORY-017 (profissional), esta é a outra metade da entrada pública no Turni: o **contratante** (estabelecimento — bar, restaurante, hotel, evento, catering) acessa `app.homolog.turni.com.br/cadastro/contratante`, preenche dados mínimos do responsável + do estabelecimento, aceita Termos, submete, e fica em `pendente_aprovacao`. Sem cadastro de contratante, o profissional não tem para quem trabalhar — o ciclo de match (EPIC-002) não existe.

Diferente do profissional: contratante é **sempre PJ** (CNPJ obrigatório no completar cadastro, conforme `domain/usuario.md`); **não há `tipo_pessoa`** para contratante; o template contratual aplicável é sempre **MEI/PJ B2B** (STORY-015); o tema visual aplicado é o **contratante** do DDR-001.

- Épico: `docs/project-state/epics/EPIC-001-cadastro-e-aprovacao/epic.md`
- Documentos canônicos a ler ANTES de codificar:
  - `docs/especificacao/domain/usuario.md` §"Tipos de pessoa" (contratante sempre PJ) e §"Atributos por papel — Contratante / Mínimo no cadastro inicial"
  - `docs/project-state/decisions/adr/ADR-009-modelo-de-dados-identidade-epic-001.md`
  - `docs/especificacao/non-functional.md` §LGPD, §Segurança
  - `docs/project-state/design/screens/SCREEN-STORY-018-pre-cadastro-contratante.md` (Designer entrega antes)
  - `docs/project-state/design/system/tokens.md` — tema **contratante**
  - `docs/skills/programador/SKILL.md`, `docs/skills/po/references/quality-standards.md`
  - STORY-017 (mesmo padrão técnico — útil como referência de implementação)

## O quê (objetivo desta estória)

Entregar fluxo de pré-cadastro público de contratante no WebApp Flutter:

1. Rota `/cadastro/contratante` em `app.homolog.turni.com.br`, **pública** (sem auth), com tema **contratante** do DDR-001.
2. Formulário com os campos mínimos pré-aprovação de `domain/usuario.md` §"Contratante / Mínimo no cadastro inicial":
   - Nome do responsável (texto, obrigatório, 3–120 chars).
   - E-mail (obrigatório, formato válido, único no sistema — verificação server-side).
   - Telefone (obrigatório, formato brasileiro).
   - Nome do estabelecimento (texto, obrigatório, 2–200 chars).
   - Tipo de operação (select obrigatório — opções: `restaurante`, `bar`, `hotel`, `evento`, `catering`, `outro`).
   - Cidade (obrigatório).
   - Foto/avatar do responsável (upload, obrigatório, ≤5 MB, JPG/PNG; mesma estratégia de armazenamento de STORY-017).
   - Senha + Confirmar senha (mesma régua de STORY-017 — Argon2id, complexidade mínima).
   - Checkbox **obrigatório** "Li e aceito os Termos de Uso e a Política de Privacidade" + link.
3. Endpoint `POST /api/cadastro/contratante` na `api`: valida, cria usuário com `role=contratante, status=pendente_aprovacao, welcome_visto=false, cadastro_completo=false`, salva foto, hash Argon2id, registra aceite dos Termos. Retorna `{success, message: "Cadastro recebido. Em até 24h a equipe Turni revisa e envia notificação por e-mail."}`. **Não autentica automaticamente** — aguarda aprovação.
4. Tela de sucesso pós-submit (mesmo padrão de STORY-017 com mensagem adaptada ao perfil contratante).
5. Tela "aguardando aprovação" quando contratante em `pendente_aprovacao` tentar logar — reutiliza a infra do funnel guard de STORY-016 (a tela e o caminho são os mesmos; só o tema/voice difere se houver diferenciação por perfil — alinhar com Designer).
6. **E-mail de confirmação de recebimento** (mesma condição de STORY-017 — se STORY-021 entregou infra de e-mail, envia; senão, registra para STORY-021 consumir).

## Por quê (valor para o usuário)

Direto: contratante (Maria — sócia de bar, persona da landing) consegue abrir conta sozinha, sem ligação. Sem essa entrada, não há demanda no marketplace — o profissional cadastrado em STORY-017 não tem para quem se candidatar. Indireto: gera **usuários na fila de aprovação** com perfil distinto para validar que a UI da fila (STORY-019) lida com os dois perfis; primeira coleta real de dado de estabelecimento (futuro Member Start gratuito por padrão — `domain/usuario.md` §"Contratante" planos).

## Critérios de aceite

- [ ] **CA-1:** Rota pública `/cadastro/contratante` no WebApp em homolog responde 200, sem auth, com tema contratante do DDR-001.
- [ ] **CA-2:** Formulário renderiza todos os campos listados em §O quê (item 2), com validação client-side e mensagens acionáveis.
- [ ] **CA-3:** Submit válido cria usuário com `role=contratante, status=pendente_aprovacao`, hash Argon2id, foto persistida, timestamp do aceite. Senha nunca em log/response.
- [ ] **CA-4:** E-mail já existente → erro genérico sem revelar existência (proteção contra enumeração — mesma régua de STORY-017 CA-4).
- [ ] **CA-5:** Checkbox de aceite desmarcado → bloqueado client + server.
- [ ] **CA-6:** Foto inválida → erro acionável.
- [ ] **CA-7:** Tela de sucesso exibe mensagem de SLA 24h + CTA voltar à home.
- [ ] **CA-8:** Contratante `pendente_aprovacao` tentando logar recebe a mesma tela do funnel guard de STORY-016 (mensagem clara, sem leak).
- [ ] **CA-9:** **E2E em browser real** cobrindo o caminho feliz (cadastrar → ver tela de sucesso → tentar logar com o e-mail recém-cadastrado → mensagem de "aguardando aprovação"). Rodando na pipeline de homolog.
- [ ] **CA-10:** Acessibilidade WCAG 2.1 AA, tema dual claro/escuro (PDR-013).
- [ ] **CA-11:** Cobertura ≥ 80% geral / ≥ 98% núcleo (validações de campo, unicidade, transição de estado, aceite de Termos).
- [ ] **CA-12:** Log estruturado de pré-cadastro com e-mail mascarado (ADR-008); audit log de admin **não** ativado (admin ainda não atuou).
- [ ] **CA-13:** Pré-cadastro **não coleta CNPJ, endereço completo, segmento, cultura, redes sociais** — esses vão em completar cadastro (STORY-024). Verificação por teste de schema (campos não presentes na request).

## Fora de escopo

- CNPJ, endereço completo, segmento, cultura, ano de fundação, quantidade de funcionários, contatos adicionais, logo — STORY-024.
- Plano contratado — default Member Start na criação; mudança via fluxo separado, fora do MVP.
- Aprovação de pré-cadastro no admin — STORY-019.
- Welcome / Completar cadastro — STORY-022/024.
- Cadastro de profissional — STORY-017.

## Padrões de qualidade exigidos

Esta estória segue `quality-standards.md`. Em particular:

- **Cobertura unitária ≥ 80% geral, ≥ 98% no núcleo** (validações, unicidade, transição, aceite Termos).
- **E2E em browser real** cobrindo CA-9.
- **TDD** nas regras.
- **Segurança (§4)**: Argon2id; senha nunca em log/response; defesa contra enumeração de e-mail; upload de foto sanitizado (MIME server-side); CSRF Sanctum no submit.
- **LGPD**: atualizar a lista de campos coletados (introduzida em STORY-017) somando os campos de contratante; classificar como dado pessoal comum (não há dado sensível neste pré-cadastro). Aceite dos Termos via checkbox = consentimento.
- **Acessibilidade (§5)**: WCAG 2.1 AA; tema dual.
- **Observabilidade (§3)**: log estruturado mascarado; alerta de Cloud Monitoring para taxa anormal de submits.
- **Banco**: migração adicional para colunas específicas do contratante (se ADR-009 demandou), idempotente, reversível.

## Dependências

- **Bloqueada por:** STORY-012 (ADR-009 `accepted`). STORY-016 (auth base aplicada — funnel guard reutilizado para "aguardando aprovação"). Designer entrega `SCREEN-STORY-018-pre-cadastro-contratante` em `ready`. Pode rodar **em paralelo com STORY-017** desde que o sync Designer↔Programador para os dois aconteça (telas espelhadas com tema diferente).
- **Bloqueia:** STORY-019 (fila depende de existir contratantes em `pendente_aprovacao`), STORY-024 (completar cadastro contratante), STORY-025 (validação).
- **Pré-requisitos:** STORY-006, STORY-007, STORY-016.

## Decisões já tomadas (não as reabra)

- **`domain/usuario.md`** — contratante sempre PJ; campos pré-aprovação listados.
- **ADR-007 / ADR-009 / PDR-013 + DDR-001 / Princípios do PO**.

## Liberdade técnica do agente

Você decide:
- Reuso de componentes Flutter de STORY-017 (campos comuns: e-mail, senha, telefone, cidade, foto, aceite) — recomendação forte: extrair componentes compartilhados em `lib/cadastro/shared/` para reduzir duplicação.
- Mensagens textuais com voice-and-tone do DDR-001 adaptadas ao contratante.
- Estratégia de tabela de "tipo de operação" (enum hard-coded vs tabela auxiliar — recomendação: enum por enquanto, registrar IDR).

Você NÃO decide:
- Coletar CNPJ aqui.
- Reabrir polimorfismo ou auth.
- Suprimir cobertura, E2E, LGPD, mascaramento.

## Definição de Pronto (DoD)

- [ ] CA-1 a CA-13 passam.
- [ ] Cobertura medida no PR.
- [ ] E2E verde na pipeline de homolog.
- [ ] LGPD: lista de campos atualizada.
- [ ] Sync Designer↔Programador registrado.
- [ ] `index.json` atualizado.
- [ ] "Notas" preenchida.
- [ ] IDR se houve decisão técnica relevante.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Carregue `docs/skills/programador/SKILL.md`. Confirme screen spec em `ready`. TDD nas regras. PR com evidência. `done` após deploy verde em homolog.

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
(a preencher)

### Pendências para fechar
(a preencher)

### Links de evidência
(a preencher)
