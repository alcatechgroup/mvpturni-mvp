# Domínio · Turno

Decisão de referência: **PDR-004** (modelo financeiro), **PDR-005** (avaliação obrigatória), **PDR-006** (disputa), **PDR-007** (cancelamento), **PDR-008** (geofencing).

## O que é

Turno é a unidade central do produto. Nasce quando uma candidatura é aprovada e percorre um ciclo até `finalizado` (pago e avaliado) ou um dos estados terminais alternativos (cancelado, disputa resolvida sem pagamento).

## Atributos

- `id` — identificador único.
- `vaga` — referência à vaga origem.
- `profissional` — quem executa.
- `contratante` — quem contrata (derivado da vaga, redundante para consulta rápida).
- `estabelecimento` — local físico (derivado).
- `status` — estado atual (ver máquina abaixo).
- `valor` — valor a pagar ao profissional (cópia do valor da vaga, congelado no aceite).
- `taxa_turni` — taxa do contratante calculada sobre valor (PDR-004).
- `total_contratante` — valor + taxa_turni.
- `check_in` — timestamp do check-in validado.
- `check_out` — timestamp do check-out validado.
- `geofencing_check_in` — `{ ok: bool, distancia_metros: number, capturado_em: timestamp }` (PDR-008).
- `geofencing_check_out` — idem (opcional).
- `avaliacao_profissional` — `{ stars: 1-5, comment?: string, criado_em: timestamp }` (avaliação que o contratante deu ao profissional).
- `avaliacao_contratante` — idem (avaliação que o profissional deu ao contratante).
- `chat` — array de mensagens entre as partes.
- `cancelamento` — `{ lado: pro|emp, motivo?: string, antecedencia_horas: number, em: timestamp }` se cancelado.
- `disputa` — `{ aberta_em, justificativa_contratante, resolucao?, valor_revisado? }` se em disputa.

## Máquina de estados

```
                  (candidatura aprovada)
                            │
                            ▼
                     ┌─────────────┐
                     │ confirmado  │
                     └─────┬───────┘
                           │
       ┌───────────────────┼─────────────────────┐
       │                   │                     │
       ▼                   ▼                     ▼
  [cancelado_pro]   [cancelado_emp]    [profissional gera PIN check-in]
                                                  │
                                                  ▼
                                      ┌─────────────────────┐
                                      │ aguardando_checkin  │
                                      └─────────┬───────────┘
                                                │
                              ┌─────────────────┼─────────────────┐
                              │                 │                 │
                              ▼                 ▼                 ▼
                  [contratante valida]  [contratante recusa]  [vencimento de horário]
                              │            (volta confirmado;       │
                              │             pro gera novo PIN)      ▼
                              ▼                                [no_show_pro]
                       ┌────────────┐
                       │   ativo    │ ← cronômetro bilateral rodando
                       └─────┬──────┘
                             │ profissional gera PIN check-out
                             ▼
                  ┌──────────────────────┐
                  │ aguardando_checkout  │
                  └─────────┬────────────┘
                            │
            ┌───────────────┼────────────────┐
            │               │                │
            ▼               ▼                ▼
  [contratante valida]  [contratante      [profissional cancela
            │            contesta]         solicitação check-out]
            ▼               │                │
   ┌────────────────┐       ▼                ▼
   │  finalizado    │  ┌─────────────┐  (volta a ativo)
   │ (pago,         │  │ em_disputa  │
   │ aguarda        │  └──────┬──────┘
   │ avaliação)     │         │ admin resolve em 30 min
   └────────┬───────┘         │
            │            ┌────┴───────────────────────┐
            │            │                            │
            ▼            ▼                            ▼
  [ambos avaliam]   [disputa: paga integral]    [disputa: paga parcial]
                            │                            │
                            ▼                            ▼
                      [finalizado]               [finalizado_ajustado]
                                                         │
                                                         ▼ ou
                                              [disputa_resolvida_sem_pagamento]
```

## Estados — descrição

| Estado | Significa |
|---|---|
| `confirmado` | Candidatura aprovada; pré-autorização Pagar.me ativa; aguardando início do turno. |
| `aguardando_checkin` | Profissional gerou PIN de check-in; contratante precisa validar. |
| `ativo` | Check-in validado; cronômetro bilateral rodando; checklist em execução. |
| `aguardando_checkout` | Profissional gerou PIN de check-out; contratante precisa validar. |
| `em_disputa` | Contratante contestou check-out; admin mediará (PDR-006). |
| `finalizado` | Pago integralmente; aguardando avaliação recíproca (PDR-005). |
| `finalizado_ajustado` | Pago após disputa com ajuste de valor; aguardando avaliação. |
| `disputa_resolvida_sem_pagamento` | Disputa resolvida sem pagamento; trilha registrada; impacta score de ambos. |
| `cancelado_pro` | Profissional cancelou (antes de `ativo`). |
| `cancelado_emp` | Contratante cancelou (antes de `ativo`). |
| `no_show_pro` | Profissional não fez check-in até X horas após início previsto (X a definir em spike). |

Após avaliação recíproca completa em `finalizado` ou `finalizado_ajustado`, o turno não muda mais de estado — fica apenas histórico.

## Regras críticas

### Pré-autorização e captura (PDR-004)

- No momento da aprovação da candidatura (`confirmado`), Pagar.me **pré-autoriza** o `total_contratante` (valor + taxa_turni) no meio de pagamento do contratante.
- Em `finalizado` (após check-out validado), Pagar.me **captura** o valor pré-autorizado.
- Profissional recebe Pix do `valor` em até 15 minutos após captura (promessa pública).
- Em cancelamento antes de `ativo`, a pré-autorização é **liberada** (não capturada).
- Em `finalizado_ajustado`, captura ajusta para o valor revisado pelo admin.
- Em `disputa_resolvida_sem_pagamento`, pré-autorização é liberada totalmente.

### Geofencing (PDR-008)

- O PIN de check-in carrega flag `geofencing_ok` e distância medida.
- `geofencing_ok: false` **não bloqueia** o check-in.
- O contratante vê o aviso destacado antes de validar o PIN.
- O evento é registrado na trilha de auditoria.

### Cronômetro bilateral

- Inicia na transição `aguardando_checkin → ativo`.
- Encerra na transição `aguardando_checkout → finalizado` (ou variação após disputa).
- Visível em tempo real para ambos os lados enquanto `ativo`.

### Cancelamento (PDR-007)

- Permitido **apenas** nos estados `confirmado` (antes do check-in).
- Não permitido em `ativo`, `aguardando_checkin`, `aguardando_checkout`, `em_disputa`, `finalizado*`.
- Registro inclui lado, motivo opcional, antecedência em horas — base para motor de penalidade futuro.

### Disputa (PDR-006)

- Aberta pelo contratante ao recusar validação de check-out.
- Justificativa textual é obrigatória.
- Vai para a fila do backoffice; SLA público 30 min.
- Resolução pelo admin: integral, parcial (com valor revisado), sem pagamento.
- Profissional é notificado da abertura e da resolução.

### Avaliação (PDR-005)

- Em `finalizado` e `finalizado_ajustado`, ambos os lados avaliam.
- Profissional não pode candidatar-se a nova vaga até avaliar.
- Contratante não pode publicar nova vaga até avaliar.
- Estrelas (1-5) obrigatórias; comentário opcional.

## Lacunas conhecidas

- Definição numérica de `no_show_pro` (quantas horas após início previsto sem check-in viram no-show?) — spike pendente.
- Tratamento de turno que ultrapassa `data_fim` previsto significativamente — hoje cronômetro continua, mas não há regra de horas extras.
- Política de retorno de pré-autorização Pagar.me em janelas longas — depende de spike técnico Pagar.me.
