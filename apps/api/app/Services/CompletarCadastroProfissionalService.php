<?php

namespace App\Services;

use App\Domain\Cadastro\DocumentoDuplicadoException;
use App\Domain\Cadastro\DocumentoValidator;
use App\Domain\Contratos\AceiteAdesaoRenderer;
use App\Domain\Contratos\TemplateIndisponivelException;
use App\Models\AceiteEletronico;
use App\Models\Template;
use App\Models\TemplateVersao;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;

/**
 * STORY-023 — Orquestra o completar cadastro do profissional + geração do AceiteEletronico.
 *
 * Decisão PO (EPIC-001): o aceite é gerado no clique explícito de "Aceito e concluir cadastro",
 * em transação atômica com a persistência dos campos e a transição liberado → ativo (CA-10).
 */
class CompletarCadastroProfissionalService
{
    /** tipo_pessoa → slug do template aplicável (PDR-001 / ADR-010). */
    private const SLUG_POR_TIPO = [
        'PF' => 'pf_autonomo_eventual',
        'MEI' => 'mei_pj_b2b',
        'PJ' => 'mei_pj_b2b',
    ];

    public function __construct(private readonly AceiteAdesaoRenderer $renderer) {}

    /**
     * Renderiza o contrato para o PREVIEW (antes do aceite). Campos de assinatura ficam
     * com marcador pendente — só são preenchidos no momento do aceite (IDR-022 b).
     */
    public function previewContrato(User $user, string $documento): string
    {
        $versao = $this->versaoAtiva($user);

        return $this->renderer->renderizar(
            $versao->conteudo,
            $this->contexto($user, $documento, [
                'aceite.timestamp' => AceiteAdesaoRenderer::ASSINATURA_PENDENTE,
                'aceite.ip' => AceiteAdesaoRenderer::ASSINATURA_PENDENTE,
                'aceite.fingerprint' => AceiteAdesaoRenderer::ASSINATURA_PENDENTE,
            ]),
        );
    }

    /**
     * Conclui o cadastro: persiste campos sensíveis, gera o aceite imutável e transiciona
     * para `ativo` — tudo em uma transação (CA-10). Lança se documento duplicado, template
     * indisponível ou renderização incompleta — nada persiste.
     *
     * @param  array<string,mixed>  $dados  campos validados + documentos_comprobatorios (paths)
     */
    public function completar(User $user, array $dados, string $ip, string $userAgent): AceiteEletronico
    {
        $profile = $user->profissionalProfile;
        $tipoDocumento = DocumentoValidator::tipoDocumento($profile->tipo_pessoa);
        $documentoDigitos = DocumentoValidator::normalizar($dados['documento']);
        $hash = $this->documentoHash($documentoDigitos);

        // CA-3 — unicidade do documento (erro genérico no controller). Index único é a 2ª camada.
        $duplicado = $profile->newQuery()
            ->where('documento_hash', $hash)
            ->where('user_id', '!=', $user->id)
            ->exists();
        if ($duplicado) {
            throw new DocumentoDuplicadoException;
        }

        $versao = $this->versaoAtiva($user);
        $aceitoEm = CarbonImmutable::now();
        $fingerprint = $this->fingerprint($userAgent, $ip, $aceitoEm);

        $contexto = $this->contexto($user, $dados['documento'], [
            'aceite.timestamp' => $aceitoEm->format('d/m/Y H:i'),
            'aceite.ip' => $ip,
            'aceite.fingerprint' => $fingerprint,
        ]);

        // Renderiza ANTES da transação: placeholder ausente => falha dura, sem efeitos colaterais.
        $conteudoRenderizado = $this->renderer->renderizar($versao->conteudo, $contexto);

        return DB::transaction(function () use (
            $profile, $user, $dados, $tipoDocumento, $hash, $versao,
            $conteudoRenderizado, $contexto, $aceitoEm, $ip, $fingerprint
        ) {
            $profile->update([
                'documento_encrypted' => DocumentoValidator::normalizar($dados['documento']),
                'documento_tipo' => $tipoDocumento,
                'documento_hash' => $hash,
                'funcoes_secundarias' => $dados['funcoes_secundarias'] ?? [],
                'raio_max_km' => $dados['raio_max_km'],
                'preco_hora' => $dados['preco_hora'],
                'bio' => $dados['bio'] ?? null,
                'chave_pix_encrypted' => $dados['chave_pix'],
                'documentos_comprobatorios' => $dados['documentos_comprobatorios'],
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

            // Transição atômica liberado → ativo (ADR-009 Decisão 2).
            $user->update([
                'status' => 'ativo',
                'cadastro_completed_at' => $aceitoEm,
            ]);

            return $aceite;
        });
    }

    /** Versão ativa do template aplicável ao tipo de pessoa do usuário. */
    private function versaoAtiva(User $user): TemplateVersao
    {
        $slug = self::SLUG_POR_TIPO[$user->profissionalProfile->tipo_pessoa] ?? null;

        $versao = $slug
            ? Template::where('slug', $slug)->first()?->versaoAtiva
            : null;

        if (! $versao) {
            throw new TemplateIndisponivelException((string) $slug);
        }

        return $versao;
    }

    /**
     * Mapa de placeholders do aceite de adesão (Seção 1 + assinatura).
     *
     * @param  array<string,string>  $assinatura
     * @return array<string,string>
     */
    private function contexto(User $user, string $documento, array $assinatura): array
    {
        $profile = $user->profissionalProfile;
        $tipoDocumento = DocumentoValidator::tipoDocumento($profile->tipo_pessoa);

        return [
            'profissional.nome' => $user->name,
            'profissional.documento' => DocumentoValidator::formatar($documento, $tipoDocumento),
            'profissional.endereco_completo' => trim("{$profile->bairro}, {$profile->cidade}", ', '),
            ...$assinatura,
        ];
    }

    /** Hash determinístico p/ unicidade do documento (IDR-022 d) — valor em claro fica só no encrypted. */
    private function documentoHash(string $documentoDigitos): string
    {
        return hash_hmac('sha256', $documentoDigitos, (string) config('app.key'));
    }

    /** SHA-256 de user_agent:ip:data (ADR-010 Decisão 4) — contexto de sessão p/ evidência. */
    private function fingerprint(string $userAgent, string $ip, CarbonImmutable $em): string
    {
        return hash('sha256', $userAgent.':'.$ip.':'.$em->format('Y-m-d'));
    }
}
