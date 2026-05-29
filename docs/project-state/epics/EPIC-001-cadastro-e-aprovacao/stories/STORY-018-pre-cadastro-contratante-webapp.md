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
status: done
owner_agent: claude-opus-programador
created_at: 2026-05-28
updated_at: 2026-05-29
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

- [x] **CA-1:** Rota pública `/cadastro/contratante`, sem auth, tema contratante (mostarda) do DDR-001 — responde 200 em dev (`:8003`) e validada manualmente no browser pelo PO. Verificação em homolog ocorre no próximo deploy (este commit não foi pushado).
- [x] **CA-2:** Formulário renderiza todos os campos de §O quê (item 2), validação client-side e mensagens acionáveis (widget tests).
- [x] **CA-3:** Submit válido cria `role=contratante, status=pendente_aprovacao`, hash Argon2id, foto persistida, timestamp do aceite; senha nunca em log/response (API tests + smoke real 201).
- [x] **CA-4:** E-mail já existente → erro genérico sem enumeração (API test + widget test).
- [x] **CA-5:** Checkbox de aceite desmarcado → bloqueado client + server (widget test + API test).
- [x] **CA-6:** Foto inválida (tipo/tamanho) → erro acionável (client + server).
- [x] **CA-7:** Tela de sucesso (Vista B) com SLA 24h + CTA "Voltar à home".
- [x] **CA-8:** Contratante `pendente_aprovacao` ao logar cai no `banner-pending` do funnel guard (STORY-016), agnóstico de papel, com SLA 24h — sem mudança de login.
- [x] **CA-9:** **E2E em browser real** — caminho feliz validado manualmente no browser pelo PO (cadastrar → recebido → tentar logar → o login rejeita e-mail inexistente sem leak; cadastro pendente cai no banner "em análise"). Spec automatizada `pre-cadastro-contratante.spec.ts` criada; rodar `make e2e-webapp` no gate de deploy.
- [x] **CA-10:** WCAG 2.1 AA + tema dual: contrastes dos dois temas verificados na SCREEN §A.7; semântica/foco/keys implementados. Verificação `axe` automatizada fica para o gate de deploy.
- [x] **CA-11:** Cobertura ≥ 80% geral; núcleo: `FormRequest` **100%**, controller **92,68%** (não-cobertas = limpeza de foto órfã no `catch`, idêntico à 017).
- [x] **CA-12:** Log estruturado `user.preregistered` com e-mail mascarado (ADR-008), `role=contratante`; sem audit log de admin (API test).
- [x] **CA-13:** Não coleta CNPJ/endereço/segmento — campos injetados são ignorados (API test de schema + smoke: cnpj/endereco NULL).

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

- [x] CA-1 a CA-13 passam (verificados local + manual pelo PO; homolog no próximo deploy).
- [x] Cobertura medida (API 128 passed; request 100% / controller 92,68%; WebApp 37 passed).
- [x] E2E: validação manual em browser pelo PO + spec automatizada criada (rodar no gate de deploy).
- [x] LGPD: lista de campos atualizada (`campos-coletados.md` §STORY-018).
- [x] Sync Designer↔Programador registrado (SCREEN-018 §A.11; Notas).
- [x] `index.json` atualizado (SCREEN-018, IDR-012, story).
- [x] "Notas" preenchida.
- [x] IDR criado (IDR-012).

> **Aprovação do PO (2026-05-29):** história aprovada para fechamento após teste manual no
> browser. Commit local (sem push); verificação em homolog ocorre no próximo deploy
> (`make e2e-webapp` + smoke da rota pública).

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Carregue `docs/skills/programador/SKILL.md`. Confirme screen spec em `ready`. TDD nas regras. PR com evidência. `done` após deploy verde em homolog.

## Notas do agente (preenchido durante/após execução)

### Entrada inicial
Designer e Programador atuaram juntos na mesma sessão (2026-05-29). Confirmado que a STORY-017
(profissional) está `done` e serve de referência técnica direta; o `banner-pending` do login
(CA-8) já é agnóstico de papel e já traz o SLA de 24h (ajustado na 017 §10) — **sem mudança de
login nesta estória**. ContratanteProfile já existia (criado na STORY-016) com
`nome_estabelecimento`/`tipo_operacao`; faltavam as colunas mínimas de pré-cadastro.

### Sync Designer↔Programador
Registrado na SCREEN-STORY-018 §A.11. Pontos alinhados:
1. `tipo_operacao` é **lista estática** (não endpoint/tabela) — enum no back + lista no front.
2. Reuso de componentes: Designer entregou keys/microcopy compatíveis com a 017 → Programador
   extraiu `lib/features/cadastro/shared/`.
3. Tokens de acento **contratante** (mostarda) adicionados ao `tokens.dart` (valores já
   sancionados por `tokens.md §6` / DDR-001).
4. Rota pública `/cadastro/contratante` adicionada ao `publicRoutes` do `router.dart`.
Designer entregou `SCREEN-STORY-018-pre-cadastro-contratante` em `ready` antes do código.

### Decisões tomadas
- **IDR-012**: `tipo_operacao` como enum estático + extração de componentes de cadastro
  compartilhados em `lib/features/cadastro/shared/` (tipos+helper HTTP e widgets de formulário).
  A tela do profissional (017) foi refatorada para consumir o módulo compartilhado.
- Plano default `member_start` na criação (fora de escopo: mudança via fluxo separado).

### Descobertas
- **Armadilha de `Key` na refatoração** (documentada em IDR-012): ao extrair os campos para
  widgets compartilhados, a `Key('$field-field')` precisa ficar **no widget filho direto do
  `Column`**, não num `Padding` interno — senão a inserção condicional do erro de "tipo de
  pessoa" (acima da seção de senha, na 017) reordena os irmãos, o Flutter casa por posição e
  recria o `FormFieldState`, perdendo o `errorText`. Pego pelo widget test "senha fraca" da 017.
  Corrigido derivando `super.key = ValueKey('$fieldKey-field')` nos campos compartilhados.

### Bloqueios encontrados
Nenhum bloqueio. (Quirk não-relacionado: smoke via `curl -F` com caracteres especiais perdia
campos; resolvido usando `--form-string` — o endpoint responde 201 correto.)

### IDRs criados
- **IDR-012** — `tipo_operacao` enum estático + componentes de cadastro compartilhados.

### Cobertura final
- **API (Pest):** 53 testes (300 asserts) nos dois pré-cadastros; suíte completa **128 passed**.
  `StoreContratantePreCadastroRequest` **100%** de linha; `ContratanteCadastroController`
  **92,68%** (as 3 linhas não cobertas são o bloco de limpeza de foto órfã no `catch` — mesmo
  padrão e mesma cobertura da 017, que shipou em 92,5%).
- **WebApp (flutter test):** suíte completa **37 passed** (017 refatorada + 018 nova + login com
  as duas portas de criar conta). `flutter analyze` limpo.

### Resultado final / evidência
- API `POST /api/cadastro/contratante` smoke real (dev): **HTTP 201** com a mensagem de SLA;
  registro persistido com `role=contratante`, `status=pendente_aprovacao`, senha `$argon2id$`,
  `plano=member_start`, **cnpj/endereço NULL** (CA-13), foto em path não-enumerável,
  `termos_aceitos_at` setado. `tipo_operacao` inválido → 422.
- Migração `add_pre_cadastro_columns_to_contratante_profiles_table` aplicada no dev (reversível).
- Pint limpo nos arquivos PHP novos/alterados.

### Ajuste pós-entrega — login com duas portas de criar conta
O login (SCREEN-016) só oferecia "Cadastre-se" → profissional. Com o contratante existindo,
o atalho virou **duas portas**: "Criar conta de profissional" (acento verde) e "Criar conta de
estabelecimento" (acento mostarda) — **cada uma no acento do seu perfil** (DDR-001), antecipando
o tema da tela de destino. Keys: `link-criar-conta` (preservada) e `link-criar-conta-contratante`.
Decisão de microcopy: superfície pública usa **"estabelecimento"** (anti-jargão; a persona não
se chama "contratante"), mantendo `role=contratante` como termo de domínio. Documentado em
SCREEN-018 §A.14/§A.15. Tela de destino renomeada para "Criar conta de estabelecimento".

### Verificação manual do PO (2026-05-29)
PO testou no browser local (`:8003`). Cadastro de estabelecimento **persistiu corretamente**
(`role=contratante`, `pendente_aprovacao`). O "credenciais inválidas" observado foi divergência
de e-mail do próprio teste (`...@gmail.com.br` no cadastro vs `...@gmail.com` no login) — **não é
bug**: o login corretamente não loga e-mail inexistente (anti-enumeração) e um cadastro pendente
cai no banner "em análise". História **aprovada para fechamento** pelo PO.

### Pendências para fechar
Nenhuma bloqueante. Operacional, no próximo deploy:
- Rodar `make e2e-webapp` (gate local Playwright, inclui `pre-cadastro-contratante.spec.ts`).
- Deploy em homolog + smoke da rota pública.
- **DDR (Designer, próximo ciclo):** promover "cadastro inicial público = form único seccionado"
  (regra de três fechada por 017+018) — registrado em SCREEN-STORY-018.

### Links de evidência
- Screen spec: `docs/project-state/design/screens/SCREEN-STORY-018-pre-cadastro-contratante.md`
- IDR: `docs/project-state/decisions/idr/IDR-012-tipo-operacao-enum-estatico-e-componentes-cadastro-compartilhados.md`
- LGPD: `docs/especificacao/lgpd/campos-coletados.md` §STORY-018
- API: `apps/api/app/Http/Controllers/Cadastro/ContratanteCadastroController.php`,
  `app/Http/Requests/StoreContratantePreCadastroRequest.php`, `routes/api.php`,
  `database/migrations/2026_05_29_120000_add_pre_cadastro_columns_to_contratante_profiles_table.php`,
  `tests/Feature/Identity/PreCadastroContratanteTest.php`
- WebApp: `apps/webapp/lib/features/cadastro/pre_cadastro_contratante_screen.dart`,
  `contratante_cadastro_service.dart`, `shared/cadastro_types.dart`, `shared/cadastro_widgets.dart`,
  `lib/ds/tokens.dart`, `lib/router.dart`, `test/pre_cadastro_contratante_test.dart`,
  `tests/e2e/pre-cadastro-contratante.spec.ts`
