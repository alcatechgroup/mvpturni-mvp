# Turni — comando único de ambiente local (princípio #6 / quality-standards 2.1).
#
#   make setup   → de "acabei de clonar" até tudo rodando com seed (1ª vez, alvo ≤5min)
#   make up      → sobe o que já foi construído (runs subsequentes, ≤1min)
#   make down    → para tudo        make clean → para e apaga volumes (zera o banco)
#   make test    → suíte completa (rodada pelo hook de pré-push)
#   make hooks   → instala o hook de pré-push (git core.hooksPath)
#
# Pré-requisitos: Docker + Docker Compose; Flutter SDK (runtime do WebApp).

SHELL := /bin/bash
DC := docker compose
COMPOSE_RUN := $(DC) run --rm --no-deps

.DEFAULT_GOAL := help
.PHONY: help setup up down clean logs ps env build install key migrate seed \
        webapp-build hooks test test-api test-admin test-webapp lint fresh \
        e2e e2e-webapp e2e-admin

help: ## Mostra os comandos disponíveis
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

setup: ## Sobe o ambiente inteiro do zero (env + build + deps + db + seed + webapp + hooks)
	$(MAKE) env
	$(DC) build
	$(MAKE) install
	$(MAKE) key
	$(DC) up -d postgres
	$(MAKE) _wait-db
	$(MAKE) migrate
	$(MAKE) seed
	$(MAKE) webapp-build
	$(MAKE) hooks
	$(DC) up -d
	@echo ""
	@echo "  Turni de pé:"
	@echo "    API        → http://localhost:$${API_PORT:-8001}"
	@echo "    Backoffice → http://localhost:$${ADMIN_PORT:-8002}"
	@echo "    WebApp     → http://localhost:$${WEBAPP_PORT:-8003}"
	@echo "    Pagar.me mock → http://localhost:$${PAGARME_MOCK_PORT:-8090}"

up: ## Sobe os serviços já construídos
	$(DC) up -d

down: ## Para todos os serviços
	$(DC) down

clean: ## Para tudo e apaga volumes (zera o banco)
	$(DC) down -v

logs: ## Segue os logs de todos os serviços
	$(DC) logs -f

ps: ## Lista o estado dos serviços
	$(DC) ps

env: ## Cria os .env a partir dos .env.example (idempotente)
	@[ -f .env ] || (cp .env.example .env && echo "criado .env (raiz)")
	@[ -f apps/api/.env ] || (cp apps/api/.env.example apps/api/.env && echo "criado apps/api/.env")
	@[ -f apps/admin/.env ] || (cp apps/admin/.env.example apps/admin/.env && echo "criado apps/admin/.env")

build: ## (Re)constrói as imagens
	$(DC) build

install: ## composer install nos apps PHP
	$(COMPOSE_RUN) api composer install --no-interaction --prefer-dist
	$(COMPOSE_RUN) admin composer install --no-interaction --prefer-dist

key: ## Gera APP_KEY onde estiver ausente (idempotente)
	@grep -q '^APP_KEY=base64' apps/api/.env   || $(COMPOSE_RUN) api php artisan key:generate
	@grep -q '^APP_KEY=base64' apps/admin/.env || $(COMPOSE_RUN) admin php artisan key:generate

migrate: ## Aplica migrações (idempotente, forward-only — ADR-004)
	$(COMPOSE_RUN) api php artisan migrate --force

seed: ## Popula dados de seed mínimos (idempotente)
	$(COMPOSE_RUN) api php artisan db:seed --force

fresh: ## Recria o schema do zero e ressemeia (DEV — destrói dados)
	$(COMPOSE_RUN) api php artisan migrate:fresh --seed --force

webapp-build: ## Build do WebApp Flutter (web) no host
	@if command -v flutter >/dev/null 2>&1; then \
	  cd apps/webapp && flutter pub get && flutter build web; \
	else \
	  echo "AVISO: Flutter não encontrado no host — WebApp não será buildado. Instale o Flutter SDK."; \
	fi

hooks: ## Instala o hook de pré-push (versionado em scripts/hooks)
	@git config core.hooksPath scripts/hooks
	@chmod +x scripts/hooks/pre-push
	@echo "hook de pré-push instalado (core.hooksPath=scripts/hooks)"

test: test-api test-admin test-webapp ## Roda a suíte completa (usada pelo pré-push)

# -e DB_DATABASE=turni_test: força o banco de teste no AMBIENTE do container. O env
# var do docker-compose (DB_DATABASE=turni) sobrepõe o <env> do phpunit.xml via
# getenv(), então sem isto o RefreshDatabase apagaria o banco de dev (turni).
test-api: ## Testes do app api (unit + integração contra Postgres + cobertura)
	$(DC) up -d postgres
	$(MAKE) _wait-db
	$(COMPOSE_RUN) -e DB_DATABASE=turni_test api ./vendor/bin/pest --colors=always --coverage --min=80

test-admin: ## Testes do app admin (unit + integração contra Postgres)
	$(DC) up -d postgres
	$(MAKE) _wait-db
	$(COMPOSE_RUN) -e DB_DATABASE=turni_test admin ./vendor/bin/pest --colors=always

test-webapp: ## Testes de widget do WebApp Flutter (no host)
	@if command -v flutter >/dev/null 2>&1; then cd apps/webapp && flutter test; \
	else echo "AVISO: Flutter ausente no host — pulando testes do WebApp."; fi

lint: ## Lint/format (Laravel Pint)
	$(COMPOSE_RUN) api ./vendor/bin/pint --test
	$(COMPOSE_RUN) admin ./vendor/bin/pint --test

e2e: ## E2E Playwright local (gate antes de criar tag rc.N — IDR-004)
	$(MAKE) _e2e-seed
	$(MAKE) e2e-webapp
	$(MAKE) e2e-admin

_e2e-seed: # Garante migrações + usuários de teste do CA-13 no banco de dev
	$(DC) exec -T api php artisan migrate --force
	$(DC) exec -T api php artisan db:seed --force

e2e-webapp: webapp-build ## E2E Playwright do WebApp contra localhost:8003 (rebuilda antes — evita build velho)
	@command -v npx >/dev/null 2>&1 || { echo "ERRO: npx ausente no PATH (instale Node 22)"; exit 1; }
	@curl -fsS -o /dev/null http://localhost:$${WEBAPP_PORT:-8003} || { echo "ERRO: WebApp não responde em :$${WEBAPP_PORT:-8003}. Rode 'make up' antes."; exit 1; }
	cd apps/webapp && (test -d node_modules || npm ci) \
	  && (test -d node_modules/playwright-core/.local-browsers || npx playwright install chromium --with-deps) \
	  && npx playwright test

e2e-admin: ## E2E Playwright do Backoffice contra localhost:8002 (exige `make up`)
	@command -v npx >/dev/null 2>&1 || { echo "ERRO: npx ausente no PATH (instale Node 22)"; exit 1; }
	@curl -fsS -o /dev/null http://localhost:$${ADMIN_PORT:-8002} || { echo "ERRO: Backoffice não responde em :$${ADMIN_PORT:-8002}. Rode 'make up' antes."; exit 1; }
	cd apps/admin && (test -d node_modules || npm ci) \
	  && (test -d node_modules/playwright-core/.local-browsers || npx playwright install chromium --with-deps) \
	  && npx playwright test

_wait-db: # Aguarda o Postgres aceitar conexões
	@echo -n "aguardando Postgres"; \
	for i in $$(seq 1 30); do \
	  if $(DC) exec -T postgres pg_isready -U $${POSTGRES_USER:-turni} -d $${POSTGRES_DB:-turni} >/dev/null 2>&1; then \
	    echo " ok"; exit 0; \
	  fi; \
	  echo -n "."; sleep 1; \
	done; \
	echo " timeout"; exit 1
