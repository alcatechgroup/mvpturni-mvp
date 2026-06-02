<?php

// STORY-050 (CA-1) — snapshot do score de match no momento do envio da candidatura.
//  - `score_no_momento` (0..100) nullable: candidaturas legadas (nenhuma no MVP) ficam null;
//    a partir de STORY-050 toda candidatura nova carimba o total calculado no POST.
//  - É a métrica de qualidade do match no instante certo (a vaga/perfil mudam depois; o
//    score do feed é on-demand — ADR-014 — então sem este snapshot a métrica se perderia).
// down() simétrico: drop column.

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('candidaturas', function (Blueprint $table) {
            $table->smallInteger('score_no_momento')->nullable()->after('vaga_versao_id');
        });
    }

    public function down(): void
    {
        Schema::table('candidaturas', function (Blueprint $table) {
            $table->dropColumn('score_no_momento');
        });
    }
};
