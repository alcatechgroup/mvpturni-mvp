<?php

// STORY-020 — núcleo: versionamento sequencial, ativação atômica, validação de placeholder,
// imutabilidade (trigger + partial unique index no Postgres) e audit log (ADR-009).

use App\Exceptions\PlaceholderInvalidoException;
use App\Models\AdminAuditLog;
use App\Models\Template;
use App\Models\TemplateVersao;
use App\Models\User;
use App\Services\TemplateService;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;

uses(RefreshDatabase::class);

function templateService(): TemplateService
{
    return app(TemplateService::class);
}

/**
 * Espera que `$fn` viole uma constraint/trigger do Postgres. Roda dentro de um savepoint
 * (DB::transaction aninhada) para que o erro não envenene a transação do RefreshDatabase —
 * só o savepoint é revertido, e as asserções seguintes continuam consultando o banco.
 */
function esperaErroDeBanco(Closure $fn): void
{
    expect(fn () => DB::transaction($fn))->toThrow(QueryException::class);
}

$valido = "## Termos gerais\n\nNome: {{profissional.nome}}\n\n## Termos do turno específico\n\nValor: {{turno.valor}}";

// ── Criação de versão ───────────────────────────────────────────

test('criarVersao gera a próxima versão sequencial como rascunho', function () use ($valido) {
    $admin = User::factory()->admin()->create();
    $template = Template::factory()->create();
    TemplateVersao::factory()->for($template)->versao(1)->ativa()->create();

    $nova = templateService()->criarVersao($template, $valido, $admin);

    expect($nova->versao)->toBe(2)
        ->and($nova->ativa)->toBeFalse()
        ->and($nova->criado_por_admin_id)->toBe($admin->id);
});

test('criarVersao grava admin.template.version_created no audit log', function () use ($valido) {
    $admin = User::factory()->admin()->create();
    $template = Template::factory()->create(['slug' => 'pf_autonomo_eventual']);

    $nova = templateService()->criarVersao($template, $valido, $admin);

    $log = AdminAuditLog::where('action', 'admin.template.version_created')->sole();
    expect($log->actor_id)->toBe($admin->id)
        ->and($log->target_type)->toBe('TemplateVersao')
        ->and($log->target_id)->toBe($nova->id)
        ->and($log->payload['template_slug'])->toBe('pf_autonomo_eventual')
        ->and($log->payload['versao'])->toBe(1);
});

test('criarVersao bloqueia placeholder fora da lista canônica (CA-5) sem persistir nada', function () {
    $admin = User::factory()->admin()->create();
    $template = Template::factory()->create();

    expect(fn () => templateService()->criarVersao($template, 'Erro: {{contratante.razao_zocial}}', $admin))
        ->toThrow(PlaceholderInvalidoException::class);

    expect(TemplateVersao::count())->toBe(0)
        ->and(AdminAuditLog::where('action', 'admin.template.version_created')->count())->toBe(0);
});

test('criarVersao rejeita conteúdo vazio', function () {
    $admin = User::factory()->admin()->create();
    $template = Template::factory()->create();

    expect(fn () => templateService()->criarVersao($template, "   \n  ", $admin))
        ->toThrow(InvalidArgumentException::class);
});

// ── Ativação ────────────────────────────────────────────────────

test('ativar troca a versão ativa atomicamente (uma só ativa por template — CA-9)', function () {
    $admin = User::factory()->admin()->create();
    $template = Template::factory()->create();
    $v1 = TemplateVersao::factory()->for($template)->versao(1)->ativa()->create();
    $v2 = TemplateVersao::factory()->for($template)->versao(2)->create();

    templateService()->ativar($v2, $admin);

    expect($v1->fresh()->ativa)->toBeFalse()
        ->and($v2->fresh()->ativa)->toBeTrue()
        ->and(TemplateVersao::where('template_id', $template->id)->where('ativa', true)->count())->toBe(1);
});

test('ativar grava admin.template.version_activated no audit log', function () {
    $admin = User::factory()->admin()->create();
    $template = Template::factory()->create(['slug' => 'mei_pj_b2b']);
    TemplateVersao::factory()->for($template)->versao(1)->ativa()->create();
    $v2 = TemplateVersao::factory()->for($template)->versao(2)->create();

    templateService()->ativar($v2, $admin);

    $log = AdminAuditLog::where('action', 'admin.template.version_activated')->sole();
    expect($log->target_id)->toBe($v2->id)
        ->and($log->payload['template_slug'])->toBe('mei_pj_b2b')
        ->and($log->payload['versao'])->toBe(2);
});

test('voltar para versão anterior reativa uma versão histórica (CA-11)', function () {
    $admin = User::factory()->admin()->create();
    $template = Template::factory()->create();
    $v1 = TemplateVersao::factory()->for($template)->versao(1)->create();
    $v2 = TemplateVersao::factory()->for($template)->versao(2)->ativa()->create();

    templateService()->ativar($v1, $admin);

    expect($v1->fresh()->ativa)->toBeTrue()
        ->and($v2->fresh()->ativa)->toBeFalse();
    expect(AdminAuditLog::where('action', 'admin.template.version_activated')->count())->toBe(1);
});

test('ativar é no-op silencioso se a versão já está ativa', function () {
    $admin = User::factory()->admin()->create();
    $template = Template::factory()->create();
    $v1 = TemplateVersao::factory()->for($template)->versao(1)->ativa()->create();

    templateService()->ativar($v1, $admin);

    expect(AdminAuditLog::where('action', 'admin.template.version_activated')->count())->toBe(0);
});

// ── Imutabilidade no banco (CA-10) ──────────────────────────────

test('conteudo de uma versão é imutável após criação (trigger Postgres)', function () {
    $template = Template::factory()->create();
    $v1 = TemplateVersao::factory()->for($template)->versao(1)->ativa()->create();

    esperaErroDeBanco(fn () => $v1->update(['conteudo' => 'editado in-place']));

    expect($v1->fresh()->conteudo)->not->toBe('editado in-place');
});

test('partial unique index impede duas versões ativas no mesmo template', function () {
    $template = Template::factory()->create();
    $admin = User::factory()->admin()->create();
    TemplateVersao::factory()->for($template)->versao(1)->ativa()->create();

    esperaErroDeBanco(fn () => TemplateVersao::create([
        'template_id' => $template->id,
        'versao' => 2,
        'conteudo' => '{{profissional.nome}}',
        'criado_por_admin_id' => $admin->id,
        'ativa' => true,
    ]));

    expect(TemplateVersao::where('template_id', $template->id)->where('ativa', true)->count())->toBe(1);
});
