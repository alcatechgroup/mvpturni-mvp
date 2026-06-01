---
story_id: STORY-050
slug: candidatura-um-toque-com-gates
title: Candidatura em 1 toque + gates (PDR-005, conflito de horário, habitualidade PDR-002)
epic_id: EPIC-002
sprint_id: SPRINT-2026-W27
type: implementation
target_role: programador
requires_design: true
design_screen_id: SCREEN-STORY-050-candidatura  # cobre modal de confirmação + estados de bloqueio
status: ready
owner_agent: null
created_at: 2026-06-01
updated_at: 2026-06-01
estimated_session_size: M
produces_idr: null
---

# STORY-050 — Candidatura em 1 toque com gates

> **Para o agente:** o "1 toque" é o coração da experiência do profissional. Tem que ser rápido e os bloqueios têm que ser claros — sem texto técnico, sem código de erro vazando para o usuário. Os 3 gates (PDR-005 avaliação, conflito de horário, habitualidade PDR-002) são checados server-side com mensagem por gate; client mostra a mensagem.

## Contexto

Depois de ver o feed (STORY-048) e abrir o detalhe (STORY-049), o profissional toca em "Candidatar-se". É o ato que abre a possibilidade de aceite (EPIC-003). Sem essa ação implementada com os 3 gates corretos, ou o profissional candidata em vaga que vai ser rejeitada na hora do aceite (frustração), ou o sistema permite habitualidade indevida (risco compliance PDR-002).

- Épico: `epics/EPIC-002-vaga-feed-e-candidatura/epic.md`
- Documentos: `domain/candidatura.md` (Pré-condições + Fluxo padrão + Retirada voluntária + Conflito de horário), PDR-005, PDR-002, `business-rules.md` (Habitualidade), STORY-044 (modelo `candidaturas`).

## O quê

Endpoint `POST /api/vagas/{id}/candidaturas` que aplica os 3 gates server-side e, se ok, cria candidatura em `pendente`, registra audit log, dispara eventos `match.candidatura_enviada` e abre o caminho para a notificação ao contratante (consumida pela STORY-053). E endpoint `DELETE /api/candidaturas/{id}` para retirada voluntária (estado `retirada`). Persiste `score_no_momento` na linha de candidatura (snapshot do score no momento do envio).

## Por quê

Sem candidatura, não há aceite. Sem gates, vaga vira lixo (candidatos inelegíveis bagunçam o painel do contratante). Sem snapshot de score, perdemos a métrica de qualidade do match no momento certo.

## Critérios de aceite

- [ ] **CA-1:** `POST /api/vagas/{id}/candidaturas` autenticado como profissional cria candidatura em `pendente`, retorna 201 com `{ id, estado: 'pendente', score_no_momento, candidatou_em }`. Falha com 422 + JSON `{ erro: 'gate_avaliacao'|'conflito_horario'|'habitualidade_bloqueio'|'vaga_fechada'|'ja_candidatou', mensagem: 'texto para usuário', detalhe?: {...} }`.
- [ ] **CA-2:** Gate 1 — PDR-005 avaliação: se profissional tem turno finalizado pendente de avaliação, retorna `gate_avaliacao` com `detalhe.turno_id` para o client guiar para a tela de avaliação.
- [ ] **CA-3:** Gate 2 — conflito de horário (`candidatura.md`): se profissional já tem candidatura `pendente`/`pendente_revisao_apos_edicao` ou turno `confirmado` com sobreposição em `data_inicio/data_fim`, retorna `conflito_horario` com `detalhe.conflito_com: { tipo: 'candidatura'|'turno', id, vaga_id, data_inicio, data_fim }`.
- [ ] **CA-4:** Gate 3 — habitualidade (PDR-002 + `business-rules.md`): conta alocações da semana corrida (seg→dom) no mesmo `estabelecimento_id`. Para PF: na 3ª alocação na semana, bloqueia (`habitualidade_bloqueio`). Para MEI/PJ: alerta + override do contratante (no MVP, ainda é só alerta server-side via `detalhe.alerta = true` sem bloqueio — fluxo "override do contratante" entra no EPIC-003 quando o contratante aprovar). Não bloqueia MEI/PJ na candidatura — apenas marca no payload da candidatura criada para o contratante ver no painel (STORY-051).
- [ ] **CA-5:** Validação de pré-condições básicas: vaga existe + `aberta` + `data_inicio > now()`; profissional `ativo`. Se falhar, retorna `vaga_fechada` ou similar.
- [ ] **CA-6:** Idempotência: tentar candidatar 2× na mesma vaga retorna 409 + `ja_candidatou` com a candidatura existente. Cobertura por constraint do banco (CA-5 da STORY-044 — `unique(profissional_id, vaga_id)`).
- [ ] **CA-7:** Sucesso registra: audit log `candidatura.criada`, evento `match.candidatura_enviada` (helper de STORY-045), e dispara evento de domínio `CandidaturaEnviada` (consumido por STORY-053 para notificar contratante).
- [ ] **CA-8:** `DELETE /api/candidaturas/{id}` autenticado como o profissional dono retorna 200 + `{ estado: 'retirada' }` se candidatura está `pendente`. Em outros estados retorna 409 com mensagem.
- [ ] **CA-9:** WebApp: clique em "Candidatar-se" na STORY-049 → chama o endpoint → se 201, badge muda para "Você já se candidatou"; se 422, mostra modal com a mensagem do gate (não JSON cru). Modal de conflito de horário lista vaga conflitante com link clicável.
- [ ] **CA-10:** Cobertura: controller + gates ≥ 98% (núcleo de regras — `quality-standards.md`). Cada gate tem teste cobrindo: dispara / não dispara, e mensagem retornada.
- [ ] **CA-11:** E2E em `integration_test`: profissional sem pendências candidata-se com sucesso; profissional com turno por avaliar tenta candidatar e vê modal "Avalie seu último turno"; profissional candidata em 2 vagas com mesmo horário e o segundo é bloqueado. 0 flake em 3 runs.

## Fora de escopo

- Override do contratante para MEI/PJ na 3ª alocação → EPIC-003 (no momento do aceite).
- Notificação ao contratante quando recebe candidatura → STORY-053.
- Listagem das próprias candidaturas (separado do feed filtro "Candidatadas") — fica como filtro no feed mesmo.
- Recusa explícita pelo contratante (`estado: recusada`) — `candidatura.md` marca como Lacuna do MVP.

## Padrões de qualidade

- Cobertura ≥ 98% no controller/gates (núcleo).
- E2E verde com pelo menos 3 cenários (sucesso + 2 gates).
- Logs estruturados para cada gate disparado (analytics futura).

## Dependências

- **Bloqueada por:** STORY-044 (modelo), STORY-045 (helper de eventos), STORY-049 (UI de origem do clique).
- **Bloqueia:** STORY-051 (painel do contratante precisa de candidaturas para ranquear), STORY-053 (consome evento de domínio), STORY-054 (validação).
- **Pré-req:** profissional seed `ativo`, vaga seed `aberta`.

## Decisões já tomadas

- ADR-013, ADR-014.
- PDR-005, PDR-002.
- `domain/candidatura.md` Pré-condições.

## Liberdade técnica

Decide: ordem de avaliação dos gates (sugestão: barato→caro — pré-condições básicas → conflito → habitualidade → avaliação que requer query agregada); estrutura de classes `GateAvaliacao`, `GateConflito`, `GateHabitualidade`. NÃO decide: lista de gates (fixada pelos PDRs), mensagens de erro técnicas vazando.

## DoD

- [ ] CAs checados.
- [ ] Cobertura ≥ 98% no núcleo.
- [ ] E2E verde.
- [ ] Deploy de homolog: 3 cenários reproduzidos.
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
