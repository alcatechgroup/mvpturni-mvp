<?php

// FIX (descoberto no deploy da STORY-053 em homolog) — restaura o privilégio UPDATE do role de
// runtime sobre `vaga_versoes`. A migração 2026_06_02_100001 fazia `REVOKE UPDATE, DELETE` na
// tabela como "append-only", mas `vaga_versoes` é a tabela-PAI de uma FK
// (`candidaturas.vaga_versao_id`). Ao inserir uma candidatura, o Postgres valida a FK com
// `SELECT ... FOR KEY SHARE` na pai — lock que, pela doc do GRANT, EXIGE privilégio UPDATE. Sem ele,
// todo INSERT de candidatura que referencie uma versão de vaga falha com
// `42501 permission denied for table vaga_versoes` em qualquer banco onde o runtime não é superuser
// (Cloud SQL homolog/prod). Localmente passava batido porque o `turni` do Docker é superuser.
//
// A imutabilidade append-only continua garantida pelo trigger `prevent_vaga_versoes_mutation`
// (levanta exceção em qualquer UPDATE/DELETE de linha) e pelo REVOKE DELETE que permanece. Conceder
// UPDATE só libera o lock de FK do Postgres — nenhum UPDATE de linha passa pelo trigger.
//
// Idempotência: GRANT é naturalmente idempotente. A migração original já foi corrigida para revogar
// só DELETE; esta migração conserta os ambientes (homolog) que rodaram a versão antiga.

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        $runtimeUser = config('database.connections.pgsql.username', 'turni');
        DB::unprepared("GRANT UPDATE ON vaga_versoes TO \"{$runtimeUser}\"");
    }

    public function down(): void
    {
        $runtimeUser = config('database.connections.pgsql.username', 'turni');
        DB::unprepared("REVOKE UPDATE ON vaga_versoes FROM \"{$runtimeUser}\"");
    }
};
