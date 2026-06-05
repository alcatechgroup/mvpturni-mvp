<?php

// STORY-061 (CA-3/CA-4) — hash do PIN de check-in no turno. Guardamos APENAS o hash
// (bcrypt, mesmo do EPIC-001); o plaintext existe só na resposta da geração e a
// re-geração sobrescreve (invalida) o hash anterior. Limpo no cancelamento e no
// consumo da validação (STORY-062).

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('turnos', function (Blueprint $table) {
            $table->string('pin_checkin_hash')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('turnos', function (Blueprint $table) {
            $table->dropColumn('pin_checkin_hash');
        });
    }
};
