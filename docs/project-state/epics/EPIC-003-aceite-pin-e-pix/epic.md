---
epic_id: EPIC-003
slug: aceite-pin-e-pix
title: Aceite da candidatura, PIN bilateral e Pix via Pagar.me
wave: WAVE-2026-01
status: ready
owner_role: po
created_at: 2026-05-26
updated_at: 2026-06-03
target_completion: 2026-08-18  # estimativa orientativa
sprint_id: SPRINT-2026-W28  # primeira (e potencialmente única) sprint do épico
---

# EPIC-003 — Aceite, PIN bilateral e Pix

## Por que existimos (problema do usuário)

Este é o coração da promessa do Turni. Sem PIN bilateral, sem Pix em 15 min, sem captura Pagar.me — o produto vira "publicar vaga em app". Este épico **demonstra os dois pilares principais** restantes da promessa central (PIN Bilateral + Pix em 15 min) e fecha o ciclo do turno em sandbox.

É o mais arriscado da onda: depende de Pagar.me sandbox, da regra de habitualidade (PDR-002) já estar implementada, e do geofencing (PDR-008) funcionar minimamente.

## Resultado esperado (outcome)

Ao fim deste épico, contratante aceita candidatura (Pagar.me pré-autoriza valor + taxa Turni; turno entra em `confirmado`); profissional faz check-in com PIN bilateral de 4 dígitos + flag de geofencing; cronômetro bilateral roda; profissional faz check-out com PIN; contratante valida; Pagar.me captura; Pix sandbox cai na chave do profissional em ≤ 15 min.

Os dois lados conseguem ver o estado do turno em tempo real (cronômetro vivo, eventos de match, notificações).

## Métrica de sucesso (como saberemos que funcionou)

- **Primária**: turno executado ponta a ponta em sandbox em ≥ 95% das tentativas no caminho feliz. Pix sandbox cai em ≤ 15 min em 95% dos turnos.
- **Validação de PIN**: ≤ 500ms p95 (operação crítica em pé, contexto de rua).
- **Habitualidade**: regra de 2x/semana (PDR-002) testada nos 4 cenários (PF 0-1-2 alocações libera; PF 3ª bloqueia; PJ 3ª alerta + override; transição de semana reseta).
- **Cronômetro bilateral**: latência de sincronização entre os dois lados ≤ 2s.

## Entregável visível no fim do épico

- [ ] Contratante aceita candidatura; Pagar.me sandbox registra pré-autorização (visível em log/painel sandbox).
- [ ] Turno aparece em `confirmado` para ambos os lados.
- [ ] Profissional, no horário de início, abre o turno e gera PIN de check-in (4 dígitos visíveis em tela).
- [ ] Contratante recebe alerta "profissional chegou — valide o PIN", digita o PIN, confirma; turno transita para `ativo`; cronômetro bilateral inicia.
- [ ] Ambos os lados veem o cronômetro vivo na mesma tela do turno.
- [ ] Geofencing: distância e flag `geofencing_ok` registradas no evento de check-in; se fora do raio de 100m, contratante vê aviso destacado (PDR-008).
- [ ] Profissional, ao fim do turno, gera PIN de check-out; contratante valida; turno transita para `finalizado`.
- [ ] Pagar.me sandbox captura valor + taxa Turni; Pix sandbox cai na chave do profissional em ≤ 15 min.
- [ ] Habitualidade aplicada no momento do aceite (PDR-002): PF bloqueado na 3ª; PJ alerta + override registrado no aceite eletrônico.

## Fora de escopo (explicitamente)

- Avaliação recíproca → vira EPIC-004.
- Disputa de check-out → vira EPIC-005.
- Pagar.me em **produção** — sandbox apenas no MVP (produção é EPIC-006 da próxima onda).
- Push notifications (mobile) — apenas in-app + e-mail no MVP.
- Tratamento sofisticado de falha de Pix > 15 min (PDR-010 — apenas alerta no admin, sem retry automático).
- Captura parcial / estorno parcial (vira EPIC-005 e EPIC-007).
- Cronograma de turno antecipado (plano Turnificado).
- Cancelamento com motor de penalidade (PDR-007 — apenas placeholder no modelo de dados).

## Referências da especificação

- `docs/especificacao/domain/turno.md` — máquina de estados completa.
- `docs/especificacao/domain/pagamento.md` — modelo financeiro, pré-autorização, captura, Pix.
- `docs/especificacao/domain/compliance.md` — habitualidade, aceite eletrônico, geofencing.
- `docs/especificacao/flows/aceite-da-candidatura.md` — fluxo (a escrever).
- `docs/especificacao/flows/check-in.md` — fluxo (a escrever).
- `docs/especificacao/flows/execucao-de-turno.md` — fluxo (a escrever).
- `docs/especificacao/flows/check-out-e-pagamento.md` — fluxo (a escrever).
- `docs/especificacao/non-functional.md` — SLAs (Pix 15 min, geofencing 100m, PIN < 500ms).
- `docs/project-state/decisions/pdr/PDR-002-habitualidade-no-mesmo-estabelecimento.md` — gate de aceite.
- `docs/project-state/decisions/pdr/PDR-004-modelo-financeiro-taxa-do-contratante.md` — base do modelo de pagamento.
- `docs/project-state/decisions/pdr/PDR-008-geofencing-alerta-e-registra.md` — comportamento do geofencing.
- `docs/project-state/decisions/pdr/PDR-010-refresh-pix-fora-de-escopo-mvp.md` — falha de Pix tratada manualmente.

## Dependências

- **Bloqueia**: EPIC-004 (avaliação só após turno finalizado), EPIC-005 (disputa precisa de aceite + check-out funcionando).
- **Bloqueado por**: EPIC-002 (sem candidatura, não há aceite).
- **Decisões arquiteturais necessárias**:
  - ADR-005 (integração Pagar.me alto nível) detalhado em ADR de implementação específica.
  - Estratégia de tempo real para cronômetro bilateral (WebSocket vs SSE vs polling).
  - Estratégia de geolocalização no check-in (browser API + cálculo Haversine vs PostGIS).
  - Estratégia de ACL para Pagar.me com idempotência (clique duplo no aceite não cobra dobrado).
  - Notificação ao profissional após captura (e-mail + in-app no MVP).

## Estórias

Decompostas via Fluxo B em **2026-06-03** (PO Alexandro/Claude), em paralelo ao fechamento da SPRINT-2026-W27. Total **14 estórias** (3 spikes + 10 implementação + 1 validação) — escopo do EPIC-003 inteiro alocado à **SPRINT-2026-W28**. Mix de sizing: 1 S + 11 M + 2 L. As duas L (STORY-056 Pagar.me e STORY-063 cronômetro bilateral) carregam gatilho de quebra documentado na própria estória.

Ordem de execução obrigatória (dependências):

```
STORY-055 (spike modelo Turno + máquina de estados + AceiteEletronico imutável)
STORY-056 (spike Pagar.me sandbox: ACL + mock em container + idempotência + webhook)
STORY-057 (spike tempo real cronômetro + geolocalização Haversine)
    │
    ├─► STORY-058 (aceitar candidatura no Backoffice + pré-autorização Pagar.me)
    │       │
    │       ├─► STORY-059 (lista "Meus turnos"/"Vagas confirmadas")
    │       └─► STORY-060 (detalhe do turno + trilha de auditoria)
    │               │
    │               ├─► STORY-061 (PIN check-in: geração + geofencing)
    │               │       │
    │               │       └─► STORY-062 (validação check-in pelo contratante → ativo)
    │               │               │
    │               │               └─► STORY-063 (cronômetro bilateral vivo)
    │               │                       │
    │               │                       └─► STORY-064 (PIN check-out)
    │               │                               │
    │               │                               └─► STORY-065 (captura + Pix sandbox)
    │               │
    │               └─► STORY-066 (cancelamento + no_show_pro + liberação pré-auth)
    │
    └─► STORY-067 (notificações in-app + e-mail dos eventos do turno)
                                                         │
                                                         ▼
                                                   STORY-068 (validador independente — última)
```

| ID | Título | Tipo | Papel | Tamanho |
|---|---|---|---|---|
| STORY-055 | Spike Arquiteto — modelo Turno + AceiteEletronico imutável + máquina de estados | spike | arquiteto | M |
| STORY-056 | Spike Arquiteto — ACL Pagar.me + adapter sandbox/mock + idempotência + webhook | spike | arquiteto | **L** |
| STORY-057 | Spike Arquiteto — tempo real cronômetro bilateral + geolocalização Haversine | spike | arquiteto | M |
| STORY-058 | Aceitar candidatura no Backoffice + AceiteEletronico imutável + pré-autorização Pagar.me | implementation | programador | M |
| STORY-059 | Lista "Meus turnos" (profissional) + "Vagas confirmadas" (contratante) no WebApp | implementation | programador (+ designer) | S |
| STORY-060 | Detalhe do turno (ambos os lados) + timeline + trilha de auditoria visível | implementation | programador (+ designer) | M |
| STORY-061 | PIN de check-in — geração pelo profissional + captura de geofencing (PDR-008) | implementation | programador (+ designer) | M |
| STORY-062 | Validação do PIN de check-in pelo contratante + transição para `ativo` | implementation | programador (+ designer) | M |
| STORY-063 | Cronômetro bilateral vivo em tempo real (latência ≤ 2s) | implementation | programador (+ designer) | **L** |
| STORY-064 | PIN de check-out — geração + validação + transição para `finalizado` | implementation | programador (+ designer) | M |
| STORY-065 | Captura Pagar.me + Pix sandbox + alerta admin em falha (PDR-010) | implementation | programador | M |
| STORY-066 | Cancelamento antes do check-in + `no_show_pro` + liberação da pré-autorização | implementation | programador (+ designer) | M |
| STORY-067 | Notificações in-app + e-mail dos eventos do turno (8 templates via STORY-020) | implementation | programador | M |
| STORY-068 | Validação final do EPIC-003 | validation | validador | M |

## Validação final

Critérios em `validation/checklist.md`. Relatório do validador em `validation/report.md`.

**Definição de épico concluído**: turno executado ponta a ponta com Pagar.me sandbox + Pix sandbox confirmado em homologação; habitualidade aplicada nos 4 cenários; geofencing registrando; cronômetro vivo; relatório do validador `approved`.

## Histórico

- 2026-05-26 — criado por PO durante planejamento da WAVE-2026-01.
