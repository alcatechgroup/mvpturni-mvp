---
pdr_id: PDR-018
slug: sprint-ux-ui-shell-de-navegacao-antes-do-epic-004
title: Sprint de UX/UI (shell de navegação + pente fino) antes do EPIC-004
status: accepted
decided_at: 2026-06-08
decided_by: PO (Alexandro / Claude)
supersedes: null
superseded_by: null
related_epics: [EPIC-012, EPIC-004]
related_adrs: [ADR-001, ADR-007]
related_pdrs: [PDR-003, PDR-013]
---

# PDR-018 — Sprint de UX/UI (shell de navegação + pente fino) antes do EPIC-004

## Contexto

A WAVE-2026-01 entregou, do EPIC-000 ao EPIC-003, o ciclo completo do turno vivo em homologação: cadastro/aprovação, publicação de vaga, feed com match, candidatura, aceite, PIN bilateral, cronômetro e Pix (fake — PDR-017). A onda foi construída **tela a tela**: cada estória entregou a sua porta de entrada própria (ícone na AppBar, rota direta), sem um **shell de navegação global**. A nota da STORY-059 documenta isso explicitamente — a porta de entrada de "Meus turnos" foi um ícone na AppBar "sem introduzir NavigationBar (seria DDR)". O `design/system/patterns.md` confirma: a v0.1 do Design System **não cataloga padrões compostos de navegação**.

O resultado é um WebApp funcionalmente completo no caminho feliz, mas com navegação fragmentada. O **Contratante**, que opera majoritariamente no **desktop** (gestão de escala, jornada longa — PDR-003), não tem um menu lateral que dê visão do todo e troca rápida de contexto. O **Profissional**, que opera majoritariamente no **mobile** (em pé, na rua), não tem uma barra de navegação inferior persistente. Ambos os perfis precisam de uma estrutura de navegação coerente e **responsiva** (mobile + desktop no mesmo codebase Flutter — ADR-001).

Ao fechar a W28, o PO registrou o compromisso de uma **pausa explícita entre EPIC-003 e EPIC-004** (avaliação recíproca). Essa pausa é a janela natural para endurecer a usabilidade do que já existe **antes** de adicionar a próxima feature de produto.

## Opções consideradas

### Opção 1 — Sprint de UX/UI agora, antes do EPIC-004 (escolhida)
- Descrição: abrir o EPIC-012 (Shell de navegação + pente fino de UX) e rodá-lo na próxima sprint (SPRINT-2026-W29), ocupando a pausa planejada. Só depois iniciar o EPIC-004.
- Prós: melhora a usabilidade de tudo que já foi entregue, antes de empilhar mais features sobre uma navegação frágil; o custo de retrofit da navegação **cresce** a cada nova tela; aproveita a pausa que já estava planejada; o EPIC-004 (avaliação) nasce já dentro do shell.
- Contras: adia o fechamento do ciclo de produto da onda (avaliação recíproca alimenta a métrica de norte); a métrica-alvo da onda não avança nesta sprint.

### Opção 2 — EPIC-004 primeiro, UX/UI depois
- Descrição: rodar avaliação recíproca primeiro (fecha o ciclo da onda) e só então a sprint de UX/UI.
- Prós: a métrica de norte (turno completo = avaliado) ganha baseline antes; mantém a sequência original do roadmap.
- Contras: mais uma tela (avaliação) nasce sem shell e terá de ser migrada depois; a fragmentação de navegação persiste por mais uma sprint, agravando o débito.

### Opção 3 — Status quo (nada mudar)
- Consequência: cada épico futuro continua adicionando telas com porta de entrada ad-hoc; a navegação nunca recebe tratamento de primeira classe; o Contratante segue sem visão de desktop e o débito de retrofit cresce indefinidamente.

## Decisão

> **Optamos pela Opção 1.**

Abrir o **EPIC-012 — Shell de navegação e UX do WebApp** e executá-lo na **SPRINT-2026-W29**, antes do EPIC-004, ocupando a pausa planejada entre épicos. O escopo é **shell de navegação global responsivo + pente fino de UX** das telas já entregues (estados vazios/erro/carregamento, acessibilidade AA, microcopy, consistência). As superfícies são **WebApp Contratante (desktop) e WebApp Profissional (mobile)**, ambas mantidas responsivas para os dois tamanhos. O **Backoffice admin fica fora** — já é desktop-first com sidebar própria.

O **padrão de navegação em si** (qual widget, quais destinos por papel, como colapsa entre breakpoints) é **decisão de design durável** e será registrado pelo Designer como **DDR-003**, produzido na primeira estória do épico (spike de Designer). Como PO, defino o **quê/porquê/qualidade** e a sequência; **não** escolho o widget de navegação.

## Justificativa

A onda demonstrou a tese técnica (os 3 pilares funcionam ponta a ponta). O gargalo de valor agora não é "mais uma feature", é **usabilidade do que já existe** — especialmente para o Contratante no desktop, que hoje navega sem um mapa do produto. Fazer o shell **antes** do EPIC-004 é mais barato (uma tela a menos para migrar) e faz a avaliação recíproca nascer já dentro de uma navegação coerente. A pausa entre épicos já estava planejada por carga cognitiva; preenchê-la com UX/UI converte uma pausa em entrega de valor sem violar o compromisso de descompressão (UX/UI é trabalho de natureza diferente do coração transacional da W28).

## Consequências

### Positivas
- Contratante ganha menu lateral/visão de desktop; Profissional ganha navegação inferior persistente no mobile; ambos responsivos.
- Telas existentes ficam mais consistentes (estados vazios/erro/carregamento padronizados, AA, microcopy).
- O padrão de navegação vira ativo durável (DDR-003) que todas as telas futuras herdam — EPIC-004 em diante já nascem dentro do shell.
- Catálogo de padrões compostos do Design System (`patterns.md`) começa a ser preenchido.

### Negativas / trade-offs aceitos
- O fechamento do ciclo de produto da onda (avaliação recíproca, EPIC-004) é adiado em uma sprint; a métrica-alvo da onda não avança em W29.
- Investir em pente fino antes de ter usuários externos reais é uma aposta de que a base já entregue é a que vai escalar — aceitável porque o shell é estrutural e independe do conteúdo das telas.

### Para o time técnico
- ADRs que esta decisão pode demandar: nenhuma nova prevista (navegação/roteamento Flutter já coberto por ADR-001/ADR-007); se o spike do Designer revelar necessidade de decisão de roteamento de baixo nível, o Programador registra IDR.
- DDR esperado: **DDR-003** (padrão de navegação global do WebApp), produzido na STORY-076.
- Impacto em épicos: EPIC-012 entra na WAVE-2026-01 antes do EPIC-004; EPIC-004 passa a herdar o shell.

## Sinais de revisão

- Se o spike de Designer (STORY-076) concluir que o shell exige decisão arquitetural de roteamento ainda não coberta, pausar a implementação e abrir spike de Arquiteto antes de seguir.
- Se, ao abrir a sprint, surgir pressão de negócio para baseline de avaliação recíproca (métrica de norte) que não possa esperar uma sprint, reavaliar a ordem (volta a ser a Opção 2).
