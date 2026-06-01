---
story_id: STORY-054
slug: validacao-final-epic-002
title: Validação final do EPIC-002 — Vaga, feed e candidatura
epic_id: EPIC-002
sprint_id: SPRINT-2026-W27
type: validation
target_role: validador
requires_design: false
design_screen_id: null
status: ready
owner_agent: null
created_at: 2026-06-01
updated_at: 2026-06-01
estimated_session_size: M
produces_idr: null
---

# STORY-054 — Validação final do EPIC-002

> **Para o validador:** lembrete da STORY-011/025 — você é independente. Seu papel é **constatar** (evidência + veredito), **não** planejar correções nem sugerir próximos passos. Aprendizado da W23: o 1º relatório que extrapolou foi corrigido e a 2ª rodada se ateve a evidência + veredito. Use o checklist abaixo, rode os testes, observe em homolog, escreva `validation/report.md`. Veredito possível: `approved`, `approved_with_pending` (com fails não-bloqueantes), `rejected`. PO decide o que fazer com o veredito.

## Contexto

EPIC-002 entrega o primeiro **encontro** entre profissional e contratante (publicar vaga → feed ranqueado → candidatura → painel de candidatos), com edição material PDR-009 funcionando e notificações in-app + e-mail. Esta estória é o portão final antes de fechar o épico e abrir EPIC-003 (Aceite, PIN, Pix).

- Épico: `epics/EPIC-002-vaga-feed-e-candidatura/epic.md`
- Documentos: tudo que as stories anteriores referenciaram + `validation/checklist.md` (a criar nesta estória).

## O quê

Produzir `epics/EPIC-002-vaga-feed-e-candidatura/validation/checklist.md` (lista de itens verificáveis cobrindo os entregáveis do épico) e `validation/report.md` (relatório com evidências e veredito). O checklist é escrito uma vez pelo validador no início; o relatório resume o que foi observado.

## Por quê

Sem validação independente, `done` do épico é autoavaliação do programador. PDR/processo do projeto exige validador externo para o fechamento ser confiável (lição STORY-011 + STORY-025).

## Critérios de aceite

- [ ] **CA-1:** `validation/checklist.md` escrito cobrindo os entregáveis declarados em `epic.md` (publicar vaga, vaga aparece no feed com score, breakdown clicável, candidatura em 1 toque, painel de candidatos ranqueado, filtros do feed, edição material com notificação PDR-009).
- [ ] **CA-2:** Métrica primária do épico verificada **com código completo do épico deployado** (lição W23/W25): publicar vaga e medir tempo até primeira candidatura em homolog em cenário seedado. Validador documenta tempo medido contra SLA (≤ 2h Member Start).
- [ ] **CA-3:** Métrica de match transparente: 100% das vagas no feed exibem score com breakdown clicável (validador navega o feed e o detalhe, captura screenshots).
- [ ] **CA-4:** Métrica de performance: feed p95 ≤ 800ms com 1k vagas seedadas (validador roda o stress seed + script de carga e mede em homolog, não no CI).
- [ ] **CA-5:** Gate PDR-005: validador tenta publicar vaga com contratante seed que tem turno por avaliar → bloqueio confirmado. Tenta candidatar profissional seed com turno por avaliar → bloqueio confirmado.
- [ ] **CA-6:** PDR-009 ciclo completo: validador edita vaga materialmente (muda valor) com 2 candidatos pendentes → confirma snapshot em `vaga_versoes` + estado candidaturas + e-mail recebido em Mailpit + cron de auto-retirada após 24h (forçando clock no CI ou aguardando em homolog).
- [ ] **CA-7:** RBAC vivo: contratante na rota de feed → 403. Profissional na rota de publicar vaga → 403. Contratante em painel de candidatos de vaga alheia → 403.
- [ ] **CA-8:** Imutabilidade de `vaga_versoes`: tentativa de UPDATE/DELETE manual via SQL falha (trigger bloqueia).
- [ ] **CA-9:** Audit log: validador faz 1 ação de cada tipo (criar vaga, candidatar, editar materialmente, cancelar) e verifica registro em `audit_logs` (queries SQL no validation/report).
- [ ] **CA-10:** Cobertura agregada do código novo do épico ≥ 80% geral; ≥ 95% nos módulos `app/Domain/Match/` (STORY-045) e `App\Http\Controllers\Api\CandidaturaController` (STORY-050 — gates são núcleo de regra).
- [ ] **CA-11:** Pipelines verdes na main em todas as estórias do EPIC-002 no momento do veredito (validador captura link do CI).
- [ ] **CA-12:** `validation/report.md` termina com veredito explícito (`approved` / `approved_with_pending` / `rejected`) + lista de evidências (links de PR, deploys, screenshots, logs) + lista de fails (bloqueantes vs. não-bloqueantes, formato F-B-N / F-NB-N como STORY-011/025).

## Fora de escopo

- Planejar estórias de correção (papel do PO).
- Sugerir próximos passos (papel do PO).
- Reabrir decisões de PDR/ADR (papel do PO/Arquiteto).
- Validar coisas que não estão no épico (EPIC-003 e além).

## Padrões de qualidade

- Validador segue skill `validador` (carregar antes — limite estreito: evidência + veredito).
- Rodar testes reais (não confiar em afirmação do programador).
- Capturar evidências (screenshots, logs, SQL queries) — disponíveis depois para auditoria.

## Dependências

- **Bloqueada por:** STORY-044, STORY-045, STORY-046, STORY-047, STORY-048, STORY-049, STORY-050, STORY-051, STORY-052, STORY-053 (toda a sprint exceto EPIC-008).
- **Bloqueia:** abertura do EPIC-003 (PO espera veredito antes de planejar).

## Decisões já tomadas

- Processo de validação: independente, fala fato + veredito (STORY-011 + STORY-025).
- Critério "métrica em homolog deve ser observada no estado final do épico" (aprendizado W23).

## Liberdade técnica

Decide: ordem de execução do checklist, forma de captura de evidência, estrutura do `validation/report.md`. NÃO decide: lista de itens essenciais (estão acima), veredito sem evidência.

## DoD

- [ ] `validation/checklist.md` criado.
- [ ] `validation/report.md` criado com veredito + evidências.
- [ ] `index.json` atualizado: estória `in_review` aguardando PO.
- [ ] PO recebe link do relatório.

## Notas do agente

### Veredito final
- 
### Bloqueantes (F-B-N)
- 
### Não-bloqueantes (F-NB-N)
- 
### Evidências
- 
### Links
- Relatório: `validation/report.md`
- Checklist: `validation/checklist.md`
