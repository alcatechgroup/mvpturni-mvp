---
story_id: STORY-086
slug: backend-gate-bloqueante
title: "Backend — gate bloqueante: sem candidatar/publicar com avaliação pendente"
epic_id: EPIC-004
sprint_id: SPRINT-2026-W30
type: implementation
target_role: programador
requires_design: false
design_screen_id: null
status: in_progress
owner_agent: claude-opus-4-8-programador-2026-06-09
created_at: 2026-06-09
updated_at: 2026-06-09
estimated_session_size: M
produces_idr: null
---

# STORY-086 — Backend: gate bloqueante de avaliação pendente

> **Para o agente que vai executar:** leia a estória inteira. Implementa o ponto de gate decidido em ADR-019 (STORY-083). Fail-secure.

## Contexto (por que esta estória existe)

A avaliação só é obrigatória se houver **gate** (PDR-005): quem tem avaliação pendente não avança. É o mecanismo que fecha o ciclo — força a reflexão antes da próxima ação.

- Decisão: ADR-019 (ponto/estratégia do gate).
- Spec: `domain/niveis-e-score.md` (regra de bloqueio), `flows/avaliacao-reciproca.md`.

## O quê (objetivo desta estória)

Aplicar o gate no ponto decidido (ADR-019): **profissional não pode candidatar-se** e **contratante não pode publicar nova vaga** enquanto houver avaliação pendente de turno `finalizado`. O bloqueio retorna mensagem clara + referência ao turno pendente (para o front linkar). Fail-secure (na dúvida, bloqueia) e RBAC-aware.

## Por quê (valor para o usuário)

Garante que a reciprocidade aconteça de fato — sem gate, a avaliação vira opcional e os dados de qualidade não acumulam.

## Critérios de aceite

- [x] **CA-1:** Profissional com avaliação pendente é bloqueado ao tentar candidatar-se; resposta tem mensagem clara + identificador do turno pendente. — `GateAvaliacao` consome a pendência derivada (`turnoPendente`); 422 `gate_avaliacao` + `detalhe.turno_id` (mais antigo). `GateAvaliacaoTest` (CA-1) + `CandidaturaTest`.
- [x] **CA-2:** Contratante com avaliação pendente é bloqueado ao publicar nova vaga; idem mensagem + turno pendente. — `PublicarVagaService` aborta com `PublicacaoBloqueadaPorAvaliacao` antes da transação; `VagaController` traduz para 422 `gate_avaliacao` + `turno_id`. `GateAvaliacaoTest` (CA-2).
- [x] **CA-3:** Sem pendência, as ações fluem normalmente (sem regressão de candidatura/publicação da W26/W28). — `GateAvaliacaoTest` (CA-3, os 2 papéis) + suíte W26/W28 intacta (1070 verde).
- [x] **CA-4:** Fail-secure: erro ao consultar pendência não libera a ação. RBAC preservado (ADR-007). — try/catch nos dois gates bloqueia no erro (com `turno_id` null); `GateAvaliacaoTest` (contratante) + `GateAvaliacaoFailSecureTest` (profissional/feed). RBAC do controller/FunnelGuard inalterado.
- [x] **CA-5:** Cobertura ≥ 80% no código novo; cenários: com pendência (bloqueia, os 2 papéis), sem pendência (libera), múltiplas pendências, e falha de consulta (bloqueia). E2E/feature test do bloqueio nos 2 papéis. — código novo 100% (PublicarVagaService/GateAvaliacao/AvaliacoesPendentes*); total 94.5%; suíte **1070 verde**.
- [ ] **CA-6:** Deploy homologação verificado.

## Fora de escopo

- UX do bloqueio no front (STORY-088). Motor de XP (STORY-085).

## Padrões de qualidade exigidos

`quality-standards.md`. ≥80%; fail-secure; TDD; mensagens sem dado sensível.

## Dependências

- **Bloqueada por:** STORY-085 (consulta a pendência de avaliação).
- **Bloqueia:** STORY-088 (UX do bloqueio), STORY-089 (validação).

## Decisões já tomadas (não as reabra)

- ADR-019 (ponto do gate), PDR-005, ADR-007 (RBAC).

## Liberdade técnica do agente

Decide: implementação concreta do gate na camada decidida, design dos testes, forma da resposta de bloqueio. NÃO decide: que as ações são bloqueadas (PDR-005), o ponto do gate (ADR-019), CAs.

## Definição de Pronto (DoD)

- [ ] CAs passam; testes verdes; cobertura atingida.
- [ ] Pipeline verde; deploy homolog verificado.
- [ ] `index.json` atualizado: status = `done`. "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

`docs/skills/po/references/agent-task-format.md` + skill `programador`.

## Notas do agente (preenchido durante/após execução)

### Entrada inicial (2026-06-09, programador) — leitura + plano

**Documentos lidos:** estória inteira; ADR-019 (5 decisões — D2 pendência derivada, D5 gate no service layer fail-secure e simétrico); STORY-085 (modelo `avaliacoes`, enum `AvaliacaoDirecao`, motor — done/rc.92). Código existente: costuras `AvaliacoesPendentes{Profissional,Contratante}` (stub-honesto), `GateAvaliacao` já ligado em `CriarCandidaturaService`, `PublicarVagaService` (ainda sem gate), `VagaController::store`, `CandidaturaController` (mapeamento de bloqueio), `Turno`/`TurnoStatus` (estados avaliáveis `finalizado`/`finalizado_ajustado`), `Avaliacao` + `AvaliacaoFactory`.

**Entendimento:** encher os dois stubs com a query derivada (ADR-019 D2: turno avaliável SEM linha de avaliação na direção do papel), ligar o gate do contratante no `PublicarVagaService`, e completar o slot `turno_id` (mais antigo) no gate do profissional. Fail-secure nos dois (erro de consulta → bloqueia). Sem tabela de pendência.

### Decisões / Descobertas / Bloqueios

**Decisões locais (latitude do programador):**
- `AvaliacoesPendentesProfissional::turnoPendente(User): ?Turno` (query derivada, mais antigo por `data_fim`) é a fonte; `podeCandidatar()` (feed/detalhe STORY-048) passa a delegar a ela com try/catch fail-secure (erro → false). `GateAvaliacao` chama `turnoPendente` direto (precisa do `turno_id`) com try/catch próprio fail-secure.
- `AvaliacoesPendentesContratante::para()` passa a contar os turnos avaliáveis do contratante sem avaliação na direção `contratante_para_profissional`; contrato `{pending, turnos:[{turno_id, data_fim}]}` (o endpoint de leitura STORY-046 e o gate consomem o mesmo).
- Lado do contratante: nova exceção de domínio `App\Domain\Avaliacao\PublicacaoBloqueadaPorAvaliacao` (carrega `turnoId`), lançada por `PublicarVagaService::garantirSemAvaliacaoPendente()` **antes** da transação; `VagaController::store` traduz para 422 com a mesma forma do gate de candidatura (`erro=gate_avaliacao`, `mensagem`, `detalhe.turno_id`). Não toquei Editar/Cancelar (gate é só sobre **publicar nova** — ADR-019 D5).
- Mensagens: profissional reusa "Avalie seu último turno para se candidatar."; contratante "Avalie seu último turno para publicar uma nova vaga.".

**Descobertas:**
- O turno-fixture (`TurnoFactory`) cria candidatura + 2 vagas próprias; asserções de "nada criado" precisam ser **escopadas** ao usuário/vaga do teste, não `assertDatabaseCount` global. Ajustei aqui e no teste CA-2 herdado de `CandidaturaTest`.
- O teste CA-2 de `CandidaturaTest` (STORY-050) mockava `podeCandidatar`; como o gate agora chama `turnoPendente`, atualizei o mock + passei a asserir `turno_id` real (contrato evoluiu).

**Mapeamento CA → teste (todos verdes):**
- CA-1 → `tests/Feature/Avaliacao/GateAvaliacaoTest.php` (bloqueia + turno_id; já-avaliou libera; mais antigo) + `tests/Feature/Candidatura/CandidaturaTest.php` (CA-2).
- CA-2 → `GateAvaliacaoTest` (bloqueia publicação + turno_id; já-avaliou publica; mais antigo; `finalizado_ajustado` conta).
- CA-3 → `GateAvaliacaoTest` (os 2 papéis liberam sem pendência) + regressão da suíte.
- CA-4 → `GateAvaliacaoTest` (fail-secure contratante; não-vazamento entre papéis/contratantes) + `tests/Unit/Avaliacao/GateAvaliacaoFailSecureTest.php` (gate + `podeCandidatar` do profissional).
- CA-5 → cobertura: código novo 100%; total 94.5%; suíte **1070 verde**; Pint limpo.
- CA-6 → push → CI → deploy homolog (em verificação).

**Bloqueios:** nenhum.
