<?php

// STORY-023 — Completar cadastro do profissional + AceiteEletronico (adesão).
// (a) Campos do completar cadastro em profissional_profiles (todos nullable — a
//     obrigatoriedade é do FormRequest; perfil é criado no pré-cadastro e completado aqui).
//     documento_hash: SHA-256/HMAC determinístico p/ unicidade do documento (IDR-022 d),
//     já que documento_encrypted (ADR-009 5A) é não-determinístico e não indexável.
// (b) aceites_eletronicos conforme ADR-010 Decisão 4A: imutável via trigger BEFORE
//     UPDATE/DELETE + REVOKE no role de runtime. Sem turno_id (chega no EPIC-003).
//
// IDEMPOTENTE (reconcilia drift de homolog): a rc.37 chegou a deployar a STORY-023
// original (migration 2026_05_30_140000) em homolog; o PO reverteu o CÓDIGO mas não o
// BANCO de homolog — que ficou com aceites_eletronicos + estas colunas. Esta migration
// (nome novo) é desconhecida lá e tentaria recriar tudo. Por isso: colunas só são
// adicionadas se ausentes, e aceites_eletronicos é dropado e recriado com o schema desta
// versão. Em banco limpo (testes/migrate:fresh) os guards são no-op + create normal.

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('profissional_profiles', function (Blueprint $table) {
            // Cada coluna só é adicionada se ausente (idempotência — ver cabeçalho).
            if (! Schema::hasColumn('profissional_profiles', 'documento_hash')) {
                // documento_hash determinístico para a constraint de unicidade (IDR-022 d).
                $table->string('documento_hash', 64)->nullable()->unique()->after('documento_tipo');
            }
            if (! Schema::hasColumn('profissional_profiles', 'funcoes_secundarias')) {
                // Funções secundárias opcionais — lista de funcao_id (multi-select).
                $table->jsonb('funcoes_secundarias')->nullable()->after('funcao_id');
            }
            if (! Schema::hasColumn('profissional_profiles', 'raio_max_km')) {
                // Raio máximo de deslocamento (km).
                $table->unsignedSmallInteger('raio_max_km')->nullable()->after('bio');
            }
            if (! Schema::hasColumn('profissional_profiles', 'preco_hora')) {
                // Preço/hora pretendido (R$/h).
                $table->decimal('preco_hora', 10, 2)->nullable()->after('raio_max_km');
            }
            if (! Schema::hasColumn('profissional_profiles', 'documentos_comprobatorios')) {
                // Documentos comprobatórios — lista de paths em disco privado (ADR-004).
                $table->jsonb('documentos_comprobatorios')->nullable()->after('foto_path');
            }
        });

        // Dropa leftover (drift de homolog) e recria com o schema desta versão. CASCADE
        // remove o trigger junto; a function é dropada explicitamente. No-op em banco limpo.
        DB::unprepared('DROP TABLE IF EXISTS aceites_eletronicos CASCADE');
        DB::unprepared('DROP FUNCTION IF EXISTS prevent_aceite_eletronico_mutation() CASCADE');

        Schema::create('aceites_eletronicos', function (Blueprint $table) {
            $table->id();
            $table->foreignId('template_versao_id')->constrained('template_versoes');
            $table->foreignId('user_id')->constrained('users');
            $table->text('conteudo_renderizado'); // documento integral exibido/assinado (autocontido)
            $table->jsonb('dados_renderizados');   // mapa placeholder -> valor usado na renderização
            $table->timestampTz('aceito_em')->default(DB::raw('NOW()'));
            $table->ipAddress('ip');
            $table->text('fingerprint'); // sha256(user_agent:ip:date) — ADR-010 Decisão 4
            // Sem updated_at: imutável após criação. Sem turno_id: EPIC-003 via ALTER TABLE.
        });

        // Imutabilidade (ADR-010 Decisão 4A) — qualquer UPDATE/DELETE levanta exceção.
        DB::unprepared('
            CREATE OR REPLACE FUNCTION prevent_aceite_eletronico_mutation()
            RETURNS TRIGGER LANGUAGE plpgsql AS $$
            BEGIN
                RAISE EXCEPTION \'aceites_eletronicos é imutável após criação — operação % não permitida\', TG_OP;
            END;
            $$;
        ');

        DB::unprepared('
            CREATE TRIGGER prevent_aceite_eletronico_mutation
            BEFORE UPDATE OR DELETE ON aceites_eletronicos
            FOR EACH ROW EXECUTE FUNCTION prevent_aceite_eletronico_mutation();
        ');

        // Defesa em profundidade: o usuário de runtime não tem UPDATE/DELETE mesmo se o
        // trigger for removido (ADR-010 / ADR-009 Decisão 4A). Em teste, runtime == turni.
        $runtimeUser = config('database.connections.pgsql.username', 'turni');
        DB::unprepared("REVOKE UPDATE, DELETE ON aceites_eletronicos FROM \"{$runtimeUser}\"");
    }

    public function down(): void
    {
        DB::unprepared('DROP TRIGGER IF EXISTS prevent_aceite_eletronico_mutation ON aceites_eletronicos');
        DB::unprepared('DROP FUNCTION IF EXISTS prevent_aceite_eletronico_mutation()');
        Schema::dropIfExists('aceites_eletronicos');

        $colunas = array_filter([
            'documento_hash',
            'funcoes_secundarias',
            'raio_max_km',
            'preco_hora',
            'documentos_comprobatorios',
        ], fn (string $c) => Schema::hasColumn('profissional_profiles', $c));

        if ($colunas !== []) {
            Schema::table('profissional_profiles', function (Blueprint $table) use ($colunas) {
                $table->dropColumn($colunas);
            });
        }
    }
};
