# Mock do Pagar.me (ADR-005). Nesta estória (STORY-006) só precisa estar DE PÉ —
# rotas funcionais (pré-autorização, captura, Pix, webhook) entram no EPIC-003.
# Reusa a imagem PHP cli alpine (já em cache) para não puxar imagem nova.
FROM php:8.5-cli-alpine
WORKDIR /srv
COPY public /srv/public
EXPOSE 8080
CMD ["php", "-S", "0.0.0.0:8080", "-t", "public"]
