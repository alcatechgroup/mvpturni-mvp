---
story_id: STORY-052
slug: edicao-material-vaga-pdr009
title: Edição material de vaga (PDR-009) — snapshot + estado `pendente_revisao_apos_edicao` + cron 24h
epic_id: EPIC-002
sprint_id: SPRINT-2026-W27
type: implementation
target_role: programador
requires_design: true
design_screen_id: SCREEN-STORY-052-editar-vaga-e-diff
status: ready
owner_agent: null
created_at: 2026-06-01
updated_at: 2026-06-01
estimated_session_size: M
produces_idr: null
---

# STORY-052 — Edição material da vaga (PDR-009)

> **Para o agente:** estória sensível porque mexe em algo que **já tem candidatos olhando**. A regra é dura: muda → snapshot + notifica candidatos pendentes + 24h ou início do turno (o que vier antes) para confirmar; sem ação, candidatura sai automaticamente. Errar aqui = candidato confirmar uma vaga com valor antigo e ficar bravo na hora do turno.

## Contexto

PDR-009 permite contratante editar vaga após receber candidaturas — desde que candidatos sejam notificados e tenham chance de confirmar/retirar. Sem isto, contratante cancela e republica (perde candidatos alinhados) ou edita silenciosamente (quebra confiança). Esta estória entrega a parte servidor + UI de edição + cron de auto-retirada.

- Épico: `epics/EPIC-002-vaga-feed-e-candidatura/epic.md`
- Documentos: PDR-009, `domain/vaga.md` (Edição pós-candidatura), `domain/candidatura.md` (Edição material da vaga + Estados), STORY-044 (modelo `vaga_versoes` + estado `pendente_revisao_apos_edicao`), SCREEN-STORY-052.

## O quê

Endpoint `PATCH /api/vagas/{id}` que (a) detecta se a edição é material (compara contra os 6 campos da STORY-044 CA-2); (b) se material e há candidatos pendentes, cria `vaga_versoes` snapshot + transita candidaturas `pendente → pendente_revisao_apos_edicao` + dispara evento de domínio `VagaEditadaMaterialmente` (consumido por STORY-053 para notificar); (c) se não material, atualiza in-place. Cron em Cloud Run Job (reusa STORY-034) varrendo candidaturas `pendente_revisao_apos_edicao` há > 24h ou com `data_inicio < now()` e movendo para `retirada_por_edicao`. UI no WebApp do contratante: tela `/contratante/vagas/{id}/editar` mostrando preview do diff antes do submit.

## Por quê

Sem PDR-009 implementado, contratante real vai sentir falta na primeira vaga que ele esquecer um detalhe (acontece sempre). Compliance: regulamentação trabalhista cobra que candidato saiba o que está aceitando.

## Critérios de aceite

- [ ] **CA-1:** `PATCH /api/vagas/{id}` autenticado como contratante dono valida RBAC; aceita os 6 campos materiais + `observacoes` (já é material) + descreve diff no response.
- [ ] **CA-2:** Detecção de edição material: compara cada campo material entre estado atual e payload. Se algum diferiu → edição material. Senão → edição não material (livre, in-place).
- [ ] **CA-3:** Edição material com candidatos pendentes (`pendente` ou `pendente_revisao_apos_edicao`): em transação Postgres — INSERT `vaga_versoes` snapshot da versão atual (antes da edição) + UPDATE `vagas` com novos valores + UPDATE candidaturas `pendente → pendente_revisao_apos_edicao` (não toca as que já estão `pendente_revisao_apos_edicao` — já estão lá) + audit log `vaga.editada_materialmente` + dispara evento `VagaEditadaMaterialmente` com `vaga_id`, `diff: {campo: {antes, depois}}`, `candidatos_notificados_ids`.
- [ ] **CA-4:** Edição material **sem** candidatos pendentes: apenas snapshot + update (sem notificação porque não há quem notificar).
- [ ] **CA-5:** Edição **não** material: UPDATE direto, sem snapshot, sem evento, sem audit `editada_materialmente` (audit pode ter `vaga.editada_minor` se quiser — decisão do agente).
- [ ] **CA-6:** Snapshot em `vaga_versoes` é imutável (trigger Postgres da STORY-044 bloqueia UPDATE/DELETE).
- [ ] **CA-7:** `POST /api/candidaturas/{id}/confirmar-apos-edicao` autenticado como profissional dono: candidatura `pendente_revisao_apos_edicao → pendente`, audit log `candidatura.mantida_apos_edicao`.
- [ ] **CA-8:** `POST /api/candidaturas/{id}/retirar-apos-edicao`: candidatura `pendente_revisao_apos_edicao → retirada_por_edicao`, audit log `candidatura.retirada_por_edicao_voluntaria`.
- [ ] **CA-9:** Cron de auto-retirada: reusa STORY-034 (Cloud Run Job + Scheduler 1/min). Job `candidaturas:auto-retirar-apos-edicao` varre candidaturas `pendente_revisao_apos_edicao` com (`updated_at + 24h < now()`) OR (`vaga.data_inicio < now()`), move para `retirada_por_edicao`, registra audit `candidatura.retirada_por_edicao_auto`. Idempotente.
- [ ] **CA-10:** UI do contratante: tela de edição mostra os campos atuais; ao submit, preview "Você vai mudar X de Y para Z — N candidatos serão notificados" antes de confirmar. Cancelar volta sem efeito.
- [ ] **CA-11:** UI do profissional: card de vaga no feed (filtro "Candidatadas") + detalhe (STORY-049) com candidatura em `pendente_revisao_apos_edicao` mostra banner "Esta vaga foi editada — confirme em até 24h" com 2 botões "Manter candidatura" / "Retirar".
- [ ] **CA-12:** Cobertura: backend (controller + detector de material + transação + cron) ≥ 98% (núcleo de regras de negócio); UI ≥ 85%. Testes: edição não material; material sem candidatos; material com candidatos; transição inválida (vaga `fechada`); cron auto-retirada após 24h; cron auto-retirada porque vaga começou.
- [ ] **CA-13:** E2E em `integration_test`: contratante edita vaga (muda valor) com 2 candidatos pendentes → candidaturas viram `pendente_revisao_apos_edicao` → profissional 1 mantém, profissional 2 não age → cron roda no CI (forçar tempo via clock injetado) → profissional 2 sai como `retirada_por_edicao`.

## Fora de escopo

- Notificação real ao candidato (e-mail/in-app) → STORY-053 consome o evento `VagaEditadaMaterialmente`.
- Histórico visível ao usuário das versões da vaga (UI exibindo `vaga_versoes`) — útil mas fora do MVP.
- Edição de vaga `fechada` → bloqueado (retorna 409).
- "Bloquear edição material após X candidaturas" — sinal de revisão do PDR-009, não MVP.

## Padrões de qualidade

≥ 98% no núcleo (detector + transação + cron), ≥ 85% UI, E2E verde, transações testadas (rollback em falha).

## Dependências

- **Bloqueada por:** STORY-044 (modelo `vaga_versoes`), STORY-034 (Cloud Run Job — já done na W25), STORY-047 (entry point UI vem da lista de vagas).
- **Bloqueia:** STORY-053 (consome eventos), STORY-054 (validação).
- **Pré-req:** vaga seed com 2 candidaturas seedadas; cron operante.

## Decisões já tomadas

- PDR-009 (campos materiais + 24h ou início).
- STORY-044 (snapshot append-only, estado `pendente_revisao_apos_edicao`).
- ADR-008 (log estruturado para audit).

## Liberdade técnica

Decide: estratégia de comparação (diff field-by-field vs. hash); estrutura do payload do evento; placement do cron (em `app/Console/Commands/` ou módulo separado). NÃO decide: campos materiais (PDR-009), prazo de 24h (PDR-009), transação atômica (regra invariante).

## DoD

- [ ] CAs checados.
- [ ] Cobertura ≥ 98% núcleo.
- [ ] E2E + cron testado.
- [ ] Deploy de homolog: ciclo de edição material reproduzido.
- [ ] `index.json` atualizado.
- [ ] "Notas do agente" preenchida.

## Notas do agente

### Decisões / Descobertas / Bloqueios / IDRs
- 
### Cobertura final
- Unitários: 
- E2E: 
### Links
- PR / Pipeline / Deploy
