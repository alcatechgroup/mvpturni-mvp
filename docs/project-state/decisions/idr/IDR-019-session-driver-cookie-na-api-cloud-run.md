---
idr_id: IDR-019
slug: session-cookie-name-session-atras-do-firebase-hosting
title: SESSION_COOKIE=__session na api atrás do Firebase Hosting (corrige 401 após login em homolog)
status: accepted
decided_at: 2026-05-31
decided_by: programador
owner_agent: claude-opus-programador-designer-2026-05-30
related_story: STORY-023
related_adrs: [ADR-002, ADR-004, ADR-007]
related_idrs: []
supersedes: null
superseded_by: null
created_at: 2026-05-31
updated_at: 2026-05-31
---

# IDR-019 — SESSION_COOKIE=__session na api (atrás do Firebase Hosting)

## Contexto

Ao subir STORY-023 em homolog, a tela de completar-cadastro caía em "Não conseguimos enviar agora". Diagnóstico (com logs e `gcloud` no projeto `turni-mvp`):

- O usuário **loga com 200**, mas **toda request autenticada seguinte retorna 401** — reproduzido com `/api/user` do usuário ativo (não é específico da STORY-023), inclusive na **mesma instância** (curl `--next`), então não é afinidade de instância nem APP_KEY por instância.
- Funciona **localmente** (webapp:8003 → api direto), falha **em homolog** (app.homolog → Firebase Hosting → Cloud Run).

Causa raiz: **o Firebase Hosting, ao reescrever `/api/**` e `/sanctum/**` para o Cloud Run, descarta TODOS os cookies da request encaminhada EXCETO um chamado `__session`** (comportamento documentado do Hosting, herdado da época das Cloud Functions). O cookie de sessão do Laravel se chamava `laravel-session` → era removido antes de chegar ao backend → o backend não via sessão → 401. O login dava 200 porque ele só precisa *criar* a sessão na própria request; a 419 intermitente no login vinha do token CSRF (que vive na sessão) também não chegar.

Achado paralelo: a imagem da api subia com `SESSION_DRIVER=array` (commit `0b63820`, "Cloud Run sem sessão em banco"), que tampouco persiste sessão. Corrigido junto.

## Decisão

> **Decidi (1) nomear o cookie de sessão da api como `__session` (`SESSION_COOKIE=__session`) — o único cookie que o Firebase Hosting encaminha ao Cloud Run; e (2) usar `SESSION_DRIVER=database`** (tabela `sessions` no Cloud SQL, que já existe).

Aplicado no `Dockerfile.prod` (default da imagem), no `release.yml` (`--update-env-vars SESSION_DRIVER=database,SESSION_COOKIE=__session` no deploy da api) e no Terraform (`infra/envs/homolog/main.tf`). Verificado ao vivo: `/api/user` passou a retornar 200, e o E2E do completar-cadastro (CA-8) passou contra `app.homolog.turni.com.br`.

O admin NÃO precisa de `__session`: é acessado direto pela URL `*.run.app` (sem Firebase Hosting na frente), então seus cookies não são filtrados.

## Por quê

- **`__session` é a única solução**: é literalmente o único nome de cookie que o Firebase Hosting deixa passar para o backend. Sem isso, nenhuma sessão por cookie funciona atrás do Hosting — independente de driver.
- **`database`** (em vez de `cookie`): a tabela `sessions` já existe (migrada em todo deploy); é instância-independente e consistente com `QUEUE_CONNECTION=database`. (`cookie` também funcionaria com `__session`, mas `array` não — `array` foi o bug secundário.)

## Alternativas consideradas

- **Manter `laravel-session`**: impossível atrás do Firebase Hosting (cookie é descartado). Descartado.
- **`SESSION_DRIVER=cookie`**: funcionaria com `__session`, mas escolhi `database` pela consistência com a fila e por já ter tabela. Não-bloqueante.
- **Trocar o Hosting/topologia** (ex.: api em domínio próprio sem Hosting): mudança de arquitetura (ADR-002/004) desproporcional — `__session` resolve com uma variável.

## Impacto / sinais de revisão

- Corrige um bug **pré-existente e geral** da auth do WebApp em homolog (não só STORY-023). Toda navegação autenticada estava quebrada.
- **Gap de teste exposto:** o E2E só roda contra `localhost` (IDR-004) — a auth de homolog nunca foi exercida em browser real automatizado. **Sinal de revisão:** adicionar um smoke autenticado pós-deploy no `release.yml` (login → request autenticada → 200), além do smoke atual de `/health` e `/version.json`.
- **Prod**: quando o WebApp de produção subir atrás do Firebase Hosting, a api de prod precisa do mesmo `SESSION_COOKIE=__session` (o Dockerfile já carrega como default).
- **Dívida de pipeline observada:** revisões antigas da api (com `--tag` por release) acumulam no Cloud Run; revisar limpeza de revisões/traffic tags.
