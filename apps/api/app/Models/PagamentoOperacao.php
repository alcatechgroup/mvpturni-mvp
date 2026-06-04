<?php

namespace App\Models;

use App\Domain\Pagamento\ResultadoOperacao;
use App\Enums\StatusOperacaoPagamento;
use App\Enums\TipoOperacaoPagamento;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * STORY-056 / ADR-016 (CA-5). Uma operação financeira da ACL Pagar.me: log + idempotência +
 * correlação numa linha. Chaveada por `(turno_id, tipo_operacao)` único — repetir a operação
 * concluída devolve esta linha em vez de chamar o provedor (OperacaoIdempotente).
 */
class PagamentoOperacao extends Model
{
    use HasFactory, HasUuids;

    protected $table = 'pagamento_operacoes';

    protected $fillable = [
        'turno_id', 'tipo_operacao', 'idempotencia_chave', 'status',
        'request_payload', 'response_payload',
        'pagarme_order_id', 'pagarme_charge_id', 'pagarme_transfer_id', 'erro',
    ];

    protected function casts(): array
    {
        return [
            'tipo_operacao' => TipoOperacaoPagamento::class,
            'status' => StatusOperacaoPagamento::class,
            'request_payload' => 'array',
            'response_payload' => 'array',
        ];
    }

    public function turno(): BelongsTo
    {
        return $this->belongsTo(Turno::class);
    }

    public function concluida(): bool
    {
        return $this->status === StatusOperacaoPagamento::Concluida;
    }

    /** Primeiro identificador de correlação disponível (para log) — opaco, não PII. */
    public function pagarmeId(): ?string
    {
        return $this->pagarme_transfer_id ?? $this->pagarme_charge_id ?? $this->pagarme_order_id;
    }

    /** Reconstrói o ResultadoOperacao guardado (curto-circuito da idempotência — ADR-016 b). */
    public function resultadoGuardado(): ResultadoOperacao
    {
        return ResultadoOperacao::deOperacaoGuardada(
            $this->tipo_operacao,
            $this->status,
            $this->pagarme_order_id,
            $this->pagarme_charge_id,
            $this->pagarme_transfer_id,
            $this->response_payload ?? [],
        );
    }
}
