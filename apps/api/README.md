# Turni — API (`apps/api`)

API JSON pública do Turni (Laravel 13, PHP 8.5). Cliente principal: o WebApp Flutter. Recebe o webhook do Pagar.me. Consome o domínio compartilhado (`packages/domain`) via Composer path repository. O `worker` (fila `database`) roda o **mesmo código** desta app. Ver ADR-002 (topologia).

## Rodar

Não rode isolado — use o comando único do monorepo (raiz):

```bash
make setup   # 1ª vez (sobe tudo)        make up   # subsequente
```

A API fica em http://localhost:8001.

## Comandos (a partir da raiz do monorepo)

```bash
make test-api    # Pest: unit + integração contra PostgreSQL real + cobertura (--min=80)
make migrate     # migrações (idempotente)            make seed   # seed do admin (idempotente)
make lint        # Laravel Pint
docker compose run --rm api php artisan <cmd>   # qualquer comando artisan
```

## Notas

- **Banco:** PostgreSQL (ADR-000). Testes de integração usam o banco isolado `turni_test`.
- **Fila:** driver `database` (sem Redis no MVP).
- **Log:** JSON em stdout (`LOG_CHANNEL=stderr` + JsonFormatter — ADR-008).
- **Pagar.me:** `PAGARME_DRIVER=mock` aponta para o container `pagarme-mock` (ADR-005).
- Sem `/health` ainda (STORY-008); sem tabelas de domínio ainda (EPIC-001).
- Padrões de fundação: `docs/project-state/decisions/idr/IDR-001`.
