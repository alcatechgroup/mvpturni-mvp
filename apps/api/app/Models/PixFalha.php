<?php

namespace App\Models;

use App\Casts\ChavePixCompartilhada;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * STORY-065 (CA-5, CA-8) — um caso da fila operacional do Backoffice (PDR-010:
 * uma tentativa, tratamento manual). Carrega o SNAPSHOT operacional do instante da
 * falha (profissional, função, estabelecimento, valor, chave Pix cifrada com segredo
 * compartilhado — IDR-028): o admin lê uma tabela só. Ver a migração.
 *
 * STORY-066 (CA-4) generalizou a fila ("Falhas de pagamento" — validado pelo PO):
 * `tipo` distingue `pix` (transferência falhou; valor = o que o admin transfere) de
 * `liberacao` (liberação da pré-autorização falhou; valor = total reservado do
 * contratante; SEM chave Pix — o tratamento é no gateway).
 */
class PixFalha extends Model
{
    use HasFactory, HasUuids;

    protected $table = 'pix_falhas';

    protected $fillable = [
        'turno_id', 'tipo', 'profissional_nome', 'funcao', 'estabelecimento', 'valor',
        'chave_pix', 'razao', 'payload_gateway', 'falhou_em',
        'resolvido_em', 'resolvido_por', 'nota_resolucao',
    ];

    protected function casts(): array
    {
        return [
            'chave_pix' => ChavePixCompartilhada::class,
            'valor' => 'decimal:2',
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
     * Caso aberto: nova falha ATUALIZA razão/payload/snapshot (CA-6 — webhook pode
     * reportar falha após sucesso aparente). Caso já resolvido: permanece resolvido
     * (a resolução é decisão humana auditada); a trilha segue nos audit logs.
     */
    public static function registrar(Turno $turno, string $razao, array $payloadGateway = []): self
    {
        return self::registrarCaso($turno, 'pix', $razao, $payloadGateway);
    }

    /** STORY-066 (CA-4) — liberação da pré-autorização falhou: caso tipo `liberacao`. */
    public static function registrarLiberacao(Turno $turno, string $razao, array $payloadGateway = []): self
    {
        return self::registrarCaso($turno, 'liberacao', $razao, $payloadGateway);
    }

    private static function registrarCaso(Turno $turno, string $tipo, string $razao, array $payloadGateway): self
    {
        $dados = [
            'tipo' => $tipo,
            'razao' => $razao,
            'payload_gateway' => $payloadGateway,
            'falhou_em' => now(),
            ...self::snapshot($turno, $tipo),
        ];

        $caso = self::firstOrCreate(['turno_id' => $turno->id], $dados);

        if (! $caso->wasRecentlyCreated && $caso->resolvido_em === null) {
            $caso->update($dados);
        }

        return $caso;
    }

    /** Estado do caso no instante da falha — o que o admin precisa para tratar (CA-5/066). */
    private static function snapshot(Turno $turno, string $tipo): array
    {
        $turno->loadMissing(['vaga.funcao:id,nome', 'profissional:id,name', 'contratante.contratanteProfile']);
        $perfil = $turno->contratante?->contratanteProfile;

        return [
            'profissional_nome' => $turno->profissional?->name,
            'funcao' => $turno->vaga?->funcao?->nome,
            'estabelecimento' => $perfil?->apelido_estabelecimento
                ?: $perfil?->nome_estabelecimento
                ?: $turno->contratante?->name,
            // Pix: o que o admin transfere ao profissional. Liberação: o total reservado
            // do contratante que ficou preso no gateway. Chave Pix só faz sentido no Pix.
            'valor' => $tipo === 'liberacao' ? $turno->total_contratante : $turno->valor,
            'chave_pix' => $tipo === 'liberacao'
                ? null
                : $turno->profissional?->profissionalProfile?->chave_pix_encrypted,
        ];
    }
}
