# Contrato Pagar.me (consumer-driven) — versionado junto da ACL

> **Decisão de referência:** ADR-005 (estratégia), **ADR-016** (implementação). Este documento
> é o **contrato que o Turni espera** do Pagar.me. O mock em container (`infra/docker/pagarme-mock`)
> simula exatamente este contrato; o **contract test noturno da STORY-056-B** o verifica contra o
> sandbox real e alerta divergência (canal do ADR-008). Quando o sandbox divergir, atualizar
> **este arquivo + o mock** é parte da estória que toca o contrato (não dívida futura).

- **Versão simulada:** `pagarme-core-v5@2026-06-04` (estilo Pagar.me Core v5, capturada em 2026-06-04).
- **Autenticação:** Bearer `secret_key` (Secret Manager em homolog/prod — ADR-004).
- **Idempotência:** header `Idempotency-Key: {tipo}:{turno_id}` em toda operação (ADR-016 b).
- **Correlação:** `external_reference` carrega o **UUID do turno como string** (ADR-018, CA-5).
- **Valores:** inteiros em **centavos** (a ACL converte de string decimal na fronteira).

## Operações (request → response)

### 1. Pré-autorização — `POST /orders`
```
req:  { "amount": 11500, "external_reference": "<turno_uuid>", "payment_token": "<tok>", "capture": false }
resp: { "id": "or_…", "status": "pending", "external_reference": "<turno_uuid>",
        "charges": [ { "id": "ch_…", "status": "authorized", "amount": 11500 } ] }
```

### 2. Captura (total ou parcial) — `POST /charges/{charge_id}/capture`
```
req:  {}                          # total
req:  { "amount": 9000 }          # parcial (EPIC-005 / PDR-006)
resp: { "id": "ch_…", "status": "paid", "amount": 11500 }
```

### 3. Liberação / estorno — `POST /charges/{charge_id}/cancel`
```
req:  {}
resp: { "id": "ch_…", "status": "canceled" }
```

### 4. Pix ao profissional — `POST /transfers`
```
req:  { "amount": 10000, "pix_key": "<chave — SENSÍVEL, nunca logada>", "external_reference": "<turno_uuid>" }
resp: { "id": "tr_…", "status": "paid", "external_reference": "<turno_uuid>" }
```

## Webhook entrante — `POST /api/webhooks/pagarme`
- **Assinatura:** header `X-Pagarme-Signature` = `HMAC-SHA256(corpo_bruto, PAGARME_WEBHOOK_SECRET)`; inválida → **401**.
- **Dedup:** por `id` (event_id) — repetição → **200** sem reprocessar.
- **Formato:**
```
{ "id": "evt_…", "type": "<tipo>", "created_at": "…", "data": { "external_reference": "<turno_uuid>", … } }
```

### Mapa `type` (Pagar.me) → evento de domínio (ADR-016 f / CA-6)
| `type` | Evento de domínio | Consumidor |
|---|---|---|
| `charge.pending`, `charge.authorized` | `PreAutorizacaoCriada` | STORY-067 |
| `charge.paid`, `charge.captured` | `CapturaConfirmada` | STORY-065/067 |
| `transfer.paid`, `transfer.created` | `PixEnviado` | STORY-065/067 |
| `transfer.failed` | `PixFalhou` | STORY-065/067 + alerta admin (PDR-010) |
| `charge.canceled`, `charge.refunded` | `PreAutorizacaoLiberada` | STORY-066/067 |
| *(qualquer outro)* | — (aceito com 200, sem evento) | — |

## Mapa de erro (HTTP → exceção de domínio — ADR-016 Decisão 3A)
| HTTP | Classe (recuperável?) |
|---|---|
| `5xx`, timeout, rede | `GatewayIndisponivel` (sim — worker retenta) |
| `4xx` em pré-autorização | `PreAutorizacaoNegada` (não) |
| `4xx` em captura/captura parcial | `CapturaFalhou` (não) |
| `4xx` em liberação | `LiberacaoFalhou` (não) |
| `4xx` em Pix | `PixFalhou` (não — PDR-010: uma tentativa) |

## Variabilidade aceita
- Campos extras do provedor são **ignorados** (não falhamos por campo novo).
- `type` de webhook desconhecido é aceito com **200** sem emitir evento.
