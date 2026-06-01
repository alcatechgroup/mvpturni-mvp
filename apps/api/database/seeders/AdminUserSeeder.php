<?php

namespace Database\Seeders;

use App\Models\ContratanteProfile;
use App\Models\ProfissionalProfile;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

/**
 * Seed de homolog/dev — STORY-016 CA-12.
 *
 * Cria 3 usuários de teste idempotentes:
 *   1. admin@turni.local         — role: admin, status: ativo
 *   2. contratante.teste@turni.local — role: contratante, status: ativo
 *   3. profissional.teste@turni.local — role: profissional, status: ativo, tipo_pessoa: MEI
 *
 * Senha para todos: ADMIN_SEED_PASSWORD env (default 'turni-dev').
 * Não é segredo de produção — admins de prod têm provisionamento próprio.
 * Idempotente: updateOrCreate pela chave natural (e-mail).
 */
class AdminUserSeeder extends Seeder
{
    public function run(): void
    {
        $password = Hash::make(env('ADMIN_SEED_PASSWORD', 'turni-dev'));

        // 1. Admin
        User::updateOrCreate(
            ['email' => env('ADMIN_SEED_EMAIL', 'admin@turni.local')],
            [
                'name' => 'Admin Turni (seed)',
                'password' => $password,
                'role' => 'admin',
                'status' => 'ativo',
                'welcome_seen_at' => null,
                'cadastro_completed_at' => null,
            ],
        );

        // 2. Contratante de teste
        $contratante = User::updateOrCreate(
            ['email' => 'contratante.teste@turni.local'],
            [
                'name' => 'Contratante Teste (seed)',
                'password' => $password,
                'role' => 'contratante',
                'status' => 'ativo',
                'welcome_seen_at' => now(),
                'cadastro_completed_at' => now(),
            ],
        );

        ContratanteProfile::updateOrCreate(
            ['user_id' => $contratante->id],
            ['nome_estabelecimento' => 'Estabelecimento Teste'],
        );

        // 3. Profissional de teste (MEI — conforme CA-12)
        $profissional = User::updateOrCreate(
            ['email' => 'profissional.teste@turni.local'],
            [
                'name' => 'Profissional Teste (seed)',
                'password' => $password,
                'role' => 'profissional',
                'status' => 'ativo',
                'welcome_seen_at' => now(),
                'cadastro_completed_at' => now(),
            ],
        );

        ProfissionalProfile::updateOrCreate(
            ['user_id' => $profissional->id],
            ['tipo_pessoa' => 'MEI'],
        );

        // 4. Profissional recém-aprovado para o E2E da tela de welcome (STORY-022 CA-11):
        //    status=liberado, welcome_seen_at=null → funnel guard manda para /welcome.
        $bemVindo = User::updateOrCreate(
            ['email' => 'bemvindo.profissional@turni.local'],
            [
                'name' => 'Bem-Vindo Teste (seed)',
                'password' => $password,
                'role' => 'profissional',
                'status' => 'liberado',
                'welcome_seen_at' => null,
                'cadastro_completed_at' => null,
            ],
        );

        ProfissionalProfile::updateOrCreate(
            ['user_id' => $bemVindo->id],
            ['tipo_pessoa' => 'MEI'],
        );
    }
}
