<?php

namespace App\Domain\Avaliacao\Exceptions;

use DomainException;

/**
 * STORY-085 (CA-3) — só quem participou do turno avalia, na direção correta (RBAC fail-secure,
 * ADR-007/019). Quem não é o profissional nem o contratante do turno não pode avaliar.
 */
class NaoParticipanteDoTurnoException extends DomainException {}
