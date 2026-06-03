---
story_id: STORY-068
slug: validacao-final-epic-003
title: Validação final do EPIC-003 — Aceite, PIN bilateral e Pix
epic_id: EPIC-003
sprint_id: SPRINT-2026-W28
type: validation
target_role: validador
requires_design: false
design_screen_id: null
status: ready
owner_agent: null
created_at: 2026-06-03
updated_at: 2026-06-03
estimated_session_size: M
produces_idr: null
---

# STORY-068 — Validação final do EPIC-003

> **Para o validador:** lembrete da STORY-011/025/054 — você é independente. Seu papel é **constatar** (evidência + veredito), **não** planejar correções nem sugerir próximos passos. Aprendizado herdado: o 1º relatório da STORY-011 que extrapolou foi corrigido e a 2ª rodada se ateve a evidência + veredito. Use o checklist em `epics/EPIC-003-aceite-pin-e-pix/validation/checklist.md`, rode os testes, observe em homolog, escreva `validation/report.md`. Veredito possível: `approved`, `approved_with_pending` (com fails não-bloqueantes), `rejected`. PO decide o que fazer com o veredito.

## Contexto

EPIC-003 entrega o **ciclo do turno** ponta a ponta em homolog com Pagar.me sandbox: aceite + AceiteEletronico imutável + pré-autorização → PIN check-in + geofencing → cronômetro bilateral vivo → PIN check-out → captura + Pix sandbox em ≤ 15 min. Cancelamento + `no_show_pro` liberam pré-autorização. Habitualidade (PDR-002) aplicada nos 4 cenários. Notificações in-app + e-mail nos 8 eventos.

Esta estória é o portão final antes de fechar o épico e abrir EPIC-004 (Avaliação recíproca).

- Épico: `epics/EPIC-003-aceite-pin-e-pix/epic.md`
- Checklist: `epics/EPIC-003-aceite-pin-e-pix/validation/checklist.md`

## O quê

Executar o checklist do EPIC-003 e produzir `validation/report.md` com veredito factual + evidências (logs, screenshots de homolog, comandos executados, resultados de testes).

## Por quê

Sem validação independente, não há prova confiável de que o épico mais arriscado da onda fechou. Aprendizado W23/W25/W27: validador descobre o que o autor não vê.

## Critérios de aceite

- [ ] **CA-1:** Checklist completo de `validation/checklist.md` percorrido — cada item marcado `[x]` com link para evidência ou `[ ]` com motivo.
- [ ] **CA-2:** Suíte completa de testes rodada em CI: api ≥ 80% / ≥ 98% no núcleo (modelo Turno, máquina de estados, ACL Pagar.me, PIN, geofencing, habitualidade), admin ≥ 80%, webapp ≥ 80%.
- [ ] **CA-3:** Métrica primária do EPIC-003 observada em homolog: ≥ 95% dos turnos seedados completam ciclo `confirmado → finalizado → Pix sandbox`. Resultado documentado.
- [ ] **CA-4:** SLA Pix observado: ≥ 95% dos Pix sandbox em ≤ 15 min no conjunto seedado. Resultado documentado com timestamps reais.
- [ ] **CA-5:** Validação de PIN ≤ 500ms p95 observada em log JSON estruturado de homolog. Resultado documentado.
- [ ] **CA-6:** Cronômetro bilateral sincronizado em ≤ 2s observado em 2 navegadores abertos no mesmo turno. Screenshot ou vídeo anexado.
- [ ] **CA-7:** Habitualidade nos 4 cenários PDR-002 testada em homolog: PF 1ª/2ª libera; PF 3ª bloqueia (mensagem clara em ambos os lados); PJ 3ª com override registra cláusula no AceiteEletronico; transição de semana reseta. Cada um com evidência.
- [ ] **CA-8:** Imutabilidade do AceiteEletronico do turno verificada via tentativa de `UPDATE`/`DELETE` direto no Postgres (deve falhar). Resultado documentado.
- [ ] **CA-9:** Imutabilidade do audit log verificada (espelha CA da STORY-054).
- [ ] **CA-10:** RBAC vivo nas duas interfaces verificado: cruzados retornam 403 fail-secure. Cenários: profissional A não vê turno do profissional B; contratante X não vê turno do contratante Y; profissional não chama endpoint de contratante e vice-versa.
- [ ] **CA-11:** LGPD básica verificada (espelha CA de EPIC-001): consentimento registrado, dados sensíveis criptografados em repouso (ADR-009).
- [ ] **CA-12:** Observabilidade verificada — log JSON em todas as operações financeiras com `request_id` propagado; log-based metrics de captura/Pix funcionando no Cloud Monitoring.
- [ ] **CA-13:** Acessibilidade básica das telas novas — contraste AAA no PIN (≥ 64pt + cor de alta legibilidade), navegação por teclado nas telas críticas, microcopy clara.
- [ ] **CA-14:** Veredito emitido em `validation/report.md` (`approved` / `approved_with_pending` / `rejected`) com fails categorizados em bloqueantes vs não-bloqueantes (`F-NB-N`).

## Fora de escopo

- Planejar correções (papel do PO).
- Sugerir próximos passos (papel do PO).
- Testar `em_disputa` (EPIC-005).
- Testar `finalizado_ajustado` (EPIC-005).
- Testar avaliação recíproca (EPIC-004).

## Padrões de qualidade

`docs/skills/validador/`. Veredito é factual: descreve o que **observou**, não o que **deveria** acontecer. PO interpreta.

## Dependências

- **Bloqueada por:** STORY-055..067 — **todas** em `done` e deployadas em homolog.
- **Bloqueia:** abertura do EPIC-004.
- **Pré-requisitos:** ambiente homolog operante com seed; credenciais Pagar.me sandbox disponíveis.

## Decisões já tomadas

Todas as ADRs/PDRs/IDRs vigentes — validador respeita, não reabre. **Em particular ADR-018 (UUIDv7 em PKs) — checklist deve verificar que PKs/FKs do EPIC-003 (Turno, AceiteEletronicoTurno, pagamento_operacoes) são UUID na base de homolog; tentativa de inserir `bigint` no `id` falha.**

## Liberdade técnica

Decide: como sequenciar a execução do checklist, formato exato do relatório (dentro do template).

NÃO decide: que está aprovado (veredito é factual, não negociado); planejar correções (papel do PO).

## Definição de Pronto

- [ ] Checklist completo percorrido.
- [ ] `validation/report.md` escrito.
- [ ] `index.json` atualizado com veredito + path do report.
- [ ] "Notas do agente" preenchida (na própria estória).
- [ ] **NÃO** marca o EPIC-003 como `done` — o PO faz isso depois de ler o report.

## Protocolo

`docs/skills/po/references/agent-task-format.md` + `docs/skills/validador/` (carrega skill do validador).

## Notas do agente

### Decisões tomadas
### Descobertas
### Bloqueios encontrados
### IDRs criados
### Cobertura final
- Unitários:
- E2E:
### Links de evidência
- PR:
- Pipeline:
- Deploy de homologação:
- Report: `epics/EPIC-003-aceite-pin-e-pix/validation/report.md`
