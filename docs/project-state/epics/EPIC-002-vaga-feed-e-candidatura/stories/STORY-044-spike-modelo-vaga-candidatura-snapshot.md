---
story_id: STORY-044
slug: spike-modelo-vaga-candidatura-snapshot
title: Spike Arquiteto — modelo de Vaga + Candidatura + snapshot de edição material (PDR-009)
epic_id: EPIC-002
sprint_id: SPRINT-2026-W27
type: spike
target_role: arquiteto
requires_design: false
design_screen_id: null
status: in_review
owner_agent: claude-opus-4-8-programador-2026-06-02
created_at: 2026-06-01
updated_at: 2026-06-02
estimated_session_size: M
produces_idr: null  # produz ADR (não IDR) — decisão de modelo é arquitetural
---

# STORY-044 — Spike Arquiteto: modelo Vaga + Candidatura + snapshot PDR-009

> **Para o agente que vai executar:** esta é a estória que destrava todo o EPIC-002. Sem ela, não há onde escrever vaga nem onde aceitar candidatura. Leia `docs/especificacao/domain/vaga.md`, `domain/candidatura.md` e `PDR-009` por completo antes de propor o modelo. O entregável é **ADR aceita** + migrações Laravel rodando em homolog — não há UI nesta estória.

## Contexto (por que esta estória existe)

O EPIC-001 fechou o funil de identidade (usuários `ativo` em homolog com RBAC vivo, audit log imutável, AceiteEletronico imutável). O EPIC-002 entrega o **primeiro encontro** entre contratante e profissional: vaga publicada → feed → candidatura → painel de candidatos. Para isso existir, o banco precisa de Vaga, Candidatura, e o mecanismo de snapshot de edição material que PDR-009 exige (candidatura precisa ver o "antes" e o "depois" e decidir manter ou retirar). Sem ADR cobrindo o modelo, nenhuma estória de implementação pode começar.

- Épico: `epics/EPIC-002-vaga-feed-e-candidatura/epic.md`
- Documentos canônicos a ler ANTES de codificar:
  - `docs/especificacao/domain/vaga.md` (inteiro)
  - `docs/especificacao/domain/candidatura.md` (inteiro)
  - `docs/project-state/decisions/pdr/PDR-009-edicao-de-vaga-pos-candidatura.md`
  - `docs/project-state/decisions/pdr/PDR-005-avaliacao-reciproca-obrigatoria.md`
  - `docs/project-state/decisions/adr/ADR-009-modelo-de-dados-identidade-epic-001.md` (padrão de modelagem do projeto)
  - `docs/project-state/decisions/adr/ADR-000-postgresql-banco-principal.md`

## O quê (objetivo desta estória)

Produzir **ADR-013 (proposed → accepted)** que fixa o modelo de dados Postgres para Vaga + Candidatura + VagaVersao (snapshot PDR-009) + os estados/transições; e materializar o modelo via **migrações Laravel reversíveis** rodando verdes em homolog (CI + `migrate` + `migrate:rollback`).

## Por quê (valor para o usuário)

Sem este modelo, não há ranqueamento por match (EPIC-002 entregável central), não há edição com notificação (PDR-009), não há gate de candidatura (PDR-005). Todo o resto do EPIC-002 depende deste spike.

## Critérios de aceite

- [ ] **CA-1:** ADR-013 escrita em `decisions/adr/ADR-013-modelo-vaga-candidatura-snapshot.md` cobrindo: tabelas (`vagas`, `vaga_versoes`, `candidaturas`), colunas com tipo/constraint, FKs, índices (em particular o índice que sustenta p95 ≤ 800ms do feed com 1k vagas — citar `EXPLAIN`), estados/transições, política de snapshot (o que entra em `vaga_versoes` no momento da edição material).
- [ ] **CA-2:** ADR fixa explicitamente os 6 campos materiais de PDR-009 (`funcao`, `data_inicio`, `data_fim`, `valor`, `posicoes`, `observacoes`, `localizacao`) — alteração em qualquer um dispara snapshot + estado `pendente_revisao_apos_edicao` nas candidaturas pendentes.
- [ ] **CA-3:** Migrações Laravel `2026_06_*_create_vagas_table.php`, `..._create_vaga_versoes_table.php`, `..._create_candidaturas_table.php` criadas com `up()` e `down()` simétricos; `php artisan migrate` e `php artisan migrate:rollback` exercidos com sucesso em homolog (quita F-NB-1 do EPIC-000 conforme aprendizado da W23/W25).
- [ ] **CA-4:** Estados das tabelas via enum Postgres (não `varchar` livre): `vaga_estado` (`aberta`, `fechada`, `cancelada`), `candidatura_estado` (`pendente`, `aprovada`, `retirada`, `pendente_revisao_apos_edicao`, `retirada_por_edicao`, `recusada`). Transições inválidas bloqueadas por trigger Postgres ou regra explícita no Eloquent (decisão do Arquiteto, registrada na ADR).
- [ ] **CA-5:** Constraints duros validam invariantes-chave: `vagas.posicoes >= 1`, `vagas.data_fim > vagas.data_inicio`, `candidaturas.profissional_id` é único por `vaga_id` (não pode candidatar 2× na mesma vaga), `vaga_versoes` é append-only (trigger bloqueia UPDATE/DELETE — mesmo padrão de imutabilidade da AceiteEletronico, ADR-010).
- [ ] **CA-6:** Audit log (`audit_logs` herdado do EPIC-001) registra: criação de vaga, edição material de vaga, cancelamento de vaga, criação de candidatura, aprovação de candidatura, retirada por edição. Lista exata dos eventos registrada na ADR.
- [ ] **CA-7:** Seed mínimo (`database/seeders/VagasSeeder.php`) cria 1 contratante seed (reaproveita seed do EPIC-001), 5 vagas em estados variados (3 abertas, 1 fechada, 1 cancelada) com `funcao` distinta. Seed roda em homolog e popula sem erro.
- [ ] **CA-8:** Microbenchmark inicial: `EXPLAIN ANALYZE` da query candidata a sustentar o feed do profissional (filtro por função primária + raio + `aberta` + data futura) com 1k vagas seedadas (script `database/seeders/VagasStressSeeder.php` separado, executável só em dev/homolog) entrega < 100ms na ADR. Não exige tuning final — só evidência de que o índice escolhido funciona; o tuning real fica para STORY-048.
- [ ] **CA-9:** Documento de decisão lista o que **não** foi resolvido nesta estória e cabe no spike de Match (STORY-045): estratégia de cálculo do score (on-demand vs. cache), eventos de telemetria (`feed:vaga_apresentada`, `match:candidatura_*`), shape do payload de breakdown.
- [ ] **CA-10:** ADR-013 termina em `status: accepted` (após revisão do PO em chat) antes do merge da estória. Sem aceitação, status fica `proposed` e a estória fica `in_review`.

## Fora de escopo

- Algoritmo de match e estratégia de cálculo do score → STORY-045 (spike próprio).
- Endpoints HTTP de Vaga/Candidatura → ficam para as estórias de implementação (046+).
- UI no WebApp ou Backoffice.
- Tabela de notificações → vive em STORY-053 (notificações da candidatura).

## Padrões de qualidade exigidos

Esta estória segue os padrões em `docs/skills/po/references/quality-standards.md`. Resumo aplicável:

- Migrações reversíveis testadas (`down()` exercido em homolog — quitar F-NB-1).
- Testes de migração no CI (PostgreSQL real, não SQLite).
- Sem código de produção sem teste — modelos Eloquent novos têm testes unitários cobrindo invariantes (>= 95% nos modelos por serem núcleo).
- ADR escrita em prosa curta seguindo `docs/skills/arquiteto/templates/adr.md`.

## Dependências

- **Bloqueada por:** nenhuma (epic anterior fechado).
- **Bloqueia:** STORY-045 (spike Match), STORY-046, STORY-047, STORY-048, STORY-050, STORY-051, STORY-052 (todas as estórias de implementação do EPIC-002).
- **Pré-requisitos de ambiente:** banco homolog operante (EPIC-000 entregou), padrão de migração ativo (ADR-009).

## Decisões já tomadas (não as reabra)

- ADR-000: Postgres como banco principal.
- ADR-009: padrões de modelagem do projeto (uuid v7 como PK pública, audit log imutável por trigger, criptografia em repouso para campos sensíveis).
- ADR-010: imutabilidade de aceite — usar o mesmo padrão de trigger bloqueando UPDATE/DELETE para `vaga_versoes`.
- PDR-005: avaliação recíproca bloqueia candidatura nova e publicação nova — o modelo deve ter como gate.
- PDR-009: edição material dispara snapshot + revisão; campos materiais fixados na decisão.

## Liberdade técnica do agente

Você (arquiteto) decide:
- Nome exato das tabelas e colunas (sugestão acima é orientativa).
- Estratégia exata do snapshot (tabela espelho vs. JSON `vaga_versoes.snapshot jsonb`).
- Índices específicos e estratégia de partição (se valer a pena agora).
- Como modelar `vaga_versoes` (uma linha por versão vs. histórico inline em `vagas`).

Você NÃO decide:
- Banco (Postgres por ADR-000).
- Imutabilidade de snapshot (PDR-009).
- Campos materiais (PDR-009).
- Estados/transições do domínio (estão em `vaga.md`/`candidatura.md`).

## Definição de Pronto (DoD)

- [ ] ADR-013 `accepted`.
- [ ] Migrações criadas, `migrate` + `migrate:rollback` verdes em homolog.
- [ ] Modelos Eloquent + testes unitários com cobertura ≥ 95%.
- [ ] Seed mínimo + stress seed rodando.
- [ ] Microbenchmark documentado na ADR.
- [ ] CI verde no PR.
- [ ] `index.json` atualizado: status = `done`; nova entrada em `decisions[]` para ADR-013.
- [ ] "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Em particular: ao terminar, marque `status: in_review` e abra PR; PO revisa a ADR antes de mover para `done`.

## Notas do agente (preenchido durante/após execução)

### Plano (registrado antes de codar — 2026-06-02)

**Documentos lidos:** ADR-013 (accepted, modelo desta estória), ADR-009 (padrão de modelagem), ADR-010 (imutabilidade por trigger+REVOKE), PDR-009, PDR-005, `domain/vaga.md`, `domain/candidatura.md`, `non-functional.md` (p95 feed), database-discipline + testing-discipline da skill. Código existente: `admin_audit_log`/templates (padrão de migração + trigger), `AceiteEletronico`/`User`/`Funcao` (padrão de model), `AuditLogTest`/`UserModelTest` (padrão de teste), `UserFactory`, seeders.

**Entendimento (minhas palavras):** materializar a ADR-013 em 4 migrações reversíveis (`vagas`, `vaga_versoes`, `candidaturas`, `audit_logs`) com enums Postgres nativos (`vaga_estado`, `candidatura_estado`), invariantes duras no banco (CHECKs + UNIQUE + trigger append-only), modelos Eloquent com máquina de estados no domínio (transições válidas/proibidas), seed mínimo (5 vagas em estados variados) e stress seed (1k vagas) para o `EXPLAIN ANALYZE < 100ms` do feed. Sem UI, sem endpoints, sem score de match (STORY-045).

**Mapeamento CA → testes (TDD — vermelho antes do código):**
- CA-3 (migrações reversíveis): `MigrationVagaSchemaTest` — `migrate` cria tabelas/colunas/enums; `migrate:rollback` exercido em homolog (manual, registrado em evidência).
- CA-4 (enums + transições): `VagaModelTest` (feliz: aberta→fechada/cancelada; proibido: fechada→cancelada; borda: fechar ao preencher última posição), `CandidaturaModelTest` (pendente→aprovada/retirada/revisão; revisão→pendente/retirada_por_edicao; proibido: aprovada→pendente). Enum nativo barra valor inválido (`*SchemaTest`).
- CA-5 (constraints): `VagaConstraintsTest` — `posicoes>=1`, `data_fim>data_inicio`, `posicoes_preenchidas BETWEEN 0 AND posicoes`, `UNIQUE(vaga_id,profissional_id)` em candidaturas; `VagaVersaoImutabilidadeTest` + `AuditLogImutabilidadeTest` (UPDATE/DELETE lançam exceção — trigger).
- CA-6 (eventos audit): `AuditLogModelTest` registra os 6 eventos de domínio (action/target/payload); lista canônica na ADR-013 §Decisão 5.
- CA-7 (seed mínimo): `VagasSeederTest` — 5 vagas (3 aberta, 1 fechada, 1 cancelada) com funções distintas + 1 contratante seed.
- CA-8 (microbenchmark): `VagasStressSeeder` 1k vagas; `EXPLAIN ANALYZE` da query do feed usando `idx_vagas_feed` < 100ms — número registrado na ADR-013 §Plano de verificação.

**Dúvidas:** nenhuma — ADR-013 fixou o modelo; liberdade do agente é só estrutura local (nomes de método da state-machine, factories, organização de testes).

**Decisão de escopo local:** modelos e migrações vivem em `apps/api` (dono do schema real — ADR-009/memória). `admin` não recebe réplica nesta estória (sem fluxo de backoffice de vaga até EPIC-003).

### Decisões tomadas
- Estados via **enum nativo Postgres** (`vaga_estado`, `candidatura_estado`) + **state-machine no domínio** (enum PHP `canTransitionTo` + `Vaga::transitionTo`/`Candidatura::transitionTo` que lançam `DomainException`). Trigger reservado só p/ imutabilidade (ADR-013 Decisão 2).
- **Snapshot `jsonb` append-only** em `vaga_versoes`, imutável por trigger + REVOKE (padrão ADR-010).
- **`audit_logs` geral** (ator = qualquer usuário) irmão do `admin_audit_log`, sem reabrir ADR-009 (Decisão 5).
- **Geo sem PostGIS**: `lat`/`lng` na vaga + índice parcial `idx_vagas_feed (funcao_id, data_inicio) WHERE estado='aberta'` + btree `(lat,lng)` p/ bbox.
- Modelos/migrações vivem em `apps/api` (dono do schema). Sem réplica no `admin` (sem fluxo de backoffice de vaga até EPIC-003).

### Descobertas
- **Gotcha Laravel+Postgres:** `RefreshDatabase`/`migrate:fresh` dropa tabelas mas **não** tipos enum nativos → 2ª migração falha com "type already exists". Fix sistêmico: `protected bool $dropTypes = true;` no `TestCase` base (passa `--drop-types`). Vale para todo enum nativo futuro do projeto.
- `jsonb` do Postgres **não preserva ordem das chaves** → asserção de payload usa `toEqual` (==), não `toBe` (idêntico ordenado).

### Bloqueios encontrados
- Nenhum.

### IDRs criados
- Nenhum (decisões estruturais já cobertas pela ADR-013; o `$dropTypes` no TestCase é convenção local de teste, não decisão transversal nova — registrada aqui e no comentário do código).

### Cobertura final (api — suíte completa)
- **Total: 93,1%** (gate `--min=80` ✓). **305 testes passando** (899 asserções).
- Núcleo novo **100%**: `VagaEstado`, `CandidaturaEstado`, `Vaga`, `Candidatura`, `VagaVersao`, `AuditLog`.
- `VagasStressSeeder` excluído da cobertura (harness de benchmark dev/homolog, não lógica de negócio — `phpunit.xml`, mesmo critério dos stubs Fortify).
- E2E: n/a (spike de modelo, sem fluxo de usuário/FE).

### Mapeamento CA → teste (todos verdes)
- **CA-3** (migrações reversíveis): `VagaSchemaTest` (tabelas/colunas) + `migrate:rollback --step=4` e `migrate` exercitados em `turni_test` (2026-06-02, sem erro).
- **CA-4** (enums nativos + transições): `VagaSchemaTest` (`pg_enum` rótulos exatos `vaga_estado`/`candidatura_estado`), `VagaEstadoTest`, `CandidaturaEstadoTest`, `VagaModelTest`, `CandidaturaModelTest` (transições válidas/proibidas).
- **CA-5** (invariantes): `VagaConstraintsTest` (`posicoes>=1`, `data_fim>data_inicio`, range de `posicoes_preenchidas`, UNIQUE candidatura), `ImutabilidadeTest` (UPDATE/DELETE em `vaga_versoes`/`audit_logs` lançam exceção; UNIQUE `versao`).
- **CA-6** (eventos audit): `AuditLogDominioTest` (6 eventos do contrato c/ ator/alvo/payload).
- **CA-7** (seed mínimo): `VagasSeederTest` (5 vagas; 3 abertas/1 fechada/1 cancelada; funções distintas; idempotência).
- **CA-8** (microbenchmark): `FeedQueryTest` (correção do predicado) + `EXPLAIN ANALYZE` real: `Index Scan using idx_vagas_feed`, **0,042 ms** sobre 1.000 vagas.

### Links de evidência
- Commits (TDD — main): `de35ce3` docs(ADR accepted), `b90f637` test(vermelho), + commit feat(verde).
- Suíte: `make test-api` → 305 passed, cobertura 93,1%.
- EXPLAIN/rollback: exercitados em `turni_test` (Postgres real) em 2026-06-02 — resultados na ADR-013 §Plano de verificação.
- Deploy de homologação: pendente push manual (workflow do projeto: commit direto na main + push manual).
