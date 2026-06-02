<?php

namespace App\Services;

use App\Enums\VagaEstado;
use App\Models\AuditLog;
use App\Models\User;
use App\Models\Vaga;
use App\Models\VagaVersao;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * STORY-046 / ADR-013 — publica uma vaga do contratante de forma atômica:
 *  1. cria a `vagas` em estado `aberta` (localização derivada do perfil — ADR-013);
 *  2. grava a `vaga_versoes` versão 1 (snapshot inicial — Decisão 1);
 *  3. registra o evento de domínio `vaga.criada` em `audit_logs` (Decisão 5 / CA-6);
 *  4. emite a telemetria estruturada `vaga.publicada` (ADR-008 / CA-10).
 */
class PublicarVagaService
{
    public function __construct(private readonly Request $request) {}

    /**
     * @param  array{funcao_id:int,data_inicio:string,data_fim:string,valor:float|string,posicoes:int,observacoes?:?string}  $dados
     */
    public function publicar(User $contratante, array $dados): Vaga
    {
        return DB::transaction(function () use ($contratante, $dados) {
            $profile = $contratante->contratanteProfile;

            $vaga = Vaga::create([
                'contratante_id' => $contratante->id,
                'funcao_id' => $dados['funcao_id'],
                'data_inicio' => $dados['data_inicio'],
                'data_fim' => $dados['data_fim'],
                'valor' => $dados['valor'],
                'posicoes' => $dados['posicoes'],
                'posicoes_preenchidas' => 0,
                'observacoes' => $dados['observacoes'] ?? null,
                // Localização é snapshot do estabelecimento (ADR-013). lat/lng entram quando
                // o perfil os tiver (EPIC-003 / geofencing); até lá, cidade/uf bastam.
                'lat' => $profile->lat ?? null,
                'lng' => $profile->lng ?? null,
                'cidade' => $profile->cidade ?? null,
                'uf' => $profile->uf ?? null,
                'estado' => VagaEstado::Aberta,
                'versao_atual' => 1,
                'publicada_em' => now(),
            ]);

            VagaVersao::create([
                'vaga_id' => $vaga->id,
                'versao' => 1,
                'snapshot' => [
                    'funcao_id' => $vaga->funcao_id,
                    'data_inicio' => $vaga->data_inicio->toIso8601String(),
                    'data_fim' => $vaga->data_fim->toIso8601String(),
                    'valor' => (float) $vaga->valor,
                    'posicoes' => $vaga->posicoes,
                    'observacoes' => $vaga->observacoes,
                    'lat' => $vaga->lat !== null ? (float) $vaga->lat : null,
                    'lng' => $vaga->lng !== null ? (float) $vaga->lng : null,
                ],
                'editado_por' => $contratante->id,
            ]);

            AuditLog::create([
                'actor_id' => $contratante->id,
                'action' => 'vaga.criada',
                'target_type' => 'Vaga',
                'target_id' => $vaga->id,
                'payload' => ['funcao_id' => $vaga->funcao_id, 'posicoes' => $vaga->posicoes],
                'ip' => $this->request->ip(),
                'user_agent' => $this->request->userAgent(),
            ]);

            // Telemetria sem PII além do contratante_id já referenciado (CA-10 / ADR-008).
            Log::info('vaga.publicada', [
                'event' => 'vaga.publicada',
                'vaga_id' => $vaga->id,
                'contratante_id' => $contratante->id,
                'funcao' => $vaga->funcao_id,
                'posicoes' => $vaga->posicoes,
                'valor' => (float) $vaga->valor,
            ]);

            return $vaga;
        });
    }
}
