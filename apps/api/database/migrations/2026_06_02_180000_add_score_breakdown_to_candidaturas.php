<?php

// STORY-051 (CA-4/CA-5) — snapshot completo do match no instante da candidatura, para o
// painel de candidatos do contratante.
//  - `score_breakdown` (jsonb, nullable): MatchScore::toArray() persistido no envio da
//    candidatura (STORY-050). O painel (STORY-051) lê este snapshot e NÃO recalcula — preserva
//    o porquê histórico do score, mesmo que vaga/perfil mudem depois (ADR-014: match on-demand).
//    Complementa o `score_no_momento` (só o total) já persistido pela STORY-050.
//  - `alerta_habitualidade` (bool, default false): MEI/PJ na 3ª alocação na semana passa sem
//    bloqueio (STORY-050 CA-4) mas marca este alerta — o painel mostra o badge laranja (CA-5).
// down() simétrico: drop das duas colunas.

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('candidaturas', function (Blueprint $table) {
            $table->jsonb('score_breakdown')->nullable()->after('score_no_momento');
            $table->boolean('alerta_habitualidade')->default(false)->after('score_breakdown');
        });
    }

    public function down(): void
    {
        Schema::table('candidaturas', function (Blueprint $table) {
            $table->dropColumn(['score_breakdown', 'alerta_habitualidade']);
        });
    }
};
