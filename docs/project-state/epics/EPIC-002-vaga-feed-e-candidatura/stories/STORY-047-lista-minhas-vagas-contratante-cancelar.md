---
story_id: STORY-047
slug: lista-minhas-vagas-contratante-cancelar
title: Lista "Minhas vagas" do contratante no WebApp + cancelar vaga
epic_id: EPIC-002
sprint_id: SPRINT-2026-W27
type: implementation
target_role: programador
requires_design: true
design_screen_id: SCREEN-STORY-047-minhas-vagas
status: ready
owner_agent: null
created_at: 2026-06-01
updated_at: 2026-06-01
estimated_session_size: S
produces_idr: null
---

# STORY-047 — Lista "Minhas vagas" + cancelar

> **Para o agente:** estória pequena (S) — lista + ação de cancelar. Coexiste com a publicação (STORY-046) e o painel de candidatos (STORY-051) — esta apenas lista e cancela; clicar em uma vaga abre o painel de candidatos quando STORY-051 estiver done.

## Contexto

Depois de publicar (STORY-046), o contratante precisa ver o que tem em campo e poder cancelar antes de receber aceite. Sem isso, vaga vira "joga e esquece" — o que confunde quando profissional candidata em vaga que o contratante já desistiu de preencher.

- Épico: `epics/EPIC-002-vaga-feed-e-candidatura/epic.md`
- Documentos: `domain/vaga.md` (seção Cancelamento), STORY-044 (modelo), SCREEN-STORY-047.

## O quê

Tela `/contratante/vagas` listando vagas do contratante autenticado agrupadas por estado (`aberta`, `fechada`, `cancelada`), com filtro padrão "Ativas" (aberta + fechada da última semana). Ação "Cancelar" disponível só em `aberta`; com confirmação clara; notifica candidatos pendentes (delegado a STORY-053 — esta estória apenas dispara o evento de domínio).

## Por quê

Operação básica do contratante. Sem listagem, não há gestão. Sem cancelamento, vaga vira lixo.

## Critérios de aceite

- [ ] **CA-1:** Contratante autenticado acessa `/contratante/vagas` e vê lista das próprias vagas (RBAC: contratante só vê próprias; profissional 403). Endpoint `GET /api/vagas/minhas`.
- [ ] **CA-2:** Cada card mostra: função, data/hora, valor, posições preenchidas/total (`2/3`), estado com cor (DDR-001), contador de candidatos pendentes.
- [ ] **CA-3:** Filtros: "Ativas" (default — `aberta` + `fechada` < 7d), "Abertas", "Fechadas", "Canceladas", "Todas". Filtro persiste em sessão (não em DB).
- [ ] **CA-4:** Card de vaga `aberta` tem botão "Cancelar vaga" — abre modal de confirmação com "X candidatos serão notificados" (X real). Confirmação chama `DELETE /api/vagas/{id}` (soft via mudança de estado para `cancelada`, não DELETE físico).
- [ ] **CA-5:** Backend `DELETE /api/vagas/{id}` valida RBAC (vaga deve ser do contratante autenticado), valida transição (`aberta → cancelada` permitida; outras retornam 409), muda estado, registra audit log `vaga.cancelada`, dispara evento de domínio `VagaCancelada` (consumido por STORY-053 para notificar candidatos pendentes).
- [ ] **CA-6:** Card mostra link "Ver candidatos" só para vagas `aberta` com `candidatos_pendentes > 0` ou `fechada`; abre `/contratante/vagas/{id}/candidatos` (STORY-051). Se STORY-051 não estiver done no merge, o link aponta para placeholder.
- [ ] **CA-7:** Lista vazia: estado vazio amigável com CTA "Publicar vaga" (link para STORY-046).
- [ ] **CA-8:** Cobertura unitária controller + componentes ≥ 85%. E2E em `integration_test`: contratante com 2 vagas (1 aberta, 1 cancelada) vê a lista; clica em cancelar → vaga muda para `cancelada` no banco.

## Fora de escopo

- Edição de vaga → STORY-052.
- Painel de candidatos → STORY-051.
- Notificação aos candidatos pendentes pelo cancelamento → STORY-053 (consome o evento de domínio).
- Duplicar vaga (`domain/vaga.md` Duplicação) — fora do MVP da W27; vai para wishlist.

## Padrões de qualidade

- Cobertura ≥ 85%.
- E2E verde.
- RBAC verificado em teste.

## Dependências

- **Bloqueada por:** STORY-044 (modelo), STORY-046 (publicar — para ter o que listar).
- **Bloqueia:** STORY-051 (painel candidatos — caminho de navegação parte daqui).
- **Pré-req:** RBAC vivo, contratante seed `ativo`.

## Decisões já tomadas

- ADR-013, ADR-007, DDR-001.
- `domain/vaga.md`: cancelar antes de candidatura é trivial; com candidatos pendentes notifica.

## Liberdade técnica

Decide: paginação se necessário (sugestão: cursor-based 20 por página, fica para depois se não bater); estrutura de cache local no WebApp.

## DoD

- [ ] CAs checados.
- [ ] Cobertura, E2E, deploy verificados.
- [ ] `index.json` atualizado.
- [ ] "Notas do agente" preenchida.

## Notas do agente

### Decisões tomadas
- 
### Descobertas
- 
### Bloqueios
- 
### IDRs
- 
### Cobertura final
- Unitários: 
- E2E: 
### Links
- PR: 
- Pipeline: 
- Deploy: 
