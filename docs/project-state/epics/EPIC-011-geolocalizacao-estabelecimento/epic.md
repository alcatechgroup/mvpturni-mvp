---
epic_id: EPIC-011
slug: geolocalizacao-estabelecimento
title: Geolocalização do estabelecimento (geocoding do endereço → coordenadas)
wave: WAVE-2026-01
status: ready  # draft | ready | in_progress | in_review | done | abandoned
owner_role: po
created_at: 2026-06-04
updated_at: 2026-06-04
target_completion: null
---

# EPIC-011 — Geolocalização do estabelecimento

## Por que existimos (problema do usuário)

O Turni promete **distância** ("vagas perto de você" no feed) e **presença real** (geofencing no check-in — PDR-008). Os dois dependem de saber **onde o estabelecimento fica** — em coordenadas (lat/lng), não só em texto. Hoje o perfil do contratante guarda o endereço **só como texto** (CEP, logradouro, cidade…) e não há geocoding: o `CepLookup` devolve endereço, nunca coordenada. A descoberta veio do spike STORY-057 (geofencing): a coordenada do estabelecimento que o backend usa para o Haversine é um snapshot da vaga (`vagas.lat/lng`), que por sua vez deveria vir do perfil do contratante — mas como o perfil não tem lat/lng, **vagas reais saem sem coordenada**. Em dev/homolog "funciona" porque os seeders cravam lat/lng na mão; em produção, a distância do feed e o geofencing do check-in ficariam indeterminados (`sem_coordenada`).

Sem resolver isso, dois dos diferenciais do produto (proximidade no feed e presença no check-in) não se materializam com dados reais.

## Resultado esperado (outcome)

Ao fim deste épico, **todo estabelecimento ativo tem coordenadas (lat/lng) derivadas do endereço cadastrado**, de modo que a distância no feed (EPIC-002) e o geofencing no check-in (EPIC-003) calculam contra a localização real do estabelecimento — não contra dado semeado.

## Métrica de sucesso (como saberemos que funcionou)

- Métrica primária: ≥ 95% dos contratantes ativos com endereço válido têm `lat/lng` não-nulos.
- Métrica de qualidade: o geofencing de um check-in real em homolog devolve uma distância em metros (não `sem_coordenada`); a distância do feed deixa de depender de seed.
- Funcionamento 100% local preservado (princípio #6): geocoding mockado sobe sem internet.

## Entregável visível no fim do épico

- [ ] Perfil do contratante com `lat/lng` populados a partir do endereço (no cadastro e quando o endereço muda).
- [ ] Backfill dos contratantes já cadastrados (homolog) com coordenada.
- [ ] Vaga publicada de verdade carrega o snapshot de coordenada do estabelecimento (a leitura já existe em `PublicarVagaService`).
- [ ] Geofencing de check-in em homolog calcula distância real (encerra a lacuna registrada na STORY-057).

## Fora de escopo (explicitamente)

- Geolocalização do **profissional** (já vem do navegador no check-in — STORY-061).
- UX de validação/correção de endereço no mapa (arrastar pin) — evolução futura.
- Múltiplas unidades/estabelecimentos por contratante (compliance.md §lacunas) — fora do MVP.
- Precisão sub-métrica / rota — Haversine ponto-a-ponto basta (ADR-017).

## Referências da especificação

- `docs/especificacao/domain/usuario.md` — perfil do contratante/estabelecimento
- `docs/especificacao/domain/vaga.md` — localização como snapshot da vaga
- `docs/especificacao/domain/turno.md` — geofencing de check-in
- `docs/project-state/decisions/pdr/PDR-008-geofencing-alerta-e-registra.md`
- `docs/project-state/decisions/adr/ADR-013-modelo-vaga-candidatura-snapshot.md` (snapshot da vaga)
- `docs/project-state/decisions/adr/ADR-017-tempo-real-cronometro-polling-e-geolocalizacao-haversine.md` (consumidor: Haversine)

## Dependências

- **Bloqueia (funcionalmente):** STORY-061 (geofencing de check-in — sem coordenada do estabelecimento sempre registra `sem_coordenada`; PDR-008 não bloqueia, mas a garantia de presença não se materializa); qualidade da distância no feed (EPIC-002).
- **Bloqueado por:** **ADR-019 (a propor) — estratégia de geocoding** (provedor: Nominatim/OSM × Google × BrasilAPI/AwesomeAPI CEP-com-coordenada × outro; ACL dedicada; idempotência; mock em container para o princípio #6; custo e rate-limit). Decisão do Arquiteto antes da implementação começar.
- **Decisões arquiteturais necessárias:** ADR-019 (geocoding). Se a deliberação for cara, abrir spike do Arquiteto.

## Estórias

- [ ] **STORY-074** — Geocodificar endereço do estabelecimento → `lat/lng` (cadastro + backfill + ACL + mock)
- [ ] STORY-XXX (validação) — Validação final do épico (quando o épico for fechado)

> Nota: as **colunas `lat/lng` em `contratante_profiles` já foram criadas** (migração `2026_06_04_160000`, durante a STORY-057) — prontas para serem populadas pela STORY-074.

## Validação final

Critérios em `validation/checklist.md`. Relatório do validador em `validation/report.md`.

**Definição de épico concluído:** todas as estórias `done` + relatório de validação `approved` + geofencing real demonstrável em homologação.

## Histórico

- 2026-06-04 — criado por PO após a STORY-057 (spike geofencing) revelar que o estabelecimento não tem coordenada geocodificada — só endereço em texto. Cross-cutting: alimenta a distância do feed (EPIC-002) e o geofencing do check-in (EPIC-003). Colunas `lat/lng` já adicionadas em `contratante_profiles` na mesma sessão (preparação).
