<?php

// STORY-053 — listeners dos 3 eventos de domínio → tabela `notificacoes` (CA-2/3/4).
// Cobre: payload por tipo, destinatário correto, audit `notificacao.criada`, idempotência,
// N-por-candidato (edição/cancelamento). Os eventos são despachados de verdade (sem Event::fake)
// para exercitar os listeners registrados no AppServiceProvider.

use App\Enums\CandidaturaEstado;
use App\Enums\NotificacaoTipo;
use App\Events\CandidaturaEnviada;
use App\Events\VagaCancelada;
use App\Events\VagaEditadaMaterialmente;
use App\Models\AuditLog;
use App\Models\Candidatura;
use App\Models\Funcao;
use App\Models\Notificacao;
use App\Models\User;
use App\Models\Vaga;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;

uses(RefreshDatabase::class);

function vagaComFuncao(string $nomeFuncao = 'Garçom', array $over = []): Vaga
{
    $funcao = Funcao::factory()->create(['nome' => $nomeFuncao]);

    return Vaga::factory()->create(array_merge([
        'funcao_id' => $funcao->id,
        // Hora fixada em BRT: a formatação (DataHora) converte UTC→America/Sao_Paulo.
        'data_inicio' => Carbon::parse('2026-07-01 18:00', 'America/Sao_Paulo'),
        'data_fim' => Carbon::parse('2026-07-01 23:00', 'America/Sao_Paulo'),
    ], $over));
}

function candPendente(Vaga $vaga, array $over = []): Candidatura
{
    $prof = User::factory()->profissional()->ativo()->create();

    return Candidatura::factory()->create(array_merge([
        'vaga_id' => $vaga->id,
        'profissional_id' => $prof->id,
        'estado' => CandidaturaEstado::Pendente,
        'score_no_momento' => 92,
    ], $over));
}

it('cria notificação para o contratante quando o profissional candidata (CA-2)', function () {
    $vaga = vagaComFuncao('Garçom');
    $cand = candPendente($vaga);

    CandidaturaEnviada::dispatch($cand);

    expect(Notificacao::count())->toBe(1);

    $n = Notificacao::first();
    expect($n->tipo)->toBe(NotificacaoTipo::CandidaturaRecebida)
        ->and($n->destinatario_id)->toBe($vaga->contratante_id)
        ->and($n->vaga_id)->toBe($vaga->id)
        ->and($n->candidatura_id)->toBe($cand->id)
        ->and($n->lida_em)->toBeNull()
        ->and($n->enviada_email_em)->toBeNull()
        ->and($n->payload['profissional_nome'])->toBe($cand->profissional->name)
        ->and($n->payload['profissional_score'])->toBe(92)
        ->and($n->payload['vaga_funcao'])->toBe('Garçom')
        // Data local pt-BR 24h (DDR-002): dd/mm/aaaa HH:mm — sem AM/PM.
        ->and($n->payload['vaga_data_inicio'])->toMatch('/^\d{2}\/\d{2}\/\d{4} \d{2}:\d{2}$/')
        ->and($n->payload['link_painel'])->toContain("/contratante/vagas/{$vaga->id}/candidatos");

    expect(AuditLog::where('action', 'notificacao.criada')->count())->toBe(1);
});

it('não duplica notificação no mesmo evento (idempotência)', function () {
    $vaga = vagaComFuncao();
    $cand = candPendente($vaga);

    CandidaturaEnviada::dispatch($cand);
    CandidaturaEnviada::dispatch($cand);

    expect(Notificacao::count())->toBe(1)
        ->and(AuditLog::where('action', 'notificacao.criada')->count())->toBe(1);
});

it('não vaza CPF nem telefone no payload de candidatura recebida (CA-10)', function () {
    $vaga = vagaComFuncao();
    $cand = candPendente($vaga);

    CandidaturaEnviada::dispatch($cand);

    $json = json_encode(Notificacao::first()->payload);
    expect($json)->not->toContain('cpf')->not->toContain('telefone');
});

it('cria uma notificação por candidato pendente no cancelamento (CA-4)', function () {
    $vaga = vagaComFuncao('Cozinheiro');
    $c1 = candPendente($vaga);
    $c2 = candPendente($vaga);
    // Uma candidatura já retirada não deve ser notificada.
    candPendente($vaga, ['estado' => CandidaturaEstado::Retirada]);

    VagaCancelada::dispatch($vaga, 2);

    $notifs = Notificacao::where('tipo', NotificacaoTipo::VagaCancelada)->get();
    expect($notifs)->toHaveCount(2)
        ->and($notifs->pluck('destinatario_id')->sort()->values()->all())
        ->toBe(collect([$c1->profissional_id, $c2->profissional_id])->sort()->values()->all());

    $n = $notifs->first();
    expect($n->payload['vaga_funcao'])->toBe('Cozinheiro')
        ->and($n->payload['link_feed'])->toContain('/feed');
});

it('cria notificação com diff formatado por candidato na edição material (CA-3)', function () {
    $vaga = vagaComFuncao('Recepcionista');
    $cand = candPendente($vaga, [
        'estado' => CandidaturaEstado::PendenteRevisaoAposEdicao,
        'revisao_prazo_em' => now()->addHours(24),
    ]);

    $diff = [[
        'campo' => 'data_inicio', 'label' => 'Início', 'tipo' => 'data',
        'antes' => Carbon::parse('2026-07-01 18:00', 'America/Sao_Paulo')->toIso8601String(),
        'depois' => Carbon::parse('2026-07-01 20:00', 'America/Sao_Paulo')->toIso8601String(),
    ]];

    VagaEditadaMaterialmente::dispatch($vaga, $diff, [$cand->id]);

    $n = Notificacao::where('tipo', NotificacaoTipo::VagaEditadaMaterial)->first();
    expect($n)->not->toBeNull()
        ->and($n->destinatario_id)->toBe($cand->profissional_id)
        ->and($n->payload['vaga_funcao'])->toBe('Recepcionista')
        ->and($n->payload['diff_texto'])->toContain('Início:')
        ->and($n->payload['diff_texto'])->toContain('→')
        ->and($n->payload['diff_texto'])->toMatch('/\d{2}\/\d{2}\/\d{4} \d{2}:\d{2} → \d{2}\/\d{2}\/\d{4} \d{2}:\d{2}/')
        ->and($n->payload['prazo_em'])->not->toBeNull()
        ->and($n->payload['link_detalhe'])->toContain("/vaga/{$vaga->id}");
});

it('a notificação é desfeita se a transação que a originou der rollback', function () {
    $vaga = vagaComFuncao();
    $cand = candPendente($vaga);

    try {
        DB::transaction(function () use ($cand) {
            CandidaturaEnviada::dispatch($cand);
            throw new RuntimeException('rollback');
        });
    } catch (RuntimeException) {
        // esperado
    }

    expect(Notificacao::count())->toBe(0);
});
