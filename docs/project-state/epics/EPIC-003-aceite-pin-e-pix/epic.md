---
epic_id: EPIC-003
slug: aceite-pin-e-pix
title: Aceite da candidatura, PIN bilateral e Pix (via fake genérico atrás de ACL — PDR-017)
wave: WAVE-2026-01
status: done  # fechado pelo PO em 2026-06-07 à luz do report da STORY-068 + correções F-NB-1/2/3/5 (F-B-1 aceito; F-NB-4/6/7 carry-forward)
owner_role: po
created_at: 2026-05-26
updated_at: 2026-06-07
target_completion: 2026-08-18  # estimativa orientativa
sprint_id: SPRINT-2026-W28  # primeira (e potencialmente única) sprint do épico
pivoted_by: PDR-017  # 2026-06-04 — Pagar.me real adiado para a próxima wave; MVP usa fake genérico atrás da mesma ACL
title_history:
  - "[até 2026-06-04] Aceite da candidatura, PIN bilateral e Pix via Pagar.me"
---

# EPIC-003 — Aceite, PIN bilateral e Pix (via fake genérico — PDR-017)

> **⚠️ Mudança de escopo (2026-06-04) — PDR-017 aplicada.** A integração real com Pagar.me **não chega a tempo** do MVP. Este épico passa a usar um **fake genérico** atrás da mesma ACL desenhada em ADR-005. A camada de abstração — o ativo arquitetural durável — fica preservada para troca futura. Banner global "Ambiente de teste — pagamentos simulados" em homolog (STORY-075). Promessa "Pix em 15 min" mantida como simulação (fake confirma em ~30s, configurável). Quando Pagar.me real entrar na próxima wave, **este épico não muda** — só o adapter.

## Por que existimos (problema do usuário)

Este é o coração da promessa do Turni. Sem PIN bilateral, sem Pix em 15 min, sem ciclo financeiro fim a fim — o produto vira "publicar vaga em app". Este épico **demonstra os dois pilares principais** restantes da promessa central (PIN Bilateral + Pix em 15 min) e fecha o ciclo do turno **em homolog com pagamento via fake genérico** (PDR-017). A integração real Pagar.me entra na próxima wave atrás da mesma ACL.

É o mais arriscado da onda em termos de domínio: depende da regra de habitualidade (PDR-002) já estar implementada, do geofencing (PDR-008) funcionar minimamente, da máquina de estados do turno (ADR-015) ser sólida, e do contrato da ACL (ADR-005 / ADR-016) ser provider-agnóstico de verdade — pré-requisito para a troca futura ser barata.

## Resultado esperado (outcome)

Ao fim deste épico, contratante aceita candidatura (fake genérico pré-autoriza valor + taxa Turni via `preAutorizar` da ACL; turno entra em `confirmado`); profissional faz check-in com PIN bilateral de 4 dígitos + flag de geofencing; cronômetro bilateral roda; profissional faz check-out com PIN; contratante valida; fake captura via `capturar`; **Pix simulado** confirma em SLA configurado (≤ 15 min como promessa pública; default ~30s em testes) com audit log `pix.enviado` + detalhe do turno mostrando "Pix enviado em HH:MM".

Os dois lados conseguem ver o estado do turno em tempo real (cronômetro vivo, eventos de match, notificações). Banner global em homolog deixa explícito que pagamento é simulado.

## Métrica de sucesso (como saberemos que funcionou)

- **Primária**: turno executado ponta a ponta em **100%** das tentativas no caminho feliz com fake em modo `success` (era 95% com sandbox — PDR-017 troca por simulação determinística). Pix simulado dentro do SLA configurado em 100% dos turnos.
- **Demonstração da promessa pública "Pix em 15 min"**: fake configurado com SLA 15min, 100% dos turnos confirmam dentro da janela. Resultado documentado pelo validador.
- **Validação de PIN**: ≤ 500ms p95 (operação crítica em pé, contexto de rua).
- **Habitualidade**: regra de 2x/semana (PDR-002) testada nos 4 cenários (PF 0-1-2 alocações libera; PF 3ª bloqueia; PJ 3ª alerta + override; transição de semana reseta).
- **Cronômetro bilateral**: latência de sincronização entre os dois lados ≤ 2s.
- **Caminho de exceção PDR-010** (alerta admin em falha de Pix): exercitado em homolog com fake em modo `fail_pix`.

## Entregável visível no fim do épico

- [ ] Contratante aceita candidatura; fake genérico registra pré-autorização (visível em `pagamento_operacoes` no Postgres + audit log `pagamento.pre_autorizado` + evento `PagamentoPreAutorizado` no log JSON).
- [ ] Turno aparece em `confirmado` para ambos os lados.
- [ ] Profissional, no horário de início, abre o turno e gera PIN de check-in (4 dígitos visíveis em tela).
- [ ] Contratante recebe alerta "profissional chegou — valide o PIN", digita o PIN, confirma; turno transita para `ativo`; cronômetro bilateral inicia.
- [ ] Ambos os lados veem o cronômetro vivo na mesma tela do turno.
- [ ] Geofencing: distância e flag `geofencing_ok` registradas no evento de check-in; se fora do raio de 100m, contratante vê aviso destacado (PDR-008).
- [ ] Profissional, ao fim do turno, gera PIN de check-out; contratante valida; turno transita para `finalizado`.
- [ ] Fake genérico captura valor + taxa Turni via `capturar`; **Pix simulado** confirma dentro do SLA configurado; detalhe do turno mostra "Pix enviado em HH:MM" no card de valor.
- [ ] Habitualidade aplicada no momento do aceite (PDR-002): PF bloqueado na 3ª; PJ alerta + override registrado no aceite eletrônico.
- [ ] **Banner global em homolog visível** em WebApp + Backoffice: "Ambiente de teste — pagamentos simulados" (STORY-075).

## Fora de escopo (explicitamente)

- Avaliação recíproca → vira EPIC-004.
- Disputa de check-out → vira EPIC-005.
- **Integração real com Pagar.me sandbox (PDR-017 — adiada para a próxima wave, em épico dedicado: sandbox + adapter real + contract test + setup operacional + go-live em produção).**
- **Contract test consumer-driven contra sandbox real (STORY-056-B abandonada por PDR-017).**
- Pagar.me em **produção** — fora MVP independente de PDR-017.
- Push notifications (mobile) — apenas in-app + e-mail no MVP.
- Tratamento sofisticado de falha de Pix > 15 min (PDR-010 — apenas alerta no admin, sem retry automático). Cenário exercitado com fake em modo `fail_pix`.
- Captura parcial / estorno parcial (vira EPIC-005 — também via fake configurável).
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
- **`docs/project-state/decisions/pdr/PDR-017-pagamento-via-fake-generico-no-mvp.md`** — pivô do MVP: fake genérico no lugar de Pagar.me real; ACL preservada; banner global em homolog.

## Dependências

- **Bloqueia**: EPIC-004 (avaliação só após turno finalizado), EPIC-005 (disputa precisa de aceite + check-out funcionando).
- **Bloqueado por**: EPIC-002 (sem candidatura, não há aceite); EPIC-010 / SPRINT-2026-W27.5 (refator UUID antes do EPIC-003 começar — ADR-018).
- **Decisões arquiteturais necessárias**:
  - ADR-005 (integração Pagar.me alto nível) **precisa ser revisada pelo Arquiteto pós-PDR-017** — desenho da ACL continua válido; escolha de PSP no MVP muda.
  - ADR-016 (ACL — em rascunho via STORY-056) **precisa ser revisada pelo Arquiteto pós-PDR-017** — vira "ACL de pagamento (provider-agnóstico) + fake genérico".
  - Estratégia de tempo real para cronômetro bilateral (WebSocket vs SSE vs polling) — ADR-017.
  - Estratégia de geolocalização no check-in (browser API + cálculo Haversine vs PostGIS) — ADR-017.
  - Notificação ao profissional após captura (e-mail + in-app no MVP) — STORY-067.

## Estórias

Decompostas via Fluxo B em **2026-06-03** (PO Alexandro/Claude), em paralelo ao fechamento da SPRINT-2026-W27. Total **15 estórias** (3 spikes + 11 implementação + 1 validação — STORY-075 adicionada em 2026-06-04 por PDR-017) — escopo do EPIC-003 inteiro alocado à **SPRINT-2026-W28**. Mix de sizing: 2 S + 11 M + 2 L. As duas L (STORY-056 ACL + fake e STORY-063 cronômetro bilateral) carregam gatilho de quebra documentado na própria estória. **STORY-056-B (contract test contra sandbox real) foi abandonada em 2026-06-04 por PDR-017.**

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
| STORY-075 | Banner global em homolog "Ambiente de teste — pagamentos simulados" (PDR-017) | implementation | programador | S |

## Validação final

Critérios em `validation/checklist.md`. Relatório do validador em `validation/report.md`.

**Definição de épico concluído**: turno executado ponta a ponta com Pagar.me sandbox + Pix sandbox confirmado em homologação; habitualidade aplicada nos 4 cenários; geofencing registrando; cronômetro vivo; relatório do validador `approved`.

## Histórico

- 2026-05-26 — criado por PO durante planejamento da WAVE-2026-01.
- 2026-06-04 — pivô PDR-017: Pagar.me sai do MVP; fake genérico atrás da mesma ACL; STORY-056-B abandonada; STORY-075 adicionada.
- 2026-06-07 — validação final (STORY-068): veredito **rejected** (1 F-B + 7 F-NB) — report em `validation/report.md`.
- 2026-06-07 — **fechado pelo PO**: F-B-1 aceito (sincronia verificada viva ≤2s; intermitência do teste assumida); F-NB-1/2/3/5 corrigidos na mesma sessão (métricas financeiras vivas no GCP, request_id api→fila→worker, runbook, cobertura dos services de check-out); F-NB-4/6/7 registrados como pendências (carry-forward). Deploy das correções de código: rc.86.
