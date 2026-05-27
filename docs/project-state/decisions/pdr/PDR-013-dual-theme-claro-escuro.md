---
pdr_id: PDR-013
slug: dual-theme-claro-escuro
title: Dual-theme (claro + escuro) suportado no produto; tema padrão do MVP = claro
status: accepted
decided_at: 2026-05-27
decided_by: PO (Alexandro / Claude)
supersedes: null
superseded_by: null
related_epics: [EPIC-000, EPIC-001]
related_adrs: [ADR-001]
---

# PDR-013 — Dual-theme (claro + escuro); padrão do MVP = claro

## Contexto

Ao redigir a fundação do Design System (DDR-001, STORY-010), o Designer verificou que o protótipo PWA (`docs/prototipo/app.html`) **já implementa dois temas** — claro (`:root`) e escuro (`[data-theme="dark"]`) — com detecção de `prefers-color-scheme` e toggle persistido por usuário, além de **esquema de cor por perfil** (profissional/contratante/admin) nos dois temas.

Algumas estórias (ex.: STORY-008) registraram, em "Fora de escopo", que "tema escuro está fora do MVP", **atribuindo a `non-functional.md`**. Porém o `non-functional.md` é **silente** sobre temas — não há decisão registrada de produto que sustente "dark fora do MVP". Ou seja: havia uma suposição não-decidida circulando nas estórias. Como dono do produto, o Alexandro precisou decidir: o MVP suporta os dois temas, ou só o claro?

## Opções consideradas

### Opção 1 — Só tema claro no MVP; escuro depois
- Descrição: formaliza apenas o tema claro; o escuro fica para uma onda futura.
- Prós: menos superfície a manter/testar agora.
- Contras: **descarta trabalho já pronto** (o escuro existe e é rico no protótipo); gera retrabalho quando voltar; ignora a realidade do `app.html`.

### Opção 2 — Suportar os dois temas; padrão do MVP = claro
- Descrição: o Design System **define e mantém** claro e escuro (neutros, acentos por perfil, semânticas em ambos). Seleção por `prefers-color-scheme` + toggle persistido. O **tema padrão de entrega do MVP é o claro** (melhor para a página pública/3G e coerente com o `background_color` do manifest); o escuro fica disponível.
- Prós: zero retrabalho — aproveita o que o protótipo já entrega; coerência total com `app.html`; respeita preferência do usuário (acessibilidade/conforto).
- Contras: mais pares de contraste a verificar (já feito em `tokens.md §6`) e mais a testar visualmente.

### Opção 3 — Status quo (silêncio)
- Consequência: a suposição "dark fora do MVP" continua não-decidida, citada por estórias sem lastro — fonte de divergência futura.

## Decisão

> **Optamos pela Opção 2.**

O produto Turni **suporta os dois temas (claro e escuro)** em todas as interfaces, com seleção por preferência do sistema (`prefers-color-scheme`) e toggle persistido por usuário. O **tema padrão do MVP é o claro**. O Design System (DDR-001) define ambos os temas e o esquema de cor por perfil (profissional/contratante/admin) em cada um.

## Justificativa

O tema escuro **não é trabalho novo** — já está no protótipo, que é a fonte de verdade desta fase. Tratá-lo como "fora do MVP" criaria retrabalho e contrariaria o `app.html`. Suportar os dois respeita a preferência do usuário (profissional usa o app em luz forte na rua e à noite; admin opera horas no backoffice) sem custo de fundação adicional, já que a verificação de contraste AA dos dois temas já foi feita em DDR-001.

## Consequências

### Positivas
- Fundação visual cobre o produto real (multi-tema, multi-perfil) sem refazer depois.
- Respeita `prefers-color-scheme` — conforto e acessibilidade.
- Coerência com o protótipo preservada.

### Negativas / trade-offs aceitos
- Mais combinações a testar visualmente (tema × perfil). Mitigado pela tabela de contraste de DDR-001 e por preview de validação.
- O hello-world do EPIC-000 (STORY-008/009) entrega o **tema claro** como padrão; suporte a escuro nessas telas placeholder é opcional, não bloqueante.

### Para o time técnico
- ADRs/IDRs: estratégia de theming no Flutter (um `ThemeData` por perfil × brilho via `ColorScheme.fromSeed`; seleção espelhando `initTheme()` do protótipo) — detalhe em DDR-001 §"Implementação sugerida".
- Impacto em épicos: EPIC-000 entrega claro; EPIC-001 em diante consome os esquemas por perfil nos dois temas.

## Atualização de especificação

`docs/especificacao/non-functional.md` recebe seção **"Temas (aparência)"** registrando o suporte dual-theme e o padrão claro — fechando a lacuna que as estórias haviam atribuído erroneamente ao documento.

## Sinais de revisão

- Se o custo de manter/testar os dois temas virar gargalo real de entrega, reavaliar reduzir o escopo de telas com dark garantido (mantendo a fundação).
- Se métricas de uso mostrarem adoção desprezível de um dos temas, reconsiderar o padrão.
