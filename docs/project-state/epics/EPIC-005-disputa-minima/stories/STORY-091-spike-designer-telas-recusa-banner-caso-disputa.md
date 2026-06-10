---
story_id: STORY-091
slug: spike-designer-telas-recusa-banner-caso-disputa
title: Spike Designer — recusar check-out + justificativa, banner de disputa e tela de caso no backoffice (DDR-005)
epic_id: EPIC-005
sprint_id: SPRINT-2026-W31
type: spike
target_role: designer
requires_design: true
status: done
owner_agent: claude-opus-4-8 (designer)
created_at: 2026-06-10
updated_at: 2026-06-10
estimated_session_size: M
---

# STORY-091 — Spike Designer: telas de recusa + banner + caso de disputa (DDR-005)

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. O entregável é uma decisão de design (DDR-005) + protótipo navegável aprovado pelo dono, dentro do Design System e do shell vigentes — não código de produção.

## Contexto (por que esta estória existe)

A disputa toca três superfícies de UI: o **contratante** (que recusa validar o check-out e digita a justificativa obrigatória), o **profissional** (que vê um banner de "valor em disputa, mediação em até 30 min") e o **admin** no backoffice (que abre o caso, lê toda a trilha e resolve). Cada uma precisa de tela definida antes de qualquer código de frontend — repetindo a disciplina das W27/W28/W30 (protótipo aprovado antes de implementar). As estórias de frontend 094, 095 e 096 ficam `blocked` até este protótipo estar aprovado pelo dono.

- Épico: `epics/EPIC-005-disputa-minima/epic.md`
- Documentos canônicos a ler ANTES de desenhar:
  - `docs/especificacao/domain/disputa.md` (atributos visíveis, justificativa obrigatória, SLA 30 min)
  - `docs/especificacao/domain/turno.md` (estado `em_disputa`, detalhe do turno, trilha)
  - `docs/project-state/decisions/ddr/DDR-001-fundacao-do-design-system.md` (DS)
  - `docs/project-state/decisions/ddr/DDR-002-pt-br-e-horario-24h.md` (idioma/formatos)
  - `docs/project-state/decisions/ddr/DDR-003-shell-de-navegacao-global.md` (shell — as telas vivem dentro dele)
  - `docs/skills/designer/SKILL.md` e referências de craft (se existirem)

## O quê (objetivo desta estória)

Produzir a **DDR-005** + a SCREEN-spec navegável cobrindo as três superfícies: (1) ação "Recusar e abrir disputa" + campo de justificativa obrigatório no fluxo de validação de check-out do contratante; (2) banner de disputa no detalhe do turno do profissional + marcação do estado `em_disputa` nas listas; (3) tela de caso de disputa no backoffice (`/disputas`): fila + detalhe com trilha completa (chat, geofencing, checklist, cronômetro, justificativa, vaga original) + ação "Resolver: pagar integral" com confirmação.

## Por quê (valor para o usuário)

A recusa de check-out é um momento de tensão (dinheiro em jogo dos dois lados). Microcopy clara e estados bem desenhados evitam que o contratante abra disputa por engano e dão ao profissional segurança de que há um processo. No admin, uma trilha legível é o que permite resolver em 30 min sem improviso.

## Critérios de aceite

- [ ] **CA-1:** SCREEN-spec do **contratante** cobre a ação "Recusar e abrir disputa" no ponto de validação de check-out, com campo de justificativa **obrigatório** (estado de erro quando vazio), confirmação explícita (a recusa é irreversível para `em_disputa`) e copy que diferencia "recusar" de "validar". Todos os estados: vazio/erro/enviando/enviado.
- [ ] **CA-2:** SCREEN-spec do **profissional** define o banner "valor em disputa — equipe Turni vai mediar em até 30 min" no detalhe do turno em `em_disputa`, e como o estado aparece nas listas ("Meus turnos"), sem ação disponível ao profissional (read-only), conforme `disputa.md`.
- [ ] **CA-3:** SCREEN-spec do **admin** cobre a fila `/disputas` (itens com contratante, profissional, valor, tempo decorrido vs SLA 30 min) e o detalhe do caso com a **trilha completa** (chat, geofencing, checklist, cronômetro, justificativa do contratante, vaga original) + ação "Resolver: pagar integral" com diálogo de confirmação e campo `nota_admin` **obrigatório** (editado de "opcional" → "obrigatório" em 2026-06-10, chancelado por Alexandro/PO; alinha com ADR-020 Decisão 3 + trilha de auditoria — ver DDR-005 Decisão 3).
- [ ] **CA-4:** Todas as telas respeitam DDR-001/002/003 (DS, pt-BR/24h, shell) e reusam componentes existentes onde possível; novos componentes são listados explicitamente na DDR-005. Acessibilidade: estados de erro não dependem só de cor; foco e ordem de teclado descritos para os formulários.
- [ ] **CA-5:** Protótipo HTML navegável (mobile para profissional, desktop para contratante e admin) entregue e **aprovado pelo dono** antes de fechar a estória; `prototype_last_validated_at` registrado.
- [ ] **CA-6:** DDR-005 fixa a decisão de SLA visível (como mostrar o "30 min" sem prometer o que o sistema não controla) e a copy padrão dos três pontos — alinhada ao SLA público de `non-functional.md`.

## Fora de escopo

- Implementar qualquer tela em código (é das estórias 094/095/096).
- Desenhar resoluções `paga_parcial`/`sem_pagamento` (fora do MVP).
- UI rica de mediação (chat dedicado admin↔partes) — fora do MVP por PDR-006/epic.

## Padrões de qualidade exigidos

Segue `quality-standards.md` no aplicável a design: protótipo navegável, estados completos, acessibilidade descrita, DDR no formato vigente, aprovação do dono registrada.

## Dependências

- **Bloqueada por:** — (paralela à STORY-090; pode iniciar imediatamente)
- **Bloqueia:** STORY-094 (FE contratante), STORY-095 (FE profissional), STORY-096 (backoffice)
- **Pré-requisitos de ambiente:** nenhum.

## Decisões já tomadas (não as reabra)

- PDR-006 — disputa via admin, SLA 30 min.
- DDR-001/002/003 — DS, pt-BR/24h, shell de navegação.
- O profissional **não** age na disputa no MVP (só é notificado) — `disputa.md`.

## Liberdade técnica do agente

Você (Designer) decide layout, componentes, microcopy e fluxo de interação dentro do DS e do shell. Você **não** decide modelo de dados nem critério de aceite de produto. Se faltar decisão de produto (ex: o que exatamente o profissional pode ver da justificativa do contratante), **pare e registre** para o PO.

## Definição de Pronto (DoD)

- [ ] DDR-005 escrita em `decisions/ddr/DDR-005-<slug>.md`, status `accepted`.
- [ ] SCREEN-spec + protótipo navegável entregues e aprovados pelo dono.
- [ ] `index.json` atualizado: DDR-005 + SCREEN indexados; STORY-091 `done`; 094/095/096 destravadas.
- [ ] Seção "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Aprovação do dono do protótipo é gate obrigatório antes de `done`.

## Notas do agente (preenchido durante/após execução)

### Decisões tomadas (sync com o dono em 2026-06-10, antes de cristalizar)
- 2026-06-10 — **Recusa do contratante = entrada única que desambigua a intenção** (não duas ações irmãs). Uma só "Recusar check-out" abre uma folha (`pattern.intent-disambiguation`) que separa "ainda não terminou" (→ `ativo`, reversível, comportamento atual da 064) de "tenho um problema" (→ disputa, irreversível, justificativa obrigatória). Previne disputa por engano (Princípio #1). Aprovado pelo dono.
- 2026-06-10 — **Profissional não vê o texto da justificativa** do contratante; vê só um `banner.status` read-only "valor em disputa — mediação em até 30 min". A justificativa é insumo do admin (mesmo princípio do motivo da recusa hoje). Aprovado pelo dono. *(Cumpre o pedido da §Liberdade técnica de registrar isto para o PO.)*
- 2026-06-10 — **`nota_admin` na resolução = OBRIGATÓRIA.** Resolve o conflito CA-3 (estória diz "opcional") × ADR-020 Decisão 3 (comando exige nota). Vale a obrigatoriedade (alinha com ADR-020 + trilha de auditoria). Aprovado pelo dono. **Pendência para o PO:** chancelar a edição do texto do CA-3 de "opcional" → "obrigatória" (Designer não edita CA por conta própria).

### Descobertas
- 2026-06-10 — A SCREEN-059 **já marca** `em_disputa` (seção própria "Em disputa" + selo `⚠ Em disputa`) — a superfície de listas do profissional (CA-2) é **reuso**, sem mudança.
- 2026-06-10 — A SCREEN-064 já tinha uma recusa benigna ("Turno ainda não terminou? Recusar check-out" → `ativo`); o ADR-020 (Decisão 2) confirma que essa recusa **convive** com a nova abertura de disputa como **comandos distintos** — daí a necessidade de desambiguar na UI.
- 2026-06-10 — O caso do admin (CA-3) é **agregação de leitura** sobre dados já existentes (ADR-020 Decisão 6); a fila é **derivada** do estado `em_disputa` (não materializada). A superfície reusa o padrão fila→drawer da SCREEN-019.

### DDRs criados
- DDR-005 — Disputa de check-out: desambiguação da recusa, banner do profissional e tela de caso do admin — `decisions/ddr/DDR-005-disputa-recusa-banner-caso.md` (status `proposed` → `accepted` após aprovação do protótipo).

### Entregáveis
- **DDR-005** (`decisions/ddr/DDR-005-disputa-recusa-banner-caso.md`).
- **SCREEN-STORY-091-disputa** (`design/screens/SCREEN-STORY-091-disputa.md`) — 3 superfícies, estados completos, microcopy, a11y, identificadores.
- **Protótipo navegável** (`design/screens/SCREEN-STORY-091-disputa/index.html`) — seletor superfície × viewport × estado; fluxo do contratante e do admin percorríveis.
- **DS atualizado:** `pattern.intent-disambiguation` (patterns.md), `banner.status` + variante campo-obrigatório do `dialog.confirm` (components.md).
- **index.json:** DDR-005 + SCREEN indexados; `design_screen_id` da STORY-091 vinculado.

### Fechamento (2026-06-10 — aprovado por Alexandro, "aprovado")
- DDR-005 → `accepted`; SCREEN-STORY-091-disputa → `ready` (`prototype_last_validated_at: 2026-06-10`); STORY-091 → `done`.
- CA-3 editado (chancela do PO): `nota_admin` de "opcional" → "obrigatória".
- Destravadas (removida a STORY-091 do `blocked_by`): STORY-094 e STORY-095 seguem bloqueadas pela STORY-092 (backend); STORY-096 pela STORY-093.
