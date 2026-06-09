---
story_id: STORY-083
slug: spike-arquiteto-modelo-eventos-gate
title: "Spike Arquiteto — modelo de avaliação + eventos de domínio + ponto do gate bloqueante (ADR-019)"
epic_id: EPIC-004
sprint_id: SPRINT-2026-W30
type: spike
target_role: arquiteto
requires_design: false
design_screen_id: null
status: done
owner_agent: claude-opus-4-8-arquiteto-2026-06-09
created_at: 2026-06-09
updated_at: 2026-06-09
estimated_session_size: M
produces_idr: ADR-019
---

# STORY-083 — Spike Arquiteto: modelo, eventos e ponto do gate (ADR-019)

> **Para o agente que vai executar:** carregue a skill `arquiteto`. Produza **ADR-019** (aceita pelo humano antes de qualquer implementação) e a **spec do fluxo** `docs/especificacao/flows/avaliacao-reciproca.md`. **Não implemente** — esta estória entrega decisão + spec. Disciplina W27/W28: decisão antes de implementação.

## Contexto (por que esta estória existe)

O EPIC-004 fecha o ciclo do turno com avaliação recíproca obrigatória (PDR-005), que alimenta XP/score/nível. Antes de codificar, três decisões arquiteturais precisam estar fixadas (o próprio `epic.md` as lista): (1) **modelo de dados** da avaliação; (2) **eventos de domínio** que disparam o fluxo e a atualização de XP; (3) **onde aplicar o gate bloqueante**. Implementar sem isso espalha decisão pelo código e gera retrabalho.

- Épico: `epics/EPIC-004-avaliacao-reciproca/epic.md`
- Spec de domínio: `docs/especificacao/domain/niveis-e-score.md` (XP/score/níveis/avaliação), `docs/especificacao/domain/turno.md`, `docs/especificacao/business-rules.md`.
- Base: PDR-005 (avaliação obrigatória), PDR-007 (penalidade futura — motor fora do MVP).

## O quê (objetivo desta estória)

Produzir **ADR-019** decidindo:
1. **Modelo de dados de avaliação**: tabela/entidade com estrelas (1–5, obrigatória), comentário (opcional), direção (contratante→profissional e profissional→contratante), linkage com o turno, timestamps; unicidade (1 avaliação por direção por turno).
2. **Eventos de domínio**: `turno_finalizado` → cria as duas pendências de avaliação; `avaliacao_recebida` → recalcula XP/score e avalia subida de nível. Mecanismo (event/listener Laravel, síncrono vs fila) coerente com ADR-017 (tempo real) e a infra de `queue:work`/`schedule:run` já provisionada (STORY-073).
3. **Ponto de aplicação do gate bloqueante**: onde barrar nova candidatura (profissional) e nova publicação (contratante) com avaliação pendente — middleware, decorator de service, ou regra no service layer — fail-secure e testável.
4. **Cálculo de XP/score/nível**: onde vive o motor (service), idempotência por evento, como o nível sobe automaticamente (500/1000/3000), tratamento de XP negativo (sem rebaixar — spec).

E escrever a **spec do fluxo** `flows/avaliacao-reciproca.md` (estados, transições, gatilhos, mensagens) — hoje inexistente.

## Por quê (valor para o usuário)

Garante que a avaliação recíproca nasça com modelo coerente e gate confiável — sem isso o ciclo não fecha e o XP/score não evolui, que é o coração da hipótese de qualidade do produto.

## Critérios de aceite

- [x] **CA-1:** ADR-019 registra o modelo de dados de avaliação (campos, unicidade por direção/turno, linkage) com justificativa e alternativas consideradas. → Decisão 1 (tabela `avaliacoes`, `UNIQUE(turno_id, direcao)`, Opção 1A vs 1B).
- [x] **CA-2:** ADR-019 decide os eventos de domínio (`turno_finalizado`, `avaliacao_recebida`), o mecanismo (síncrono/fila) e a idempotência do motor de XP/score. → Decisões 3 (eventos síncronos) e 4 (motor por recomputação idempotente).
- [x] **CA-3:** ADR-019 decide o ponto do gate bloqueante (camada + estratégia) fail-secure, aplicável aos dois papéis, com nota de testabilidade. → Decisão 5 (service layer, fail-secure, simétrico) + Plano de verificação.
- [x] **CA-4:** `flows/avaliacao-reciproca.md` escrito: estados/transições do fluxo, gatilhos, mensagens-chave, e como o gate se manifesta.
- [x] **CA-5:** ADR-019 `accepted` (aprovação do humano em 2026-06-09) e indexado em `index.json` (decisions.adr). Respeita ADR-015 (modelo Turno), ADR-007 (RBAC ortogonal ao gate), ADR-018 (UUIDv7 em PKs/FKs).
- [x] **CA-6:** Decisões abrem caminho claro para STORY-085 (modelo+motor; fronteira de quebra = evento `AvaliacaoRegistrada`) e STORY-086 (gate) — sem decisão de baixo nível em aberto.

## Fora de escopo

- Implementação (modelo, motor, gate) — STORY-085/086.
- Telas e visibilidade de depoimentos — STORY-084 (Designer/DDR-004).
- Motor de penalidade/decay (PDR-007) — fora do MVP; placeholder no modelo apenas.

## Padrões de qualidade exigidos

`docs/skills/po/references/quality-standards.md` + `docs/skills/arquiteto/references/architecture-principles.md`. ADR com contexto, decisão, consequências, alternativas.

## Dependências

- **Bloqueada por:** EPIC-003 `done` (turno `finalizado` existe) — satisfeito.
- **Bloqueia:** STORY-085 e STORY-086 (implementação não começa sem ADR-019 aceita).

## Decisões já tomadas (não as reabra)

- PDR-005 (avaliação obrigatória), ADR-015 (modelo Turno), ADR-017 (tempo real + geo), ADR-007 (RBAC), ADR-018 (UUID).

## Liberdade técnica do agente

Decide: forma do modelo, mecanismo de eventos, camada do gate, desenho do motor de XP. NÃO decide: que a avaliação é obrigatória (PDR-005), valores de XP (spec, ajustáveis em operação), MVP cuts do `epic.md`.

## Definição de Pronto (DoD)

- [x] ADR-019 `accepted` + indexado; `flows/avaliacao-reciproca.md` escrito.
- [x] `index.json` atualizado: status da estória = `done`. "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

`docs/skills/po/references/agent-task-format.md` + skill `arquiteto`.

## Notas do agente (preenchido durante/após execução)

### Decisões
- **ADR-019 escrita em `proposed`** (`decisions/adr/ADR-019-avaliacao-reciproca-modelo-eventos-gate.md`) + spec `docs/especificacao/flows/avaliacao-reciproca.md`. Indexada em `index.json` (`decisions.adr`, `proposed`). **CA-5 pende de aprovação humana** (não me marco `accepted`); até lá a estória fica `in_progress`.
- **D1 (modelo, CA-1):** tabela `avaliacoes` separada — uma linha por direção/turno, `UNIQUE (turno_id, direcao)`, `CHECK (estrelas BETWEEN 1 AND 5)`, `CHECK (autor_id <> avaliado_id)`, índice de cobertura `(avaliado_id, created_at DESC)`. **Diverge do esboço jsonb de `turno.md`** (atributos no turno) — assumido: latitude de modelagem do arquiteto; tabela separada é a forma correta para reputação consultável (média + depoimentos).
- **D2:** pendência **derivada do estado** (turno finalizado/finalizado_ajustado sem linha na direção), **não materializada** — refina a linguagem "cria as duas pendências" do `epic.md`; idempotente e sem peça nova (espelha ADR-014).
- **D3 (eventos, CA-2):** reusa `App\Events\TurnoFinalizado` (já existe) somando um listener de notificação "avalie seu turno"; novo `App\Events\AvaliacaoRegistrada` dispara o motor. **Síncronos dentro da transação** (auto-discovery está OFF — registro explícito no `AppServiceProvider`), payload de IDs string UUID.
- **D4 (motor, CA-2):** `App\Domain\Avaliacao\MotorReputacao` recomputa score/XP/turnos do `avaliado` a partir dos fatos canônicos → **idempotente por construção** (sem ledger, elimina "XP em dobro"); nível é **high-water-mark** (sobe, nunca rebaixa). Schema: `profissional_profiles.xp` **`unsignedInteger → integer` signed** (spec: "XP pode ficar negativo"); `contratante_profiles` **ganha `score`**; enum `NivelProfissional` recomendado.
- **D5 (gate, CA-3):** **service layer**, fail-secure, simétrico, ortogonal ao RBAC. Reusa as costuras prontas: `GateAvaliacao` já liga `CriarCandidaturaService` (STORY-086 enche `AvaliacoesPendentesProfissional` + preenche `turno_id`); falta **ligar `PublicarVagaService`** via `AvaliacoesPendentesContratante` (STORY-086).

### Descobertas
- As costuras do gate **já existem** como stubs honestos do EPIC-002 (`app/Domain/Avaliacao/AvaliacoesPendentes{Profissional,Contratante}` + `app/Domain/Candidatura/Gates/GateAvaliacao`); o lado do profissional já está ligado à candidatura, o do contratante **não** está ligado ao `PublicarVagaService`.
- `profissional_profiles` já tem `nivel/score/xp/turnos_realizados`; **`xp` é `unsignedInteger`** (conflita com "XP negativo" — D4 manda virar signed). `contratante_profiles` **não tem** `score` (D4 adiciona).
- Evento `TurnoFinalizado` já existe e já dispara o ciclo financeiro; o auto-discovery de listeners está **desligado** (`bootstrap/app.php`).
- **CA-6 atendido:** STORY-085 (modelo+motor — fronteira de quebra = o evento `AvaliacaoRegistrada`) e STORY-086 (gate) ficam sem decisão de baixo nível em aberto.

### Bloqueios
- Nenhum técnico. **Bloqueio de processo:** CA-5/DoD exigem ADR-019 `accepted` (aprovação do Alexandro) antes de STORY-085/086 começarem. Apresentada ao PO para aprovação.
