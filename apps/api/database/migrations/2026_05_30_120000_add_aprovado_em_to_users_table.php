<?php

// STORY-021 — CA-5 — Carimbo de aprovação para ancorar as janelas do lembrete de
// completar cadastro (48h/5d/14d após aprovação). Preenchido pelo ApprovalService do
// admin na transição pendente_aprovacao → liberado. Reversível (dropColumn).

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->timestampTz('aprovado_em')->nullable()->after('status');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('aprovado_em');
        });
    }
};
