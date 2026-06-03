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
status: ready
owner_agent: null
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
- <data> — <decisão local>

### Descobertas
- <data> — <gotcha>

### Bloqueios encontrados
- <data> — <bloqueio>

### Evidências por CA
- CA-1: <link de commits>
- CA-2: <link>
- CA-3: <screenshots dos 4 fluxos>
- CA-4: `integration_test` — <link CI>
- CA-5: Playwright — <link CI>
- CA-6: `int.tryParse` preservados — <lista>
- CA-7: <ok>
- CA-8: router — <link commit>
- CA-9: build release — <log>
- CA-10: IDR? <sim/não>

### Cobertura final
- `integration_test`: <% / cenários>
- E2E (Playwright smoke): <cenários>

### Links de evidência
- PR: <url>
- Pipeline: <url>
- Build release: <log>
