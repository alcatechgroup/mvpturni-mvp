# Turni

> **Hospitalidade on-demand** — a plataforma onde **profissional vende turnos com autonomia** e **contratante cobre escala que muda**. Match IA · PIN Bilateral · Pix em 15 minutos.

Monorepo do produto **Turni**: backend e Backoffice em Laravel, WebApp em Flutter, domínio compartilhado, mais a documentação operacional (especificação, decisões, skills de agentes). Ponto de entrada para agentes de IA: [`AGENTS.md`](AGENTS.md). Estado vivo do projeto (épicos, estórias, sprints, decisões): [`docs/project-state/`](docs/project-state/).

## Rodar localmente em 1 comando

Pré-requisitos (instale antes):

- **Docker** + **Docker Compose** (Docker Desktop recente).
- **Flutter SDK** ≥ 3.41 (runtime do WebApp; PHP/Composer rodam em container, não precisam estar no host).

Da raiz do repositório, **um único comando** leva de "acabei de clonar" até tudo rodando com dados de seed:

```bash
make setup
```

Isso cria os `.env` a partir dos `.env.example`, constrói as imagens, instala dependências, sobe o PostgreSQL, aplica migrações, semeia o admin de teste, builda o WebApp e instala o hook de pré-push. Ao final:

| Serviço | URL local |
|---|---|
| API (Laravel, JSON) | http://localhost:8001 |
| Backoffice (Livewire) | http://localhost:8002 |
| WebApp (Flutter Web) | http://localhost:8003 |
| Mock do Pagar.me | http://localhost:8090 |
| PostgreSQL | localhost:5433 (interno 5432) |

Runs subsequentes (sem rebuild):

```bash
make up
```

### Comandos auxiliares

```bash
make test     # suíte completa: unit + integração (Postgres real) + cobertura + widget tests
make lint     # Laravel Pint (formatação)
make migrate  # aplica migrações (idempotente)         make seed   # popula seed (idempotente)
make fresh    # recria o schema e ressemeia (DEV — apaga dados)
make down     # para tudo                              make clean  # para e apaga volumes (zera o banco)
make logs     # segue os logs                          make ps     # estado dos serviços
make help     # lista todos os comandos
```

O **hook de pré-push** (instalado por `make hooks`, já chamado no `make setup`) roda detector de segredos + a suíte de testes antes de cada `git push`; se algo falhar, o push é abortado.

## Estrutura do repositório

```
mvpturni-mvp/
├── apps/
│   ├── api/            # Laravel — API JSON pública (cliente: WebApp Flutter)
│   ├── admin/          # Laravel + Livewire — Backoffice (rede restrita em prod)
│   └── webapp/         # Flutter — WebApp (web no MVP; nativo no futuro)
├── packages/
│   ├── domain/         # PHP — domínio compartilhado (Composer path repository)
│   └── design-tokens/  # fonte única de design tokens (Designer/DDR-001)
├── contracts/          # contrato de API (OpenAPI) — gera cliente Dart do WebApp
├── infra/docker/       # Dockerfiles: imagem PHP compartilhada, mock Pagar.me, initdb do Postgres
├── scripts/hooks/      # hooks de git versionados (pré-push)
├── docker-compose.yml  # sobe api + admin + worker + postgres + pagarme-mock + webapp
├── Makefile            # comando único e utilitários
├── docs/               # protótipo, especificação, skills de agentes, project-state (decisões)
└── AGENTS.md           # ponto de entrada para agentes de IA
```

Arquitetura: monolito modular Laravel com domínio compartilhado e duas camadas de entrega (`api`, `admin`) + `worker`, tudo sobre um único PostgreSQL — ver `docs/project-state/decisions/adr/` (ADR-001 stack, ADR-002 topologia, ADR-003 monorepo) e `docs/project-state/decisions/idr/IDR-001` (fundação do ambiente local).

## Protótipo PWA

O protótipo navegável original segue em `docs/prototipo/` (HTML/JS, mobile-first):

```bash
open docs/prototipo/index.html
# ou, para service worker/manifest funcionarem:
cd docs/prototipo && python3 -m http.server 8080   # http://localhost:8080
```

## Skills de agentes

O projeto é construído por **agentes de IA** em 5 papéis com fronteiras de decisão claras:

| Papel | Skill | Responsabilidade |
|---|---|---|
| Product Owner | [`docs/skills/po`](docs/skills/po/SKILL.md) | O quê, por quê, para quem, em que ordem; spec a partir do protótipo |
| Arquiteto | [`docs/skills/arquiteto`](docs/skills/arquiteto/SKILL.md) | Stack, padrões, ADRs |
| Designer | [`docs/skills/designer`](docs/skills/designer/SKILL.md) | UX/UI, Design System, DDRs |
| Programador | [`docs/skills/programador`](docs/skills/programador/SKILL.md) | Implementação com TDD + E2E, IDRs |
| Validador | [`docs/skills/validador`](docs/skills/validador/SKILL.md) | Verificação independente ao fim de cada épico |

Detalhes de fluxo e fronteiras entre papéis: [`AGENTS.md`](AGENTS.md).

## Princípios herdados (não-negociáveis)

1. **Entrega em produção desde o dia 1** — homologação no dia 1, produção no fim do primeiro épico.
2. **TDD + E2E** — 80% cobertura geral, 98% em núcleo de regras de negócio.
3. **Automação por padrão** — ambiente local, CI/CD, deploy, homologação e produção.
4. **Estado registrado, sempre** — toda decisão durável vira PDR/ADR/DDR/IDR versionado em git.
