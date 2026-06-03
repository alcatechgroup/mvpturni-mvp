<?php

// STORY-053 (CA-6, Path A) — generaliza o catálogo de templates (antes só contratos, STORY-020)
// para abrigar também os corpos editáveis dos e-mails de notificação. `categoria` separa as duas
// famílias: 'contrato' (placeholders `{{ns.campo}}`, renderizado no aceite) e 'email' (placeholders
// `{snake_case}`, interpolado pelo worker com o payload da notificação). Default 'contrato' faz o
// backfill das linhas existentes sem tocá-las.

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
