---
adr_id: ADR-016
slug: acl-pagarme-sandbox-idempotencia-webhook
title: Implementação concreta da ACL Pagar.me — interface GatewayPagamento, adapter HTTP, mock em container que devolve o webhook, idempotência sobre Postgres e webhook entrante validado por HMAC
status: proposed  # proposed | accepted | superseded | rejected | deferred
decided_at: null
decided_by: arquiteto
approved_by: null
supersedes: null
superseded_by: null
related_adrs: [ADR-002, ADR-004, ADR-005, ADR-008, ADR-015, ADR-018]
related_pdrs: [PDR-004, PDR-006, PDR-010]
related_epics: [EPIC-003, EPIC-005]
created_at: 2026-06-04
updated_at: 2026-06-04
source_story: STORY-056
---

# ADR-016 — Implementação concreta da ACL Pagar.me

## Contexto

A **ADR-005** (`accepted`, 2026-05-27) fixou a **estratégia de alto nível** da integração financeira: Anti-Corruption Layer no módulo `Pagamento`, mock dedicado em container, idempotência por chave de operação, fluxo pré-autorização → captura → Pix com webhook entrante validado, e contract test contra o sandbox no CI noturno (Opção A da ADR-005). Esta ADR **não reabre** nada disso — ela **aterrissa** a estratégia em schema, classes, contrato HTTP e rotas concretas, para que STORY-058 (pré-autorização no aceite), STORY-065 (captura + Pix) e STORY-066 (liberação no cancelamento) tenham fundação executável e testável **sem internet**.

As restrições já fixadas que esta ADR herda sem discutir: a integração roda em **jobs assíncronos no `worker`** sobre a fila `database` e o **webhook entra no `api`** (ADR-002); **segredos no Secret Manager**, webhook público em `southamerica-east1` (ADR-004); **log JSON em stdout com `request_id` propagado `api`→fila→`worker`** e log-based metrics (ADR-008); **PKs e FKs em UUIDv7**, com `external_reference` carregando o UUID do turno como string (ADR-018); o **modelo de Turno e a máquina de estados** já existem (ADR-015); a **falha de Pix é uma tentativa + alerta admin, sem retry automático** (PDR-010); e o **modelo financeiro** é `total_contratante = valor + taxa_turni`, com a `taxa_turni` ficando na conta Turni (PDR-004, `domain/pagamento.md`).

O que **falta decidir** (e esta ADR decide) são as escolhas concretas que terão impacto transversal — outros agentes vão se basear nelas: (1) a **forma da interface** `GatewayPagamento` (vocabulário, assinaturas, tipos de retorno e de erro); (2) **onde mora a correlação** com os identificadores do Pagar.me e **como a idempotência é persistida** (uma tabela ou duas; qual chave; o que curto-circuita); (3) o **contrato HTTP** que o adapter fala e que o mock simula; (4) a **forma do webhook entrante** (validação, deduplicação, processamento assíncrono) e **quais eventos de domínio** ele emite para STORY-065/067; (5) a **seleção de driver** (`mock|sandbox|live`) sem `if` espalhado pelo código.

Esta é a estória **L** de maior risco da WAVE-2026-01. Conforme o gatilho de quebra da STORY-056, ela foi dividida: **STORY-056-A** (esta ADR + a implementação local completa — interface, adapter, mock, idempotência, webhook, observabilidade) e **STORY-056-B** (o contract test consumer-driven contra o sandbox real no CI noturno + alerta de divergência, CA-8). Esta ADR **descreve o desenho inteiro**, inclusive a parte que a STORY-056-B implementa, porque a decisão arquitetural é uma só; a separação é de execução, não de design.

## Forças (drivers) da decisão

- **F1 — Isolamento do provedor (princípio #5, F1 da ADR-005):** peso **alto**. Nenhum `order_id`/`charge_id`/status do Pagar.me pode vazar para o modelo de Turno ou para os controllers. A interface fala vocabulário Turni; o adapter é o único que conhece o provedor.
- **F2 — Idempotência à prova de clique-duplo e retry (PDR-004, F3 da ADR-005):** peso **alto**. Dinheiro não pode mover duas vezes. Aprovar a candidatura duas vezes, o worker retentar um job, ou o Pagar.me reenviar o webhook **não** pode duplicar pré-autorização/captura/Pix.
- **F3 — Local 100% sem internet (princípio #6, F2 da ADR-005):** peso **alto**. `docker compose up` roda o ciclo financeiro inteiro contra o mock, inclusive recebendo o webhook de volta. `make setup` continua hermético.
- **F4 — Testabilidade do núcleo (princípio #10, `quality-standards.md`):** peso **alto**. Idempotência, parsing/validação do webhook e mapeamento de erro são o núcleo financeiro — exigem ≥ 98% de cobertura. O desenho tem que permitir testar essas três peças **sem** subir container e **sem** rede.
- **F5 — Webhook seguro e idempotente (`integration-architecture.md` §webhook, F3 da ADR-005):** peso **alto**. Assinatura HMAC validada; duplicata por `event_id` responde 200 sem reprocessar; recepção rápida + processamento assíncrono.
- **F6 — Observabilidade financeira com PII mascarada (ADR-008, F6 da ADR-005):** peso **médio**. Cada operação emite uma linha JSON correlacionável por `request_id`; a chave Pix **nunca** aparece em claro.
- **F7 — Simplicidade / não-antecipação (princípio #1, F7 da ADR-005):** peso **alto**. Uma tabela em vez de duas se uma resolve; nenhum broker; idempotência sobre o Postgres que já temos; captura parcial exposta na interface (para o EPIC-005) mas **não** implementada além do necessário.

## Opções consideradas

A maioria das tensões já foi resolvida pela ADR-005 (ACL vs cliente direto, mock em container vs `Http::fake`, sandbox como CI noturno vs como dev local). Restam **três decisões locais reais**, cada uma com uma escolha não-óbvia.

### Decisão 1 — Correlação + idempotência: uma tabela ou duas?

A ADR-005 menciona em alto nível uma **tabela de correlação** (`pagamento_externo_ref`) e uma **chave idempotente** registrada localmente. A CA-1 da STORY-056 lista "tabela de correlação (turno_id ↔ order_id/charge_id)" **e** "tabela de idempotência (chave + status + payload)" — pode soar como duas tabelas. A CA-5 só exige **uma**: `pagamento_operacoes`.

- **Opção 1A — Uma tabela `pagamento_operacoes` (escolhida).** Linha por operação financeira, chaveada por `(turno_id, tipo_operacao)` único. Guarda `idempotencia_chave`, `status`, `request_payload` e `response_payload` (jsonb) **e** colunas desnormalizadas de correlação (`pagarme_order_id`, `pagarme_charge_id`, `pagarme_transfer_id`) extraídas da resposta para consulta direta. A correlação é uma **projeção** da resposta, não uma tabela à parte.
  - ✅ Simplicidade (#1/F7): um turno tem ≤ 5 operações financeiras na vida; não há cardinalidade que justifique normalizar a correlação numa tabela própria. Um `JOIN` a menos, uma migração a menos, uma fonte de verdade.
  - ✅ Idempotência (F2): o índice único `(turno_id, tipo_operacao)` **é** a garantia de não-duplicação — o banco recusa a segunda pré-autorização do mesmo turno.
  - ✅ Auditoria (ADR-015/`compliance.md`): request e response ficam imutáveis na própria linha que prova a operação.
- **Opção 1B — Duas tabelas (`pagamento_externo_ref` + `pagamento_operacoes`).** Separa a correlação (1 linha por id de provedor) do log de operação.
  - ⚠️ Normalização que não paga: a relação é praticamente 1:1 entre operação e id de correlação; separar cria FK e JOIN sem ganho de integridade real no MVP.
  - ❌ Mais superfície (duas migrações, dois modelos, dois triggers de imutabilidade) contra o princípio #1.

> **Decisão óbvia (1A):** com ≤ 5 operações por turno e relação ~1:1 com os ids do provedor, normalizar a correlação numa segunda tabela é complexidade sem dor real. Uma tabela com colunas de correlação desnormalizadas atende CA-1 e CA-5 e respeita o princípio #1. Caso o EPIC-005 (disputa: captura parcial + estorno) revele necessidade de N operações do mesmo tipo por turno, a chave `(turno_id, tipo_operacao)` evolui para incluir uma sequência — gatilho registrado em "Plano de verificação".

### Decisão 2 — Seleção de driver (`mock|sandbox|live`): subclasses ou base_url por config?

A ADR-005 fixou `PAGARME_DRIVER=mock|sandbox|live`. Como isso vira código?

- **Opção 2A — Um único `PagarmeGateway`, `base_url` + credenciais resolvidas por config (escolhida).** Existe **um** adapter. O `config/services.php` mapeia o driver para `base_url` (mock → `http://pagarme-mock:8080`; sandbox/live → host do Pagar.me) e para a chave secreta correspondente. O mock fala o **mesmo contrato HTTP** do Pagar.me real (é o ponto inteiro da Opção A da ADR-005), então não há ramificação de código por driver.
  - ✅ Isolamento (F1) e simplicidade (F7): zero `if ($driver === 'mock')` no adapter; o driver só troca um endereço e uma credencial.
  - ✅ Fidelidade (F5/contract test): como o mesmo código fala com mock e com sandbox, o contract test da STORY-056-B exercita exatamente o caminho de produção.
- **Opção 2B — Uma implementação de `GatewayPagamento` por driver (`MockGateway`, `PagarmeGateway`).** O binding troca a classe inteira.
  - ❌ Viola F5: o `MockGateway` seria um caminho de código **diferente** do que roda em produção — o contract test deixaria de guardar o código real. Reintroduz o problema que a ADR-005 rejeitou ao recusar o `Http::fake` (Opção B de lá).

> **Decisão óbvia (2A):** o mock é um **container que fala o protocolo**, não um duble de objeto. Logo há um só adapter; o driver é só endereço + credencial em config. Isso é o que mantém o contract test honesto.

### Decisão 3 — Forma do erro e do retorno da interface

- **Opção 3A — Retorno: um value object `ResultadoOperacao`; erro: exceções de domínio tipadas (escolhida).** Cada operação devolve um `ResultadoOperacao` imutável (tipo, status, ids de correlação, payload bruto). Falhas **fatais de negócio** (recusa de pré-autorização, dados inválidos, chave Pix inválida) viram `PreAutorizacaoNegada`, `CapturaFalhou`, `PixFalhou`, `LiberacaoFalhou` (todas estendendo `OperacaoPagamentoException`). Falhas **recuperáveis** (timeout, 5xx, rede) viram `GatewayIndisponivel` — sinal para o worker retentar com backoff. Nenhum `HTTP 4xx/5xx` do Pagar.me sobe.
  - ✅ F1: o domínio só vê exceções dele. O mapeamento HTTP→exceção mora num lugar (o adapter).
  - ✅ F4: o mapeamento de erro é uma função pura testável com `Http::fake` — entra no núcleo de 98%.
- **Opção 3B — Retorno `Result<T,E>` (sem exceções).** Mais funcional, mas estranho ao idioma Laravel já adotado no resto do `api` (services lançam exceções de domínio — ver `Cadastro`, `Candidatura`). Inconsistência transversal sem ganho.

> **Decisão óbvia (3A):** espelha o idioma já usado nos outros módulos de domínio do `api` (exceções de domínio), mantém o externo isolado e deixa o mapeamento de erro testável como função.

## Decisão proposta

> **Optamos por: uma tabela `pagamento_operacoes` (1A), um adapter `PagarmeGateway` com driver por config (2A), e retorno por value object + exceções de domínio tipadas (3A) — tudo dentro do módulo `app/Domain/Pagamento`.**

### (a) Interface `GatewayPagamento` (CA-2)

Vive em `app/Domain/Pagamento/GatewayPagamento.php`. Cinco operações, vocabulário Turni, **sem** vazar conceito do provedor. Valores monetários trafegam como **string decimal** (`"123.45"`) — coerente com o cast `decimal:2` do `Turno` (ADR-015) e à prova do erro de ponto flutuante; o adapter converte para centavos inteiros na fronteira.

```php
interface GatewayPagamento
{
    public function preAutorizar(string $turnoId, string $totalContratante, string $meioPagamentoToken): ResultadoOperacao;
    public function capturar(string $turnoId): ResultadoOperacao;
    public function capturarParcial(string $turnoId, string $valorRevisado): ResultadoOperacao; // EPIC-005, exposto desde já
    public function liberar(string $turnoId): ResultadoOperacao;
    public function transferirPix(string $turnoId, string $valorProfissional, string $chavePix): ResultadoOperacao;
}
```

`ResultadoOperacao` é um value object imutável: `tipo` (enum `TipoOperacaoPagamento`), `status` (enum `StatusOperacaoPagamento`), `pagarmeOrderId`/`pagarmeChargeId`/`pagarmeTransferId` (nullable, **identificadores opacos**, não PII), e `raw` (array da resposta para a trilha). O `meioPagamentoToken` na pré-autorização é o token do meio de pagamento do contratante — **fornecido pela STORY-058**; nesta estória existe só na assinatura e no mock.

> **Refinamento sobre a ADR-005:** a ADR-005 escreveu as assinaturas como `preAutorizar(turno, totalContratante)`. Esta ADR passa **`string $turnoId` + valores primitivos** em vez do modelo Eloquent `Turno`, para não acoplar a ACL à camada de persistência e manter o núcleo testável sem banco (F1/F4). É refinamento de vocabulário, não mudança de estratégia.

### (b) Idempotência sobre `pagamento_operacoes` (CA-5, Decisão 1A)

Tabela nova (migração + modelo `App\Models\PagamentoOperacao`), seguindo ADR-018:

| Coluna | Tipo | Papel |
|---|---|---|
| `id` | `uuid` (UUIDv7) PK | ADR-018 |
| `turno_id` | `foreignUuid` → `turnos` | correlação com o turno |
| `tipo_operacao` | `text` (enum) | `pre_autorizacao`, `captura`, `captura_parcial`, `liberacao`, `pix` |
| `idempotencia_chave` | `text` único | `"{tipo}:{turno_id}"`, determinística (ADR-005 d) |
| `status` | `text` (enum) | `pendente`, `concluida`, `falhou` |
| `request_payload` | `jsonb` | enviado ao provedor (sem PII em claro) |
| `response_payload` | `jsonb` nullable | recebido do provedor |
| `pagarme_order_id` / `pagarme_charge_id` / `pagarme_transfer_id` | `text` nullable | correlação desnormalizada |
| `erro` | `text` nullable | mensagem da falha |
| timestamps | | `created_at`/`updated_at` |

Índice **único composto** `(turno_id, tipo_operacao)` — é a barreira de hardware contra duplicação. O runner `OperacaoIdempotente` (núcleo, 98%): se já existe linha `concluida` para a chave → devolve o `ResultadoOperacao` reconstruído **sem** chamar o Pagar.me; caso contrário grava `pendente`, chama o gateway enviando a `idempotencia_chave` também como header `Idempotency-Key` (defesa dupla — o provedor deduplica do lado dele), e grava `concluida`+resposta ou `falhou`+erro. Corrida de inserção é resolvida pelo índice único: violação → recarrega a linha existente. Teste de **clique-duplo** garante exatamente uma chamada ao provedor.

A tabela **não** é imutável por trigger (diferente do `aceites_eletronicos_turno`): uma operação `pendente`→`concluida` precisa de `UPDATE`. A imutabilidade do *registro financeiro* é responsabilidade da trilha de auditoria do turno (ADR-015), não desta tabela operacional.

### (c) Adapter `PagarmeGateway` + seleção de driver (CA-3, CA-4, Decisão 2A)

`app/Domain/Pagamento/Pagarme/PagarmeGateway.php` implementa `GatewayPagamento` usando o client `Http` do Laravel (ADR-001). Lê `base_url`, `secret_key` e `timeout` de `config('services.pagarme')`, que resolve a partir de `PAGARME_DRIVER`. Segredos **só** via env/Secret Manager (ADR-004) — nunca em código. O `external_reference` enviado em toda operação carrega o **UUID do turno como string** (ADR-018, CA-5). O mapeamento HTTP→exceção (Decisão 3A) é a função `mapearErro()`, testável isoladamente. Binding `GatewayPagamento → PagarmeGateway` num `PagamentoServiceProvider`.

### (d) Mock em container que devolve o webhook (CA-4, CA-7)

O serviço `pagarme-mock` (já no `docker-compose.yml` desde STORY-006) ganha **rotas funcionais** espelhando o contrato HTTP do Pagar.me: criação de order com pré-autorização, captura, transfer (Pix), e estorno/void (liberação). Ao completar cada operação, o mock **emite o webhook de volta** para `http://api:8000/api/webhooks/pagarme`, assinado com o mesmo segredo HMAC (`PAGARME_WEBHOOK_SECRET`), com `event_id` único e payload no formato do provedor. Loga `[MOCK]` (ADR-005) e versiona qual versão do contrato simula. Isso fecha o ciclo pré-auth → captura → Pix → webhook **sem internet** (CA-7).

### (e) Webhook entrante validado (CA-6, Decisão da F5)

Rota pública `POST /api/webhooks/pagarme` (fora de `auth`/`FunnelGuard`/`WebAppOnly`), no `api`. O `PagarmeWebhookController`: (1) valida a **assinatura HMAC** (`hash_hmac('sha256', body, secret)` comparada com `hash_equals` — `PagarmeWebhookValidator`, núcleo 98%); assinatura inválida → **401**, sem processar; (2) deduplica por **`event_id`** numa tabela `webhook_eventos_pagarme` (event_id único) — duplicata responde **200** sem reprocessar; (3) persiste o evento e **enfileira** `ProcessarWebhookPagarmeJob`, respondendo **200** rápido. O job (no `worker`) faz o parsing do tipo de evento do Pagar.me → **evento de domínio canônico** e atualiza a `pagamento_operacoes` correspondente.

### (f) Eventos de domínio emitidos (CA-6)

O parsing mapeia o evento do provedor para um destes eventos de domínio (em `App\Events\Pagamento`), consumidos por STORY-065 (captura+Pix) e STORY-067 (notificações):

| Evento Pagar.me (exemplo) | Evento de domínio | Consumidor |
|---|---|---|
| `charge.pending` / order autorizada | `PreAutorizacaoCriada` | STORY-067 |
| `charge.captured` / `charge.paid` | `CapturaConfirmada` | STORY-065/067 |
| `transfer.paid` (Pix) | `PixEnviado` | STORY-065/067 |
| `transfer.failed` | `PixFalhou` | STORY-065/067 + **alerta admin (PDR-010)** |
| `charge.refunded` / `charge.canceled` | `PreAutorizacaoLiberada` | STORY-066/067 |

`PixFalhou` é o gancho do PDR-010: **uma tentativa, alerta no admin, sem retry automático** — a *policy* de alerta é wirada na STORY-065; aqui o evento já nasce.

### (g) Observabilidade financeira (CA-9)

`App\Support\Telemetry\PagamentoEvents` emite uma linha JSON por operação (espelhando `MatchEvents`/ADR-008), com `event`, `operacao`, `turno_id`, `idempotencia_chave`, `pagarme_id`, `latencia_ms`, `resultado`. **Mascarado/omitido:** chave Pix, dados bancários (a chave Pix nunca entra no log — `Pii`/ADR-008). O `request_id` propaga `api`→fila→`worker` (mecanismo do ADR-008). As log-based metrics (taxa de erro ≤ 1%, latência p95 de captura e de webhook) são **definidas** em `docs/operacao/` para o Terraform da STORY-007 wirar; a métrica vive no mecanismo do ADR-008.

### (h) Contract test no CI noturno → STORY-056-B (CA-8)

O contract test consumer-driven contra o sandbox real, o job de `cron` noturno no GitHub Actions e o alerta de divergência (canal do ADR-008) são o escopo da **STORY-056-B** (quebra documentada em SPRINT-2026-W28). Esta ADR fixa o **desenho**: o contrato esperado é versionado junto da ACL (`docs/project-state/integrations/pagarme/contract.md` — request/response/erros por operação, "simula API vX capturada em <data>"); o job roda fora do caminho de PR (não depende de internet no push, princípio #6); divergência mock↔sandbox notifica Alexandro pelo canal do ADR-008. Credenciais sandbox no Secret Manager são pré-requisito da STORY-056-B (Alexandro provê).

## Diagrama

```mermaid
flowchart TB
  subgraph dom["app/Domain/Pagamento (ACL)"]
    GP["GatewayPagamento (interface)\npreAutorizar/capturar/capturarParcial/liberar/transferirPix"]
    OI["OperacaoIdempotente (núcleo)\nchave = tipo:turno_id"]
    ADP["PagarmeGateway (adapter HTTP)\nbase_url+secret por PAGARME_DRIVER\nmapearErro(): HTTP -> exceção de domínio"]
    GP --> OI --> ADP
  end
  PO[("pagamento_operacoes\nUNIQUE(turno_id,tipo_operacao)\nstatus+payloads+correlação")]
  OI --> PO
  PG["pagarme-mock | sandbox | live\n(mesmo contrato HTTP)"]
  ADP -->|Http + Idempotency-Key + external_reference=turno_uuid| PG
  PG -.->|webhook HMAC + event_id| WH["POST /api/webhooks/pagarme\nvalida HMAC (401 se inválido)\ndedup por event_id (200 se dup)\nenfileira"]
  WH --> JOB["ProcessarWebhookPagarmeJob (worker)\nparse evento provedor -> evento de domínio"]
  JOB --> EV["PreAutorizacaoCriada · CapturaConfirmada\nPixEnviado · PixFalhou(alerta admin) · PreAutorizacaoLiberada"]
  EV --> S065["STORY-065 captura+Pix"]
  EV --> S067["STORY-067 notificações"]
```

## Consequências

### Positivas (o que ganhamos)
- STORY-058/065/066 ganham uma interface estável e um ciclo financeiro que roda **local sem internet** (mock em container devolvendo o webhook).
- Não-duplicação garantida pelo índice único `(turno_id, tipo_operacao)` **mais** o `Idempotency-Key` no provedor — defesa em duas camadas.
- Núcleo financeiro (idempotência, parsing/validação de webhook, mapeamento de erro) testável sem container e sem rede → cobertura ≥ 98% realista.
- Um só caminho de código fala com mock e sandbox → o contract test da STORY-056-B guarda exatamente o código de produção.
- Captura parcial já exposta na interface (EPIC-005) sem custo de antecipação real.

### Negativas / trade-offs aceitos
- **Manutenção do mock** quando o contrato Pagar.me mudar (herdado da ADR-005; mitigado pelo contract test da STORY-056-B).
- **Card/meio de pagamento real** da pré-autorização fica para STORY-058 — nesta estória o `meioPagamentoToken` existe na assinatura e é honrado pelo mock, mas o fluxo de tokenização do contratante não é exercido contra o sandbox aqui.
- Colunas de correlação desnormalizadas em `pagamento_operacoes` pressupõem ≤ 1 operação por `(turno, tipo)`; o EPIC-005 pode forçar uma sequência na chave (ver Plano de verificação).

### Neutras
- A `pagamento_operacoes` é mutável (`pendente`→`concluida`), diferente do `aceites_eletronicos_turno` imutável — a imutabilidade financeira mora na trilha de auditoria do turno (ADR-015), não aqui.
- O `worker` que processa o webhook é o mesmo da ADR-002/004 (GCE `e2-micro`) — sem impacto novo de infra.

### Para o time
- **Impacto em estórias:** destrava STORY-058 (`preAutorizar`), STORY-065 (`capturar`+`transferirPix`+webhook), STORY-066 (`liberar`). Define o contrato dos eventos de domínio que STORY-067 consome.
- **ADRs/PDRs:** detalha ADR-005; consome ADR-002/004/008/015/018; implementa PDR-004; respeita PDR-010 (`PixFalhou` sem retry) e PDR-006 (`capturarParcial` exposta).
- **Spike de validação:** não. O contract test da STORY-056-B passa a guardar a fidelidade continuamente.

## Plano de verificação

- **Como verificar conformidade:**
  - **Lint arquitetural:** nenhum import do client/SDK Pagar.me fora de `app/Domain/Pagamento/Pagarme`; nenhuma coluna `order_id`/`charge_id` no modelo `Turno` (vivem em `pagamento_operacoes`).
  - **Idempotência:** teste reexecuta a mesma operação com a mesma chave e confirma **uma** chamada ao provedor (mock/`Http::fake`); webhook duplicado por `event_id` não reprocessa.
  - **Local sem internet:** `docker compose up` com `PAGARME_DRIVER=mock` roda pré-auth→captura→Pix→webhook sem rede externa (CA-7 / STORY-006).
  - **Observabilidade:** eventos `pagamento.*`/`pix.*` no log JSON com `request_id` correlacionado e **sem** chave Pix em claro (teste do `PagamentoEvents`/`Pii`).
- **Sinais de revisão (quando reabrir):**
  - Se o EPIC-005 exigir **N operações do mesmo tipo** por turno (estornos parciais sucessivos) → a chave `(turno_id, tipo_operacao)` ganha uma sequência; reabre a Decisão 1.
  - Se o contract test (STORY-056-B) acusar **divergência recorrente** mock↔sandbox → revisar cadência de manutenção do mock (sinal da ADR-005).
  - Se **erro de transação > 1%** ou **falha de Pix > 1%** → reabre política de retry/circuit breaker (na ADR-005/PDR-010, não aqui).
- **Spike de validação proposto:** nenhum dedicado; STORY-056-B (contract test) é a guarda contínua.

---

## Aprovação humana

> Esta seção é o registro formal do aceite. Não preencher sozinho — preencher quando o humano aprovar no chat ou via PR.

- **Status final:** ⬜ pendente | ✅ aceita | ❌ rejeitada | 🔄 superseded
- **Aprovado por:** <Alexandro>
- **Data:** YYYY-MM-DD
- **Forma do aceite:** <ex: "aprovado em chat (sessão de YYYY-MM-DD)" | "PR #N mergeado">
- **Condicionantes do aceite:** <se houver>

### Em caso de rejeição
- **Motivo:** ...
- **Próximos passos sugeridos:** ...

### Em caso de superseding
- **Substituída por:** ADR-YYY
- **Razão da substituição:** ...

---

## Histórico

- 2026-06-04 — criada como `proposed` por Arquiteto (STORY-056-A). Detalha a ADR-005: interface `GatewayPagamento` (valores como string decimal, ids opacos no `ResultadoOperacao`), tabela única `pagamento_operacoes` com correlação desnormalizada e índice único `(turno_id, tipo_operacao)` (Decisão 1A), adapter único com driver por config (Decisão 2A), erro por exceção de domínio tipada (Decisão 3A), mock em container devolvendo webhook, webhook entrante HMAC + dedup por `event_id` + processamento assíncrono, 5 eventos de domínio canônicos, observabilidade com chave Pix mascarada. Contract test no CI noturno delegado à STORY-056-B (quebra da estória L).
