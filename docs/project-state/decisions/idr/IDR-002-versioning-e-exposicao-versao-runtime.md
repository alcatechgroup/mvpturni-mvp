---
idr_id: IDR-002
slug: versioning-e-exposicao-versao-runtime
title: Mecanismo de stamping da tag no artefato e exposição da versão em runtime
status: accepted
decided_at: 2026-05-27
decided_by: programador
related_stories: [STORY-007]
related_adrs: [ADR-001, ADR-004]
created_at: 2026-05-27
updated_at: 2026-05-27
---

# IDR-002 — Stamping da tag no artefato e exposição da versão em runtime

## Contexto

STORY-007 CA-7b a CA-7e exigem que o pipeline de release injete a tag `vX.Y.Z-rc.N` no
artefato de cada interface no momento do build, e que cada interface exponha essa versão
em runtime por um mecanismo padronizado e único. STORY-008 e STORY-009 consomem esse
mecanismo sem reinventá-lo — este IDR é a fonte de verdade.

## Decisão

### Stamping (CA-7b)

**PHP (api e admin):** o pipeline injeta `APP_VERSION=$TAG` como Docker build ARG no
`Dockerfile.prod`. Dentro do builder stage, o arquivo `public/version.json` é gerado
com o conteúdo `{"version":"$TAG"}` via:

```dockerfile
RUN echo "{\"version\":\"${APP_VERSION}\"}" > public/version.json
```

A versão persiste no artefato publicado sem depender de variável de runtime do provedor
(o arquivo está no filesystem do container). Adicionalmente, a env var `APP_VERSION` é
propagada ao runtime do Cloud Run para uso no endpoint `/health`.

**Flutter web (webapp):** o pipeline gera `web/version.json` com `{"version":"$TAG"}`
**antes** do `flutter build web`, e também injeta via `--dart-define=APP_VERSION=$TAG`
para uso programático opcional no Dart. O arquivo `version.json` gerado é incluído no
build output e servido pelo Firebase Hosting.

### Exposição em runtime (CA-7c, CA-7d)

**Padrão único para as três interfaces:** arquivo estático `/version.json` servido
diretamente pelo servidor web de cada interface. Estrutura do payload:

```json
{"version":"v1.2.3-rc.4"}
```

| Interface | URL                                         | Mecanismo              |
|-----------|---------------------------------------------|------------------------|
| webapp    | `https://app.homolog.turni.com.br/version.json`   | Firebase Hosting serve o arquivo gerado no build |
| api       | `https://api.homolog.turni.com.br/version.json`   | Nginx serve `public/version.json` gerado no build |
| admin     | `https://admin.homolog.turni.com.br/version.json` | Nginx serve `public/version.json` gerado no build |

**Headers de cache:** `/version.json` é servido com `Cache-Control: no-cache` em todas
as interfaces (configurado no Firebase Hosting via `firebase.json` e no nginx via
header na resposta estática). Isso garante que um `curl` sempre pega a versão atual.

### Verificação (CA-7d)

```bash
# Após deploy com tag v0.1.0-rc.1:
curl https://api.homolog.turni.com.br/version.json
# {"version":"v0.1.0-rc.1"}

curl https://admin.homolog.turni.com.br/version.json
# {"version":"v0.1.0-rc.1"}

curl https://app.homolog.turni.com.br/version.json
# {"version":"v0.1.0-rc.1"}
```

Versão `dev`, `unknown` ou vazia é falha de pipeline — o build ARG não foi injetado.

### Endpoint /health (complementar)

O endpoint `/health` dos apps PHP também expõe a versão via `env('APP_VERSION')` no
payload JSON (ver ADR-008), como conveniência. A fonte de verdade para automação é
`/version.json`.

## Alternativas consideradas

- **Variável de ambiente de runtime do provedor**: rejeitada porque a versão não
  persistiria no artefato publicado — dependeria da configuração de runtime, o que
  viola CA-7b ("persiste no artefato publicado").
- **Header HTTP**: mais complexo de verificar via curl simples e requer endpoint real
  respondendo. Arquivo estático é mais resiliente.
- **Endpoint `/version` dedicado no Laravel**: cria inconsistência com o Flutter Web
  (que não tem processo backend). Arquivo estático `/version.json` é o mesmo padrão
  para todas as interfaces.

## Como STORY-008 e STORY-009 consomem este padrão

- **STORY-008 (WebApp):** ler `APP_VERSION` via `--dart-define` já disponível no
  ambiente de build para exibir na tela hello world. Arquivo `/version.json` já existe
  (gerado pelo pipeline); não criar outro mecanismo.
- **STORY-009 (Backoffice):** ler `env('APP_VERSION')` para exibir na tela hello world
  e retornar no payload do `/health`. Arquivo `/version.json` em `public/` já existe.

## Convenção de tags

| Padrão         | Dispara               | Ambiente    |
|----------------|-----------------------|-------------|
| `vX.Y.Z-rc.N`  | build + deploy auto   | homolog     |
| `vX.Y.Z`       | build + deploy humano | prod        |

Criação de tag: ato manual de quem libera o release (no commit já mergeado em `main`):

```bash
git tag v0.1.0-rc.1
git push origin v0.1.0-rc.1
```
