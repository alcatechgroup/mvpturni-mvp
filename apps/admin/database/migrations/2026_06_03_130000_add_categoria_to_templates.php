<?php

// STORY-053 (CA-6, Path A) — cópia paralela da migração do `api` (dono do schema real). No `admin`
// ela existe só para o DB de teste (`turni_test`, RefreshDatabase). Ver memória
// `project-backoffice-db-ownership`: feature do Backoffice com tabela/coluna nova exige a migração
// nos dois apps. `categoria` separa 'contrato' (STORY-020) de 'email' (notificações, STORY-053).

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('templates', function (Blueprint $table) {
            $table->string('categoria', 20)->default('contrato')->after('slug');
        });
    }

    public function down(): void
    {
        Schema::table('templates', function (Blueprint $table) {
            $table->dropColumn('categoria');
        });
    }
};
