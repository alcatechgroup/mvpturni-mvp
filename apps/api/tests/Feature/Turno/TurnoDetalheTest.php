<?php

// STORY-060 — GET /api/turnos/{turno}: detalhe compartilhado pelos 2 papéis com RBAC fail-secure
// (CA-1), visibilidade financeira por papel (CA-2 / domain/pagamento.md), timeline filtrada por
// whitelist em ordem descendente com valores por papel (CA-3 / SCREEN-060 §4.1) e aceite
// eletrônico inline para o modal somente-leitura (CA-5).

use App\Enums\TurnoStatus;
use App\Models\AceiteEletronicoTurno;
use App\Models\AuditLog;
use App\Models\Avaliacao;
use App\Models\Turno;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

/**
 * Audit log mínimo apontando para o turno (target Turno, padrão da 058/065/066).
 * `created_at` precisa ir no INSERT (forceCreate): audit_logs é append-only no banco
 * (trigger + REVOKE) — UPDATE levanta exceção.
 */
function auditDoTurno(Turno $turno, string $action, array $payload = [], ?string $em = null): AuditLog
{
    return AuditLog::query()->forceCreate(array_filter([
        'actor_id' => $turno->contratante_id,
        'action' => $action,
        'target_type' => 'Turno',
        'target_id' => $turno->id,
        'payload' => $payload,
        'created_at' => $em,
    ], fn ($v) => $v !== null));
}

// ---------------------------------------------------------------- payload por papel (CA-1/CA-2)

test('profissional vê o próprio turno com valor e estabelecimento — sem taxa/total', function () {
    $turno = Turno::factory()->status(TurnoStatus::Confirmado)->create();
    $pro = $turno->profissional;

    $json = $this->actingAs($pro)->getJson("/api/turnos/{$turno->id}")
        ->assertStatus(200)
        ->json();

    expect($json['id'])->toBe($turno->id)
        ->and($json['funcao'])->toBe($turno->vaga->funcao->nome)
        ->and($json['estado'])->toBe('confirmado')
        ->and($json['data_inicio'])->toBe($turno->data_inicio->toIso8601String())
        ->and($json['data_fim'])->toBe($turno->data_fim->toIso8601String())
        ->and($json['valor'])->toEqual((float) $turno->valor)
        ->and($json['estabelecimento']['nome'])->toBe($turno->contratante->name)
        // PDR-004: o profissional NUNCA vê taxa/total — o payload nem carrega as chaves.
        ->and($json)->not->toHaveKeys(['taxa_turni', 'total_contratante']);
});

test('contratante vê valor, taxa e total separados + nome do profissional (CA-2)', function () {
    $turno = Turno::factory()->status(TurnoStatus::Confirmado)->create();
    $contratante = $turno->contratante;

    $json = $this->actingAs($contratante)->getJson("/api/turnos/{$turno->id}")
        ->assertStatus(200)
        ->json();

    expect($json['valor'])->toEqual((float) $turno->valor)
        ->and($json['taxa_turni'])->toEqual((float) $turno->taxa_turni)
        ->and($json['total_contratante'])->toEqual((float) $turno->total_contratante)
        ->and($json['profissional']['nome'])->toBe($turno->profissional->name)
        ->and($json['estabelecimento']['nome'])->toBe($contratante->name);
});

// ---------------------------------------------------------------- RBAC fail-secure (CA-1)

test('profissional de OUTRO turno → 403 (cruzado)', function () {
    $turno = Turno::factory()->status(TurnoStatus::Confirmado)->create();
    $outroPro = User::factory()->profissional()->ativo()->create();

    $this->actingAs($outroPro)->getJson("/api/turnos/{$turno->id}")->assertStatus(403);
});

test('contratante de OUTRA vaga → 403 (cruzado)', function () {
    $turno = Turno::factory()->status(TurnoStatus::Confirmado)->create();
    $outroContratante = User::factory()->contratante()->ativo()->create();

    $this->actingAs($outroContratante)->getJson("/api/turnos/{$turno->id}")->assertStatus(403);
});

test('não autenticado → 401; uuid inexistente → 404', function () {
    $turno = Turno::factory()->status(TurnoStatus::Confirmado)->create();

    $this->getJson("/api/turnos/{$turno->id}")->assertStatus(401);

    $this->actingAs($turno->profissional)
        ->getJson('/api/turnos/0197a000-0000-7000-8000-000000000000')
        ->assertStatus(404);
});

// ---------------------------------------------------------------- timeline (CA-3)

test('timeline vem em ordem cronológica descendente com eventos do CA-3', function () {
    $turno = Turno::factory()->status(TurnoStatus::Confirmado)->create();
    auditDoTurno($turno, 'turno.criado', [], now()->subMinutes(3)->toDateTimeString());
    auditDoTurno($turno, 'pagamento.pre_autorizado', [], now()->subMinute()->toDateTimeString());
    // aceite_eletronico.emitido tem target próprio e referencia o turno via payload (058).
    AuditLog::query()->forceCreate([
        'actor_id' => $turno->contratante_id,
        'action' => 'aceite_eletronico.emitido',
        'target_type' => 'AceiteEletronicoTurno',
        'target_id' => AceiteEletronicoTurno::factory()->create(['turno_id' => $turno->id])->id,
        'payload' => ['turno_id' => $turno->id],
        'created_at' => now()->subMinutes(2)->toDateTimeString(),
    ]);

    $timeline = $this->actingAs($turno->profissional)
        ->getJson("/api/turnos/{$turno->id}")
        ->json('timeline');

    expect(array_column($timeline, 'evento'))
        ->toBe(['pagamento_pre_autorizado', 'aceite_eletronico_emitido', 'turno_criado'])
        ->and($timeline[0])->toHaveKeys(['id', 'evento', 'ocorrido_em']);
});

test('evento fora da whitelist não aparece (trilha completa é do admin)', function () {
    $turno = Turno::factory()->status(TurnoStatus::Confirmado)->create();
    auditDoTurno($turno, 'turno.criado');
    auditDoTurno($turno, 'pagamento.pre_autorizacao_falhou', ['motivo' => 'cartão recusado']);

    $timeline = $this->actingAs($turno->profissional)
        ->getJson("/api/turnos/{$turno->id}")
        ->json('timeline');

    expect(array_column($timeline, 'evento'))->toBe(['turno_criado']);
});

test('timeline de turno alheio não vaza pelo OR do aceite (payload de outro turno)', function () {
    $meu = Turno::factory()->status(TurnoStatus::Confirmado)->create();
    $alheio = Turno::factory()->status(TurnoStatus::Confirmado)->create();
    AuditLog::create([
        'actor_id' => $alheio->contratante_id,
        'action' => 'aceite_eletronico.emitido',
        'target_type' => 'AceiteEletronicoTurno',
        'target_id' => AceiteEletronicoTurno::factory()->create(['turno_id' => $alheio->id])->id,
        'payload' => ['turno_id' => $alheio->id],
    ]);

    $timeline = $this->actingAs($meu->profissional)
        ->getJson("/api/turnos/{$meu->id}")
        ->json('timeline');

    expect($timeline)->toBe([]);
});

// ------------------------------------------- visibilidade financeira na timeline (SCREEN-060 §4.1)

test('profissional não vê valor em pagamento_pre_autorizado; vê o seu em pix_enviado', function () {
    $turno = Turno::factory()->status(TurnoStatus::Finalizado)->create();
    auditDoTurno($turno, 'pagamento.pre_autorizado', [], now()->subMinutes(2)->toDateTimeString());
    auditDoTurno($turno, 'pix.enviado', [], now()->subMinute()->toDateTimeString());

    $timeline = $this->actingAs($turno->profissional)
        ->getJson("/api/turnos/{$turno->id}")
        ->json('timeline');

    $porEvento = array_column($timeline, null, 'evento');
    expect($porEvento['pix_enviado']['valor'])->toEqual((float) $turno->valor)
        ->and($porEvento['pagamento_pre_autorizado'])->not->toHaveKey('valor');
});

test('contratante vê o total em pagamento_pre_autorizado/capturado; sem valor em pix_enviado', function () {
    $turno = Turno::factory()->status(TurnoStatus::Finalizado)->create();
    auditDoTurno($turno, 'pagamento.pre_autorizado', [], now()->subMinutes(3)->toDateTimeString());
    auditDoTurno($turno, 'pagamento.capturado', [], now()->subMinutes(2)->toDateTimeString());
    auditDoTurno($turno, 'pix.enviado', [], now()->subMinute()->toDateTimeString());

    $timeline = $this->actingAs($turno->contratante)
        ->getJson("/api/turnos/{$turno->id}")
        ->json('timeline');

    $porEvento = array_column($timeline, null, 'evento');
    expect($porEvento['pagamento_pre_autorizado']['valor'])->toEqual((float) $turno->total_contratante)
        ->and($porEvento['pagamento_capturado']['valor'])->toEqual((float) $turno->total_contratante)
        ->and($porEvento['pix_enviado'])->not->toHaveKey('valor');
});

test('cancelado expõe o lado quando o payload o traz (STORY-066)', function () {
    $turno = Turno::factory()->status(TurnoStatus::CanceladoEmp)->create();
    auditDoTurno($turno, 'turno.cancelado', ['lado' => 'emp']);

    $timeline = $this->actingAs($turno->profissional)
        ->getJson("/api/turnos/{$turno->id}")
        ->json('timeline');

    expect($timeline[0]['evento'])->toBe('cancelado')
        ->and($timeline[0]['lado'])->toBe('emp');
});

// ---------------------------------------------------------------- aceite eletrônico (CA-5)

test('aceite vem inline com conteudo_renderizado e emitido_em (modal somente-leitura)', function () {
    $turno = Turno::factory()->status(TurnoStatus::Confirmado)->create();
    $aceite = AceiteEletronicoTurno::factory()->create(['turno_id' => $turno->id]);

    $json = $this->actingAs($turno->profissional)
        ->getJson("/api/turnos/{$turno->id}")
        ->json('aceite');

    expect($json['conteudo_renderizado'])->toBe($aceite->conteudo_renderizado)
        ->and($json['emitido_em'])->toBe($aceite->aceito_em->toIso8601String());
});

test('turno sem aceite (seed antigo): aceite null, tela não quebra', function () {
    $turno = Turno::factory()->status(TurnoStatus::Confirmado)->create();

    $this->actingAs($turno->profissional)
        ->getJson("/api/turnos/{$turno->id}")
        ->assertStatus(200)
        ->assertJsonPath('aceite', null);
});

// ---------------------------------------------------------------- STORY-061 (aditivos do PIN)

test('STORY-061: profissional recebe checkin_janela calculada da config (contratante não)', function () {
    config(['turno.checkin_janela_antes_min' => 30, 'turno.checkin_janela_depois_min' => 120]);
    $turno = Turno::factory()->status(TurnoStatus::Confirmado)->create([
        'data_inicio' => now()->startOfSecond()->addMinutes(15),
        'data_fim' => now()->startOfSecond()->addHours(6),
    ]);

    $json = $this->actingAs($turno->profissional)->getJson("/api/turnos/{$turno->id}")
        ->assertStatus(200)->json();

    expect($json)->toHaveKey('checkin_janela')
        ->and($json['checkin_janela'])->toHaveKeys(['abre_em', 'fecha_em']);
    expect(new DateTimeImmutable($json['checkin_janela']['abre_em']))
        ->toEqual($turno->data_inicio->copy()->subMinutes(30)->toDateTimeImmutable());
    expect(new DateTimeImmutable($json['checkin_janela']['fecha_em']))
        ->toEqual($turno->data_inicio->copy()->addMinutes(120)->toDateTimeImmutable());

    // Contratante não gera PIN — não recebe a janela (payload mínimo por papel).
    $jsonContr = $this->actingAs($turno->contratante->fresh())
        ->getJson("/api/turnos/{$turno->id}")->assertStatus(200)->json();
    expect($jsonContr)->not->toHaveKey('checkin_janela');
});

test('STORY-061: timeline expõe o geofencing do checkin_solicitado para os dois papéis', function () {
    $turno = Turno::factory()->status(TurnoStatus::AguardandoCheckin)->create();
    auditDoTurno($turno, 'turno.checkin_solicitado', [
        'geofencing_check_in' => ['ok' => false, 'distancia_metros' => 230.4, 'razao' => 'fora_do_raio',
            'capturado_em' => now()->toIso8601String()],
        'pin_regerado' => false,
    ]);

    foreach ([$turno->profissional, $turno->contratante->fresh()] as $user) {
        $timeline = $this->actingAs($user)->getJson("/api/turnos/{$turno->id}")
            ->assertStatus(200)->json('timeline');
        $evento = collect($timeline)->firstWhere('evento', 'checkin_solicitado');

        expect($evento)->not->toBeNull()
            ->and($evento['geofencing']['ok'])->toBeFalse()
            ->and($evento['geofencing']['distancia_metros'])->toBe(230.4)
            ->and($evento['geofencing']['razao'])->toBe('fora_do_raio');
    }
});

test('STORY-061: checkin_solicitado antigo sem payload de geofencing não quebra a timeline', function () {
    $turno = Turno::factory()->status(TurnoStatus::AguardandoCheckin)->create();
    auditDoTurno($turno, 'turno.checkin_solicitado'); // seed antigo: payload vazio

    $timeline = $this->actingAs($turno->profissional)->getJson("/api/turnos/{$turno->id}")
        ->assertStatus(200)->json('timeline');
    $evento = collect($timeline)->firstWhere('evento', 'checkin_solicitado');

    expect($evento)->not->toBeNull()->and($evento)->not->toHaveKey('geofencing');
});

test('STORY-061: checkin_cancelado aparece na timeline (whitelist atualizada)', function () {
    $turno = Turno::factory()->status(TurnoStatus::Confirmado)->create();
    auditDoTurno($turno, 'turno.checkin_cancelado');

    $timeline = $this->actingAs($turno->profissional)->getJson("/api/turnos/{$turno->id}")
        ->assertStatus(200)->json('timeline');

    expect(collect($timeline)->pluck('evento'))->toContain('checkin_cancelado');
});

// ---------------------------------------------------------------- STORY-062 (aditivos da validação)

test('STORY-062: contratante recebe geofencing_check_in em aguardando_checkin (card de aviso da SCREEN-062)', function () {
    $turno = Turno::factory()->status(TurnoStatus::AguardandoCheckin)->create([
        'geofencing_check_in' => ['ok' => false, 'distancia_metros' => 350.0,
            'razao' => 'fora_do_raio', 'capturado_em' => now()->toIso8601String()],
    ]);

    $json = $this->actingAs($turno->contratante)->getJson("/api/turnos/{$turno->id}")
        ->assertStatus(200)->json();

    expect($json['geofencing_check_in']['ok'])->toBeFalse()
        ->and($json['geofencing_check_in']['distancia_metros'])->toEqual(350.0)
        ->and($json['geofencing_check_in']['razao'])->toBe('fora_do_raio');
});

test('STORY-062: geofencing_check_in NÃO vaza fora de aguardando_checkin nem para o profissional', function () {
    $snapshot = ['ok' => true, 'distancia_metros' => 23.0, 'razao' => null,
        'capturado_em' => now()->toIso8601String()];

    // Contratante, turno já ativo: o aviso é só do momento da validação.
    $ativo = Turno::factory()->status(TurnoStatus::Ativo)->create(['geofencing_check_in' => $snapshot]);
    $json = $this->actingAs($ativo->contratante)->getJson("/api/turnos/{$ativo->id}")
        ->assertStatus(200)->json();
    expect($json)->not->toHaveKey('geofencing_check_in');

    // Profissional vê a nota na tela do PIN (061) — o detalhe dele não carrega o snapshot.
    $aguardando = Turno::factory()->status(TurnoStatus::AguardandoCheckin)->create(['geofencing_check_in' => $snapshot]);
    $json = $this->actingAs($aguardando->profissional)->getJson("/api/turnos/{$aguardando->id}")
        ->assertStatus(200)->json();
    expect($json)->not->toHaveKey('geofencing_check_in');
});

test('STORY-062: checkin_recusado e checkin_pin_expirado aparecem na timeline (whitelist — SCREEN-062 §4.11)', function () {
    $turno = Turno::factory()->status(TurnoStatus::Confirmado)->create();
    auditDoTurno($turno, 'turno.checkin_recusado', ['motivo' => 'não chegou']);
    auditDoTurno($turno, 'turno.checkin_pin_expirado', ['tentativas' => 3]);

    $timeline = $this->actingAs($turno->profissional)->getJson("/api/turnos/{$turno->id}")
        ->assertStatus(200)->json('timeline');

    expect(collect($timeline)->pluck('evento'))
        ->toContain('checkin_recusado')
        ->toContain('checkin_pin_expirado');

    // O motivo da recusa fica na trilha do admin — NÃO vaza para a timeline das partes.
    $recusado = collect($timeline)->firstWhere('evento', 'checkin_recusado');
    expect(json_encode($recusado))->not->toContain('não chegou');
});

// ------------------------------------------------------- status do Pix (STORY-065 CA-4)

// (a) feliz — Pix confirmado pelo webhook: card mostra "Pix enviado em HH:MM".
test('CA-4 (065): profissional em finalizado COM pix.enviado vê pix{status: enviado, enviado_em}', function () {
    $turno = Turno::factory()->status(TurnoStatus::Finalizado)->create();
    auditDoTurno($turno, 'pix.enviado', ['pagarme_transfer_id' => 'tr_1'], '2026-06-05T18:32:00Z');

    $json = $this->actingAs($turno->profissional)->getJson("/api/turnos/{$turno->id}")
        ->assertStatus(200)->json();

    expect($json['pix']['status'])->toBe('enviado')
        ->and($json['pix']['enviado_em'])->toBe('2026-06-05T18:32:00+00:00');
});

// (a) feliz — entre finalizado e o webhook: "Pix a caminho".
test('CA-4 (065): profissional em finalizado SEM pix.enviado vê pix{status: a_caminho}', function () {
    $turno = Turno::factory()->status(TurnoStatus::Finalizado)->create();

    $json = $this->actingAs($turno->profissional)->getJson("/api/turnos/{$turno->id}")
        ->assertStatus(200)->json();

    expect($json['pix']['status'])->toBe('a_caminho')
        ->and($json['pix']['enviado_em'])->toBeNull();
});

// (b) decisão SCREEN-065 §A.4 — falha de Pix NÃO muda a linha do profissional (PDR-010).
test('CA-4 (065): pix.falhou aparece ao profissional como a_caminho (PDR-010 — tratamento é da operação)', function () {
    $turno = Turno::factory()->status(TurnoStatus::Finalizado)->create();
    auditDoTurno($turno, 'pix.falhou', ['razao' => 'invalid_pix_key — chave não encontrada']);

    $json = $this->actingAs($turno->profissional)->getJson("/api/turnos/{$turno->id}")
        ->assertStatus(200)->json();

    expect($json['pix']['status'])->toBe('a_caminho');
    // A razão da falha NUNCA vaza para as partes (trilha do admin).
    expect(json_encode($json))->not->toContain('invalid_pix_key');
});

// (b) inválido — fora de finalizado não existe pix{} (estado terminal é pré-condição).
test('CA-4 (065): turno fora de finalizado NÃO carrega pix{}', function () {
    $turno = Turno::factory()->status(TurnoStatus::Ativo)->create();

    $json = $this->actingAs($turno->profissional)->getJson("/api/turnos/{$turno->id}")
        ->assertStatus(200)->json();

    expect($json)->not->toHaveKey('pix');
});

// (b) RBAC — contratante não recebe pix{} (visibilidade é do profissional — CA-4).
test('CA-4 (065): contratante em finalizado NÃO recebe pix{}', function () {
    $turno = Turno::factory()->status(TurnoStatus::Finalizado)->create();
    auditDoTurno($turno, 'pix.enviado', [], '2026-06-05T18:32:00Z');

    $json = $this->actingAs($turno->contratante)->getJson("/api/turnos/{$turno->id}")
        ->assertStatus(200)->json();

    expect($json)->not->toHaveKey('pix');
});

// (d) borda — timeline do profissional ganha o pix_enviado com o valor dele (já era da 060;
// garante que a 065, ao emitir o audit de verdade, conversa com o mapa existente).
test('CA-4 (065): timeline do profissional traz pix_enviado com o valor integral', function () {
    $turno = Turno::factory()->status(TurnoStatus::Finalizado)->create([
        'valor' => 200.00, 'taxa_turni' => 30.00, 'total_contratante' => 230.00,
    ]);
    auditDoTurno($turno, 'pix.enviado', ['pagarme_transfer_id' => 'tr_1']);

    $timeline = $this->actingAs($turno->profissional)->getJson("/api/turnos/{$turno->id}")
        ->assertStatus(200)->json('timeline');

    $evento = collect($timeline)->firstWhere('evento', 'pix_enviado');
    expect($evento)->not->toBeNull()
        ->and($evento['valor'])->toEqual(200.0);
});

// ---------------------------------------------------------------- STORY-087 (bloco `avaliacao`)
//
// Aditivo, read-only: o WebApp mostra o CTA "Avaliar turno" só quando a direção do usuário
// está PENDENTE e, pós-envio, o reload reflete `pendente: false` (CA-3/CA-4). Pendência
// derivada do estado (ADR-019 D2) — sem tabela; a mesma fonte das AvaliacoesPendentes*.

// (a) feliz — profissional em finalizado sem avaliação: pendente na direção dele.
test('STORY-087: profissional em finalizado sem avaliação vê avaliacao{pendente:true, direcao}', function () {
    $turno = Turno::factory()->status(TurnoStatus::Finalizado)->create();

    $json = $this->actingAs($turno->profissional)->getJson("/api/turnos/{$turno->id}")
        ->assertStatus(200)->json();

    expect($json['avaliacao']['pendente'])->toBeTrue()
        ->and($json['avaliacao']['direcao'])->toBe('profissional_para_contratante');
});

// (a) feliz — contratante em finalizado sem avaliação: pendente na direção dele.
test('STORY-087: contratante em finalizado sem avaliação vê avaliacao{pendente:true, direcao}', function () {
    $turno = Turno::factory()->status(TurnoStatus::Finalizado)->create();

    $json = $this->actingAs($turno->contratante)->getJson("/api/turnos/{$turno->id}")
        ->assertStatus(200)->json();

    expect($json['avaliacao']['pendente'])->toBeTrue()
        ->and($json['avaliacao']['direcao'])->toBe('contratante_para_profissional');
});

// (a) feliz — CA-4: depois que o profissional avaliou, a direção DELE deixa de estar pendente.
test('STORY-087: profissional que já avaliou vê avaliacao{pendente:false}', function () {
    $turno = Turno::factory()->status(TurnoStatus::Finalizado)->create();
    Avaliacao::factory()->doProfissional()->paraTurno($turno)->create();

    $json = $this->actingAs($turno->profissional)->getJson("/api/turnos/{$turno->id}")
        ->assertStatus(200)->json();

    expect($json['avaliacao']['pendente'])->toBeFalse()
        ->and($json['avaliacao']['direcao'])->toBe('profissional_para_contratante');
});

// (b) borda — direções independentes: a avaliação de um lado não zera a pendência do outro.
test('STORY-087: avaliação do profissional NÃO resolve a pendência do contratante', function () {
    $turno = Turno::factory()->status(TurnoStatus::Finalizado)->create();
    Avaliacao::factory()->doProfissional()->paraTurno($turno)->create();

    $json = $this->actingAs($turno->contratante)->getJson("/api/turnos/{$turno->id}")
        ->assertStatus(200)->json();

    expect($json['avaliacao']['pendente'])->toBeTrue()
        ->and($json['avaliacao']['direcao'])->toBe('contratante_para_profissional');
});

// (b) borda — finalizado_ajustado também é avaliável (ESTADOS_AVALIAVEIS — STORY-085).
test('STORY-087: finalizado_ajustado também carrega o bloco avaliacao', function () {
    $turno = Turno::factory()->status(TurnoStatus::FinalizadoAjustado)->create();

    $json = $this->actingAs($turno->profissional)->getJson("/api/turnos/{$turno->id}")
        ->assertStatus(200)->json();

    expect($json['avaliacao']['pendente'])->toBeTrue();
});

// (b) inválido — fora de finalizado/finalizado_ajustado não existe avaliacao{} (pré-condição).
test('STORY-087: turno fora de estado avaliável NÃO carrega avaliacao{}', function () {
    $turno = Turno::factory()->status(TurnoStatus::Confirmado)->create();

    $json = $this->actingAs($turno->profissional)->getJson("/api/turnos/{$turno->id}")
        ->assertStatus(200)->json();

    expect($json)->not->toHaveKey('avaliacao');
});
