<?php

// STORY-074 (preparação) — coordenadas do estabelecimento em `contratante_profiles`.
//
// O geofencing de check-in (PDR-008 / STORY-061) precisa da posição do estabelecimento como
// ponto de referência, mas o perfil do contratante só guardava o endereço em TEXTO (CEP,
// logradouro…), sem lat/lng — e o CepLookup não geocodifica. Sem coordenada, `PublicarVagaService`
// snapshota `lat/lng` nulos na vaga e a distância fica indeterminada (STORY-057 descobriu isso).
//
// Esta migração só CRIA as colunas (nullable), prontas para serem POPULADAS pela STORY-074
// (geocoding do endereço → lat/lng). Mesma precisão da geo da vaga (decimal 10,7 ≈ 1cm). Nenhum
// dado é geocodificado aqui; coluna nula = comportamento atual (degrada para `sem_coordenada`).
// Reversível com dropColumn.

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('contratante_profiles', function (Blueprint $table) {
            $table->decimal('lat', 10, 7)->nullable()->after('complemento');
            $table->decimal('lng', 10, 7)->nullable()->after('lat');
        });
    }

    public function down(): void
    {
        Schema::table('contratante_profiles', function (Blueprint $table) {
            $table->dropColumn(['lat', 'lng']);
        });
    }
};
