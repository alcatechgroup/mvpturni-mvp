<?php

namespace Database\Seeders;

use App\Models\ContratanteProfile;
use App\Models\Funcao;
use App\Models\ProfissionalProfile;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

/**
 * STORY-019 — cadastros em `pendente_aprovacao` para a fila de aprovação do Backoffice.
 *
 * Popula dev/homolog com casos variados (PF/MEI/PJ + contratante) e idades distintas
 * para exercitar os buckets de SLA (verde/amarelo/vermelho) e os filtros. Idempotente
 * por e-mail. Não roda em produção (são dados de teste).
 */
class FilaAprovacaoPendentesSeeder extends Seeder
{
    public function run(): void
    {
        if (app()->environment('production')) {
            return;
        }

        $password = Hash::make(env('ADMIN_SEED_PASSWORD', 'turni-dev'));
        $garcom = Funcao::where('slug', 'garcom')->first()?->id;

        // Profissional MEI — 21h na fila (vermelho/SLA em risco).
        $this->profissional($password, [
            'email' => 'pendente.mei@turni.local',
            'name' => 'Carlos Henrique Silva',
            'created_at' => now()->subHours(21),
        ], ['tipo_pessoa' => 'MEI', 'telefone' => '(11) 9 9999-1111', 'cidade' => 'São Paulo', 'bairro' => 'Mooca', 'funcao_id' => $garcom]);

        // Profissional PF — 3h (verde).
        $this->profissional($password, [
            'email' => 'pendente.pf@turni.local',
            'name' => 'Diego Reis',
            'created_at' => now()->subHours(3),
        ], ['tipo_pessoa' => 'PF', 'telefone' => '(11) 9 9999-2222', 'cidade' => 'Santo André', 'funcao_id' => $garcom]);

        // Profissional PJ — 14h (amarelo).
        $this->profissional($password, [
            'email' => 'pendente.pj@turni.local',
            'name' => 'Ana Beatriz Eventos ME',
            'created_at' => now()->subHours(14),
        ], ['tipo_pessoa' => 'PJ', 'telefone' => '(11) 9 9999-3333', 'cidade' => 'São Paulo']);

        // Contratante — 14h (amarelo).
        $contratante = User::updateOrCreate(
            ['email' => 'pendente.contratante@turni.local'],
            [
                'name' => 'Pizzaria Mooca Ltda',
                'password' => $password,
                'role' => 'contratante',
                'status' => 'pendente_aprovacao',
                'welcome_seen_at' => null,
                'cadastro_completed_at' => null,
                'created_at' => now()->subHours(14),
            ],
        );
        ContratanteProfile::updateOrCreate(
            ['user_id' => $contratante->id],
            ['nome_estabelecimento' => 'Pizzaria Mooca', 'tipo_operacao' => 'Restaurante', 'telefone' => '(11) 3 3333-3333', 'cidade' => 'São Paulo', 'termos_aceitos_at' => now()->subHours(14)],
        );
    }

    private function profissional(string $password, array $user, array $profile): void
    {
        $u = User::updateOrCreate(
            ['email' => $user['email']],
            [
                'name' => $user['name'],
                'password' => $password,
                'role' => 'profissional',
                'status' => 'pendente_aprovacao',
                'welcome_seen_at' => null,
                'cadastro_completed_at' => null,
                'created_at' => $user['created_at'],
            ],
        );

        ProfissionalProfile::updateOrCreate(
            ['user_id' => $u->id],
            array_merge(['termos_aceitos_at' => $user['created_at']], $profile),
        );
    }
}
