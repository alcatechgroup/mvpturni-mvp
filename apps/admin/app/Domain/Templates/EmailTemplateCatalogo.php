<?php

namespace App\Domain\Templates;

/**
 * STORY-053 (CA-6, Path A) — catálogo dos 5 templates de e-mail de notificação editáveis no
 * Backoffice. Fonte única do que o editor sabe sobre a família `email`:
 *  - `nome` — rótulo amigável (espelha o seeder do `api`);
 *  - `variaveis` — as `{snake_case}` permitidas no corpo (documentadas no editor, CA-6) e usadas
 *    pelo TemplateContentValidator para barrar placeholders fora da lista.
 *
 * As variáveis vêm do `payload` de cada notificação (STORY-053 §"Texto-seed v1"): o worker do `api`
 * (CA-5) interpola o corpo com esse payload. Mantido separado dos placeholders de CONTRATO
 * (`{{ns.campo}}`, TemplateContentValidator::CANONICOS) — famílias e sintaxes distintas.
 */
class EmailTemplateCatalogo
{
    public const CATEGORIA = 'email';

    /** @var array<string,array{nome:string,variaveis:list<string>}> */
    public const TEMPLATES = [
        'candidatura_recebida_email' => [
            'nome' => 'E-mail — Nova candidatura recebida (contratante)',
            'variaveis' => ['profissional_nome', 'profissional_score', 'vaga_id', 'vaga_funcao', 'vaga_data_inicio', 'link_painel'],
        ],
        'vaga_editada_material_email' => [
            'nome' => 'E-mail — Vaga editada (profissional)',
            'variaveis' => ['vaga_id', 'vaga_funcao', 'diff_texto', 'prazo_em', 'link_detalhe'],
        ],
        'vaga_cancelada_email' => [
            'nome' => 'E-mail — Vaga cancelada (profissional)',
            'variaveis' => ['vaga_id', 'vaga_funcao', 'vaga_data_inicio', 'link_feed'],
        ],
        'vaga_editada_material_candidatura_mantida_email' => [
            'nome' => 'E-mail — Candidato mantido após edição (contratante)',
            'variaveis' => ['profissional_nome', 'profissional_score', 'vaga_id', 'vaga_funcao', 'vaga_data_inicio', 'link_painel'],
        ],
        'vaga_editada_material_candidatura_retirada_email' => [
            'nome' => 'E-mail — Candidato saiu após edição (contratante)',
            'variaveis' => ['profissional_nome', 'vaga_id', 'vaga_funcao', 'vaga_data_inicio', 'motivo_texto', 'link_painel'],
        ],
    ];

    public static function isEmailSlug(string $slug): bool
    {
        return array_key_exists($slug, self::TEMPLATES);
    }

    /** Variáveis `{snake_case}` permitidas no template (vazio se não for template de e-mail). */
    public static function variaveis(string $slug): array
    {
        return self::TEMPLATES[$slug]['variaveis'] ?? [];
    }
}
