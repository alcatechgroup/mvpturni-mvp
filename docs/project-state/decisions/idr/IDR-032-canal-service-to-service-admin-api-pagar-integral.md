---
idr_id: IDR-032
slug: canal-service-to-service-admin-api-pagar-integral
title: Canal admin→api do comando "pagar integral" via endpoint interno + segredo compartilhado (X-Internal-Token)
status: accepted  # aprovado por Alexandro em chat (2026-06-10) na decisão da STORY-093
decided_at: 2026-06-10
decided_by: programador
owner_agent: claude-opus-4-8
related_story: STORY-093
related_adrs: [ADR-007, ADR-016, ADR-020]
related_idrs: [IDR-028]
supersedes: null
superseded_by: null
created_at: 2026-06-10
updated_at: 2026-06-10
---

# IDR-032 — Canal admin→api do comando "pagar integral" (endpoint interno + segredo compartilhado)

## Contexto

A **ADR-020 (Decisão 3A)** fixou o princípio: a resolução `paga_integral` da disputa é um
**comando da api** (`ResolverDisputaService`), porque a captura+Pix é disparada por um evento
**in-process** (`TurnoFinalizado`) que o `apps/admin` — processo separado — **não consegue emitir**.
O admin é **cliente** desse comando. O ADR deixou explícito que o **mecanismo do canal** admin→api
("endpoint HTTP autenticado por sessão de admin vs serviço-a-serviço") é **detalhe de implementação
da STORY-093/096 — registrar como IDR**. Este é esse IDR.

Restrições herdadas:

- As rotas da api hoje são todas `auth:web` + `WebAppOnly` (sessão por cookie do **WebApp Flutter**).
  O `WebAppOnly` inclusive **bloqueia admins** (403 `admin_must_use_backoffice`) — o admin **não tem**
  sessão na api.
- Os dois apps **compartilham o banco** mas **não** a sessão nem a `APP_KEY` (cada um tem a sua).
- Não existe, até aqui, **nenhum canal HTTP** admin→api: o backoffice lê/escreve o banco direto via
  Eloquent próprio (PixFalhas é resolução **não-financeira**, escrita direto). O único segredo já
  compartilhado entre os apps é o `PIX_FALHA_CHAVE_KEY` (IDR-028), duplicado nos dois `.env`.
- ADR-020 (3B) **rejeitou** o admin escrever a transição/enfileirar o job direto no banco (acopla os
  apps, reintroduz o risco de "finalizado sem captura").

## Decisão

> **O comando "pagar integral" é exposto como um endpoint INTERNO da api
> (`POST /api/internal/turnos/{turno}/resolver-disputa`), FORA do grupo `auth:web`/`WebAppOnly`,
> autenticado por um SEGREDO service-to-service compartilhado (`INTERNAL_SERVICE_TOKEN`, header
> `X-Internal-Token`, comparado em tempo constante via `hash_equals`). A IDENTIDADE do admin chega
> no corpo (`admin_id`), asserida pelo app admin confiável e re-verificada na api (`isAdmin()`).**

- **Middleware `InternalServiceAuth`** protege o prefixo `/api/internal/*`. Fail-secure: segredo
  ausente na config **ou** header divergente → **401**. Espelha o racional do `PagarmeWebhookController`
  (segredo na borda, 401 se inválido), mas para tráfego **interno** (não há HMAC de provedor aqui).
- **RBAC em duas camadas (ADR-007):** o **canal** prova que o chamador é o app admin confiável (segredo);
  a **identidade** (`admin_id`) é re-verificada como `isAdmin()` no controller — id inexistente ou de
  contratante/profissional → **403**. Assim a CA-5 ("apenas admin resolve; demais 403; não autenticado
  401") é satisfeita no modelo service-to-service.
- **Segredo compartilhado nos 2 `.env`** (`INTERNAL_SERVICE_TOKEN`), default só para dev/CI no
  `config/services.php` (`services.internal.token`), homolog/prod via **Secret Manager** (ADR-004) —
  mesmo padrão e mesmo racional do `PIX_FALHA_CHAVE_KEY` (IDR-028).
- O **cliente HTTP** do lado do admin (base URL da api + envio do header/`admin_id`) é entregue pela
  **STORY-096** (backoffice). A STORY-093 entrega só o lado servidor + a paridade de config.

## Alternativas consideradas

- **Sessão/guard de admin na api (token Sanctum dedicado):** mais robusto a longo prazo, mas exige um
  novo guard/provedor de credencial de admin na api e fluxo de emissão/rotação de token — peças de auth
  desproporcionais para o MVP, que tem **um** comando interno. Reversível: migrar de segredo S2S para
  token por-admin é localizado (troca o middleware + o cliente do admin) se a superfície interna crescer.
- **Admin escreve no banco/enfileira o job** (ADR-020 3B): **rejeitado** no ADR (acoplamento + risco de
  estado fantasma).

## Consequências

- **+** Captura **single-sourced** na api (F1/F3 da ADR-020); o admin não toca dinheiro direto.
- **+** Zero peças novas de auth de usuário; reusa o padrão de segredo compartilhado já existente.
- **+** Superfície interna isolada sob `/api/internal/*` com seu próprio guard — não se mistura com a
  sessão do WebApp.
- **−** O `admin_id` é **asserido** pelo app admin (confiança no chamador autenticado pelo segredo), não
  provado por credencial do próprio admin na api. Aceitável: o app admin já autentica o admin com sessão
  própria antes de chamar; o segredo prova que é o app admin. Ponto de evolução registrado acima.
- **−** Mais um segredo a gerir no Secret Manager (paridade entre os apps), como o IDR-028 já exige.

## Pendência / evolução

- Se a superfície interna admin→api crescer além deste comando, reavaliar para um **guard de admin
  dedicado** (token por-admin) — auditoria por identidade provada na própria api, sem confiar no
  `admin_id` do corpo.
