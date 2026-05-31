<?php

// STORY-023 / ADR-009 + ADR-010 — Completar cadastro do profissional + AceiteEletronico.
//
// (1) Colunas de completar-cadastro em profissional_profiles (domain/usuario.md §pós-aprovação).
//     `documento_hash` permite enforçar unicidade do documento (CA-3) sem expor o texto claro:
//     o `documento` em si fica em Encrypted Cast (ciphertext muda a cada IV, não é UNIQUE-ável) —
//     o hash determinístico (HMAC-SHA256 com pepper) é a estratégia prevista no ADR-009 §evolução.
// (2) aceites_eletronicos (ADR-010 Decisão 4): imutável por trigger BEFORE UPDATE OR DELETE +
//     REVOKE UPDATE,DELETE no role de runtime (mesmo padrão de admin_audit_log / template_versoes).

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('profissional_profiles', function (Blueprint $table) {
            $table->unsignedInteger('raio_max_km')->nullable()->after('bio');
            $table->decimal('preco_hora', 10, 2)->nullable()->after('raio_max_km');
            // Lista de funcao_id secundárias (opcional, multi-select). JSONB simples — o
            // volume é pequeno e a leitura é sempre do perfil inteiro (sem query por elemento).
            $table->jsonb('funcoes_secundarias')->nullable()->after('preco_hora');
            // Documento comprobatório (foto do RG/CNH/CCMEI/Cartão CNPJ) em disco privado,
            // path não-enumerável (hash do store) — ADR-004. Sem URL pública direta.
            $table->string('documento_comprobatorio_path')->nullable()->after('funcoes_secundarias');
            // Unicidade do documento no sistema (CA-3) sobre dado criptografado (ADR-009 §evolução).
            $table->string('documento_hash', 64)->nullable()->after('documento_tipo');
            $table->unique('documento_hash', 'profissional_profiles_documento_hash_unique');
        });

        // aceites_eletronicos — ADR-010 Decisão 4 (schema canônico).
        Schema::create('aceites_eletronicos', function (Blueprint $table) {
            $table->id();
            $table->foreignId('template_versao_id')->constrained('template_versoes');
            $table->foreignId('user_id')->constrained('users');
            $table->text('conteudo_renderizado');
            $table->jsonb('dados_renderizados');
            $table->timestampTz('aceito_em')->default(DB::raw('NOW()'));
            // INET nativo do Postgres (IPv4/IPv6). Blueprint não tem helper — coluna adicionada via raw abaixo.
            $table->text('fingerprint');
            // Imutável: sem updated_at; turno_id chega só no EPIC-003 (ALTER TABLE).
        });

        // `ip` como INET (não string) — tipo nativo do Postgres (ADR-010 §campos).
        DB::statement('ALTER TABLE aceites_eletronicos ADD COLUMN ip INET NOT NULL');

        // Imutabilidade total: nenhum UPDATE/DELETE após a criação (evidência jurídica).
        DB::unprepared('
            CREATE OR REPLACE FUNCTION prevent_aceite_eletronico_mutation()
            RETURNS TRIGGER LANGUAGE plpgsql AS $$
            BEGIN
                RAISE EXCEPTION \'aceites_eletronicos é imutável após criação\';
                RETURN NULL;
            END;
            $$;
        ');

        DB::unprepared('
            CREATE TRIGGER prevent_aceite_eletronico_mutation
            BEFORE UPDATE OR DELETE ON aceites_eletronicos
            FOR EACH ROW EXECUTE FUNCTION prevent_aceite_eletronico_mutation();
        ');

        // 2ª camada (defesa em profundidade — padrão ADR-009): o runtime não pode mutar a tabela.
        $runtimeUser = config('database.connections.pgsql.username', 'turni');
        DB::unprepared("REVOKE UPDATE, DELETE ON aceites_eletronicos FROM \"{$runtimeUser}\"");
    }

    public function down(): void
    {
        $runtimeUser = config('database.connections.pgsql.username', 'turni');
        // GRANT defensivo antes do DROP (sem ele, o role sem permissão pode falhar no drop).
        DB::unprepared("GRANT UPDATE, DELETE ON aceites_eletronicos TO \"{$runtimeUser}\"");
        DB::unprepared('DROP TRIGGER IF EXISTS prevent_aceite_eletronico_mutation ON aceites_eletronicos');
        DB::unprepared('DROP FUNCTION IF EXISTS prevent_aceite_eletronico_mutation()');
        Schema::dropIfExists('aceites_eletronicos');

        Schema::table('profissional_profiles', function (Blueprint $table) {
            $table->dropUnique('profissional_profiles_documento_hash_unique');
            $table->dropColumn([
                'raio_max_km',
                'preco_hora',
                'funcoes_secundarias',
                'documento_comprobatorio_path',
                'documento_hash',
            ]);
        });
    }
};
