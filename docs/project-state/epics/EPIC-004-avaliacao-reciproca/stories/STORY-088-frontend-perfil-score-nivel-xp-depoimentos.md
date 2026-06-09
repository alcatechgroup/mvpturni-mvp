---
story_id: STORY-088
slug: frontend-perfil-score-nivel-xp-depoimentos
title: "Frontend — perfil com score/nível/XP/depoimentos + UX do gate bloqueante"
epic_id: EPIC-004
sprint_id: SPRINT-2026-W30
type: implementation
target_role: programador
requires_design: true
design_screen_id: SCREEN-STORY-084-avaliacao-e-perfil
status: done
owner_agent: claude-opus-4-8
created_at: 2026-06-09
updated_at: 2026-06-09
estimated_session_size: M
produces_idr: null
---

# STORY-088 — Frontend: perfil (score/nível/XP/depoimentos) + UX do gate

> **Para o agente que vai executar:** leia a estória inteira. Fecha a superfície visível do EPIC-004. TDD + E2E.

## Contexto (por que esta estória existe)

A reputação só vira valor quando é **visível**: o perfil precisa mostrar score público, nível/badge, XP até o próximo nível e depoimentos; e o bloqueio (STORY-086) precisa de uma UX clara que leve ao turno pendente.

- Specs: `SCREEN-STORY-084-avaliacao-e-perfil` (perfil + UX do gate), DDR-004 (visibilidade de depoimentos).
- API: perfil expõe score/nível/XP/depoimentos (STORY-085); bloqueio retorna mensagem + turno pendente (STORY-086).

## O quê (objetivo desta estória)

- Atualizar o **perfil** (profissional e contratante — reciprocidade): score público (1 casa, ex. 4.9★), nível + badge (Iniciante/Confiável/Destaque/Elite), XP atual + XP até o próximo nível, depoimentos (até 3 mais recentes, conforme DDR-004).
- **UX do gate bloqueante**: ao ser bloqueado (candidatar/publicar), mostrar mensagem clara + **link para o turno pendente** que abre a tela de avaliação (STORY-087) dentro do shell.
- Estados vazio/erro/loading reusando o DS (STORY-079).

## Por quê (valor para o usuário)

Reputação visível motiva a operar bem; o bloqueio com saída clara transforma uma fricção em um próximo passo óbvio.

## Critérios de aceite

- [x] **CA-1:** Perfil do profissional mostra score (1 casa), nível + badge, XP atual e XP até o próximo nível, e depoimentos (até 3, conforme DDR-004) — fiel ao protótipo.
- [x] **CA-2:** Perfil do contratante (acessível pelo profissional) mostra score + depoimentos (reciprocidade), sem nível (MVP).
- [x] **CA-3:** Subida de nível reflete no perfil em ≤1s após avaliação recebida — o motor recomputa **síncrono** na transação (STORY-085) e o front **não cacheia** (lê o snapshot na próxima carga do perfil); verificável em homolog pelo roteiro.
- [x] **CA-4:** UX do gate: tentar candidatar-se/publicar com pendência mostra mensagem clara + link que abre a avaliação do turno pendente no shell.
- [x] **CA-5:** Estados vazio (sem avaliações/depoimentos), erro (com retry) e loading (skeleton) padronizados (DS).
- [x] **CA-6:** Cobertura ≥ 80% no código novo; **E2E** cobre: perfil exibe score/nível/depoimentos; bloqueio ao candidatar/publicar leva ao turno pendente.
- [x] **CA-7:** Deploy homologação verificado (rc.99 — app.homolog em v0.1.0-rc.99 + job "Smoke pós-deploy (homolog)" verde).

## Fora de escopo

- Telas de captura da avaliação (STORY-087). Backend (085/086). Dívida de a11y parqueada (só não regredir o piso AA).

## Padrões de qualidade exigidos

`quality-standards.md`. ≥80%; E2E integration_test; pt-BR/24h; AA por construção.

## Dependências

- **Bloqueada por:** STORY-087 (telas de avaliação — o gate linka para elas), STORY-085 (API do perfil), STORY-086 (resposta do bloqueio).
- **Bloqueia:** STORY-089 (validação).

## Decisões já tomadas (não as reabra)

- DDR-004 (depoimentos), DDR-003 (shell), ADR-019, PDR-005, spec de níveis/score.

## Liberdade técnica do agente

Decide: estrutura dos widgets do perfil, componente de badge/nível, design dos testes. NÃO decide: visibilidade de depoimentos (DDR-004), limites de nível (spec), CAs.

## Definição de Pronto (DoD)

- [x] CAs passam; widget + E2E verdes; cobertura atingida.
- [x] Pipeline verde; deploy homolog verificado (PO confirma visualmente — roteiro entregue).
- [x] `index.json` atualizado: status = `done`. "Notas do agente" preenchida.

**Resultado:** WebApp 734 testes verdes + API 1078 verdes; E2E browser real (perfil + gate) verde
no harness same-origin; lint api+admin+analyze limpos; deploy homolog rc.99 (release run 27237717550,
todos os jobs success). Descobertas corrigidas no caminho: (1) `POST /api/login` não devolvia `id`
— corrigido (bug de produto: perfil de reputação quebrava pós-login); (2) seed `profissional.avaliacao`
alinhado ao feed para o E2E do gate; (3) binding do E2E vai no **leaf** (não no entrypoint) — memória
do projeto atualizada.

## Protocolo do agente (obrigatório)

`docs/skills/po/references/agent-task-format.md` + skill `programador`. Designer revisa contra o protótipo.

## Notas do agente (preenchido durante/após execução)

### Decisões / Descobertas / Bloqueios

**Documentos lidos:** estória inteira; SCREEN-STORY-084 (T1–T4, microcopy §5, ids §7, estados §4);
skill `programador` + `agent-task-format`; API STORY-085 (`PerfilReputacaoController`/`Query`,
enum `NivelProfissional`); gate STORY-086 (`GateAvaliacao`, `PublicacaoBloqueadaPorAvaliacao`,
`AvaliacoesPendentesProfissional/Contratante`, 422 `{erro,mensagem,detalhe.turno_id}`); telas
STORY-087 (`avaliar_turno_screen`, rota `/turnos/:id/avaliar`); DS `state_views`, `rating_input`;
`perfil_screen` (Stateless, identidade+tema+Sair); `turni_datetime`; feed/vaga gate banners atuais.

**Entendimento:** STORY-088 = superfícies visíveis do EPIC-004 = **T3 (reputação no Perfil)** +
**T4 (UX do gate)**. T3 lê `GET /api/perfil/{id}` (score 1-casa / nível+badge / XP / depoimentos
até 3); contratante = score+depoimentos (sem nível/XP). T4 = "Avaliar agora" que leva o usuário
bloqueado ao turno pendente.

**3 gaps protótipo×API resolvidos com o PO (2026-06-09):**
1. **`funcao` no depoimento** — a API 085 não devolve a função; **decisão: adicionar** `funcao`
   ao `PerfilReputacaoQuery` (vem de `avaliacao.turno.vaga.funcao.nome`). Mudança aditiva.
2. **"Ver todas as avaliações (N)"** — sem endpoint de lista completa; **decisão: não renderizar**
   (só os 3 mais recentes; o total já aparece no score). CA-1 pede "até 3".
3. **Deep-link do gate** — feed do profissional só traz `pode_candidatar` (sem turno_id);
   **decisão: banner proativo → destino Turnos**; deep-link direto ao turno só no caminho reativo
   (tocar Candidatar/Publicar → 422 traz `detalhe.turno_id`). Onde o turno_id já existe (publicação,
   via `pendentes-do-contratante`), deep-linka direto.

**Descobertas:** `UserSession` não carrega `id` (preciso p/ `GET /perfil/{id}`) — `/api/user` já
devolve `id`; adiciono ao `UserSession` (aditivo, FE). `TurniDateTime` não tem data relativa —
adiciono `tempoRelativo()` (DDR-002: "há 3 dias"/"há 1 semana"/"há 2 meses"; >30d → dd/MM/aaaa).
DS não tem `display.rating`/`badge.nivel`/`meter.xp`/`card.depoimento` — crio os 4. Gate de
publicação do contratante é uma **fase de tela** (`_Phase.gate`), não banner.

**Plano (TDD por item):**
1. BE: `funcao` no depoimento (estende `PerfilReputacaoTest`).
2. `TurniDateTime.tempoRelativo` (unit).
3. DS: `RatingDisplay`, `NivelBadge`, `XpMeter`, `DepoimentoCard` (widget).
4. `UserSession.id` + `PerfilReputacaoService` + models (service).
5. Perfil T3: bloco de reputação no `perfil_screen` (Stateful) — estados loading/vazio/erro (CA-1/2/5).
6. T4: `CandidaturaBloqueada.turnoId` + "Avaliar agora" no modal/banners/fase do gate (CA-4).
7. E2E (integration_test): perfil exibe reputação; bloqueio leva ao turno pendente (CA-6).
8. Cobertura ≥80% + suíte verde + lint + deploy homolog (CA-7).

**Mapeamento CA → testes:**

- **CA-1 (perfil profissional: score/nível/XP/depoimentos):**
  - API: `PerfilReputacaoTest` › "depoimento traz a função do turno".
  - DS: `test/ds/reputacao_views_test.dart` (RatingDisplay score+contagem; NivelBadge rótulo;
    XpMeter "Faltam k XP para {próximo}"; DepoimentoCard nominal+data relativa).
  - Tela: `test/features/app/perfil_screen_test.dart` › "CA-1 profissional: score + nível + XP +
    depoimentos".
  - E2E: `integration_test/perfil/reputacao_e_gate_test.dart` › "Perfil exibe score, nível, XP e
    depoimentos".
- **CA-2 (perfil contratante: score + depoimentos, sem nível/XP):**
  - Service: `perfil_reputacao_service_test.dart` › "200 contratante: sem nível/XP, autor anônimo".
  - Tela: `perfil_screen_test.dart` › "CA-2 contratante: score + depoimentos, SEM nível e SEM XP".
- **CA-3 (subida de nível reflete ≤1s):** métrica do épico — o motor recomputa síncrono
  (STORY-085, `MotorReputacaoTest`); o perfil só lê o snapshot já recomputado (sem cache no front,
  reflete na próxima carga). Verificável em homolog (roteiro de teste).
- **CA-4 (UX do gate → turno pendente):**
  - Reativo candidatura: `candidatura_service_test.dart` (parse `detalhe.turno_id`) +
    `candidatura_flow_test.dart` › "gate avaliação com turno_id → 'Avaliar agora' deep-linka".
  - Banners: `feed_screen_test.dart` + `vaga_detalhe_screen_test.dart` › "'Avaliar agora' → Turnos".
  - Publicação: `vaga_service_test.dart` (turnoId de turnos[0]) + `publicar_vaga_screen_test.dart`
    › "gate da publicação deep-linka ao turno pendente mais antigo" / fail-secure → /turnos.
  - E2E: `reputacao_e_gate_test.dart` › "banner do gate no feed leva aos Turnos".
- **CA-5 (vazio/erro/loading):** `perfil_screen_test.dart` › "loading — skeleton", "vazio sem
  avaliações", "com score mas sem comentário", "erro — retry refaz a carga; Sair continua".
- **CA-6 (cobertura ≥80% + E2E):** suíte WebApp 734 verde; API 1078 verde; E2E perfil+gate.
- **CA-7 (deploy homolog):** verificado em homolog (rc.NN) — abaixo.

**Categorias de teste (não só caminho feliz):** inválido (gate sem turno_id → sem CTA; sessão sem
id → erro), exceção (404/500/rede no service; erro de reputação com retry), borda (Elite sem
xp_proximo; selo Novo 0/1/2; ≥30 dias → data absoluta; singular/plural da data relativa).


