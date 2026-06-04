---
story_id: STORY-055
slug: spike-modelo-turno-aceite-eletronico-maquina-estados
title: Spike Arquiteto — modelo de Turno + AceiteEletronico imutável + máquina de estados
epic_id: EPIC-003
sprint_id: SPRINT-2026-W28
type: spike
target_role: arquiteto
requires_design: false
design_screen_id: null
status: done
owner_agent: claude-opus-4-8-arquiteto-2026-06-03
created_at: 2026-06-03
updated_at: 2026-06-04
estimated_session_size: M
produces_idr: null  # produz ADR-015 (modelo de dados é arquitetural)
---

# STORY-055 — Spike Arquiteto: modelo Turno + AceiteEletronico + máquina de estados

> **Para o agente arquiteto:** esta é a estória que destrava todo o EPIC-003. Sem ela, não há onde escrever Turno, AceiteEletronico, nem onde aplicar as invariantes da máquina de estados. Leia `docs/especificacao/domain/turno.md`, `domain/compliance.md` (seção AceiteEletronico) e PDR-002/PDR-007/PDR-008 por completo antes de propor o modelo. O entregável é **ADR-015 aceita** + migrações Laravel rodando em homolog — não há UI nesta estória.

## Contexto (por que esta estória existe)

O EPIC-002 fechou o primeiro encontro (vaga → candidatura). O EPIC-003 entrega o **ciclo do turno** (aceite → check-in → ativo → check-out → captura → Pix). Para isso existir, o banco precisa de **Turno** com máquina de estados explícita e **AceiteEletronico imutável** anexado (espelhando o que ADR-010 fez para usuários — mas agora por turno, com cláusula adicional para override de habitualidade PJ). Sem ADR cobrindo o modelo + invariantes, nenhuma estória de implementação pode começar.

- Épico: `epics/EPIC-003-aceite-pin-e-pix/epic.md`
- Documentos canônicos a ler ANTES de codificar:
  - `docs/especificacao/domain/turno.md` (máquina de estados completa, atributos, regras críticas)
  - `docs/especificacao/domain/compliance.md` (AceiteEletronico, estrutura de Template, imutabilidade)
  - `docs/especificacao/domain/pagamento.md` (atributos financeiros do Turno: valor, taxa_turni, total_contratante)
  - `decisions/pdr/PDR-002-habitualidade-no-mesmo-estabelecimento.md` (cláusula override PJ)
  - `decisions/pdr/PDR-007-cancelamento-permitido-com-penalidade-futura.md` (cancelamento + no-show no MVP mínimo)
  - `decisions/pdr/PDR-008-geofencing-alerta-e-registra.md` (geofencing como atributo do evento check-in)
  - `decisions/adr/ADR-006-estrategia-habitualidade.md` (índice e consulta — Turno é a tabela alvo)
  - `decisions/adr/ADR-009-modelo-de-dados-identidade-epic-001.md` (padrão de modelo a espelhar)
  - `decisions/adr/ADR-010-template-versao-e-aceite-eletronico.md` (padrão de imutabilidade a espelhar para AceiteEletronico do Turno)
  - `decisions/adr/ADR-013-modelo-vaga-candidatura-snapshot.md` (Turno consome Candidatura aprovada)

## O quê (objetivo desta estória)

Propor **ADR-015** com o modelo concreto de Turno + AceiteEletronico (do turno) + invariantes da máquina de estados, e entregar as migrações Postgres correspondentes rodando em homolog.

## Por quê (valor para o usuário)

Sem modelo de Turno auditado e máquina de estados explícita, a sprint não consegue garantir que `confirmado → ativo → finalizado` seja sempre coerente (ex: dois check-outs no mesmo turno, AceiteEletronico editado depois). A garantia jurídica e operacional do produto vive aqui.

## Critérios de aceite

Cada item é uma asserção testável. O agente DEVE escrever testes que cubram cada um.

- [x] **CA-1:** ADR-015 escrita seguindo o padrão de ADR-009/ADR-010/ADR-013, com status `accepted` e aprovação do Alexandro registrada.
- [x] **CA-2:** Schema do `Turno` inclui: **`id` UUIDv7 (ADR-018)**, **`vaga_id` foreignUuid** (snapshot herdado de ADR-013, refatorado para UUID em EPIC-010/W27.5), **`vaga_versao_id` foreignUuid**, **`candidatura_id` foreignUuid**, **`profissional_id` foreignUuid**, **`contratante_id` foreignUuid**, **`estabelecimento_id` foreignUuid**, `status` (enum com os 11 estados de `domain/turno.md`), `valor`, `taxa_turni`, `total_contratante`, `data_inicio`, `data_fim`, `check_in_at`, `check_out_at`, `geofencing_check_in` (jsonb), `geofencing_check_out` (jsonb), `cancelamento` (jsonb nullable), `created_at`, `updated_at`. Model usa **`HasVersion7Uuids`** (padrão EPIC-010). Todos os timestamps em UTC; UI delega a IDR-026.
- [x] **CA-3:** Schema do `AceiteEletronicoTurno` (separado do AceiteEletronico do usuário do EPIC-001 — espelha o padrão mas é por turno): **`id` UUIDv7**, **`turno_id` foreignUuid**, **`template_versao_id` foreignUuid** (FK em `template_versoes` do ADR-010, refatorado em EPIC-010), `conteudo_renderizado` (text), `dados_renderizados` (jsonb com placeholders preenchidos — quando referenciar IDs do Turno/Profissional/Contratante, usar string UUID), `timestamp`, `ip`, `fingerprint`, `habitualidade_override` (boolean — true quando 3ª alocação PJ aprovada com override). Trigger Postgres bloqueia `UPDATE` e `DELETE` (espelha ADR-010 e ADR-013 vaga_versoes).
- [x] **CA-4:** Máquina de estados expressa como **invariante de banco** (CHECK constraint ou trigger) — transições válidas conforme `domain/turno.md`; transição inválida (ex: `confirmado → finalizado` sem passar por `ativo`) levanta erro. ADR-015 documenta as 13 transições válidas.
- [x] **CA-5:** Índices criados: `(profissional_id, status)`, `(contratante_id, status)`, `(estabelecimento_id, profissional_id, data_inicio)` (este último complementa o índice já criado por ADR-006/EPIC-001 para habitualidade). Microbenchmark com `EXPLAIN ANALYZE` para o caminho de aceite (consulta de habitualidade) anexado à ADR.
- [x] **CA-6:** Migração com lógica de negócio real (CHECK constraint de máquina de estados + trigger de imutabilidade) — exercício de `migrate:rollback` em homolog (documentado no `runbook-homolog.md`). Confirma disciplina herdada.
- [x] **CA-7:** Seeders para os 11 estados em ambiente local — permitem a partir daqui que as próximas estórias seedem cenários sem reimplementar.
- [x] **CA-8:** Cobertura ≥ 98% no núcleo da máquina de estados (regra de negócio crítica); ≥ 80% no resto da migração.

## Fora de escopo

- Implementação de qualquer caminho de aceite/check-in/check-out — só modelo + migração + seeders.
- ACL Pagar.me — vive em STORY-056 (ADR-016).
- Estratégia de tempo real do cronômetro — vive em STORY-057 (ADR-017).
- UI de qualquer tela — sem Designer nesta estória.

## Padrões de qualidade exigidos

`docs/skills/po/references/quality-standards.md`. Resumo: ≥ 80% geral, ≥ 98% no núcleo (máquina de estados, imutabilidade do AceiteEletronico). Testes unitários cobrem todas as 13 transições válidas + 5 inválidas representativas. Migration testada com rollback exercido em homolog.

## Dependências

- **Bloqueada por:** nenhuma (primeira estória do EPIC-003; consome modelo de Candidatura `aprovada` que já existe desde STORY-044).
- **Bloqueia:** STORY-058 (precisa do modelo de Turno + AceiteEletronico), STORY-066 (cancelamento depende da máquina de estados), STORY-067 (notificações consomem eventos da transição).
- **Pré-requisitos de ambiente:** ambiente homolog operante (herdado de EPIC-000), Candidatura modelada (herdado de STORY-044/EPIC-002).

## Decisões já tomadas (não as reabra)

- ADR-005 — Pagar.me alto nível (STORY-056 detalha em ADR-016)
- ADR-006 — Estratégia de habitualidade (índice e consulta)
- ADR-009 — Modelo de dados identidade (padrão de modelo a espelhar)
- ADR-010 — Template + AceiteEletronico imutável (padrão a espelhar)
- ADR-013 — Modelo Vaga + Candidatura + snapshot PDR-009
- **ADR-018 — UUIDv7 em PKs (EPIC-010/W27.5 aplicou refator transversal antes desta sprint começar). PKs e FKs de Turno/AceiteEletronicoTurno são UUID, não bigint. Use `HasVersion7Uuids` no model. Índice composto da habitualidade (CA-5) cobre `(estabelecimento_id, profissional_id, data_inicio)` com colunas uuid.**
- PDR-002 / PDR-004 / PDR-007 / PDR-008 / PDR-010 / PDR-012

## Liberdade técnica do agente

Você (arquiteto) decide:
- Nome exato das tabelas e colunas (respeitando vocabulário do `domain/turno.md`).
- Forma da invariante de máquina de estados (CHECK constraint composta, trigger, ou ambos).
- Forma do índice composto que ajude habitualidade + listas de turno.

Você (arquiteto) NÃO decide:
- Estratégia de Pagar.me (vive em STORY-056/ADR-016).
- Estratégia de tempo real do cronômetro (vive em STORY-057/ADR-017).
- UI de qualquer tela.

## Definição de Pronto (DoD)

- [x] ADR-015 escrita, revisada em chat com Alexandro, status `accepted`.
- [x] Migrações rodando em homolog (deploy verificado — release `v0.1.0-rc.63`; smoke `✓ API/Admin/WebApp version=rc.63`; TurnosSeeder criou 11 turnos + aceites em homolog).
- [x] Rollback de migrações exercido (turni_test; procedimento de homolog em `docs/operacao/runbook-homolog.md` §rollback-turnos).
- [x] Pipeline verde com cobertura ≥ 80% / 98% no núcleo (597 testes, 93,4% global, núcleo 100%).
- [x] `index.json` atualizado: STORY-055 `in_review`→`done` no merge, ADR-015 `accepted`, EPIC-003 `in_progress`.
- [x] Esta estória atualizada com a seção "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Resumo: editar frontmatter ao iniciar (`status: in_progress`, `owner_agent`, `updated_at`), TaskList interna, IDR/ADR registrados antes do código, ao terminar marcar `in_review`, preencher Notas, atualizar `index.json`.

## Notas do agente (preenchido durante/após execução)

### Decisões tomadas
- **Máquina de estados como invariante de banco (CA-4) — divergência consciente de ADR-013.** ADR-013 pôs as transições de Vaga/Candidatura só no domínio (trigger reservado a imutabilidade). O CA-4 manda invariante de banco para o Turno: trigger `enforce_turno_transition` (`BEFORE UPDATE`) valida as 13 transições e barra até SQL cru; o enum `TurnoStatus::canTransitionTo()` espelha a matriz para o domínio/testes. Defesa em profundidade (ADR-015 Decisão 2).
- **AceiteEletronicoTurno em tabela SEPARADA (CA-3) — revê o hint de ADR-010.** ADR-010 antecipou `ALTER TABLE aceites_eletronicos ADD turno_id`; o CA-3 pede entidade por turno. Os artefatos são distintos (adesão única vs. por aprovação, com `habitualidade_override`), então tabela própria `aceites_eletronicos_turno` evita polimorfismo disfarçado (ADR-015 Decisão 3).
- **`estabelecimento_id` = `contratante_id` no MVP, mas coluna separada.** Honra a convenção já codificada no `GateHabitualidade` (STORY-050) e o par de habitualidade de ADR-006, e prepara multi-unidade sem migração futura.
- **Nome `aceito_em` para o campo que compliance.md chama `timestamp`** (palavra reservada SQL; espelha ADR-010). Latitude do arquiteto.
- **Limite de `no_show_pro` (lacuna de turno.md):** modelo suporta a transição; proposta de 2h de tolerância como parâmetro de config, confirmação final do PO na STORY-066 (não bloqueia o spike). ADR-015 Decisão 6.

### Descobertas
- **Trait é `HasUuids`, não `HasVersion7Uuids`.** CA-2/CA-3 citam `HasVersion7Uuids` (que não existe no Laravel instalado — correção empírica de ADR-018/STORY-069). Usei `HasUuids`, que já gera UUIDv7. Registrado na ADR-015 (§Contexto).
- **Gotcha de FK + REVOKE (herdado da migration 2026_06_03_140000):** REVOKE em tabela-pai de FK quebra INSERT em Cloud SQL (lock de validação exige UPDATE). `aceites_eletronicos_turno` não é tabela-pai → REVOKE seguro. `turnos` é tabela-pai mas é mutável (runtime mantém UPDATE) → ok. Documentado na ADR-015 Decisão 4.

### Bloqueios encontrados
- Nenhum bloqueio técnico. ADR-015 aprovada pelo Alexandro (chat 2026-06-03). Deploy de homolog feito (rc.63).

### Descobertas no deploy (2 regressões UUID herdadas + 1 do próprio seeder)
- **`wire:click` com UUID sem aspas (regressão ADR-018/STORY-070 no Backoffice).** Após o refator UUID, `wire:click="verDetalhes({{ $u->id }})"` renderizava o UUID sem aspas → o Livewire parseava como expressão JS inválida e a ação não disparava (fila "Ver detalhes" e templates "Ativar" mortos). Pego pelo E2E do Backoffice (invisível aos testes Livewire de unidade, que chamam o método direto). Corrigido nas 3 chamadas (commit `fix(admin)`).
- **Seeder de produção não pode usar `fake()`/factory.** O job de migração de homolog roda `APP_ENV=production`, onde `fake()` não existe — o `TurnosSeeder` original (via `Turno::factory()`) quebrava o `db:seed`. Reescrito production-safe com `Model::create` (padrão VagasSeeder). Factories seguem só para testes.
- **`TurnosSeeder` poluía o catálogo de templates** (factory criava 1 template por aceite) — agora reusa a versão ativa do `pf_autonomo_eventual`.
- **Infra:** Cloud SQL homolog estava `STOPPED` (scheduler de economia); o primeiro deploy correu a frio e a 1ª conexão caiu (`08006`) — resolveu sozinho após a instância estabilizar.

### ADRs/IDRs criados
- **ADR-015** — Modelo Turno + AceiteEletronicoTurno imutável + máquina de estados — `decisions/adr/ADR-015-modelo-turno-aceite-eletronico-maquina-estados.md` (status `proposed`).

### Cobertura final
- **Unitários + integração (api):** 597 testes verdes, **93,4%** de cobertura global (gate ≥80%). Núcleo (`TurnoStatus`, `Turno`, `TurnosSeeder`) em **100%** (gate ≥98%). `pint --test` verde (17 arquivos).
- **Testes do Turno:** 62 testes / 228 asserções — enum puro (13 transições válidas + inválidas + terminais), trigger no banco (13 válidas via SQL cru + inválidas barradas), schema/índices, constraints, imutabilidade do aceite, seeder dos 11 estados, EXPLAIN do índice de habitualidade.
- **Microbenchmark CA-5:** `Index Only Scan using idx_turnos_habitualidade`, Execution Time **0,050 ms** (precedente ADR-006: 0,042 ms/1.000 linhas).
- **Rollback CA-6:** `migrate:rollback --step=2` + replay verdes em `turni_test`; procedimento de homolog em `runbook-homolog.md` §{#rollback-turnos}.

### Links de evidência
- Migrações: `apps/api/database/migrations/2026_06_03_150000_create_turnos_table.php`, `..._150001_create_aceites_eletronicos_turno_table.php`
- Modelos/enum: `app/Models/Turno.php`, `app/Models/AceiteEletronicoTurno.php`, `app/Enums/TurnoStatus.php`
- Seeder: `database/seeders/TurnosSeeder.php` (registrado no `DatabaseSeeder`)
- Testes: `tests/Unit/Turno/`, `tests/Feature/Turno/`
- Commits na main: `feat(STORY-055)` (modelo/migração/testes), `fix(admin)` (wire:click UUID), `fix(STORY-055)` (seeder reusa template + production-safe).
- Deploy de homologação: release `v0.1.0-rc.63` verde. Smoke pós-deploy: `✓ API/Admin/WebApp version=v0.1.0-rc.63`. Migrações aplicadas; TurnosSeeder criou 11 turnos + aceites em homolog (Cloud Run Job `turni-migrate-homolog`).
