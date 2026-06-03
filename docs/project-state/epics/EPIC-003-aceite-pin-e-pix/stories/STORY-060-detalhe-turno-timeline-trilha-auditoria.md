---
story_id: STORY-060
slug: detalhe-turno-timeline-trilha-auditoria
title: Detalhe do turno (ambos os lados) + timeline + trilha de auditoria visível
epic_id: EPIC-003
sprint_id: SPRINT-2026-W28
type: implementation
target_role: programador
requires_design: true
design_screen_id: SCREEN-STORY-060-detalhe-turno
status: ready
owner_agent: null
created_at: 2026-06-03
updated_at: 2026-06-03
estimated_session_size: M
produces_idr: null
---

# STORY-060 — Detalhe do turno + timeline + trilha de auditoria

## Contexto

A lista da STORY-059 leva o usuário até o turno individual. Esta tela é a **casa do turno** — onde o profissional gera PIN (STORY-061/064), o contratante valida PIN (STORY-062/064), ambos veem cronômetro (STORY-063), e a timeline mostra eventos passados de forma legível. A trilha de auditoria simplificada vive aqui (admin tem versão completa no Backoffice).

- Épico: `epics/EPIC-003-aceite-pin-e-pix/epic.md`
- Documentos: `domain/turno.md`, `domain/compliance.md` (trilha de auditoria), `domain/pagamento.md` (valores visíveis).

## O quê

Tela `/turnos/{id}` (compartilhada profissional/contratante, RBAC) com: atributos do turno (função, data/hora, estabelecimento, valor — visibilidade diferente por papel conforme `domain/pagamento.md`), estado atual com badge visual, timeline de eventos passados (audit log filtrado para os campos visíveis), área de ações (placeholder — as ações concretas chegam em 061/062/063/064/066).

## Por quê

É o componente que **costura** todas as ações do turno em um único lugar. Sem ele, profissional e contratante precisariam navegar por telas separadas para cada ação.

## Critérios de aceite

- [ ] **CA-1:** `GET /api/turnos/{id}` retorna o turno com atributos + timeline filtrada (eventos relevantes para o papel) — RBAC: profissional vê só os próprios; contratante vê só os turnos das próprias vagas; cruzados 403.
- [ ] **CA-2:** Tela `/turnos/{id}` renderiza header com função/data/hora/estabelecimento, estado atual com badge visual (DDR-001), e card de valor com **visibilidade diferenciada por papel** (profissional vê `valor` em destaque + "valor integral · taxa Turni cobrada do contratante" em letra menor; contratante vê `valor + taxa_turni + total_contratante` separados — `domain/pagamento.md` §"Visibilidade financeira").
- [ ] **CA-3:** Timeline mostra eventos em ordem cronológica descendente: `turno_criado`, `aceite_eletronico_emitido`, `pagamento_pre_autorizado`, `checkin_solicitado`, `checkin_validado`, `checkout_solicitado`, `checkout_validado`, `pagamento_capturado`, `pix_enviado`, `cancelado`, `no_show_pro`. Cada evento traz timestamp em formato 24h pt-BR (IDR-026/DDR-002) e descrição amigável.
- [ ] **CA-4:** Área de ações (botão grande, alta legibilidade) com placeholder que as estórias 061/062/063/064/066 vão preencher conforme o estado.
- [ ] **CA-5:** Link "Ver aceite eletrônico" abre modal com o `conteudo_renderizado` do AceiteEletronico (somente leitura — imutabilidade).
- [ ] **CA-6:** Cobertura ≥ 80%; E2E cobre o caminho lista → detalhe para os 2 papéis.

## Fora de escopo

- Ações sobre o turno (estórias seguintes).
- Cronômetro vivo (STORY-063).
- Trilha de auditoria **completa** no Backoffice (admin tem visão diferente; pode ficar como follow-up se não couber).

## Padrões de qualidade

≥ 80%. E2E em `integration_test`. RBAC verificado por teste explícito.

## Dependências

- **Bloqueada por:** STORY-058 (modelo + dados em `confirmado`).
- **Bloqueia:** STORY-061, STORY-062, STORY-063, STORY-064, STORY-066 (ações vivem aqui).
- **Pré-requisitos:** SCREEN-STORY-060 entregue.

## Decisões já tomadas

ADR-013, ADR-015, ADR-010 (imutabilidade do aceite), **ADR-018 (UUIDv7 em PKs — URL `/turnos/{uuid}`; DTO Flutter tipa `id` como `String`; audit log payload referencia entidades por UUID)**, DDR-001/002, IDR-026.

## Liberdade técnica

Decide: estrutura interna da timeline (componente reaproveitado), tamanho/posição da área de ações.

NÃO decide: visibilidade financeira (fixada em `domain/pagamento.md`).

## Definição de Pronto

- [ ] CAs marcados; deploy verificado.
- [ ] SCREEN-STORY-060 marcado `shipped`.
- [ ] `index.json` atualizado.
- [ ] "Notas do agente" preenchida.

## Protocolo

`docs/skills/po/references/agent-task-format.md`.

## Notas do agente

### Decisões tomadas
### Descobertas
### Bloqueios encontrados
### IDRs criados
### Cobertura final
- Unitários:
- E2E:
### Links de evidência
- PR:
- Pipeline:
- Deploy de homologação:
