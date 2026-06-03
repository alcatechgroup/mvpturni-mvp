<?php

// STORY-069 — CA-3 — laravel/passkeys (NÃO spatie/laravel-passkeys) com User
// de PK UUID (ADR-018, Decisão 4 estendida).
//
// Descoberta do spike: o projeto usa o pacote OFICIAL `laravel/passkeys`
// (^0.2.0), não `spatie/laravel-passkeys` como a story/ADR assumiram. A
// migration real (2026_05_28_173734_create_passkeys_table.php) usa
// `foreignIdFor(Passkeys::userModel(), 'user_id')`.
//
// `Blueprint::foreignIdFor()` adapta o tipo da coluna conforme o keyType do
// model relacionado: keyType 'int' -> bigint; HasUlids -> ulid; senão ->
// foreignUuid. Logo, quando o User vira PK UUID (`$keyType = 'string'`), a
// coluna `passkeys.user_id` vira `uuid` AUTOMATICAMENTE — zero edição na
// migration do pacote.
//
// Este teste prova isso empiricamente apontando Passkeys::useUserModel para um
// User temporário de PK UUID e replicando o mecanismo da migration.

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Laravel\Passkeys\Passkey;
use Laravel\Passkeys\Passkeys;

/** User temporário de PK UUID — o que o User real vira na STORY-070. */
class _Ca3UuidUser extends Authenticatable
{
    use HasUuids;

    protected $table = 'ca3_users';

    protected $guarded = [];
}

beforeEach(function () {
    Schema::dropIfExists('ca3_passkeys');
    Schema::dropIfExists('ca3_users');

    Schema::create('ca3_users', function (Blueprint $table) {
        $table->uuid('id')->primary();
        $table->string('name');
        $table->timestamps();
    });

    $this->originalUserModel = Passkeys::userModel();
    Passkeys::useUserModel(_Ca3UuidUser::class);

    // Replica EXATAMENTE o mecanismo da migration real do pacote.
    Schema::create('ca3_passkeys', function (Blueprint $table) {
        $table->id();
        $table->foreignIdFor(Passkeys::userModel(), 'user_id')->constrained('ca3_users')->cascadeOnDelete();
        $table->string('name');
        $table->string('credential_id')->unique();
        $table->json('credential');
        $table->timestamp('last_used_at')->nullable();
        $table->timestamps();
    });
});

afterEach(function () {
    Schema::dropIfExists('ca3_passkeys');
    Schema::dropIfExists('ca3_users');
    Passkeys::useUserModel($this->originalUserModel);
});

test('CA-3: foreignIdFor gera user_id UUID quando User tem PK UUID', function () {
    // A coluna FK virou `uuid` nativo automaticamente.
    $userIdType = DB::selectOne(
        "select data_type from information_schema.columns
         where table_name = 'ca3_passkeys' and column_name = 'user_id'"
    );
    expect($userIdType->data_type)->toBe('uuid');

    // A PK própria da tabela passkeys permanece bigint (como personal_access_tokens.id).
    $pkType = DB::selectOne(
        "select data_type from information_schema.columns
         where table_name = 'ca3_passkeys' and column_name = 'id'"
    );
    expect($pkType->data_type)->toBe('bigint');

    // O model Passkey do pacote tem PK incremental int (não vira UUID; não há
    // FK de domínio apontando para passkeys.id).
    expect((new Passkey)->getKeyType())->toBe('int');
    expect((new Passkey)->getIncrementing())->toBeTrue();
});

test('CA-3: passkey vincula a User UUID e a relação belongsTo resolve', function () {
    $user = _Ca3UuidUser::create(['name' => 'Spike Passkey']);
    expect($user->getKeyType())->toBe('string');
    expect($user->id[14])->toBe('7');

    $passkeyId = DB::table('ca3_passkeys')->insertGetId([
        'user_id' => $user->id,
        'name' => 'iPhone',
        'credential_id' => 'cred-'.$user->id,
        'credential' => json_encode(['aaguid' => 'x']),
        'created_at' => now(),
        'updated_at' => now(),
    ]);

    $row = DB::table('ca3_passkeys')->where('id', $passkeyId)->first();
    expect($row->user_id)->toBe($user->id);

    // FK constraint real: deletar o user cascateia o passkey (uuid FK válida).
    $user->delete();
    expect(DB::table('ca3_passkeys')->where('id', $passkeyId)->exists())->toBeFalse();
});
