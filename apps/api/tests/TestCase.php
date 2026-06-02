<?php

namespace Tests;

use Illuminate\Foundation\Testing\TestCase as BaseTestCase;

abstract class TestCase extends BaseTestCase
{
    // STORY-044 — `migrate:fresh` do RefreshDatabase dropa tabelas mas NÃO os tipos enum
    // nativos do Postgres (vaga_estado, candidatura_estado — ADR-013 CA-4). Sem isto, a
    // 2ª migração da suíte falha com "type already exists". `--drop-types` resolve.
    protected bool $dropTypes = true;
}
