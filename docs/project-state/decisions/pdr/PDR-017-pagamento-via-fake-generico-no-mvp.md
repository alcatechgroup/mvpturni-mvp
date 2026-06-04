---
pdr_id: PDR-017
slug: pagamento-via-fake-generico-no-mvp
title: Pagamento via fake genérico no MVP — integração Pagar.me adiada para a próxima wave; ACL preservada
status: accepted
decided_at: 2026-06-04
decided_by: PO (Alexandro / Claude)
supersedes: null
superseded_by: null
related_epics: [EPIC-003, EPIC-005]
related_adrs: [ADR-005, ADR-016]
related_stories: [STORY-056, STORY-056-B, STORY-058, STORY-065, STORY-066, STORY-068, STORY-075]
---

# PDR-017 — Pagamento via fake genérico no MVP

## Contexto

A WAVE-2026-01 nasceu apostando em integração real com Pagar.me em **sandbox** durante o MVP, atrás de uma camada de abstração (ACL) decidida em ADR-005 e detalhada operacionalmente em ADR-016 (em rascunho via STORY-056, atualmente `in_review`). O desenho previa: interface `GatewayPagamento` no domínio, adapter Pagar.me real, mock dedicado em container para desenvolvimento local, contract test consumer-driven contra o sandbox real no CI noturno (STORY-056-B), e webhook entrante validado por assinatura HMAC.

A SPRINT-2026-W28 (planned) abriria essa frente ao ativar. Mas a integração Pagar.me em sandbox **não vai chegar a tempo** do MVP: o setup operacional do provedor (credenciais, conta sandbox aprovada, configuração de chave Pix, webhook URL liberada) tem janela própria de calendário do Pagar.me que não cabe no ciclo da W28. A STORY-056-A, atualmente `in_review`, está **travada justamente nesse ponto** — o agente arquiteto entregou o desenho da ACL + mock em container + idempotência + esqueleto de webhook, mas o adapter Pagar.me real não pôde ser exercido contra um sandbox vivo.

Sem decisão de produto, o cenário se desdobra mal de 3 jeitos: (a) o EPIC-003 estaria preso aguardando habilitação externa de fornecedor, (b) o time empurra um "Pagar.me sandbox half-baked" que esconde o atraso mas não funciona ponta a ponta, (c) o MVP atrasa em semanas o ciclo do turno e a WAVE-2026-01 perde sua hipótese central de "ciclo executável em homologação".

A decisão aqui é a **mais barata e a que preserva mais valor**: substituir o adapter Pagar.me real por um **fake genérico** que vive atrás da mesma ACL, eliminar o contract test contra sandbox real (não há sandbox), e seguir o ciclo do turno fim a fim com pagamento simulado. A camada de abstração — o ativo durável da ADR-005 — fica preservada para que a troca futura (Pagar.me real, ou outro PSP) seja localizada.

## Opções consideradas

### Opção 1 — Substituir adapter Pagar.me real por fake genérico atrás da mesma ACL (escolhida)

- **Descrição:** Adapter Pagar.me real sai. Fake genérico implementa a interface `GatewayPagamento` (operações `preAutorizar`, `capturar`, `liberar`, `transferirPix`). É o **driver padrão único** em todos os ambientes (dev local, homolog e qualquer futuro). Mock em container vira o próprio fake. Webhook entrante existe no desenho mas o fake emite eventos internos diretamente (não há HTTP externo). Contract test contra sandbox real (STORY-056-B) sai. Banner global "Ambiente de teste — pagamentos simulados" em homolog para deixar claro a qualquer pessoa que abre o WebApp ou o Backoffice em homolog que o pagamento não é real.
- **Prós:**
  - Caminho mais curto até EPIC-003 fechar — destrava a STORY-056 sem aguardar fornecedor externo.
  - Camada de abstração preservada — quando Pagar.me (ou outro PSP) entrar, troca-se apenas o adapter; domínio do Turno não muda.
  - Permite simular caminhos de exceção (falha de captura, falha de Pix, atraso) sem depender do sandbox — útil para testar PDR-010 (alerta admin) com determinismo.
  - Banner em homolog elimina ambiguidade demonstrativa (Alexandro/equipe demonstrando para parceiros).
- **Contras:**
  - O ciclo end-to-end fica **demonstrado mas não exercitado contra rede externa real** — surpresa de integração ao trocar adapter (autenticação, formato de payload, idempotência do provedor real, semântica de webhook) só aparece quando a Wave seguinte introduzir Pagar.me de verdade. Mitigação: a interface foi desenhada genérica desde a ADR-005; o custo de surpresa é localizado no novo adapter, não no domínio.
  - Promessa pública "Pix em 15 min" passa a ser **simulada** em homolog. Mitigação: manter como simulação respeita PDR-004 e PDR-010 conceitualmente; comunicação ao usuário em homolog via banner global.

### Opção 2 — Esperar Pagar.me sandbox ficar disponível e atrasar W28

- **Descrição:** Pausar W28 até a habilitação externa do Pagar.me; manter o desenho da STORY-056-A em `in_review`; nada de fake.
- **Consequência se mantivermos:** WAVE-2026-01 perde semanas (calendário do fornecedor é opaco). Hipótese central da onda ("ciclo do turno em homolog ponta a ponta") fica adiada sem aprendizado de produto enquanto isso. Custo de oportunidade alto e sem ganho proporcional — o sandbox do Pagar.me **não muda o desenho da ACL nem ensina nada novo sobre o domínio**; é só infra externa.

### Opção 3 — Ir direto para Pagar.me em produção pulando sandbox

- **Descrição:** Saltar o sandbox e configurar Pagar.me real em homolog/prod já.
- **Consequência se mantivermos:** Inaceitável. (a) Sem sandbox não há ensaio antes de tocar dinheiro real; (b) homolog passa a movimentar dinheiro real, o que invalida o próprio papel da homologação; (c) o time não tem volume de operações para justificar entrada em produção financeira nesta wave.

### Opção 4 — Status quo (manter o desenho original e esperar)

- **Consequência se mantivermos:** STORY-056-A continua `in_review` indefinidamente; W28 não ativa; agentes ficam ociosos esperando algo que não depende de código. Pior versão da Opção 2.

## Decisão

> **Optamos pela Opção 1.** Pagar.me **sai do MVP**; entra em escopo da próxima wave. No lugar, MVP usa **fake genérico atrás da mesma ACL** (`GatewayPagamento`). Banner global "Ambiente de teste — pagamentos simulados" em homolog. Promessa "Pix em 15 min" mantida como **simulação** — fake confirma em ~30s e o produto diz "Pix enviado". STORY-056 é reescopada (não abandonada); STORY-056-B (contract test contra sandbox) é abandonada por perda de objeto.

## Justificativa

A ACL é o ativo arquitetural durável da ADR-005 — escolhida exatamente para que a troca futura de PSP fosse barata. Esta decisão **exercita esse ativo na primeira oportunidade**: o adapter é o que muda, o domínio do Turno não. Preserva o aprendizado dos princípios #5 (isolar externo do domínio) e #6 (local funcional sem internet) cunhados em ADR-005; só não exercita o aprendizado de #5 contra um adapter externo real — esse é o trade-off aceito.

O cronograma da WAVE-2026-01 vale mais do que a fidelidade do sandbox em homolog para o MVP. A hipótese central da onda — "ciclo do turno executável em homolog ponta a ponta" — fica demonstrável; o que muda é o realismo da camada financeira, que continua sendo a **mais frágil** mesmo com sandbox (o sandbox do Pagar.me não é produção; já era uma simulação parcial). A diferença entre simulação Pagar.me sandbox e simulação fake local é menor do que parece em valor de aprendizado de produto e maior do que parece em custo de operação.

PDR-004 (taxa Turni 15% sobre valor) e PDR-010 (Pix sem retry no MVP — uma tentativa, alerta admin em falha) **continuam valendo conceitualmente** — o fake implementa o mesmo comportamento. PDR-006 (disputa via admin, EPIC-005) também não é afetado — disputa opera sobre o modelo do Turno, não sobre o gateway.

## Consequências

### Positivas

- STORY-056 destrava imediatamente — o trabalho já feito (interface + ACL + idempotência + esqueleto de webhook + mock em container) é aproveitado integralmente; só o adapter Pagar.me real e o contract test contra sandbox saem.
- W28 pode ativar assim que W27.5 (refator UUID) fechar — sem dependência de habilitação externa.
- Fake configurável (sucesso / falha de captura / falha de Pix / atraso) permite testar PDR-010 com determinismo, sem depender de variabilidade do sandbox.
- Eliminação do contract test contra sandbox tira do CI noturno um job que custa tempo e flakeia por motivos externos.
- Banner global "Ambiente de teste — pagamentos simulados" elimina ambiguidade demonstrativa para Alexandro/equipe Turni e qualquer parceiro/investidor que abra o homolog.
- A ACL é validada pelo seu **propósito real** (trocar adapter sem mudar domínio) já no MVP, em vez de ser apenas teoria.

### Negativas / trade-offs aceitos

- Ciclo end-to-end **não é exercitado contra rede externa real** no MVP. Surpresas de integração (autenticação, formato do payload, semântica do webhook, idempotência do provedor) só aparecem quando a wave seguinte introduzir Pagar.me real. Risco aceito: o domínio do Turno não muda, só o adapter; e o custo de descoberta tardia é absorvido por um épico dedicado à integração real (próxima wave).
- "Pix em 15 min" da promessa pública passa a ser **simulação** em homolog. O produto fala "Pix enviado" sem nada cair de verdade. Mitigação: banner global em homolog deixa explícito; em comunicação externa (landing, materiais comerciais) a promessa continua descrita como capacidade do produto, não como "o que está rodando hoje em homolog".
- O EPIC-005 (disputa) precisará simular captura parcial / sem pagamento via fake também — mas isso já é trivial pelo desenho da ACL e cabe naquele épico, não muda esta decisão.
- A próxima wave terá um épico dedicado à integração Pagar.me real (com sandbox + adapter + contract test + setup operacional + go-live em produção). Esse épico vira **risco técnico nº 1 daquela wave** — antecipar isso agora no `roadmap/next-wave.md`.

### Para o time técnico

- **ADRs que esta decisão pode demandar (a serem revistas pelo Arquiteto, não pelo PO):**
  - **ADR-005** (Pagar.me alto nível, status `accepted`) — precisa ser **superseded** ou anotada: o desenho da ACL continua válido; a escolha de PSP como Pagar.me **único no MVP** deixa de ser verdade — passa a "Pagar.me adiado, fake genérico no MVP". Arquiteto decide se vira nova ADR (ADR-019?) supersedendo ADR-005, ou se ADR-005 ganha apenas nota.
  - **ADR-016** (ACL Pagar.me sandbox + idempotência + webhook, em rascunho via STORY-056-A) — escopo muda: vira "ACL de pagamento (provider-agnóstico) + fake genérico + idempotência + webhook interno". STORY-056 reescopada cobre essa revisão.
- **Impacto em épicos:**
  - EPIC-003 (esta wave) — implementa atrás da ACL com fake. Métrica primária "Pix sandbox em ≤ 15 min em 95% dos turnos" passa a "fake processa em SLA configurado (~30s) em 100% dos turnos no caminho feliz".
  - EPIC-005 (esta wave) — captura parcial e "sem pagamento" implementam atrás da mesma ACL com fake.
  - Wave seguinte — épico novo de integração Pagar.me real (sandbox + adapter + contract test + setup operacional + go-live), trocando o adapter sob a mesma ACL.
- **Impacto em estórias** (todas em SPRINT-2026-W28 `planned`):
  - **STORY-056** — `in_review` → `in_progress` com escopo revisto (rebatizada de "ACL Pagar.me sandbox" para "ACL de pagamento + fake genérico"). Aproveita o trabalho já feito.
  - **STORY-056-B** — `ready` → `abandoned` (contract test contra sandbox perde objeto).
  - **STORY-058** — pré-autorização via fake, sem dependência de credenciais Pagar.me.
  - **STORY-065** — captura + Pix via fake; métrica ajustada.
  - **STORY-066** — liberação via fake.
  - **STORY-068** (validador) — checklist ajustado: sem evidência no painel sandbox Pagar.me; verifica banner em homolog; SLA do fake; ACL permanece provider-agnóstica.
  - **STORY-075** — Banner global em homolog "Ambiente de teste — pagamentos simulados" (frontend WebApp + Backoffice, S). Decisão de produto desta PDR, implementada como estória própria. *Originalmente reservada como STORY-074, renumerada por colisão com EPIC-011 (geocoding) reservado em paralelo.*

## Sinais de revisão

- **Wave seguinte muda os requisitos.** Se a equipe Turni e Pagar.me destravarem a habilitação operacional antes do encerramento da WAVE-2026-01 e Alexandro decidir antecipar a integração real, esta decisão é revisitada (nova PDR registra a retomada).
- **Fake esconde gap de domínio.** Se durante o EPIC-003 ou EPIC-005 o time descobrir que o fake esconde uma decisão de produto não tomada (ex: o que fazer quando captura confirma mas Pix falha em janelas específicas; semântica exata de webhook reentrante), parar e tratar como PDR novo — não decidir no código.
- **Promessa "Pix em 15 min" fica inverificável por tempo demais.** Se a wave seguinte adiar a integração real, há risco de a promessa pública envelhecer sem evidência operacional. Reavaliar comunicação externa.
- **ADR-005 + ADR-016 ficam ambíguas no índice.** Se o Arquiteto não revisar essas ADRs em janela curta (~1 semana), o PO escala — não pode haver ADR `accepted` que contradiz o estado real do código.
