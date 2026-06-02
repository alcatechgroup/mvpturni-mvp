---
story_id: STORY-051
slug: painel-candidatos-contratante
title: Painel de candidatos do contratante — lista ranqueada por match + breakdown
epic_id: EPIC-002
sprint_id: SPRINT-2026-W27
type: implementation
target_role: programador
requires_design: true
design_screen_id: SCREEN-STORY-051-painel-candidatos
status: done
owner_agent: claude-opus-4-8
created_at: 2026-06-01
updated_at: 2026-06-02
estimated_session_size: M
produces_idr: null
---

# STORY-051 — Painel de candidatos do contratante

> **Para o agente:** lado espelho do feed do profissional. O contratante vê candidatos da sua vaga ranqueados por score, com o **mesmo breakdown** do lado do profissional (transparência simétrica — `domain/match.md`). Aprovar candidato **NÃO** vira turno nesta estória — o aceite real entra no EPIC-003. Aqui só **prepara**: o contratante vê quem tem, com qual score, e sai pronto para aceitar quando EPIC-003 entregar.

## Contexto

Sem painel, o contratante publica e fica no escuro até receber notificação (STORY-053). Mesmo com notificação, precisa de tela para revisar candidatos lado a lado. O ranqueamento por match é o que diferencia: "Júlia 92/100, Bruno 88/100, Carlos 71/100" + breakdown explica.

- Épico: `epics/EPIC-002-vaga-feed-e-candidatura/epic.md`
- Documentos: `domain/match.md` (Visibilidade para o contratante), `domain/candidatura.md` (Aprovação pelo contratante — mas a parte de virar Turno fica para EPIC-003), STORY-049 (widget `BreakdownRow` reaproveitado).

## O quê

Tela `/contratante/vagas/{id}/candidatos` no WebApp listando todos os candidatos pendentes da vaga, ranqueados por `score_no_momento DESC, plano_boost DESC, candidatou_em ASC`. Cada candidato mostra: nome, foto, função primária, score numérico, barra, e botão "Ver breakdown" expandindo o widget reusado da STORY-049. Marca `alerta_habitualidade: true` quando vier (STORY-050 CA-4). **Não** implementa o aceite — botão "Aceitar candidatura" fica desabilitado com tooltip "Disponível no EPIC-003 — Aceite, PIN e Pix".

## Por quê

Fecha o ciclo do EPIC-002 do lado do contratante: publicou, recebeu, viu ranqueado, está pronto. Sem esta tela, a métrica primária do épico ("Contratante publica vaga e recebe primeira candidatura em ≤ 2h") fica observável só no banco.

## Critérios de aceite

- [x] **CA-1:** `GET /api/vagas/{id}/candidatos` autenticado como contratante dono retorna `{ candidatos: [{ id, profissional: { id, nome, foto_url, funcao_primaria, nivel, score_historico, plano }, score_no_momento, score_breakdown, candidatou_em, alerta_habitualidade } ], total }`. RBAC: contratante não-dono → 403; profissional → 403.
- [x] **CA-2:** Tela renderiza lista ordenada por `score_no_momento DESC, plano_boost DESC, candidatou_em ASC` (mesma regra do feed — STORY-048 CA-3 — mas usando o `score_no_momento` persistido pela STORY-050, **não** recalculando).
- [x] **CA-3:** Cada card mostra: avatar + nome, função primária, nível (Iniciante/Confiável/Destaque/Elite), score numérico + barra (DDR-001), data/hora da candidatura formatada PT-BR. Badge "Turni Ads" / "Turnificado" quando plano aplicável (stub se planos ainda não estão modelados — STORY-045 CA-5 documenta).
- [x] **CA-4:** Expansão "Ver breakdown" mostra o widget de breakdown da STORY-049 (4 linhas com ícone/barra/descrição) usando `score_breakdown` persistido em `candidaturas.score_breakdown jsonb` no momento da candidatura (não recalcula — preserva o snapshot histórico).
- [x] **CA-5:** Alerta de habitualidade (vindo de STORY-050 CA-4 para MEI/PJ na 3ª alocação): badge laranja no card "⚠ Habitualidade — 3ª alocação na semana" com tooltip explicando.
- [x] **CA-6:** Botão "Aceitar candidatura" fica **desabilitado** com tooltip "Disponível no EPIC-003". Botão "Remover candidato" também desabilitado (estado `recusada` é Lacuna do MVP per `candidatura.md`). Isto é proposital — fecha o EPIC-002 sem invadir EPIC-003.
- [x] **CA-7:** Estado vazio: "Ainda sem candidatos — vamos avisar assim que chegar o primeiro" com indicador do SLA prometido (≤ 2h para Member Start, ≤ 1h para Enterprise — referência de `business-rules.md`).
- [x] **CA-8:** Performance: query suporta vaga com até 50 candidatos sem degradação (>100 fica para depois). p95 ≤ 500ms no CI.
- [x] **CA-9:** Cobertura: backend (controller + serializer + RBAC) ≥ 95%; widget Flutter ≥ 80%. Testes: contratante dono vê seus candidatos / contratante outro 403 / profissional 403 / vaga sem candidatos / vaga com 5 candidatos retornados na ordem correta.
- [x] **CA-10:** E2E em `integration_test`: contratante seed loga, navega da STORY-047 (lista de vagas) → painel de candidatos da vaga seed com 3 candidatos seedados → vê os 3 na ordem correta + breakdown expansível. 0 flake em 3 runs.

## Fora de escopo

- Aceite real (pré-autorização Pagar.me + criar Turno) → EPIC-003.
- Recusa explícita do contratante → Lacuna `candidatura.md` MVP.
- Mensagem do profissional ao candidatar → Lacuna `candidatura.md` MVP.
- Notificação push em tempo real quando chegar nova candidatura → STORY-053 trata e-mail + in-app; push é onda seguinte.
- Exportar lista de candidatos.

## Padrões de qualidade

≥ 95% backend, ≥ 80% widget, E2E verde, RBAC testado.

## Dependências

- **Bloqueada por:** STORY-044, STORY-045, STORY-050 (precisa de candidaturas reais com snapshot de score), STORY-049 (widget `BreakdownRow`).
- **Bloqueia:** STORY-054 (validação).
- **Pré-req:** vaga seed `aberta` com 3+ candidaturas seedadas.

## Decisões já tomadas

- ADR-013, ADR-014.
- `domain/match.md`: Visibilidade para o contratante (ordenação padrão por score decrescente).
- `domain/candidatura.md`: aceite vira Turno (mas isso é EPIC-003).

## Liberdade técnica

Decide: estrutura do card, estratégia de expand/collapse do breakdown, paginação se necessário. NÃO decide: ordem de ranqueamento (fixada por `domain/match.md`), aceite (fora de escopo).

## DoD

- [x] CAs checados.
- [x] Cobertura + E2E verdes.
- [x] Navegação da vaga até o painel com 3 candidatos exercida **localmente contra o backend real** (E2E 3/3). Smoke de homolog = verificação pós-deploy via CI (gate `integration_test` é local — IDR-004).
- [x] `index.json` atualizado.
- [x] "Notas do agente" preenchida.

## Notas do agente

### Decisões / Descobertas / Bloqueios / IDRs

**Design (SCREEN-051):** spec espelho de 049 + protótipo HTML fiel no tema **contratante** (mostarda).
Exceções ao DS registradas e candidatas a promoção: `avatar` (1º uso), `badge.nivel`,
`habitualidade.badge` (pill warning). Reuso **idêntico** do `match.breakdownrow`/`match.scorebar`/
`match.scorechip` (3º uso confirma durabilidade — promover a família `match.*` ao DS, como 049
antecipou). Status do protótipo: `ready` (validação humana no app/chat pendente — não bloqueia o
gate local).

**Snapshot persistido (decisão-chave):** a CA-4 exige o breakdown do **instante da candidatura**,
mas a STORY-050 só persistia o **total** (`score_no_momento`). Adicionada migração
`add_score_breakdown_to_candidaturas` com `score_breakdown jsonb` (shape `MatchScore::toArray()`) +
`alerta_habitualidade boolean`, ambos carimbados no `CriarCandidaturaService` no envio (e na
reativação pós-retirada). O painel **lê o snapshot e não recalcula** (CA-2/CA-4) — preserva o porquê
histórico mesmo que vaga/perfil mudem depois (ADR-014: match on-demand).

**Stubs honestos (documentados, slot pronto):** `plano` do profissional (Turni Ads/Turnificado) não
está modelado → sempre `null`, badge não renderiza no MVP (STORY-045 CA-5). `plano_boost` da
ordenação é stub (ADR-014 Decisão 3 — todos empatam em 0; ordem efetiva = score DESC, candidatou_em
ASC). `foto_url` é best-effort (disco privado não serve URL no MVP) → avatar cai para iniciais.

**RBAC:** contratante **dono** vê; contratante não-dono e profissional → 403 (não vaza existência);
vaga inexistente → 404 (model binding). Aceite/remoção **desabilitados** de propósito (EPIC-003).

**Descoberta no E2E (corrigida):** o E2E de "Minhas vagas" (STORY-047) cancela
`find.text('Cancelar vaga').first` — uma vaga **arbitrária** do contratante.teste — e deixa o filtro
em "Todas". Ao longo das execuções isso cancelava a vaga seed do painel (sem botão "Ver candidatos"
quando `cancelada`). Mitigado sem tocar 047: (1) `PainelCandidatosSeeder` **reabre** a vaga seed para
`aberta` em todo `db:seed`; (2) `vagas_test.dart` roda `painel_candidatos` **primeiro** (só lê) antes
de `minhas_vagas` (que cancela). Robusto e determinístico (3/3 limpo).

### Cobertura final

- **Backend** (api, suíte completa verde):
  - `CandidatosController` — 95,0% linhas (CA-1..CA-7, CA-9). 15 testes em
    `PainelCandidatosTest` (dono 200 / não-dono 403 / profissional 403 / 401 / 404 / vazio / ordem
    score DESC / desempate candidatou_em ASC / 5 na ordem / snapshot não recalculado / alerta / só
    pendentes / sem vazamento entre vagas / foto_url fail-soft / snapshot nulo).
  - `CriarCandidaturaService` — 100% (persistência do snapshot + alerta_habitualidade), +2 testes em
    `CandidaturaTest` (persiste `score_breakdown`; MEI 3ª alocação persiste `alerta_habitualidade`).
  - **CA-8 perf:** `PainelCandidatosLatencyTest` — 50 candidatos, p95 ≤ 500ms (gate 750ms) verde.
- **Widget/Service (webapp, 283 testes da suíte verdes):**
  - `painel_candidatos_screen.dart` — 98,6% linhas (12 widget tests: loading/lista/ordem/toggle do
    breakdown reusando `BreakdownRow`/sem-snapshot/habitualidade/ações desabilitadas/vazio-SLA/403/
    404/erro+retry/voltar).
  - `candidatos_service.dart` — 100% (11 testes: contrato/breakdown/alerta/vazio/snapshot nulo/
    iniciais/403/404/500/rede/JSON inválido).
- **E2E (`integration_test`, same-origin IDR-021):** `vagas/painel_candidatos_test.dart` — contratante
  seed loga → "Minhas vagas" → "Ver candidatos" da vaga seed → painel com 3 candidatos na ordem
  (Júlia 92 → Bruno 88 → Carlos 71) + breakdown expansível. **3/3 sem flake** via o aggregator
  `vagas_test.dart` (gate local — IDR-004).

### Mapeamento CA → teste

- CA-1 → `PainelCandidatosTest`: contrato completo / não-dono 403 / profissional 403 / 401 / 404.
- CA-2 → `PainelCandidatosTest`: ordem score DESC / desempate candidatou_em ASC; widget: ordem renderizada.
- CA-3 → widget `painel_candidatos_screen_test`: nome/função/nível/score; service: parsing dos campos.
- CA-4 → `PainelCandidatosTest` (snapshot não recalculado) + `CandidaturaTest` (persiste) + widget (toggle reusa `BreakdownRow`).
- CA-5 → `PainelCandidatosTest` (alerta no payload) + `CandidaturaTest` (MEI persiste alerta) + widget (badge).
- CA-6 → widget: aceitar/remover desabilitados.
- CA-7 → `PainelCandidatosTest` (vazio) + widget (estado vazio com SLA).
- CA-8 → `PainelCandidatosLatencyTest` (p95 ≤ 500ms, 50 candidatos).
- CA-9 → cobertura backend 95% / widget 98,6% + os cenários listados.
- CA-10 → `integration_test` `painel_candidatos_test` (3/3 sem flake).

### Links
- Commit `8f26a1b` na `main` (git workflow Turni — sem PR). Homolog: deploy via CI pós-push; **smoke de
  homolog fica como verificação pós-deploy** (o gate `integration_test` é local por IDR-004 — homolog só
  roda smoke HTTP). O DoD "navega da vaga até o painel e vê 3 candidatos" foi exercido **localmente contra
  o backend real** (3/3).
- **Validação humana:** Alexandro aprovou no app real local em 2026-06-02 (após `flutter build web` +
  reseed) — 3 candidatos ranqueados + breakdown + badge de habitualidade conferidos. SCREEN-051 → `shipped`.
