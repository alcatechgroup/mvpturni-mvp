<?php

namespace App\Domain\Match;

/**
 * STORY-045 / ADR-014 (CA-2, CA-3, CA-4). Núcleo do algoritmo de Match. Função PURA:
 * sem leitura de banco, sem clock, sem container — entradas explícitas via MatchInput.
 * Pesos canônicos de business-rules.md / domain/match.md (não reabertos aqui):
 *   Função 40 (primária) · 25 (secundária) · 0
 *   Distância 20 (no raio) · 0
 *   Histórico 30 linear entre 4.0★→0 e 5.0★→30 (0 turnos = 0)
 *   Nível 10 Elite · 6 Destaque · 3 Confiável · 0 Iniciante
 * Total cap 100 (aplicado no MatchScore).
 */
final class MatchCalculator
{
    public function calcular(MatchInput $input): MatchScore
    {
        return new MatchScore(
            $this->funcao($input),
            $this->distancia($input),
            $this->historico($input),
            $this->nivel($input),
        );
    }

    private function funcao(MatchInput $input): BreakdownItem
    {
        if ($input->funcaoVagaId === $input->funcaoPrimariaProfId) {
            return new BreakdownItem(40, 40, EstadoComponente::Ok, 'Sua função primária bate');
        }

        if (in_array($input->funcaoVagaId, $input->funcoesSecundariasProfIds, true)) {
            return new BreakdownItem(25, 40, EstadoComponente::Partial, 'Uma função secundária bate');
        }

        return new BreakdownItem(0, 40, EstadoComponente::Miss, 'Função não corresponde');
    }

    private function distancia(MatchInput $input): BreakdownItem
    {
        if ($input->distanciaKm === null) {
            return new BreakdownItem(0, 20, EstadoComponente::Miss, 'Localização indisponível');
        }

        if ($input->distanciaKm <= $input->raioMaxKm) {
            return new BreakdownItem(20, 20, EstadoComponente::Ok, "Dentro do seu raio de {$input->raioMaxKm}km");
        }

        return new BreakdownItem(0, 20, EstadoComponente::Miss, "Fora do seu raio de {$input->raioMaxKm}km");
    }

    private function historico(MatchInput $input): BreakdownItem
    {
        // Sem turnos ou sem score consolidado → não pontua nesta dimensão (domain/match.md).
        if ($input->turnosRealizados <= 0 || $input->scoreHistorico === null) {
            return new BreakdownItem(0, 30, EstadoComponente::Miss, 'Sem histórico de turnos');
        }

        // Linear entre 4.0★ (0) e 5.0★ (30); clampado fora desse intervalo.
        $fracao = max(0.0, min(1.0, $input->scoreHistorico - 4.0));
        $pontos = (int) round($fracao * 30);

        $estado = match (true) {
            $pontos >= 30 => EstadoComponente::Ok,
            $pontos > 0 => EstadoComponente::Partial,
            default => EstadoComponente::Miss,
        };

        $media = number_format($input->scoreHistorico, 1, '.', '');

        return new BreakdownItem($pontos, 30, $estado, "Sua média {$media}★ em {$input->turnosRealizados} turnos");
    }

    private function nivel(MatchInput $input): BreakdownItem
    {
        $chave = $input->nivel !== null ? mb_strtolower(trim($input->nivel)) : null;

        [$pontos, $label] = match ($chave) {
            'iniciante' => [0, 'Iniciante'],
            'confiavel', 'confiável' => [3, 'Confiável'],
            'destaque' => [6, 'Destaque'],
            'elite' => [10, 'Elite'],
            default => [0, null],
        };

        if ($label === null) {
            return new BreakdownItem(0, 10, EstadoComponente::Miss, 'Nível não definido');
        }

        $estado = match (true) {
            $pontos >= 10 => EstadoComponente::Ok,
            $pontos > 0 => EstadoComponente::Partial,
            default => EstadoComponente::Miss,
        };

        return new BreakdownItem($pontos, 10, $estado, "{$label} na trilha");
    }
}
