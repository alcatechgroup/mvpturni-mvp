<?php

namespace Database\Seeders;

use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    public function run(): void
    {
        // Seed mínimo da fundação (STORY-006): só o admin de teste.
        // Dados de domínio (vagas, candidaturas, etc.) entram no EPIC-001.
        $this->call(AdminUserSeeder::class);
    }
}
