<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

/**
 * Seed mínimo (CA-7): garante a presença de um usuário admin de teste para o
 * backoffice. NÃO há login funcional ainda (EPIC-001) — é só presença no banco
 * para estórias futuras consumirem.
 *
 * Idempotente: usa updateOrCreate pela chave natural (e-mail), então rodar o
 * seed duas vezes não duplica o admin (quality-standards 2.4).
 *
 * A senha é um placeholder de DEV vindo de env (default conhecido). Não é
 * segredo de produção — em homolog/prod o provisionamento de admin é outro fluxo.
 */
class AdminUserSeeder extends Seeder
{
    public function run(): void
    {
        User::updateOrCreate(
            ['email' => env('ADMIN_SEED_EMAIL', 'admin@turni.local')],
            [
                'name' => 'Admin Turni (seed)',
                'password' => Hash::make(env('ADMIN_SEED_PASSWORD', 'turni-dev')),
            ],
        );
    }
}
