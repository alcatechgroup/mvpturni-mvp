<?php

// STORY-020 — seeder do catálogo + v1 (CA-12 idempotência, CA-16 fidelidade ao texto-seed).

use App\Domain\Templates\TemplateContentValidator;
use App\Models\Template;
use App\Models\TemplateVersao;
use App\Models\User;
use Database\Seeders\TemplatesContratuaisSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

beforeEach(function () {
    // O seeder exige um admin como autor da v1.
    User::factory()->admin()->create(['email' => 'admin@turni.local']);
});

test('semeia os 2 templates do MVP com a v1 ativa', function () {
    $this->seed(TemplatesContratuaisSeeder::class);

    expect(Template::pluck('slug')->sort()->values()->all())
        ->toBe(['mei_pj_b2b', 'pf_autonomo_eventual']);

    foreach (['pf_autonomo_eventual', 'mei_pj_b2b'] as $slug) {
        $ativa = Template::where('slug', $slug)->first()->versaoAtiva;
        expect($ativa)->not->toBeNull()
            ->and($ativa->versao)->toBe(1)
            ->and($ativa->ativa)->toBeTrue();
    }
});

test('é idempotente: rodar 2× não duplica template nem versão', function () {
    $this->seed(TemplatesContratuaisSeeder::class);
    $this->seed(TemplatesContratuaisSeeder::class);

    expect(Template::count())->toBe(2)
        ->and(TemplateVersao::count())->toBe(2);
});

test('o conteúdo da v1 vem do texto-seed e usa só placeholders canônicos (CA-16)', function () {
    $this->seed(TemplatesContratuaisSeeder::class);

    $pf = Template::where('slug', 'pf_autonomo_eventual')->first()->versaoAtiva->conteudo;
    $arquivo = trim(file_get_contents(database_path('seeders/contracts/template-pf-autonomo-eventual-v1.md')));

    expect($pf)->toBe($arquivo)
        ->and($pf)->toContain('{{profissional.nome}}');

    // Nenhum placeholder fora da lista canônica (o {{namespace.campo}} do frontmatter
    // de STORY-015 foi descartado — só o corpo é semeado).
    $invalidos = (new TemplateContentValidator)->placeholdersDesconhecidos($pf);
    expect($invalidos)->toBe([]);
});
