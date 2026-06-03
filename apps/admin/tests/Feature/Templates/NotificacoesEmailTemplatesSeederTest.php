<?php

// STORY-053 (CA-6, Path A) — cópia paralela do seeder do `api`: 5 templates de e-mail com v1 ativa,
// idempotente. Roda só contra o DB de teste do admin (memória project-backoffice-db-ownership).

use App\Domain\Templates\EmailTemplateCatalogo;
use App\Models\Template;
use App\Models\TemplateVersao;
use App\Models\User;
use Database\Seeders\NotificacoesEmailTemplatesSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

beforeEach(function () {
    User::factory()->admin()->create(['email' => 'admin@turni.local']);
});

test('semeia os 5 templates de e-mail com v1 ativa e categoria email', function () {
    $this->seed(NotificacoesEmailTemplatesSeeder::class);

    foreach (array_keys(EmailTemplateCatalogo::TEMPLATES) as $slug) {
        $template = Template::where('slug', $slug)->first();
        expect($template)->not->toBeNull()
            ->and($template->categoria)->toBe('email')
            ->and($template->versaoAtiva?->versao)->toBe(1)
            ->and($template->versaoAtiva?->ativa)->toBeTrue();
    }

    expect(Template::where('categoria', 'email')->count())->toBe(5);
});

test('é idempotente: rodar 2× não duplica', function () {
    $this->seed(NotificacoesEmailTemplatesSeeder::class);
    $this->seed(NotificacoesEmailTemplatesSeeder::class);

    expect(Template::where('categoria', 'email')->count())->toBe(5)
        ->and(TemplateVersao::count())->toBe(5);
});
