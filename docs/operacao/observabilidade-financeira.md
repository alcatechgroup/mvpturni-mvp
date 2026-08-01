# Observabilidade financeira — log-based metrics (ADR-008 / ADR-016 g)

> Definição operacional prometida pela ADR-016 §Observabilidade e wirada no Terraform
> (`infra/modules/monitoring/main.tf` — bloco "Operações financeiras"). Criada na
> resposta ao F-NB-1 da validação do EPIC-003 (STORY-068, 2026-06-07).

## Fonte dos dados

`App\Support\Telemetry\PagamentoEvents` emite uma linha JSON por operação da ACL de
pagamento, executada no worker e no scheduler. Desde a ADR-021 (stack numa VPS), essas
linhas chegam ao Cloud Logging pelos log names `turni-<env>-worker` e
`turni-<env>-scheduler` — o Ops Agent lê o arquivo JSON de cada serviço. Os filtros das
métricas usam `log_id(...)` no lugar do antigo `resource.type="cloud_run_job"`:

| Evento (`jsonPayload.message`) | Quando | Campos usados |
|---|---|---|
| `pagamento.operacao_concluida` | operação concluiu no provedor (1ª vez) | `context.operacao`, `context.latencia_ms` |
| `pagamento.operacao_reaproveitada` | curto-circuito idempotente (não chamou o provedor) | — (não conta no SLO; latência 0) |
| `pagamento.operacao_falhou` | falha fatal de negócio ou `GatewayIndisponivel` | `context.operacao`, `context.recuperavel` |
| `pagamento.webhook_processado` | confirmação assíncrona do gateway processada (fonte de verdade — ADR-016 e) | `context.evento_dominio`, `context.latencia_ms` |

A chave Pix e dados bancários **nunca** entram no log (ADR-008/ADR-016 g — verificado
por teste). Correlação por `turno_id` (e `request_id` — ADR-008 §f).

## Métricas (Cloud Monitoring, `logging.googleapis.com/user/…`)

| Métrica | Tipo | O quê |
|---|---|---|
| `turni_<env>_pagamento_erros` | counter (labels `operacao`, `recuperavel`) | numerador do SLO de erro |
| `turni_<env>_pagamento_operacoes` | counter (label `operacao`) | denominador do SLO |
| `turni_<env>_pagamento_latencia_ms` | distribution (label `operacao`) | **p95 de captura** = percentil 95 com `operacao=captura`; pix/liberação/pré-auth pela mesma métrica |
| `turni_<env>_pagamento_webhook_latencia_ms` | distribution (label `evento_dominio`) | **p95 do webhook** |

## SLOs (ADR-016)

- **Taxa de erro ≤ 1%**: `pagamento_erros / (pagamento_erros + pagamento_operacoes)`
  por janela de 1 dia. No volume atual, o alerta dispara em **qualquer** falha
  (alert policy "Turni falha de operação financeira (<env>)") — PDR-010 não tem retry
  de Pix, então 1 falha já é caso operacional (fila "Falhas de pagamento" do admin).
- **Latência p95 de captura** e **p95 de webhook**: acompanhar pelas distributions
  acima (Metrics Explorer → percentil 95). Sem alerta dedicado por ora — o SLA
  fim-a-fim do Pix é coberto pela simulação do fake (PDR-017) e pelo alerta de SLA
  de e-mail de notificação.

## Verificação rápida

```bash
gcloud logging metrics list --project=foodhub-87e0c | grep pagamento
# turni_homolog_pagamento_erros / _operacoes / _latencia_ms / _webhook_latencia_ms
```
