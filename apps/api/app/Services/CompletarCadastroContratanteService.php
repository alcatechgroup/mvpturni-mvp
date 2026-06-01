<?php

namespace App\Services;

use App\Domain\Cadastro\DocumentoDuplicadoException;
use App\Domain\Cadastro\DocumentoValidator;
use App\Domain\Contratos\AceiteAdesaoRenderer;
use App\Domain\Contratos\TemplateIndisponivelException;
use App\Models\AceiteEletronico;
use App\Models\ContratanteProfile;
use App\Models\Template;
use App\Models\TemplateVersao;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;

/**
 * STORY-024 — Orquestra o completar cadastro do contratante + geração do AceiteEletronico.
 *
 * Espelha CompletarCadastroProfissionalService. Contratante é sempre PJ (CNPJ). O aceite
 * referencia `termos_plataforma_contratante` (IDR-023) — template próprio do contratante,
 * com a taxa Turni 15% (PDR-004) como cláusula permanente. Aceite gerado no clique de
 * "Aceito e concluir cadastro", em transação atômica com a persistência dos campos e a
 * transição liberado → ativo + plano Member Start (CA-9/10/12).
 */
class CompletarCadastroContratanteService
{
    /** Template de adesão do contratante (IDR-023). */
    private const SLUG_TEMPLATE = 'termos_plataforma_contratante';

    /** Plano padrão na conclusão do cadastro (domain/usuario.md §Contratante/Planos). */
    private const PLANO_PADRAO = 'member_start';

    /** Taxa Turni cobrada do contratante (PDR-004). */
    private const TAXA_TURNI = '15%';

    public function __construct(private readonly AceiteAdesaoRenderer $renderer) {}

    /**
     * Preview do contrato (antes do aceite). Carimbos de assinatura ficam com marcador
     * pendente — só preenchidos no momento do aceite (IDR-022 b).
     *
     * @param  array<string,mixed>  $dados  cnpj + (opcional) campos de endereço para render
     */
    public function previewContrato(User $user, array $dados): string
    {
        return $this->renderer->renderizar(
            $this->versaoAtiva()->conteudo,
            $this->contexto($user, $dados, [
                'aceite.timestamp' => AceiteAdesaoRenderer::ASSINATURA_PENDENTE,
                'aceite.ip' => AceiteAdesaoRenderer::ASSINATURA_PENDENTE,
                'aceite.fingerprint' => AceiteAdesaoRenderer::ASSINATURA_PENDENTE,
            ]),
        );
    }

    /**
     * Conclui o cadastro: persiste campos, gera o aceite imutável e transiciona para `ativo`
     * com plano Member Start — tudo em uma transação (CA-10). Lança se CNPJ duplicado,
     * template indisponível ou renderização incompleta — nada persiste.
     *
     * @param  array<string,mixed>  $dados  campos validados (+ logo_path resolvido no controller)
     */
    public function completar(User $user, array $dados, string $ip, string $userAgent): AceiteEletronico
    {
        $profile = $user->contratanteProfile;
        $cnpjDigitos = DocumentoValidator::normalizar($dados['cnpj']);
        $hash = $this->cnpjHash($cnpjDigitos);

        // CA-3 — unicidade do CNPJ (erro genérico no controller). Index único é a 2ª camada.
        $duplicado = $profile->newQuery()
            ->where('cnpj_hash', $hash)
            ->where('user_id', '!=', $user->id)
            ->exists();
        if ($duplicado) {
            throw new DocumentoDuplicadoException;
        }

        $versao = $this->versaoAtiva();
        $aceitoEm = CarbonImmutable::now();
        $fingerprint = $this->fingerprint($userAgent, $ip, $aceitoEm);

        $contexto = $this->contexto($user, $dados, [
            'aceite.timestamp' => $aceitoEm->format('d/m/Y H:i'),
            'aceite.ip' => $ip,
            'aceite.fingerprint' => $fingerprint,
        ]);

        // Renderiza ANTES da transação: placeholder ausente => falha dura, sem efeitos colaterais.
        $conteudoRenderizado = $this->renderer->renderizar($versao->conteudo, $contexto);

        return DB::transaction(function () use (
            $profile, $user, $dados, $cnpjDigitos, $hash, $versao,
            $conteudoRenderizado, $contexto, $aceitoEm, $ip, $fingerprint
        ) {
            $profile->update([
                'cnpj_encrypted' => $cnpjDigitos,
                'cnpj_hash' => $hash,
                'cep' => $dados['cep'],
                'logradouro' => $dados['logradouro'],
                'numero' => $dados['numero'],
                'bairro' => $dados['bairro'],
                'cidade' => $dados['cidade'],
                'uf' => $dados['uf'],
                'complemento' => $dados['complemento'] ?? null,
                'endereco_completo' => $this->enderecoCompleto($dados),
                'apelido_estabelecimento' => $dados['apelido_estabelecimento'] ?? null,
                'segmento' => $dados['segmento'],
                'ano_fundacao' => $dados['ano_fundacao'],
                'qtd_funcionarios' => $dados['qtd_funcionarios'],
                'turnos_operacao' => $dados['turnos_operacao'] ?? null,
                'cultura_valores' => $dados['cultura_valores'] ?? null,
                'site' => $dados['site'] ?? null,
                'redes_sociais' => $dados['redes_sociais'] ?? null,
                'contatos_adicionais' => $dados['contatos_adicionais'] ?? [],
                'logo_path' => $dados['logo_path'] ?? $profile->logo_path,
                'plano' => self::PLANO_PADRAO,
            ]);

            $aceite = AceiteEletronico::create([
                'template_versao_id' => $versao->id,
                'user_id' => $user->id,
                'conteudo_renderizado' => $conteudoRenderizado,
                'dados_renderizados' => $contexto,
                'aceito_em' => $aceitoEm,
                'ip' => $ip,
                'fingerprint' => $fingerprint,
            ]);

            $user->update([
                'status' => 'ativo',
                'cadastro_completed_at' => $aceitoEm,
            ]);

            return $aceite;
        });
    }

    private function versaoAtiva(): TemplateVersao
    {
        $versao = Template::where('slug', self::SLUG_TEMPLATE)->first()?->versaoAtiva;

        if (! $versao) {
            throw new TemplateIndisponivelException(self::SLUG_TEMPLATE);
        }

        return $versao;
    }

    /**
     * Mapa de placeholders do aceite de adesão do contratante. Estes são os placeholders
     * disponíveis para o texto-seed `termos_plataforma_contratante` (contrato com o PO).
     * O endereço é composto a partir do payload (não do perfil ainda-não-persistido).
     *
     * @param  array<string,mixed>  $dados
     * @param  array<string,string>  $assinatura
     * @return array<string,string>
     */
    private function contexto(User $user, array $dados, array $assinatura): array
    {
        $profile = $user->contratanteProfile;

        return [
            'contratante.razao_social' => (string) $profile->nome_estabelecimento,
            'contratante.cnpj' => DocumentoValidator::formatar((string) $dados['cnpj'], 'CNPJ'),
            'contratante.endereco_completo' => $this->enderecoCompleto($dados, $profile),
            'plataforma.taxa_turni' => self::TAXA_TURNI,
            ...$assinatura,
        ];
    }

    /**
     * Compõe o endereço para exibição/persistência a partir do payload. No preview, quando
     * os campos de endereço ainda não foram enviados, cai para a cidade do perfil.
     *
     * @param  array<string,mixed>  $dados
     */
    private function enderecoCompleto(array $dados, ?ContratanteProfile $profile = null): string
    {
        if (! empty($dados['logradouro']) && ! empty($dados['cidade'])) {
            $rua = trim("{$dados['logradouro']}, ".($dados['numero'] ?? ''), ', ');
            $complemento = ! empty($dados['complemento']) ? " ({$dados['complemento']})" : '';
            $cep = ! empty($dados['cep']) ? " · CEP {$dados['cep']}" : '';

            return "{$rua}{$complemento} — {$dados['bairro']}, {$dados['cidade']}/{$dados['uf']}{$cep}";
        }

        return trim((string) ($dados['cidade'] ?? $profile?->cidade ?? ''));
    }

    /** Hash determinístico p/ unicidade do CNPJ (IDR-022 d) — valor em claro fica só no encrypted. */
    private function cnpjHash(string $cnpjDigitos): string
    {
        return hash_hmac('sha256', $cnpjDigitos, (string) config('app.key'));
    }

    /** SHA-256 de user_agent:ip:data (ADR-010 Decisão 4). */
    private function fingerprint(string $userAgent, string $ip, CarbonImmutable $em): string
    {
        return hash('sha256', $userAgent.':'.$ip.':'.$em->format('Y-m-d'));
    }
}
