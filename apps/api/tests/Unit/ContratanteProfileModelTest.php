<?php

// STORY-024 — Modelo do contratante no completar cadastro: criptografia em repouso do CNPJ
// (CA-6), unicidade via cnpj_hash (CA-3) e casts dos campos estruturados (endereço, contatos
// adicionais, redes sociais). Espelha o que a STORY-023 fez para o profissional.

use App\Models\ContratanteProfile;
use App\Models\User;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;

uses(RefreshDatabase::class);

test('CNPJ do contratante é criptografado em repouso e decripta na leitura (CA-6)', function () {
    $user = User::factory()->contratante()->create();

    $profile = ContratanteProfile::create([
        'user_id' => $user->id,
        'cnpj_encrypted' => '12345678000190',
        'cnpj_hash' => hash_hmac('sha256', '12345678000190', (string) config('app.key')),
    ]);

    // Leitura pelo Eloquent decripta de volta ao valor em claro.
    expect($profile->fresh()->cnpj_encrypted)->toBe('12345678000190');

    // Query direta no Postgres NÃO retorna o CNPJ em claro (ciphertext Laravel).
    $raw = DB::table('contratante_profiles')->where('user_id', $user->id)->value('cnpj_encrypted');
    expect($raw)->not->toContain('12345678000190');
    expect($raw)->toStartWith('eyJpdiI6'); // base64 do envelope {"iv":...} do encrypter do Laravel
});

test('cnpj_hash é único entre contratantes (CA-3)', function () {
    $hash = hash_hmac('sha256', '12345678000190', (string) config('app.key'));

    ContratanteProfile::create([
        'user_id' => User::factory()->contratante()->create()->id,
        'cnpj_encrypted' => '12345678000190',
        'cnpj_hash' => $hash,
    ]);

    expect(fn () => ContratanteProfile::create([
        'user_id' => User::factory()->contratante()->create()->id,
        'cnpj_encrypted' => '12345678000190',
        'cnpj_hash' => $hash,
    ]))->toThrow(QueryException::class);
});

test('campos estruturados do contratante fazem round-trip (endereço, contatos, redes)', function () {
    $user = User::factory()->contratante()->create();

    $profile = ContratanteProfile::create([
        'user_id' => $user->id,
        'logradouro' => 'Rua das Flores',
        'numero' => '100',
        'bairro' => 'Centro',
        'cidade' => 'São Paulo',
        'uf' => 'SP',
        'cep' => '01001-000',
        'complemento' => 'Sala 2',
        'endereco_completo' => 'Rua das Flores, 100 — Centro, São Paulo/SP',
        'apelido_estabelecimento' => 'Flores',
        'segmento' => 'Restaurante italiano',
        'ano_fundacao' => 2015,
        'qtd_funcionarios' => '11-50',
        'turnos_operacao' => 'Almoço e jantar',
        'cultura_valores' => 'Hospitalidade acima de tudo',
        'site' => 'https://flores.example',
        'redes_sociais' => ['instagram' => 'https://instagram.com/flores'],
        'contatos_adicionais' => [
            ['nome' => 'Ana', 'funcao' => 'Gerente', 'telefone' => '11999990000'],
        ],
    ]);

    $reloaded = $profile->fresh();

    expect($reloaded->ano_fundacao)->toBe(2015);
    expect($reloaded->redes_sociais)->toBe(['instagram' => 'https://instagram.com/flores']);
    expect($reloaded->contatos_adicionais)->toBe([
        ['nome' => 'Ana', 'funcao' => 'Gerente', 'telefone' => '11999990000'],
    ]);
    expect($reloaded->uf)->toBe('SP');
});

test('lat/lng do estabelecimento existem, são nulos por padrão e fazem round-trip (STORY-074)', function () {
    $user = User::factory()->contratante()->create();

    // Por padrão (sem geocoding ainda) as coordenadas são nulas — comportamento atual preservado.
    $semGeo = ContratanteProfile::create(['user_id' => $user->id]);
    expect($semGeo->fresh()->lat)->toBeNull();
    expect($semGeo->fresh()->lng)->toBeNull();

    // Quando populadas (futuro), persistem com a precisão da geo (decimal:7).
    $semGeo->update(['lat' => -23.5505199, 'lng' => -46.6333094]);
    $reloaded = $semGeo->fresh();
    expect((float) $reloaded->lat)->toBe(-23.5505199);
    expect((float) $reloaded->lng)->toBe(-46.6333094);
});
