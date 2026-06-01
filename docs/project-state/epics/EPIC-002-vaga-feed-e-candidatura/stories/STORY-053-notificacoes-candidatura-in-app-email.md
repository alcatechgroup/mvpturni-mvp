---
story_id: STORY-053
slug: notificacoes-candidatura-in-app-email
title: Notificações da candidatura — in-app + e-mail (recebida, edição material, retirada por edição, cancelamento)
epic_id: EPIC-002
sprint_id: SPRINT-2026-W27
type: implementation
target_role: programador
requires_design: true
design_screen_id: SCREEN-STORY-053-notificacoes  # caixa in-app + e-mails transacionais
status: ready
owner_agent: null
created_at: 2026-06-01
updated_at: 2026-06-01
estimated_session_size: M
produces_idr: null
---

# STORY-053 — Notificações da candidatura (in-app + e-mail)

> **Para o agente:** consome 3 eventos de domínio (`CandidaturaEnviada`, `VagaEditadaMaterialmente`, `VagaCancelada`) e emite 5 notificações: (1) contratante recebe e-mail + in-app quando profissional candidata; (2) profissional recebe e-mail + in-app quando vaga é editada materialmente; (3) profissional recebe e-mail quando vaga é cancelada (cancelamento já notifica no momento da ação UI, mas o e-mail garante para quem fechou o app). Reusa a infraestrutura de e-mail da STORY-021 (EPIC-001).

## Contexto

Sem notificação ao contratante, a métrica primária do épico ("contratante recebe primeira candidatura em ≤ 2h") fica invisível — contratante teria que abrir o app e ficar dando refresh no painel. Sem notificação ao profissional na edição, candidato confirma vaga que não viu mudar — quebra de PDR-009. Sem notificação no cancelamento, candidato chega no estabelecimento e a vaga não existe.

- Épico: `epics/EPIC-002-vaga-feed-e-candidatura/epic.md`
- Documentos: PDR-009 (diff antes/depois na notificação), `domain/candidatura.md`, STORY-021 (provedor de e-mail + templates SPF/DKIM/DMARC verdes), STORY-014 (Anti-Corruption Layer e-mail).

## O quê

Listener para os 3 eventos de domínio que (a) cria registros em uma tabela `notificacoes` (nova) com `tipo`, `destinatario_id`, `vaga_id`, `candidatura_id`, `payload jsonb`, `lida_em`, `criada_em`; (b) dispara worker (reusa Cloud Run Job da STORY-034) que processa fila e envia e-mail via provedor de STORY-014/021; (c) endpoint `GET /api/notificacoes` para o WebApp mostrar caixa in-app + `POST /api/notificacoes/{id}/marcar-lida`. 5 templates de e-mail novos no editor de templates (STORY-020) — texto-seed v1 do PO entra como TemplateVersao ativo.

## Por quê

Fecha a malha do EPIC-002: cada ação relevante chega a quem precisa saber, automaticamente. Sem isto, o sistema funciona mas a comunicação depende do usuário fazer poll manual.

## Critérios de aceite

- [ ] **CA-1:** Migração cria tabela `notificacoes` com colunas listadas acima; índice em `(destinatario_id, lida_em, criada_em DESC)`.
- [ ] **CA-2:** Listener `App\Listeners\HandleCandidaturaEnviada` consome `CandidaturaEnviada` → insere 1 linha em `notificacoes` para o contratante dono da vaga com `tipo='candidatura_recebida'`, payload = `{ profissional_nome, profissional_score, vaga_id }`. Audit log `notificacao.criada`.
- [ ] **CA-3:** Listener `HandleVagaEditadaMaterialmente` consome `VagaEditadaMaterialmente` → insere N linhas em `notificacoes` (1 por candidato pendente) com `tipo='vaga_editada_material'`, payload = `{ vaga_id, diff: { campo: { antes, depois } } }`.
- [ ] **CA-4:** Listener `HandleVagaCancelada` consome `VagaCancelada` → insere N linhas em `notificacoes` (1 por candidato pendente) com `tipo='vaga_cancelada'`, payload = `{ vaga_id, vaga_funcao, vaga_data_inicio }`.
- [ ] **CA-5:** Worker (Cloud Run Job + Scheduler 1/min, reusa STORY-034) pega `notificacoes` não enviadas por e-mail (marca via campo `enviada_email_em`), gera e-mail pelo template ativo correspondente (5 novos: `candidatura_recebida_contratante`, `vaga_editada_material_profissional`, `vaga_cancelada_profissional`, `vaga_editada_material_candidatura_mantida_contratante` — confirma envio, `vaga_editada_material_candidatura_retirada_contratante` — retirada por edição), envia via provedor de STORY-021. Falha de envio: retry com backoff (3 tentativas), depois marca como `falha_envio` e alerta no log.
- [ ] **CA-6:** 5 templates novos criados no editor (STORY-020), texto-seed v1 do PO (Alexandro) carregado como `TemplateVersao` ativa (mesmo padrão do EPIC-001 STORY-015). Variáveis disponíveis em cada template estão documentadas no editor.
- [ ] **CA-7:** Endpoint `GET /api/notificacoes?lidas=false` retorna últimas 50 notificações não lidas do usuário autenticado, ordem `criada_em DESC`. `POST /api/notificacoes/{id}/marcar-lida` marca; `POST /api/notificacoes/marcar-todas-lidas` atalho.
- [ ] **CA-8:** WebApp: badge no app shell mostra contagem de não-lidas; clique abre painel lateral com lista; clicar em notificação navega para a vaga relevante e marca como lida.
- [ ] **CA-9:** SLA: notificação criada → e-mail enviado em ≤ 60s p95 (worker rodando 1/min). Métrica observada em homolog via log-based metric.
- [ ] **CA-10:** Privacidade: e-mail de candidatura recebida ao contratante mostra nome + score (não CPF, não telefone — esses só aparecem após aceite no EPIC-003). Aliasing/PII conforme `business-rules.md` (não há nada novo para o EPIC-002).
- [ ] **CA-11:** Cobertura: listeners + worker + endpoints ≥ 95%; widget in-app ≥ 80%. Testes: cada listener com evento mock; worker com 5 notificações pendentes; retry após falha; endpoints com filtros.
- [ ] **CA-12:** E2E: profissional candidata → contratante recebe e-mail em inbox de teste (Mailpit em homolog) + notificação aparece no badge ao recarregar. Contratante edita vaga → 2 candidatos recebem e-mail + in-app. Contratante cancela → candidatos recebem e-mail. 0 flake em 3 runs.

## Fora de escopo

- Push notifications nativas (FCM/APNs/Web Push) — onda 2.
- Preferências do usuário (quero/não quero e-mail) — fica como wishlist; default é receber tudo do funil.
- Templates segmentados por persona (Member Start vs. Enterprise) — fora do MVP.
- Reset de senha / e-mails de identidade — já em STORY-021.

## Padrões de qualidade

≥ 95% listeners/worker/endpoints, ≥ 80% widget, E2E verde com 3 cenários, SLA ≤ 60s observado.

## Dependências

- **Bloqueada por:** STORY-021 (provedor de e-mail + SPF/DKIM/DMARC), STORY-020 (editor de templates), STORY-034 (Cloud Run Job worker), STORY-050 (`CandidaturaEnviada`), STORY-052 (`VagaEditadaMaterialmente`), STORY-047 (`VagaCancelada`).
- **Bloqueia:** STORY-054 (validação).
- **Pré-req:** Mailpit em homolog operante (já em pé pela STORY-021).

## Decisões já tomadas

- ADR-011: provedor de e-mail transacional + ACL.
- PDR-009: notificação obrigatória em edição material (com diff).
- STORY-014 (Anti-Corruption Layer) + STORY-021 (provedor implementado).

## Liberdade técnica

Decide: nome dos listeners, estrutura do worker, estratégia de fila (sugestão: usar `notificacoes.enviada_email_em IS NULL` como fila implícita; sem Redis/Beanstalkd no MVP); microcopy dos templates (PO revisa antes de aceitar). NÃO decide: lista de eventos consumidos (3 fixos), SLA de 60s, lista de templates (5 fixos).

## DoD

- [ ] CAs checados.
- [ ] Cobertura + E2E verdes, SLA observado.
- [ ] 5 templates ativos no editor (TemplateVersao ativa).
- [ ] Deploy de homolog: ciclo completo (candidata → e-mail no Mailpit do contratante).
- [ ] `index.json` atualizado.
- [ ] "Notas do agente" preenchida com link para os 5 templates carregados.

## Notas do agente

### Decisões / Descobertas / Bloqueios / IDRs
- 
### Cobertura final
- Unitários: 
- E2E: 
### Templates carregados
- 
### Links
- PR / Pipeline / Deploy
