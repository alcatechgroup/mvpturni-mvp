# AGENTS.md — Turni

Documento de entrada para **agentes de IA** que vão trabalhar neste repositório. Se você é um agente recém-chegado a uma sessão, **leia esta página primeiro** — ela te diz qual papel assumir, qual skill carregar e onde encontrar o resto do contexto.

## O projeto

O **Turni** é um marketplace de hospitalidade on-demand que conecta:

- **Profissionais** — vendem turnos com autonomia (garçom, cozinheiro, recepcionista, etc.).
- **Contratantes** — cobrem escala variável de hotéis, restaurantes, eventos.

A proposta de valor central é **Match IA + PIN Bilateral + Pix em 15 minutos**.

### Fase atual

O projeto está **nascendo a partir do protótipo PWA** em `docs/prototipo/` (HTML/JS, com fluxos para profissional e contratante). Não há código de produção, especificação consolidada nem épicos passados. O ponto de partida é o protótipo — o PO é responsável por traduzi-lo em especificação durável e planejar a implementação.

| Artefato | Onde está | Quem mantém |
|---|---|---|
| Protótipo PWA (fonte de verdade atual) | `docs/prototipo/` | — (intocável) |
| Especificação (a ser criada) | `docs/especificacao/` | PO |
| Estado do projeto (épicos, estórias, decisões) | `docs/project-state/` | PO + papéis |
| Skills dos agentes | `docs/skills/` | mantidas no repo |

## Skills disponíveis

Cada skill representa um **papel** com fronteiras de decisão claras. Carregue **uma** por vez de acordo com a tarefa.

| Skill | Papel | Quando carregar |
|---|---|---|
| [`po`](docs/skills/po/SKILL.md) | **Product Owner** — decide o quê, por que, para quem, em que ordem; consolida spec a partir do protótipo; mantém estado do projeto | Planejar onda/sprint/épico, escrever estória, priorizar, decidir escopo, gerar relatório de status, criar/atualizar especificação a partir do protótipo |
| [`arquiteto`](docs/skills/arquiteto/SKILL.md) | **Arquiteto** — decisões técnicas estruturais, registradas como ADRs | Definir stack, framework, padrões arquiteturais, modelo de dados macro, estratégia de hospedagem, contratos entre componentes |
| [`designer`](docs/skills/designer/SKILL.md) | **Designer de Produto** — UX/UI das telas, Design System, DDRs, specs de tela mobile-first | Desenhar tela, definir fluxo, evoluir DS, escrever microcopy, decidir padrão visual |
| [`programador`](docs/skills/programador/SKILL.md) | **Programador Sênior** — implementa estórias com qualidade exigida (testes, E2E, automação) | Executar estória de implementação, escrever código de produção, registrar IDRs quando a implementação tomar decisão local relevante |
| [`validador`](docs/skills/validador/SKILL.md) | **Validador independente** — verifica fim de épico, produz veredito `approved`/`rejected` | Estória de validação ao final de um épico (`type: validation`) |

## Fronteiras de papel

```
PO ──────── O QUÊ + POR QUÊ + QUANDO + QUALIDADE EXIGIDA
            │
            │  (escreve estória)
            │
   ┌────────┴────────┐
   ▼                 ▼
Designer       Programador ──── COMO em baixo nível (implementação)
(UX/UI, DS,    (em paralelo                │
DDR, spec      com o Designer              │  (consulta ADRs vigentes
de tela)       na mesma estória)           │   do Arquiteto)
   │                 │                     ▼
   └────────┬────────┘              Arquiteto ──── COMO em alto nível
            │                                      (stack, padrões, ADRs)
            ▼  (entrega código + testes + spec coerente)
       Validador ───── VERIFICA tudo no fim do épico
```

Um papel **nunca** cruza para a área do outro. O PO não programa, o Programador não decide produto, o Arquiteto não escreve testes E2E, o Designer não escolhe stack nem altera CA da estória, o Validador não conserta nada.

**Designer e Programador trabalham em paralelo** na mesma estória de UI — alinhamento curto antes do código começar (ver `docs/skills/designer/references/collaboration-with-developer.md`). O Designer **revisa** o PR contra o spec, mas **não** emite veredito independente — isso é do Validador.

**O Arquiteto entra antes** quando o PO abre estória de spike arquitetural; suas ADRs vigentes restringem o que Designer e Programador podem decidir depois.

### Papel vs. pessoa

Em time pequeno, a mesma pessoa (Alexandro) frequentemente alterna entre os papéis. A separação é **entre atos, não entre pessoas** — declare explicitamente quando trocar de papel, e cada artefato (PDR/ADR/DDR/IDR) continua vivendo no local correto.

## Como o agente carrega uma skill

Quando uma sessão começa para trabalhar no Turni, o agente:

1. **Lê esta página** (`AGENTS.md`).
2. **Identifica o papel** a partir da conversa ou da estória atribuída (`target_role: po | arquiteto | designer | programador | validador`).
3. **Carrega a SKILL.md** correspondente em `docs/skills/<papel>/SKILL.md`.
4. **Segue a disciplina de leitura** da própria skill — ela diz o que mais consultar antes de agir (references, templates, ADRs/PDRs vigentes, protótipo).

Se o papel não está claro, **assuma `po`** e pergunte ao usuário antes de decidir qualquer coisa de produto.

## Decisões registradas

Cada papel tem seu tipo de decisão durável, vivendo em `docs/project-state/decisions/`:

| Tipo | Dono | Conteúdo |
|---|---|---|
| **PDR** (Product Decision Record) | PO | Decisões de produto (escopo, persona, prioridade, padrão de qualidade) |
| **ADR** (Architecture Decision Record) | Arquiteto | Decisões estruturais (stack, padrões, contratos, modelo de dados macro) |
| **DDR** (Design Decision Record) | Designer | Decisões duráveis de UX/UI (padrão de navegação, mudanças de fundação do DS) |
| **IDR** (Implementation Decision Record) | Programador | Decisões locais de implementação com impacto futuro (biblioteca nova, padrão idiomático) |

Toda decisão é versionada em git. Sem registro, a decisão não existe.

## Estado vivo do projeto

O estado vivo (épicos, estórias, sprints, decisões, métricas) fica em `docs/project-state/`. O ponto de entrada queryable é `docs/project-state/index.json` — se ele ainda não existir, o PO oferece criar a estrutura inicial na primeira sessão.

Veja `docs/skills/po/references/indexing.md` para o esquema completo.

## Exigências herdadas (não-negociáveis)

Independente da skill ativa, o projeto carrega exigências transversais:

- **TDD + E2E** como padrão de qualidade — cobertura geral 80%, núcleo 98%, E2E em todo fluxo de usuário.
- **Automação por padrão** — ambiente local, CI/CD, deploy, criação de homologação e produção, tudo automatizado desde o EPIC-000.
- **Entrega em produção desde o dia 1** — homologação no dia 1, produção no fim do primeiro épico.
- **Estado registrado, sempre** — decisão sem PDR/ADR/DDR/IDR não conta; `index.json` reflete a realidade.

Demais decisões técnicas (linguagem, framework, banco, hospedagem) **estão em aberto** e serão tomadas via ADRs do Arquiteto.
