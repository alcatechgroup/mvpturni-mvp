<?php

// STORY-048 / ADR-014 (nota geográfica) — geolocalização do profissional.
// O cálculo de distância do feed (ADR-013: bbox + Haversine) precisa das coordenadas do
// profissional para filtrar vagas por raio e injetar `distanciaKm` no MatchInput. Hoje o
// perfil tem `cidade`/`bairro`/`raio_max_km` mas falta lat/lng — ADR-014 marcou isso como
// pré-requisito desta estória. Colunas nullable: sem geo, o feed não filtra por raio e o
// componente de distância zera (não esconde o feed inteiro por falta de coordenada).
//
// IDEMPOTENTE (mesmo cuidado das demais migrations de profissional_profiles): cada coluna
// só é adicionada se ausente, para reconciliar drift de homolog sem quebrar.

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('profissional_profiles', function (Blueprint $table) {
            if (! Schema::hasColumn('profissional_profiles', 'lat')) {
                $table->decimal('lat', 10, 7)->nullable()->after('bairro');
            }
            if (! Schema::hasColumn('profissional_profiles', 'lng')) {
                $table->decimal('lng', 10, 7)->nullable()->after('lat');
            }
        });

        // Prefiltro bounding-box do raio (espelha idx_vagas_geo de ADR-013).
        DB::statement('CREATE INDEX IF NOT EXISTS idx_profissional_geo ON profissional_profiles (lat, lng)');
    }

    public function down(): void
    {
        DB::statement('DROP INDEX IF EXISTS idx_profissional_geo');

        $colunas = array_filter(
            ['lat', 'lng'],
            fn (string $c) => Schema::hasColumn('profissional_profiles', $c),
        );

        if ($colunas !== []) {
            Schema::table('profissional_profiles', function (Blueprint $table) use ($colunas) {
                $table->dropColumn($colunas);
            });
        }
    }
};
