<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * STORY-065 (CA-5, CA-8) — um caso da fila "Pix com falha" do Backoffice (PDR-010:
 * uma tentativa, tratamento manual). Ver a migração para as invariantes da tabela.
 */
class PixFalha extends Model
{
    use HasFactory, HasUuids;

    protected $table = 'pix_falhas';

    protected $fillable = [
        'turno_id', 'razao', 'payload_gateway', 'falhou_em',
        'resolvido_em', 'resolvido_por', 'nota_resolucao',
    ];

    protected function casts(): array
    {
        return [
            'payload_gateway' => 'array',
            'falhou_em' => 'datetime',
            'resolvido_em' => 'datetime',
        ];
    }

    public function turno(): BelongsTo
    {
        return $this->belongsTo(Turno::class);
    }

    /**
     * Registra (ou atualiza) o caso do turno — idempotente por UNIQUE(turno_id).
     * Caso aberto: nova falha ATUALIZA razão/payload (CA-6 — webhook pode reportar
     * falha após sucesso aparente). Caso já resolvido: permanece resolvido (a
     * resolução é decisão humana auditada); a trilha segue nos audit logs.
     */
    public static function registrar(string $turnoId, string $razao, array $payloadGateway = []): self
    {
        $caso = self::firstOrCreate(
            ['turno_id' => $turnoId],
            ['razao' => $razao, 'payload_gateway' => $payloadGateway, 'falhou_em' => now()],
        );

        if (! $caso->wasRecentlyCreated && $caso->resolvido_em === null) {
            $caso->update(['razao' => $razao, 'payload_gateway' => $payloadGateway, 'falhou_em' => now()]);
        }

        return $caso;
    }
}
