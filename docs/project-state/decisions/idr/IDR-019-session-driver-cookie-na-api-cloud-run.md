---
idr_id: IDR-019
slug: session-driver-cookie-na-api-cloud-run
title: SESSION_DRIVER=cookie na api (Cloud Run) — corrige sessão não-persistente (401 após login)
status: accepted
decided_at: 2026-05-31
decided_by: programador
owner_agent: claude-opus-programador-designer-2026-05-30
related_story: STORY-023
related_adrs: [ADR-004, ADR-007]
related_idrs: []
supersedes: null
superseded_by: null
created_at: 2026-05-31
updated_at: 2026-05-31
---

# IDR-019 — SESSION_DRIVER=cookie na api (Cloud Run)

## Contexto

Ao subir STORY-023 em homolog, a tela de completar-cadastro caía em "Não conseguimos enviar agora" no preview. Diagnóstico: o usuário **loga com 200** (a sessão é criada e o cookie `laravel-session` é setado), mas **qualquer request autenticada seguinte retorna 401** (testado com `/api/user` do usuário ativo — também 401). O cookie de sessão está presente no jar e é enviado, mas o servidor não encontra a sessão.

Causa raiz: a imagem da api (`infra/docker/api/Dockerfile.prod`) trazia `ENV SESSION_DRIVER=array` (commit `0b63820`, "Cloud Run sem sessão em banco"). O driver **`array` não persiste a sessão entre requisições** — funciona só dentro de uma request. Para um SPA Sanctum com auth por cookie de sessão em Cloud Run (stateless, sem afinidade de instância), `array` quebra toda a navegação autenticada. Era um bug latente: o gate de E2E roda contra `localhost` (IDR-004), nunca contra homolog, então nenhum teste automatizado pegou. STORY-023 é o primeiro fluxo que exercita várias requests autenticadas em sequência (contexto GET → preview POST → completar POST) e expôs o problema.

## Decisão

> **Decidi usar `SESSION_DRIVER=cookie` na api** (não `array`, não `database`).

O driver `cookie` guarda a sessão **cifrada (APP_KEY) no próprio cookie** — stateless, sem tabela, sem round-trip de banco, e imune à ausência de afinidade de instância do Cloud Run. É o mesmo driver que o **admin** já usa com sucesso no mesmo homolog. Aplicado em três lugares para ser determinístico: `Dockerfile.prod` (default da imagem), `release.yml` (`--update-env-vars SESSION_DRIVER=cookie` no deploy da api) e `infra/envs/homolog/main.tf` (reconciliação do Terraform, que estava em `database`).

## Por quê

- **Honra a intenção original** ("Cloud Run sem sessão em banco") — `cookie` é a realização correta de "sem sessão em banco"; `array` foi a escolha errada (é driver de teste, não de produção).
- **Provado**: o admin roda com `cookie` em homolog sem problema.
- **Menor risco** que `database`: não depende da tabela `sessions` existir/estar acessível (com `database`, tabela ausente → 500 no login). Sessão do SPA é pequena (id do usuário + token CSRF) — cabe folgado no limite de 4 KB do cookie.

## Alternativas consideradas

- **`database`** (o que o Terraform declarava): funciona e a migration de `sessions` existe, mas adiciona round-trip e risco de 500 se a tabela faltar; contraria a intenção "sem sessão em banco". Descartado em favor de `cookie` (stateless, provado no admin).
- **Manter `array`**: é o bug. Sem persistência = auth quebrada. Descartado.

## Impacto / sinais de revisão

- Afeta **toda** a auth do WebApp em homolog (não só STORY-023) — corrige um bug pré-existente.
- **Gap de teste exposto:** o E2E só roda local; a auth de homolog nunca foi validada em browser real automatizado. Sinal de revisão: avaliar um smoke autenticado pós-deploy (login → request autenticada → 200) no `release.yml`, além do smoke atual de `/health` e `/version.json`.
- Se a sessão do SPA crescer além de ~4 KB no futuro (improvável no MVP), migrar para `database`.
