<?php

// STORY-062 (CA-3) — contador de erros de validação do PIN ativo. Persistido no turno
// (não em cache): o limite de 3 erros é regra de domínio transacional — sobrevive a
// restart/troca de processo e é zerado pela (re)geração da 061, pela recusa e pelo
// consumo na validação. O rate limit de requests (CA-2) é outra camada (RateLimiter).

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('turnos', function (Blueprint $table) {
            $table->unsignedSmallInteger('pin_checkin_tentativas')->default(0);
        });
    }

    public function down(): void
    {
        Schema::table('turnos', function (Blueprint $table) {
            $table->dropColumn('pin_checkin_tentativas');
        });
    }
};
