---
story_id: STORY-090
slug: spike-arquiteto-modelo-disputa-transicao-captura-admin
title: Spike Arquiteto — modelo de disputa + transição em_disputa + comando de captura do admin (ADR-020)
epic_id: EPIC-005
sprint_id: SPRINT-2026-W31
type: spike
target_role: arquiteto
requires_design: false
status: done
owner_agent: claude-opus-4-8-arquiteto-2026-06-10
created_at: 2026-06-10
updated_at: 2026-06-10
estimated_session_size: M
---

# STORY-090 — Spike Arquiteto: modelo de disputa + transição `em_disputa` + comando de captura do admin (ADR-020)

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Se algo estiver ambíguo, registre a dúvida em "Notas do agente" e pause em vez de adivinhar. Esta é uma estória de **decisão arquitetural** — o entregável é um ADR aceito, não código de produção.

## Contexto (por que esta estória existe)

O EPIC-005 fecha a WAVE-2026-01 entregando o caminho de exceção do check-out: quando o contratante recusa validar o PIN de check-out, o turno entra em `em_disputa` e a equipe Turni resolve no backoffice. Antes de qualquer código, é preciso fixar **como** isso é modelado: onde mora a disputa (atributos no turno vs entidade própria), como a máquina de estados transita e — crítico — **como o admin dispara a captura/Pix fora do fluxo normal de check-out**, já que no MVP o pagamento passa por um fake genérico atrás de ACL (PDR-017), não pelo Pagar.me real.

Esta estória repete a lição das W27/W28/W30: **a decisão precede a implementação**. As estórias de backend (092, 093) e de backoffice (096) ficam `blocked` até este ADR estar `accepted`.

- Épico: `epics/EPIC-005-disputa-minima/epic.md`
- Documentos canônicos a ler ANTES de decidir:
  - `docs/especificacao/domain/disputa.md` (atributos da disputa, fluxo, SLA)
  - `docs/especificacao/domain/turno.md` (máquina de estados — transição `aguardando_checkout → em_disputa → finalizado`)
  - `docs/especificacao/domain/pagamento.md` (seção "Disputa": pré-autorização bloqueada; `paga_integral` = captura padrão)
  - `docs/project-state/decisions/pdr/PDR-006-disputa-checkout-via-admin.md` (base do épico)
  - `docs/project-state/decisions/pdr/PDR-017-pagamento-via-fake-generico-no-mvp.md` (pagamento via fake atrás de ACL)
  - `docs/project-state/decisions/adr/ADR-015-modelo-turno-aceite-eletronico-maquina-estados.md` (modelo de Turno vigente)
  - `docs/project-state/decisions/adr/ADR-016-acl-pagarme-sandbox-idempotencia-webhook.md` (ACL de pagamento + idempotência)
  - `docs/project-state/decisions/adr/ADR-019-avaliacao-reciproca-modelo-eventos-gate.md` (padrão de eventos de domínio + notificação adotado na W30)

## O quê (objetivo desta estória)

Produzir o **ADR-020** decidindo: (1) o modelo de dados da disputa e onde ela vive; (2) as transições de estado `aguardando_checkout → em_disputa` (abertura) e `em_disputa → finalizado` (resolução `paga_integral`); (3) o comando do admin que dispara a captura padrão + Pix via ACL de pagamento (PDR-017/ADR-016), reusando idempotência; (4) o(s) evento(s) de domínio que notificam o profissional na abertura e na resolução, reusando o padrão da ADR-019.

## Por quê (valor para o usuário)

Sem um modelo claro, a recusa de check-out vira estado fantasma (turno preso, ninguém pago, ninguém notificado) — exatamente o que o épico existe para eliminar. A decisão arquitetural fixa o contrato que faz o caminho de exceção ser auditável e fechável em 30 min.

## Critérios de aceite

Cada item é uma asserção verificável no ADR entregue.

- [ ] **CA-1:** ADR-020 decide **onde mora a disputa** (atributos embutidos no turno conforme `disputa.md` vs tabela própria), com justificativa coerente com ADR-015 e ADR-018 (UUID). Os atributos mínimos do MVP estão cobertos: `aberta_em`, `aberta_por` (contratante), `justificativa_contratante` (obrigatória), `resolucao` (apenas `paga_integral` no MVP), `nota_admin`, `resolvida_em`, `resolvida_por`.
- [ ] **CA-2:** ADR-020 define a transição de **abertura** `aguardando_checkout → em_disputa`: pré-condições (turno em `aguardando_checkout`, ator = contratante dono da vaga, justificativa não-vazia), efeito (pré-autorização permanece **bloqueada**, sem capturar nem liberar) e o evento de domínio emitido na transação.
- [ ] **CA-3:** ADR-020 define a transição de **resolução** `em_disputa → finalizado` para `paga_integral`: ator = admin, efeito = **captura padrão via ACL de pagamento + Pix do `valor` ao profissional** (mesma máquina do check-out feliz, agora disparada por comando do admin), reusando a idempotência da ADR-016 para não capturar/pagar em dobro.
- [ ] **CA-4:** ADR-020 especifica o(s) **evento(s)/notificação** ao profissional na abertura (in-app + e-mail, "valor em disputa, mediação em até 30 min") e na resolução, reusando o padrão de eventos síncronos na transação da ADR-019. Define se a pendência do admin (fila) é **derivada do estado** `em_disputa` (preferido, lição da W30) ou materializada.
- [ ] **CA-5:** ADR-020 lista explicitamente o que **fica fora do MVP** e por quê: resoluções `paga_parcial` e `sem_pagamento` (e portanto os estados `finalizado_ajustado` e `disputa_resolvida_sem_pagamento`), captura/estorno parcial, penalidade automática de score. Aponta o ponto de extensão para a WAVE-2026-02 (EPIC-007).
- [ ] **CA-6:** ADR-020 registra o impacto de leitura: o admin precisa ver a **trilha completa** (chat, geofencing, checklist, cronômetro, justificativa, vaga original) — decide se isso é uma agregação de leitura nova na API ou reuso de endpoints existentes. Não inventa contrato de UI (isso é da 091/096) — só fixa a fronteira de dados.

## Fora de escopo

- Escrever qualquer código de produção, migração ou teste.
- Decidir telas, layout ou textos (é da STORY-091 — Designer).
- Modelar `paga_parcial` / `sem_pagamento` (fora do MVP).
- Reabrir PDR-006 ou PDR-017 — são decisões de produto/estratégia já tomadas; o ADR vive **dentro** delas.

## Padrões de qualidade exigidos

Esta estória segue `docs/skills/po/references/quality-standards.md` no que se aplica a um spike de arquitetura:

- Entregável é um ADR no formato vigente (`docs/skills/arquiteto/references/adr-lifecycle.md`), status `accepted` após aprovação do dono.
- A decisão é **autocontida e implementável** por um agente programador lendo só o ADR + specs citadas.
- Sem código não testado entregue (não há código nesta estória).

## Dependências

- **Bloqueada por:** — (pode iniciar imediatamente)
- **Bloqueia:** STORY-092 (backend abertura) e STORY-093 (backend resolução) diretamente; STORY-096 (backoffice) de forma transitiva via 093
- **Pré-requisitos de ambiente:** nenhum.

## Decisões já tomadas (não as reabra)

- PDR-006 — disputa de check-out via admin, SLA público 30 min → `decisions/pdr/PDR-006-disputa-checkout-via-admin.md`
- PDR-017 — pagamento via fake genérico atrás de ACL no MVP → `decisions/pdr/PDR-017-pagamento-via-fake-generico-no-mvp.md`
- ADR-015 — modelo de Turno e máquina de estados → `decisions/adr/ADR-015-modelo-turno-aceite-eletronico-maquina-estados.md`
- ADR-016 — ACL de pagamento + idempotência → `decisions/adr/ADR-016-acl-pagarme-sandbox-idempotencia-webhook.md`
- ADR-018 — UUID como chave primária → `decisions/adr/ADR-018-uuid-chave-primaria-entidades-dominio.md`
- ADR-019 — padrão de eventos de domínio + notificação → `decisions/adr/ADR-019-avaliacao-reciproca-modelo-eventos-gate.md`

## Liberdade técnica do agente

Você (Arquiteto) decide o modelo de dados, as transições, o desenho dos eventos e o ponto de disparo da captura — desde que dentro de PDR-006, PDR-017 e das ADRs vigentes. Você **não** decide critério de aceite de produto nem telas.

Se durante a análise perceber que uma decisão de **produto** está em aberto (ex: o que mostrar ao profissional, prazo de janela para abrir disputa), **pare e registre** em "Notas do agente" para o PO — não decida sozinho.

## Definição de Pronto (DoD)

- [x] ADR-020 escrito em `decisions/adr/ADR-020-modelo-disputa-transicoes-comando-captura-admin.md`, cobrindo CA-1..CA-6.
- [x] ADR aprovado pelo dono (status `accepted`) — `decided_at: 2026-06-10`, `decided_by: arquiteto`, `approved_by: Alexandro`.
- [x] `index.json` atualizado: ADR-020 indexado (`accepted`); STORY-090 `status: done`.
- [x] STORY-092/093/096 saíram de `blocked` para `ready` (anotado no índice).
- [x] Seção "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Em resumo: ao iniciar, marque `status: in_progress` no frontmatter e no `index.json`; se travar numa decisão de produto, marque `blocked` e descreva; ao terminar, marque `done`, atualize o índice e avise o PO que as estórias de implementação estão destravadas.

## Notas do agente (preenchido durante/após execução)

### Decisões tomadas
- 2026-06-10 — **CA-1:** disputa **embutida** em `turnos.disputa` (jsonb, grão de `cancelamento`), **não** tabela própria. Regra do Turni: embute quando 1:1/contextual/sem agregação cross-turno/sem constraint dura (`cancelamento`, `geofencing`); tabela quando cross-query/constraints/N linhas (`avaliacoes`/ADR-019). A disputa cai do lado de `cancelamento`. Obrigatoriedade da justificativa e validade da resolução vivem no **comando de domínio**; auditabilidade em `audit_logs`.
- 2026-06-10 — **CA-2:** abertura via comando próprio `AbrirDisputaService` (`aguardando_checkout → em_disputa`), **distinto** do `ValidarCheckoutService::recusar()` existente (que vai a `ativo`). Justificativa obrigatória, ator = contratante dono, pré-autorização **mantida bloqueada** (nenhum evento financeiro), evento novo `DisputaAberta` pós-commit.
- 2026-06-10 — **CA-3 (central):** resolução `paga_integral` é **comando da api** (`ResolverDisputaService`) que transita `em_disputa → finalizado` e **reusa o `TurnoFinalizado` existente** → mesma máquina de captura+Pix do check-out feliz (fake/PDR-017). **Admin é cliente** (endpoint autenticado), **nunca escrita direta no banco** — porque a captura é disparada por evento in-process da api que o processo separado do admin não consegue emitir; escrita direta = risco de "finalizado sem captura" (fantasma). Idempotência em **3 camadas**: trigger de transição + guard do job (`status===Finalizado`) + índice único `(turno_id, tipo_operacao)` de ADR-016.
- 2026-06-10 — **CA-4:** evento novo `DisputaAberta` (notifica profissional in-app + e-mail, SLA 30 min) + **reuso** de `TurnoFinalizado` na resolução (sem evento `DisputaResolvida`). Fila do admin **derivada** do estado `em_disputa` (não materializada — lição W30); difere de `pix_falhas` (que é snapshot pois falha de Pix não tem estado-espelho).
- 2026-06-10 — **CA-5/CA-6:** `paga_parcial`/`sem_pagamento` fora do MVP (estados já no enum/trigger; comandos ao EPIC-007 — sem `ALTER TYPE`). Trilha de leitura do admin = agregação de dados **já existentes** no turno + `disputa` + `audit_logs`; sem contrato de domínio novo (forma da leitura é IDR da STORY-096).

### Descobertas
- 2026-06-10 — A máquina financeira é disparada por **evento** (`TurnoFinalizado`), não por estado no banco: `CapturarEPagarTurnoJob` faz no-op se `status ≠ Finalizado`. Isso fundamenta CA-3 — a resolução **tem que** reemitir `TurnoFinalizado`, e por isso precisa rodar **na api**, não no admin.
- 2026-06-10 — `apps/admin` (Laravel+Livewire) compartilha o banco e faz resoluções **não-financeiras** direto (PixFalhas marca snapshot). A disputa é o **primeiro** caso transacional que **move dinheiro** pelo backoffice → exige o canal admin→api (1ª vez).
- 2026-06-10 — ADR-019 §Resumo dos eventos **já antecipou** que a transição via disputa emitiria `TurnoFinalizado` e o fluxo se aplicaria sem mudança. ADR-015 **já modelou** as transições de `em_disputa` no trigger "para evitar `ALTER TYPE` depois". O ADR-020 colhe esses dois investimentos.

### Bloqueios encontrados
- 2026-06-10 — **Nota de fronteira para PO/Designer (não-bloqueante):** no ponto de check-out o contratante tem **duas** ações distintas — (a) `recusar()` o PIN → volta a `ativo` (peça novo PIN, motivo opcional, já existe) e (b) **abrir disputa** → `em_disputa` (justificativa obrigatória, novo). A arquitetura trata as duas como comandos separados; **qual affordance de UI mapeia para cada uma** é decisão do Designer (STORY-091/094). Registrado, não decidido aqui (não trava o ADR).
- 2026-06-10 — Aguardando **aprovação humana** do ADR-020 (status `proposed`). STORY-092/093/096 seguem `blocked` até `accepted`.

### ADRs criados
- ADR-020 — Modelo de disputa, transições e comando de captura do admin — `decisions/adr/ADR-020-modelo-disputa-transicoes-comando-captura-admin.md` (status `proposed`)
