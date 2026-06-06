<?php

// STORY-073 (CA-3/CA-5) — seeder MANUAL do cenário de verificação ao vivo do scheduler
// em homolog: candidatura em `pendente_revisao_apos_edicao` com prazo real curto
// (vaga começando em ~5 min ⇒ prazo = início do turno, regra PDR-009 "24h OU início,
// o que vier antes"). O cron `candidaturas:auto-retirar-apos-edicao`, agora disparado
// pelo Cloud Run Job de `schedule:run`, retira a candidatura no tick seguinte ao prazo.
// NÃO registrado no DatabaseSeeder (rodaria a cada release re-disparando retirada +
// e-mail): uso via `php artisan db:seed --class=RevisaoAposEdicaoSeeder`.

use App\Enums\CandidaturaEstado;
use App\Enums\VagaEstado;
use App\Models\AuditLog;
use App\Models\Candidatura;
use App\Models\Vaga;
use Database\Seeders\AdminUserSeeder;
use Database\Seeders\FuncaoSeeder;
use Database\Seeders\RevisaoAposEdicaoSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;

uses(RefreshDatabase::class);

/** A vaga marcador do cenário (criada pelo seeder). */
function vagaStory073(): ?Vaga
{
    return Vaga::where('observacoes', RevisaoAposEdicaoSeeder::MARCADOR)->first();
}

beforeEach(function () {
    // O e-mail/notificação da edição material é caminho da STORY-053, não deste seeder.
    Event::fake([\App\Events\VagaEditadaMaterialmente::class]);
    $this->seed(FuncaoSeeder::class);
    $this->seed(AdminUserSeeder::class);
});

// (a) caminho feliz — cenário completo pelo caminho REAL (EditarVagaService).
test('seed cria candidatura em pendente_revisao_apos_edicao com prazo real curto', function () {
    $this->seed(RevisaoAposEdicaoSeeder::class);

    $vaga = vagaStory073();
    expect($vaga)->not->toBeNull()
        ->and($vaga->estado)->toBe(VagaEstado::Aberta)
        ->and($vaga->versao_atual)->toBeGreaterThanOrEqual(2); // edição material criou v2

    $candidatura = Candidatura::where('vaga_id', $vaga->id)->first();
    expect($candidatura)->not->toBeNull()
        ->and($candidatura->estado)->toBe(CandidaturaEstado::PendenteRevisaoAposEdicao)
        ->and($candidatura->revisao_prazo_em)->not->toBeNull()
        // Prazo = início do turno (PDR-009): à frente de agora, mas a no máximo ~10 min.
        ->and($candidatura->revisao_prazo_em->isAfter(now()))->toBeTrue()
        ->and($candidatura->revisao_prazo_em->isBefore(now()->addMinutes(10)))->toBeTrue();

    // Trilha real: a edição material foi auditada como no fluxo do contratante.
    expect(AuditLog::where('action', 'vaga.editada_materialmente')
        ->where('target_id', $vaga->id)->exists())->toBeTrue();
});

// (b) pré-requisito ausente — sem usuários/funções de seed, não cria nada e não lança.
test('seed sem contratante.teste é no-op silencioso', function () {
    Vaga::query()->delete();
    \App\Models\User::query()->delete();

    $this->seed(RevisaoAposEdicaoSeeder::class);

    expect(Vaga::count())->toBe(0)->and(Candidatura::count())->toBe(0);
});

// (c) recuperação de cenário consumido — vaga cancelada por E2E + candidatura já retirada
// pelo cron: re-seed restaura o estado canônico (aberta + em revisão com prazo novo).
test('seed restaura cenário consumido (vaga cancelada, candidatura retirada)', function () {
    $this->seed(RevisaoAposEdicaoSeeder::class);

    $vaga = vagaStory073();
    $candidatura = Candidatura::where('vaga_id', $vaga->id)->first();
    $vaga->forceFill(['estado' => VagaEstado::Cancelada, 'cancelada_em' => now()])->save();
    $candidatura->forceFill([
        'estado' => CandidaturaEstado::RetiradaPorEdicao,
        'revisao_prazo_em' => now()->subHour(),
    ])->save();

    $this->seed(RevisaoAposEdicaoSeeder::class);

    $vaga->refresh();
    $candidatura->refresh();
    expect($vaga->estado)->toBe(VagaEstado::Aberta)
        ->and($candidatura->estado)->toBe(CandidaturaEstado::PendenteRevisaoAposEdicao)
        ->and($candidatura->revisao_prazo_em->isAfter(now()))->toBeTrue();
});

// (d) borda — idempotência: rodar 2× não duplica vaga/candidatura/profissional.
test('seed é idempotente — rodar de novo não duplica', function () {
    $this->seed(RevisaoAposEdicaoSeeder::class);
    $this->seed(RevisaoAposEdicaoSeeder::class);

    $vaga = vagaStory073();
    expect(Vaga::where('observacoes', RevisaoAposEdicaoSeeder::MARCADOR)->count())->toBe(1)
        ->and(Candidatura::where('vaga_id', $vaga->id)->count())->toBe(1)
        ->and(\App\Models\User::where('email', RevisaoAposEdicaoSeeder::EMAIL_CANDIDATO)->count())->toBe(1);
});

// (d) borda/integração — a candidatura seedada é ELEGÍVEL para o cron (CA-5): passado o
// prazo, `candidaturas:auto-retirar-apos-edicao` retira e audita (cenário do validador,
// CA-3 (b) via relógio simulado como a estória permite).
test('cron retira a candidatura seedada após o prazo e audita', function () {
    $this->seed(RevisaoAposEdicaoSeeder::class);
    $vaga = vagaStory073();
    $candidatura = Candidatura::where('vaga_id', $vaga->id)->first();

    // Antes do prazo: tick não retira (não fura o prazo do candidato).
    $this->artisan('candidaturas:auto-retirar-apos-edicao')->assertSuccessful();
    expect($candidatura->refresh()->estado)->toBe(CandidaturaEstado::PendenteRevisaoAposEdicao);

    $this->travel(11)->minutes(); // além do prazo (~5 min) e do início do turno

    $this->artisan('candidaturas:auto-retirar-apos-edicao')->assertSuccessful();

    expect($candidatura->refresh()->estado)->toBe(CandidaturaEstado::RetiradaPorEdicao)
        ->and(AuditLog::where('action', 'candidatura.retirada_por_edicao_auto')
            ->where('target_id', $candidatura->id)->exists())->toBeTrue();
});
