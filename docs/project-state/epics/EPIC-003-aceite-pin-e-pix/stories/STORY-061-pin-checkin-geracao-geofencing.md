---
story_id: STORY-061
slug: pin-checkin-geracao-geofencing
title: PIN de check-in — geração pelo profissional + captura de geofencing (PDR-008)
epic_id: EPIC-003
sprint_id: SPRINT-2026-W28
type: implementation
target_role: programador
requires_design: true
design_screen_id: SCREEN-STORY-061-pin-checkin
status: in_review
owner_agent: claude-opus-4-8
created_at: 2026-06-03
updated_at: 2026-06-05
estimated_session_size: M
produces_idr: null
---

# STORY-061 — PIN de check-in + captura de geofencing

## Contexto

Profissional chega ao local. Em `confirmado`, no horário próximo de início, ele gera um **PIN de 4 dígitos** que aparece em tela grande para ser lido pelo contratante. No momento da geração, o WebApp captura a geolocalização (PDR-008 alerta-e-registra — não bloqueia) e o backend calcula a distância via Haversine (decisão em ADR-017/STORY-057), gravando flag `geofencing_ok` + distância no evento.

- Épico: `epics/EPIC-003-aceite-pin-e-pix/epic.md`
- Documentos: `domain/turno.md` (transição `confirmado → aguardando_checkin`, atributos `check_in`, `geofencing_check_in`), PDR-008.

## O quê

Botão "Gerar PIN de check-in" no detalhe do turno (STORY-060) quando estado for `confirmado` e horário próximo de início. Geração cria PIN aleatório de 4 dígitos guardado server-side hasheado (não em plaintext nos logs); transita turno para `aguardando_checkin`; captura geolocalização do navegador e grava `geofencing_check_in: { ok, distancia_metros, capturado_em, razao? }` no turno.

## Por quê

PIN bilateral é um dos 3 pilares do produto. Sem geração, não há check-in. Geofencing é a peça que prova ao contratante que o profissional chegou de fato — sem isso, PDR-008 não está em vigor.

## Critérios de aceite

- [x] **CA-1:** Botão "Gerar PIN de check-in" aparece **apenas** quando turno em `confirmado` E horário corrente está em [data_inicio - 30min, data_inicio + 2h] (janela configurável via env, default explícito). Fora dessa janela: botão desabilitado com microcopy explicando.
- [x] **CA-2:** Clique solicita geolocalização ao navegador. Se concedida: WebApp envia `{ pin_solicitado: true, lat, lng, accuracy_m }`. Se negada/timeout/erro: WebApp envia `{ pin_solicitado: true, geo: null, razao: 'permissao_negada' | 'timeout' | 'erro_browser' }`.
- [x] **CA-3:** Backend gera PIN aleatório de 4 dígitos (uniforme, com retry para evitar PINs trivais — repetidos/sequenciais — opcional; documentar decisão); guarda **hash + sal** server-side (nunca plaintext após resposta inicial); transita turno para `aguardando_checkin` em transação com gravação do `geofencing_check_in` (calculando distância via Haversine para coordenada do estabelecimento — reuso do helper `Support\Geo` da STORY-049/057).
- [x] **CA-4:** Resposta retorna **PIN em plaintext** para a tela do profissional (única vez que aparece — refresh perde o PIN, profissional re-gera). PIN nunca aparece em logs JSON (só hash + flag de geração).
- [x] **CA-5:** Tela do profissional mostra PIN em grande (tipografia ≥ 64pt; contraste AAA) com microcopy "Mostre este PIN ao contratante para validar a chegada". Botão "Não chegou ainda? Cancelar PIN" volta para `confirmado` (idempotente — geração nova invalida hash anterior).
- [x] **CA-6:** `geofencing_ok` calculado contra raio do estabelecimento (default 100m, configurável por estabelecimento — registrar como follow-up se for muito; default 100m é o suficiente para o sprint). `geofencing_ok: false` **não bloqueia** o check-in (PDR-008) — só registra.
- [x] **CA-7:** Audit log captura `turno.checkin_solicitado` com `geofencing_check_in` completo (snapshot).
- [x] **CA-8:** RBAC: só o profissional do turno gera PIN; contratante recebe 403 ao tentar; admin não gera (papel do admin é diferente).
- [x] **CA-9:** Cobertura ≥ 98% na geração de PIN (regra de negócio) e cálculo de geofencing; ≥ 80% no resto. E2E cobre os 3 caminhos de geo (concedida, negada, timeout).

## Fora de escopo

- Validação do PIN pelo contratante (STORY-062).
- Geofencing no check-out (STORY-064 traz).
- Raio configurável por estabelecimento — vira follow-up se reclamado.

## Padrões de qualidade

≥ 80% / ≥ 98% no núcleo (PIN + Haversine). E2E em `integration_test` cobre todos os caminhos de geo.

## Dependências

- **Bloqueada por:** STORY-057 (geolocalização decidida), STORY-060 (área de ações no detalhe).
- **Bloqueia:** STORY-062 (validação consome PIN gerado).
- **Pré-requisitos:** SCREEN-STORY-061 entregue.

## Decisões já tomadas

ADR-015, ADR-017, **ADR-018 (UUIDv7 em PKs — `turno_id` em audit log/eventos é UUID string; URL `/turnos/{uuid}/gerar-pin-checkin` aceita UUID)**, PDR-008, IDR-026.

## Liberdade técnica

Decide: algoritmo de hash (bcrypt/Argon2id — usar o já presente do EPIC-001), formato da janela de geração, microcopy do estado vazio.

NÃO decide: comportamento de geofencing (PDR-008 fixa); imutabilidade do snapshot (ADR-015 fixa).

## Definição de Pronto

- [ ] CAs marcados; deploy verificado.
- [ ] SCREEN-STORY-061 `shipped`.
- [ ] Alexandro testa em homolog (gera PIN, vê tela grande, geo capturada).
- [ ] `index.json` atualizado.
- [ ] "Notas do agente" preenchida.

## Protocolo

`docs/skills/po/references/agent-task-format.md`.

## Notas do agente

### Entrada inicial (2026-06-05, claude-opus-4-8)

**Documentos lidos:** estória inteira; SCREEN-STORY-061 (ready, aprovado); PDR-008; ADR-015/017/018;
`domain/turno.md`; código existente: `Turno`/`TurnoStatus` (transitionTo + trigger), `Support\Geo\{Haversine,Geofencing}`
(STORY-057 — núcleo pronto e testado), `CheckinGeoController` (PoC — semente desta estória),
`TurnoDetalheController` (EVENTOS já mapeia `turno.checkin_solicitado`), `AprovarCandidaturaService`
(padrão de AuditLog::create em transação), webapp: `geolocalizacao.dart` (captura com guarda de
timeout, razões `permissao_negada|timeout|indisponivel`), `turno_detalhe_screen/service`, harness E2E
(pumpApp + seeds exclusivos por suíte), `TurnosSeeder` (production-safe, sem fake()).

**Entendimento:** botão na área de ações do detalhe (confirmado + janela [-30min,+2h] configurável);
clique captura geo (nunca bloqueia — PDR-008) e POST gera PIN 4 dígitos (hash server-side, plaintext
só na resposta), transita `confirmado→aguardando_checkin` em transação com snapshot
`geofencing_check_in` (Geofencing::avaliar, raio 100m) + audit `turno.checkin_solicitado`; re-geração
em `aguardando_checkin` invalida hash anterior (sem transição); cancelar volta a `confirmado`
(+ audit `turno.checkin_cancelado` — premissa da SCREEN-061 §4.10); tela do PIN ≥64pt efêmera.

**Dúvidas:** nenhuma bloqueante. Ajuste consciente vs. spec: razões de geo seguem o conjunto já
existente do código (`permissao_negada|timeout|indisponivel` — STORY-057) em vez do
`erro_browser` exemplificado no CA-2; microcopy "indisponível" cobre o terceiro caso.

**Plano:**
1. API (TDD): unit `Domain\Turno\PinCheckin` (geração uniforme + anti-trivial) → migration
   `pin_checkin_hash` + `config/turno.php` (janela via env) → feature `gerar-pin-checkin`
   (janela, transição, hash, geofencing, audit, RBAC 403, re-geração) → feature
   `cancelar-pin-checkin` → detalhe: `checkin_janela` no payload do profissional +
   `checkin_cancelado` no EVENTOS + geofencing exposto no item `checkin_solicitado`.
2. WebApp (TDD): service `PinCheckinService` (captura injetável p/ teste) → área de ações
   (janela aberta/antes/depois, loading "um gesto só", erro, aguardando c/ regen+cancelar) →
   `PinCheckinScreen` (PIN mono 72/96pt, nota geo, cancelar) → timeline (nota geofencing +
   evento cancelado).
3. Seeder: turno `confirmado` dentro da janela com usuários exclusivos `*.pin.seed@turni.local`
   (E2E muta estado; não contaminar a suíte da 059/060); refresh de `data_inicio` a cada seed.
4. E2E browser real: 3 caminhos de geo (concedida/negada/timeout) via override de captura
   (`debugCapturarPosicaoOverride`, padrão `debugSetSession`) contra backend real — browser real
   não permite conceder permissão de geo programaticamente no harness; a ponte JS real foi
   validada na PoC da STORY-057. Cada cenário restaura `confirmado` (cancelar) → idempotente.

**Mapeamento CA → testes planejados:**
- CA-1 (janela): feature `gerar pin fora da janela (antes) → 422`, `(depois) → 422`, bordas
  exatas (abre/fecha inclusive), janela via env; widget `botão desabilitado antes/depois com microcopy`.
- CA-2 (geo): feature `geo concedida → snapshot ok`, `negada → razao preservada`,
  `timeout → razao timeout`; widget `loading durante captura`; E2E 3 caminhos.
- CA-3 (PIN+transição): unit `PinCheckin gera 4 dígitos uniformes`, `rejeita triviais
  (repetidos/sequências asc/desc)`; feature `gera → aguardando_checkin + hash bcrypt persistido
  (≠ plaintext)`, `transação: falha não deixa estado parcial`, `estado inválido → 422`.
- CA-4 (plaintext única vez): feature `resposta traz pin 4 dígitos`, `audit payload não contém pin`,
  `re-geração invalida hash anterior`.
- CA-5 (tela + cancelar): widget `PIN ≥64pt + microcopy fixa`, `cancelar volta confirmado`;
  feature `cancelar-pin: aguardando→confirmado + hash limpo + audit`, `cancelar em estado errado → 422`.
- CA-6 (raio/não bloqueia): coberto por GeofencingTest (STORY-057, ≥98%) + feature `fora do raio
  → ok:false e PIN gerado mesmo assim`.
- CA-7 (audit): feature `checkin_solicitado com geofencing_check_in completo no payload`.
- CA-8 (RBAC): feature `contratante → 403`, `terceiro → 403`, `não autenticado → 401`.
- CA-9 (cobertura/E2E): pest --coverage ≥80/≥98 núcleo; E2E `pin_checkin_test.dart` 3 cenários.

### Decisões tomadas

- **Anti-trivial implementado** (CA-3 marcava como opcional): `PinCheckin::ehTrivial` rejeita
  4 dígitos repetidos e sequências de passo 1 asc/desc (24/10.000 ≈ 0,24% de re-sorteio) —
  custo desprezível, PIN menos chutável. Hash **bcrypt** via `Hash::make` (o já presente do
  EPIC-001).
- **Razões de geo**: mantive o conjunto da STORY-057 (`permissao_negada|timeout|indisponivel`)
  em vez do `erro_browser` exemplificado no CA-2 — reuso da validação do `Geofencing` e da
  ponte `geolocalizacao.dart` já testadas; microcopy humana: "permissão negada", "tempo
  esgotado", "indisponível". Registrado também na SCREEN-061.
- **Janela em `config/turno.php`** (`TURNI_CHECKIN_JANELA_ANTES_MIN`/`_DEPOIS_MIN`, defaults
  30/120) com **bordas inclusivas**; o detalhe expõe `checkin_janela` para o profissional —
  a UI deriva microcopy/estado do botão sem hardcodar minutos; servidor revalida (422
  `fora_da_janela` carrega a janela).
- **RBAC 403** nos dois endpoints (CA-8 fixa 403 para contratante; o fail-secure 404 segue
  nas rotas de leitura cruzada).
- **`turno.checkin_cancelado`** criado na trilha (premissa da SCREEN-061 §4.10 — a transição
  `aguardando_checkin→confirmado` pelo profissional precisava de evento); entrou na whitelist
  da timeline do detalhe.
- **Re-geração** em `aguardando_checkin` troca o hash sem transição (o enum/trigger não têm
  self-loop) + audit com `pin_regerado: true`.
- **Tela do PIN efêmera** (sem rota): push de Navigator; refresh cai no detalhe em
  `aguardando_checkin` com "Gerar novo PIN" (CA-4/CA-5, SCREEN-061 §4.7).
- **E2E com posição injetada** (`debugCapturarPosicaoOverride`, padrão `debugSetSession`):
  o Chrome do harness não concede permissão de geolocalização programaticamente; a ponte
  JS real foi validada na PoC da STORY-057. Todo o resto do fluxo é real (POST, bcrypt,
  Haversine, transição, audit). Cada cenário termina cancelando → turno volta a
  `confirmado` (idempotente).
- **Seed `*.pin.seed`** exclusivo (o E2E muta estado; não contamina a suíte 059/060) com
  **refresh da janela a cada reseed** — em homolog a janela não envelhece entre deploys.
- A atomicidade da transação (gerar/cancelar) é garantida por `DB::transaction` + trigger
  do banco; não há teste de falha-no-meio (forçar falha exigiria mock do próprio módulo —
  red flag de mock).

### Descobertas

- O teste de borda exata da janela exige `travelTo(now()->startOfSecond())` — o Postgres
  trunca microssegundos do `datetime` e desloca a borda em <1s.
- No E2E, após o pop da tela do PIN o botão do detalhe aparece **antes** de a tela sair da
  árvore (animação de pop) — assert de `findsNothing` precisa de `pumpAndSettle` após o
  `pumpUntilFound`, que também drena os microtasks de foco (FocusManager disposed flaky).

### Bloqueios encontrados

Nenhum.

### IDRs criados

Nenhum (nenhuma lib nova; decisões locais documentadas acima).

### Cobertura final

- Unitários/integração API: **804 testes verdes; 93,2% total**; núcleo da estória 100%
  (`PinCheckin`, `PinCheckinService`, `PinCheckinController`, `Geofencing`, `Haversine`,
  `TurnoDetalheController`) — CA-9 ≥98% no núcleo ✓.
- WebApp: **441 testes verdes** (27 novos: service do PIN, área de ações, tela do PIN,
  timeline, parse).
- E2E (browser real, same-origin, backend real): `pin_checkin_test.dart` — 3 cenários
  (geo concedida/negada/timeout), gate `make e2e-webapp-integration` verde com a suíte
  completa (auth + cadastro + vagas + feed + turnos).

### Mapeamento CA → teste (provas)

| CA | Testes |
|---|---|
| CA-1 | `GerarPinCheckin`: antes/depois da janela 422 + estado intacto, bordas inclusivas, janela via config; widget: botão desabilitado antes/depois com microcopy, habilitado na janela |
| CA-2 | service webapp: POST com lat/lng/accuracy · geo nulo + razão; feature: negada/timeout preservam razão; E2E 3 caminhos |
| CA-3 | unit `PinCheckin` (formato, uniformidade, anti-trivial, retry, exaustão); feature: hash bcrypt persistido ≠ plaintext, transição, estado inválido 422 |
| CA-4 | feature: resposta com pin 4 dígitos; audit payload sem PIN; re-geração invalida hash anterior; E2E: PIN visível uma vez, regen após refresh |
| CA-5 | widget: PIN ≥64pt + microcopy fixa + cancelar volta; feature `CancelarPinCheckin`: confirmado + hash limpo + audit + ciclo gerar→cancelar→gerar |
| CA-6 | `GeofencingTest` (STORY-057, 100%); feature: fora do raio → ok:false + PIN gerado |
| CA-7 | feature: audit `turno.checkin_solicitado` com snapshot completo; detalhe expõe geofencing na timeline |
| CA-8 | feature: contratante 403, terceiro 403, 401 (gerar e cancelar); widget: contratante sem botão |
| CA-9 | pest --coverage (93,2% / núcleo 100%); E2E 3 cenários de geo verdes |

### Links de evidência

- PR: commit direto na main (workflow do projeto) — TDD evidenciado na sequência de commits
  `test(...) (red)` → `feat(...) (green)` de 2026-06-05.
- Pipeline: CI da main + tag de release.
- Deploy de homologação: v0.1.0-rc.73 (tag desta entrega).
