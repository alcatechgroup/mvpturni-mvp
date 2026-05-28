---
story_id: STORY-020
slug: editor-templates-contratuais-backoffice
title: Editor de templates contratuais no Backoffice (CRUD + versionamento)
epic_id: EPIC-001
sprint_id: SPRINT-2026-W24
type: implementation
target_role: programador
requires_design: true
design_screen_id: SCREEN-STORY-020-editor-templates
status: ready
owner_agent: null
created_at: 2026-05-28
updated_at: 2026-05-28
estimated_session_size: M
---

# STORY-020 — Editor de templates contratuais no Backoffice

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Ela contém tudo o que você precisa. Se algo estiver ambíguo, registre a dúvida na seção "Notas do agente" no final e pause em vez de adivinhar.

## Contexto (por que esta estória existe)

PDR-012 reverteu o spike jurídico bloqueante e definiu que **templates contratuais são entidades editáveis pelo admin no backoffice com versionamento append-only**. Esta estória entrega a UI dessa capability: o admin abre `admin.../templates`, vê os 2 templates do MVP (PF autônomo eventual + MEI/PJ B2B), navega versões, vê preview da versão ativa, cria nova versão (com base em rascunho da versão ativa atual) e a ativa — substituindo a antiga sem afetar contratos passados (`AceiteEletronico` continua apontando para a versão original). Sem esta estória, a hipótese central de PDR-012 ("edição substitui release") não é entregue.

Esta estória tem **alta sensibilidade de UX** porque o admin está editando documento juridicamente vinculante. Confirmação dupla na ativação, preview lado a lado, possibilidade de "voltar versão" (reativar versão anterior) são bons defaults — `PDR-012` §Consequências enfatiza isso.

- Épico: `docs/project-state/epics/EPIC-001-cadastro-e-aprovacao/epic.md`
- Documentos canônicos a ler ANTES de codificar:
  - `docs/project-state/decisions/pdr/PDR-012-templates-contratuais-editaveis-no-backoffice.md` inteira
  - `docs/project-state/decisions/adr/ADR-010-template-versao-e-aceite-eletronico.md` (STORY-013) — esquema concreto
  - `docs/especificacao/domain/compliance.md` §"Estrutura do template no banco" e §"Placeholders esperados"
  - Texto-seed entregue por STORY-015 — versão 1 dos dois templates
  - `docs/project-state/design/screens/SCREEN-STORY-020-editor-templates.md` (Designer entrega antes)
  - `docs/project-state/design/system/preview-backoffice.html`
  - `docs/skills/programador/SKILL.md`, `docs/skills/po/references/quality-standards.md`

## O quê (objetivo desta estória)

Entregar editor de templates no Backoffice Livewire:

1. Rota `/templates` (lista) no admin. Apenas `role=admin`; 403 fail-secure caso contrário.
2. **Lista de templates** (catálogo): 2 itens fixos do MVP — `pf_autonomo_eventual` ("Contrato — Profissional PF / Autônomo eventual") e `mei_pj_b2b` ("Contrato — MEI/PJ / B2B"). Cada item exibe: nome amigável, slug, versão ativa, data da ativação, autor da versão ativa, e CTA "Abrir".
3. **Rota `/templates/{slug}` (detalhe)**: exibe versão ativa renderizada (com placeholders visíveis como `{{contratante.razao_social}}` etc.); abaixo, **histórico de versões** em ordem decrescente (mais nova no topo); cada linha do histórico mostra `versao`, data, autor, status (`ativa` / `histórica`), preview rápido, link "ver completa".
4. **"Criar nova versão"**: botão na tela de detalhe. Abre editor com **conteúdo da versão ativa** pré-carregado (para o admin editar a partir do existente, não do zero). Editor é **textarea com Markdown** (sem WYSIWYG no MVP — sua decisão de tooling; sugestão: textarea simples com fonte monoespaçada + ajuda contextual "Use Markdown. Placeholders são `{{namespace.campo}}`"). Side-by-side **preview** que renderiza o Markdown e destaca visualmente os placeholders.
5. **Validação ao salvar nova versão**:
   - Conteúdo não-vazio.
   - Não introduz placeholders **fora da lista canônica** definida em ADR-010 / `compliance.md` (lista finita; validador checa cada `{{...}}` contra a lista; placeholder desconhecido bloqueia o salvamento com mensagem acionável).
   - Estrutura de seções nomeadas mantida (`## Termos gerais` + `## Termos do turno específico` — convenção de STORY-015) — validador soft (aviso, não bloqueio) se faltar.
6. **Salvar nova versão** cria `TemplateVersao` com `versao = max(versao_existente) + 1`, `ativa = false`, `criado_por_admin_id`, timestamp. **Não desativa a versão atual ainda** — admin pode salvar várias versões rascunho-equivalentes sem afetar a ativa.
7. **"Ativar versão"**: botão visível em qualquer versão com `ativa = false`. Confirmação dupla ("Confirma ativar a versão N? Cadastros aprovados a partir deste momento usarão esta versão. Aceites passados continuam apontando para suas versões originais — eles não mudam."). Ao confirmar: transação que marca a versão alvo `ativa = true` e a anterior `ativa = false`. Grava `admin.template.version_activated` no audit log (ADR-009). Atualiza catálogo.
8. **Imutabilidade da versão ativa**: a versão ativa **não pode ser editada in-place** (PDR-012). Toda edição = nova versão. Tentativa de UPDATE direto no banco numa linha de `template_versoes` deve falhar (mecanismo de ADR-010).
9. **"Voltar para versão anterior"**: para tratar erros, admin pode ativar uma versão histórica (mesmo fluxo do botão "Ativar" aplicado a versão antiga). Audit log captura.
10. **Eventos auditáveis**: `admin.template.version_created` quando uma nova versão é salva; `admin.template.version_activated` quando uma versão é ativada (mesmo se for retorno a versão antiga).
11. **Seed inicial**: ao rodar `php artisan db:seed` (incluindo na pipeline de homolog), os 2 templates do catálogo ficam com `versao = 1` carregada com o texto-seed escrito em STORY-015 e marcada `ativa = true`. Idempotente: rodar 2× não cria duplicata.

## Por quê (valor para o usuário)

Direto: a equipe Turni (e o advogado externo, quando contratado) consegue editar o contrato sem mexer no código — entrega central da hipótese de PDR-012. Indireto: destrava STORY-023/024 (completar cadastro precisa da versão ativa para renderizar o aceite); valida em uso real o desenho de ADR-010; primeiro caso de uso de imutabilidade do audit log de admin com múltiplos eventos em sequência.

## Critérios de aceite

- [ ] **CA-1:** `/templates` no Backoffice em homolog responde 200 para admin autenticado; 403 fail-secure caso contrário.
- [ ] **CA-2:** Catálogo lista os 2 templates do MVP com nome amigável, slug, versão ativa, autor, data. Visual coerente com `preview-backoffice.html`.
- [ ] **CA-3:** Detalhe `/templates/{slug}` exibe versão ativa renderizada (com placeholders visíveis) + histórico de versões em ordem decrescente.
- [ ] **CA-4:** "Criar nova versão" abre editor com conteúdo da versão ativa pré-carregado. Editor + preview side-by-side funcionam. Markdown formatado no preview; placeholders destacados visualmente.
- [ ] **CA-5:** Salvar tentativa com **placeholder fora da lista canônica** bloqueia com mensagem acionável que cita o placeholder problemático.
- [ ] **CA-6:** Salvar com sucesso cria nova versão com `ativa = false`, número sequencial correto, autor + timestamp.
- [ ] **CA-7:** Audit log: salvar gera `admin.template.version_created`; ativar gera `admin.template.version_activated`. Verificação em homolog via query.
- [ ] **CA-8:** Ativação exige confirmação dupla com mensagem que explica claramente que aceites passados **não mudam**.
- [ ] **CA-9:** Transação de ativação é atômica: ou a versão alvo fica `ativa=true` E a anterior `ativa=false`, ou nada muda. Teste cobre.
- [ ] **CA-10:** Imutabilidade verificada: tentativa de UPDATE/DELETE direto no Postgres numa linha de `template_versoes` falha (registrar evidência no runbook).
- [ ] **CA-11:** Reativação de versão antiga ("voltar versão") funciona pelo mesmo fluxo do ativar; audit log captura.
- [ ] **CA-12:** Seed carrega versão 1 do texto-seed de STORY-015 nos dois templates em ambientes dev/homolog, idempotente.
- [ ] **CA-13:** Acessibilidade WCAG 2.1 AA: editor navegável por teclado; preview com região live para leitor de tela; tema dual claro/escuro funciona.
- [ ] **CA-14:** Cobertura unitária ≥ 80% / ≥ 98% no núcleo (versionamento, ativação atômica, validação de placeholder, autoria).
- [ ] **CA-15:** **E2E em browser real** cobrindo: (a) admin abre o catálogo, vê 2 templates; (b) admin cria nova versão do template PF, salva → versão 2 aparece como histórica; (c) admin ativa a versão 2 → catálogo passa a apontar para versão 2 ativa; aceite de teste pré-existente (criado por seed para esse teste) ainda referencia versão 1 e renderiza versão 1 (cobre imutabilidade do aceite — núcleo de PDR-012).
- [ ] **CA-16:** Carrega versão 1 de cada template a partir dos arquivos `docs/especificacao/contratos/template-*.md` de STORY-015 (ler arquivo no seeder, hash do conteúdo registrado como evidência de fidelidade).

## Fora de escopo

- WYSIWYG / rich text editor — textarea + Markdown serve no MVP; pode virar pedido da equipe Turni se incomodar.
- Diff visual entre versões — útil mas não crítico no MVP; entrega futura.
- Aprovação multi-admin (uma versão precisar de 2 confirmações) — fora do MVP.
- Templates além dos 2 fixos (`pf_autonomo_eventual`, `mei_pj_b2b`) — PDR-012 sinaliza que novos contextos viram revisão se aparecerem.
- Geração de PDF do contrato — fora do MVP (renderização é texto Markdown).
- Edição inline da versão ativa — proibida por design (PDR-012 + imutabilidade).
- Conteúdo do texto-seed — STORY-015.

## Padrões de qualidade exigidos

`quality-standards.md`. Em particular:

- **Cobertura ≥ 80% / ≥ 98% núcleo** (versionamento sequencial, ativação atômica, validação de placeholder, audit log writer).
- **E2E em browser real** cobrindo CA-15 na pipeline de homolog.
- **TDD** nas regras.
- **Segurança (§4)**: edição exige admin autenticado + middleware; CSRF Livewire; audit log captura toda ação; conteúdo de template **não é executado como código** (apenas renderizado — sem eval, sem template injection — mesmo o motor de renderização escolhido em ADR-010 é restrito a substituição de placeholders, **não** a expressões arbitrárias).
- **Observabilidade (§3)**: log estruturado por ação; métrica de versões criadas por dia; alerta se 5+ ativações em 1h (sinal de uso suspeito).
- **Banco**: migração das tabelas Template/TemplateVersao (já fixadas em ADR-010), idempotente, reversível. Seed idempotente.
- **Acessibilidade (§5)**: WCAG 2.1 AA; tema dual.

## Dependências

- **Bloqueada por:** STORY-013 (ADR-010 `accepted` — esquema). STORY-015 (texto-seed `done` — fonte do seeder). STORY-016 (admin login + audit log infra). Designer entrega `SCREEN-STORY-020-editor-templates` em `ready`; sync ≤15 min.
- **Bloqueia:** STORY-023/024 (geração de AceiteEletronico precisa de versão ativa carregada); STORY-025 (validação).
- **Pré-requisitos:** STORY-006, STORY-007, STORY-016.

## Decisões já tomadas (não as reabra)

- **PDR-012** — Templates editáveis no backoffice; versionamento append-only; aceites passados imutáveis.
- **ADR-010** — esquema concreto.
- **ADR-009** — eventos auditáveis canônicos.
- **STORY-015** — versão 1 dos templates (fonte do seeder).
- **Princípios do PO**.

## Liberdade técnica do agente

Você decide:
- Componente de edição (textarea + preview vs editor de markdown leve como SimpleMDE — desde que **sem execução de código**).
- Layout side-by-side responsivo no desktop-first do admin.
- Estratégia exata de seed (ler arquivo md de STORY-015 vs duplicar conteúdo no seeder — recomendação: ler arquivo, registrar hash para auditoria de fidelidade).
- Mensagens de toast/feedback.

Você NÃO decide:
- Permitir edição inline da versão ativa (PDR-012).
- Reabrir esquema (ADR-010) ou conjunto de eventos auditáveis (ADR-009).
- Suprimir confirmação dupla na ativação, cobertura, E2E, imutabilidade.

## Definição de Pronto (DoD)

- [ ] CA-1 a CA-16 passam com evidência.
- [ ] Cobertura medida no PR.
- [ ] E2E verde na pipeline de homolog.
- [ ] Imutabilidade verificada (CA-10).
- [ ] Seed idempotente verificado em homolog.
- [ ] Sync Designer↔Programador registrado.
- [ ] `index.json` atualizado.
- [ ] "Notas" preenchida.
- [ ] IDR se houve decisão técnica relevante.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Carregue `docs/skills/programador/SKILL.md`. Confirme screen spec em `ready`. TDD nas regras. PR com evidência. `done` após deploy verde.

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
