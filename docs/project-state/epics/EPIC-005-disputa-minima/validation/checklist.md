# Checklist de validação final — EPIC-005 (Disputa mínima)

> Preenchido pelo PO para a STORY-097. O validador executa cada item em homologação e registra evidência no `report.md`. **Fechamento da WAVE-2026-01** depende do veredito positivo deste épico.

## 1. Abertura da disputa (caminho do contratante)

- [ ] Contratante em `aguardando_checkout` tem a ação "Recusar e abrir disputa" distinta de "validar".
- [ ] Justificativa **obrigatória**: enviar vazio é bloqueado com erro acionável; não chama API.
- [ ] Com justificativa válida + confirmação, o turno transita para `em_disputa`.
- [ ] Abrir disputa fora de `aguardando_checkout` é rejeitado (409/422), sem efeito.
- [ ] RBAC: só o contratante dono da vaga abre; profissional/outro contratante/anônimo → 403 (fail-secure).

## 2. Efeito financeiro na abertura

- [ ] Ao entrar em `em_disputa`, a pré-autorização permanece **bloqueada** — nem captura nem libera (verificável via ACL/fake PDR-017).

## 3. Notificação e visão do profissional

- [ ] Profissional recebe notificação **in-app + e-mail** na abertura (≤ 30s), idempotente (sem duplicar).
- [ ] Banner "valor em disputa — mediação em até 30 min" aparece no detalhe do turno; estado `em_disputa` marcado na lista "Meus turnos".
- [ ] Profissional **não** tem nenhuma ação sobre a disputa (read-only).

## 4. Mediação e resolução (admin)

- [ ] `/disputas` mostra a fila de turnos `em_disputa` com contratante, profissional, valor e tempo decorrido vs SLA 30 min, mais antigo primeiro.
- [ ] Tela de caso mostra a **trilha completa**: chat, geofencing, checklist, cronômetro, justificativa, vaga original, dados de ambos.
- [ ] Ação "Resolver: pagar integral" com confirmação + `nota_admin` opcional.
- [ ] Resolução executa **captura padrão + Pix do `valor`** (fake) e transita o turno para `finalizado`.
- [ ] Disputa registra `resolucao: paga_integral`, `resolvida_em`, `resolvida_por`, `nota_admin`.
- [ ] RBAC: só admin resolve; outros papéis bloqueados, sem vazar dados.
- [ ] **Idempotência financeira**: reprocessar/resolução concorrente não captura/paga em dobro (no-op ou 409).
- [ ] Falha de Pix não trava o estado: turno fica `finalizado` com pagamento sinalizado para tratamento manual (PDR-010).

## 5. Fechamento do ciclo (não regredir)

- [ ] Turno resolvido vira `finalizado` apto à avaliação recíproca — gate/notificação do EPIC-004 não regrediram.
- [ ] Banner de disputa some após a resolução; turno exibe estado normal.

## 6. Trilha de auditoria

- [ ] 100% das disputas têm trilha completa e consultável (abertura + resolução + ator + timestamps + justificativa + nota).

## 7. Qualidade e pipeline

- [ ] Suítes api + webapp + admin verdes; cobertura ≥ 80% geral, **≥ 98% no núcleo** (transições de disputa, captura/idempotência, RBAC).
- [ ] CI **verde na main** (cosmético também conta — lição F-B-1 da W30).
- [ ] E2E do fluxo de disputa (contratante recusa + admin resolve) verdes; E2E do caminho feliz (EPIC-003/004) sem regressão.

## 8. Escopo do MVP respeitado

- [ ] `paga_parcial`, `sem_pagamento`, captura/estorno parcial e penalidade automática **não** estão implementados nem expostos na UI.
- [ ] Estados `finalizado_ajustado` e `disputa_resolvida_sem_pagamento` **não** são alcançáveis nesta entrega.

## 9. Demonstrável em homologação

- [ ] Vídeo/sequência de evidência: ciclo de disputa ponta a ponta em `app.homolog.turni.com.br` + `admin.homolog.turni.com.br`.

## Veredito

- [ ] `approved` | `approved_with_pending` | `rejected` — registrado em `report.md` com evidências e bloqueantes acionáveis.
