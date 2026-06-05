---
story_id: STORY-059
slug: listas-meus-turnos-vagas-confirmadas
title: Lista "Meus turnos" (profissional) + "Vagas confirmadas" (contratante) no WebApp
epic_id: EPIC-003
sprint_id: SPRINT-2026-W28
type: implementation
target_role: programador
requires_design: true
design_screen_id: SCREEN-STORY-059-listas-turnos
status: done
owner_agent: claude-opus-4-8
created_at: 2026-06-03
updated_at: 2026-06-05
estimated_session_size: S
produces_idr: null
---

# STORY-059 — Listas "Meus turnos" e "Vagas confirmadas"

## Contexto

A partir de STORY-058, existem Turnos `confirmado` em homolog. Profissional e contratante precisam de **uma porta de entrada** para ver os turnos deles agrupados por estado — caso contrário, só dá pra acessar via URL direta.

- Épico: `epics/EPIC-003-aceite-pin-e-pix/epic.md`
- Documentos: `docs/especificacao/domain/turno.md` (estados), STORY-047 (padrão de lista "Minhas vagas" — reuso).

## O quê

Duas telas espelhadas no WebApp: `/profissional/turnos` (lista do profissional) e `/contratante/turnos` (lista do contratante), ambas agrupadas pelos estados de `domain/turno.md`. Reuso direto dos componentes da STORY-047 (card + agrupamento + filtros).

## Por quê

Sem essa porta de entrada, o resto da sprint vira invisível para o usuário. É a UI mais barata possível (S) que destrava todas as estórias seguintes.

## Critérios de aceite

- [x] **CA-1:** `GET /api/profissional/turnos` lista turnos do profissional autenticado agrupados por estado (`confirmado`, `aguardando_checkin`, `ativo`, `aguardando_checkout`, `finalizado`, terminais — e `em_disputa` como seção própria, decisão PO 2026-06-05). Ordem dentro do grupo: por `data_inicio` ascendente (futuros primeiro) ou `data_fim` descendente (passados primeiro), conforme o grupo.
- [x] **CA-2:** `GET /api/contratante/turnos` espelha — turnos das vagas do contratante autenticado, mesmos grupos.
- [x] **CA-3:** Tela `/profissional/turnos` renderiza cards de turno (função + data + valor + estado + estabelecimento) agrupados por estado.
- [x] **CA-4:** Tela `/contratante/turnos` espelha, com tema visual do contratante (DDR-001). Título "Turnos" (decisão PO 2026-06-05).
- [x] **CA-5:** RBAC: profissional vê só os próprios turnos; contratante vê só os turnos das próprias vagas; cruzados retornam 403 fail-secure.
- [x] **CA-6:** Vazio: estado vazio amigável (microcopy revisado pelo PO em chat) — "Ainda não há turnos — quando o contratante aceitar sua candidatura, ele aparece aqui" / espelho contratante.
- [x] **CA-7:** Cobertura ≥ 80% no código novo (API 100%; webapp 98%); E2E `integration_test` (Chrome headless) cobre os 2 caminhos.

## Fora de escopo

- Detalhe do turno (STORY-060).
- Qualquer ação sobre o turno (estórias seguintes).
- Filtros avançados — só agrupamento por estado.

## Padrões de qualidade

≥ 80%. E2E em `integration_test` (IDR-010/011). Locale pt-BR + 24h (DDR-002 + IDR-026).

## Dependências

- **Bloqueada por:** STORY-058 (precisa de turnos em `confirmado` para listar).
- **Bloqueia:** nenhuma (paralela a STORY-060).
- **Pré-requisitos:** SCREEN-STORY-059 entregue pelo Designer antes da implementação.

## Decisões já tomadas

- ADR-013 (modelo herdado), ADR-015 (modelo Turno), **ADR-018 (UUIDv7 em PKs — DTOs Flutter tipam `id` como `String`; URLs `/turnos/{uuid}` aceitam string)**, DDR-001/002, IDR-010/011/026.

## Liberdade técnica

Decide: reuso de componentes da STORY-047, estrutura interna da query.

NÃO decide: estados que aparecem (fixados em `domain/turno.md`).

## Definição de Pronto

- [x] CAs marcados; deploy em homolog (rc.71) verificado e **aprovado por Alexandro em chat (2026-06-05)**.
- [x] SCREEN-STORY-059 marcado `shipped`.
- [x] `index.json` atualizado.
- [x] "Notas do agente" preenchida.

## Protocolo

`docs/skills/po/references/agent-task-format.md`.

## Notas do agente

### Decisões tomadas
- **Fluxo Designer → validação humana → Programador** na mesma sessão (2026-06-05).
  SCREEN-STORY-059 (spec + protótipo HTML) aprovada por Alexandro antes do código.
- **`em_disputa` é seção própria** (decisão PO em chat, 2026-06-05): o CA-1 enumerava 6 grupos
  sem citar `em_disputa`, mas o estado existe em `domain/turno.md` e um turno em disputa não
  pode ficar invisível para as partes. Posição 5, entre check-out e finalizados.
- **Título do contratante: "Turnos"** (decisão PO em chat, 2026-06-05) — a estória nomeava
  "Vagas confirmadas", mas a tela lista turnos em todos os estados; "Turnos" é o termo do
  glossário. Rota continua `/contratante/turnos` como especificado.
- **Contrato da API agrupado no servidor**: `{ grupos: [{ grupo, turnos[] }] }` — array (não
  objeto) para a ordem das seções sobreviver ao JSON; grupo vazio omitido; ordenação interna
  no servidor (CA-1) e o front não reordena. Visibilidade financeira por papel (PDR-004):
  profissional vê `valor`; contratante vê `total_contratante` (+ sufixo "· total" na UI).
- **Card sem ação** (sem falsa affordance) até a STORY-060; anatomia já preparada para virar
  alvo de toque. Linha "quem" espelhada: estabelecimento (prof.) / nome do profissional
  (contr., reusa a regra apelido ?: nome da STORY-049).
- **Porta de entrada**: ícone `event_note` na AppBar do feed (`feed-meus-turnos-btn`) e de
  Minhas vagas (`minhas-vagas-turnos-btn`) — sem introduzir NavigationBar (seria DDR).
- **Fail-soft no front**: grupo/estado desconhecido vindo do back cai em "Encerrados" com selo
  neutro — visível, nunca quebra (SCREEN-059 §4.6).
- **E2E com usuários exclusivos do TurnosSeeder** (`*.turnos.seed@turni.local`, 11 estados):
  determinístico e sem disputa de estado com as suítes existentes.

### Descobertas
- O `TurnoAtivoController` (STORY-057) se declarava "semente de Meus turnos" — mantido como
  atalho do cronômetro; a lista nova não o substitui.
- `pint --test` falhava em `AprovacaoCandidaturaSeeder.php` (estilo pré-existente na main,
  `fully_qualified_strict_types`); corrigido mecanicamente com pint nesta entrega.
- `badge.status` nunca tinha sido registrado no `components.md` (ficou como exceção desde a
  047); registrado agora junto com `section.group-header` (§8 do spec).
- O E2E pegou (1ª rodada do gate): contratante sem `ContratanteProfile` (caso dos usuários do
  TurnosSeeder) deixava `estabelecimento.nome` nulo e o card sem "onde". Fix no controller:
  fallback `apelido ?: nome_estabelecimento ?: contratante.name` (estabelecimento = contratante,
  convenção MVP) + teste Pest do fallback.

### Bloqueios encontrados
- Nenhum.

### IDRs criados
- Nenhum (sem decisão de implementação durável nova — padrões reusados de 047/IDR-021).

### Cobertura final
- Unitários: API `TurnosController` 100% (13 testes Pest, 36 asserts); WebApp
  `turnos_service.dart` 98,3% e `turnos_lista_screen.dart` 98,1% (16 testes).
- E2E: `integration_test/turnos/listas_turnos_test.dart` — 2 cenários (profissional e
  contratante) em Chrome headless same-origin (IDR-021), backend real + TurnosSeeder.

### Links de evidência
- PR: n/a (commit direto na main — fluxo combinado).
- Pipeline: Release run 27017134814 (verde de primeira, sem rerun de Cloud SQL).
- Deploy de homologação: **v0.1.0-rc.71** no ar (2026-06-05; `version.json` confere;
  API respondendo). **Verificado e aprovado por Alexandro em chat (2026-06-05)** — roteiro
  de 5 cenários (listas dos 2 papéis, dados reais da 058, vazio, RBAC cruzado).
