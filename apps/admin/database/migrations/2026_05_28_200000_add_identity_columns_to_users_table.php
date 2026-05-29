<?php

// STORY-016 — CA-1 — Adiciona colunas de identidade EPIC-001 à tabela users (ADR-009).
// Esta é a primeira migração com lógica de negócio — critério herdado F-NB-1 do EPIC-000:
// execute php artisan migrate:rollback em homolog e registre evidência no runbook.

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('role', 30)->default('profissional')->after('email');
            $table->string('status', 30)->default('pendente_aprovacao')->after('role');
            $table->timestampTz('welcome_seen_at')->nullable()->after('status');
            $table->timestampTz('cadastro_completed_at')->nullable()->after('welcome_seen_at');
        });

        // CHECK constraint garante que apenas valores válidos entram (ADR-009).
        // Não usa enum do Postgres para facilitar rollback (DROP CONSTRAINT é simples).
        DB::statement("
            ALTER TABLE users
            ADD CONSTRAINT users_role_check
            CHECK (role IN ('admin','contratante','profissional'))
        ");

        DB::statement("
            ALTER TABLE users
            ADD CONSTRAINT users_status_check
            CHECK (status IN ('pendente_aprovacao','liberado','ativo','recusado'))
        ");
    }

    public function down(): void
    {
        // role/status são CHECK constraints (não FK) — basta dropá-las por nome.
        // (Linha anterior usava dropConstrainedForeignId, que gerava DROP de uma
        // constraint FK inexistente e quebrava o rollback — pego pelo F-NB-1/CA-2.)
        DB::statement('ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check');
        DB::statement('ALTER TABLE users DROP CONSTRAINT IF EXISTS users_status_check');

        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['role', 'status', 'welcome_seen_at', 'cadastro_completed_at']);
        });
    }
};
