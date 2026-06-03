<?php

namespace App\Domain\Vaga;

use App\Models\Vaga;
use Illuminate\Support\Carbon;

/**
 * STORY-052 / PDR-009 — detector de edição **material** da vaga e cálculo do diff.
 *
 * Os campos materiais são fixos por PDR-009 (STORY-044 CA-2): mudar qualquer um deles dispara
 * snapshot + revisão das candidaturas pendentes. A localização também é material, mas não é
 * editável por este fluxo (deriva do perfil do contratante — ADR-013), então não entra no
 * payload nem no diff; comparamos apenas os 6 campos que o contratante de fato edita.
 *
 * Lógica **pura** (sem banco, sem request): recebe o estado atual e o payload normalizados,
 * decide se é material e produz o diff ordenado. Testável isoladamente (CA-12 núcleo ≥ 98%).
 */
final class EdicaoMaterial
{
    /**
     * Campos materiais editáveis, em ordem canônica de exibição (SCREEN-052 §5) → rótulo + tipo.
     * O `tipo` orienta a formatação no cliente (data 24h, moeda, etc.) sem o servidor decidir UI.
     *
     * @var array<string,array{label:string,tipo:string}>
     */
    public const CAMPOS = [
        'funcao_id' => ['label' => 'Função', 'tipo' => 'funcao'],
        'data_inicio' => ['label' => 'Início', 'tipo' => 'data'],
        'data_fim' => ['label' => 'Fim', 'tipo' => 'data'],
        'valor' => ['label' => 'Valor', 'tipo' => 'valor'],
        'posicoes' => ['label' => 'Quantas pessoas', 'tipo' => 'posicoes'],
        'observacoes' => ['label' => 'Observações', 'tipo' => 'texto'],
    ];

    /**
     * Estado material normalizado de uma vaga (para comparação e snapshot).
     *
     * @return array<string,mixed>
     */
    public static function snapshotDeVaga(Vaga $vaga): array
    {
        return self::normalizar([
            'funcao_id' => $vaga->funcao_id,
            'data_inicio' => $vaga->data_inicio,
            'data_fim' => $vaga->data_fim,
            'valor' => $vaga->valor,
            'posicoes' => $vaga->posicoes,
            'observacoes' => $vaga->observacoes,
        ]);
    }

    /**
     * Estado material normalizado vindo de um payload validado (PATCH).
     *
     * @param  array<string,mixed>  $payload
     * @return array<string,mixed>
     */
    public static function snapshotDePayload(array $payload): array
    {
        return self::normalizar([
            'funcao_id' => $payload['funcao_id'] ?? null,
            'data_inicio' => $payload['data_inicio'] ?? null,
            'data_fim' => $payload['data_fim'] ?? null,
            'valor' => $payload['valor'] ?? null,
            'posicoes' => $payload['posicoes'] ?? null,
            'observacoes' => $payload['observacoes'] ?? null,
        ]);
    }

    /**
     * Diff campo-a-campo entre dois snapshots normalizados, na ordem canônica de [CAMPOS].
     * Cada item: `{ campo, label, tipo, antes, depois }`. Vazio ⇒ edição **não** material.
     *
     * @param  array<string,mixed>  $antes
     * @param  array<string,mixed>  $depois
     * @return list<array{campo:string,label:string,tipo:string,antes:mixed,depois:mixed}>
     */
    public static function diff(array $antes, array $depois): array
    {
        $mudancas = [];
        foreach (self::CAMPOS as $campo => $meta) {
            $a = $antes[$campo] ?? null;
            $b = $depois[$campo] ?? null;
            if (! self::igual($campo, $a, $b)) {
                $mudancas[] = [
                    'campo' => $campo,
                    'label' => $meta['label'],
                    'tipo' => $meta['tipo'],
                    'antes' => self::paraSaida($campo, $a),
                    'depois' => self::paraSaida($campo, $b),
                ];
            }
        }

        return $mudancas;
    }

    /** É edição material? (algum campo material diferiu) */
    public static function ehMaterial(array $antes, array $depois): bool
    {
        return self::diff($antes, $depois) !== [];
    }

    /** Normaliza os tipos para comparação estável (datas → Carbon, valor → 2 casas, texto → trim). */
    private static function normalizar(array $dados): array
    {
        return [
            'funcao_id' => $dados['funcao_id'] !== null ? (int) $dados['funcao_id'] : null,
            'data_inicio' => self::data($dados['data_inicio']),
            'data_fim' => self::data($dados['data_fim']),
            'valor' => $dados['valor'] !== null ? number_format((float) $dados['valor'], 2, '.', '') : null,
            'posicoes' => $dados['posicoes'] !== null ? (int) $dados['posicoes'] : null,
            // null e '' são equivalentes para "sem observação"; trim para ignorar só-espaço.
            'observacoes' => self::texto($dados['observacoes']),
        ];
    }

    private static function data(mixed $v): ?Carbon
    {
        if ($v === null) {
            return null;
        }

        return $v instanceof Carbon ? $v : Carbon::parse($v);
    }

    private static function texto(mixed $v): ?string
    {
        if ($v === null) {
            return null;
        }
        $t = trim((string) $v);

        return $t === '' ? null : $t;
    }

    private static function igual(string $campo, mixed $a, mixed $b): bool
    {
        if ($a instanceof Carbon && $b instanceof Carbon) {
            return $a->equalTo($b);
        }

        // null === null, e os escalares já estão normalizados (string/int).
        return $a === $b;
    }

    /** Valor pronto para o JSON do diff: datas em ISO-8601, demais como já normalizados. */
    private static function paraSaida(string $campo, mixed $v): mixed
    {
        if ($v instanceof Carbon) {
            return $v->toIso8601String();
        }
        if ($campo === 'valor' && $v !== null) {
            return (float) $v;
        }

        return $v;
    }
}
