<?php

// STORY-053 (templates 4/5) — notificações ao CONTRATANTE no desfecho da revisão após edição
// material: manter (template 4), retirar voluntária e auto-retirada 24h (template 5, por motivo).
// Não há evento de domínio: nascem nos hooks de RevisarCandidaturaService + AutoRetirarAposEdicaoCommand.

use App\Enums\CandidaturaEstado;
use App\Enums\NotificacaoTipo;
use App\Enums\VagaEstado;
use App\Models\Candidatura;
use App\Models\ContratanteProfile;
use App\Models\Funcao;
use App\Models\Notificacao;
use App\Models\ProfissionalProfile;
use App\Models\Template;
use App\Models\User;
use App\Models\Vaga;
use App\Services\Notificacao\EmailTemplateRenderer;
use Database\Seeders\NotificacoesEmailTemplatesSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

/**
 * Vaga aberta futura em revisão; candidatura do profissional em `pendente_revisao_apos_edicao`.
 *
 * @return array{0:User,1:User,2:Candidatura,3:Vaga} [contratante, profissional, candidatura, vaga]
 */
function cenarioRevisaoNotif(array $candOver = []): array
{
    $func = Funcao::firstOrCreate(['slug' => 'garcom'], ['nome' => 'Garçom', 'ativo' => true]);
    $contratante = User::factory()->contratante()->ativo()->create();
    ContratanteProfile::create([
        'user_id' => $contratante->id, 'nome_estabelecimento' => 'Bar do Zé',
        'tipo_operacao' => 'bar', 'cidade' => 'São Paulo', 'uf' => 'SP',
    ]);
    $prof = User::factory()->profissional()->ativo()->create(['name' => 'Ana Silva']);
    ProfissionalProfile::factory()->create(['user_id' => $prof->id]);

    $vaga = Vaga::factory()->create([
        'contratante_id' => $contratante->id, 'funcao_id' => $func->id,
        'estado' => VagaEstado::Aberta,
        'data_inicio' => now()->addDays(3)->setTime(19, 0),
        'data_fim' => now()->addDays(3)->setTime(23, 0),
        'valor' => 150.00, 'posicoes' => 2, 'versao_atual' => 2,
    ]);
    $cand = Candidatura::factory()->create(array_merge([
        'vaga_id' => $vaga->id, 'profissional_id' => $prof->id,
        'estado' => CandidaturaEstado::PendenteRevisaoAposEdicao,
        'score_no_momento' => 80,
        'revisao_prazo_em' => now()->addHours(20),
    ], $candOver));

    return [$contratante, $prof, $cand, $vaga];
}

test('confirmar após edição cria notificação template 4 (mantida) para o contratante', function () {
    [$contratante, $prof, $cand, $vaga] = cenarioRevisaoNotif();

    $this->actingAs($prof)->postJson("/api/candidaturas/{$cand->id}/confirmar-apos-edicao")->assertOk();

    $notif = Notificacao::where('destinatario_id', $contratante->id)
        ->where('tipo', NotificacaoTipo::VagaEditadaMaterialCandidaturaMantida)->first();

    expect($notif)->not->toBeNull()
        ->and($notif->candidatura_id)->toBe($cand->id)
        ->and($notif->payload['profissional_nome'])->toBe('Ana Silva')
        ->and($notif->payload['vaga_funcao'])->toBe('Garçom')
        ->and($notif->payload['link_painel'])->toContain("/contratante/vagas/{$vaga->id}/candidatos")
        ->and($notif->idempotency_key)->toBe("vaga_editada_material_candidatura_mantida:{$cand->id}:2");
});

test('retirar após edição cria notificação template 5 com motivo voluntaria', function () {
    [$contratante, $prof, $cand] = cenarioRevisaoNotif();

    $this->actingAs($prof)->postJson("/api/candidaturas/{$cand->id}/retirar-apos-edicao")->assertOk();

    $notif = Notificacao::where('destinatario_id', $contratante->id)
        ->where('tipo', NotificacaoTipo::VagaEditadaMaterialCandidaturaRetirada)->first();

    expect($notif)->not->toBeNull()
        ->and($notif->payload['motivo'])->toBe('voluntaria')
        ->and($notif->payload['motivo_texto'])->toContain('optou por não continuar')
        ->and($notif->payload['motivo_texto'])->toContain('Ana Silva');
});

test('auto-retirada 24h cria notificação template 5 com motivo auto_24h', function () {
    [$contratante, $prof, $cand] = cenarioRevisaoNotif(['revisao_prazo_em' => now()->subHour()]);

    $this->artisan('candidaturas:auto-retirar-apos-edicao')->assertSuccessful();

    $cand->refresh();
    expect($cand->estado)->toBe(CandidaturaEstado::RetiradaPorEdicao);

    $notif = Notificacao::where('destinatario_id', $contratante->id)
        ->where('tipo', NotificacaoTipo::VagaEditadaMaterialCandidaturaRetirada)->first();

    expect($notif)->not->toBeNull()
        ->and($notif->payload['motivo'])->toBe('auto_24h')
        ->and($notif->payload['motivo_texto'])->toContain('não respondeu à alteração');
});

test('a notificação da revisão renderiza num e-mail válido (template ativo)', function () {
    // Garante que o corpo semeado interpola sem variável faltante (paridade com o worker, CA-5).
    User::factory()->admin()->create();
    $this->seed(NotificacoesEmailTemplatesSeeder::class);

    [$contratante, $prof, $cand] = cenarioRevisaoNotif();
    $this->actingAs($prof)->postJson("/api/candidaturas/{$cand->id}/confirmar-apos-edicao")->assertOk();

    $notif = Notificacao::where('tipo', NotificacaoTipo::VagaEditadaMaterialCandidaturaMantida)->firstOrFail();
    $versao = Template::where('slug', $notif->tipo->templateSlug())->with('versaoAtiva')->first()->versaoAtiva;

    $conteudo = app(EmailTemplateRenderer::class)
        ->renderizar($versao->conteudo, $notif->payload, $contratante->name);

    expect($conteudo['h1'])->toBe('Candidato mantido após edição')
        ->and($conteudo['paragrafos'][0])->toContain('Ana Silva');
});
