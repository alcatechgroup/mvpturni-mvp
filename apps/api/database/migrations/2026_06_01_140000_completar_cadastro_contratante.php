<?php

// STORY-024 — Campos do completar cadastro do contratante (domain/usuario.md §Contratante /
// "Adicionados no completar cadastro"). Espelha a STORY-023 do profissional:
//  - cnpj_encrypted já existe (ADR-009 5A, criptografado em repouso). Aqui soma-se cnpj_hash
//    (HMAC-SHA256 determinístico) p/ a constraint de unicidade — encrypted cast é não-indexável
//    (IDR-022 d).
//  - endereço estruturado (logradouro/numero/bairro/uf/cep/complemento). cidade e
//    endereco_completo já existem (STORY-016/018); endereco_completo guarda a string composta
//    usada na renderização do contrato.
//  - demais campos do perfil do estabelecimento (apelido, segmento, ano, faixa de funcionários,
//    turnos, cultura, redes sociais, site, contatos adicionais).
// Todas nullable no banco — a obrigatoriedade vive no FormRequest; o perfil é criado no
// pré-cadastro (STORY-018) e completado aqui. Reversível via dropColumn.

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('contratante_profiles', function (Blueprint $table) {
            // Unicidade do CNPJ (IDR-022 d) — determinístico, indexável; valor em claro só no encrypted.
            $table->string('cnpj_hash', 64)->nullable()->unique()->after('cnpj_encrypted');

            // Endereço estruturado (cidade e endereco_completo já existem).
            $table->string('logradouro', 180)->nullable()->after('endereco_completo');
            $table->string('numero', 20)->nullable()->after('logradouro');
            $table->string('bairro', 120)->nullable()->after('numero');
            $table->string('uf', 2)->nullable()->after('bairro');
            $table->string('cep', 9)->nullable()->after('uf');
            $table->string('complemento', 120)->nullable()->after('cep');

            // Perfil do estabelecimento.
            $table->string('apelido_estabelecimento', 60)->nullable()->after('complemento');
            $table->string('segmento', 120)->nullable()->after('apelido_estabelecimento');
            $table->unsignedSmallInteger('ano_fundacao')->nullable()->after('segmento');
            $table->string('qtd_funcionarios', 20)->nullable()->after('ano_fundacao'); // faixa: 1-10|11-50|51-200|200+
            $table->text('turnos_operacao')->nullable()->after('qtd_funcionarios');
            $table->text('cultura_valores')->nullable()->after('turnos_operacao');
            $table->string('site', 200)->nullable()->after('cultura_valores');
            $table->jsonb('redes_sociais')->nullable()->after('site'); // {rede: url}
            $table->jsonb('contatos_adicionais')->nullable()->after('redes_sociais'); // [{nome,funcao,telefone}]
        });
    }

    public function down(): void
    {
        Schema::table('contratante_profiles', function (Blueprint $table) {
            $table->dropColumn([
                'cnpj_hash',
                'logradouro',
                'numero',
                'bairro',
                'uf',
                'cep',
                'complemento',
                'apelido_estabelecimento',
                'segmento',
                'ano_fundacao',
                'qtd_funcionarios',
                'turnos_operacao',
                'cultura_valores',
                'site',
                'redes_sociais',
                'contatos_adicionais',
            ]);
        });
    }
};
