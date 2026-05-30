---
idr_id: IDR-014
slug: dev-same-origin-proxy-e-endpoint-me
title: Proxy same-origin no dev do WebApp + convenção de endpoint /usuarios/me/*
status: accepted
decided_at: 2026-05-29
decided_by: programador
owner_agent: claude-opus-4-8
related_story: STORY-022
related_adrs: [ADR-007]
related_idrs: [IDR-006]
supersedes: null
superseded_by: null
created_at: 2026-05-29
updated_at: 2026-05-29
---

# IDR-014 — Proxy same-origin no dev do WebApp + convenção de endpoint /usuarios/me/*

> **O que é um IDR.** Decisão técnica local com impacto em outras estórias/agentes.

## Contexto

A STORY-022 é a **primeira** estória do WebApp a fazer uma chamada de API **autenticada** após o login (`POST /api/usuarios/me/welcome-visto` — marca `welcome_seen_at`). Até aqui, todas as chamadas (login, pré-cadastros) liam apenas o **corpo** da resposta; nenhuma dependia do **cookie de sessão** voltar numa requisição posterior.

A autenticação do projeto é **Sanctum SPA por cookie de sessão** (ADR-007 §b). Em produção/homolog o WebApp e a API são **same-origin**: o Firebase Hosting reescreve `/api/**` e `/sanctum/**` para o Cloud Run da API (`firebase.json`), e o build é feito com `--dart-define=API_BASE_URL=` (vazio = mesma origem, ver `release.yml`). Same-origin é o que faz o cookie de sessão (`SameSite=lax`) trafegar nas requisições XHR seguintes.

No **dev local**, porém, o build default apontava para `http://localhost:8001` (API) enquanto o WebApp era servido em `http://localhost:8003` — **cross-origin**. Resultado: o cookie de sessão `SameSite=lax` **não** é enviado em XHR cross-site, então a chamada autenticada caía em `401 Unauthenticated`. O login "funcionava" só porque usa o corpo da resposta, não o cookie — mascarando o problema até agora.

## Decisão

> **Decidi (1) espelhar em dev a topologia same-origin de produção via um proxy no container do WebApp, e (2) padronizar endpoints "do próprio usuário logado" sob `/api/usuarios/me/*`, fora do `FunnelGuard` quando a ação faz parte da própria transição de funil.**

Concretamente:

1. **Dev same-origin:** o container `webapp` passa a servir com `php -S ... router.php`. O `router.php` (apps/webapp/router.php) encaminha `/api/**` e `/sanctum/**` para o container `api`; o resto é servido estático (com o fallback de SPA já existente). O default de `API_BASE_URL` no código passa a ser `''` (mesma origem), igual ao release — o WebApp chama `/api/...` no próprio host em todos os ambientes.
2. **Endpoint `/usuarios/me/welcome-visto`:** protegido por `auth:web` + `WebAppOnly` + `StartSession`, **sem** `FunnelGuard`. O guard retorna 423 para quem não está `active`; mas quem precisa marcar o welcome está justamente em `await_welcome` — colocá-lo sob o guard tornaria a ação impossível. A proteção de sessão + WebApp-only basta.

## Por quê

- **Paridade dev↔prod (KISS, princípio #3 "siga o ambiente real").** Bugs de cookie/CORS/CSRF aparecem cedo, no dev, em vez de só no deploy. O proxy reproduz exatamente o que o Firebase faz, sem introduzir CORS/`SameSite=none`/`Secure` que o cross-origin exigiria (e que não casa com `http://localhost`).
- **`API_BASE_URL=''` unifica os ambientes** num único caminho de código (mesma origem), eliminando a divergência "dev cross-origin vs prod same-origin".
- **`/usuarios/me/*`** é uma convenção REST comum e legível para recursos do usuário autenticado; mantém o endpoint de transição de funil acessível por quem está no meio do funil.

## Alternativas consideradas

- **CORS + `withCredentials` + `SameSite=none; Secure` (manter cross-origin):** descartada — `SameSite=none` exige `Secure`, que exige HTTPS; `http://localhost` não atende. Além disso, CSRF do Sanctum SPA pressupõe same-origin/sub-domínio. Seria nadar contra a arquitetura (ADR-007).
- **Servir o build do WebApp pelo próprio container `api` (Laravel):** descartada — mistura responsabilidades (a API serviria SPA estático) e diverge mais do desenho de produção (Firebase serve o estático).
- **Endpoint sob o grupo com `FunnelGuard`:** descartada — bloquearia (423) justamente o usuário `await_welcome` que precisa chamá-lo.

## Consequências

### Para outros agentes
- **Toda chamada autenticada do WebApp em dev passa pelo proxy same-origin** — não aponte `API_BASE_URL` para `localhost:8001`. Builds (inclusive E2E) usam mesma origem (`/api`, `/sanctum`).
- **Endpoints "do usuário logado" seguem `/api/usuarios/me/*`.** Ações que fazem parte da transição de funil (welcome, completar cadastro) ficam **fora** do `FunnelGuard`, protegidas por `auth:web` + `WebAppOnly`.
- `apps/webapp/router.php` é **infra de dev**, não código de produção — em produção quem reescreve é o Firebase.

### Para o projeto
- Container `webapp` agora roda um router PHP de ~70 linhas; sem dependência nova.
- O E2E autenticado do WebApp passou a ser possível localmente (gate antes do rc, IDR-004).

### Trade-offs aceitos
- O `router.php` é um proxy simples (sem streaming; usa `CURLOPT_RETURNTRANSFER`). Suficiente para dev; não é caminho de produção.

## Como verificar

- `curl http://localhost:8003/api/funcoes` deve responder 200 (proxy ativo).
- E2E `welcome.spec.ts` (CA-11) verde: login → /welcome → "Vamos lá" → /completar-cadastro; 2º login pula o welcome.
- Se a topologia de produção deixar de ser same-origin (improvável), reabrir esta IDR.

## Tipo

- [x] **Convenção interna**: endpoints `/usuarios/me/*` + dev same-origin como padrão.
- [x] **Workaround**: proxy de dev para espelhar o rewrite do Firebase.

---

## Histórico

- 2026-05-29 — criada como `accepted` por programador (sessão claude-opus-4-8) durante STORY-022
