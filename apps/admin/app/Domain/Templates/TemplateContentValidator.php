<?php

namespace App\Domain\Templates;

/**
 * STORY-020 — Validação de conteúdo de template (CA-5).
 *
 * Regra dura (bloqueia o salvamento): todo placeholder `{{namespace.campo}}` precisa
 * pertencer à lista canônica de ADR-010 / `compliance.md §Placeholders esperados`.
 * Regra soft (apenas aviso): convenção de seções nomeadas de STORY-015.
 *
 * Função pura, sem dependência de banco — testável unitariamente e reusável tanto pela
 * UI (feedback ao vivo) quanto pelo TemplateService (gate autoritativo antes do INSERT).
 */
class TemplateContentValidator
{
    /**
     * Lista finita e canônica de placeholders (ADR-010 / compliance.md).
     * `habitualidade.clausula_adicional` é o ponto de injeção da cláusula condicional
     * resolvida pelo chamador no momento do aceite (ADR-010 Decisão 3).
     */
    public const CANONICOS = [
        'contratante.razao_social',
        'contratante.cnpj',
        'contratante.endereco_completo',
        'profissional.nome',
        'profissional.documento',
        'profissional.endereco_completo',
        'turno.funcao',
        'turno.data_inicio',
        'turno.data_fim',
        'turno.valor',
        'turno.taxa_turni',
        'turno.total_contratante',
        'aceite.timestamp',
        'aceite.ip',
        'aceite.fingerprint',
        'habitualidade.override_aceito',
        'habitualidade.clausula_adicional',
    ];

    /** Convenção de seções de STORY-015 — verificada de forma soft (aviso, não bloqueio). */
    private const SECOES_ESPERADAS = ['Termos gerais', 'Termos do turno'];

    /**
     * Extrai todos os placeholders `{{ns.campo}}` presentes no conteúdo, na ordem de aparição
     * (sem duplicatas). Tolera espaços internos: `{{ ns.campo }}`.
     *
     * @return list<string>
     */
    public function placeholders(string $conteudo): array
    {
        preg_match_all('/\{\{\s*([\w.]+)\s*\}\}/', $conteudo, $matches);

        return array_values(array_unique($matches[1]));
    }

    /**
     * Placeholders que NÃO estão na lista canônica (bloqueiam o salvamento — CA-5).
     *
     * @return list<string>
     */
    public function placeholdersDesconhecidos(string $conteudo): array
    {
        return array_values(array_diff($this->placeholders($conteudo), self::CANONICOS));
    }

    /**
     * Seções nomeadas esperadas que estão ausentes (gera aviso soft, não bloqueio).
     *
     * @return list<string>
     */
    public function secoesFaltando(string $conteudo): array
    {
        return array_values(array_filter(
            self::SECOES_ESPERADAS,
            fn (string $secao) => ! str_contains($conteudo, $secao),
        ));
    }
}
