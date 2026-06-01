---
story_id: STORY-024
slug: completar-cadastro-contratante-com-aceite
title: Completar cadastro de Contratante no WebApp + geração do AceiteEletronico
epic_id: EPIC-001
sprint_id: SPRINT-2026-W25
type: implementation
target_role: programador
requires_design: true
design_screen_id: SCREEN-STORY-024-completar-cadastro-contratante
status: in_progress
owner_agent: claude-opus-4-8-programador-2026-06-01
created_at: 2026-05-28
updated_at: 2026-06-01
estimated_session_size: M
---

# STORY-024 — Completar cadastro de Contratante + AceiteEletronico

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Ela contém tudo o que você precisa. Se algo estiver ambíguo, registre a dúvida na seção "Notas do agente" no final e pause em vez de adivinhar.

## Contexto (por que esta estória existe)

Espelha STORY-023 para o lado do contratante. Coleta os dados de pós-aprovação listados em `domain/usuario.md` para contratante (CNPJ, endereço completo, segmento, cultura, contatos, logo, etc.) e, no clique final de "Aceito e concluir cadastro", gera o `AceiteEletronico` imutável referenciando a versão ativa do template **MEI/PJ B2B** (contratante é sempre PJ — `usuario.md`). Sem isso, o contratante não vira `ativo` e não pode publicar vagas no EPIC-002.

A estória é **M** (não L como STORY-023) porque há menos variações por tipo de pessoa (sempre PJ) e o aceite é direto (um único template). Reaproveita amplamente os componentes da STORY-023 (multi-step, preview, transação atômica, geração de aceite). Justificativa para não fundir 023+024: cada uma deploya valor independente (profissional ou contratante), permite paralelismo no sprint, e mantém PRs revisáveis.

- Épico: `docs/project-state/epics/EPIC-001-cadastro-e-aprovacao/epic.md`
- Documentos canônicos a ler ANTES de codificar:
  - `docs/especificacao/domain/usuario.md` §"Atributos por papel — Contratante / Adicionados no completar cadastro"
  - STORY-023 (referência técnica — espelhada para contratante)
  - `docs/especificacao/domain/compliance.md` §"Aceite eletrônico"
  - `docs/project-state/decisions/adr/ADR-009-modelo-de-dados-identidade-epic-001.md`
  - `docs/project-state/decisions/adr/ADR-010-template-versao-e-aceite-eletronico.md`
  - `docs/project-state/design/screens/SCREEN-STORY-024-completar-cadastro-contratante.md`
  - `docs/skills/programador/SKILL.md`, `docs/skills/po/references/quality-standards.md`

## O quê (objetivo desta estória)

Entregar fluxo de completar cadastro do contratante:

1. Rota `/completar-cadastro` no WebApp para contratante `liberado, welcome_visto=true, cadastro_completo=false`. (Mesma rota de STORY-023; router decide a tela pelo papel — coordenado com STORY-023.)
2. **Formulário multi-step** (sugestão: 3 passos — Identidade do Estabelecimento, Operação, Cultura/Contatos — com barra de progresso).
3. **Campos coletados** (`domain/usuario.md` §"Contratante / Adicionados no completar cadastro"):
   - **CNPJ** (validação formato + dígitos verificadores; sem Receita; único no sistema).
   - **Endereço completo**: logradouro, número, bairro, cidade, UF, CEP, complemento. CEP busca automática (ViaCEP ou equivalente — sua decisão, registrado em IDR; opcional, não bloqueia se a API estiver fora).
   - Apelido do estabelecimento (texto curto, usado em UI compacta).
   - Segmento (texto livre).
   - Ano de fundação (inteiro).
   - Quantidade de funcionários (faixa: 1–10, 11–50, 51–200, 200+).
   - Turnos de operação típicos (texto livre).
   - Cultura e valores-chave (textarea).
   - Redes sociais e site (URLs opcionais).
   - Contatos adicionais (gerente/chef/sommelier — lista dinâmica de nome + função + telefone, ≥0 entradas).
   - Logo (upload, opcional, JPG/PNG, ≤5 MB).
4. **Dados sensíveis criptografados em repouso** conforme ADR-009 (CNPJ; CEP/endereço não necessariamente sensível — siga a classificação do ADR).
5. **Preview do contrato** antes do aceite — texto integral da versão ativa do template `termos_plataforma_contratante` renderizado com dados do contratante. (Decisão PO 2026-06-01 — ver IDR-023 e §"Decisões já tomadas": era `mei_pj_b2b`, mas a Seção 1 daquele template é do _profissional_; contratante adere a um template próprio de Termos de Adesão à Plataforma com a taxa Turni 15% como cláusula permanente.)
6. **Geração do AceiteEletronico** ao clique final, mesmo padrão de STORY-023: transação atômica que persiste campos + cria aceite + transiciona `liberado → ativo`.
7. Após aceite, contratante cai em rota interna placeholder ("Cadastro concluído — em breve você poderá publicar vagas" — vagas reais é EPIC-002).
8. **Plano contratado**: na criação implícita do contratante, fica `Member Start` (gratuito) — `domain/usuario.md` §Contratante/Planos. Sem UI de mudança aqui.

## Por quê (valor para o usuário)

Direto: contratante fica `ativo`, pronto para publicar vagas (no futuro). Aceite eletrônico assinado fixa as condições comerciais (taxa Turni 15% — PDR-004) com prova jurídica. Indireto: fecha o EPIC-001 completamente; primeira coleta de CNPJ e endereço; valida que o desenho de ADR-010 funciona para **dois usos distintos** (PF profissional e PJ contratante) no mesmo épico.

## Critérios de aceite

- [ ] **CA-1:** Rota `/completar-cadastro` em homolog renderiza fluxo do contratante (router decide pela presença de `role=contratante`).
- [ ] **CA-2:** Formulário coleta todos os campos listados em §O quê (item 3), com validação client + server e mensagens acionáveis.
- [ ] **CA-3:** Validação de CNPJ (formato + dígitos verificadores). Único por sistema; tentativa de CNPJ já cadastrado bloqueia com erro genérico (sem leak).
- [ ] **CA-4:** Busca de endereço por CEP funciona (caminho feliz com ViaCEP ou equivalente); falha da API externa **não** bloqueia o submit (degrada para entrada manual + log de falha de integração).
- [ ] **CA-5:** Upload de logo funciona (opcional, MIME server-side, signed URL).
- [ ] **CA-6:** Dados sensíveis criptografados em repouso conforme ADR-009. Evidência via psql.
- [ ] **CA-7:** Preview do contrato renderiza versão ativa de `termos_plataforma_contratante` (era `mei_pj_b2b` — ajuste PO 2026-06-01, IDR-023) com dados do contratante substituídos. Texto coerente para o contratante (Termos de Adesão à Plataforma).
- [ ] **CA-8:** Checkbox + botão "Aceito e concluir cadastro" — botão só habilita após checkbox marcado E preview exibido.
- [ ] **CA-9:** Clique final gera `AceiteEletronico` no banco com `template_versao_id` da versão ativa de `termos_plataforma_contratante` (ajuste PO 2026-06-01, IDR-023), `conteudo_renderizado` igual ao preview, `dados_renderizados` JSON, `timestamp`, `ip`, `fingerprint`.
- [ ] **CA-10:** Transação atômica (mesma régua de STORY-023 CA-10).
- [ ] **CA-11:** Aceite imutável (mesma régua de STORY-023 CA-11). Evidência registrada — pode ser a mesma do runbook de STORY-023.
- [ ] **CA-12:** Após aceite, contratante transiciona para `ativo, cadastro_completo=true`. Plano `Member Start` registrado.
- [ ] **CA-13:** Acessibilidade WCAG 2.1 AA; tema dual.
- [ ] **CA-14:** Cobertura ≥ 80% / ≥ 98% núcleo (validação CNPJ, integração CEP, transação atômica, renderização, criptografia, transição).
- [ ] **CA-15:** **E2E em browser real**: seed contratante `liberado, welcome_visto=true`; preenche os 3 passos; vê preview com CNPJ + endereço; aceita; cai em placeholder; verifica no banco o aceite com `template_versao_id` da versão ativa de `termos_plataforma_contratante` (ajuste PO 2026-06-01, IDR-023).
- [ ] **CA-16:** Log estruturado `user.cadastro_completed` com `user_id, role=contratante, template_versao_id` — sem dado pessoal claro.
- [ ] **CA-17:** LGPD: lista de campos atualizada (CNPJ + endereço + contatos = dados pessoais comuns/contato; classificar conforme `non-functional.md`).

## Fora de escopo

- Completar cadastro do profissional — STORY-023.
- Publicação de vaga — EPIC-002.
- Mudança de plano (Member, Enterprise) — fora do MVP.
- Múltiplos estabelecimentos por contratante — Enterprise, fora do MVP.
- Edição posterior do perfil — fora do EPIC-001.

## Padrões de qualidade exigidos

`quality-standards.md`. Em particular:

- **Cobertura ≥ 80% / ≥ 98% núcleo** (validação CNPJ, integração CEP com fallback, transação atômica, renderização, criptografia, transição).
- **E2E em browser real** cobrindo CA-15 na pipeline de homolog.
- **TDD** nas regras.
- **Segurança (§4)**: criptografia em repouso de CNPJ conforme ADR-009; signed URLs para logo; CSRF Sanctum; nenhum dado sensível em log claro.
- **LGPD**: lista de campos atualizada; consentimento explícito; dados acessíveis.
- **Observabilidade (§3)**: log estruturado; métrica de cadastros completados por dia.
- **Acessibilidade (§5)**: WCAG 2.1 AA; tema dual.

## Dependências

- **Bloqueada por:** STORY-012 (ADR-009). STORY-013 (ADR-010). STORY-015 (texto-seed). STORY-016 (auth + funnel guard). STORY-018 (pré-cadastro contratante). STORY-019 (admin aprova contratantes). STORY-020 (templates carregados). STORY-022 (welcome). Designer entrega `SCREEN-STORY-024-completar-cadastro-contratante`; sync ≤15 min.
- **Bloqueia:** STORY-025 (validação).
- **Pré-requisitos:** STORY-006, STORY-007.

## Decisões já tomadas (não as reabra)

- **PDR-001** — Contratante sempre PJ (CNPJ).
- **PDR-012** — Aceite imutável referenciando versão.
- **PDR-004** — Taxa Turni 15% cobrada do contratante (referência no template).
- **ADR-009 / ADR-010**.
- **Decisão PO sobre momento do aceite** — gerado no clique final do completar cadastro.
- **`domain/usuario.md`** — lista de campos.
- **DDR-001 + PDR-013**.
- **Decisão PO 2026-06-01 (IDR-023) — template do contratante:** o contratante adere a um template
  **próprio**, `termos_plataforma_contratante` ("Termos de Adesão à Plataforma para Contratante"),
  com a taxa Turni 15% (PDR-004) como **cláusula permanente** (não por turno). **Não** reusa
  `mei_pj_b2b` (cuja Seção 1 identifica o profissional). Motivo: reuso seria juridicamente
  incoerente; PDR-004 exige aceite de plataforma além do por-turno; concretiza os "dois usos
  distintos" do ADR-010 citados no contexto. **Texto-seed é authoring do PO** (extensão de
  STORY-015), entregue em 24–48h e validado cláusula a cláusula antes do seed. CA-7/9/15 ajustadas.
  Trabalho que não depende do texto (migration, service de campos, validação CNPJ, CEP, upload,
  UI multi-step, transição) segue em paralelo; só preview + persistência do aceite ficam atrás do seed.

## Liberdade técnica do agente

Você decide:
- API de busca de CEP (ViaCEP, BrasilAPI, etc.) com fallback.
- Reuso de componentes de STORY-023.
- Estratégia de "salvar rascunho" entre passos.
- Layout do passo "Contatos adicionais" (lista dinâmica).

Você NÃO decide:
- Pular preview / checkbox final.
- Suprimir criptografia, cobertura, E2E.
- Coletar dados de profissional aqui.

## Definição de Pronto (DoD)

- [ ] CA-1 a CA-17 passam.
- [ ] Cobertura medida.
- [ ] E2E verde.
- [ ] Imutabilidade verificada (CA-11).
- [ ] LGPD lista atualizada.
- [ ] Sync Designer↔Programador registrado.
- [ ] `index.json` atualizado.
- [ ] "Notas" preenchida.
- [ ] IDR se houve decisão técnica.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Carregue `docs/skills/programador/SKILL.md`. Confirme screen spec em `ready`. TDD. PR com evidência. `done` após deploy verde.

## Notas do agente (preenchido durante/após execução)

### Entrada inicial
2026-06-01 — assumida em `in_progress` (claude-opus-4-8-programador). Li a estória inteira, a
STORY-023 (espelho, `done`), `domain/usuario.md` (§Contratante), `compliance.md` §"Aceite
eletrônico por turno", IDR-022, LGPD `campos-coletados.md`, ADR-009/010 (via STORY-023), e o código
de STORY-023 no `api` (`CompletarCadastroProfissionalService/Controller/Request`,
`AceiteAdesaoRenderer`, `DocumentoValidator`, models, migration). Também os dois textos-seed de
template (`mei_pj_b2b`, `pf_autonomo_eventual`) e o `TemplatesContratuaisSeeder`.

**Plano (FE + BE espelhando STORY-023):** migration p/ colunas do completar contratante +
`cnpj_hash`; `ContratanteProfile` ganha encrypted cast no CNPJ; `CompletarCadastroContratanteService`
(transação atômica campos + aceite + `liberado→ativo`, plano `Member Start`); `CnpjValidator`
(dígitos verificadores); endpoints `contexto/preview/store` fora do FunnelGuard; integração CEP com
fallback (IDR); upload de logo signed; tela Flutter multi-step (3 passos) + preview + checkbox;
widget tests + feature/unit tests api (4 categorias) + E2E browser real (same-origin, IDR-021).

**[ESCALONAMENTO-PO] Bloqueio de produto encontrado ANTES de codar — qual contrato o contratante
adere?** A estória manda renderizar a versão ativa de `mei_pj_b2b`, **apenas Seção 1 (Termos
gerais)**, com dados do contratante (CA-7/9). Mas ao reler o texto-seed real de `mei_pj_b2b`
descobri que a **Seção 1 identifica o _Prestador (Profissional)_** e seus únicos placeholders de
identidade são `{{profissional.nome}}`, `{{profissional.documento}}`,
`{{profissional.endereco_completo}}` — **não há placeholder de contratante na Seção 1**. A
identidade do contratante (`contratante.razao_social/cnpj/endereco_completo`) e a taxa Turni 15%
vivem só na **Seção 2 (turno-específico)**, que o `AceiteAdesaoRenderer` **omite** no aceite de
adesão (IDR-022 a). Consequências:
- Reusar `mei_pj_b2b` + renderer de adesão como está **falharia** (RenderizacaoIncompletaException:
  não há valores de `profissional.*` para um contratante) — ou, se eu injetasse dados do contratante
  nos placeholders `profissional.*`, o documento imprimiria o contratante como "Prestador
  (Profissional)", o que é juridicamente incoerente.
- `compliance.md` só descreve o aceite do contratante **por turno** (Seção 2, ao aprovar
  candidatura). Não existe, em lugar nenhum da spec, um texto de contrato/Termos de adesão para o
  contratante. Authoring de texto contratual é responsabilidade PO/jurídico (STORY-015), fora da
  minha alçada ("Você NÃO decide: …").

Escalei ao PO (ver pergunta na sessão). Não escrevo código de contrato até a decisão. Restante da
estória (campos/validação/CEP/upload/transição/UI) não depende dela e pode começar em paralelo.

### Contrato de placeholders para o texto-seed `termos_plataforma_contratante` (PO)
⚠️ **Importante para o PO:** o renderer (`AceiteAdesaoRenderer`, ADR-010/IDR-022) faz **falha dura**
se o template citar um `{{placeholder}}` que o serviço **não** fornece — nenhum aceite incompleto é
gerado. Use **apenas** os placeholders abaixo no texto-seed (pode usar um subconjunto; usar um fora
da lista quebra a renderização):

- `{{contratante.razao_social}}` — `nome_estabelecimento`
- `{{contratante.cnpj}}` — CNPJ formatado `00.000.000/0000-00`
- `{{contratante.endereco_completo}}` — endereço composto (logradouro, nº — bairro, cidade/UF · CEP)
- `{{plataforma.taxa_turni}}` — `"15%"` (PDR-004; cláusula permanente)
- `{{aceite.timestamp}}`, `{{aceite.ip}}`, `{{aceite.fingerprint}}` — carimbos de assinatura

Estrutura esperada (mesma do `mei_pj_b2b` p/ o renderer cortar certo): preâmbulo + bloco(s) `## …`
(o corpo de adesão). Blocos `## Seção 2`, `## Histórico de validação` e `## Notas do PO` são
**omitidos** automaticamente (IDR-022 a) — pode deixar notas internas nesses blocos sem vazar ao
usuário. Quando o texto chegar: adiciono o slug ao `TemplatesContratuaisSeeder` + vendoro a cópia em
`database/seeders/contracts/` (com SHA-256), e troco o template-fixture dos testes por asserções
contra o seed real. Só então CA-7/9 fecham em homolog (CA-15 E2E junto).

### Sync Designer↔Programador
FEITO (projeto solo). `SCREEN-STORY-024` criada espelhando a `SCREEN-023`, **ready**, indexada em
`design.screens[]`. Decisão de UX: **wizard de 3 passos** (Identidade do Estabelecimento / Operação /
Cultura & Contatos) + fase de revisão/aceite — pelo volume de campos do contratante (~15), form único
sufocaria a persona (princípio #1); a própria estória sugere 3 passos. Tema **contratante mostarda**
(`accent #9A6E25` claro / `#D4A95C` escuro). `repeater.row` para contatos adicionais; CEP autocompleta
sem bloquear; `contract.view` reusado da 023. Keys lógicas `completar-cadastro:*` no spec.

### Decisões tomadas
- **IDR-023** — contratante adere a template próprio `termos_plataforma_contratante` (não `mei_pj_b2b`);
  taxa Turni 15% como cláusula permanente. Decisão PO.
- **IDR-024** — busca de CEP via ViaCEP, `Http` nativo (sem lib nova), fail-soft (CA-4).
- Reuso de `DocumentoValidator::cnpjValido()` (já testado na STORY-023) — sem `CnpjValidator` novo.
- `cnpj_hash` HMAC-SHA256 p/ unicidade (IDR-022 d), espelhando `documento_hash` do profissional.
- Plano `member_start` gravado na conclusão (domain/usuario.md §Contratante/Planos).
- Endpoints fora do FunnelGuard (usuário em `await_cadastro`); `authorize()` garante o estado.
  Endereço do contrato é composto a partir do **payload** (render antes da transação), não do perfil.

### Cobertura final (backend + frontend)
**api** (núcleo do story, medido isolado): `CompletarCadastroContratanteService` **100%**,
`CompletarCadastroContratanteRequest` **100%**, `CepLookup` **100%**, controller 89% (ramos
defensivos), `ContratanteProfile` 87.5%. Suíte api completa: **238 passed**. Pint limpo.
**webapp**: 10 widget tests novos (`completar_cadastro_contratante_screen_test.dart`) cobrindo
CA-1/2/4/5/7/8/12 + navegação do wizard + erro de preview/servidor + contatos add/remove. Suíte
webapp completa: **121 passed**. `flutter analyze` + `dart format` limpos.
Falta (pós-texto do PO): asserção contra o seed real + wiring do `TemplatesContratuaisSeeder` +
E2E em browser real (CA-15) + deploy homolog + smoke.

### IDRs criados
- IDR-023 (template próprio do contratante), IDR-024 (CEP ViaCEP fail-soft).

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
