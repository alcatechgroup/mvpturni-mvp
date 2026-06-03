---
story_id: STORY-071
slug: refactor-frontend-uuid-flutter
title: Refactor frontend — Flutter webapp: DTOs, services, telas, integration_test (IDs como String)
epic_id: EPIC-010
sprint_id: SPRINT-2026-W27.5
type: refactor
target_role: programador
requires_design: false
design_screen_id: null
status: done
owner_agent: claude-opus-4-8 (sessão 2026-06-03 STORY-071)
created_at: 2026-06-03
updated_at: 2026-06-03
estimated_session_size: M
produces_idr: null
---

# STORY-071 — Refactor frontend: IDs como `String` no Flutter webapp

> **Para o agente que vai executar:** roda **em paralelo** com STORY-070 — pastas distintas, zero overlap de merge. **Antes de começar**, leia `epics/EPIC-010-.../runbook-refactor-flutter.md` produzido pela STORY-069 (essa é a lista mecânica do que tocar) e ADR-018 (especialmente Decisão 7). Refactor é mecânico — não inventar tipagem extra (ex: classe `EntityId`), apenas trocar `int` por `String` onde for ID e ajustar `int.tryParse`/`toString()` que existir.

## Contexto (por que esta estória existe)

ADR-018 fixou IDs do Turni como `uuid` no banco e `String` no Flutter. O webapp hoje tipa IDs como `int?`: `funcao_id: json['funcao_id'] as int?`, `int? _funcaoId`, `CadastroDropdownField<int>`. Após STORY-070 entrar em homolog, a API começa a retornar IDs como string UUID; o webapp para de funcionar se não acompanhar.

- Épico: `epics/EPIC-010-refator-uuid-chaves-primarias/epic.md`
- Documentos canônicos:
  - `epics/EPIC-010-.../runbook-refactor-flutter.md` (produzido pela STORY-069)
  - `decisions/adr/ADR-018-uuid-chave-primaria-entidades-dominio.md` (§Decisão 7)

## O quê (objetivo desta estória)

Trocar tipo de IDs de `int?`/`int` para `String?`/`String` em todos os DTOs, services, controllers e widgets do `apps/webapp/lib/`, ajustar formulários (dropdown, hidden fields) e atualizar testes (`integration_test` + Playwright smoke) para o novo tipo. Sem mudar UX, sem mudar lógica de validação de formulário.

## Por quê (valor para o usuário)

Indireto: sem este refactor, após STORY-070 ir para homolog o WebApp quebra ao tentar consumir API.

## Critérios de aceite

- [ ] **CA-1 — DTOs e services convertidos.** Toda variável tipada como `int? *_id`, `int *_id`, ou similar em `apps/webapp/lib/features/**/*.dart` vira `String?` / `String`. Inclui no mínimo (varrer todos, não apenas estes):
  - `lib/features/cadastro/completar_cadastro_service.dart`: `int? funcaoId` → `String? funcaoId`; `json['funcao_id'] as int?` → `json['funcao_id'] as String?`.
  - `lib/features/cadastro/cadastro_service.dart`: `int funcaoId` → `String funcaoId`; `'funcao_id': funcaoId.toString()` → `'funcao_id': funcaoId` (sem `toString()`).
  - `lib/features/cadastro/pre_cadastro_profissional_screen.dart`: `int? _funcaoId` → `String? _funcaoId`; `CadastroDropdownField<int>` → `CadastroDropdownField<String>`.
  - `lib/features/cadastro/completar_cadastro_screen.dart`: filtro `f.id != _contexto?.funcaoId` continua válido — só tipo muda.
  - Qualquer tela/feature que materialize após este refactor (vaga, candidatura, painel) — varrer com `grep -rn "int? .*_id\|as int?" lib/`.

- [ ] **CA-2 — Modelos de domínio Dart (se houver).** Se existir alguma classe `Funcao`, `User`, `Vaga` em Dart com `int id`, virar `String id`. Auditar `lib/features/*/models/*.dart` e `lib/core/**/*.dart` se houver.

- [ ] **CA-3 — Forms preservam comportamento.** Após mudança de tipo, todo dropdown/select continua exibindo as mesmas opções, value selecionado é gravado no estado correto, submissão para a API envia `funcao_id` como string (UUID). Testes manuais em `flutter run -d chrome` validam: pré-cadastro profissional, pré-cadastro contratante, completar cadastro profissional, completar cadastro contratante.

- [ ] **CA-4 — `integration_test` verde.** Suíte completa `apps/webapp/integration_test/*.dart` roda verde com schema novo da API (depende de STORY-070 estar deployada em ambiente onde os testes rodam — assumir homolog ou ambiente local docker-composado).

- [ ] **CA-5 — Playwright smoke verde.** `apps/webapp/tests/e2e/*.spec.ts` continua passando — auditar se algum spec assume formato de ID (ex: número em URL); se sim, ajustar regex para UUID (`/[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/` é o pattern v7).

- [ ] **CA-6 — `int.tryParse` removido em campos de ID.** `grep -rn "int.tryParse" lib/` — qualquer ocorrência sobre ID some; ocorrências sobre valores numéricos reais (CEP filtrado, valor em centavos, etc.) ficam. Documentar nas notas quais foram preservadas e por quê.

- [ ] **CA-7 — Mensagens de erro de form e validação preservadas.** Ao submeter form com ID inválido, mensagem do servidor (`_serverErrors['funcao_id']`) continua sendo exibida no campo certo. Nenhuma regressão de UX.

- [ ] **CA-8 — Sem cast `int` residual em handlers de notificação ou navegação.** Se há rotas que carregam `vagaId` ou `candidaturaId` em path params (ex: `/vagas/:id`), ajustar o router (`apps/webapp/lib/router.dart`) para aceitar string. Auditar `router.dart` por completo.

- [ ] **CA-9 — Build de produção verde.** `flutter build web --release` em `apps/webapp/` sem warnings novos. Compilação AOT passa.

- [ ] **CA-10 — IDR aberto se houve descoberta relevante.** Mesma regra de STORY-070.

## Fora de escopo

- Refactor do backend — STORY-070.
- Mudar lógica de validação ou UX.
- Refatorar para usar value object/typed ID class (`UserId`, `VagaId`, etc.) — fora desta sprint; se PO quiser depois, vira IDR/ADR próprio.
- Tocar admin (admin tem testes próprios — STORY-070 cobre).

## Padrões de qualidade exigidos

- `integration_test` verde.
- Playwright smoke verde.
- `flutter analyze` sem novos warnings em código novo.
- Sem regressão de UX (validar manualmente os 4 fluxos do CA-3).

## Dependências

- **Bloqueada por:** STORY-069 (`done`, runbook Flutter pronto).
- **Bloqueia:** STORY-072 (validação).
- **Paralelo a:** STORY-070 (zero overlap de merge — `apps/webapp/lib/` vs `apps/api/` e `apps/admin/`).
- **Pré-requisitos de ambiente:** Flutter SDK no projeto; STORY-070 deployada (ou ambiente local com api/admin novos) para rodar `integration_test` contra schema novo.

## Decisões já tomadas (não as reabra)

- ADR-018 §Decisão 7: IDs como `String` no Flutter; sem typed ID class.

## Liberdade técnica do agente

Você decide:
- Ordem de arquivos a refatorar.
- Se vale criar helper `String? _tryString(dynamic v) => v?.toString()` para defesa em parsing — provavelmente não, mas é decisão local.
- Como atualizar testes.

Você NÃO decide:
- Tipo do ID (já é `String`).
- Se cria typed ID class (não, fora de escopo).

## Definição de Pronto (DoD)

- [ ] Todos os 10 CAs passam.
- [ ] `integration_test` e Playwright smoke verdes.
- [ ] `flutter analyze` limpo.
- [ ] Pipeline CI verde.
- [ ] `index.json` atualizado: status `done`.
- [ ] Notas do agente preenchidas.

## Protocolo do agente (obrigatório)

Padrão do projeto.

## Notas do agente (preenchido durante/após execução)

### Decisões tomadas
- 2026-06-03 — IDs viram `String`/`String?` opacos (ADR-018 §Decisão 7). Sem typed ID class, sem validação de formato UUID no Flutter (quem valida é o backend). Parsing JSON: `as String`/`as String?`, removendo `(... as num).toInt()` e `?? 0`. Onde a UI exige não-nulo (ex.: `PublicarSuccess.vagaId`, `VagaEditar.funcaoId`), fallback `?? ''`.
- 2026-06-03 — Ids string curtos (`'1'`, `'7'`…) nos testes unit/widget em vez de UUIDs literais. O Flutter trata o id como string opaca, então `'1'` preserva todas as asserções de `Key('feed-card-1')`/`Key('candidato-card-1')` sem reescrever os matchers — diff mínimo.

### Descobertas
- 2026-06-03 — **Runbook (§3) errou ao listar `ValueChanged<int>` (publicar_vaga:522 / editar_vaga:885) como "função → `<String>`".** Essas linhas são o **stepper de posições** (`onChanged(value-1)`/`onChanged(value+1)`) — inteiro real, não ID. Mantidas como `int`. Só os dropdowns de função (`DropdownMenu<int>`/`DropdownMenuEntry<int>`) viraram `<String>`.
- 2026-06-03 — **`integration_test` tinha matcher de card com id numérico**: `RegExp(r'^feed-card-\d+$')` em `feed/feed_test.dart` e `vagas/candidatura_test.dart`. Com UUID o card vira `feed-card-019e8f6d-…` e o `\d+` não casava → trocado pelo pattern UUID `^feed-card-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$` (casa só o card principal, não as sub-keys `-score`/`-alto-match`).
- 2026-06-03 — **Telas carregavam mais campos-ID que o runbook enumerou**: `feed_screen` (`_SeloRevisao`/`_ScoreChip`/`_ScoreBar`/`_AltoMatchBadge`), `minhas_vagas` (`_EstadoBadge`/`_PosicoesPill`), `painel_candidatos` (7 widgets com `vagaCandidatoId`), `vaga_detalhe_screen` (`onConflito`). Todos só usavam o id em `ValueKey` interpolada — retipados `int→String` sem outra mudança.

### Bloqueios encontrados
- 2026-06-03 — **`integration_test` falhou na 1ª rodada por banco de dev sujo** (não por regressão): `_e2e-seed` faz `migrate + db:seed` (aditivo/idempotente), e runs anteriores deixaram a vaga do painel cancelada + 0 candidaturas pendentes + 12 vagas "Bartender" acumuladas. Resolvido com `migrate:fresh --seed --force --drop-types` (IDR-027 — o `--drop-types` é obrigatório pelos enums `vaga_estado`/`candidatura_estado` da STORY-070). Após reset, `PainelCandidatosSeeder` recriou "vaga do contratante.teste + 3 candidaturas ranqueadas" e a suíte passou 100%.

### Evidências por CA
- CA-1: services/DTOs convertidos — `feed_service`, `notificacao(es)_service`, `vaga_service`, `vaga_detalhe_service`, `candidatos_service`, `candidatura_service`, `cadastro_service`, `completar_cadastro_service`. `flutter analyze` limpo.
- CA-2: modelos de domínio Dart (`Funcao`, `FeedVagaResumo`, `VagaResumo`, `VagaEditar`, `VagaDetalhe`, `Notificacao`, `PerfilCandidato`, `CandidatoCard`, `CandidaturaResumo`, `ConflitoInfo`) com `id`/`*_id` em `String`.
- CA-3: 4 fluxos validados via `integration_test` (rodando no Chrome same-origin contra API UUID local): pré/completar cadastro (função no dropdown), publicar/editar vaga (função), candidatura, painel de candidatos.
- CA-4: `make e2e-webapp-integration` → **All tests passed** (exit 0) em banco limpo.
- CA-5: `make e2e-webapp-smoke` → 4 passed, 1 skipped (`/health` é homolog-only).
- CA-6: `int.tryParse` preservados (não-ID): `completar_cadastro_contratante_screen.dart:652` (CEP filtrado por `\D`), `completar_cadastro_screen.dart:195` (raio_max_km) e `:312` (validação de raio em km). Nenhum sobre ID restante em `lib/`.
- CA-7: mensagens de erro de form preservadas — `_serverErrors['funcao_id']`/validators intactos; widget tests verdes.
- CA-8: `router.dart` — 3 rotas (`/vaga/:id`, `/contratante/vagas/:id/editar`, `…/:id/candidatos`) passaram de `int.tryParse(...) ?? 0` para `state.pathParameters['id'] ?? ''`; telas retipadas para `vagaId: String`.
- CA-9: `flutter build web --release` → ✓ Built build/web (wasm dry-run ok, sem warnings novos).
- CA-10: **Sem IDR formal** — as 2 descobertas (stepper `<int>` mal-listado no runbook; regex `\d+` no integration_test) são correções locais registradas aqui; não alteram ADR-018 nem o contrato. Vale o Arquiteto corrigir o runbook §3 para a próxima vez.

### Cobertura final
- `flutter test` (unit/widget): 340 testes verdes.
- `integration_test` (área logada, local same-origin): feed ranqueado + detalhe/breakdown, painel candidatos, editar+diff, candidatura+retirada, conflito de horário — todos verdes.
- E2E (Playwright smoke): hello-world, version.json, console limpo, deep link /login.

### Links de evidência
- Commit: `feat(STORY-071): UUID como String no Flutter webapp` (main)
- Build release: `flutter build web --release` ✓ (local)
- integration_test: `/tmp/e2e-out3.txt` (All tests passed)
