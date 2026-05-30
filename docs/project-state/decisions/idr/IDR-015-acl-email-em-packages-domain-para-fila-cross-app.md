---
idr_id: IDR-015
slug: acl-email-em-packages-domain-para-fila-cross-app
title: ACL de e-mail transacional em packages/domain (Turni\Domain\Email) — habilita a fila database cross-app
status: accepted
decided_at: 2026-05-30
decided_by: programador
owner_agent: "Programador (claude-opus-4-8)"
related_story: STORY-021
related_adrs: [ADR-011, ADR-002, ADR-005]
related_idrs: [IDR-013]
supersedes: null
superseded_by: null
created_at: 2026-05-30
updated_at: 2026-05-30
---

# IDR-015 — ACL de e-mail transacional em `packages/domain` (`Turni\Domain\Email`)

## Contexto

STORY-019 (IDR-013) criou o seam de e-mail — interface `EnviaEmailTransacional`, VO `EmailTransacional`, enum `TipoEmail`, adapter log-only e `EnviarEmailTransacionalJob` — **dentro do app `admin`** (`App\Domain\Email\*`, `App\Jobs\*`), como placeholder até esta estória. A aprovação (`aprovacao_concedida`) é despachada de lá, na fila `database` (ADR-002), com `->onConnection('database')`.

Ao implementar a entrega real (STORY-021), encontrei a restrição que decide a localização: **a fila é cross-app**. O serviço `worker` do `docker-compose.yml` roda `php artisan queue:work` no **contexto do app `api`** (`env_file: ./apps/api/.env`, monta `packages/domain`), sobre o **mesmo Postgres** que o `admin` usa. Quando o `admin` enfileira um job, o payload serializado guarda o **FQCN** da classe; o worker (api) precisa instanciar exatamente esse FQCN para processar. Com o Job em `App\Jobs\EnviarEmailTransacionalJob` existindo **só no admin**, o worker do api não consegue reconstruí-lo — o e-mail de aprovação nunca seria entregue (CA-4). Além disso, o reset de senha (Fortify) e o job de lembrete rodam no `api`, que também precisa da mesma ACL. ADR-011 §b delega explicitamente ao Programador a localização exata da interface ("`packages/domain` ou equivalente — decisão do Programador na STORY-021, IDR").

## Decisão

> **Decidi mover a ACL de e-mail transacional para `packages/domain`, sob o namespace `Turni\Domain\Email\`**, consumida in-process por `api` **e** `admin` (path-repo Composer já existente).

Movidos para `packages/domain/src/Email/`: `EmailTransacional` (VO), `EnviaEmailTransacional` (interface), `TipoEmail` (enum), `LogEnviaEmailTransacional` (adapter log), `EnviarEmailTransacionalJob` (job da fila) e a nova `EmailTransacionalException` (exceção de domínio, ADR-011 §g). O adapter concreto **Resend** e os Mailables/templates Blade ficam em **cada app** (são detalhe de entrega, dependem do `Mail` do Laravel de cada app), mas implementam a interface compartilhada. Cada app registra seu binding em `AppServiceProvider`.

## Por quê

- **Correção, não estética:** sem FQCN compartilhado a fila cross-app não deserializa — é pré-requisito de CA-4, não refino.
- **Satisfaz CA-1 literalmente:** "interface `SendTransactionalEmail` (ou equivalente) em `packages/domain`".
- **Coerente com ADR-005 / `integration-architecture.md`:** o contrato da ACL é vocabulário de **domínio** (`TipoEmail::AprovacaoConcedida`), naturalmente compartilhado; o que é específico de provedor (adapter Resend) e de entrega (Mailable/Blade) fica fora do domínio, em cada app.
- **`packages/domain` já é o lar compartilhado** (path-repo consumido por ambos os apps) e estava vazio aguardando o EPIC-001 — esta é a primeira modelagem de domínio compartilhada real.

## Alternativas consideradas

- **Alternativa A — duplicar o Job/ACL nos dois apps com mesmo FQCN sob `App\`:** rejeitada — duas cópias do mesmo contrato divergem com o tempo, e `App\` é namespace de aplicação (não compartilhável sem gambiarra de autoload cruzado). DRY de intenção real.
- **Alternativa B — manter tudo no `admin` e dar ao `admin` seu próprio worker:** rejeitada — multiplica workers/infra (contra ADR-002 que centraliza na fila `database` única), e ainda assim o `api` (Fortify reset, lembrete) precisaria da ACL. Não resolve, só adia.
- **Alternativa C — envio síncrono no request (sem fila):** rejeitada — viola ADR-011 §g (nunca síncrono no request HTTP).

## Consequências

### Para outros agentes
- **Toda nova mensagem transacional** usa `Turni\Domain\Email\*`. O adapter de provedor e os Mailables ficam **no app** que envia; a interface/VO/enum/Job/exceção ficam **no domínio**.
- Jobs destinados ao worker do `api` **devem** ter FQCN resolvível pelo `api` — na prática, morar em `packages/domain` (`Turni\Domain\`) ou ser duplicados intencionalmente. Padrão para futuros jobs cross-app.
- O binding `EnviaEmailTransacional::class → ResendAdapter` é registrado **por app** no `AppServiceProvider`; em dev o adapter usa o `Mail` apontando para Mailpit via `.env` (sem troca de classe — ADR-011 §c).

### Para o projeto
- `packages/domain` deixa de ser stub: ganha `src/Email/*` e dependências de teste próprias.
- Imports em `admin` (`ApprovalService`, `AppServiceProvider`, testes da STORY-019) passam de `App\Domain\Email\*` / `App\Jobs\*` para `Turni\Domain\Email\*` — refactor mecânico coberto pela suíte existente.

### Trade-offs aceitos
- `packages/domain` passa a depender de contratos do Laravel (`ShouldQueue`, `Queueable`) para o Job. Aceito: ADR-002/ADR-003 já definem `turni/domain` como "Eloquent + regras", consumido in-process pelos apps Laravel — não é um domínio framework-agnóstico puro, e o Job é parte legítima do contrato de despacho.

## Como verificar

- `grep -r "App\\\\Domain\\\\Email" apps/` não retorna nada (tudo migrado para `Turni\Domain\Email`).
- A suíte do `admin` (STORY-019: `ApprovalServiceTest`, `FilaAprovacaoTest`) continua verde após o refactor.
- Em dev: aprovar no Backoffice → job na tabela `jobs` → worker (api) processa → e-mail aparece no Mailpit (`localhost:8025`). Prova a fila cross-app de ponta a ponta.
- `packages/domain/src/Email/` **não** importa nenhuma classe `Resend\*` (o domínio é agnóstico de provedor — ADR-011 plano de verificação).
