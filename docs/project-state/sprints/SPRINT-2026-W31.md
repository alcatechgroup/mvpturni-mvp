---
sprint_id: SPRINT-2026-W31
wave: WAVE-2026-01
status: active  # planned | active | closed
start_date: 2026-06-10
end_date: null  # fechamento por goal-atingido
opened_at: 2026-06-10
opened_by: "PO (Alexandro / Claude)"
activated_at: 2026-06-10
activated_by: "PO (Alexandro / chat)"
soft_cap_date: 2026-07-15  # ~35 dias — épico de feature transacional + backoffice (mesma régua de folga da W30)
closure_rule: "Fechamento por goal-atingido: encerra quando STORY-090..096 estiverem `done` E STORY-097 (validador) emitir veredito aceitável pelo PO (`approved` ou `approved_with_pending`). Este é o ÚLTIMO épico da WAVE-2026-01: o veredito positivo fecha o EPIC-005 e a onda. Soft-cap 2026-07-15 (~35d) é gatilho de reavaliação, não prazo. Pendências parqueadas da W30 (a11y do EPIC-012, reativar checkout_test, revisar tempo do gate E2E, chore do seeder) ficam FORA desta sprint por foco — candidatas à abertura da WAVE-2026-02."
goal: "Fechar a WAVE-2026-01 entregando o caminho de exceção do check-out (EPIC-005 — disputa mínima): contratante recusa validar o check-out com justificativa obrigatória → turno em_disputa (pré-autorização mantida) → profissional notificado → admin vê na fila do backoffice e resolve 'pagar integral' → captura + Pix via fake (PDR-017) → turno finalizado, com trilha de auditoria completa — tudo demonstrável em homologação. Decisões em ADR-020 (modelo/transições/comando de captura do admin) e DDR-005 (telas de recusa, banner e caso de disputa)."
---

# SPRINT-2026-W31

## Objetivo do sprint

A SPRINT-2026-W30 fechou o EPIC-004 (avaliação recíproca) por goal-atingido em 2026-06-10 — o ciclo do turno agora termina em avaliação obrigatória com reputação visível. Resta **um** épico para fechar a WAVE-2026-01: o **EPIC-005 — Disputa mínima de check-out via backoffice**.

O problema que esta sprint resolve: hoje, se o contratante recusar validar o check-out, não há caminho — o turno fica em estado fantasma entre `aguardando_checkout` e `finalizado`, ninguém é pago, ninguém é notificado, e o admin não tem ferramenta para mediar. A WAVE-2026-01 entregou o caminho feliz ponta a ponta; este épico garante que o **caminho de exceção mais crítico** tem tratamento mínimo defensável (PDR-006): recusa com justificativa obrigatória → `em_disputa` → mediação no backoffice → resolução "pagar integral" com captura + Pix e trilha de auditoria. As resoluções `paga_parcial`/`sem_pagamento` ficam para a WAVE-2026-02 (EPIC-007).

**Decisão de escopo da W31** (a que o dono havia adiado no fechamento da W30): tackle **EPIC-005** para fechar a onda — escolhido pelo dono em 2026-06-10. As pendências parqueadas (dívida de a11y do EPIC-012, etc.) seguem candidatas à abertura da próxima onda.

## Escopo e duração

- **Escopo**: **8 estórias** — EPIC-005 inteiro decomposto via Fluxo B (2 spikes de decisão + 5 implementação + 1 validação). Mix: **1 S + 6 M + 1 L** — mesma régua da W30 ("ritmo bom", pedido do dono).
  - A **L** (STORY-092, backend de abertura da disputa) é candidata a quebra de sessão: se modelo + transição `em_disputa` + evento + notificação não couber, separar (a) modelo + transição + justificativa de (b) evento + notificação ao profissional. Escalar ao PO **antes** de inflar (padrão W28/W29/W30).
- **Superfícies**: API (`apps/api`) para modelo/transições/captura; WebApp Contratante (desktop, recusar check-out) + Profissional (mobile, banner); **Backoffice Admin** (`apps/admin`, fila + caso + resolver) — primeira vez que a disputa toca o backoffice de forma transacional.
- **Duração**: aberta, **fechamento por goal-atingido**. Soft-cap em **2026-07-15** (~35 dias) como gatilho de reavaliação, não prazo.

## Estórias incluídas

| ID        | Título                                                                                     | Épico    | Tipo           | Papel       | Tamanho | Status  |
| --------- | ------------------------------------------------------------------------------------------ | -------- | -------------- | ----------- | ------- | ------- |
| STORY-090 | Spike Arquiteto — modelo de disputa + transição em_disputa + comando de captura (ADR-020)  | EPIC-005 | spike          | arquiteto   | M       | done    |
| STORY-091 | Spike Designer — recusa + justificativa, banner e caso de disputa (DDR-005)                | EPIC-005 | spike          | designer    | M       | done    |
| STORY-092 | Backend — abertura de disputa (transição + justificativa + preauth mantida + notificação)  | EPIC-005 | implementation | programador | L       | done    |
| STORY-093 | Backend — resolução "paga integral" (captura via fake + Pix + finalizado + trilha)         | EPIC-005 | implementation | programador | M       | done    |
| STORY-094 | Frontend Contratante — recusar check-out e abrir disputa com justificativa                  | EPIC-005 | implementation | programador | M       | done    |
| STORY-095 | Frontend Profissional — banner de disputa + estado em_disputa nas listas                    | EPIC-005 | implementation | programador | S       | done    |
| STORY-096 | Backoffice Admin — fila + caso com trilha completa + resolver "pagar integral"              | EPIC-005 | implementation | programador | M       | done    |
| STORY-097 | Validação final do EPIC-005 (fecha a WAVE-2026-01)                                          | EPIC-005 | validation     | validador   | M       | done    |

**Sizing total**: **1 S + 6 M + 1 L (8 estórias)** — igual à W30.

## Ordem de execução obrigatória

```
STORY-090 (Arquiteto — ADR-020: modelo + transições + comando de captura do admin) ──┐
STORY-091 (Designer — DDR-005 + SCREENs recusa/banner/caso + protótipo aprovado) ────┤ (paralelo; ambos antes da implementação)
    │ ADR-020 accepted                                                                │ DDR-005 + protótipo "vai"
    ▼                                                                                 ▼
STORY-092 (BE — abertura: em_disputa + justificativa + preauth + notificação)   STORY-094 (FE contratante — recusar + justificativa)
    │ turno chega a em_disputa                                                        │ (dep 091 + 092)
    ├─► STORY-093 (BE — resolução paga_integral: captura + Pix + finalizado)          ├─► STORY-095 (FE profissional — banner) (dep 091 + 092)
    │       │ comando de resolução vivo                                               │
    │       └─► STORY-096 (Backoffice — fila + caso + resolver) (dep 091 + 093 + 092) │
    │                                                                                 │
    └──────────────────────────► 092..096 done ◄─────────────────────────────────────┘
                                       ▼
                                STORY-097 (validador — última; fecha a onda)
```

**Por que esta ordem.** A decisão precede a implementação (lição W27/W28/W30): ADR-020 fixa modelo/transições/captura antes de qualquer código; DDR-005 + protótipo aprovado pelo dono antes de qualquer tela. O backend de abertura (092) destrava a resolução (093) e os dois frontends (094/095); a resolução (093) destrava o backoffice (096). O validador (097) fecha — e seu veredito positivo encerra o EPIC-005 **e a WAVE-2026-01**.

## Compromisso visível ao fim do sprint

**Em `app.homolog.turni.com.br` + `admin.homolog.turni.com.br` + API:**

- Contratante, no ponto de validação de check-out, tem "Recusar e abrir disputa" com **justificativa obrigatória**; ao recusar, o turno entra em `em_disputa` (pré-autorização mantida).
- Profissional recebe **notificação (in-app + e-mail)** e vê **banner** "valor em disputa — mediação em até 30 min" no detalhe do turno; estado `em_disputa` marcado nas listas.
- Admin vê o caso em `/disputas` com a **trilha completa** (chat, geofencing, checklist, cronômetro, justificativa, vaga) e resolve com **"pagar integral"** → captura + Pix (fake) → turno `finalizado` apto à avaliação recíproca.
- **Trilha de auditoria** completa: abertura (justificativa, quem, quando) + resolução (admin, decisão, nota, quando).

**Decisões registradas:** ADR-020 (modelo/transições/comando de captura), DDR-005 (telas de recusa/banner/caso). IDR(s) eventuais de implementação.

## Decisões de produto/arquitetura que entram em vigor agora

- **PDR-006** (disputa de check-out via admin, SLA público 30 min) — base do épico.
- **PDR-017** (pagamento via fake genérico atrás de ACL no MVP) — captura/Pix da resolução passam pelo fake.
- **ADR-020** (a produzir na STORY-090), **DDR-005** (a produzir na STORY-091).
- **Vigentes respeitados**: ADR-015 (modelo Turno), ADR-016 (ACL pagamento + idempotência), ADR-018 (UUID), ADR-019 (eventos/notificação + gate), DDR-001/002/003 (DS, pt-BR/24h, shell).
- **Fora do MVP (do `epic.md` e PDR-006)**: resoluções `paga_parcial` e `sem_pagamento`; estados `finalizado_ajustado`/`disputa_resolvida_sem_pagamento`; captura/estorno parcial; penalidade automática de score; UI rica de mediação; recurso do profissional.
- **Fora desta sprint (foco)**: dívida de a11y do EPIC-012; reativar `checkout_test` no gate; revisão de tempo do gate E2E; chore de higiene do seeder `seedTurnoNaJanela`. Permanecem parqueadas — candidatas à abertura da WAVE-2026-02.

## Riscos identificados na abertura

| Risco | Probabilidade | Impacto | Mitigação | Owner |
|---|---|---|---|---|
| Spikes (090/091) viram gargalo de entrada — toda a implementação depende deles | alta | alto | São as primeiras e rodam em paralelo; PO prioriza aprovação da ADR-020 e do protótipo no D1–D3; enquanto não fecham, 092+ ficam `blocked` | Arquiteto + Designer + PO |
| STORY-092 (L) estoura sessão única — modelo + transição + evento + notificação é bastante | média | médio | Gatilho de quebra documentado (modelo/transição vs evento/notificação); ADR-020 entrega a decisão antes | Programador + PO |
| Idempotência financeira na resolução — reprocesso captura/paga em dobro | média | alto | CA-4 de 093 exige idempotência por construção (reuso ADR-016) + testes de borda; núcleo ≥98%; validador confirma | Programador + Validador |
| Captura/Pix via fake (PDR-017) diverge do fluxo de check-out feliz | baixa | médio | 093 reusa a mesma máquina de captura do check-out; não cria caminho financeiro novo | Programador |
| Disputa toca o backoffice de forma transacional pela 1ª vez — RBAC/admin pode vazar dados | média | alto | CA-5 de 096 + fail-secure; E2E do admin; PO verifica em homolog | Programador + Validador |
| CI vermelho cosmético mascarando falha (repetir F-B-1 da W30) | média | médio | CA-3 da validação exige CI verde na main; Pint/analyze/format limpos antes de `done` | Programador + Validador |
| Regressão do caminho feliz (EPIC-003/004) ao mexer na máquina de estados | baixa | alto | E2E vigentes não podem regredir (CA-4 da validação); resolução reusa gate/notificação do EPIC-004 | Programador + Validador |

## Acompanhamento contínuo (PO)

- **Diário (~10 min)**: olhar `index.json`; desbloquear sobretudo ADR-020 e o protótipo da STORY-091 (gargalos de entrada).
- **Mid-sprint check**: ADR-020 + DDR-005 fecharam? 092 destravou 093/094/095? Se 092 foi quebrada, avaliar sessão extra.
- **Antes da validação**: checklist do EPIC-005 já está escrito (`validation/checklist.md`) para a STORY-097.
- **Soft-cap check em 2026-07-15**: se goal não bateu, abrir "Mudanças no escopo" e decidir.

### Registro de acompanhamento

| Data | Check | Situação |
|---|---|---|
| 2026-06-10 | Abertura da sprint (PO) | W31 aberta logo após o fechamento da W30 (EPIC-004 done). Dono escolheu EPIC-005 (fecha a WAVE-2026-01) como escopo. EPIC-005 decomposto em 8 estórias via Fluxo B (`ready`/`blocked`); `checklist.md` de validação escrito. Próximo passo: agentes Arquiteto (STORY-090 → ADR-020) e Designer (STORY-091 → DDR-005 + protótipo) executam em paralelo; humano aprova ADR e protótipo antes da implementação. |
| 2026-06-10 | STORY-090 DONE — ADR-020 accepted | Arquiteto entregou e o dono aprovou o **ADR-020** (6 decisões): disputa embutida em `turnos.disputa` (jsonb, grão de `cancelamento`, não tabela); abertura via `AbrirDisputaService` (`aguardando_checkout → em_disputa`, justificativa obrigatória, pré-autorização mantida) distinta do `recusar()` existente; **resolução `paga_integral` = comando da api `ResolverDisputaService` reusando o `TurnoFinalizado` existente** → mesma máquina captura+Pix do check-out feliz (fake/PDR-017), idempotente em 3 camadas, **admin é cliente (nunca escreve no banco)**; evento novo `DisputaAberta` + fila do admin derivada do estado; `paga_parcial`/`sem_pagamento` fora do MVP (estados já modelados → EPIC-007). **Destravou STORY-092/093/096 (blocked → ready).** Gargalo de entrada restante: **STORY-091 (Designer → DDR-005 + protótipo)**, que ainda libera 094/095. |
| 2026-06-10 | STORY-091 DONE — DDR-005 + protótipo | Designer entregou e o dono aprovou o **DDR-005** + SCREEN-STORY-091-disputa: recusa que desambigua o check-out, banner read-only do profissional ("valor em disputa — mediação em até 30 min") e tela de caso do admin com trilha completa. **Destravou STORY-094/095/096 (blocked → ready).** Com 090 e 091 fechados, os dois gargalos de entrada (spikes de decisão) saíram do caminho crítico — implementação liberada. |
| 2026-06-10 | STORY-092 DONE — abertura de disputa (BE) | Programador entregou a **abertura**: transição `aguardando_checkout → em_disputa`, justificativa obrigatória, pré-autorização mantida e notificação ao profissional. CI verde + deploy homolog verificado. A **L** coube em sessão única — **não foi preciso quebrar** (gatilho de quebra documentado não acionado). **Destravou STORY-093/094/095 (blocked → ready).** |
| 2026-06-10 | STORY-093 DONE — resolução "paga integral" (BE) | Programador entregou a **resolução**: comando do admin `em_disputa → finalizado` reusando captura+Pix do check-out feliz (fake/PDR-017) + trilha de auditoria, idempotente por construção (ADR-016). **Destravou STORY-096 (blocked → ready).** Com isso o caminho transacional da disputa (abertura + resolução) está completo no backend. |
| 2026-06-10 | STORY-094 DONE — recusar check-out (FE contratante) | Programador entregou o **frontend do contratante**: ação "Recusar e abrir disputa" com justificativa obrigatória no ponto de validação de check-out. CI verde + Deploy Stage/homolog verificado. |
| 2026-06-10 | Mid-sprint check (situação atual) | **5/8 estórias `done`** (090, 091, 092, 093, 094). **Restam: STORY-095 (FE profissional — banner, S, `ready`) e STORY-096 (Backoffice admin — fila + caso + resolver, M, `ready`)** — ambas destravadas e prontas para iniciar (sem dependência aberta). **STORY-097 (validação) segue `blocked`** aguardando 095 e 096. **Próximo passo:** executar 095 e 096 (podem rodar em paralelo — 095 depende de 092 done; 096 depende de 093 done); ao fecharem, 097 destrava e o validador fecha o EPIC-005 **e a WAVE-2026-01**. Spikes não viraram gargalo (risco nº 1 mitigado) e a L não estourou sessão (risco nº 2 não materializado). Bem dentro do soft-cap (2026-07-15). Nota de higiene: o commit `18579b0` toca código de 095/096/097, mas estas seguem `ready`/`blocked` no `index.json` (fonte de verdade) — não foram marcadas `done`; tratar como trabalho ainda não validado/fechado. |
| 2026-06-11 | STORY-095 DONE — banner do profissional (FE) | Programador entregou o **banner read-only do profissional** ("valor em disputa — mediação em até 30 min") no detalhe do turno + estado `em_disputa` nas listas. CI dos jobs da estória verde. |
| 2026-06-11 | STORY-096 DONE — backoffice admin (fila + caso + resolver) | Programador entregou a fila `/disputas` (derivada do estado, SLA 30 min), o caso com trilha (justificativa + audit_logs + geofencing + cronômetro + vaga; chat/checklist não existem no MVP — ADR-020 D6), e a ação "Resolver: pagar integral" (`nota_admin` OBRIGATÓRIA — ADR-020/DDR-005, supera o "opcional" do CA original) via canal interno admin→api (IDR-032). Cobertura do código novo do admin 100%. Fechada em 2 passos: (1) **CI verde na main** — o vermelho do Trivy NÃO era CVE base não-fixável (hipótese do BUG-001): eram 4 CVEs HIGH **fixáveis** de pacote OS na base alpine:3.22 (openssl/libxml2/nginx), corrigidos via `apk upgrade --no-cache` nos Dockerfiles (commit `019b668`, run `27372520746`); o Commit lint vermelho (header de 162 chars) curou-se no commit seguinte; (2) **Deploy Stage** (run `27372780215`) + smoke `/disputas` (fail-secure HTTP + visual logado chancelado pelo PO). |
| 2026-06-11 | STORY-097 DONE — validação do EPIC-005: **veredito APPROVED** | Validador executou o checklist completo (9 seções) com evidência independente: **0 fail** (bloqueante ou não). Suítes verdes (api 1118 / admin 153 / webapp 753), cobertura geral ≥80% e **núcleo api+admin 100%**, CI verde na main (run `27373316385`), E2E de disputa (contratante recusa + admin resolve) verdes + caminho feliz EPIC-003/004 sem regressão, escopo MVP respeitado (parcial/sem_pagamento/penalidade inalcançáveis), ciclo demonstrável no **stage** (turno `em_disputa` semeado, pré-auth mantida, trilha de abertura, `/disputas` fail-secure). Observações não-bloqueantes no report: flake pré-existente do EPIC-003 (`GerarPinCheckoutTest`, ~18%, verde no CI); 2 controllers de disputa em 91,7% (catch defensivo inalcançável); cold-start no Playwright do admin (passa no retry). Report em `epics/EPIC-005-disputa-minima/validation/report.md`; `index.json` com `validation_verdict: approved`. **Todos os 7 riscos da abertura mitigados** (idempotência financeira confirmada, RBAC fail-secure verificado, sem regressão, CI verde — F-B-1 não se repetiu). **8/8 estórias `done`. A `closure_rule` está satisfeita** (090..096 done + 097 veredito aceitável). Pendente: decisão do PO de declarar o fechamento do EPIC-005, da SPRINT-2026-W31 e da WAVE-2026-01 por goal-atingido. |

## Mudanças no escopo do sprint

> Toda alteração no conjunto de estórias após esta abertura registra aqui, com data e motivo.

| Data | O que mudou | Motivo | Custo |
|---|---|---|---|
| — | — | — | — |

## Fechamento do sprint (preencher no encerramento)

### O que foi entregue
- ...

### O que ficou para trás (e por quê)
- ...

### Aprendizados
- <aprendizado de produto>
- <aprendizado de processo>

### Ajustes para o próximo sprint
- <ajuste> — abertura da WAVE-2026-02 (replanejamento de onda, Fluxo A).
