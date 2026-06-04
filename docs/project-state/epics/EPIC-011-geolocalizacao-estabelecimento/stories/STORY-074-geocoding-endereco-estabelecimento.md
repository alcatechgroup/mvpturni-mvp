---
story_id: STORY-074
slug: geocoding-endereco-estabelecimento
title: Geocodificar o endereço do estabelecimento → lat/lng (cadastro + backfill + ACL + mock)
epic_id: EPIC-011
sprint_id: null  # backlog — PO define o sprint (candidata a entrar antes de STORY-061 ser "real")
type: implementation
target_role: programador
requires_design: false
design_screen_id: null
status: ready
owner_agent: null
created_at: 2026-06-04
updated_at: 2026-06-04
estimated_session_size: M
---

# STORY-074 — Geocodificar o endereço do estabelecimento → lat/lng

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. **Pré-requisito duro:** a estratégia de geocoding (provedor + ACL + mock local) é decisão do Arquiteto — **ADR-019 precisa existir e estar `accepted` antes de implementar**. Se não existir, pare e escale ao Arquiteto (não escolha o provedor sozinho — é integração externa com custo/rate-limit/princípio #6). O PO pode quebrar esta estória em spike (Arquiteto → ADR-019) + implementação no planejamento.

## Contexto (por que esta estória existe)

O spike STORY-057 (geofencing) descobriu que **o estabelecimento não tem coordenada**: `contratante_profiles` guardava só o endereço em texto e o `CepLookup` não geocodifica. Logo `PublicarVagaService` snapshota `lat/lng` nulos na vaga, e tanto a **distância do feed** (EPIC-002) quanto o **geofencing do check-in** (PDR-008/EPIC-003) ficam sem ponto de referência — funcionam em dev/homolog só porque os seeders cravam coordenadas na mão.

As **colunas `lat/lng` em `contratante_profiles` já existem** (migração `2026_06_04_160000`, criada junto da STORY-057). Falta **populá-las** geocodificando o endereço, com backfill dos já cadastrados, dentro de uma ACL com mock local.

- Épico: `epics/EPIC-011-geolocalizacao-estabelecimento/epic.md`
- Documentos canônicos a ler ANTES de codificar:
  - `decisions/adr/ADR-019-*` (estratégia de geocoding — **pré-requisito**)
  - `decisions/pdr/PDR-008-geofencing-alerta-e-registra.md`
  - `decisions/adr/ADR-013-modelo-vaga-candidatura-snapshot.md` (snapshot da vaga)
  - `app/Services/PublicarVagaService.php` (já lê `$profile->lat`), `app/Domain/Cadastro/CepLookup.php`, `app/Support/Geo/Geofencing.php` (consumidor — STORY-057)

## O quê (objetivo desta estória)

Geocodificar o endereço do estabelecimento em `lat/lng` (via ACL com mock local definida na ADR-019), populando `contratante_profiles.lat/lng` no cadastro/edição de endereço e fazendo backfill dos existentes, de modo que vagas publicadas carreguem a coordenada real e o geofencing calcule distância de verdade.

## Por quê (valor para o usuário)

A proximidade no feed e a presença real no check-in só funcionam com a localização verdadeira do estabelecimento — é o que sustenta dois diferenciais do produto.

## Critérios de aceite

Cada item é uma asserção testável. O agente DEVE escrever testes que cubram cada um.

- [ ] **CA-1:** Existe uma ACL de geocoding (interface + adapter + **mock em container**, conforme ADR-019) que, dado um endereço/CEP, devolve `{ lat, lng }` ou `null` (não geocodificável), sem lançar. Funciona 100% local sem internet (princípio #6).
- [ ] **CA-2:** Ao **completar/editar o endereço** do contratante, `contratante_profiles.lat/lng` é populado a partir do endereço; endereço inválido/não-geocodificável → `lat/lng` nulos + log estruturado (não bloqueia o cadastro).
- [ ] **CA-3:** **Backfill** idempotente dos contratantes já cadastrados sem coordenada (comando/seed apto a rodar em homolog).
- [ ] **CA-4:** Vaga publicada após a coordenada existir carrega o snapshot `vagas.lat/lng` do perfil (a leitura já está em `PublicarVagaService`; garantir o caminho real, não só seed).
- [ ] **CA-5:** Com coordenada real, o geofencing de check-in (STORY-057/`Geofencing`) devolve `distancia_metros` numérica (não `sem_coordenada`) — teste cobrindo o caminho ponta-a-ponta.
- [ ] **CA-6:** Idempotência/observabilidade: geocodificar duas vezes o mesmo endereço não duplica chamadas desnecessárias (cache/short-circuit conforme ADR-019); falhas do provedor são logadas e não quebram o fluxo.

## Fora de escopo

- Geolocalização do **profissional** (vem do navegador no check-in — STORY-061).
- UX de mapa/ajuste de pin; validação de endereço; múltiplas unidades.
- Reprocessar a distância de vagas **já publicadas** (snapshot é imutável — ADR-013; vale só para novas).

## Padrões de qualidade exigidos

`docs/skills/po/references/quality-standards.md`. Resumo: ≥ 80% no código novo; ≥ 98% no núcleo (parsing da resposta do provedor / decisão de geocodificável). Mock local obrigatório (princípio #6). E2E/integração cobrindo cadastro→coordenada e coordenada→geofencing.

## Dependências

- **Bloqueada por:** **ADR-019 (estratégia de geocoding)** — a propor pelo Arquiteto. (Schema já preparado: colunas `lat/lng` existem.)
- **Bloqueia (funcionalmente):** STORY-061 (geofencing real) e a qualidade da distância no feed (EPIC-002). Não é bloqueio duro — PDR-008 é alerta-e-registra.
- **Pré-requisitos de ambiente:** homolog operante; mock de geocoding em container.

## Decisões já tomadas (não as reabra)

- **PDR-008** — geofencing alerta-e-registra (coordenada ausente não bloqueia).
- **ADR-013** — localização é snapshot imutável da vaga na publicação.
- **ADR-017** — distância por Haversine (`Support\Geo\Geofencing`/`Haversine`), sem PostGIS.
- **ADR-018** — UUID nas PKs.
- **Princípio #6** — funcionamento 100% local: geocoding tem mock em container.
- **ADR-019 (a existir)** — provedor + ACL + idempotência do geocoding. **Sem ela, não implemente.**

## Liberdade técnica do agente

Você decide a estrutura local do código dentro da ADR-019. Você **não** decide o provedor de geocoding (ADR-019), os critérios de aceite (PO), nem o comportamento de geofencing (PDR-008). Se a ADR-019 não existir, pare e escale.

## Definição de Pronto (DoD)

- [ ] Todos os critérios de aceite passam, com as coberturas exigidas.
- [ ] Mock local funcionando (princípio #6); ACL testada contra o mock.
- [ ] Backfill rodado e verificado em homolog.
- [ ] Pipeline verde; deploy em homolog verificado (geofencing real demonstrável).
- [ ] IDR registrado se houver descoberta técnica relevante.
- [ ] `index.json` atualizado: `status: done`.
- [ ] "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

`docs/skills/po/references/agent-task-format.md`. Ao iniciar: confirme que **ADR-019 está `accepted`**; senão, `status: blocked` + escale ao Arquiteto.

## Notas do agente (preenchido durante/após execução)

### Decisões tomadas
- 2026-06-04 — (PO/preparação) colunas `lat/lng` adicionadas a `contratante_profiles` (migração `2026_06_04_160000`, nullable, `decimal:7`) + model fillable/cast + teste de round-trip, durante a STORY-057. Só o schema; nenhum dado geocodificado.

### Descobertas
- 2026-06-04 — (origem, STORY-057) `CepLookup` devolve só endereço, sem coordenada; `contratante_profiles` não tinha lat/lng; `PublicarVagaService` lia `$profile->lat` que era sempre nulo → vagas reais sem geo. Seeders mascaravam isso cravando coordenadas.

### Bloqueios encontrados
- Aberto: depende de ADR-019 (geocoding) antes de implementar.

### IDRs criados
-

### Cobertura final
- Unitários: <%>
- E2E: <cenários>

### Links de evidência
- PR:
- Pipeline:
- Deploy de homologação:
