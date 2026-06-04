---
story_id: STORY-057
slug: spike-tempo-real-cronometro-geolocalizacao
title: Spike Arquiteto — tempo real do cronômetro bilateral + geolocalização Haversine no check-in
epic_id: EPIC-003
sprint_id: SPRINT-2026-W28
type: spike
target_role: arquiteto
requires_design: false
design_screen_id: null
status: in_progress
owner_agent: claude-opus-4-8
created_at: 2026-06-03
updated_at: 2026-06-04
estimated_session_size: M
produces_idr: null  # produz ADR-017
---

# STORY-057 — Spike Arquiteto: tempo real cronômetro + geolocalização Haversine

> **Para o agente arquiteto:** esta estória decide duas estratégias técnicas de runtime que afetam várias estórias de implementação (063 cronômetro, 061 check-in com geofencing, 062 validação). Não confunda: o **comportamento** (cronômetro bilateral visível em tempo real, geofencing alerta-e-registra) está fixado em `domain/turno.md` e PDR-008 — esta estória escolhe **como tecnicamente** entregar.

## Contexto (por que esta estória existe)

`domain/turno.md` exige cronômetro bilateral vivo enquanto turno `ativo` (latência ≤ 2s entre os 2 lados) e PIN de check-in carregando flag `geofencing_ok` + distância em metros (PDR-008). Sem decisão arquitetural cobrindo esses dois pontos, STORY-061 (check-in) e STORY-063 (cronômetro) não conseguem começar.

As duas decisões cabem na **mesma ADR** porque são "estratégias técnicas de runtime" — escolhas de mecanismo do navegador/servidor — com superfície disjunta mas afinidade de timing (ambas envolvem o evento de check-in).

- Épico: `epics/EPIC-003-aceite-pin-e-pix/epic.md`
- Documentos canônicos:
  - `docs/especificacao/domain/turno.md` (cronômetro bilateral, geofencing como atributo do evento)
  - `decisions/pdr/PDR-008-geofencing-alerta-e-registra.md` (comportamento)
  - `decisions/adr/ADR-001-stack-principal.md` (Laravel + Livewire + Flutter — restringe ferramental)
  - `decisions/adr/ADR-002-topologia.md` (api + admin + worker)
  - `decisions/idr/IDR-026-*` (TurniDateTime — política única de data/hora; cronômetro consome)

## O quê (objetivo desta estória)

Propor **ADR-017** com 2 decisões: (a) canal de tempo real do cronômetro bilateral e (b) estratégia de geolocalização no check-in. Entregar **prova de conceito mínima** rodando em homolog (cronômetro vazio que sobe via canal escolhido; coordenada do navegador chegando ao backend e calculando distância via Haversine).

## Por quê (valor para o usuário)

Cronômetro fora de sincronia entre os 2 lados quebra a confiança no produto (cada um vê um tempo). Geofencing que não funciona em rua quebra PDR-008. As duas precisam estar tecnicamente desenhadas antes da UI ser construída.

## Critérios de aceite

- [ ] **CA-1:** ADR-017 escrita, status `accepted`, aprovação do Alexandro registrada.
- [ ] **CA-2:** Decisão de canal de tempo real fundamentada — comparar pelo menos WebSocket (Laravel Reverb/Pusher), SSE e polling com janela curta. Considerar: latência (≤ 2s requerida), custo em homolog/produção, complexidade de operação, fit com ADR-001/002. Princípio #1 (simplicidade) e princípio #7 (não-antecipação) ponderados explicitamente.
- [ ] **CA-3:** Decisão de geolocalização fundamentada — browser Geolocation API + cálculo Haversine no backend usando o helper `Support\Geo` (criado em STORY-049 EPIC-002, reuso) vs PostGIS. Mesma análise de complexidade × benefício.
- [ ] **CA-4:** Servidor é fonte de verdade do tempo decorrido — clientes só consomem (mitiga risco de clocks divergentes do sprint). ADR-017 fixa essa invariante.
- [ ] **CA-5:** Prova de conceito mínima em homolog: turno seedado em `ativo` mostra cronômetro avançando em 2 navegadores abertos simultaneamente (profissional e contratante), sincronizado em ≤ 2s. Geolocalização do navegador chega ao backend e o backend calcula distância em metros via Haversine.
- [ ] **CA-6:** Cobertura ≥ 80% no código novo, ≥ 98% no cálculo de Haversine (núcleo de regra) — reuso do código já testado em STORY-049 é aceitável e desejável.

## Fora de escopo

- UI do cronômetro propriamente dita (vive em STORY-063).
- UI do PIN de check-in (vive em STORY-061).
- Validação do PIN pelo contratante (vive em STORY-062).
- Política de retry quando o navegador perde conexão por > 5s (registrar como follow-up, não bloqueia esta estória).

## Padrões de qualidade exigidos

`docs/skills/po/references/quality-standards.md`. ≥ 80% geral, ≥ 98% no cálculo de Haversine. Prova de conceito tem evidência observável (vídeo de tela ou screenshot dos 2 navegadores em homolog).

## Dependências

- **Bloqueada por:** nenhuma.
- **Bloqueia:** STORY-061 (geolocalização), STORY-063 (cronômetro bilateral).
- **Pré-requisitos de ambiente:** WebApp e admin operantes em homolog (herdado de EPIC-000); helper `Support\Geo` (criado em STORY-049).

## Decisões já tomadas (não as reabra)

- ADR-001 / ADR-002 / ADR-004 / ADR-008 / IDR-026
- **ADR-018 — UUIDv7 em PKs (EPIC-010/W27.5). Eventos do canal de tempo real carregam `turno_id` como string UUID.**
- PDR-008 — comportamento de geofencing (alerta-e-registra, não bloqueia)

## Liberdade técnica do agente

Você decide: canal de tempo real, formato de payload, política de reconexão básica, estrutura interna do cálculo de distância.

Você NÃO decide: comportamento de geofencing (PDR-008 fixa); comportamento de cronômetro (`domain/turno.md` fixa).

## Definição de Pronto (DoD)

- [ ] ADR-017 escrita, revisada, `accepted`.
- [ ] Prova de conceito rodando em homolog (evidência anexada à estória).
- [ ] Pipeline verde com cobertura exigida.
- [ ] `index.json` atualizado.
- [ ] "Notas do agente" preenchida.

## Protocolo do agente

`docs/skills/po/references/agent-task-format.md`.

## Notas do agente

### Decisões tomadas (2026-06-04, Arquiteto — direção confirmada por Alexandro antes de formalizar)
- **(a) Canal de tempo real → âncora-de-timestamp + polling de janela curta.** O cronômetro é uma **duração derivada**, não um fluxo empurrado: o servidor grava `iniciado_em` (UTC) na transição `→ ativo` e expõe `{ estado, iniciado_em, servidor_agora, encerrado_em? }` num endpoint REST leve. O WebApp calcula offset de relógio contra `servidor_agora`, **tica localmente** (consumindo `TurniDateTime`/IDR-026) e faz polling ~5s só para reconciliar e detectar saída de `ativo`. **Zero infra nova** — descartados WebSocket (Reverb) e SSE por brigarem com Cloud Run stateless/scale-to-zero (ADR-004) e exigirem processo always-on + Redis (fere princípios #1/#3/#7/#11). Sincronia ≤ 2s vira **estrutural** (âncora comum + cancelamento de skew), não dependente de latência de canal.
- **(b) Geolocalização → Geolocation API do navegador + `App\Support\Geo\Haversine` (reuso STORY-049), sem PostGIS.** Backend calcula distância em metros e grava `geofencing_check_in = { ok, distancia_metros, capturado_em }`; falha de captura vira `ok:false`, `distancia_metros:null` + razão. PostGIS descartado — extensão inteira para uma única distância ponto-a-ponto é complexidade sem dor real (princípio #1); PostGIS só se justifica com busca espacial em massa (sinal de revisão).
- **Invariante fixada (CA-4):** servidor é a fonte de verdade do tempo decorrido; clientes só consomem.

### Descobertas
- A topologia Cloud Run stateless + scale-to-zero (ADR-004) é o fator que mais empurra a decisão (a) — qualquer canal de conexão persistente exige peça always-on + fan-out (Redis), exatamente o tipo de custo/operação que um time minúsculo não justifica sem dor real.
- O requisito "tempo real" **colapsa num único timestamp**: com servidor como fonte de verdade, o cronômetro é uma duração derivada de `iniciado_em` que o cliente computa sozinho — empurrar tiques por WS/SSE empurraria pela rede um número que o cliente já sabe calcular.
- `App\Support\Geo\Haversine` já existe e está testado (STORY-049) — CA-3/CA-6 pedem reuso explícito; só falta a conversão km→m e a regra de raio/razão de falha.

### Implementação (PoC — 2026-06-04, programador)
Slice vertical entregue e verde (semente direta de STORY-063/061):
- **Backend (api):**
  - `App\Support\Geo\Geofencing` — núcleo puro do geofencing (reusa `Haversine` da STORY-049): `avaliar()` → `{ ok, distancia_metros, razao }`, raio padrão 100m, falha de captura vira `ok:false`/`distancia null`/razão.
  - `GET /api/turnos/{turno}/cronometro` (`CronometroController`) — âncora `{ estado, iniciado_em (=check_in_at), encerrado_em (=check_out_at), servidor_agora }`. RBAC bilateral (404 p/ terceiros). **Sem coluna nova** — `check_in_at`/`check_out_at` já existem (ADR-015).
  - `POST /api/turnos/{turno}/checkin-geo` (`CheckinGeoController`) — recebe posição do navegador, calcula metros via Haversine, grava snapshot `geofencing_check_in`. RBAC: só o profissional.
- **Cliente (WebApp Flutter):**
  - `lib/features/turno/cronometro_ancora.dart` — núcleo PURO `CronometroAncora`: `sincronizar()` calcula offset de relógio, `decorrido()` tica local cancelando skew, `formatar()` HH:MM:SS. Prova determinística da sincronia ≤ 2s (teste com 73s de skew bruto entre os lados → diferença residual ≤ 2s).
  - `lib/features/turno/geolocalizacao.dart` (+ `_stub`/`_web`) — ponte de Geolocation API do navegador no padrão de import condicional do repo (stub no-op em VM; `package:web`+`js_interop` no browser). Falha vira razão (`permissao_negada`/`timeout`/`indisponivel`), nunca lança.
  - `lib/features/turno/turno_poc_service.dart` — `cronometro()` (GET) + `checkinGeo()` (POST), sessão same-origin sem csrf-cookie (IDR-019). Parsing via `TurniDateTime` (IDR-026).
  - `lib/features/turno/cronometro_poc_screen.dart` + rota `/turno/:id/cronometro-poc` (`router.dart`) — tela de PoC: polling 5s + tique local 1s + botão de captura de geolocalização.

### PoC viva em homolog (CA-5) — runbook
Decisão do PO (2026-06-04): construir tela PoC + deploy. Após o deploy de `api`+`webapp` em homolog:
1. Semear o turno ativo (check-in no passado): `php artisan db:seed --class=Database\Seeders\CronometroPocSeeder --force` no ambiente da `api` (o seeder imprime o `turno_id`).
2. Navegador 1 — login `profissional.poc@turni.local` / `password` → abrir `app.homolog.turni.com.br/turno/{turno_id}/cronometro-poc`.
3. Navegador 2 — login `contratante.poc@turni.local` / `password` → mesma URL.
4. Observar: o cronômetro avança nos dois lados sincronizado em ≤ 2s (mesmo `iniciado_em`). No navegador do profissional, "Capturar localização" → permitir geolocalização → ver a distância em metros calculada pelo backend (Haversine). Permissão negada → "sem coordenada (não bloqueia)".
5. Anexar evidência (vídeo/screenshot dos 2 navegadores) em "Links de evidência".

### Bloqueios encontrados
- Nenhum bloqueador técnico. ADR-017 `accepted` por Alexandro (2026-06-04). Código completo, testado e buildando (`flutter build web` ok). **Pendente:** captura da evidência viva dos 2 navegadores em homolog (CA-5) após o deploy — runbook acima pronto.

### ADRs/IDRs criados
- ADR-017 — Tempo real cronômetro (polling+âncora) + geolocalização Haversine — `decisions/adr/ADR-017-tempo-real-cronometro-polling-e-geolocalizacao-haversine.md` (status `accepted`).

### Cobertura final
- **api (novo código):** `Geofencing` 100%, `Haversine` 100% (reuso), `CronometroController` 100%, `CheckinGeoController` 100% — 25 testes (Unit `GeofencingTest` + Feature `CronometroTest`/`CheckinGeoTest`). Atende CA-6 (≥ 98% Haversine, ≥ 80% novo).
- **webapp:** 16 testes (`CronometroAncora` 9 + `TurnoPocService` 7), `flutter analyze` limpo nos arquivos novos, `flutter build web` ok (interop js da geolocalização compila).
- **Suíte api completa:** 673 testes verdes, cobertura total 91,8% (gate ≥ 80).

### Links de evidência
- PR:
- Pipeline:
- Deploy de homologação (PoC):
