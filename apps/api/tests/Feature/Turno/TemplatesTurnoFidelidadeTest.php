<?php

// STORY-058 (CA-8, ajustado pelo PO em 2026-06-04) — os 2 templates de turno (PF + MEI/PJ) JÁ
// existem como TemplateVersao v1 ativa desde a STORY-020 (categoria `contrato`). Este teste é a
// evidência de fidelidade: o conteúdo ativo no banco é byte a byte o texto-seed vendorado
// (cópia fiel de docs/especificacao/contratos/ — conferida no host, docs/ não monta no container),
// com SHA-256 registrado. Também garante que ambos têm os placeholders de turno (Seção 2).

use App\Models\Template;
use App\Models\User;
use Database\Seeders\TemplatesContratuaisSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

beforeEach(function () {
    User::factory()->admin()->create();
    test()->seed(TemplatesContratuaisSeeder::class);
});

test('CA-8: v1 ativa de cada template de turno é fiel ao texto-seed (SHA-256)', function (string $slug, string $arquivo) {
    $versao = Template::where('slug', $slug)->firstOrFail()->versaoAtiva;
    $seed = trim((string) file_get_contents(database_path('seeders/contracts/'.$arquivo)));

    expect($versao)->not->toBeNull()
        ->and($versao->versao)->toBe(1)
        ->and(hash('sha256', $versao->conteudo))->toBe(hash('sha256', $seed));
})->with([
    ['pf_autonomo_eventual', 'template-pf-autonomo-eventual-v1.md'],
    ['mei_pj_b2b', 'template-mei-pj-b2b-v1.md'],
]);

test('CA-8: templates de turno carregam os placeholders da Seção 2 (turno + contratante)', function (string $slug) {
    $conteudo = Template::where('slug', $slug)->firstOrFail()->versaoAtiva->conteudo;

    foreach ([
        '{{contratante.razao_social}}', '{{contratante.cnpj}}', '{{contratante.endereco_completo}}',
        '{{turno.funcao}}', '{{turno.data_inicio}}', '{{turno.data_fim}}',
        '{{turno.valor}}', '{{turno.taxa_turni}}', '{{turno.total_contratante}}',
        '{{aceite.timestamp}}', '{{aceite.ip}}', '{{aceite.fingerprint}}',
    ] as $placeholder) {
        expect($conteudo)->toContain($placeholder);
    }
})->with(['pf_autonomo_eventual', 'mei_pj_b2b']);

test('CA-8: cláusula condicional de override existe no template MEI/PJ e não no PF', function () {
    $mei = Template::where('slug', 'mei_pj_b2b')->firstOrFail()->versaoAtiva->conteudo;
    $pf = Template::where('slug', 'pf_autonomo_eventual')->firstOrFail()->versaoAtiva->conteudo;

    expect($mei)->toContain('{{habitualidade.override_aceito}}')
        ->and($pf)->not->toContain('{{habitualidade.override_aceito}}'); // PF não tem override (PDR-002)
});
