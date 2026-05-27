---
adr_id: ADR-003
slug: monorepo-vs-polirepo
title: Monorepo poliglota único para api, admin, WebApp e domínio compartilhado
status: accepted  # proposed | accepted | superseded | rejected | deferred
decided_at: 2026-05-27
decided_by: arquiteto
approved_by: Alexandro
supersedes: null
superseded_by: null
related_adrs: [ADR-001, ADR-002]
related_pdrs: [PDR-003]
related_epics: [EPIC-000]
created_at: 2026-05-27
updated_at: 2026-05-27
---

# ADR-003 — Monorepo vs polirepo

## Contexto

PDR-003 exige **duas interfaces** com deploy independente e pede explicitamente uma estratégia para compartilhar **código comum (design tokens, regras de domínio) sem duplicação descontrolada**. Com a stack (ADR-001) e a topologia (ADR-002) decididas, os artefatos do projeto são: o **package de domínio** (PHP/Laravel), o app **`api`** (Laravel JSON), o app **`admin`** (Laravel + Livewire) e o **WebApp** (Flutter/Dart). Falta decidir **como esses artefatos se organizam em repositório(s)** — um monorepo ou múltiplos repos — de modo a compartilhar o que é comum e manter os deploys independentes e a superfície de segurança do admin separada.

Há uma particularidade herdada da stack: o projeto é **poliglota** (PHP + Dart). O compartilhamento de **código de runtime** acontece sobretudo **entre `api` e `admin`** (ambos PHP, sobre o package de domínio — ADR-002). Entre o WebApp (Dart) e o Backoffice (PHP/Livewire) **não há código de runtime comum**: o que se compartilha é o **contrato de API** e os **design tokens**. Qualquer estratégia de repositório precisa reconhecer isso honestamente.

## Forças (drivers) da decisão

- **F1 — Compartilhar domínio sem duplicação (PDR-003, princípio #5):** peso **alto**. `api` e `admin` devem consumir **o mesmo** domínio; mudança de regra num só lugar.
- **F2 — Simplicidade para time minúsculo (princípio #1):** peso **alto**. Menos cerimônia de versionamento/publicação de pacotes internos.
- **F3 — Deploy independente + segregação de superfície do admin (PDR-003, ADR-002):** peso **alto**. Bundles/artefatos separados; admin nunca embarca código público e vice-versa.
- **F4 — Mudança transversal atômica:** peso **médio**. Alterar contrato de API + cliente + tokens num único PR coeso.
- **F5 — Fonte única de design tokens para dois frontends heterogêneos (Dart + CSS):** peso **médio**. Tokens definidos uma vez, gerados para Flutter e para o admin.

## Opções consideradas

### Opção A — Monorepo poliglota único — **escolhida**
- **Resumo:** Um único repositório Git contém tudo: package de domínio PHP (compartilhado via **Composer path repository**), apps `api` e `admin`, o WebApp Flutter (próprio `pubspec`) e uma fonte única de **design tokens** que gera artefatos para Dart (tema Flutter) e para o admin (CSS/Blade). Deploys independentes por app via **path filters** no pipeline; o contrato de API (OpenAPI) gera um **cliente Dart** para o WebApp.
- **Como atende aos princípios:**
  - ✅ **Simplicidade (1):** um repo, um histórico, um PR atravessa domínio + contrato + cliente + tokens; sem publicar pacotes internos.
  - ✅ **Coesão/acoplamento (5):** o domínio compartilhado por path package torna o reuso `api`↔`admin` trivial e explícito.
  - ✅ **PDR-003:** deploys independentes por path filter; bundles separados → admin não embarca código público (segregação no **build/deploy**, não no repo).
  - ✅ **Reversibilidade (7):** extrair um diretório para repo próprio depois é barato; o caminho inverso (juntar repos) é caro — começar junto preserva opções.
- **Prós concretos:** reuso máximo do domínio PHP; mudanças transversais atômicas; fonte única de tokens; um só lugar para clonar e rodar local (princípio #6); um pipeline (com filtros) em vez de N.
- **Contras concretos:** repo poliglota exige tooling por linguagem (Composer para PHP, pub para Dart) — não há um único orquestrador como Nx/Turborepo cobrindo PHP+Dart; CI precisa de path filters bem-feitos para não rebuildar tudo a cada commit.

### Opção B — Polirepo (um repo por interface + pacotes publicados)
- **Resumo:** Repos separados (`turni-api`, `turni-admin`, `turni-webapp`) + o domínio como **pacote Composer publicado** (registry privado) e tokens como pacote versionado.
- **Como atende aos princípios:** ✅ isolamento físico forte; ⚠️ **Simplicidade (1):** cada mudança de domínio exige versionar/publicar o pacote e atualizar consumidores — cerimônia pesada para time minúsculo; ⚠️ mudança transversal vira N PRs coordenados.
- **Razão da rejeição:** o custo de versionar/publicar pacotes internos e coordenar PRs entre repos é desproporcional para um time de 1–3 pessoas; mata F2 e F4. A segregação de segurança que o polirepo oferece "de graça" já é obtida no monorepo via artefatos de build/deploy separados (ADR-002) + rede restrita do admin.

### Opção C — Status quo (nenhum repo de produção)
- **Consequência se mantivermos:** não há onde o código de produção nascer; bloqueia STORY-006 em diante.
- **Custo de adiar:** bloqueia o EPIC-000. Descartada — a decisão é necessária agora.

## Matriz comparativa

| Critério (força) | Peso | A — Monorepo | B — Polirepo | C — Status quo |
|---|---|---|---|---|
| F1 — Domínio sem duplicação | alto | ✅ path package, reuso direto | ⚠️ pacote publicado/versionado | ❌ |
| F2 — Simplicidade p/ time pequeno | alto | ✅ sem publicação interna | ❌ cerimônia de versionar/publicar | — |
| F3 — Deploy indep. + segregação | alto | ✅ path filters + artefatos separados | ✅ isolamento físico | ❌ |
| F4 — Mudança transversal atômica | médio | ✅ um PR | ❌ N PRs coordenados | — |
| F5 — Fonte única de tokens | médio | ✅ gera p/ Dart + CSS no mesmo repo | ⚠️ pacote de tokens versionado | ❌ |

## Decisão proposta

> **Optamos pela Opção A — monorepo poliglota único.**

Todo o produto vive num único repositório Git. Esboço de estrutura (detalhe fino fica a cargo do Programador na STORY-006):

```
turni/
├── apps/
│   ├── api/            # Laravel — API JSON pública (cliente: Flutter WebApp)
│   ├── admin/          # Laravel + Livewire — Backoffice (rede restrita)
│   └── webapp/         # Flutter — WebApp (web no MVP; nativo no futuro)
├── packages/
│   ├── domain/         # PHP — domínio compartilhado (Eloquent + regras), via Composer path repository
│   └── design-tokens/  # fonte única de tokens → gera tema Dart + CSS/Blade
├── contracts/          # OpenAPI da API → gera cliente Dart para o webapp
├── docker-compose.yml  # sobe api + admin + worker + Postgres (1 comando — princípio #6)
└── ...                 # CI com path filters → deploy independente por app
```

- **Compartilhamento PHP (`api`↔`admin`):** via `packages/domain` referenciado como **Composer path repository** — sem publicar.
- **Compartilhamento heterogêneo (WebApp Dart ↔ resto):** **contrato de API** (OpenAPI em `contracts/`, gerando cliente Dart) + **design tokens** (`packages/design-tokens` gerando tema Flutter e CSS do admin). Reconhecemos: WebApp e Backoffice **não** compartilham código de runtime — só contrato e tokens.
- **Segregação de segurança (PDR-003):** garantida no **build/deploy** — cada app gera artefato próprio; o do admin nunca embarca código público; o deploy do admin é em rede restrita (ADR-002). A fronteira de segurança é de runtime/deploy, não de repositório.

## Consequências

### Positivas (o que ganhamos)
- Reuso direto do domínio entre `api` e `admin`, sem versionar/publicar pacotes.
- Mudanças transversais (contrato + cliente + tokens + domínio) num único PR atômico.
- Um único `docker-compose` sobe o sistema inteiro local (princípio #6).
- Fonte única de design tokens elimina a duplicação que PDR-003 teme.

### Negativas / trade-offs aceitos
- Repo poliglota: tooling por linguagem (Composer + pub); sem orquestrador único cobrindo PHP+Dart.
- CI precisa de **path filters** bem-feitos para deploy independente e para não rebuildar tudo a cada commit (cabe à STORY-007).
- WebApp (Dart) e Backoffice (PHP) **não** compartilham runtime — declarado honestamente; o elo é contrato + tokens.

### Neutras
- Extrair futuramente um diretório (ex.: `webapp`) para repo próprio, se algum dia fizer sentido, é barato e reversível (princípio #7). Começar junto preserva a opção sem custo hoje.

### Para o time
- **Impacto em estórias existentes:** define a estrutura inicial da STORY-006 (setup repo + ambiente local em 1 comando), molda a STORY-007 (pipeline com path filters → deploys independentes por app), e dá lar ao `packages/design-tokens` que o Designer alimenta (DDR-001 / STORY-010).
- **ADRs relacionados:** ADR-001 (stack poliglota que motiva o desenho) e ADR-002 (os artefatos api/admin/worker + domínio que o monorepo abriga).
- **Necessidade de spike de validação:** não.

## Plano de verificação

- **Como verificar conformidade:**
  - CI com path filters: commit que toca só `apps/admin` não dispara deploy de `api` (e vice-versa) — verificável pelos jobs do pipeline (STORY-007).
  - Build do `admin` e do `api` produzem artefatos separados; teste/checagem garante que o artefato público não inclui código exclusivo do admin (princípio #9).
  - Design tokens têm **uma** fonte; lint/checagem detecta token hardcoded fora de `packages/design-tokens`.
- **Sinais de revisão (quando reabrir esta decisão):**
  - Se o monorepo crescer a ponto de o tooling poliglota virar gargalo real de CI (builds lentos mesmo com filtros) → avaliar extrair o `webapp` Flutter para repo próprio (polirepo parcial).
  - Se a segregação de segurança exigida por compliance passar a demandar **isolamento físico** de repositório (não só de deploy) → reabrir para polirepo do admin.
- **Spike de validação proposto:** nenhum.

---

## Aprovação humana

- **Status final:** ✅ aceita
- **Aprovado por:** Alexandro
- **Data:** 2026-05-27
- **Forma do aceite:** aprovado em chat (sessão de 2026-05-27)
- **Condicionantes do aceite:** nenhuma.

---

## Histórico

- 2026-05-27 — criada como `proposed` por Arquiteto. Estratégia de repositório derivada de ADR-001 (stack poliglota) e ADR-002 (topologia), honrando o compartilhamento e a segregação exigidos por PDR-003.
- 2026-05-27 — `accepted` por Alexandro (aprovação em chat, junto de ADR-001 e ADR-002).
