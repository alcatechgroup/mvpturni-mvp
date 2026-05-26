# Turni

> **Hospitalidade on-demand** — a plataforma onde **profissional vende turnos com autonomia** e **contratante cobre escala que muda**.
>
> Match IA · PIN Bilateral · Pix em 15 minutos.

Este repositório é o monorepo do produto **Turni**. Hoje contém o **protótipo PWA navegável** e a **documentação operacional** (skills de agentes, decisões, processo). O código de produção ainda não existe — a stack será definida pelo Arquiteto a partir do protótipo.

## Estado do projeto

- ✅ **Protótipo PWA** navegável em `docs/prototipo/` (HTML/JS, mobile-first).
- ⏳ **Especificação consolidada** — a ser escrita pelo PO a partir do protótipo, em `docs/especificacao/`.
- ⏳ **Stack técnica** — a ser decidida pelo Arquiteto em ADRs, a partir da especificação.
- ⏳ **Implementação** — começa após o primeiro spike de arquitetura.

## Como navegar o protótipo

O protótipo é um **PWA estático** — basta abrir o HTML em qualquer browser moderno.

```bash
# Opção 1: abrir diretamente
open docs/prototipo/index.html

# Opção 2: servir localmente (recomendado para que o service worker e o manifest funcionem)
cd docs/prototipo && python3 -m http.server 8080
# depois acesse http://localhost:8080
```

Arquivos principais:

| Arquivo | O que é |
|---|---|
| `docs/prototipo/index.html` | Landing/apresentação do produto |
| `docs/prototipo/app.html` | Aplicação navegável (fluxos do profissional e do contratante) |
| `docs/prototipo/manifest.json` | Manifesto PWA (nome, tema, ícones, atalhos) |
| `docs/prototipo/sw.js` | Service Worker |
| `docs/prototipo/tour.js`, `tour.css` | Tour guiado pela interface |

## Estrutura do repositório

```
mvpturni-mvp/
├── AGENTS.md                 ← ponto de entrada para agentes de IA
├── README.md                 ← este arquivo (humanos)
├── docs/
│   ├── prototipo/            ← protótipo PWA (fonte de verdade atual)
│   ├── especificacao/        ← especificação consolidada (a ser criada pelo PO)
│   ├── skills/               ← skills dos agentes (PO, Arquiteto, Designer, Programador, Validador)
│   └── project-state/        ← estado vivo (épicos, estórias, sprints, decisões) — criado pelo PO na primeira sessão
└── .github/                  ← workflows, templates de issue/PR
```

## Skills de agentes

O projeto é construído por **agentes de IA** atuando em 5 papéis distintos, cada um com fronteiras claras de decisão:

| Papel | Skill | Responsabilidade |
|---|---|---|
| Product Owner | [`docs/skills/po`](docs/skills/po/SKILL.md) | O quê, por quê, para quem, em que ordem; spec a partir do protótipo |
| Arquiteto | [`docs/skills/arquiteto`](docs/skills/arquiteto/SKILL.md) | Stack, padrões, ADRs |
| Designer | [`docs/skills/designer`](docs/skills/designer/SKILL.md) | UX/UI, Design System, DDRs |
| Programador | [`docs/skills/programador`](docs/skills/programador/SKILL.md) | Implementação com TDD + E2E, IDRs |
| Validador | [`docs/skills/validador`](docs/skills/validador/SKILL.md) | Verificação independente ao fim de cada épico |

Detalhes operacionais — como um agente carrega uma skill, fronteiras entre papéis, decisões herdadas — estão em [`AGENTS.md`](AGENTS.md).

## Princípios herdados (não-negociáveis)

Independente da stack que vier a ser escolhida:

1. **Entrega em produção desde o dia 1** — homologação no dia 1, produção no fim do primeiro épico.
2. **TDD + E2E** como exigência de qualidade — 80% cobertura geral, 98% em núcleo de regras de negócio.
3. **Automação por padrão** — ambiente local, CI/CD, deploy, homologação e produção, tudo automatizado.
4. **Estado registrado, sempre** — toda decisão durável vira PDR/ADR/DDR/IDR versionado em git.

## Próximos passos

Para arrancar o projeto:

1. **PO** lê o protótipo (`docs/prototipo/`) e consolida a primeira versão da especificação em `docs/especificacao/`.
2. **PO** abre a primeira onda em `docs/project-state/` com um EPIC-000 de fundação (pipeline, homologação, hello world).
3. **Arquiteto** propõe a stack em ADRs durante o spike inicial.
4. **Designer** + **Programador** começam a primeira estória de UI em paralelo.

## Para contribuintes humanos

- Use a skill correspondente ao seu papel ao operar o projeto via agente — declare a troca de papel explicitamente quando alternar.
- Toda decisão durável precisa de registro (PDR/ADR/DDR/IDR). Sem registro, a decisão não existe.
- Em dúvida sobre papéis ou fluxo, comece por [`AGENTS.md`](AGENTS.md) e pela skill do PO em [`docs/skills/po/SKILL.md`](docs/skills/po/SKILL.md).
