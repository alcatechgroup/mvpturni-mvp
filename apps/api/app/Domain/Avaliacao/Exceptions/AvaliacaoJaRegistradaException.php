<?php

namespace App\Domain\Avaliacao\Exceptions;

use DomainException;

/**
 * STORY-085 (CA-3) — uma avaliação por direção por turno (UNIQUE — ADR-019 Decisão 1).
 * Reenvio na mesma direção é rejeitado (idempotência de produto: avaliação é imutável de fato).
 */
class AvaliacaoJaRegistradaException extends DomainException {}
