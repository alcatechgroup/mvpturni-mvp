<?php

namespace App\Models;

use App\Enums\TurnoStatus;
use DomainException;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

/**
 * STORY-055 / ADR-015. Turno — unidade central do produto (domain/turno.md). Nasce de uma
 * candidatura aprovada (`confirmado`) e percorre a máquina de estados até um terminal.
 *
 * A máquina de estados é garantida em DUAS camadas (CA-4): o trigger Postgres
 * `enforce_turno_transition` é a invariante dura (à prova de SQL cru); `transitionTo()` aqui
 * é a porta ergonômica do domínio, que falha cedo (DomainException) e carimba os timestamps
 * da transição. Ambas refletem as mesmas 13 transições de TurnoStatus::canTransitionTo().
 */
class Turno extends Model
{
    use HasFactory, HasUuids;

    protected $table = 'turnos';

    protected $fillable = [
        'candidatura_id', 'vaga_id', 'vaga_versao_id', 'profissional_id', 'contratante_id',
        'estabelecimento_id', 'status', 'valor', 'taxa_turni', 'total_contratante',
        'data_inicio', 'data_fim', 'check_in_at', 'check_out_at',
        'geofencing_check_in', 'geofencing_check_out', 'cancelamento', 'disputa', 'pin_checkin_hash',
        'pin_checkin_tentativas', 'pin_checkout_hash', 'pin_checkout_tentativas',
    ];

    protected function casts(): array
    {
        return [
            'status' => TurnoStatus::class,
            'valor' => 'decimal:2',
            'taxa_turni' => 'decimal:2',
            'total_contratante' => 'decimal:2',
            'data_inicio' => 'datetime',
            'data_fim' => 'datetime',
            'check_in_at' => 'datetime',
            'check_out_at' => 'datetime',
            'geofencing_check_in' => 'array',
            'geofencing_check_out' => 'array',
            'cancelamento' => 'array',
            'disputa' => 'array',
            'pin_checkin_tentativas' => 'integer',
            'pin_checkout_tentativas' => 'integer',
        ];
    }

    /**
     * Transição guardada (ADR-015): só executa se permitida pelo enum (espelho do trigger);
     * carimba os timestamps da transição. Persiste a mudança. O trigger do banco é a rede de
     * segurança final — uma transição que passasse aqui mas violasse o trigger levantaria
     * exceção do Postgres no save().
     */
    public function transitionTo(TurnoStatus $novo): void
    {
        if (! $this->status->canTransitionTo($novo)) {
            throw new DomainException("Transição de turno inválida: {$this->status->value} → {$novo->value}");
        }

        $this->status = $novo;

        // Check-in validado (domain/turno.md: check_in = timestamp do check-in validado).
        if ($novo === TurnoStatus::Ativo && $this->check_in_at === null) {
            $this->check_in_at = now();
        }
        // Check-out validado (encerra na transição para finalizado/finalizado_ajustado).
        if (in_array($novo, [TurnoStatus::Finalizado, TurnoStatus::FinalizadoAjustado], true)
            && $this->check_out_at === null) {
            $this->check_out_at = now();
        }

        $this->save();
    }

    public function candidatura(): BelongsTo
    {
        return $this->belongsTo(Candidatura::class);
    }

    public function vaga(): BelongsTo
    {
        return $this->belongsTo(Vaga::class);
    }

    public function vagaVersao(): BelongsTo
    {
        return $this->belongsTo(VagaVersao::class);
    }

    public function profissional(): BelongsTo
    {
        return $this->belongsTo(User::class, 'profissional_id');
    }

    public function contratante(): BelongsTo
    {
        return $this->belongsTo(User::class, 'contratante_id');
    }

    public function estabelecimento(): BelongsTo
    {
        return $this->belongsTo(User::class, 'estabelecimento_id');
    }

    /** Aceite eletrônico imutável do turno (1:1 no MVP — emitido na criação). */
    public function aceite(): HasOne
    {
        return $this->hasOne(AceiteEletronicoTurno::class);
    }

    public function aceites(): HasMany
    {
        return $this->hasMany(AceiteEletronicoTurno::class);
    }

    /** Avaliações recíprocas deste turno (até 2 — uma por direção). STORY-085 / ADR-019. */
    public function avaliacoes(): HasMany
    {
        return $this->hasMany(Avaliacao::class);
    }
}
