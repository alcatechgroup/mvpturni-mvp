<?php

namespace Database\Seeders;

use App\Models\Funcao;
use Illuminate\Database\Seeder;

/**
 * STORY-017 — Funções pivotais do Turni (hospitalidade: restaurante, bar, hotel,
 * evento, catering). Idempotente via updateOrCreate pela chave natural (slug).
 * Lista inicial; a equipe Turni amplia pelo backoffice no futuro.
 */
class FuncaoSeeder extends Seeder
{
    public function run(): void
    {
        $funcoes = [
            'garcom' => 'Garçom / Garçonete',
            'bartender' => 'Bartender',
            'barista' => 'Barista',
            'cozinheiro' => 'Cozinheiro(a)',
            'auxiliar-cozinha' => 'Auxiliar de Cozinha',
            'chapeiro' => 'Chapeiro(a)',
            'copeiro' => 'Copeiro(a)',
            'recepcionista' => 'Recepcionista',
            'hostess' => 'Hostess / Recepção de Salão',
            'camareira' => 'Camareira / Arrumação',
            'auxiliar-limpeza' => 'Auxiliar de Limpeza',
            'seguranca' => 'Segurança',
            'auxiliar-eventos' => 'Auxiliar de Eventos',
            'promotor' => 'Promotor(a) de Vendas',
        ];

        foreach ($funcoes as $slug => $nome) {
            Funcao::updateOrCreate(['slug' => $slug], ['nome' => $nome, 'ativo' => true]);
        }
    }
}
