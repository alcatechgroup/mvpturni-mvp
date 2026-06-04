---
adr_id: ADR-017
slug: tempo-real-cronometro-polling-e-geolocalizacao-haversine
title: Tempo real do cronômetro bilateral por âncora-de-timestamp + polling curto, e geolocalização no check-in por Geolocation API + Haversine (reuso), sem WebSocket nem PostGIS
status: accepted  # proposed | accepted | superseded | rejected | deferred
decided_at: 2026-06-04
decided_by: arquiteto
approved_by: Alexandro
supersedes: null
superseded_by: null
related_adrs: [ADR-001, ADR-002, ADR-004, ADR-014, ADR-015]
related_pdrs: [PDR-008]
related_idrs: [IDR-026]
related_epics: [EPIC-003]
created_at: 2026-06-04
updated_at: 2026-06-04
source_story: STORY-057
---

# ADR-017 — Tempo real do cronômetro bilateral e geolocalização do check-in

> Duas decisões de **estratégia técnica de runtime** numa só ADR (superfície disjunta, afinidade de timing — ambas tocam o evento de check-in/`ativo`): **(a)** como o cronômetro bilateral fica sincronizado em tempo real entre os dois lados (≤ 2s) e **(b)** como o check-in mede a distância profissional↔estabelecimento para a flag de geofencing (PDR-008).

## Contexto

`docs/especificacao/domain/turno.md` exige um **cronômetro bilateral** que inicia na transição `aguardando_checkin → ativo`, encerra em `aguardando_checkout → finalizado` e é **visível em tempo real para ambos os lados** enquanto o turno está `ativo`. A SPRINT-2026-W28 fixa o alvo numérico: **sincronia ≤ 2s** entre o que o profissional vê e o que o contratante vê. O `domain/turno.md` também exige que o PIN de check-in carregue a flag `geofencing_ok` e a **distância medida** (`geofencing_check_in = { ok, distancia_metros, capturado_em }`), conforme **PDR-008** (alerta-e-registra, não bloqueia).

Sem decisão de runtime cobrindo esses dois pontos, **STORY-063** (cronômetro bilateral, L) e **STORY-061** (check-in + geofencing) não conseguem começar. Esta ADR escolhe **como tecnicamente** entregar — o **comportamento** já está fixado (cronômetro vivo em `domain/turno.md`; geofencing alerta-e-registra em PDR-008) e **não** é reaberto aqui.

Duas restrições herdadas dominam a deliberação:

- **Topologia de hospedagem (ADR-004): Cloud Run stateless + scale-to-zero.** `api` e `admin` são serviços Cloud Run baseados em request HTTP, que escalam a zero em homologação e multiplicam instâncias sob carga sem estado compartilhado. Qualquer canal que exija um **processo always-on com conexões persistentes e estado de conexão por instância** (WebSocket/SSE) briga com esse modelo: precisa de uma peça extra always-on (como o `worker` já é uma exceção em VM), de um fan-out entre instâncias (Redis pub/sub — segundo armazenamento que o princípio #3 manda evitar) e de mais orçamento e operação para um time minúsculo (princípios #1, #11).
- **`TurniDateTime` (IDR-026) já é a fronteira única de data/hora do WebApp.** A API troca instantes em **UTC**; a UI converte para local num único ponto; o round-trip é lossless. O cronômetro consome essa política — ele exibe uma **duração** derivada de um instante de início (verdade do servidor), não um relógio de parede que cada cliente inventa.

Para a geolocalização, o helper **`App\Support\Geo\Haversine`** já existe e está testado (criado em STORY-049/EPIC-002, reusado entre `FeedQuery` e `VagaDetalheQuery`) — calcula distância entre dois pares lat/lng, retornando `null` quando falta geo de qualquer lado. CA-3 e CA-6 da STORY-057 pedem explicitamente o **reuso** desse código já coberto.

## Forças (drivers) da decisão

- **F1 — Simplicidade e não-antecipação (princípios #1 e #7):** peso **alto**. A solução mais simples que entrega o comportamento atual. Não adicionar infra de tempo real "porque um dia teremos chat".
- **F2 — Fit com a topologia stateless do Cloud Run (ADR-004):** peso **alto**. A escolha não pode exigir um processo always-on com estado de conexão que o Cloud Run não comporta limpo.
- **F3 — Sincronia ≤ 2s entre os dois lados (DoD do sprint, CA-5):** peso **alto**. Requisito duro de produto — cronômetro fora de sincronia quebra a confiança.
- **F4 — Servidor como fonte de verdade do tempo (CA-4):** peso **alto**. Clientes só consomem; mitiga o risco de clocks divergentes registrado no sprint.
- **F5 — Postgres-first, sem segundo armazenamento (princípio #3):** peso **alto**. Evitar Redis/PostGIS sem prova numérica de necessidade.
- **F6 — Custo recorrente em homolog/prod (princípio #11):** peso **médio**. Cada peça always-on tem piso de custo; Cloud Run a zero não.
- **F7 — Reuso de código já testado (CA-3/CA-6, princípio #5):** peso **médio**. `Haversine` já existe e está coberto; reusar > reimplementar.
- **F8 — Compatibilidade com TDD/E2E (princípio #10):** peso **médio**. A escolha precisa ser testável sem heroísmo (o cálculo de tempo e de distância devem ser funções puras testáveis isoladamente).

---

## Decisão (a) — Canal de tempo real do cronômetro

### Insight que reduz o problema

O requisito "tempo real" **colapsa num único timestamp**. Se o servidor é a fonte de verdade (F4/CA-4), o cronômetro não é um fluxo de tiques que precisam ser empurrados — é uma **duração derivada de um instante de início fixo** (`iniciado_em`, gravado na transição `→ ativo`). O servidor expõe `iniciado_em` **e a sua hora atual** (`servidor_agora`); cada cliente:

1. calcula um **offset de relógio** uma vez: `offset = cliente_agora − servidor_agora`;
2. **tica localmente** a cada segundo: `decorrido = (cliente_agora − offset) − iniciado_em`;
3. **reconcilia periodicamente** (polling curto) para corrigir drift do relógio local e detectar a saída de `ativo` (check-out → cronômetro encerra).

Assim a **sincronia entre os dois lados é estrutural, não dependente de latência de canal**: ambos ancoram no mesmo `iniciado_em` e ambos cancelam o próprio skew via offset contra o mesmo relógio de servidor. Dois clientes lendo o mesmo `iniciado_em` mostram a mesma duração a menos do erro residual de offset (uma medição de rede, tipicamente < 1s) — muito dentro dos 2s. Empurrar tiques por WebSocket seria empurrar pela rede um número que o cliente **já sabe computar sozinho**.

### Opções consideradas

#### Opção A — Âncora-de-timestamp + polling de janela curta — **escolhida**
- **Resumo:** o cronômetro é puramente derivado. Endpoint REST leve (ex.: `GET /turnos/{id}/cronometro`) devolve `{ estado, iniciado_em, servidor_agora, encerrado_em? }`. O WebApp tica localmente (sem rede por tique) e faz polling a cada **~5s** apenas para reconciliar offset e detectar transição de estado. Nenhuma infra nova; usa a API REST que já existe (Cloud Run, stateless).
- **Como atende aos princípios:**
  - ✅ **Simplicidade (1) / não-antecipação (7):** zero peça nova; o "canal" é o REST existente.
  - ✅ **Fit Cloud Run (ADR-004):** requests curtos e stateless — o modelo nativo do Cloud Run, escala a zero entre turnos.
  - ✅ **Postgres-first (3):** sem Redis; `iniciado_em` é uma coluna do turno (ADR-015).
  - ✅ **Custo (11):** sem processo always-on; sem piso de conexão.
  - ✅ **Servidor fonte de verdade (CA-4):** o tempo nasce de `iniciado_em` + `servidor_agora`; o cliente nunca é autoridade.
  - ✅ **TDD (10):** o cálculo de `decorrido`/offset é função pura testável; o endpoint é teste de feature trivial.
- **Prós concretos:** simplicidade máxima; sincronia estrutural ≤ 2s; reusa autenticação/observabilidade da API; degrada graciosamente (perdeu polling → o tique local segue; reconcilia no próximo ciclo).
- **Contras concretos:** o polling tem custo de N requests/turno-ativo (mitigável: janela de 5s, pausa quando a aba está em background, para no fim do turno); não é "push" — uma transição de estado pode demorar até uma janela (~5s) para ser notada pelo outro lado (aceitável: check-out não exige reação sub-segundo).

#### Opção B — WebSocket (Laravel Reverb)
- **Resumo:** servidor WS persistente (Reverb) empurra eventos de turno; clientes assinam um canal por turno.
- **Como atende aos princípios:** ❌ **Fit Cloud Run:** Reverb é um servidor always-on com estado de conexão por instância — não cai limpo no Cloud Run stateless; exige peça extra (VM, como o `worker`) e **Redis pub/sub** para fan-out entre instâncias (segundo armazenamento — fere princípio #3 sem prova de dor). ❌ **Simplicidade (1)/não-antecipação (7):** infra de tempo real para empurrar um número derivável de um timestamp. ⚠️ **Custo (11):** piso de processo always-on + Redis.
- **Prós:** push real (latência sub-segundo); pronto para futuros fluxos genuinamente push (chat, presença).
- **Contras:** desproporcional ao problema; custo e operação que um time minúsculo não justifica agora.
- **Razão da rejeição:** perde decisivamente em F1, F2, F5 e F6. O ganho (push sub-segundo) não tem dor real que o exija — o cronômetro não precisa de push, e não há outro fluxo push no EPIC-003.

#### Opção C — SSE (Server-Sent Events)
- **Resumo:** stream HTTP unidirecional de longa duração; o servidor envia tiques/eventos.
- **Como atende aos princípios:** ⚠️ mais leve que WS (sem handshake bidirecional, sem Redis obrigatório para o caso simples), mas ainda é **conexão longa** que briga com o modelo request/scale-to-zero do Cloud Run (timeouts de request, instância presa por conexão) e **não ganha nada** sobre o polling aqui, já que o tique é local.
- **Razão da rejeição:** carrega o ônus da conexão persistente (F2) sem entregar valor sobre a Opção A — o cliente não precisa de stream para exibir uma duração que ele mesmo computa.

#### Opção D — Status quo (sem decisão)
- **Consequência:** STORY-061/063 ficam bloqueadas; o caminho até `ativo` não fecha no sprint.
- **Custo de adiar:** bloqueia o coração do EPIC-003. Descartada — a decisão é necessária agora.

### Matriz comparativa (a)

| Critério (força) | Peso | A — Âncora + polling | B — WebSocket (Reverb) | C — SSE |
|---|---|---|---|---|
| F1 — Simplicidade / não-antecipação | alto | ✅ zero peça nova | ❌ infra de tempo real | ⚠️ conexão longa |
| F2 — Fit Cloud Run stateless | alto | ✅ request curto nativo | ❌ always-on + Redis | ❌ conexão longa presa |
| F3 — Sincronia ≤ 2s | alto | ✅ estrutural (âncora comum) | ✅ push | ✅ stream |
| F4 — Servidor fonte de verdade | alto | ✅ `iniciado_em`+`servidor_agora` | ✅ servidor emite | ✅ servidor emite |
| F5 — Postgres-first | alto | ✅ sem 2º armazenamento | ❌ Redis p/ fan-out | ⚠️ ok no caso simples |
| F6 — Custo recorrente | médio | ✅ escala a zero | ❌ piso always-on + Redis | ⚠️ instância presa |

---

## Decisão (b) — Geolocalização no check-in

### Opções consideradas

#### Opção A — Browser Geolocation API + Haversine no backend (reuso) — **escolhida**
- **Resumo:** no momento da geração do PIN de check-in, o WebApp Flutter Web pede a posição via **Geolocation API do navegador** (`navigator.geolocation`) e envia `{ lat, lng }` ao backend. O backend calcula a distância em metros até as coordenadas do estabelecimento usando **`App\Support\Geo\Haversine`** (já testado, STORY-049) — `km × 1000` → metros — e grava `geofencing_check_in = { ok, distancia_metros, capturado_em }` no evento de check-in. `ok = distancia_metros ≤ 100` (raio do `domain/turno.md`). Quando a posição falha (permissão negada, GPS off, timeout), o evento registra `ok: false`, `distancia_metros: null` e a **razão** (`permissao_negada`, `timeout`, `indisponivel`) — exatamente o cenário "sem coordenada" previsto na STORY-061.
- **Como atende aos princípios:**
  - ✅ **Simplicidade (1):** uma única distância ponto-a-ponto; função pura já existente.
  - ✅ **Postgres-first (3):** sem extensão nova — Haversine roda em PHP puro.
  - ✅ **Reuso / coesão (5, F7):** o mesmo cálculo que o feed usa; um lugar para a fórmula.
  - ✅ **TDD (10, CA-6):** núcleo já com cobertura; basta a conversão km→m e a regra de raio/razão.
- **Prós:** reuso direto de código coberto; PDR-008 (alerta-e-registra) cabe sem bloqueio; cenário "sem coordenada" é first-class.
- **Contras:** precisão depende do dispositivo/navegador (aceito — PDR-008 não bloqueia; contratante é a barreira); cálculo Haversine assume Terra esférica (erro < 0,5% em distâncias urbanas — irrelevante para um raio de 100m).

#### Opção B — PostGIS
- **Resumo:** extensão geoespacial no Postgres; coordenadas como `geography`; distância via `ST_Distance`/`ST_DWithin`.
- **Como atende aos princípios:** ⚠️ poderoso, mas justificável apenas quando há **queries espaciais em massa** (índice espacial sobre muitos pontos, "estabelecimentos num raio") — **não** para uma única distância ponto-a-ponto no instante do check-in. Adiciona uma extensão a habilitar/manter (princípio #1) sem dor real.
- **Razão da rejeição:** complexidade sem necessidade demonstrada; o `Haversine` já resolve o caso atual com código testado. PostGIS fica como caminho natural **se/quando** surgir busca espacial em massa (sinal de revisão abaixo).

> Decisão (b) é **claramente óbvia**: reusar um helper já testado para calcular uma única distância vence habilitar uma extensão geoespacial inteira. A matriz seria teatro — a única força em que PostGIS ganharia (queries espaciais em escala) não está no problema.

---

## Decisão proposta

> **Optamos pela Opção A em ambas as decisões.**

**(a) Cronômetro bilateral — âncora-de-timestamp + polling de janela curta.** O cronômetro é uma **duração derivada**, não um fluxo empurrado. O servidor é a fonte de verdade do tempo: grava `iniciado_em` (UTC) na transição `→ ativo` e expõe um endpoint REST leve devolvendo `{ estado, iniciado_em, servidor_agora, encerrado_em? }`. O WebApp calcula um offset de relógio contra `servidor_agora`, **tica localmente** a cada segundo (consumindo `TurniDateTime`/IDR-026 para a fronteira UTC↔local e formatação de duração) e faz **polling a cada ~5s** apenas para reconciliar o offset e detectar a saída de `ativo`. **Nenhuma infra de tempo real nova** — o "canal" é a API REST existente sobre Cloud Run. A invariante **"servidor é a fonte de verdade do tempo decorrido; clientes só consomem"** fica fixada por esta ADR (CA-4).

**(b) Geolocalização no check-in — Geolocation API do navegador + Haversine no backend.** O WebApp captura `{ lat, lng }` via Geolocation API no momento do PIN; o backend calcula a distância em metros com o helper `App\Support\Geo\Haversine` **reusado** (STORY-049), aplica o raio de 100m para `geofencing_ok` e grava o snapshot `geofencing_check_in = { ok, distancia_metros, capturado_em }` no evento. Falha de captura vira `ok: false`, `distancia_metros: null` + razão. **Sem PostGIS.**

## Justificativa

A decisão (a) vence porque **reduz o problema antes de resolvê-lo**: ao reconhecer que um cronômetro com servidor como fonte de verdade é uma duração derivada de um único instante, a necessidade de um canal push desaparece. A sincronia ≤ 2s passa a ser uma propriedade **estrutural** (âncora comum + cancelamento de skew) em vez de uma corrida contra a latência de rede — e isso se entrega com **zero peça nova**, em pleno acordo com a topologia stateless do Cloud Run (ADR-004) e com os princípios #1, #3, #7 e #11. WebSocket e SSE resolveriam um problema que não temos (push sub-segundo) ao custo de infra always-on que um time minúsculo não justifica. O trade-off honesto: uma transição de estado (check-out) pode levar até ~5s para o outro lado notar — aceitável, pois nada no fluxo exige reação sub-segundo, e a janela é um parâmetro ajustável.

A decisão (b) vence por reuso e simplicidade: o `Haversine` já existe, já está testado, e o caso é uma única distância ponto-a-ponto. PostGIS seria habilitar uma extensão inteira para um cálculo que cabe numa função pura — complexidade sem dor real (princípio #1). PDR-008 (alerta-e-registra) encaixa naturalmente: o cálculo nunca bloqueia, e o cenário "sem coordenada" é tratado como dado de primeira classe.

## Diagrama — fluxo do cronômetro (decisão a)

```mermaid
sequenceDiagram
    participant P as WebApp Profissional
    participant C as WebApp Contratante
    participant API as api (Cloud Run, REST)
    participant DB as PostgreSQL

    Note over API,DB: transição aguardando_checkin → ativo grava iniciado_em (UTC)
    P->>API: GET /turnos/{id}/cronometro
    API->>DB: SELECT estado, iniciado_em
    API-->>P: { estado: ativo, iniciado_em, servidor_agora }
    C->>API: GET /turnos/{id}/cronometro
    API-->>C: { estado: ativo, iniciado_em, servidor_agora }
    Note over P: offset_P = cliente_agora − servidor_agora
    Note over C: offset_C = cliente_agora − servidor_agora
    loop a cada 1s (LOCAL, sem rede)
        Note over P: decorrido = (cliente_agora − offset_P) − iniciado_em
        Note over C: decorrido = (cliente_agora − offset_C) − iniciado_em
    end
    loop a cada ~5s (reconciliação)
        P->>API: GET /turnos/{id}/cronometro
        API-->>P: { estado, iniciado_em, servidor_agora, encerrado_em? }
        Note over P: corrige offset; se estado ≠ ativo, encerra cronômetro
    end
```

Ambos os lados ancoram no **mesmo** `iniciado_em` → sincronia estrutural ≤ 2s.

## Consequências

### Positivas (o que ganhamos)
- Zero infra de tempo real nova; o cronômetro vive sobre a API REST e o Cloud Run existentes (escala a zero entre turnos).
- Sincronia ≤ 2s é estrutural, não frágil a picos de latência.
- Servidor é fonte de verdade do tempo (CA-4) — clocks divergentes do cliente deixam de ser risco.
- Reuso direto do `Haversine` já testado; um único lugar para a fórmula de distância (coerente com STORY-049).
- Degradação graciosa: perda de rede pausa só a reconciliação; o tique local segue e corrige no próximo ciclo.

### Negativas / trade-offs aceitos
- **Polling não é push:** uma transição de estado (check-out) pode levar até ~5s para o outro lado notar. Aceito — nenhum fluxo exige reação sub-segundo; a janela é parâmetro ajustável.
- **Custo de N requests por turno ativo:** mitigado por janela de 5s, pausa em background (`visibilitychange`) e parada no fim do turno. Em homolog/prod é tráfego barato sobre Cloud Run.
- **Precisão de geolocalização depende do dispositivo:** aceito por PDR-008 (não bloqueia; contratante é a barreira).
- **Haversine assume Terra esférica:** erro < 0,5%, irrelevante para um raio de 100m.

### Neutras
- O endpoint do cronômetro é mais um recurso REST do turno — cabe no padrão de API já existente (ADR-001/002), sem nova superfície de segurança (Sanctum cobre).
- `servidor_agora` no payload existe **só** para o offset de relógio; não é exibido ao usuário (a UI formata `decorrido` via `TurniDateTime`).

### Para o time
- **Impacto em estórias existentes:** **destrava STORY-063** (cronômetro bilateral — implementa o endpoint + tique local + polling) e **STORY-061** (check-in — captura geo + grava snapshot via Haversine). STORY-062 (validação check-in) consome o mesmo snapshot. STORY-060 (detalhe + timeline) exibe a duração final do turno a partir de `iniciado_em`/`encerrado_em`.
- **ADRs/IDRs relacionados:** consome IDR-026 (`TurniDateTime`) para a fronteira de tempo; respeita ADR-004 (Cloud Run) e ADR-015 (modelo Turno — `iniciado_em`/`encerrado_em` são colunas do turno). ADR-014 reusa o mesmo `Haversine` no feed.
- **Necessidade de spike de validação:** a própria PoC desta estória (CA-5) valida empiricamente em homolog — dois navegadores sincronizados ≤ 2s + distância calculada no backend.

## Plano de verificação

- **Como verificar conformidade:**
  - O tempo decorrido **nunca** nasce no cliente — teste/revisão de PR garante que a UI deriva de `iniciado_em` + offset, sem `Stopwatch` local autônomo como fonte.
  - Cálculo de `decorrido`/offset e a conversão km→m do Haversine são **funções puras** com teste unitário (CA-6: ≥ 98% no núcleo de Haversine — herdado da cobertura de STORY-049; ≥ 80% no código novo do cronômetro).
  - Nenhuma dependência de WebSocket/SSE/Redis entra no `composer.json`/`pubspec.yaml` (lint/revisão).
- **PoC (CA-5):** turno seedado em `ativo` em homolog; cronômetro avançando sincronizado ≤ 2s em dois navegadores (profissional + contratante); Geolocation do navegador chegando ao backend e distância em metros calculada via Haversine. Evidência (vídeo/screenshot dos dois navegadores) anexada à estória.
- **Sinais de revisão (quando reabrir esta decisão):**
  - Se surgir um fluxo **genuinamente push** (chat ao vivo, presença, notificação sub-segundo) → reabrir o canal (Reverb/SSE), aí com dor real justificando a infra.
  - Se o custo de polling em prod (com volume real de turnos simultâneos) virar linha relevante na conta → ajustar a janela ou reavaliar SSE para o caso de muitos turnos ativos concorrentes.
  - Se surgir **busca espacial em massa** (estabelecimentos/profissionais num raio, com índice) → reabrir a decisão (b) para PostGIS.
  - Se a sincronia medida em homolog/prod ultrapassar 2s de forma consistente → investigar offset de relógio / janela de polling antes de trocar de mecanismo.
- **Follow-up registrado (fora de escopo desta estória):** política de retry quando o navegador perde conexão por > 5s (a STORY-057 a declara fora de escopo) — o tique local cobre a lacuna curta; a política formal de reconexão fica para a STORY-063.

---

## Aprovação humana

> Esta seção é o registro formal do aceite. Não preencher sozinho — preencher quando o humano aprovar no chat ou via PR.

- **Status final:** ✅ aceita
- **Aprovado por:** Alexandro
- **Data:** 2026-06-04
- **Forma do aceite:** aprovado em chat (sessão de 2026-06-04), após confirmação prévia da direção das duas decisões.
- **Condicionantes do aceite:** nenhuma. PoC (CA-5) e cobertura (CA-6) seguem como fase de implementação desta mesma estória.

### Em caso de rejeição
- **Motivo:** ...
- **Próximos passos sugeridos:** ...

---

## Histórico

- 2026-06-04 — criada como `proposed` por Arquiteto (STORY-057), após confirmação de direção com Alexandro: (a) polling de janela curta com âncora-de-timestamp e (b) Geolocation API + Haversine (reuso), ambas as recomendações do Arquiteto.
- 2026-06-04 — `accepted` por Alexandro (aprovação em chat). Liberada a fase de implementação da PoC (CA-5/CA-6).
