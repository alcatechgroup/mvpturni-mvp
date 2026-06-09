---
story_id: STORY-084
slug: spike-designer-depoimentos-telas-perfil
title: "Spike Designer — DDR-004 (visibilidade de depoimentos) + telas de avaliação + perfil (score/nível/XP) + protótipo"
epic_id: EPIC-004
sprint_id: SPRINT-2026-W30
type: spike
target_role: designer
requires_design: true
design_screen_id: SCREEN-STORY-084-avaliacao-e-perfil
status: done
owner_agent: claude-opus-4-8-designer-2026-06-09
created_at: 2026-06-09
updated_at: 2026-06-09
estimated_session_size: M
produces_idr: DDR-004
---

# STORY-084 — Spike Designer: depoimentos (DDR-004) + telas de avaliação + perfil

> **Para o agente que vai executar:** carregue a skill `designer`. Produza **DDR-004** + as **SCREEN specs** + **protótipo navegável** aprovado pelo humano. Roda **em paralelo** à STORY-083. **Não implemente** Flutter — entrega decisão de design + spec + protótipo.

## Contexto (por que esta estória existe)

A avaliação recíproca tem superfície visível significativa: duas telas de avaliação (estrelas + comentário) e a evolução do perfil (score público, nível/badge, XP até o próximo nível, depoimentos). A spec de domínio (`niveis-e-score.md`) deixa **explicitamente em aberto para DDR** a visibilidade dos depoimentos: *"nome do estabelecimento visível, autor individual da avaliação não" (sugestão a ratificar)*. Sem decisão de design e telas plugadas no shell (EPIC-012), a implementação não tem fonte de verdade visual.

- Épico: `epics/EPIC-004-avaliacao-reciproca/epic.md`
- Spec: `docs/especificacao/domain/niveis-e-score.md` (visibilidade), `screens/README.md` (inventário).
- Fundação: DDR-001 (DS, chrome por perfil, breakpoints), DDR-002 (pt-BR/24h), DDR-003 (shell de navegação — as telas nascem dentro dele).

## O quê (objetivo desta estória)

1. **DDR-004 — visibilidade de depoimentos**: decidir nominal × anônimo (autor individual, nome do estabelecimento, papel), ordenação (mais recentes), quantidade no perfil (até 3 na visão expandida — spec), e tratamento de avaliação sem comentário (não vira depoimento).
2. **SCREEN specs + protótipo navegável**:
   - Tela de avaliação **profissional → contratante** (estrelas obrigatórias 1–5 + comentário opcional).
   - Tela de avaliação **contratante → profissional** (idem).
   - Atualização do **perfil**: score público (1 casa, ex. 4.9★), nível + badge (Iniciante/Confiável/Destaque/Elite), XP atual e XP até o próximo nível, depoimentos (até 3).
   - **UX do gate bloqueante**: como o bloqueio aparece (mensagem + link para o turno pendente) ao tentar candidatar-se/publicar.
3. Tudo dentro do **shell** (DDR-003), responsivo (mobile profissional / desktop contratante), AA por construção (consome tokens — sem reabrir a dívida de a11y parqueada).

## Por quê (valor para o usuário)

Avaliação e reputação são onde a confiança bilateral se materializa para usuários não-técnicos; telas claras e um gate compreensível fecham o ciclo sem fricção.

## Critérios de aceite

- [ ] **CA-1:** DDR-004 `accepted` (aprovação do humano) decide a visibilidade dos depoimentos (autor/estabelecimento/papel), ordenação e quantidade, com justificativa.
- [ ] **CA-2:** SCREEN specs das duas telas de avaliação (estrelas obrigatórias + comentário opcional) + estados (vazio/erro/loading reusando o padrão da STORY-079).
- [ ] **CA-3:** SCREEN spec da atualização do perfil (score/nível/badge/XP/depoimentos) para profissional e contratante (reciprocidade — perfil do contratante também tem score + depoimentos).
- [ ] **CA-4:** SCREEN/spec da UX do gate bloqueante (mensagem + link para turno pendente), coerente com os padrões de erro/bloqueio do DS.
- [ ] **CA-5:** Protótipo navegável aprovado pelo humano; reflexo em `design/system/patterns.md` se surgir padrão composto novo (ex.: rating input, badge de nível).
- [ ] **CA-6:** Tudo dentro do shell (DDR-003), responsivo nos dois tamanhos, consumindo tokens DDR-001 (AA por construção).

## Fora de escopo

- Implementação Flutter — STORY-087/088.
- Modelo de dados/eventos/gate backend — STORY-083 (Arquiteto).
- Aprofundar a dívida de a11y parqueada (telas pesadas/teclado) — as telas novas só não devem regredir o piso AA.

## Padrões de qualidade exigidos

`docs/skills/po/references/quality-standards.md` + `docs/skills/designer/references/*`. Protótipo é fonte de verdade visual; humano aprova antes de implementação.

## Dependências

- **Bloqueada por:** DDR-003 (shell — `accepted`), STORY-067/EPIC-012 (perfil já existe no shell).
- **Bloqueia:** STORY-087 e STORY-088 (telas e perfil não se codificam sem spec/protótipo).
- **Coordena com:** STORY-083 (o modelo de dados define o que a tela captura/exibe).

## Decisões já tomadas (não as reabra)

- DDR-001/002/003, PDR-005 (obrigatoriedade), MVP cuts do `epic.md` (sem nível de contratante, sem decay).

## Liberdade técnica do agente

Decide: layout das telas, componente de rating, badge de nível, forma do gate. NÃO decide: obrigatoriedade da avaliação (PDR-005), MVP cuts, padrão de navegação (DDR-003).

## Definição de Pronto (DoD)

- [ ] DDR-004 `accepted` + indexado; SCREEN specs + protótipo aprovados pelo humano.
- [ ] `index.json` atualizado: status = `done`; SCREEN(s) indexadas. "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

`docs/skills/po/references/agent-task-format.md` + skill `designer`.

## Notas do agente (preenchido durante/após execução)

### Decisões
- **DDR-004 `accepted`** (ratificado pelo dono em chat, 2026-06-09). Duas escolhas-núcleo:
  - **Visibilidade do autor — assimétrica:** depoimento **sobre profissional** mostra **nome do estabelecimento + função + data** (PJ/marca pública, dá credibilidade); depoimento **sobre contratante** mostra **"Profissional" + função + data**, **sem nome individual** (pessoa física — LGPD + proteção contra retaliação). Descartadas: anônimo total (perde credibilidade) e nominal nos dois lados (expõe pessoa física — inaceitável).
  - **Score com poucos dados — selo "Novo":** com `< 3` avaliações, mostra selo "Novo na plataforma" (+ contagem) em vez da média; a partir de 3, média 1-casa. Limiar `3` é parâmetro de produto (`business-rules.md`), não fixado pelo design.
  - Regras derivadas: ordenação mais-recente-primeiro; até 3 depoimentos no perfil + "Ver todas (N)"; avaliação **sem comentário não vira depoimento** (conta no score, não na lista); data relativa pt-BR (> ~30 dias → data absoluta).
- **SCREEN-STORY-084-avaliacao-e-perfil** (`ready`) cobre as 4 superfícies: T1/T2 avaliação (estrelas obrigatórias + comentário opcional), T3 perfil (score/nível/XP/depoimentos — nível/XP só profissional, reciprocidade no score), T4 UX do gate. Todos os estados especificados (vazio/loading/erro/sem-permissão/parcial/1ª-vez). Protótipo HTML navegável mobile+desktop, tokens reais, microcopy = §5, dentro do shell (DDR-003).
- **DS atualizado** na mesma operação: `input.rating`, `display.rating`, `badge.nivel`, `meter.xp`, `card.depoimento`, `badge.novo` (componentes) e `pattern.gate-avaliacao`/`banner.gate` (padrão). Nenhuma exceção ao DS.

### Descobertas
- A tela de Perfil já existe no shell (`apps/webapp/lib/features/app/perfil_screen.dart`) como placeholder declarado ("score e depoimentos chegam em épicos futuros") — T3 **estende** o destino, não cria tela nova; o bloco de reputação entra acima de Preferências/Sair.
- **Risco LGPD para o back (anotado p/ STORY-085/088):** o contrato de leitura de depoimentos do **contratante** NÃO deve trafegar `autor_id`/nome do profissional ao cliente — só papel, função, estrelas, comentário, data. A assimetria do DDR-004 precisa ser garantida no payload, não só no front.
- Componentes de reputação (`display.rating`/`badge.nivel`) também aparecem hoje no feed/detalhe-vaga/painel-candidatos (SCREEN-048/049/051) com tratamento ad-hoc — migração para os componentes do DS fica anotada como dívida não-bloqueante desta sprint.

### Bloqueios
- Nenhum. Protótipo **aprovado pelo dono em 2026-06-09** (sem ajustes) — `prototype_last_validated_at` registrado no spec. CA-1..CA-6 e DoD satisfeitos; STORY-087/088 destravadas com confiança visual.
