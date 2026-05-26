# Domínio · Disputa

Decisão de referência: **PDR-006** (disputa via admin).

## Quando nasce

Uma disputa nasce **apenas** no momento do check-out, quando o contratante recusa validar o PIN gerado pelo profissional. Não há disputa antes de chegar a `aguardando_checkout` — divergências anteriores são tratadas por cancelamento ou ocorrência sem efeito financeiro.

## Estado do turno

`em_disputa` (ver máquina em `domain/turno.md`).

## Atributos da disputa

Anexado ao turno:

- `aberta_em` — timestamp da recusa do check-out.
- `aberta_por` — sempre o contratante no MVP.
- `justificativa_contratante` — texto livre, **obrigatório**. Sem justificativa o contratante não consegue abrir disputa; o caminho alternativo é validar o check-out.
- `evidencias_contratante` — anexos opcionais (foto, captura de mensagem) — futuro.
- `resolucao` — preenchido pelo admin: `paga_integral` | `paga_parcial` | `sem_pagamento`.
- `valor_revisado` — preenchido apenas em `paga_parcial`.
- `nota_admin` — texto livre do admin com justificativa da decisão.
- `resolvida_em` — timestamp da resolução.
- `resolvida_por` — admin que resolveu.

## SLA público

**30 minutos** entre abertura e resolução. Promessa pública da plataforma.

Internamente, esse SLA depende de capacidade da equipe Turni; se atingido em > 90% dos casos no primeiro mês, sustentamos; senão, reabrimos com prioridade.

## Fluxo

```
[ contratante recusa validar check-out ]
        │
        ▼
[ digita justificativa obrigatória ]
        │
        ▼
[ turno transita para em_disputa ]
        │
        ├──► profissional é notificado
        ├──► admin recebe item na fila de disputas
        └──► pré-autorização Pagar.me permanece bloqueada
        │
        ▼
[ admin abre o caso no backoffice ]
        │
[ admin vê: chat completo, geofencing, checklist, cronômetro, justificativa, vaga original, histórico de ambos ]
        │
        ├──► (eventual) contato direto com cada lado fora do app
        │
        ▼
[ admin decide ]
        │
   ┌────┴───────────────┬──────────────────┐
   ▼                    ▼                  ▼
[paga_integral]   [paga_parcial]    [sem_pagamento]
   │                    │                  │
   │                    │                  │
   ▼                    ▼                  ▼
[captura padrão]   [captura ajustada;  [pré-aut. liberada;
                    diferença liberada] profissional não recebe]
   │                    │                  │
   ▼                    ▼                  ▼
[ finalizado ]   [ finalizado_     [ disputa_resolvida_
                  ajustado ]         sem_pagamento ]
   │                    │                  │
   └────────────────────┴──────────────────┘
                        │
                        ▼
            [ ambos avaliam (PDR-005) ]
                        │
                        ▼
            [ trilha de auditoria registra tudo ]
```

## Impacto no score / nível

- `paga_integral`: nenhum efeito específico além das avaliações normais.
- `paga_parcial`: avaliações normais; o registro permanece como trilha — não impacta score automaticamente no MVP, mas o admin pode penalizar manualmente em casos graves.
- `sem_pagamento`: avaliações normais ainda obrigatórias; registro fica como sinal forte de risco para o admin.

Em todos os casos, o admin pode aplicar penalidade manual ao profissional ou ao contratante via backoffice (ex: reduzir score em N pontos, suspender temporariamente). Isso é evolução; no MVP, basta o registro.

## Casos de abuso

Padrões que merecem atenção do admin (futuro):

- Contratante abre disputas com frequência alta (sinal de potencial abuso para reduzir pagamento).
- Profissional aparece em múltiplas disputas como "sem_pagamento" (sinal de problemas reais de execução).

Esses padrões são detectados manualmente no MVP. Automatização (alertas, suspensões) é evolução pós-MVP.

## Lacunas conhecidas

- Recurso do profissional contra resolução do admin — fora do MVP (depende de mais maturidade operacional).
- Tempo máximo entre check-out e abertura de disputa — hoje exige imediato (no ato da recusa); janela maior fica para futuro.
- Anexos / evidências do contratante na justificativa — fora do MVP, texto livre é suficiente.
- Anexos / evidências do profissional ao ser notificado — fora do MVP.
- Comunicação automatizada entre as partes durante a disputa — fora do MVP; admin pode mediar contatando cada lado.
