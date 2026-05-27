# Turni — Backoffice (`apps/admin`)

Backoffice administrativo do Turni (Laravel 13 + Livewire 4, PHP 8.5). Em produção roda em **rede restrita** (ADR-002/ADR-004), com deploy e superfície separados do público. Consome o **mesmo** domínio compartilhado (`packages/domain`) e o **mesmo** PostgreSQL que a `api` — a separação é de entrega, não de domínio.

## Rodar

Use o comando único do monorepo (raiz):

```bash
make setup   # 1ª vez        make up   # subsequente
```

O Backoffice fica em http://localhost:8002.

## Comandos (a partir da raiz do monorepo)

```bash
make test-admin   # Pest: unit + integração contra PostgreSQL real
make lint
docker compose run --rm admin php artisan <cmd>
```

## Notas

- **Banco:** mesmo PostgreSQL da `api` (um único banco, ADR-002).
- **Log:** JSON em stdout (ADR-008).
- Sem login funcional ainda — há um usuário admin de seed (`admin@turni.local`) só para presença (EPIC-001 implementa auth).
- Padrões de fundação: `docs/project-state/decisions/idr/IDR-001`.
