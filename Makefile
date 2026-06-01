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
# Harness same-origin do integration_test no Web (flutter drive) — STORY-043/IDR-021.
# Override por env: `make e2e-webapp-integration CHROMEDRIVER_PORT=4445 E2E_PROXY_PORT=3000`.
#   CHROMEDRIVER_PORT — porta do chromedriver.
#   E2E_PROXY_PORT    — origem única que o browser abre; DEVE ser stateful no Sanctum
#                       (localhost:3000 já está no default de SANCTUM_STATEFUL_DOMAINS).
#   E2E_APP_PORT      — porta do dev-server do flutter drive (--web-port).
#   E2E_HEADLESS      — 1 (default, gate) roda Chrome headless; 0 abre o browser VISÍVEL
#                       (debug): `make e2e-webapp-integration E2E_HEADLESS=0`.
CHROMEDRIVER_PORT ?= 4444
E2E_PROXY_PORT ?= 3000
E2E_APP_PORT ?= 7357
E2E_HEADLESS ?= 1
# Flag --headless só quando E2E_HEADLESS != 0 (vazio = browser visível).
E2E_HEADLESS_FLAG := $(if $(filter 0,$(E2E_HEADLESS)),,--headless)

.DEFAULT_GOAL := help
.PHONY: help setup up down clean logs ps env build install key migrate seed \
        webapp-build hooks test test-api test-admin test-webapp lint fresh \
        e2e e2e-webapp e2e-webapp-integration e2e-webapp-smoke \
        e2e-webapp-app-update e2e-admin

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

e2e: ## E2E local completo (gate antes de tag rc.N — IDR-004): WebApp (híbrido) + Backoffice
	$(MAKE) e2e-webapp
	$(MAKE) e2e-admin

_e2e-seed: # Garante migrações + usuários de teste do CA-13 no banco de dev
	$(DC) exec -T api php artisan migrate --force
	$(DC) exec -T api php artisan db:seed --force

# E2E híbrido do WebApp (IDR-010): integration_test (UI Flutter) + smoke HTTP (Playwright).
# Ordem: build fresco (IDR-006 §c) → seed → integration_test → smoke. Sai !=0 no 1º fail.
e2e-webapp: webapp-build ## E2E híbrido do WebApp: integration_test (UI) + smoke Playwright (IDR-010)
	$(MAKE) e2e-webapp-integration
	$(MAKE) e2e-webapp-smoke

# Iteração em dev: cenários de UI em integration_test (Chrome headless via flutter drive),
# rodando SAME-ORIGIN (STORY-043 / IDR-021). No Web, integration_test exige `flutter drive` +
# chromedriver com MAJOR igual ao do Chrome local (ver README §"Testes E2E"). O dev-server do
# flutter drive (E2E_APP_PORT) fica numa origem diferente da API — o que mataria o cookie Sanctum
# em chamadas autenticadas pós-login. Por isso subimos um PROXY reverso (scripts/e2e-webapp-proxy.js)
# numa origem única (E2E_PROXY_PORT, stateful no Sanctum) que roteia /api+/sanctum → API e o resto →
# dev-server, e apontamos o browser para o proxy via `--web-launch-url`. App e API ficam same-origin,
# como em produção (IDR-014) — sem --dart-define, sem CORS, sem withCredentials, sem tocar produção.
# Pré-condição: stack no ar (`make up`). O target RE-SEMEIA antes de rodar (CA-5): o cenário de
# welcome muta welcome_visto, então cada execução precisa do usuário recém-semeado (welcome_seen_at
# null) — por isso o seed é parte do target e não só do `make e2e-webapp` (determinismo standalone).
e2e-webapp-integration: ## integration_test (UI) do WebApp no Chrome headless, same-origin — IDR-010/011/021
	@command -v flutter >/dev/null 2>&1 || { echo "ERRO: Flutter ausente no PATH"; exit 1; }
	@command -v chromedriver >/dev/null 2>&1 || { echo "ERRO: chromedriver ausente. Instale um chromedriver com MAJOR == seu Chrome (README §Testes E2E)."; exit 1; }
	@command -v node >/dev/null 2>&1 || { echo "ERRO: node ausente no PATH (proxy same-origin)"; exit 1; }
	@curl -sS -o /dev/null http://localhost:$${API_PORT:-8001} || { echo "ERRO: API não responde em :$${API_PORT:-8001}. Rode 'make up' antes."; exit 1; }
	$(MAKE) _e2e-seed
	chromedriver --port=$(CHROMEDRIVER_PORT) >/tmp/turni-chromedriver.log 2>&1 & \
	  CD_PID=$$!; \
	  PROXY_PORT=$(E2E_PROXY_PORT) APP_PORT=$(E2E_APP_PORT) API_PORT=$${API_PORT:-8001} \
	    node scripts/e2e-webapp-proxy.js >/tmp/turni-e2e-proxy.log 2>&1 & \
	  PROXY_PID=$$!; \
	  trap 'kill $$CD_PID $$PROXY_PID 2>/dev/null' EXIT INT TERM; \
	  for i in $$(seq 1 20); do curl -fsS http://localhost:$(CHROMEDRIVER_PORT)/status >/dev/null 2>&1 && break; sleep 0.5; done; \
	  for i in $$(seq 1 20); do curl -sS -o /dev/null http://localhost:$(E2E_PROXY_PORT)/ 2>/dev/null && break; sleep 0.3; done; \
	  cd apps/webapp && flutter drive --driver=test_driver/integration_test.dart \
	    --target=integration_test/web_test.dart \
	    -d web-server --browser-name=chrome $(E2E_HEADLESS_FLAG) \
	    --web-hostname=127.0.0.1 --web-port=$(E2E_APP_PORT) \
	    --web-launch-url=http://localhost:$(E2E_PROXY_PORT)

# Smoke HTTP do WebApp em Playwright (IDR-010): SÓ webapp-hello-world.spec.ts — título,
# /version.json, /health (homolog), console limpo, deep link /login. É a única camada que
# bate no build servido em :8003. Determinístico (não interage com widgets via semantics).
e2e-webapp-smoke: ## smoke HTTP do WebApp (Playwright) contra localhost:8003 — IDR-010
	@command -v npx >/dev/null 2>&1 || { echo "ERRO: npx ausente no PATH (instale Node 22)"; exit 1; }
	@curl -fsS -o /dev/null http://localhost:$${WEBAPP_PORT:-8003} || { echo "ERRO: WebApp não responde em :$${WEBAPP_PORT:-8003}. Rode 'make up' antes."; exit 1; }
	cd apps/webapp && (test -d node_modules || npm ci) \
	  && (test -d node_modules/playwright-core/.local-browsers || npx playwright install chromium --with-deps) \
	  && npx playwright test webapp-hello-world.spec.ts

# app-update: comportamento WEB-PLATFORM (service worker, polling de /version.json,
# page.route mock, skipWaiting+reload) — NÃO migra para integration_test (STORY-043 CA-7).
# Fica em Playwright, em target próprio NÃO-gating: o banner de nova versão só dispara
# contra um build com tag real (IDR-017 desabilita a checagem em dev, version='dev'):
#   BASE_URL=https://app.homolog.turni.com.br make e2e-webapp-app-update
# (welcome e as validações de pré-cadastro migraram para integration_test na STORY-043 —
# o antigo `e2e-webapp-playwright-legacy` foi removido junto com os specs flaky de semantics.)
e2e-webapp-app-update: ## smoke web-platform de auto-update (Playwright, NÃO-gating) — IDR-017/STORY-043
	@command -v npx >/dev/null 2>&1 || { echo "ERRO: npx ausente no PATH (instale Node 22)"; exit 1; }
	@curl -fsS -o /dev/null http://localhost:$${WEBAPP_PORT:-8003} || { echo "ERRO: WebApp não responde em :$${WEBAPP_PORT:-8003}. Rode 'make up' antes."; exit 1; }
	cd apps/webapp && (test -d node_modules || npm ci) \
	  && (test -d node_modules/playwright-core/.local-browsers || npx playwright install chromium --with-deps) \
	  && npx playwright test app-update.spec.ts

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
