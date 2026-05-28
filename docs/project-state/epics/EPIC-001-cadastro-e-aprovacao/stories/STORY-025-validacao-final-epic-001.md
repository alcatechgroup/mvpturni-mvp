---
story_id: STORY-025
slug: validacao-final-epic-001
title: Validação final do EPIC-001 Cadastro e aprovação
epic_id: EPIC-001
sprint_id: null
type: validation
target_role: validador
requires_design: false
status: ready
owner_agent: null
created_at: 2026-05-28
updated_at: 2026-05-28
estimated_session_size: M
---

# STORY-025 — Validação final do EPIC-001

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Ela contém tudo o que você precisa. Se algo estiver ambíguo, registre a dúvida na seção "Notas do agente" no final e pause em vez de adivinhar. **Limite de papel:** você é o Validador. Você produz **fato + veredito**. **Não** propõe estórias de correção, **não** sugere próximos passos, **não** planeja. Planejamento é do PO. (Aprendizado da skill após rodada 1 de STORY-011.)

## Contexto (por que esta estória existe)

EPIC-001 entrega o funil completo de identidade do Turni: pré-cadastro público de profissional (PF/MEI/PJ) e contratante, aprovação manual via backoffice dentro do SLA de 24h, editor de templates contratuais com versionamento (PDR-012), AceiteEletronico imutável gerado no fim do completar cadastro, RBAC vivo entre WebApp e Backoffice com audit log do admin, e e-mails transacionais. Antes do épico fechar como `done`, o **validador independente** percorre o checklist, verifica evidências, e produz veredito factual em `validation/report.md`. Sem isso, o PO não marca o épico como concluído (princípio não-negociável #5 — estado registrado).

A validação aprende com a STORY-011 do EPIC-000: **2 rodadas se necessário** (reprovação é sinal saudável); validador se atém a evidência + veredito; PO trata o relatório como gatilho de planejamento (sem pressionar o validador a aprovar).

- Épico: `docs/project-state/epics/EPIC-001-cadastro-e-aprovacao/epic.md`
- Documentos canônicos a ler ANTES de validar:
  - `validation/checklist.md` deste épico (criado pelo PO; lista de verificação operacional do validador)
  - Todas as STORYs 012–024 deste épico (estados, evidências, "Notas do agente")
  - Todos os PDRs/ADRs aceitos referenciados (PDR-001, PDR-003, PDR-012, PDR-013; ADR-007, ADR-008, ADR-009, ADR-010, ADR-011)
  - `docs/especificacao/domain/usuario.md` e `compliance.md` (referência funcional)
  - `docs/especificacao/non-functional.md` (SLA, segurança, LGPD, observabilidade, acessibilidade)
  - `docs/skills/validador/SKILL.md`
  - `docs/skills/po/references/quality-standards.md`
  - `docs/skills/po/templates/validation-checklist.md` (se existir)

## O quê (objetivo desta estória)

Executar o checklist de validação do EPIC-001 e produzir relatório com veredito.

1. Verificar **pré-condições** (STORY-012 a STORY-024 com `status: done` no `index.json`; EPIC-001 com `status: in_review`).
2. Executar o checklist em `epics/EPIC-001-cadastro-e-aprovacao/validation/checklist.md`. Cada item tem **status** (`pass`, `pass com ressalva`, `fail bloqueante`, `fail não-bloqueante`, `n/a`) e **evidência observável** (comando rodado + saída, screenshot, log, URL de homolog testada, query no banco, etc.).
3. **Métrica primária do épico**: cadastro fim a fim em homologação (pré-cadastro → aprovação → completar → ativo) executável em ≤ 5 min para o usuário, com aprovação manual visível ao admin em ≤ 30s após submit. Verificar percorrendo o fluxo em homolog manualmente E via E2E na pipeline. **Esta métrica é observada com o código completo do épico deployado** (lição da STORY-011: estados intermediários não contam).
4. **Validar imutabilidade do AceiteEletronico em uso real**: criar aceite via fluxo; ativar nova versão de template no backoffice; verificar que o aceite criado **não muda** (renderiza versão original). Esta é a verificação central de PDR-012.
5. **Validar imutabilidade do audit log de admin**: tentativa de UPDATE/DELETE direto em psql na tabela falha; cobertura dos eventos canônicos (`admin.login`, `admin.user.approved`, `admin.user.removed`, `admin.template.version_created`, `admin.template.version_activated`).
6. **Validar RBAC vivo**: cada combinação papel × interface (admin no WebApp, contratante no Backoffice, profissional no Backoffice, profissional logado tentando acessar dados de outro profissional via API direta) é testada e bloqueada conforme ADR-007/ADR-009.
7. **Validar LGPD básica**: dados pessoais coletados estão registrados (lista atualizada); dados sensíveis criptografados em repouso (query psql); aceite dos Termos no checkbox registra timestamp.
8. **Validar segurança transversal**: senhas Argon2id, nenhum segredo em código (gitleaks verde), throttling Fortify ativo, defesa contra enumeração de e-mails (não revela se e-mail existe), CSRF Sanctum, HTTPS obrigatório, cookie `httpOnly + Secure + SameSite=Lax` verificado em homolog deployado, mascaramento em logs (e-mail destinatário, senha, documento).
9. **Validar pendência herdada**: `php artisan migrate:rollback` foi exercido em homologação (F-NB-1 do EPIC-000) — STORY-016 deveria ter cumprido.
10. **Validar cobertura e E2E**: cobertura ≥ 80% geral / ≥ 98% núcleo no código novo do épico; E2E em browser real cobrindo todos os fluxos chave verdes na pipeline.
11. **Validar observabilidade**: log estruturado JSON, métricas RED (taxa de cadastros, aprovações, e-mails enviados), alertas configurados (SLA de 24h em risco, falha persistente de envio crítico).
12. **Validar acessibilidade**: WCAG 2.1 AA nas telas implementadas (pelo menos amostragem com Lighthouse ou axe).
13. **Produzir `validation/report.md`** em `epics/EPIC-001-cadastro-e-aprovacao/validation/report.md` com veredito final.

**Vereditos possíveis** (mesma régua de STORY-011):
- `approved`: zero fails (bloqueantes ou não); épico pronto para `done`.
- `approved_with_pending`: zero fails bloqueantes, fails não-bloqueantes presentes. PO decide se trata como goal atingido ou pendência carregada (precedente de STORY-011 — em geral é carry forward para próximo épico).
- `rejected`: ≥ 1 fail bloqueante. PO abre estória(s) de correção em mini-sprint dedicada; épico permanece `in_review`.

## Por quê (valor para o usuário)

Direto: garantia que o ciclo de cadastro/aprovação está **defensável** antes de seguir para os épicos seguintes (vagas, candidatura, pagamento) que dependem da identidade real. Indireto: 2ª aplicação real do ciclo "valida → reprova → corrige → revalida" — calibra o desenho do papel validador para épicos maiores à frente.

## Critérios de aceite

- [ ] **CA-1:** `epics/EPIC-001-cadastro-e-aprovacao/validation/report.md` existe com `verdict` preenchido (`approved` | `approved_with_pending` | `rejected`).
- [ ] **CA-2:** Cada item do `validation/checklist.md` tem status registrado e evidência (comando + saída, log, screenshot, query, URL).
- [ ] **CA-3:** Métrica primária verificada com **código completo do épico** deployado em homolog (lição STORY-011).
- [ ] **CA-4:** Imutabilidade do AceiteEletronico verificada em uso real (cenário com ativação de nova versão pós-aceite).
- [ ] **CA-5:** Imutabilidade do audit log verificada via psql (tentativa de UPDATE/DELETE bloqueada).
- [ ] **CA-6:** RBAC vivo verificado nas 4+ combinações de papel × interface.
- [ ] **CA-7:** Critério herdado F-NB-1 do EPIC-000 (`migrate:rollback` em homolog) — status registrado: `pass` se evidência da STORY-016 confirma; `fail não-bloqueante` se não (não bloqueia o EPIC-001, mas continua pendente para próximos).
- [ ] **CA-8:** Cobertura unitária medida nos componentes do EPIC-001; metas atingidas ou exceção justificada por item.
- [ ] **CA-9:** E2E verde nos cenários canônicos do EPIC-001 na pipeline de homolog.
- [ ] **CA-10:** `index.json` atualizado: `epics[EPIC-001].validation_report` aponta para o relatório com `verdict` e `validated_at`; status da própria estória STORY-025 transiciona para `done` ao final.

## Fora de escopo

- Decidir o que fazer com o veredito — PO planeja (aprende com STORY-011).
- Propor estórias de correção — PO planeja.
- Reabrir PDR/ADR — fora do papel do validador.
- Avaliar PDR-012 do ponto de vista jurídico (texto do contrato) — não é função do validador; é decisão futura da equipe Turni.
- Implementar correções (validador valida; não corrige).

## Padrões de qualidade exigidos

Esta estória é **validation**. Segue `quality-standards.md` com as exceções autorizadas em `story-craft.md` (validação não produz código de produção):

- **Cobertura unitária / E2E:** N/A nesta estória (mede a cobertura/E2E das outras).
- **Disciplina aplicável:** factualidade, evidência observável por item (não declaração genérica), limite de papel (não planejar, não corrigir, não propor estórias — só fato + veredito).
- **Independência:** validador roda o checklist sem coordenação com o autor das STORYs implementadas; PO não pressiona por aprovação.

## Dependências

- **Bloqueada por:** STORY-012 a STORY-024 com `status: done`. EPIC-001 com `status: in_review`. `validation/checklist.md` deste épico preenchido pelo PO.
- **Bloqueia:** fechamento de EPIC-001 (`status: done`); abertura do EPIC-002 com fundação de identidade pronta.
- **Pré-requisitos:** ambiente de homolog operacional; acesso de leitura ao banco (psql) para verificações de imutabilidade.

## Decisões já tomadas (não as reabra)

- **Princípio do PO #5** — Estado registrado, sempre. Épico não fecha sem report.
- **`docs/skills/validador/SKILL.md`** — Validador produz fato + veredito; não planeja.
- **STORY-011** (precedente) — 2 rodadas são esperadas; reprovar é saudável.
- **Critério herdado F-NB-1 do EPIC-000** — `migrate:rollback` em homolog é critério para a primeira estória do EPIC-001 com migração de lógica de negócio (STORY-016 ou outra).

## Liberdade do validador

Você decide:
- Ordem de execução dos itens do checklist.
- Quais comandos exatos rodar para colher evidência.
- Como organizar o `report.md` (sugestão: blocos por temática — pré-condições, CAs das estórias, cobertura, automação, funcionalidade observável, qualidade transversal, documentação, métrica primária — seguindo padrão de STORY-011).
- Quais ressalvas registrar (cada `pass com ressalva` é uma nota factual; sem propor solução).

Você NÃO decide:
- Marcar veredito como `approved` se há `fail bloqueante`.
- Propor estórias de correção (PO faz).
- Reabrir PDR/ADR.
- Sugerir próximos passos.

## Definição de Pronto (DoD)

- [ ] CA-1 a CA-10 passam.
- [ ] `report.md` em `validation/` com veredito final, status item-a-item, evidência por item.
- [ ] Se for `rejected`: lista de fails bloqueantes com evidência factual de cada um — sem sugestão de correção.
- [ ] `index.json` atualizado.
- [ ] "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Carregue `docs/skills/validador/SKILL.md` (atendendo o limite de papel afinado pela STORY-011). PR não se aplica (relatório é entregue direto no commit). `done` quando relatório está completo e `index.json` atualizado.

## Notas do agente (preenchido durante/após execução)

### Entrada inicial
(a preencher)

### Pré-condições
(a preencher — `index.json` consultado, estado das STORYs)

### Itens executados (com evidência)
(a preencher por bloco — mesma estrutura do `report.md` do EPIC-000 serve como modelo)

### Veredito final
(a preencher: `approved` | `approved_with_pending` | `rejected`)

### Resultado final / evidência
(a preencher — link do `report.md`)
