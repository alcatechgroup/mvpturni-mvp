<?php

// STORY-016 — CA-12 — Seed de homolog

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

test('seed cria admin@turni.local com role admin e status ativo', function () {
    $this->seed(\Database\Seeders\DatabaseSeeder::class);

    $admin = User::where('email', 'admin@turni.local')->first();
    expect($admin)->not->toBeNull();
    expect($admin->role)->toBe('admin');
    expect($admin->status)->toBe('ativo');
});

test('seed cria contratante.teste@turni.local com role e status corretos', function () {
    $this->seed(\Database\Seeders\DatabaseSeeder::class);

    $user = User::where('email', 'contratante.teste@turni.local')->first();
    expect($user)->not->toBeNull();
    expect($user->role)->toBe('contratante');
    expect($user->status)->toBe('ativo');
});

test('seed cria profissional.teste@turni.local com role e tipo_pessoa corretos', function () {
    $this->seed(\Database\Seeders\DatabaseSeeder::class);

    $user = User::where('email', 'profissional.teste@turni.local')->first();
    expect($user)->not->toBeNull();
    expect($user->role)->toBe('profissional');
    expect($user->status)->toBe('ativo');
    expect($user->profissionalProfile->tipo_pessoa)->toBe('MEI');
});

test('seed é idempotente — rodar duas vezes produz os mesmos 3 usuários', function () {
    $this->seed(\Database\Seeders\DatabaseSeeder::class);
    $this->seed(\Database\Seeders\DatabaseSeeder::class);

    expect(User::where('email', 'admin@turni.local')->count())->toBe(1);
    expect(User::where('email', 'contratante.teste@turni.local')->count())->toBe(1);
    expect(User::where('email', 'profissional.teste@turni.local')->count())->toBe(1);
});

test('senha do seed nunca aparece em log ou serialização JSON', function () {
    $this->seed(\Database\Seeders\DatabaseSeeder::class);

    $user = User::where('email', 'admin@turni.local')->first();
    $json = $user->toJson();
    $array = $user->toArray();

    expect($json)->not->toContain('password');
    expect($array)->not->toHaveKey('password');
    expect($array)->not->toHaveKey('remember_token');
});
