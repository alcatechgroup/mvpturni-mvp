# Imagem PHP compartilhada pelos apps Laravel (api, admin) e pelo worker.
# Base alinhada ao ADR-001 (alvo PHP 8.5). Um único Dockerfile parametrizado
# pela pasta do app (APP_DIR) — api e admin são apps Laravel finos sobre o
# mesmo domínio (packages/domain), então compartilham runtime.
FROM php:8.5-cli-alpine

# Ferramentas de runtime: git + unzip são exigidas pelo Composer para extrair
# pacotes dist de forma confiável (sem elas, alguns pacotes falham na extração).
RUN apk add --no-cache git unzip

# Extensões PHP exigidas pela stack:
# - pdo_pgsql: Eloquent sobre PostgreSQL (ADR-000)
# - pcntl: tratamento de sinais do `queue:work` (worker, ADR-002)
RUN apk add --no-cache --virtual .build-deps $PHPIZE_DEPS postgresql-dev \
    && docker-php-ext-install -j"$(nproc)" pdo_pgsql pcntl \
    # PCOV: driver de cobertura leve (CA-6 exige medição de cobertura no pré-push)
    && pecl install pcov \
    && docker-php-ext-enable pcov \
    && apk del .build-deps \
    && apk add --no-cache postgresql-libs

# pcov instrumenta apenas a sua "directory"; o default auto-detecta /app/app e
# deixaria database/seeders de fora da cobertura. Apontamos para a raiz do app.
RUN echo 'pcov.directory=/app' > /usr/local/etc/php/conf.d/zz-pcov-directory.ini

# Composer (copiado da imagem oficial — sem instalar globalmente na mão)
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

ENV COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_NO_INTERACTION=1

WORKDIR /app

# APP_DIR aponta para apps/api ou apps/admin no compose. O código é montado
# por volume em dev (hot reload); em build de produção (STORY-007) será COPY.
EXPOSE 8000

CMD ["php", "-S", "0.0.0.0:8000", "-t", "public"]
