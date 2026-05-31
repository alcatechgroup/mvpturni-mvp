---
story_id: STORY-023
slug: completar-cadastro-profissional-com-aceite
title: Completar cadastro de Profissional no WebApp + geração do AceiteEletronico
epic_id: EPIC-001
sprint_id: SPRINT-2026-W25
type: implementation
target_role: programador
requires_design: true
design_screen_id: SCREEN-STORY-023-completar-cadastro-profissional
status: in_review
owner_agent: claude-opus-programador-designer-2026-05-30
created_at: 2026-05-28
updated_at: 2026-05-31
estimated_session_size: L
---

# STORY-023 — Completar cadastro de Profissional + AceiteEletronico

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Ela contém tudo o que você precisa. Se algo estiver ambíguo, registre a dúvida na seção "Notas do agente" no final e pause em vez de adivinhar.

## Contexto (por que esta estória existe)

Esta é a estória que **leva o profissional ao estado `ativo`** — fim do funil de cadastro. Coleta os dados sensíveis que `domain/usuario.md` lista para pós-aprovação (documento conforme `tipo_pessoa`, chave Pix, documentos comprobatórios, e demais campos), e — no momento do clique explícito do usuário em "Aceito e concluir cadastro" — **gera o AceiteEletronico imutável** que referencia a versão ativa do template contratual aplicável (`pf_autonomo_eventual` se PF; `mei_pj_b2b` se MEI/PJ), renderizado com os dados do usuário. Esse é o **momento legal de consentimento informado** do MVP. Sem isso, o ciclo do usuário não fecha e nenhum dos épicos seguintes (EPIC-002 candidatura, EPIC-003 PIN+Pix) faz sentido.

A estória é L pelo número de campos e variações por `tipo_pessoa`. Justificativa para não dividir: o aceite eletrônico precisa ser gerado **com todos os dados juntos** (split entre "coletar dados" e "gerar aceite" produz aceite incompleto, ou dado coletado sem ato de consentimento — pior dos dois mundos). Mitigação do tamanho: cobertura rica de testes; uso intensivo de componentes compartilhados de STORY-017; agente pode escalar se sentir que não cabe em sessão única.

A geração do aceite na **STORY-023** (e na STORY-024 espelhada para contratante) resolve a ambiguidade do `epic.md` original. Decisão PO registrada: aceite é gerado no clique de "Aceito" no fim do completar cadastro — momento em que o usuário tem todos os dados, vê o texto renderizado completo, e dá consentimento explícito. **Não** na aprovação do admin (gate operacional, não consentimento). Esta decisão é citada em PDR futuro se necessário; por ora, fica registrada nas estórias do EPIC-001.

- Épico: `docs/project-state/epics/EPIC-001-cadastro-e-aprovacao/epic.md`
- Documentos canônicos a ler ANTES de codificar:
  - `docs/especificacao/domain/usuario.md` §"Atributos por papel — Profissional / Adicionados no completar cadastro"
  - `docs/especificacao/domain/compliance.md` §"Aceite eletrônico por turno" (usa mesma infra para aceite de adesão), §"Placeholders esperados", §"Imutabilidade do aceite"
  - `docs/project-state/decisions/pdr/PDR-001-tipos-de-pessoa-aceitos.md` (CPF/CNPJ por tipo; consequências tributárias)
  - `docs/project-state/decisions/pdr/PDR-012-templates-contratuais-editaveis-no-backoffice.md` (versão ativa anexada ao aceite; imutabilidade)
  - `docs/project-state/decisions/adr/ADR-009-modelo-de-dados-identidade-epic-001.md` (campos sensíveis + criptografia em repouso)
  - `docs/project-state/decisions/adr/ADR-010-template-versao-e-aceite-eletronico.md` (motor de renderização + esquema do aceite)
  - `docs/especificacao/non-functional.md` §LGPD, §Segurança
  - `docs/project-state/design/screens/SCREEN-STORY-023-completar-cadastro-profissional.md`
  - `docs/skills/programador/SKILL.md`, `docs/skills/po/references/quality-standards.md`

## O quê (objetivo desta estória)

Entregar fluxo de completar cadastro do profissional:

1. Rota `/completar-cadastro` no WebApp para profissional `liberado, welcome_visto=true, cadastro_completo=false`. Substitui o placeholder de STORY-016.
2. **Formulário multi-step** (sugestão: 3 passos — Identidade, Profissional, Financeiro/Documentos — com barra de progresso). Sua decisão técnica sobre passo único vs multi-step; recomendação forte: multi-step para reduzir fricção mental.
3. **Campos coletados** (`domain/usuario.md` §"Profissional / Adicionados no completar cadastro"):
   - **Documento** (CPF se `tipo_pessoa=PF`; CNPJ se MEI/PJ — validação de formato server-side; sem consulta Receita por PDR-001). Único por sistema.
   - Função(ões) secundária(s) opcional(is) — multi-select.
   - Raio máximo de deslocamento (km) — número.
   - Preço/hora pretendido (R$/h) — número, com sugestão de faixa por função.
   - Bio curta — textarea, ≤500 chars.
   - **Chave Pix** — texto (CPF/CNPJ/e-mail/telefone/aleatória; validação básica de formato).
   - **Documentos comprobatórios** — upload (foto do documento PF=RG/CNH ou MEI/PJ=CCMEI/Cartão CNPJ). ≤10 MB cada; JPG/PNG/PDF.
4. **Dados sensíveis criptografados em repouso** conforme ADR-009 (CPF/CNPJ, chave Pix, dados bancários no futuro, foto de documento). Mecanismo decidido em ADR-009.
5. **Preview do contrato antes do aceite**: no último passo, antes do botão final, o usuário vê o **texto integral do contrato renderizado** com seus dados preenchidos (placeholders substituídos). Pode rolar, ler, voltar para editar. Apenas após visualizar o preview e marcar checkbox "Li, entendi e aceito os termos do contrato" o botão **"Aceito e concluir cadastro"** habilita.
6. **Geração do AceiteEletronico** ao clique final:
   - Carrega `TemplateVersao` ativa do slug correto (`pf_autonomo_eventual` ou `mei_pj_b2b` conforme `tipo_pessoa`).
   - Renderiza com os dados do usuário coletados (apenas seção "Termos gerais aplicáveis a todo turno" da estrutura de STORY-015; seção "Termos do turno específico" fica vazia/omitida — é aceite de adesão, sem turno).
   - Cria `AceiteEletronico` no banco com `template_versao_id`, `usuario_id`, `conteudo_renderizado`, `dados_renderizados` (JSON), `timestamp`, `ip` (da request), `fingerprint` (estratégia de ADR-010). **Imutável**.
   - Transação atômica: tudo (campos do usuário + AceiteEletronico + transição `liberado → ativo`) ou nada.
7. Após aceite, usuário transiciona para `status = ativo, cadastro_completo = true`, e cai em rota interna placeholder ("Cadastro concluído — em breve você terá o feed de vagas" — feed real é EPIC-002).
8. **Audit log de admin**: nenhum evento aqui (usuário concluindo o próprio cadastro não é ação de admin).
9. Cópia do aceite eletrônico disponível ao próprio profissional via "Meu contrato" (rota futura — nesta estória basta o registro estar persistido e legível pelo admin no detalhe da fila/visão de usuário).

## Por quê (valor para o usuário)

Direto: profissional fica `ativo` e pronto para usar a plataforma. Aceite eletrônico assinado é a prova jurídica defensável da relação. Indireto: primeira coleta de dados financeiros (chave Pix) — destrava futura entrega de Pix em 15 min (EPIC-003); valida em uso real ADR-010 (renderização e imutabilidade); fecha a metade profissional do funil do EPIC-001.

## Critérios de aceite

- [ ] **CA-1:** Rota `/completar-cadastro` em homolog renderiza fluxo real (substituindo placeholder) para profissional `liberado, welcome_visto=true`.
- [ ] **CA-2:** Formulário coleta todos os campos listados em §O quê (item 3), com validação client + server e mensagens acionáveis.
- [ ] **CA-3:** Validação de documento por `tipo_pessoa`: PF → CPF (formato + dígitos verificadores válidos); MEI/PJ → CNPJ (formato + dígitos válidos). Documento único no sistema; tentativa de cadastrar documento já existente bloqueia com erro genérico.
- [ ] **CA-4:** Chave Pix validada (tipo + formato básico). Aceita CPF/CNPJ/e-mail/telefone/aleatória.
- [ ] **CA-5:** Upload de documentos comprobatórios funciona (≤10 MB, JPG/PNG/PDF), MIME validado server-side, armazenamento conforme ADR-004 com signed URLs / path não enumerável.
- [ ] **CA-6:** Dados sensíveis (CPF/CNPJ, chave Pix, fotos de documentos) criptografados em repouso conforme ADR-009. Verificação: query direta no Postgres não retorna texto claro (depende do mecanismo escolhido; trigger uma sql para evidência).
- [ ] **CA-7:** Preview do contrato renderiza o **texto integral da versão ativa do template aplicável** com placeholders substituídos pelos dados do usuário. Texto coerente: só seção "Termos gerais" (sem turno específico). Visual legível (escala de fonte, espaçamento), tema dual claro/escuro.
- [ ] **CA-8:** Checkbox "Li, entendi e aceito" + botão "Aceito e concluir cadastro" — o botão **só habilita** após checkbox marcado E preview exibido (testar que não é possível submeter sem preview visto).
- [ ] **CA-9:** Clique final gera `AceiteEletronico` no banco com todos os campos corretos: `template_versao_id` correto (versão ativa no momento), `conteudo_renderizado` igual ao preview exibido, `dados_renderizados` JSON estruturado, `timestamp`, `ip`, `fingerprint` conforme ADR-010.
- [ ] **CA-10:** Transação atômica: se qualquer parte (criação do aceite, atualização dos campos, transição de status) falhar, **nada** persiste; usuário recebe erro acionável e estado anterior preservado.
- [ ] **CA-11:** Aceite **imutável**: tentativa de UPDATE/DELETE direto no Postgres numa linha de `aceites_eletronicos` falha (mecanismo de ADR-010). Evidência no runbook.
- [ ] **CA-12:** Após aceite com sucesso, usuário transiciona para `ativo, cadastro_completo=true` e cai em placeholder de feed (texto + logout). Funnel guard não redireciona mais.
- [ ] **CA-13:** Acessibilidade WCAG 2.1 AA em todo o fluxo (multi-step, preview, checkbox final); tema dual.
- [ ] **CA-14:** Cobertura ≥ 80% / ≥ 98% no núcleo (validação documento por tipo_pessoa, transação atômica de aceite, renderização correta da versão ativa, criptografia em repouso, transição de status).
- [ ] **CA-15:** **E2E em browser real**: (a) seed profissional `liberado, welcome_visto=true, tipo_pessoa=PF`; navega completar cadastro; preenche os 3 passos; vê preview com CPF + dados pessoais; aceita; cai em rota interna placeholder; verifica no banco que `AceiteEletronico` existe com `template_versao_id` correto e `conteudo_renderizado` igual ao preview. (b) Mesma sequência para MEI (CNPJ + template MEI/PJ). (c) Tentativa de aceitar sem checkbox marcado é bloqueada.
- [ ] **CA-16:** **Cenário crítico de imutabilidade**: após aceite criado, admin ativa nova versão do template aplicável (STORY-020); aceite existente do usuário deste teste continua **referenciando a versão original** e renderizando exatamente o texto original. Teste E2E ou de integração cobre.
- [ ] **CA-17:** Log estruturado (ADR-008): evento `user.cadastro_completed` com `user_id, role, tipo_pessoa, template_versao_id` — sem dado pessoal claro.
- [ ] **CA-18:** LGPD: lista de campos coletados nesta estória atualizada em `docs/especificacao/non-functional.md` (ou arquivo dedicado) com classificação (CPF/CNPJ + foto de documento + chave Pix = **dados sensíveis**; demais = dados pessoais comuns). Acesso a esses campos sempre via permissões controladas (admin lê; outros não).

## Fora de escopo

- Completar cadastro do contratante — STORY-024.
- Feed de vagas — EPIC-002.
- Aceite eletrônico **por turno** (`compliance.md` §"Aceite eletrônico por turno") — fora do EPIC-001; chega no EPIC-003 reutilizando ADR-010.
- Edição posterior do perfil do profissional — fora do EPIC-001; vira épico próprio na próxima onda.
- Dashboard "Meu contrato" no perfil — fora do MVP (aceite fica disponível ao admin; auto-serviço futuro).
- Validação automática de CPF/CNPJ contra Receita — PDR-001 exclui.
- Assinatura digital qualificada / ICP-Brasil — declarado fora do MVP.

## Padrões de qualidade exigidos

`quality-standards.md`. Em particular:

- **Cobertura ≥ 80% / ≥ 98% núcleo** (transação atômica de aceite, validação documento por tipo, renderização, criptografia, transição de status, imutabilidade).
- **E2E em browser real** cobrindo CA-15 e CA-16 na pipeline de homolog. **CA-16 é especialmente importante** — é a verificação central de PDR-012 em uso real.
- **TDD** nas regras.
- **Segurança (§4)**: criptografia em repouso de dados sensíveis (ADR-009); signed URLs para documentos enviados; CSRF Sanctum; nenhum dado sensível em log claro; gitleaks no pré-push.
- **LGPD**: lista de campos atualizada + classificação; consentimento explícito (aceite) registra timestamp/IP/fingerprint; dados acessíveis ao titular (auto-serviço futuro fora do MVP, mas estrutura prepara).
- **Observabilidade (§3)**: log estruturado mascarado; métrica de cadastros completados por dia; alerta se taxa anormal (sucesso ou falha).
- **Acessibilidade (§5)**: WCAG 2.1 AA; tema dual.

## Dependências

- **Bloqueada por:** STORY-012 (ADR-009 — campos sensíveis, criptografia, transição). STORY-013 (ADR-010 — esquema do aceite, motor de renderização, imutabilidade). STORY-015 (texto-seed dos templates carregado). STORY-016 (auth + funnel guard). STORY-017 (pré-cadastro do profissional). STORY-019 (admin aprova profissionais — usuários `liberado` existem). STORY-020 (editor de templates → seeds de templates em prod-equivalente). STORY-022 (welcome marca `welcome_visto = true`). Designer entrega `SCREEN-STORY-023-completar-cadastro-profissional` em `ready`; sync ≤15 min.
- **Bloqueia:** STORY-025 (validação).
- **Pré-requisitos:** STORY-006, STORY-007.

## Decisões já tomadas (não as reabra)

- **PDR-001** — documento por tipo_pessoa; sem Receita.
- **PDR-012** — aceite imutável referenciando versão; mudanças posteriores não afetam.
- **ADR-009 / ADR-010** — esquema de aceite, renderização, imutabilidade.
- **Decisão PO do EPIC-001 sobre momento do AceiteEletronico**: gerado no clique explícito de "Aceito e concluir cadastro" no fim do completar cadastro, **não na aprovação do admin** (resolução de ambiguidade do `epic.md` original). Registrada em STORY-019 §Decisões já tomadas; aplicada aqui em uso real.
- **`domain/usuario.md`** — lista de campos pós-aprovação.
- **DDR-001 + PDR-013** — tema dual; tema profissional.

## Liberdade técnica do agente

Você decide:
- Multi-step vs single page (recomendação forte: multi-step).
- Componente de upload (mesmo de STORY-017/018 reusado).
- Mecanismo concreto de validação CPF/CNPJ (digito verificador — lib ou implementação própria; testar com casos válidos/inválidos).
- Layout do preview do contrato (modal, side-by-side, full screen — sua decisão com Designer).
- Estratégia de "salvar rascunho" entre passos (recomendação: salvar campos parciais a cada passo para tolerar refresh — registrado em IDR).
- Implementação concreta da transação atômica (DB transaction com SAVEPOINTs ou pattern).

Você NÃO decide:
- Pular preview do contrato ou checkbox final (consentimento explícito é requisito).
- Reabrir ADR-010 (motor) ou ADR-009 (campos sensíveis).
- Validar CPF/CNPJ contra Receita (PDR-001).
- Suprimir criptografia em repouso, cobertura, E2E, ou LGPD.

## Definição de Pronto (DoD)

- [ ] CA-1 a CA-18 passam com evidência.
- [ ] Cobertura medida no PR.
- [ ] E2E verde na pipeline de homolog (incluindo CA-16 — cenário de imutabilidade após nova versão).
- [ ] Criptografia em repouso verificada em homolog (query direta no Postgres).
- [ ] Imutabilidade verificada (CA-11 com evidência no runbook).
- [ ] LGPD: lista de campos atualizada (CA-18).
- [ ] Sync Designer↔Programador registrado.
- [ ] `index.json` atualizado.
- [ ] "Notas" preenchida.
- [ ] IDR se houve decisão técnica relevante.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Carregue `docs/skills/programador/SKILL.md`. Confirme screen spec em `ready`. TDD. PR com evidência. **Se a estória estourar sessão única**: escalar ao PO antes de inflar; aceitar carry-over para próxima sprint é exceção válida dada o tamanho L. `done` após deploy verde + CA-16 evidenciado.

## Notas do agente (preenchido durante/após execução)

### Entrada inicial

**Assumida em** 2026-05-30 por `claude-opus-programador-designer-2026-05-30` (dupla Designer+Programador na mesma sessão — aprendizado #1 da W24).

**Documentos lidos (íntegra):** esta estória; SPRINT-2026-W25; ADR-009 (perfis 1:1, funil status+timestamps, transição atômica `liberado→ativo`, Encrypted Cast para dados sensíveis); ADR-010 (schema Template/TemplateVersao/AceiteEletronico, partial unique index, motor de renderização por regex com falha-dura em placeholder ausente, imutabilidade por trigger + REVOKE); `domain/usuario.md` §Profissional pós-aprovação; `domain/compliance.md` §placeholders; SKILL programador + designer. Código: webapp (`pre_cadastro_profissional_screen`, `cadastro/shared/*`, `completar_cadastro_placeholder_screen`, router, funnel); api (`routes/api.php`, `FunnelGuard`, `WelcomeController`, `User`, `ProfissionalProfile`, migrations de identidade/templates, `TemplatesContratuaisSeeder`, seeds dos 2 templates); admin (`TemplateRenderer` — só destaca placeholders, não substitui).

**Entendimento consolidado (minhas palavras):** o profissional `liberado, welcome_visto=true, cadastro_completo=false` preenche um formulário multi-step (Identidade → Profissional → Financeiro/Documentos), vê no último passo o **contrato renderizado com seus dados** (Seção 1 dos termos gerais + bloco de assinatura), marca "Li, entendi e aceito" e clica "Aceito e concluir cadastro". Nesse clique único e atômico: cria-se o `AceiteEletronico` imutável (referenciando a `template_versao` ativa do slug por `tipo_pessoa`), gravam-se os campos sensíveis criptografados, e o usuário transiciona para `ativo, cadastro_completo=true`. Tudo ou nada.

**Descobertas que mudam o plano:** (a) `api` não tem models Template/TemplateVersao/AceiteEletronico nem a migration de `aceites_eletronicos` — preciso criá-los (models duplicados por app, como User/Funcao já são); (b) não há motor de substituição de placeholders em `api` — preciso implementá-lo (ADR-010 Decisão 3A); (c) colunas de completar-cadastro (`raio_max_km`, `preco_hora`, `funcoes_secundarias`, `documento_path`) não existem em `profissional_profiles`; (d) Encrypted Casts ainda não estão ligados no model `ProfissionalProfile`.

**Plano (fases):**
1. **Backend foundation (TDD):** migration (colunas completar-cadastro + `aceites_eletronicos` com trigger BEFORE UPDATE OR DELETE + REVOKE); models `Template`/`TemplateVersao`/`AceiteEletronico` em `api`; Encrypted Casts em `ProfissionalProfile`; validador CPF/CNPJ (dígitos) e chave Pix; `AceiteRenderer` (substituição por regex, falha-dura, render só Seção 1 + Assinatura); `CompletarCadastroService` (transação atômica) + `CompletarCadastroController` + rota `POST /api/usuarios/me/completar-cadastro` (fora do FunnelGuard, dentro de auth:web+WebAppOnly — convenção IDR-014). Upload de documento (ADR-004, signed URL / path não-enumerável). Unit + Feature tests (núcleo ≥98%).
2. **Frontend (Flutter multi-step + preview + aceite) + widget tests.**
3. **E2E browser (PF + MEI + bloqueio sem checkbox) + CA-16 (imutabilidade pós-nova-versão).**
4. **Deploy homolog + verificação cripto em repouso (psql) + imutabilidade (psql) + LGPD doc + observabilidade.**

**Dúvidas/ambiguidades:** ver §Decisões tomadas (resolvidas com default defensável) e §Bloqueios (flag de conteúdo do template para o PO).

### Sync Designer↔Programador

Sessão única (mesmo agente nos dois papéis). Alinhamento antes da primeira linha de UI:
- **Fluxo:** 3 passos (`Stepper`) — (1) Identidade: documento por `tipo_pessoa` (CPF/CNPJ, máscara + validação dígitos); (2) Profissional: funções secundárias (multi-select `FilterChip`), raio (km), preço/hora (com faixa sugerida), bio (≤500, contador); (3) Financeiro/Documentos: chave Pix (tipo + valor) + upload do documento comprobatório. Último passo expande o **preview do contrato** (full-screen scrollável) + checkbox + CTA final desabilitado até preview visto E checkbox marcado.
- **Reuso:** componentes de `cadastro/shared/` (CadastroTextField, CadastroDropdownField, CadastroPhotoField→documento, CadastroSection, CadastroErrorText, banner). Tokens DDR-001 (tema dual). Sem componente novo de DS previsto.
- **Limitações técnicas levantadas (programador→designer):** preview precisa do contrato renderizado **server-side** (mesmo texto que vai pro aceite — CA-9 exige `conteudo_renderizado == preview`); logo o preview faz um POST de "render preview" antes do aceite, ou o render acontece client-side a partir do template+dados. Decisão: **render server-side** (fonte única de verdade; evita divergência preview×aceite). Endpoint `POST /api/usuarios/me/completar-cadastro/preview` devolve o `conteudo_renderizado` sem persistir; o aceite final re-renderiza e persiste na transação.
- **Identificadores estáveis sugeridos:** `screen-completar-cadastro`, `step-identidade|profissional|financeiro`, `input-documento`, `input-chave-pix`, `input-raio`, `input-preco-hora`, `input-bio`, `chips-funcoes-secundarias`, `field-documento-upload`, `contract-preview`, `check-aceite`, `btn-aceito-concluir`.

### Decisões tomadas

- **IDR-018 (a criar) — Motor de renderização do aceite em `api` + render só da Seção 1:** implementa ADR-010 Decisão 3A (regex `preg_replace_callback`, falha-dura em placeholder ausente). Para o aceite de adesão (EPIC-001, sem turno), renderiza **apenas a Seção 1 (Termos gerais) + o bloco "Assinatura eletrônica"**; omite a Seção 2 (turno) e os blocos de meta-autoria (`## Histórico de validação`, `## Notas do PO`) presentes no `conteudo` seedado. Acoplamento documentado: a omissão é por marcador de heading (`## Seção 2`, `## Assinatura eletrônica`, `## Histórico`, `## Notas`). Reusado/estendido no EPIC-003 (aceite por turno renderiza Seção 1 + Seção 2).
- **`profissional.endereco_completo`:** não é campo coletado no completar-cadastro (story §3 / `usuario.md`). Composto de `bairro, cidade` do pré-cadastro. Evita pedir endereço completo não-especificado; satisfaz a falha-dura do renderer.
- **REVOKE com usuário único `turni`:** segue o padrão da migration de templates existente (não o split de dois usuários que o ADR descreve como ideal). Trigger BEFORE UPDATE OR DELETE garante a imutabilidade independentemente; REVOKE UPDATE,DELETE é a 2ª camada.
- **Preview renderizado server-side** (ver Sync acima) — fonte única; `conteudo_renderizado` do aceite == preview exibido (CA-7/CA-9).

### Descobertas

- O `api` não tinha models Template/TemplateVersao/AceiteEletronico nem a migration de `aceites_eletronicos` (existiam só no `admin`). Criados no `api` (models duplicados por app — padrão do projeto).
- O `TemplateRenderer` do `admin` apenas **destaca** placeholders; o motor de **substituição** (ADR-010 Decisão 3A) não existia — implementado em `App\Domain\Aceites\AceiteRenderer`.
- O `conteudo` seedado dos templates inclui blocos de meta-autoria (`## Histórico de validação`, `## Notas do PO`) — o render de adesão os omite (ver IDR-018). **Flag para o PO:** convém limpar o texto-seed para conter só o documento jurídico.
- A migration de templates usa **um** usuário de banco (`turni`) no REVOKE, não o split de dois usuários do ADR — segui o padrão existente.

### Bloqueios encontrados

Nenhum bloqueador. Uma flag de conteúdo registrada para o PO (meta-autoria no texto-seed dos templates — ver IDR-018 §sinais de revisão).

### IDRs criados

- **IDR-018** — render do aceite de adesão por seções (Seção 1 + Assinatura) + `documento_hash` HMAC-SHA256 para unicidade sobre dado criptografado.

### Cobertura final

Backend (parcial — só o que foi entregue nesta fase). Núcleo bem coberto:
- `AceiteRenderer` 95% linhas · `CompletarCadastroProfissional` (serviço/transação atômica) 97% · `CompletarCadastroProfissionalRequest` 100% · `DocumentoValidator`/`ChavePixValidator` ~97–100% · `CompletarCadastroController` 81%.
- Suíte api inteira **verde: 214 passed (689 assertions)**; 51 testes novos (34 unit + 17 feature). Pint limpo. Cobertura de **frontend/E2E pendente** (fase 2/3).

### Resultado final / evidência

**STATUS: in_review (2026-05-31).** Backend + frontend + E2E completos e verdes localmente. Pendente: deploy homolog (push dispara CI) + smoke/CA-16 em homolog + validação do PO. Detalhe das 4 fases abaixo.

**Bug real encontrado e corrigido pelo E2E (importante):** o `CompletarCadastroService` chamava `GET /sanctum/csrf-cookie` antes do POST autenticado (preview/completar) — hit no csrf-cookie no meio de uma sessão ativa **regenera a sessão e desloga o usuário** (401 → banner "Não conseguimos enviar agora"). Removido (mesmo padrão de `markWelcomeSeen`). Sem o E2E em browser real, isso só apareceria no celular do PO. Reforça a regra "validar no browser de verdade".

**Suítes locais verdes:** api 214 · admin 91 · webapp 109 (widget) · E2E Playwright 3/3 (PF + MEI + bloqueio sem checkbox) · Pint + dart format limpos.

---
_(histórico da Fase 1 abaixo mantido)_

**STATUS anterior: Fase 1 (backend) concluída.**

**Entregue (fase 1 — backend):**
- Migration `2026_05_30_140000_completar_cadastro_profissional_e_aceites` (colunas completar-cadastro em `profissional_profiles` + `aceites_eletronicos` com trigger BEFORE UPDATE OR DELETE + REVOKE).
- Models `Template`, `TemplateVersao`, `AceiteEletronico` (api) + Encrypted Casts em `ProfissionalProfile` (CA-6).
- `DocumentoValidator` (CPF/CNPJ por dígitos — CA-3), `ChavePixValidator` (CA-4), `AceiteRenderer` (CA-7/CA-9), `CompletarCadastroProfissional` (transação atômica — CA-10).
- `CompletarCadastroProfissionalRequest` (CA-2/3/4/5) + `CompletarCadastroController` (preview + completar) + rotas `POST /api/usuarios/me/completar-cadastro[/preview]` fora do FunnelGuard (IDR-014).
- Cobertura por teste: CA-1,2,3,4,5,6,7,9,10,11,12,16,17 no nível backend/integração.
- Designer: `SCREEN-STORY-023` em `draft` (spec dos 3 passos + preview + estados + microcopy + identificadores). IDR-018.

**Pendente (fases 2–4):** ver §Pendências.

### Pendências para fechar (para o PO validar de manhã)

✅ **Feito:** Frontend Flutter (tela real substitui placeholder; 3 passos + preview server-side + aceite gated + conclusão; widget tests). E2E Playwright CA-15 (PF + MEI + bloqueio). Designer: spec + protótipo HTML. CA-18 (inventário LGPD em `non-functional.md`). CA-16 coberto por teste de integração (feature). Suítes completas verdes + lint.

⏳ **Resta para `done`:**
1. **Deploy homolog** (o push na `main` dispara o CI) + smoke pelo navegador/celular do PO em `app.homolog.turni.com.br/completar-cadastro`.
2. **Evidências em homolog:** CA-6 (psql mostra ciphertext) e CA-11 (UPDATE/DELETE em `aceites_eletronicos` falha) — comandos prontos no chat; rodar contra o banco de homolog. CA-16 também em homolog (ativar nova versão de template via Backoffice e confirmar que o aceite mantém a original).
3. **Validação humana (PO)** do protótipo/microcopy de consentimento para promover `SCREEN-023` a `ready`.
4. **Métrica de cadastros/dia** (observabilidade) — o log `user.cadastro_completed` já é emitido; o painel/contagem fica para a checagem de homolog.
5. **Flag de conteúdo (PO):** limpar o texto-seed dos templates (remover `## Notas do PO` / `## Histórico de validação` do `conteudo`) — hoje o renderer os omite, mas o ideal é o seed conter só o documento jurídico.

### Links de evidência

- Suíte api local verde: `make test-api` → 214 passed (689 assertions), 2026-05-30.
- IDR-018; SCREEN-STORY-023 (draft).
