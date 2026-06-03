---
idr_id: IDR-026
slug: politica-unica-de-data-hora-turnidatetime
title: Política única de data/hora do WebApp (TurniDateTime) — UTC na API, local na UI
status: accepted
decided_at: 2026-06-03
decided_by: programador
owner_agent: claude-opus-4-8
related_story: STORY-052
related_adrs: []
related_ddrs: [DDR-002]
related_idrs: []
supersedes: null
superseded_by: null
created_at: 2026-06-03
updated_at: 2026-06-03
---

# IDR-026 — Política única de data/hora do WebApp (`TurniDateTime`)

## Contexto

Horário é crítico no Turni (turno, prazo de revisão PDR-009, Pix em 15 min). A manipulação de data/hora
no WebApp estava **espalhada**: cada tela tinha seu próprio `_formatQuando`/`_formatData`/`_fmtHora`/
`_parseDataHora`, os modelos faziam `DateTime.parse` solto, e a serialização para a API foi remendada
caso a caso. A consequência apareceu na STORY-052: a API guarda em **UTC** (`timestamptz`,
`app.timezone=UTC`) e o card/detalhe/feed exibiam com `.toLocal()` (→ BRT), mas a tela de **edição** lia
a hora crua do instante UTC (→ +3h) e, ao salvar, serializava o horário de parede **sem fuso** — a API
relia como UTC e **deslocava o turno em 3h**, ainda disparando uma edição "material" fantasma mesmo sem o
contratante mexer no horário.

O problema não era de uma tela: era a **ausência de uma fronteira única** entre o instante (API) e o
horário de parede (usuário). Corrigir tela a tela só multiplicaria o risco.

## Decisão

> **Toda conversão, formatação, parsing e serialização de data/hora do WebApp passa por um único
> componente puro — `lib/core/time/turni_datetime.dart` (`TurniDateTime`) — muito bem testado. Telas,
> serviços e modelos delegam; nenhum improvisa `.toLocal()`/`.toIso8601String()`/`padLeft` de data.**

Contrato do componente:

- **API troca instantes em UTC.** `TurniDateTime.toApi(x)` → sempre ISO-8601 UTC (`…Z`); `parse`/
  `parseRequired` leem o ISO preservando o ponto no tempo.
- **Usuário pensa em horário de parede local.** Toda exibição converte o instante para local
  (`.toLocal()` num **único** ponto privado, `_local`); toda entrada do usuário é interpretada como local
  (`parseEntrada`).
- **Ida-e-volta lossless (invariância central):** `parseEntrada(formatData(i), formatHora(i))` reproduz o
  **mesmo instante** `i`. É isso que garante que "abrir a edição e salvar sem mexer no horário" não
  desloque a vaga nem vire edição material fantasma.
- **Fuso:** produto Brasil-only; usamos o fuso **local do dispositivo** — a convenção que
  "Minhas vagas"/"Detalhe"/"Feed" já adotavam. Se um dia o horário precisar ser fixado no fuso do
  **estabelecimento** (e não no do espectador), o **único** ponto a mudar é o helper privado `_local`.

Formatos pt-BR/24h (DDR-002) ficam todos no componente: `formatData` (`12/06/2026`), `formatDataCurta`
(`12/06`), `formatHora` (`18:00`), `formatIntervalo` (`Sex, 12/06 · 18:00–23:00`), `formatResumo`,
`formatDataHoraCurta`, `formatPrazo`, `formatDuracao`, `formatDiaSemana`, `formatHoraComponentes`.

## Alternativas consideradas

1. **Corrigir só a tela de edição** (status quo + patch). Resolve o sintoma reportado, mas mantém a
   duplicação e a fronteira difusa — a próxima tela com data repete o bug. Rejeitada.
2. **Adotar `package:intl` / `package:timezone`.** Poderoso, mas: (a) `intl` traz peso e API de
   formatação que excede o que precisamos (pt-BR/24h é um punhado de formatos fixos); (b) `timezone`
   embute o banco IANA — só se justifica quando precisarmos do fuso do **estabelecimento** (hoje BRT sem
   DST desde 2019). Mantemos o componente sem dependência nova; trocar `_local` por uma resolução via
   `timezone` é uma mudança localizada se/quando necessário.
3. **Centralizar (escolhida).** Um módulo puro, sem Flutter, sem rede, testável isoladamente, que as
   telas/serviços consomem. Elimina a classe inteira de bug por construção.

## Consequências

### Positivas
- Bug de fuso vira **impossível por construção** nas telas que delegam (invariância testada).
- Formatos pt-BR/24h num só lugar (coerência com DDR-002); mudar um formato é um ponto.
- Trocar a política de fuso (device → estabelecimento) é trivial (`_local`).

### Negativas / trade-offs aceitos
- Um componente a mais para conhecer (mitigado por doc no topo do arquivo + testes como exemplo vivo).
- Formatação de **moeda** (`R$`) **não** entra neste componente — é outra responsabilidade; segue local
  às telas por ora (candidato a um `TurniMoney` análogo no futuro, fora do escopo desta estória).

### Escopo aplicado nesta estória
Refatorados para delegar ao `TurniDateTime`: `publicar_vaga_screen`, `editar_vaga_screen`,
`minhas_vagas_screen`, `vaga_detalhe_screen`, `feed_screen`, `painel_candidatos_screen`, `vaga_service`,
`vaga_detalhe_service`, `feed_service`. Os `_formatQuando`/`_formatData`/`_fmtHora`/`_parseDataHora`
duplicados foram removidos. Suíte webapp inteira verde (324) com os mesmos textos de horário de antes.

## Sinais de revisão
- Se surgir requisito de exibir o horário no **fuso do estabelecimento** (não no do dispositivo), trocar
  `_local` (e, aí sim, avaliar `package:timezone`).
- Se a formatação de moeda/percentual proliferar, abrir IDR análogo para um componente de números.
