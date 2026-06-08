---
epic_id: EPIC-012
slug: shell-navegacao-e-ux
title: Shell de navegação e pente fino de UX do WebApp
wave: WAVE-2026-01
status: ready
owner_role: po
created_at: 2026-06-08
updated_at: 2026-06-08
target_completion: 2026-06-30  # estimativa orientativa, não compromisso rígido
---

# EPIC-012 — Shell de navegação e pente fino de UX do WebApp

## Por que existimos (problema do usuário)

A WAVE-2026-01 construiu o WebApp **tela a tela**: cada estória entregou a sua própria porta de entrada (ícone na AppBar, rota direta) sem uma estrutura de navegação global. O resultado é funcionalmente completo no caminho feliz, mas **navegacionalmente fragmentado** — não há um mapa do produto, não há troca rápida de contexto, e o usuário precisa "saber a rota" em vez de "ver o caminho".

O **Contratante** (gestor de operação de hotel/restaurante/evento) opera majoritariamente no **desktop**, em jornada longa de gestão de escala — e hoje não tem um menu lateral que dê visão do todo. O **Profissional** (garçom, cozinheiro, recepcionista) opera majoritariamente no **mobile**, em pé e na rua — e não tem uma barra de navegação inferior persistente. Ambos são pessoas **não-técnicas**: a navegação precisa ser óbvia, não aprendida. Além da navegação, as telas já entregues carregam pequenas inconsistências (estados vazios/erro/carregamento ad-hoc, foco/contraste/microcopy variáveis) que somadas pesam na percepção de qualidade.

## Resultado esperado (outcome)

Ao fim deste épico, **Contratante e Profissional navegam o WebApp por um shell coerente e responsivo** — menu lateral (rail/drawer) no desktop, navegação inferior no mobile — e percebem um produto **consistente e fácil de usar**, com estados vazios/erro/carregamento padronizados e acessibilidade AA em todas as telas tocadas.

## Métrica de sucesso (como saberemos que funcionou)

- Métrica primária: **100% das telas autenticadas do WebApp** (profissional e contratante) são alcançáveis a partir do shell, sem digitar rota — verificável navegando em homologação a partir do destino inicial de cada papel.
- Métrica de qualidade: contraste **WCAG AA** (4.5:1 texto / 3:1 ícone) e navegação por teclado verdes no gate automatizado (axe/lighthouse) em todas as telas tocadas; zero estado vazio/erro sem microcopy + próximo passo.
- Métrica de responsividade: o shell colapsa corretamente nos breakpoints do DDR-001 (compact/medium/expanded/large) sem "mobile esticado" nem "desktop encolhido" — verificável em homologação nos dois tamanhos.

## Entregável visível no fim do épico

- [ ] Em `app.homolog.turni.com.br`, **Contratante** entra e vê um **menu lateral** (rail/drawer no desktop) com todos os destinos do seu papel; troca de contexto em 1 clique; o menu colapsa para navegação inferior no mobile.
- [ ] **Profissional** entra e vê uma **navegação inferior** persistente no mobile com seus destinos; no desktop a mesma navegação vira rail lateral.
- [ ] Todas as telas já entregues (feed, vagas, candidatos, turnos, detalhe, notificações, perfil) estão **plugadas no shell** — nenhuma fica órfã.
- [ ] Estados **vazios, de erro e de carregamento** padronizados nas telas do WebApp (instrução + próximo passo; erro recuperável com "tentar de novo").
- [ ] Acessibilidade **AA** verificada (contraste, foco visível, teclado, alvos de toque ≥48dp, ícones com label) nas telas tocadas.
- [ ] **DDR-003** (padrão de navegação global) `accepted` e refletido em `design/system/patterns.md`.

## Fora de escopo (explicitamente)

- **Backoffice admin** — já é desktop-first com sidebar própria (`design/system/preview-backoffice.html`); fica fora deste épico.
- **EPIC-004 (avaliação recíproca)** e qualquer feature de produto nova — este épico não adiciona funcionalidade de negócio, só estrutura de navegação e qualidade das telas existentes.
- **Notificações push web (PWA)** — fora do MVP por current-wave.
- **Redesenho visual de marca / nova paleta** — a fundação do DS (DDR-001) é mantida; o épico consome os tokens existentes, não os redefine.
- **Novas telas** que não existam hoje (ex.: dashboard analítico do contratante) — só plugamos o que já foi entregue.

## Referências da especificação

- `docs/especificacao/glossary.md` — termos canônicos (Profissional, Contratante, Vaga, Turno).
- `docs/especificacao/non-functional.md` — NFRs de acessibilidade (WCAG AA), texto mínimo, pt-BR.
- `docs/especificacao/screens/README.md` — inventário de telas por papel (comportamento esperado).
- `docs/project-state/design/system/tokens.md` — breakpoints Material 3 (§5.6), esquema de cor por perfil (chrome/sidebar).
- `docs/project-state/design/system/patterns.md` — catálogo de padrões compostos (a ser preenchido com o padrão de navegação).
- `docs/prototipo/app.html` — fonte de verdade visual do produto (sidebar pintada por perfil — DDR-001).

## Dependências

- **Bloqueia:** EPIC-004 (avaliação recíproca) passa a nascer dentro do shell — recomendável (não obrigatório) que comece após este épico.
- **Bloqueado por:** nenhum — EPIC-003 já fechado; ambiente de homologação operante.
- **Decisões necessárias antes da implementação:** **DDR-003** (padrão de navegação) produzido pela STORY-076 (spike de Designer) antes das estórias de implementação. ADR-001 (Flutter) e ADR-007 (RBAC por papel) já vigentes cobrem stack e papéis; se o spike revelar decisão de roteamento de baixo nível, o Programador registra IDR.

## Estórias

- [x] STORY-076 — Spike Designer: padrão de navegação global do WebApp (DDR-003) + protótipo navegável
- [x] STORY-077 — App shell adaptativo (rail/drawer desktop ↔ navegação inferior mobile) + destinos por papel + roteamento
- [ ] STORY-078 — Migrar as telas existentes do WebApp para o shell (nenhuma órfã) + contexto/título no desktop
- [ ] STORY-079 — Padronizar estados vazios, de erro e de carregamento (skeleton) nas telas do WebApp
- [ ] STORY-080 — Auditoria de acessibilidade AA + navegação por teclado + alvos de toque + microcopy
- [ ] STORY-081 (validação) — Validação final do épico

## Validação final

Critérios em `validation/checklist.md`. Relatório do validador em `validation/report.md`.

**Definição de épico concluído:** todas as estórias `done` + relatório de validação `approved` (ou `approved_with_pending` assumido pelo PO como goal-atingido) + shell de navegação demonstrável em homologação nos dois papéis e nos dois tamanhos.

## Histórico

- 2026-06-08 — criado por PO (Alexandro / Claude) a partir de PDR-018. Escopo: shell de navegação + pente fino de UX; superfícies WebApp contratante (desktop) + profissional (mobile); Backoffice fora.
