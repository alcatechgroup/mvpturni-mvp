<?php

// STORY-069 — CA-2 — Override de `personal_access_tokens.tokenable_id` (Sanctum)
// para `uuidMorphs`, com um User de PK UUID (ADR-018, Decisão 4).
//
// Prova empírica de que, ao trocar `morphs('tokenable')` por
// `uuidMorphs('tokenable')`, o Sanctum:
//   (a) persiste o tokenable_id como `uuid` nativo do Postgres;
//   (b) emite token via createToken();
//   (c) resolve o tokenable de volta via findToken()/morphTo para o User UUID.
//
// O teste é auto-contido: cria tabelas temporárias (ca2_users e uma versão
// uuidMorphs de personal_access_tokens), exercita o fluxo e derruba tudo no
// final — não depende das migrations reais (que ainda são bigint até STORY-070).

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Laravel\Sanctum\HasApiTokens;
use Laravel\Sanctum\PersonalAccessToken;
use Laravel\Sanctum\Sanctum;

/** User temporário de PK UUID — o que o User real vira na STORY-070. */
class _Ca2UuidUser extends Authenticatable
{
    use HasApiTokens, HasUuids;

    protected $table = 'ca2_users';

    protected $guarded = [];

    public $timestamps = true;
}

beforeEach(function () {
    Schema::dropIfExists('ca2_personal_access_tokens');
    Schema::dropIfExists('ca2_users');

    Schema::create('ca2_users', function (Blueprint $table) {
        $table->uuid('id')->primary();
        $table->string('name');
        $table->string('email')->unique();
        $table->timestamps();
    });

    Schema::create('ca2_personal_access_tokens', function (Blueprint $table) {
        $table->id();
        $table->uuidMorphs('tokenable'); // <- o override testado (era morphs())
        $table->text('name');
        $table->string('token', 64)->unique();
        $table->text('abilities')->nullable();
        $table->timestamp('last_used_at')->nullable();
        $table->timestamp('expires_at')->nullable()->index();
        $table->timestamps();
    });

    // Aponta o model do Sanctum para a tabela override só durante o teste.
    Sanctum::usePersonalAccessTokenModel(Ca2PersonalAccessToken::class);
});

afterEach(function () {
    // Restaura o model padrão do Sanctum — senão o override vaza para os demais
    // testes do mesmo processo e quebra a autenticação deles.
    Sanctum::usePersonalAccessTokenModel(PersonalAccessToken::class);
    Schema::dropIfExists('ca2_personal_access_tokens');
    Schema::dropIfExists('ca2_users');
});

/** PAT apontando para a tabela override. */
class Ca2PersonalAccessToken extends PersonalAccessToken
{
    protected $table = 'ca2_personal_access_tokens';
}

test('CA-2: Sanctum emite e resolve token com tokenable_id UUID (uuidMorphs)', function () {
    $user = _Ca2UuidUser::create([
        'name' => 'Spike UUID',
        'email' => 'spike-ca2@turni.local',
    ]);

    // (a) PK é UUIDv7.
    expect($user->getKeyType())->toBe('string');
    expect($user->id[14])->toBe('7');

    // (b) emite token.
    $new = $user->createToken('spike-token');
    $plain = $new->plainTextToken;
    expect($plain)->toContain('|');

    // tokenable_id foi gravado como uuid (igual ao id do user).
    $row = DB::table('ca2_personal_access_tokens')->first();
    expect($row->tokenable_id)->toBe($user->id);
    expect($row->tokenable_type)->toBe(_Ca2UuidUser::class);

    // a coluna é do tipo `uuid` nativo no Postgres.
    $colType = DB::selectOne(
        "select data_type from information_schema.columns
         where table_name = 'ca2_personal_access_tokens' and column_name = 'tokenable_id'"
    );
    expect($colType->data_type)->toBe('uuid');

    // (c) resolve de volta via findToken() -> tokenable morphTo -> User UUID.
    $found = Ca2PersonalAccessToken::findToken($plain);
    expect($found)->not->toBeNull();
    expect($found->tokenable)->not->toBeNull();
    expect($found->tokenable->id)->toBe($user->id);
    expect($found->tokenable)->toBeInstanceOf(_Ca2UuidUser::class);
});
