<?php

// STORY-053 (CA-6, Path A) — NotificacoesEmailTemplatesSeeder: cria os 5 templates de e-mail
// (categoria `email`) com v1 ativa, idempotente, e o slug 1:1 com NotificacaoTipo.

use App\Enums\NotificacaoTipo;
use App\Models\Template;
use App\Models\User;
use Database\Seeders\NotificacoesEmailTemplatesSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

beforeEach(function () {
    User::factory()->admin()->create();
});

it('cria os 5 templates de e-mail com v1 ativa e categoria email', function () {
    $this->seed(NotificacoesEmailTemplatesSeeder::class);

    foreach (NotificacaoTipo::cases() as $tipo) {
        $template = Template::where('slug', $tipo->templateSlug())->with('versaoAtiva')->first();

        expect($template)->not->toBeNull()
            ->and($template->categoria)->toBe('email')
            ->and($template->versaoAtiva)->not->toBeNull()
            ->and($template->versaoAtiva->versao)->toBe(1)
            ->and($template->versaoAtiva->conteudo)->toContain('---'); // front-matter + corpo
    }

    expect(Template::where('categoria', 'email')->count())->toBe(5);
});

it('é idempotente — rodar 2× não duplica templates nem versões', function () {
    $this->seed(NotificacoesEmailTemplatesSeeder::class);
    $this->seed(NotificacoesEmailTemplatesSeeder::class);

    $slug = NotificacaoTipo::CandidaturaRecebida->templateSlug();

    expect(Template::where('slug', $slug)->count())->toBe(1)
        ->and(Template::where('slug', $slug)->first()->versoes()->count())->toBe(1);
});
