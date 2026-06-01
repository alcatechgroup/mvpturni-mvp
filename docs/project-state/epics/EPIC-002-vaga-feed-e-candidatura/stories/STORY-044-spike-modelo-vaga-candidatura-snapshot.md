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
status: ready
owner_agent: null
created_at: 2026-06-01
updated_at: 2026-06-01
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

### Decisões tomadas
- 

### Descobertas
- 

### Bloqueios encontrados
- 

### IDRs criados
- 

### Cobertura final
- Unitários: 
- E2E: n/a (spike de modelo, sem fluxo de usuário)

### Links de evidência
- PR: 
- Pipeline: 
- Deploy de homologação: 
