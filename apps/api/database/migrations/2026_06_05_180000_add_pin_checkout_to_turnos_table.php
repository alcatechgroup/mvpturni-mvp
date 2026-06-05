<?php

// STORY-064 (CA-2/CA-4) — PIN de check-out: hash + contador de erros, espelho exato das
// colunas da dupla 061/062 (`pin_checkin_*`). Guardamos APENAS o hash (bcrypt); o
// plaintext existe só na resposta da geração e a re-geração sobrescreve o anterior.
// O contador persiste no turno (regra de domínio transacional — 3 erros expiram o PIN
// e devolvem o turno a `ativo`); zerado pela (re)geração, recusa, cancelamento e consumo.

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('turnos', function (Blueprint $table) {
            $table->string('pin_checkout_hash')->nullable();
            $table->unsignedSmallInteger('pin_checkout_tentativas')->default(0);
        });
    }

    public function down(): void
    {
        Schema::table('turnos', function (Blueprint $table) {
            $table->dropColumn(['pin_checkout_hash', 'pin_checkout_tentativas']);
        });
    }
};
