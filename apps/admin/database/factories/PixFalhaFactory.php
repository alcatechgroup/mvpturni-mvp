<?php

namespace Database\Factories;

use App\Models\PixFalha;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * STORY-065 — caso da fila "Pix com falha" para os testes do Backoffice. No banco real
 * quem escreve é o worker da api (snapshot do instante da falha — IDR-028).
 */
class PixFalhaFactory extends Factory
{
    protected $model = PixFalha::class;

    public function definition(): array
    {
        return [
            'turno_id' => (string) Str::uuid7(),
            'profissional_nome' => fake()->name(),
            'funcao' => 'Garçom',
            'estabelecimento' => 'Bar do Zé',
            'valor' => fake()->randomFloat(2, 80, 400),
            'chave_pix' => fake()->safeEmail(),
            'razao' => 'invalid_pix_key — chave não encontrada na instituição de destino',
            'payload_gateway' => ['transfer_id' => 'tr_'.fake()->lexify('????????')],
            'falhou_em' => now()->subHours(2),
        ];
    }
}
