# Especificação do Turni

Contrato durável do produto Turni — vocabulário, entidades, regras de negócio, fluxos, requisitos não-funcionais. Conforme esta especificação for ficando completa, ela passa a ser a fonte de verdade canônica do produto; até lá, o protótipo em `docs/prototipo/` continua sendo referência viva.

## Como navegar

- **`glossary.md`** — vocabulário canônico do domínio.
- **`domain/`** — entidades e regras versionadas, uma por área:
  - `usuario.md` — perfis, tipos de pessoa, papéis, ciclo de vida.
  - `vaga.md` — publicação, edição, estados.
  - `candidatura.md` — envio, aceite, retirada.
  - `turno.md` — máquina de estados completa do turno.
  - `pagamento.md` — modelo financeiro, taxa, Pix, Pagar.me.
  - `match.md` — algoritmo, score, breakdown.
  - `niveis-e-score.md` — trilha de níveis, XP, perks.
  - `compliance.md` — habitualidade, zonas, bloqueios.
  - `avaliacao.md` — score recíproco, obrigatoriedade.
  - `disputa.md` — fluxo de mediação no admin.
- **`flows/`** — fluxos ponta-a-ponta do ponto de vista do usuário, atravessando entidades. Cada arquivo descreve um fluxo completo (`cadastro-e-aprovacao.md`, `publicar-vaga.md`, `feed-e-candidatura.md`, etc.).
- **`screens/`** — inventário de telas por papel, referenciando o protótipo. O detalhe visual é do Designer; aqui fica o **comportamento** esperado de cada tela.
- **`non-functional.md`** — SLAs, NFRs, promessas operacionais públicas (Pix 15 min, match 2h, geofencing 100m, etc.).
- **`business-rules.md`** — taxas, planos, números — coisa que muda com decisão de produto e precisa ser localizável.

## Como esta spec é mantida

- PO é o dono. Cada decisão durável vira PDR em `docs/project-state/decisions/pdr/` e atualiza a spec correspondente.
- Estórias referenciam a spec por caminho. Sem cópia de conteúdo grande.
- A spec não tem código — só comportamento. Decisão técnica vai para ADR; decisão de design vai para DDR.

## Estado atual

Esta primeira versão estabelece o esqueleto. Os arquivos do domínio carregam o núcleo das regras já decididas em PDRs. Áreas com lacuna (ex: `disputa.md`, `avaliacao.md`) carregam o que está decidido e marcam explicitamente o que ainda depende de spike ou novo PDR.
