<?php

namespace App\Models;

use App\Enums\VagaEstado;
use DomainException;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * STORY-044 / ADR-013. Vaga publicada pelo contratante (domain/vaga.md). Estados e
 * transições guardados no domínio (Decisão 2); invariantes duras no banco (Decisão 4).
 */
class Vaga extends Model
{
    use HasFactory;

    protected $fillable = [
        'contratante_id', 'funcao_id', 'data_inicio', 'data_fim', 'valor', 'valor_hora',
        'posicoes', 'posicoes_preenchidas', 'observacoes', 'lat', 'lng', 'cidade', 'uf',
        'estado', 'versao_atual', 'publicada_em', 'fechada_em', 'cancelada_em',
    ];

    protected function casts(): array
    {
        return [
            'estado' => VagaEstado::class,
            'data_inicio' => 'datetime',
            'data_fim' => 'datetime',
            'publicada_em' => 'datetime',
            'fechada_em' => 'datetime',
            'cancelada_em' => 'datetime',
            'valor' => 'decimal:2',
            'valor_hora' => 'decimal:2',
            'lat' => 'decimal:7',
            'lng' => 'decimal:7',
            'posicoes' => 'integer',
            'posicoes_preenchidas' => 'integer',
            'versao_atual' => 'integer',
        ];
    }

    /**
     * Transição guardada (ADR-013 Decisão 2): só executa se permitida pelo enum;
     * carimba o timestamp da transição. Persiste a mudança.
     */
    public function transitionTo(VagaEstado $novo): void
    {
        if (! $this->estado->canTransitionTo($novo)) {
            throw new DomainException("Transição de vaga inválida: {$this->estado->value} → {$novo->value}");
        }

        $this->estado = $novo;
        if ($novo === VagaEstado::Fechada) {
            $this->fechada_em = now();
        }
        if ($novo === VagaEstado::Cancelada) {
            $this->cancelada_em = now();
        }
        $this->save();
    }

    /**
     * Preenche uma posição; ao igualar `posicoes`, fecha a vaga automaticamente
     * (domain/vaga.md: "ao preencher a última posição, a vaga fecha").
     */
    public function preencherPosicao(): void
    {
        $this->posicoes_preenchidas++;
        if ($this->posicoes_preenchidas >= $this->posicoes) {
            $this->transitionTo(VagaEstado::Fechada); // persiste estado + posicoes_preenchidas
        } else {
            $this->save();
        }
    }

    public function contratante(): BelongsTo
    {
        return $this->belongsTo(User::class, 'contratante_id');
    }

    public function funcao(): BelongsTo
    {
        return $this->belongsTo(Funcao::class);
    }

    public function versoes(): HasMany
    {
        return $this->hasMany(VagaVersao::class);
    }

    public function candidaturas(): HasMany
    {
        return $this->hasMany(Candidatura::class);
    }
}
