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
status: ready
owner_agent: null
created_at: 2026-06-03
updated_at: 2026-06-03
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

- [ ] **CA-1:** ADR-015 escrita seguindo o padrão de ADR-009/ADR-010/ADR-013, com status `accepted` e aprovação do Alexandro registrada.
- [ ] **CA-2:** Schema do `Turno` inclui: `id`, `vaga_id`, `vaga_versao_id` (snapshot herdado de ADR-013), `candidatura_id`, `profissional_id`, `contratante_id`, `estabelecimento_id`, `status` (enum com os 11 estados de `domain/turno.md`), `valor`, `taxa_turni`, `total_contratante`, `data_inicio`, `data_fim`, `check_in_at`, `check_out_at`, `geofencing_check_in` (jsonb), `geofencing_check_out` (jsonb), `cancelamento` (jsonb nullable), `created_at`, `updated_at`. Todos os timestamps em UTC; UI delega a IDR-026.
- [ ] **CA-3:** Schema do `AceiteEletronicoTurno` (separado do AceiteEletronico do usuário do EPIC-001 — espelha o padrão mas é por turno): `id`, `turno_id`, `template_versao_id` (FK em `template_versoes` do ADR-010), `conteudo_renderizado` (text), `dados_renderizados` (jsonb com placeholders preenchidos), `timestamp`, `ip`, `fingerprint`, `habitualidade_override` (boolean — true quando 3ª alocação PJ aprovada com override). Trigger Postgres bloqueia `UPDATE` e `DELETE` (espelha ADR-010 e ADR-013 vaga_versoes).
- [ ] **CA-4:** Máquina de estados expressa como **invariante de banco** (CHECK constraint ou trigger) — transições válidas conforme `domain/turno.md`; transição inválida (ex: `confirmado → finalizado` sem passar por `ativo`) levanta erro. ADR-015 documenta as 13 transições válidas.
- [ ] **CA-5:** Índices criados: `(profissional_id, status)`, `(contratante_id, status)`, `(estabelecimento_id, profissional_id, data_inicio)` (este último complementa o índice já criado por ADR-006/EPIC-001 para habitualidade). Microbenchmark com `EXPLAIN ANALYZE` para o caminho de aceite (consulta de habitualidade) anexado à ADR.
- [ ] **CA-6:** Migração com lógica de negócio real (CHECK constraint de máquina de estados + trigger de imutabilidade) — exercício de `migrate:rollback` em homolog (documentado no `runbook-homolog.md`). Confirma disciplina herdada.
- [ ] **CA-7:** Seeders para os 11 estados em ambiente local — permitem a partir daqui que as próximas estórias seedem cenários sem reimplementar.
- [ ] **CA-8:** Cobertura ≥ 98% no núcleo da máquina de estados (regra de negócio crítica); ≥ 80% no resto da migração.

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

- [ ] ADR-015 escrita, revisada em chat com Alexandro, status `accepted`.
- [ ] Migrações rodando em homolog (deploy verificado).
- [ ] Rollback de migrações exercido em homolog (registrado em `docs/operacao/runbook-homolog.md`).
- [ ] Pipeline verde com cobertura ≥ 80% / 98% no núcleo.
- [ ] `index.json` atualizado: STORY-055 `done`, ADR-015 `accepted`, EPIC-003 ainda `in_progress`.
- [ ] Esta estória atualizada com a seção "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Resumo: editar frontmatter ao iniciar (`status: in_progress`, `owner_agent`, `updated_at`), TaskList interna, IDR/ADR registrados antes do código, ao terminar marcar `in_review`, preencher Notas, atualizar `index.json`.

## Notas do agente (preenchido durante/após execução)

### Decisões tomadas
- 

### Descobertas
- 

### Bloqueios encontrados
- 

### ADRs/IDRs criados
- ADR-015 — Modelo Turno + AceiteEletronico imutável + máquina de estados — `decisions/adr/ADR-015-<slug>.md`

### Cobertura final
- Unitários: <%>
- E2E: <quantos cenários, link para evidência>

### Links de evidência
- PR:
- Pipeline:
- Deploy de homologação:
