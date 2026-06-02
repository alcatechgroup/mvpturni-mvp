<?php

namespace App\Models;

use App\Enums\CandidaturaEstado;
use DomainException;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * STORY-044 / ADR-013. Candidatura de um profissional a uma vaga (domain/candidatura.md).
 * Transições guardadas no domínio (Decisão 2). Gate de criação (PDR-005/PDR-002,
 * conflito de horário) é aplicado na estória de candidatura (STORY-050), não aqui.
 */
class Candidatura extends Model
{
    use HasFactory;

    protected $table = 'candidaturas';

    protected $fillable = [
        'vaga_id', 'profissional_id', 'estado', 'vaga_versao_id', 'score_no_momento',
        'score_breakdown', 'alerta_habitualidade',
        'revisao_prazo_em', 'aprovada_em', 'retirada_em',
    ];

    protected function casts(): array
    {
        return [
            'estado' => CandidaturaEstado::class,
            'score_no_momento' => 'integer',
            // Snapshot do breakdown explicável no instante da candidatura (STORY-051 CA-4):
            // shape de MatchScore::toArray(); o painel do contratante lê sem recalcular.
            'score_breakdown' => 'array',
            'alerta_habitualidade' => 'boolean',
            'revisao_prazo_em' => 'datetime',
            'aprovada_em' => 'datetime',
            'retirada_em' => 'datetime',
        ];
    }

    /** Transição guardada (ADR-013 Decisão 2); carimba timestamp da transição. */
    public function transitionTo(CandidaturaEstado $novo): void
    {
        if (! $this->estado->canTransitionTo($novo)) {
            throw new DomainException("Transição de candidatura inválida: {$this->estado->value} → {$novo->value}");
        }

        $this->estado = $novo;
        if ($novo === CandidaturaEstado::Aprovada) {
            $this->aprovada_em = now();
        }
        if (in_array($novo, [CandidaturaEstado::Retirada, CandidaturaEstado::RetiradaPorEdicao], true)) {
            $this->retirada_em = now();
        }
        $this->save();
    }

    public function vaga(): BelongsTo
    {
        return $this->belongsTo(Vaga::class);
    }

    public function profissional(): BelongsTo
    {
        return $this->belongsTo(User::class, 'profissional_id');
    }

    public function vagaVersao(): BelongsTo
    {
        return $this->belongsTo(VagaVersao::class);
    }
}
