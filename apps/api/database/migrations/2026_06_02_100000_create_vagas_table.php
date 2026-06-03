<?php

// STORY-044 / ADR-013 (CA-3, CA-4, CA-5, CA-8) — tabela `vagas`.
//  - estado em enum NATIVO do Postgres (`vaga_estado`), não varchar (Decisão 4/CA-4);
//  - invariantes duras: posicoes>=1, data_fim>data_inicio, posicoes_preenchidas no range;
//  - localização (lat/lng) é campo material (PDR-009) — snapshot do estabelecimento;
//  - índice parcial do feed `idx_vagas_feed` (Decisão 3/CA-8) + bbox geo + minhas vagas.
// down() simétrico: drop table → drop type (F-NB-1).

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        DB::statement("CREATE TYPE vaga_estado AS ENUM ('aberta', 'fechada', 'cancelada')");

        Schema::create('vagas', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('contratante_id')->constrained('users')->restrictOnDelete();
            $table->foreignUuid('funcao_id')->constrained('funcoes')->restrictOnDelete();
            $table->timestampTz('data_inicio');
            $table->timestampTz('data_fim');
            $table->decimal('valor', 10, 2);
            $table->decimal('valor_hora', 10, 2)->nullable();
            $table->smallInteger('posicoes');
            $table->smallInteger('posicoes_preenchidas')->default(0);
            $table->text('observacoes')->nullable();
            $table->decimal('lat', 10, 7)->nullable();
            $table->decimal('lng', 10, 7)->nullable();
            $table->string('cidade', 120)->nullable();
            $table->char('uf', 2)->nullable();
            // `estado` é adicionado via ALTER (tipo enum nativo — Laravel não tem builder nativo).
            $table->smallInteger('versao_atual')->default(1);
            $table->timestampTz('publicada_em')->nullable();
            $table->timestampTz('fechada_em')->nullable();
            $table->timestampTz('cancelada_em')->nullable();
            $table->timestampsTz();
        });

        DB::statement("ALTER TABLE vagas ADD COLUMN estado vaga_estado NOT NULL DEFAULT 'aberta'");

        // Invariantes-chave no banco (CA-5).
        DB::statement('ALTER TABLE vagas ADD CONSTRAINT vagas_posicoes_min CHECK (posicoes >= 1)');
        DB::statement('ALTER TABLE vagas ADD CONSTRAINT vagas_datas_ordem CHECK (data_fim > data_inicio)');
        DB::statement('ALTER TABLE vagas ADD CONSTRAINT vagas_preenchidas_range CHECK (posicoes_preenchidas >= 0 AND posicoes_preenchidas <= posicoes)');

        // Índice parcial do feed: função + data futura, restrito a abertas (CA-8).
        DB::statement("CREATE INDEX idx_vagas_feed ON vagas (funcao_id, data_inicio) WHERE estado = 'aberta'");
        // Prefiltro bounding-box do raio (Decisão 3).
        DB::statement('CREATE INDEX idx_vagas_geo ON vagas (lat, lng)');
        // "Minhas vagas" do contratante (STORY-047).
        DB::statement('CREATE INDEX idx_vagas_contratante ON vagas (contratante_id, estado)');
    }

    public function down(): void
    {
        Schema::dropIfExists('vagas');
        DB::statement('DROP TYPE IF EXISTS vaga_estado');
    }
};
