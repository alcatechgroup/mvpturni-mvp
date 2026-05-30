<?php

namespace Turni\Domain\Email;

use RuntimeException;

/**
 * Exceção de domínio para falha de envio (ADR-011 §g). O adapter captura a exceção do
 * SDK do provedor e a relança como esta — assim o dispatcher de jobs do Laravel a trata
 * como falha do job (retry/backoff/dead-letter) sem que nenhuma camada fora do adapter
 * conheça exceções do Resend.
 */
class EmailTransacionalException extends RuntimeException
{
}
