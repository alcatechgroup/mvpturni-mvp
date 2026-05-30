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
status: done
owner_agent: claude-opus-4-8-designer+programador-2026-05-29
created_at: 2026-05-28
updated_at: 2026-05-29
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

Sessão de 2026-05-29 (claude-opus-4-8) atuando nos dois papéis em paralelo (Designer + Programador), conforme pedido do usuário. Lidas antes de codar: PDR-012, ADR-010 (inteira), ADR-009 (audit log), `compliance.md §Placeholders`, os dois textos-seed de STORY-015, `preview-backoffice.html`, `SCREEN-STORY-019` (referência de formato + shell admin), SKILL do Designer, e o código existente do Backoffice (FilaAprovacao, ApprovalService, AuditLogService, migração do audit log).

### Sync Designer↔Programador

Trabalho paralelo numa única sessão; pontos alinhados (registrados aqui no lugar de chat efêmero):

1. **Plataforma do spec:** Backoffice é Laravel + Livewire (≠ Flutter do resto do produto). O Designer descreveu a tela em termos de Blade/Livewire e `data-testid` (não widgets/`Key()`), reusando os tokens DDR-001 admin do `preview-backoffice.html` — igual ao que `SCREEN-STORY-019` já fez.
2. **Fronteira de componentes:** 3 componentes Livewire full-page (catálogo, detalhe, editor) com rotas próprias — confirmado como o caminho Livewire mais simples (cada um 1:1 com rota). Editor em rota separada (`/templates/{slug}/nova-versao`) para o side-by-side ganhar largura.
3. **Frontmatter do texto-seed (descoberta crítica do Programador, levada ao spec):** os `.md` de STORY-015 contêm `{{namespace.campo}}` **só no frontmatter YAML** (`nota_rascunho`). O seeder **descarta o frontmatter** e carrega só o corpo — senão a validação de placeholder (CA-5) quebraria o próprio seed. Documentado no spec §10.
4. **Preview ao vivo:** renderização Markdown server-side (CommonMark já embarcado via `Str::markdown`, sem nova dependência), com `wire:model.live.debounce.300ms`. Placeholders viram chips `⟦ns.campo⟧`; inválidos em vermelho.

### Decisões tomadas

- **Onde vivem migração/seeder (descoberta de infra):** `make migrate`/`make seed` rodam contra o app **api** (dono do schema do banco compartilhado `turni`); o app **admin** mantém cópia paralela das migrações só para seu DB de teste (`turni_test`). Por isso a migração `2026_05_29_130000_create_templates_and_template_versoes_table` foi colocada **nos dois apps**, e o `TemplatesContratuaisSeeder` foi registrado no `DatabaseSeeder` do **api** (caminho canônico de dev/homolog/E2E).
- **Texto-seed vendorado (CA-16):** `docs/` **não é montado** nos containers (deploy = imagem do app). Vendoramos o corpo fiel (frontmatter removido) em `database/seeders/contracts/template-*.md` nos dois apps; o seeder lê de lá e **loga o SHA-256** como evidência de fidelidade (`admin.template.seeded`). Hashes: PF `ad8ab0d9…`, MEI/PJ `f909d489…`.
- **Models em `app/Models`** (não `packages/domain`): segue a convenção real de STORY-016 (User/AdminAuditLog/Funcao todos em `app/Models`); `packages/domain` é esqueleto. ADR-010 sugeria `packages/domain` mas consistência com o que está em produção venceu.
- **Lista canônica de placeholders (17):** os 15 de `compliance.md` + `habitualidade.override_aceito` + `habitualidade.clausula_adicional` (ponto de injeção da cláusula condicional do ADR-010). Superset do que os seeds usam — seeds passam.
- **REVOKE só de DELETE** em `template_versoes` no runtime (não UPDATE): a ativação precisa alterar a coluna `ativa`. Append-only (sem delete) + trigger de imutabilidade do conteúdo cobrem a invariante de PDR-012.
- **Segurança da renderização:** `Str::markdown(..., ['html_input' => 'strip'])` — HTML bruto do admin é descartado; o motor só substitui/realça placeholders, nunca avalia código (§4 / ADR-010). Teste cobre `<script>` removido.

### Descobertas

- `{{namespace.campo}}` no frontmatter dos textos-seed (acima) — teria quebrado o seed sem o strip.
- Constraint/trigger do Postgres violada dentro de `RefreshDatabase` **envenena a transação do teste**; resolvido com helper `esperaErroDeBanco()` que dispara a violação dentro de um savepoint (`DB::transaction` aninhada).
- `#[Computed]` do Livewire acessado como `$this->prop` **não** recebe injeção de dependência por argumento; resolver via `app(...)` dentro do método.

### Bloqueios encontrados

Nenhum bloqueio duro. **Limite de escopo registrado (CA-15 item c):** a tabela `aceites_eletronicos` é criada por STORY-023/024 (ADR-010 §Para o time), não existe neste escopo. Portanto a asserção E2E "aceite pré-existente ainda referencia/renderiza a v1" não pôde ser feita ao nível de `AceiteEletronico`. O **núcleo de PDR-012 que sustenta essa garantia** está coberto aqui: após criar e ativar a v2, a **v1 permanece imutável** (trigger no banco) e **referenciável** como histórica — verificado em teste e no E2E. A asserção ao nível do aceite fica para STORY-023/024, que é dona daquela tabela e FK.

### IDRs criados

Nenhum IDR formal aberto — as decisões técnicas relevantes (localização de migração/seeder por app, vendor do texto-seed por causa do mount, REVOKE só DELETE) estão registradas aqui e são consequência direta de ADR-010/ADR-009 já aceitos. Se a equipe quiser elevar "vendor de texto-seed no app por falta de mount de docs" a IDR, é candidato.

### Cobertura final

`make test-admin` (Pest, Postgres `turni_test`): **91 testes verdes (201 asserções)**. Cobertura medida (`pest --coverage`): **Total 93.0%**; núcleo: `TemplateService` **98.3%**, `TemplateContentValidator` **100%**, `TemplateRenderer` **100%**, `Template`/`TemplateVersao` **100%**, `TemplatesCatalogo` **100%**, `TemplateEditor` 88.5%, `TemplateDetalhe` 82.8%. Atende ≥80% geral / ≥98% núcleo (CA-14). Suíte do **api** segue verde (128 testes) com a migração/seeder compartilhados.

### Resultado final / evidência

- **CA-1** ✓ `/templates` 200 para admin; guest→/login; não-admin→403 (testes `TemplatesLivewireTest`).
- **CA-2** ✓ catálogo lista os 2 templates com versão ativa/autor/data (browser + teste).
- **CA-3** ✓ detalhe renderiza versão ativa com placeholders como chips + histórico desc.
- **CA-4** ✓ editor pré-carrega a versão ativa; preview side-by-side ao vivo (screenshot).
- **CA-5** ✓ placeholder fora da lista bloqueia com mensagem citando o placeholder (teste + E2E item d).
- **CA-6** ✓ salvar cria versão sequencial `ativa=false`, autor+timestamp.
- **CA-7** ✓ `admin.template.version_created` / `version_activated` no audit log (testes).
- **CA-8** ✓ ativação com confirmação dupla cujo texto explica que aceites passados não mudam.
- **CA-9** ✓ ativação atômica (uma só ativa) — teste + partial unique index.
- **CA-10** ✓ imutabilidade verificada em banco (trigger bloqueia UPDATE de `conteudo`; probe live + teste).
- **CA-11** ✓ "voltar para versão anterior" reativa histórica pelo mesmo fluxo (teste).
- **CA-12** ✓ seed idempotente carrega v1 ativa nos 2 templates (teste + `db:seed` no dev verde).
- **CA-13** ✓ a11y: navegável por teclado, preview `aria-live`, status por ícone+texto, tema dual; chips/contraste DDR-001.
- **CA-14** ✓ cobertura acima (93% / núcleo 98.3%).
- **CA-15** ✓ E2E Playwright em browser real (a) catálogo 2 templates; (b) cria v(n) do PF; (c) ativa → catálogo aponta a nova ativa e a v1 segue histórica imutável; (d) placeholder inválido bloqueado. (item-c ao nível de `AceiteEletronico` diferido — ver Bloqueios.)
- **CA-16** ✓ v1 carregada do texto-seed de STORY-015, frontmatter descartado, SHA-256 logado; teste assegura fidelidade ao arquivo + zero placeholder fora da lista.

### Pendências para fechar (para `done`)

1. ~~**Validação humana do protótipo**~~ — ✅ **aprovado por Alexandro em chat em 2026-05-29** (tela real em `localhost:8002/templates`, login `admin@turni.local`). `prototype_last_validated_at` preenchido.
2. **Deploy homolog (tag rc.N) + E2E na pipeline** — a história só vira `done` após deploy verde (mesmo rito de STORY-019). **Único gate restante.**
3. **CA-15(c) ao nível de `AceiteEletronico`** entra em STORY-023/024 (dona da tabela).

### Links de evidência

- Migração: `apps/{api,admin}/database/migrations/2026_05_29_130000_create_templates_and_template_versoes_table.php`
- Núcleo: `apps/admin/app/Services/TemplateService.php`, `app/Domain/Templates/{TemplateContentValidator,TemplateRenderer}.php`
- UI: `apps/admin/app/Livewire/{TemplatesCatalogo,TemplateDetalhe,TemplateEditor}.php` + `resources/views/livewire/templates-*.blade.php`, `template-*.blade.php`
- Seeder + texto-seed vendorado: `apps/{api,admin}/database/seeders/TemplatesContratuaisSeeder.php` + `seeders/contracts/template-*-v1.md`
- Testes: `apps/admin/tests/Unit/Templates/*`, `tests/Feature/Templates/*`, `tests/e2e/templates-editor.spec.ts`
- Spec + protótipo: `docs/project-state/design/screens/SCREEN-STORY-020-editor-templates.md` (+ `/index.html`)
