<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use RuntimeException;

/**
 * STORY-020 (CA-12, CA-16) — Catálogo de templates contratuais + versão 1 ativa.
 *
 * O conteúdo da v1 vem dos textos-seed de STORY-015. Os arquivos canônicos vivem em
 * `docs/especificacao/contratos/`, que NÃO é montado no container (deploy = imagem do app).
 * Por isso vendoramos uma cópia fiel (frontmatter YAML removido) em
 * `database/seeders/contracts/` e registramos o SHA-256 como evidência de fidelidade.
 *
 * Idempotente: cria o template e a v1 só quando ainda não existem. Rodar 2× não duplica.
 */
class TemplatesContratuaisSeeder extends Seeder
{
    /** @var array<string,array{nome:string,arquivo:string}> */
    private const CATALOGO = [
        'pf_autonomo_eventual' => [
            'nome' => 'Contrato PF — Autônomo eventual',
            'arquivo' => 'template-pf-autonomo-eventual-v1.md',
        ],
        'mei_pj_b2b' => [
            'nome' => 'Contrato MEI/PJ — B2B PJ↔PJ',
            'arquivo' => 'template-mei-pj-b2b-v1.md',
        ],
    ];

    public function run(): void
    {
        $adminId = DB::table('users')->where('role', 'admin')->orderBy('id')->value('id');

        if ($adminId === null) {
            throw new RuntimeException('TemplatesContratuaisSeeder requer um admin (rode AdminUserSeeder antes).');
        }

        foreach (self::CATALOGO as $slug => $meta) {
            $templateId = DB::table('templates')->where('slug', $slug)->value('id');

            if ($templateId === null) {
                $templateId = DB::table('templates')->insertGetId([
                    'slug' => $slug,
                    'nome_amigavel' => $meta['nome'],
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
            }

            // Idempotência: só carrega a v1 se o template ainda não tem nenhuma versão.
            $jaTemVersao = DB::table('template_versoes')->where('template_id', $templateId)->exists();
            if ($jaTemVersao) {
                continue;
            }

            $conteudo = $this->carregarConteudo($meta['arquivo']);
            $hash = hash('sha256', $conteudo);

            DB::table('template_versoes')->insert([
                'template_id' => $templateId,
                'versao' => 1,
                'conteudo' => $conteudo,
                'criado_por_admin_id' => $adminId,
                'ativa' => true,
                'created_at' => now(),
            ]);

            // Evidência de fidelidade ao texto-seed de STORY-015 (CA-16).
            Log::info('admin.template.seeded', [
                'event' => 'admin.template.seeded',
                'service' => 'seed',
                'template_slug' => $slug,
                'versao' => 1,
                'content_sha256' => $hash,
            ]);
        }
    }

    private function carregarConteudo(string $arquivo): string
    {
        $caminho = database_path('seeders/contracts/'.$arquivo);

        if (! is_file($caminho)) {
            throw new RuntimeException("Texto-seed do template não encontrado: {$caminho}");
        }

        $conteudo = trim((string) file_get_contents($caminho));

        if ($conteudo === '') {
            throw new RuntimeException("Texto-seed do template está vazio: {$caminho}");
        }

        return $conteudo;
    }
}
