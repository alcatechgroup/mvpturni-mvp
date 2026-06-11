<?php

namespace App\Models;

use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * STORY-096 / ADR-020 — leitura do turno no Backoffice (a tabela CANÔNICA é do app `api`).
 * O admin só LÊ: a fila de disputas é DERIVADA do estado `em_disputa` (Decisão 4) e o caso é
 * uma agregação de leitura sobre dados já existentes (Decisão 6). A resolução "pagar integral"
 * NÃO escreve aqui — é um comando da api (IDR-032); o admin é cliente.
 *
 * `status` é string (a réplica não tem o enum/trigger da canônica — ADR-015); a comparação com
 * `em_disputa`/`finalizado` é textual.
 */
class Turno extends Model
{
    use HasFactory, HasUuids;

    protected $table = 'turnos';

    /** Estado do turno em disputa aberta (ADR-015 / domain/turno.md). */
    public const STATUS_EM_DISPUTA = 'em_disputa';

    /** SLA público de mediação da disputa (minutos) — non-functional.md / PDR-006. */
    public const SLA_MINUTOS = 30;

    protected $fillable = [
        'contratante_id', 'profissional_id', 'status', 'valor',
        'data_inicio', 'data_fim', 'check_in_at', 'check_out_at',
        'geofencing_check_in', 'geofencing_check_out', 'disputa', 'vaga_versao_id',
    ];

    protected function casts(): array
    {
        return [
            'valor' => 'decimal:2',
            'data_inicio' => 'datetime',
            'data_fim' => 'datetime',
            'check_in_at' => 'datetime',
            'check_out_at' => 'datetime',
            'geofencing_check_in' => 'array',
            'geofencing_check_out' => 'array',
            'disputa' => 'array',
        ];
    }

    public function contratante(): BelongsTo
    {
        return $this->belongsTo(User::class, 'contratante_id');
    }

    public function profissional(): BelongsTo
    {
        return $this->belongsTo(User::class, 'profissional_id');
    }

    /** Trilha imutável do turno (audit_logs escritos pela api — agregação de leitura, ADR-020 D6). */
    public function auditLogs(): HasMany
    {
        return $this->hasMany(TurnoAuditLog::class, 'target_id')
            ->where('target_type', 'Turno')
            ->orderByDesc('created_at');
    }

    /** Fila do admin = DERIVADA do estado (ADR-020 Decisão 4): sem tabela de fila. */
    public function scopeEmDisputa(Builder $query): Builder
    {
        return $query->where('status', self::STATUS_EM_DISPUTA);
    }

    /** Instante de abertura da disputa (de `turnos.disputa`), ou null se ausente/ilegível. */
    public function disputaAbertaEm(): ?CarbonImmutable
    {
        $aberta = $this->disputa['aberta_em'] ?? null;

        return $aberta ? CarbonImmutable::parse($aberta) : null;
    }

    /** Justificativa do contratante (texto livre, peça central do caso — DDR-005 Decisão 3). */
    public function justificativaContratante(): ?string
    {
        return $this->disputa['justificativa_contratante'] ?? null;
    }
}
