---
story_id: STORY-087
slug: frontend-telas-avaliacao-reciproca
title: "Frontend — telas de avaliação recíproca (estrelas obrigatórias + comentário) no shell"
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

# STORY-087 — Frontend: telas de avaliação recíproca

> **Para o agente que vai executar:** leia a estória inteira. Implementa as SCREEN specs da STORY-084 dentro do shell (DDR-003). TDD + E2E (integration_test).

## Contexto (por que esta estória existe)

Com modelo/API (STORY-085) e specs/protótipo (STORY-084) prontos, o WebApp precisa das duas telas onde cada lado avalia o outro após o turno `finalizado`.

- Specs: `design/screens/SCREEN-STORY-084-avaliacao-e-perfil/` (protótipo = fonte de verdade visual).
- API: endpoints de submissão e de pendências (STORY-085).

## O quê (objetivo desta estória)

Implementar em Flutter, dentro do shell:
- Tela **profissional → contratante**: estrelas obrigatórias (1–5) + comentário opcional + submeter.
- Tela **contratante → profissional**: idem.
- Acesso a partir do turno `finalizado` e do ponto de bloqueio (link para o turno pendente).
- Estados vazio/erro/loading reusando o DS (STORY-079); microcopy pt-BR (DDR-002).

## Por quê (valor para o usuário)

É onde o usuário efetivamente fecha o ciclo — uma interação rápida e clara para avaliar e destravar a próxima ação.

## Critérios de aceite

- [x] **CA-1:** Tela profissional→contratante: estrelas obrigatórias (CTA desabilitado com 0), comentário opcional, submissão chama a API e trata sucesso/erro (retry). — `avaliar_turno_screen_test` + `avaliar_turno_service_test` + E2E (profissional).
- [x] **CA-2:** Tela contratante→profissional: idem (copy "Como foi o trabalho de {1º nome}?"). — `avaliar_turno_screen_test` + E2E (contratante).
- [x] **CA-3:** Telas no shell (drill-down no branch Turnos), responsivas (mobile rodapé fixo / desktop card centrado ≤560 com Voltar/Enviar); alcançáveis pelo CTA "Avaliar turno" do detalhe (sem rota); fiéis ao protótipo. — bloco `avaliacao` no detalhe + CTA + E2E lista→detalhe→tela.
- [x] **CA-4:** Erro de envio recuperável (banner "Tentar de novo" mantém estrelas+comentário); sucesso confirma (SnackBar) e volta ao contexto; o CTA some pós-envio (reload reflete `pendente:false`). — `avaliar_turno_screen_test` + `turno_detalhe_screen_test` + E2E.
- [x] **CA-5:** RBAC fail-secure: direção derivada do papel no servidor; 403/404 → "Este turno não é seu.". — `avaliar_turno_screen_test` + `avaliar_turno_service_test` + `TurnoDetalheTest`.
- [x] **CA-6:** Cobertura: api ≥80% (gate `--min=80` verde; controller 91.8%, seeder 99%); webapp 690 verdes. **E2E** (integration_test, Chrome 148 headless, same-origin) por papel: abrir a tela do turno pendente, submeter sem estrela (bloqueado), submeter com estrela (sucesso) — `avaliar_turno_test` 2 cenários, "All tests passed".
- [x] **CA-7:** Deploy homologação verificado — **rc.98** (release run 27232188315 verde: migrate+seed + deploy api/webapp/admin + smoke pós-deploy). Confirmação visual do PO nos 2 papéis pendente.

## Fora de escopo

- Perfil (score/nível/XP/depoimentos) + UX do gate — STORY-088. Backend — STORY-085/086.
- Dívida de a11y parqueada — só não regredir o piso AA dos componentes do DS.

## Padrões de qualidade exigidos

`quality-standards.md`. ≥80%; E2E integration_test; pt-BR/24h; AA por construção (DS).

## Dependências

- **Bloqueada por:** STORY-084 (specs/protótipo) e STORY-085 (API).
- **Bloqueia:** STORY-088 (perfil/UX do gate parte daqui) e STORY-089 (validação).

## Decisões já tomadas (não as reabra)

- DDR-003 (shell), DDR-004 (depoimentos — afeta o perfil, não a captura), ADR-019, PDR-005, IDR-010/011/021 (E2E).

## Liberdade técnica do agente

Decide: estrutura dos widgets, componente de rating (se DDR-004/Designer promoveu um ao DS, consome), design dos testes. NÃO decide: layout (protótipo STORY-084), obrigatoriedade (PDR-005), CAs.

## Definição de Pronto (DoD)

- [x] CAs passam; widget + E2E verdes; cobertura atingida.
- [x] Pipeline verde; deploy homolog verificado via rc.98 (PO confirma visualmente nos 2 papéis).
- [x] `index.json` atualizado: status = `done`. "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

`docs/skills/po/references/agent-task-format.md` + skill `programador`. Designer revisa contra o protótipo.

## Notas do agente (preenchido durante/após execução)

### Plano (registrado antes de codar — 2026-06-09)

**Documentos lidos:** estória inteira; `agent-task-format.md`; skill `programador`; `SCREEN-STORY-084-avaliacao-e-perfil.md` (§§1–11); API STORY-085/086 (`AvaliarTurnoController`, `RegistrarAvaliacaoService`, `AvaliacaoDirecao`, `Avaliacao`, `AvaliacoesPendentesProfissional/Contratante`, `GateAvaliacao`, `TurnoDetalheController`); WebApp (`turno_detalhe_screen/service`, `router.dart`, `ds/state_views.dart`, `ds/tokens.dart`); harness E2E (`pump_app`, `login_helper`, `route_helper`, `detalhe_turno_test`, `web_test`/`turnos_test`); `AvaliacaoSeeder`; Makefile E2E.

**Entendimento consolidado:** T1 (profissional→contratante) e T2 (contratante→profissional) — uma tarefa: estrelas obrigatórias (1–5) + comentário opcional (≤280 na UI; API aceita ≤1000) + enviar. Direção/avaliado derivam do papel no servidor (RBAC fail-secure). Contratos: `POST /turnos/{id}/avaliar` → 201 | 422 `estado_invalido` | 409 `ja_avaliado` | 403; contexto do turno via `GET /turnos/{id}`. T3/T4 (perfil + gate banner) são STORY-088 — fora.

**Decisão de escopo (aditiva, sinalizada ao PO):** os CA-3/CA-4 exigem alcance "pelo turno pendente, sem digitar rota" e que a pendência reflita resolvida pós-envio. Adiciono ao payload de `GET /turnos/{id}` (estados `finalizado`/`finalizado_ajustado`) um bloco **aditivo, read-only** `avaliacao: { pendente: bool, direcao: string }`, derivado do estado (sem tabela nova; reusa a mesma fonte das `AvaliacoesPendentes*`). Powers o CTA "Avaliar turno" no detalhe (só quando pendente) e o estado inicial da tela. É costura de wiring do front, não decisão de produto/arquitetura (modelo/gate já existem em ADR-019/STORY-085/086).

**Plano (bullets):**
1. BE — `TurnoDetalheController`: bloco `avaliacao` (TDD Feature).
2. BE — par de seed E2E determinístico (1 turno finalizado, reset-to-pending por run).
3. DS — `TurniRatingInput` (input.rating) + widget tests.
4. FE — `AvaliarTurnoService` (sealed result) + unit tests.
5. FE — `AvaliarTurnoScreen` (T1/T2, estados §4) + widget tests; rota `/turnos/:id/avaliar`; CTA no detalhe + reload pós-sucesso.
6. E2E — `avaliar_turno_test.dart` (2 papéis) no agregador `turnos_test`.

**Mapa CA → testes (a preencher com nomes finais):**
- CA-1 (T1 prof→contratante): widget `avaliar_screen` (feliz/sem-estrela-bloqueia/erro-retry-mantém-estado) + unit service + E2E profissional.
- CA-2 (T2 contratante→prof): idem espelho + E2E contratante.
- CA-3 (shell, responsivo, alcançável, fiel): widget de layout mobile/desktop + CTA no detalhe (widget) + E2E (lista→detalhe→avaliar).
- CA-4 (erro recuperável; sucesso resolve): widget erro-retry + E2E pendência some pós-envio.
- CA-5 (RBAC fail-secure): widget 403 "Este turno não é seu"; servidor é fonte de verdade.
- CA-6 (≥80% + E2E por papel): cobertura + 2 cenários E2E.

### Decisões / Descobertas / Bloqueios

**Decisões locais**
- **Campo aditivo `avaliacao{pendente,direcao}` no `GET /turnos/{id}`** (estados avaliáveis) — costura read-only derivada do estado (reusa a régua das `AvaliacoesPendentes*`/`RegistrarAvaliacaoService`), exigida por CA-3 (alcançar pelo turno pendente, sem rota) e CA-4 (pós-envio a pendência reflete resolvida → o CTA some). Não é decisão de produto/arquitetura (modelo/gate já são ADR-019/085/086). `TurnoDetalheController` 91.8% (linhas descobertas são branches pré-existentes 060/065).
- **`input.rating` (DS): `TurniRatingInput`** — estrela cheia/vazia por ÍCONE (`star_rounded`×`star_border_rounded`), não só cor (regra AA dos tokens); helper textual duplica o valor ("Ruim".."Ótimo"); alvos ≥48dp; `errorText` associado. Controle puro (estado é da tela).
- **Entrada via CTA "Avaliar turno" no detalhe do turno finalizado** (SCREEN-084 §2): `push('/turnos/:id/avaliar')`; ao voltar, o detalhe recarrega e o CTA some (CA-4). Tela reusa `GET /turnos/{id}` para o contexto.
- **Estados 409/422 como informativo** ("Você já avaliou este turno." / "Este turno não pode mais ser avaliado."), 403/404 → "Este turno não é seu." (CA-5 fail-secure), erro de rede → banner inline recuperável que MANTÉM estrelas+comentário (CA-4).
- **Comentário ≤280 na UI** (API aceita ≤1000); a linha de onboarding (§4.7) entra estática e discreta (sem rastrear "1ª vez" — simplificação consciente, a11y parqueada).
- **Seed E2E determinístico** (`AvaliacaoSeeder::seedE2ePair`): par `*.aval087.seed` com EXATAMENTE 1 turno finalizado, RESETADO p/ totalmente pendente a cada seed (E2E repetível apesar da mutação; os 2 papéis avaliam direções distintas do mesmo turno sem colidir).

**Descobertas (gotchas)**
- **Entrypoint E2E top-level inicializa o binding.** Os leaf files de `turnos/` NÃO chamam `IntegrationTestWidgetsFlutterBinding.ensureInitialized()` — dependem do `auth_test` rodar 1º no `web_test.dart`. Rodar um leaf isolado trava com "Timed out receiving message from renderer". Para validar isolado, criar um entrypoint top-level que inicializa o binding (e `../helpers` resolve só a partir do topo de `integration_test/`).
- **Suíte api full local precisa de `memory_limit=512M`** (o `make test-api` já usa) — o `php artisan test` cru a 128M estoura no `SeedTest` conforme a base cresce.

### Mapeamento CA → teste (final)
- **CA-1 (T1 prof→contratante):** `avaliar_turno_screen_test` (copy T1 + estabelecimento; escolher estrela habilita+envia; comentário viaja) · `avaliar_turno_service_test` (201/comentário) · E2E `avaliar_turno_test` (profissional).
- **CA-2 (T2 contratante→prof):** `avaliar_turno_screen_test` ("Como foi o trabalho de {1º nome}?") · E2E `avaliar_turno_test` (contratante).
- **CA-3 (shell/responsivo/alcançável/fiel):** `avaliar_turno_screen_test` (desktop par Voltar/Enviar; mobile rodapé) · `turno_detalhe_screen_test` (CTA presente em finalizado pendente) · `TurnoDetalheTest` (bloco `avaliacao`) · E2E (lista→detalhe→CTA→tela).
- **CA-4 (erro recuperável; sucesso resolve):** `avaliar_turno_screen_test` (erro de envio mantém estrelas/comentário + retry; 409→informativo) · `turno_detalhe_screen_test` (pendente:false NÃO mostra CTA) · E2E (CTA some após enviar).
- **CA-5 (RBAC fail-secure):** `avaliar_turno_screen_test` (404→"Este turno não é seu"; 403 no envio idem) · `avaliar_turno_service_test` (403) · `TurnoDetalheTest` (direção independente não vaza).
- **CA-6 (≥80% + E2E por papel):** cobertura api ≥80% (gate `--min=80` verde; controller 91.8%, seeder 99%); webapp 690 testes verdes; E2E `avaliar_turno_test` 2 cenários (profissional + contratante: bloqueio sem estrela → sucesso), em Chrome real same-origin.
- **`TurniRatingInput`:** `rating_input_test` (4 categorias: feliz/borda 0/borda contagem/erro).
- **`AvaliarTurnoService`:** `avaliar_turno_service_test` (201/comentário-nulo/409/422/403/rede/500).

### Evidência
- api: 1076 passed (6456 assertions); coverage gate `--min=80` verde.
- webapp: 690 testes (unit+widget) verdes; `flutter analyze` limpo (2 infos pré-existentes em `pre_cadastro_*`, intocados); `dart format` aplicado; `pint --test` 433 files PASS.
- E2E: `make e2e-webapp-pinned` (Chrome 148 pinado, headless, same-origin) — "All tests passed." (2 cenários).
