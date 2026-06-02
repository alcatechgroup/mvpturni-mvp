<?php

namespace App\Domain\Feed;

/**
 * STORY-048 (CA-1, CA-4). Filtros fixos do feed do profissional (domain/vaga.md §Filtros).
 * A lista é fixada pelo produto — não se inventa filtro novo aqui (estória §Liberdade técnica).
 *
 *   todas        — todas as vagas visíveis (função primária OU secundária, raio, data futura)
 *   minha_funcao — restringe à função PRIMÁRIA do profissional
 *   alto_match   — só score total ≥ 80 (filtro pós-cálculo, ADR-014)
 *   candidatadas — só vagas em que o profissional tem candidatura ativa (pendente/em revisão)
 */
enum FeedFiltro: string
{
    case Todas = 'todas';
    case MinhaFuncao = 'minha_funcao';
    case AltoMatch = 'alto_match';
    case Candidatadas = 'candidatadas';

    /** Fail-soft: parâmetro ausente/desconhecido recai em "todas" (default do feed). */
    public static function fromParam(?string $value): self
    {
        return self::tryFrom($value ?? '') ?? self::Todas;
    }
}
