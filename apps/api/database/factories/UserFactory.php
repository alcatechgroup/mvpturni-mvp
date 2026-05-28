<?php

namespace Database\Factories;

use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

/**
 * @extends Factory<User>
 */
class UserFactory extends Factory
{
    protected static ?string $password;

    public function definition(): array
    {
        return [
            'name' => fake()->name(),
            'email' => fake()->unique()->safeEmail(),
            'email_verified_at' => now(),
            'password' => static::$password ??= Hash::make('password'),
            'remember_token' => Str::random(10),
            'role' => 'profissional',
            'status' => 'pendente_aprovacao',
            'welcome_seen_at' => null,
            'cadastro_completed_at' => null,
        ];
    }

    public function unverified(): static
    {
        return $this->state(fn (array $attributes) => [
            'email_verified_at' => null,
        ]);
    }

    public function admin(): static
    {
        return $this->state(fn (array $attributes) => [
            'role' => 'admin',
            'status' => 'ativo',
            'welcome_seen_at' => null,
            'cadastro_completed_at' => null,
        ]);
    }

    public function contratante(): static
    {
        return $this->state(fn (array $attributes) => [
            'role' => 'contratante',
            'status' => 'pendente_aprovacao',
        ]);
    }

    public function profissional(): static
    {
        return $this->state(fn (array $attributes) => [
            'role' => 'profissional',
            'status' => 'pendente_aprovacao',
        ]);
    }

    public function ativo(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => 'ativo',
            'welcome_seen_at' => now(),
            'cadastro_completed_at' => now(),
        ]);
    }

    public function liberado(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => 'liberado',
            'welcome_seen_at' => null,
            'cadastro_completed_at' => null,
        ]);
    }

    public function liberadoWelcomeVisto(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => 'liberado',
            'welcome_seen_at' => now(),
            'cadastro_completed_at' => null,
        ]);
    }

    public function pendenteAprovacao(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => 'pendente_aprovacao',
            'welcome_seen_at' => null,
            'cadastro_completed_at' => null,
        ]);
    }
}
