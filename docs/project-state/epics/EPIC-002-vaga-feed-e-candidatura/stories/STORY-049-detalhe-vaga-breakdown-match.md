---
story_id: STORY-049
slug: detalhe-vaga-breakdown-match
title: Detalhe da vaga no WebApp + breakdown explicável do match
epic_id: EPIC-002
sprint_id: SPRINT-2026-W27
type: implementation
target_role: programador
requires_design: true
design_screen_id: SCREEN-STORY-049-detalhe-vaga
status: done
owner_agent: claude-opus-4-8-2026-06-02
created_at: 2026-06-01
updated_at: 2026-06-02
estimated_session_size: M
produces_idr: null
---

# STORY-049 — Detalhe da vaga + breakdown do match

> **Para o agente:** materializa o princípio "cálculo do match é aberto" — o profissional sabe exatamente por que está em 97/100 ou em 45/100. Sem esta tela, o feed da STORY-048 é uma caixa preta. Designer entrega o layout do breakdown (4 linhas, ícone, barra, descrição em prosa).

## Contexto

O feed (STORY-048) mostra score numérico em cada card. Quando o profissional toca, abre o detalhe — tudo da vaga + breakdown item a item. É a peça que torna o Match defensável: "Sua função primária bate · Garçom", "Estabelecimento em São Paulo · dentro do raio de 8km", "Sua média 4.9★ em 127 turnos", "Elite · topo da trilha".

- Épico: `epics/EPIC-002-vaga-feed-e-candidatura/epic.md`
- Documentos: `domain/match.md` (seções Breakdown explicável + Visibilidade), `domain/vaga.md` (Atributos), STORY-045 (shape do payload `MatchBreakdown`), SCREEN-STORY-049.

## O quê

Tela `/feed/vaga/{id}` no WebApp Flutter exibindo: cabeçalho da vaga (função, estabelecimento, data/hora, valor, distância), bloco "Por que estou vendo esta vaga" com os 4 componentes do match (ícone, barra, descrição), CTA "Candidatar-se" (chama STORY-050) ou "Você já se candidatou" (estado).

## Por quê

Transparência do algoritmo (princípio central de `domain/match.md`). Sem o breakdown, o profissional não confia no ranqueamento e tampouco aprende como subir de posição.

## Critérios de aceite

- [ ] **CA-1:** `GET /api/vagas/{id}/detalhe` autenticado retorna shape unificado: dados da vaga + `score_breakdown` no formato de STORY-045 (`{ total, componentes, breakdown: { funcao: {pontos, pontos_max, estado, descricao}, ... } }`) + `pode_candidatar: bool` + `ja_candidatou: bool` + `motivo_bloqueio: string|null`.
- [ ] **CA-2:** Tela renderiza cabeçalho com 5 campos (função, estabelecimento curto, data/hora formatada PT-BR, valor R$, distância km) e o bloco "Por que estou vendo esta vaga" com 4 linhas de breakdown (uma por componente). Cada linha: ícone (`ok` ✓ / `partial` ◐ / `miss` ✕), barra preenchida proporcional, label, valor `X/Y`, descrição em prosa curta.
- [ ] **CA-3:** Estado da linha de breakdown: `ok` quando `pontos == pontos_max`; `partial` quando `0 < pontos < pontos_max`; `miss` quando `pontos == 0`. Cores conforme DDR-001.
- [ ] **CA-4:** Total geral `XX/100` exibido em destaque com a barra agregada.
- [ ] **CA-5:** CTA "Candidatar-se": habilitado quando `pode_candidatar == true` e `ja_candidatou == false`; texto + estado seguem `motivo_bloqueio` se aplicável ("Avalie seu último turno", "Você já tem turno neste horário", "Habitualidade — 2 alocações desta semana neste local"). Clique chama o endpoint da STORY-050 (até STORY-050 estar done, o botão pode ser placeholder log + toast "em construção").
- [ ] **CA-6:** Quando `ja_candidatou == true`, CTA vira badge "Você já se candidatou" com data/hora; opção "Retirar candidatura" se candidatura `pendente` (chama endpoint STORY-050).
- [ ] **CA-7:** RBAC: contratante na rota recebe 403; profissional não-`ativo` recebe 403 ou redireciona para tela de completar cadastro.
- [ ] **CA-8:** Acessibilidade: barras de progresso têm `Semantics` de leitor de tela ("Função: 40 de 40 pontos · Sua função primária bate"); ícones têm `label` semântico.
- [ ] **CA-9:** Cobertura backend (controller + serializer) ≥ 95%; widget Flutter do breakdown ≥ 90%. Testes cobrem: vaga existente / inexistente / RBAC errado / cada estado de breakdown (ok/partial/miss em cada componente).
- [ ] **CA-10:** E2E em `integration_test`: profissional seed loga → abre feed → toca em uma vaga → vê breakdown completo com os 4 componentes corretos. 0 flake em 3 runs.

## Fora de escopo

- Implementação da candidatura → STORY-050.
- Histórico de score por candidatura → vive em STORY-050 (registra `score_no_momento`).
- Compartilhar vaga / favoritar / abrir em mapa.

## Padrões de qualidade

≥ 95% backend, ≥ 90% widget, E2E verde, acessibilidade testada.

## Dependências

- **Bloqueada por:** STORY-044, STORY-045, STORY-048 (rota chega daqui).
- **Bloqueia:** STORY-050 (botão "Candidatar-se" mora aqui), STORY-051 (mesmo padrão de breakdown reusado no lado do contratante).
- **Pré-req:** mesmo seed do feed.

## Decisões já tomadas

- ADR-014: shape do `MatchBreakdown`.
- DDR-001: tokens visuais.
- `domain/match.md`: princípio "cálculo é aberto" + estados ok/partial/miss.

## Liberdade técnica

Decide: widget reutilizável (`BreakdownRow`) que serve aqui e em STORY-051; animação da barra. NÃO decide: ordem dos componentes (segue a tabela de `domain/match.md`), estados de cor (DDR-001).

## DoD

- [x] CAs checados (mapa CA→teste abaixo).
- [x] Cobertura + E2E verdes (api suíte 423 ✓; webapp 250 widget ✓; E2E 3/3 sem flake).
- [ ] Deploy de homolog renderiza para profissional seed. *(pendente push/deploy — push é manual.)*
- [x] `index.json` atualizado (screen 049 `ready`; story `in_review`).
- [x] "Notas do agente" preenchida.

## Notas do agente

### Plano (registrado antes de codar — 2026-06-02)

Dois atos na mesma sessão (papel declarado em cada): **Designer** entrega SCREEN-049 + protótipo HTML;
**Programador** implementa backend (endpoint + match reusado) e frontend (tela + `BreakdownRow`), em TDD,
com E2E same-origin. Documentos lidos: STORY-049 (inteira), `domain/match.md` (breakdown + visibilidade),
ADR-014/STORY-045 (shape `MatchScore::toArray`), SCREEN-048 (tela mãe + padrão), DDR-001 (tokens/estados),
DDR-002 (pt-BR/24h), skills designer/programador. Código reusado: `MatchScoring`/`MatchScore` (núcleo do
match), `FeedQuery` (visibilidade/distância), `AvaliacoesPendentesProfissional` (gate PDR-005).

### Decisões / Descobertas / Bloqueios / IDRs

**Como Designer (SCREEN-049, `ready`):**
- **`miss` = cinza-mudo, não vermelho** (decisão local registrada no §Tema do spec): DDR-001 reserva vermelho
  para erro/destrutivo; um componente que zerou não é erro. Diferenciação por ícone (✕) + `0/Y` + prosa, não
  só cor — sustenta WCAG AA sem alarmar.
- **`match.breakdownrow` + `match.scoretotal`** entram como exceções aditivas ao DS (§8), candidatas a DDR
  quando STORY-051 reusar (3º uso da barra de score). `match.scorechip`/`gate.banner`/`badge.status` já têm
  2º/3º uso → promover ao DS.
- Protótipo HTML fiel com 8 estados navegáveis. **Validação humana do protótipo ainda pendente** (apresentar
  a Alexandro junto do app real, como em 048).

**Como Programador:**
- **Endpoint `GET /api/vagas/{vaga}/detalhe`** (não `/detalhe` em FeedController) — controller próprio
  `Feed\VagaDetalheController` + `Domain\Vaga\VagaDetalheQuery` (espelha o par FeedController/FeedQuery).
- **Detalhe NÃO filtra por função nem raio** (≠ feed): o breakdown existe para explicar um match baixo, então
  uma vaga acessada por deep-link renderiza breakdown honesto (função/distância `miss`). O 404 cobre só
  inexistente / não-`aberta` / no passado (SCREEN-049 §4.7). Registrado no docblock do `VagaDetalheQuery`.
- **Haversine extraído** de `FeedQuery` para `App\Support\Geo\Haversine` (reuso feed↔detalhe; mesma distância
  que pontuou o match). FeedQuery refatorado para usá-lo — suíte do feed segue verde.
- **`motivo_bloqueio`** só preenchido quando `pode_candidatar == false`; no MVP só o gate PDR-005 dispara
  ("Avalie seu último turno…"). Conflito de horário e habitualidade são **slots** do contrato com lógica em
  STORY-050.
- **`ja_candidatou`** considera candidatura em `pendente`/`pendente_revisao_apos_edicao`/`aprovada`; retiradas
  não contam. "Retirar candidatura" só quando `pendente` (CA-6).
- **`BreakdownRow`** é widget público reutilizável (STORY-051 reusa). Barra na cor do estado;
  `Semantics(label:)` por linha anuncia "Label: atende · X de Y pontos · descrição" (CA-8).
- **CTA "Candidatar-se" / "Retirar"** são placeholders (toast) até STORY-050 — mesma estratégia de 047/048.
- **Descoberta:** `ContratanteProfile` não tem factory; testes usam `::create([...])` com `cnpj_hash` único.
  No teste de service Flutter, o `★` da descrição exige `content-type: charset=utf-8` no mock (o `http.Response`
  default usa latin1 e quebraria) — reflete a resposta real da API.
- **IDRs criados:** nenhum (decisões locais cobertas pela ADR-014 + registradas aqui e nos docblocks).

### Cobertura final
- **api (suíte completa):** 423 passed (1338 asserções), gate `--min=80` ✓. Novos arquivos a **100%**:
  `VagaDetalheController`, `VagaDetalheQuery`, `VagaDetalhe`, `Support\Geo\Haversine`.
- **webapp:** 250 widget tests ✓. `vaga_detalhe_service.dart` **100%**; `vaga_detalhe_screen.dart` **97,9%**
  (330/337 ≥ 90% exigido).
- **E2E (`make e2e-webapp-integration`, same-origin IDR-021):** 3/3 runs **All tests passed** (0 flake —
  login profissional.teste → feed → toca vaga → breakdown 4 componentes + total).

### Mapeamento CA → teste (todos verdes)
- **CA-1** (shape unificado + score_breakdown): `VagaDetalheTest` ("contrato unificado", estrutura completa) +
  `vaga_detalhe_service_test` (parse).
- **CA-2** (cabeçalho 5 campos + 4 linhas): `vaga_detalhe_screen_test` ("cabeçalho", "4 linhas ordem canônica").
- **CA-3** (estados ok/partial/miss): `VagaDetalheTest` (primária/secundária/nenhuma; distância sem geo;
  histórico parcial; iniciante miss) + `vaga_detalhe_screen_test` ("ícones distintos").
- **CA-4** (total XX/100): `vaga_detalhe_screen_test` ("total agregado").
- **CA-5** (CTA + gate + motivo): `VagaDetalheTest` ("gate ativo") + `vaga_detalhe_screen_test`
  ("CTA habilitado", "gate banner + desabilitado").
- **CA-6** (já candidatou + retirar): `VagaDetalheTest` (pendente/retirada) + `vaga_detalhe_screen_test`
  (pendente→retirar; aprovada→sem retirar).
- **CA-7** (RBAC): `VagaDetalheTest` (403 contratante / 401) + `vaga_detalhe_screen_test` ("sem permissão").
- **CA-8** (acessibilidade): `Semantics` por linha + barra `ExcludeSemantics` (revisar no app).
- **CA-9** (cobertura): ver acima (100% back / 97,9% widget).
- **CA-10** (E2E): `feed/feed_test.dart` 2º teste — 3/3 sem flake.

### Links
- Commits: `feat(STORY-049)` na main (push manual). Arquivos: `Support/Geo/Haversine`,
  `Domain/Vaga/{VagaDetalhe,VagaDetalheQuery}`, `Http/Controllers/Feed/VagaDetalheController`, rota
  `/api/vagas/{vaga}/detalhe`; `features/vagas/{vaga_detalhe_service,vaga_detalhe_screen}.dart`, rota `/vaga/:id`.
- Pipeline/Deploy de homolog: pendente (push manual).

### Aprovação
- **Validado no app real e aprovado por Alexandro em chat (2026-06-02).** O `done` inicial foi prematuro
  (aprovação por engano antes do teste) e a tela ainda servia o placeholder antigo; após `flutter build web`
  o WebApp renderizou o detalhe + breakdown corretos. Story `done`, protótipo SCREEN-049 `shipped`. Deploy de
  homolog acompanha o push.
