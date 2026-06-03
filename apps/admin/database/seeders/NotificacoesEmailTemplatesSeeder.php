<?php

namespace Database\Seeders;

use App\Domain\Templates\EmailTemplateCatalogo;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use RuntimeException;

/**
 * STORY-053 (CA-6, Path A) — cópia paralela do seeder do `api` (dono do schema real). No `admin`
 * roda só contra o DB de teste; o catálogo de slugs/nomes vem de EmailTemplateCatalogo (fonte que
 * o editor também usa). Conteúdo vendorado em `database/seeders/emails/`. Idempotente.
 */
class NotificacoesEmailTemplatesSeeder extends Seeder
{
    public function run(): void
    {
        $adminId = DB::table('users')->where('role', 'admin')->orderBy('id')->value('id');

        if ($adminId === null) {
            throw new RuntimeException('NotificacoesEmailTemplatesSeeder requer um admin (rode AdminUserSeeder antes).');
        }

        foreach (EmailTemplateCatalogo::TEMPLATES as $slug => $meta) {
            $templateId = DB::table('templates')->where('slug', $slug)->value('id');

            if ($templateId === null) {
                $templateId = DB::table('templates')->insertGetId([
                    'slug' => $slug,
                    'categoria' => EmailTemplateCatalogo::CATEGORIA,
                    'nome_amigavel' => $meta['nome'],
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
            }

            if (DB::table('template_versoes')->where('template_id', $templateId)->exists()) {
                continue;
            }

            DB::table('template_versoes')->insert([
                'template_id' => $templateId,
                'versao' => 1,
                'conteudo' => $this->carregarConteudo($slug),
                'criado_por_admin_id' => $adminId,
                'ativa' => true,
                'created_at' => now(),
            ]);
        }
    }

    private function carregarConteudo(string $slug): string
    {
        $caminho = database_path("seeders/emails/{$slug}.md");

        if (! is_file($caminho)) {
            throw new RuntimeException("Texto-seed do template de e-mail não encontrado: {$caminho}");
        }

        $conteudo = trim((string) file_get_contents($caminho));

        if ($conteudo === '') {
            throw new RuntimeException("Texto-seed do template de e-mail está vazio: {$caminho}");
        }

        return $conteudo;
    }
}
