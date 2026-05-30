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
status: ready
owner_agent: null
created_at: 2026-05-28
updated_at: 2026-05-30
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
5. **Preview do contrato** antes do aceite — texto integral da versão ativa do template `mei_pj_b2b` renderizado com dados do contratante. Apenas seção "Termos gerais aplicáveis a todo turno" (sem turno específico — aceite de adesão).
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
- [ ] **CA-7:** Preview do contrato renderiza versão ativa de `mei_pj_b2b` com dados do contratante substituídos. Texto coerente: apenas seção "Termos gerais".
- [ ] **CA-8:** Checkbox + botão "Aceito e concluir cadastro" — botão só habilita após checkbox marcado E preview exibido.
- [ ] **CA-9:** Clique final gera `AceiteEletronico` no banco com `template_versao_id` da versão ativa de `mei_pj_b2b`, `conteudo_renderizado` igual ao preview, `dados_renderizados` JSON, `timestamp`, `ip`, `fingerprint`.
- [ ] **CA-10:** Transação atômica (mesma régua de STORY-023 CA-10).
- [ ] **CA-11:** Aceite imutável (mesma régua de STORY-023 CA-11). Evidência registrada — pode ser a mesma do runbook de STORY-023.
- [ ] **CA-12:** Após aceite, contratante transiciona para `ativo, cadastro_completo=true`. Plano `Member Start` registrado.
- [ ] **CA-13:** Acessibilidade WCAG 2.1 AA; tema dual.
- [ ] **CA-14:** Cobertura ≥ 80% / ≥ 98% núcleo (validação CNPJ, integração CEP, transação atômica, renderização, criptografia, transição).
- [ ] **CA-15:** **E2E em browser real**: seed contratante `liberado, welcome_visto=true`; preenche os 3 passos; vê preview com CNPJ + endereço; aceita; cai em placeholder; verifica no banco o aceite com `template_versao_id` da versão ativa de `mei_pj_b2b`.
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
