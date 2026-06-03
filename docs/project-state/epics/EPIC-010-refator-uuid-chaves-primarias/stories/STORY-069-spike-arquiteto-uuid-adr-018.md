---
story_id: STORY-069
slug: spike-arquiteto-uuid-adr-018
title: Spike Arquiteto — variante UUID, polimórficos, plano de execução (produz ADR-018 accepted)
epic_id: EPIC-010
sprint_id: SPRINT-2026-W27.5
type: spike
target_role: arquiteto
requires_design: false
design_screen_id: null
status: ready
owner_agent: null
created_at: 2026-06-03
updated_at: 2026-06-03
estimated_session_size: M
produces_idr: null  # produz ADR-018, não IDR
---

# STORY-069 — Spike Arquiteto: variante UUID + ADR-018 `accepted`

> **Para o agente que vai executar:** esta estória **destrava** todo o EPIC-010 e, indiretamente, a SPRINT-2026-W28. Sem ADR-018 `accepted`, nada pode mudar de tipo no banco. Leia o **draft de ADR-018 em `decisions/adr/ADR-018-uuid-chave-primaria-entidades-dominio.md`** (status `proposed`) por inteiro antes de começar — ele já contém o desenho proposto. Sua missão é validar empiricamente os pontos finos, fechar lacunas, e levar a ADR ao status `accepted`. **Não é** spike "do zero": é spike de validação de uma proposta já estruturada.

## Contexto (por que esta estória existe)

O Turni assumiu, na origem, o desejo arquitetural de IDs de entidade como UUID string — incluindo no banco — mas a intenção nunca foi registrada em ADR e ficou para trás nas SPRINTs W22–W27 sob pressão de execução. Ao fim da W27 o débito materializou-se em escala: ≈27 migrations × 2 apps, 14 models, 17 FKs bigint, 2 polimórficas, ~8 telas Flutter assumindo `int?`. A SPRINT-2026-W28 (planned) integra Pagar.me sandbox (STORY-056) e passa a usar `external_reference` apontando para IDs do Turni — a partir desse commit, a janela para virar o tipo a baixo custo se fecha.

Esta estória produz **ADR-018 `accepted`**, validando 4 pontos finos por execução empírica em ambiente local/homolog, antes que STORY-070 (refactor backend) e STORY-071 (refactor Flutter) comecem.

- Épico: `epics/EPIC-010-refator-uuid-chaves-primarias/epic.md`
- Documentos canônicos a ler ANTES de executar:
  - `docs/project-state/decisions/adr/ADR-018-uuid-chave-primaria-entidades-dominio.md` (draft `proposed` — sua base)
  - `docs/project-state/decisions/adr/ADR-000-postgresql-banco-principal.md`
  - `docs/project-state/decisions/adr/ADR-001-stack-principal.md`
  - `docs/project-state/decisions/adr/ADR-007-auth-base-e-roteamento.md`
  - `docs/project-state/decisions/adr/ADR-009-modelo-de-dados-identidade-epic-001.md`
  - `docs/project-state/decisions/adr/ADR-013-modelo-vaga-candidatura-snapshot.md`
  - Schema atual: `apps/api/database/migrations/` e `apps/admin/database/migrations/` (especialmente arquivos `2026_05_*` e `2026_06_*`)
  - Documentação Laravel: `HasVersion7Uuids`, `foreignUuid()`, `uuidMorphs()` (referenciar versão exata do Laravel instalado em `apps/api/composer.lock`)

## O quê (objetivo desta estória)

Validar empiricamente 4 pontos finos da proposta da ADR-018, fechar lacunas (se houver), levar a ADR ao status `accepted` por PO, e produzir um **runbook de execução** que STORY-070 e STORY-071 consumirão sem ambiguidade.

## Por quê (valor para o usuário)

Sem ADR aceita, nenhuma mudança estrutural pode acontecer (disciplina herdada — princípio não-negociável #5 do PO). Validar antes de mexer no schema evita refactor com surpresa no meio (caro e arriscado).

## Critérios de aceite

Cada item é uma asserção testável. O agente DEVE registrar evidência (link de commit/log/output) para cada CA na seção "Notas do agente".

- [ ] **CA-1 — `HasVersion7Uuids` produz UUIDs válidos e ordenados em PHP.** Em uma sessão `php artisan tinker` ou script standalone em `apps/api`, criar 1000 instâncias de um model temporário com `HasVersion7Uuids`, coletar os UUIDs gerados em ordem, e verificar: (a) todos têm versão 7 (4 bits altos do 7º byte = `7`); (b) `usort($ids)` resulta na mesma ordem cronológica de geração (tolerância: empates dentro do mesmo ms); (c) zero colisões em 1000 IDs. Registrar o script usado no diretório `apps/api/database/scripts/uuid_v7_validation.php` (apagar ao fim do spike ou mover para `tests/Unit/UuidV7GenerationTest.php`).

- [ ] **CA-2 — Override de `personal_access_tokens.tokenable_id` (Sanctum) funciona.** Criar uma migration de teste local que substitui `morphs('tokenable')` por `uuidMorphs('tokenable')` na tabela `personal_access_tokens` (rebuild da tabela em ambiente local, ou nova migration que faz `DROP COLUMN tokenable_id, tokenable_type; ADD uuidMorphs('tokenable')`). Executar fluxo de login de teste contra a tabela alterada com um User com PK UUID temporário; verificar que Sanctum emite token e autentica corretamente. Documentar o caminho exato na ADR (seção Decisão 4 expandida com snippet).

- [ ] **CA-3 — Spatie/Laravel-Passkeys suporta User com PK UUID OU caminho alternativo identificado.** Inspecionar o código do pacote em `apps/api/vendor/spatie/laravel-passkeys/` para verificar se `Passkeys::userModel()` e `foreignIdFor` funcionam quando o User tem `$keyType = 'string'`. Se sim, documentar. Se não, propor um dos caminhos: (a) override da migration que cria `passkeys.user_id` para `uuid`; (b) coluna `users.uuid` separada usada apenas pelo Passkeys; (c) substituição da lib. **Decidir e registrar na ADR-018** (atualizando Decisão 4 ou criando Decisão 4-bis).

- [ ] **CA-4 — Migration de conversão proposta vs. reset: confirmar reset é viável.** Confirmar que o banco de homolog está com **dados descartáveis** (sem cadastros reais de usuários externos). Documentar o estado em texto na ADR (Decisão 5). Se houver qualquer dado material, **parar e escalar ao PO** — Decisão 5 pode precisar virar 5B. Registrar evidência: `SELECT COUNT(*) FROM users WHERE email NOT LIKE '%@turni.local' AND email NOT LIKE '%@example.%' AND email NOT LIKE '%@seed.%'` em homolog deve retornar 0 (ou lista revisada e marcada como descartável pelo PO).

- [ ] **CA-5 — Runbook de execução pronto para STORY-070.** Arquivo `epics/EPIC-010-refator-uuid-chaves-primarias/runbook-refactor-backend.md` criado com o passo-a-passo mecânico que STORY-070 vai seguir: (1) ordem de reescrita das migrations, (2) lista de models que recebem `HasVersion7Uuids` e `$keyType = 'string'`, (3) lista de FKs (de → para) que viram `foreignUuid`, (4) lista de polimórficas (override de Sanctum + uuidMorphs em audit_logs), (5) lista de seeders a auditar (referência a `->id` pode quebrar), (6) lista de tests a auditar e re-rodar, (7) comando exato de deploy em homolog (`migrate:fresh --seed` + smoke de `migrate:rollback` + `migrate:fresh` de novo). O runbook é a interface entre o spike e a execução; precisa ser sem ambiguidade.

- [ ] **CA-6 — Runbook de execução pronto para STORY-071 (Flutter).** Arquivo `epics/EPIC-010-refator-uuid-chaves-primarias/runbook-refactor-flutter.md` criado com: (1) lista de DTOs/services com `int? id` ou `int? *_id` que viram `String?`/`String`, (2) lista de widgets que tipam value de dropdown como `int` (esp. `CadastroDropdownField<int>` em `pre_cadastro_profissional_screen.dart`), (3) lista de testes (`tests/e2e/*.spec.ts` + `integration_test/*.dart`) que asseram tipo de ID, (4) padrão para `score_breakdown` JSON se contiver IDs.

- [ ] **CA-7 — Análise de impacto no `score_breakdown` JSON de `candidaturas`.** Auditar o shape gerado pela STORY-045 (Match) e a forma que STORY-049/051 consomem o breakdown. Se IDs estiverem embutidos no JSON, registrar na ADR como item de cuidado da STORY-070 (varrer e ajustar formato). Se não estiverem (apenas valores numéricos do score), registrar como "sem impacto" e seguir.

- [ ] **CA-8 — ADR-018 termina em `status: accepted`** após revisão do PO em chat ou via PR. Sem aceitação, a estória fica `in_review`. Atualizar frontmatter da ADR (`status`, `decided_at`, `approved_by`, `forma do aceite`) e registrar no histórico.

- [ ] **CA-9 — Estimativa final de esforço para STORY-070 e STORY-071 atualizada na ADR.** Spike é a oportunidade de calibrar: se descobrir que o trabalho é maior (ex: Spatie passkeys exigir patch), atualizar a tabela de "Custo de refactor agora" na ADR e avisar PO. Se for menor, idem.

## Fora de escopo

- Mudar qualquer linha de código de produção (migrations, models, Flutter) — isso é STORY-070 e STORY-071.
- Decidir nova ADR sobre Postgres 18+ ou `gen_random_uuid()` no banco — fora do escopo desta refator (referenciado no plano de verificação da ADR-018 como sinal de revisão futura).
- Refatorar tabelas internas do Laravel (`cache`, `jobs`, `sessions`). Decisão 3 da ADR já fixou: ficam como estão.

## Padrões de qualidade exigidos

- Toda asserção de CA tem evidência documentada (link de commit, output de comando, screenshot).
- Scripts de validação criados em `apps/api/database/scripts/` durante o spike vão para `tests/Unit/` (se forem teste durável) ou são apagados ao fim (se forem exploração temporária). Não deixar lixo no repo.
- A ADR atualizada com qualquer descoberta empírica — não inventar caminho que não foi testado.

## Dependências

- **Bloqueada por:** SPRINT-2026-W27 fechada (STORY-053 + STORY-054 `done`, veredito aceito pelo PO). Sem isso, esta sprint não ativa.
- **Bloqueia:** STORY-070, STORY-071, STORY-072 (toda a sprint depende desta).
- **Pré-requisitos de ambiente:** ambiente local Docker subindo `apps/api` + Postgres; acesso a homolog para conferir estado de dados (CA-4).

## Decisões já tomadas (não as reabra)

- **ADR-000**: PostgreSQL principal, tipo `uuid` nativo disponível.
- **ADR-001**: Laravel/Eloquent. `HasVersion7Uuids`, `foreignUuid()`, `uuidMorphs()` são first-class.
- **ADR-007**: Sanctum SPA. Mexer em `tokenable_id` polimórfico é necessário; mecanismo (sessão, RBAC, FunnelGuard) NÃO muda.
- **ADR-009 e ADR-013**: modelo lógico das tabelas (1:1 perfis, snapshot vaga_versoes, polimórfico audit_logs) **permanece igual**. Só o tipo da chave muda.
- **ADR-018 draft proposed**: já fixa UUIDv7, tipo `uuid` Postgres, escopo (15 tabelas de domínio), polimórficos com `uuidMorphs()`, geração na aplicação, reset de migrations, Flutter String. Você valida e leva ao `accepted`; não reabre as decisões 1 a 7 a menos que a validação empírica revele bloqueador.

## Liberdade técnica do agente

Você (agente arquiteto) decide:
- Forma exata dos scripts de validação dos CAs 1, 2, 3.
- Granularidade dos runbooks (CA-5 e CA-6) — desde que não-ambíguos para STORY-070 e STORY-071.
- Como propor caminho alternativo no CA-3 se Spatie passkeys for incompatível.

Você (agente arquiteto) NÃO decide:
- Variante (v4 vs v7 vs ULID) — ADR-018 já decidiu v7.
- Tipo de coluna (uuid vs char(36)) — ADR-018 já decidiu uuid.
- Escopo (que tabelas mudam) — ADR-018 já decidiu.
- Estratégia (reset vs conversão) — ADR-018 já decidiu reset, condicionado ao check de CA-4.

Se durante a execução empírica você descobrir bloqueador real (ex: Sanctum override quebrar fluxo de auth de modo não-contornável), **pare e escale ao PO** — não decida sozinho reabrir a ADR.

## Definição de Pronto (DoD)

- [ ] Todos os CAs (1 a 9) marcados com evidência.
- [ ] ADR-018 em `status: accepted` (CA-8).
- [ ] Runbooks de backend e Flutter criados em `epics/EPIC-010-.../runbook-refactor-*.md`.
- [ ] Scripts de validação temporários apagados ou movidos para `tests/Unit/`.
- [ ] `index.json` atualizado: STORY-069 status `done`, ADR-018 status `accepted`.
- [ ] Notas do agente preenchidas.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Em resumo:

1. **Ao iniciar:** edite o frontmatter desta estória: `status: in_progress`, `owner_agent: <sua sessão>`, `updated_at: <hoje>`. Atualize `index.json`.
2. **Durante:** valide empiricamente cada CA — não responda "deve funcionar" sem rodar. ADR-018 atualizada na medida em que validações fecham.
3. **Se travar:** edite frontmatter para `status: blocked`. Descreva bloqueio. Nunca decida sozinho reabrir ADR.
4. **Ao terminar:** preencha "Notas do agente", marque `status: in_review`, atualize `index.json`, abra PR. PO aceita ADR no chat ou via PR — sem aceite, status fica em `in_review`.

## Notas do agente (preenchido durante/após execução)

### Decisões tomadas
- <data> — <decisão local>

### Descobertas
- <data> — <surpresa, gotcha, item de cuidado para STORY-070/071>

### Bloqueios encontrados
- <data> — <bloqueio> — <como foi resolvido ou está aberto>

### Evidências por CA
- CA-1: <link/output>
- CA-2: <link/output>
- CA-3: <link/output> — caminho escolhido: <a/b/c>
- CA-4: <link/output> — premissa "zero produção" confirmada? <sim/não>
- CA-5: `runbook-refactor-backend.md` — <link>
- CA-6: `runbook-refactor-flutter.md` — <link>
- CA-7: impacto em `score_breakdown` — <sim/não> + caminho proposto
- CA-8: ADR-018 `accepted` em <data> por <quem>, forma do aceite: <chat/PR>
- CA-9: estimativa atualizada — STORY-070: <M/L>, STORY-071: <M/L>

### Cobertura final
- Unitários: <%> (apenas se script de UUIDv7 virou test)
- E2E: N/A (esta é spike)

### Links de evidência
- PR: <url>
- ADR-018 atualizada: <commit>
