<?php

namespace App\Domain\Aceites;

use App\Models\AceiteEletronico;
use App\Models\Template;
use App\Models\TemplateVersao;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

/**
 * STORY-023 — Núcleo do completar-cadastro do profissional + geração do AceiteEletronico.
 *
 * Decisão PO (EPIC-001): o aceite nasce no clique de "Aceito e concluir cadastro" — aqui.
 * Tudo numa transação atômica (CA-10): campos sensíveis (criptografados em repouso, ADR-009) +
 * AceiteEletronico imutável (ADR-010) + transição `liberado → ativo`. Qualquer falha → rollback
 * total, estado anterior preservado.
 */
class CompletarCadastroProfissional
{
    public function __construct(private readonly AceiteRenderer $renderer = new AceiteRenderer) {}

    /**
     * Renderiza o contrato de adesão para PREVIEW (sem persistir nada). Mesmo motor e contexto
     * do aceite final — fonte única de verdade (CA-7/CA-9).
     *
     * @param  array<string,mixed>  $dados
     */
    public function renderizarPreview(User $user, array $dados, string $ip, string $userAgent, ?Carbon $aceitoEm = null): string
    {
        $aceitoEm ??= now();
        $profile = $user->profissionalProfile;
        $versao = $this->versaoAtivaPara($profile->tipo_pessoa);
        $contexto = $this->montarContexto($user, $dados, $ip, $userAgent, $aceitoEm);

        return $this->renderer->renderAdesao($versao->conteudo, $contexto);
    }

    /**
     * Executa o completar-cadastro de forma atômica e retorna o aceite criado.
     *
     * @param  array<string,mixed>  $dados  documento, funcoes_secundarias, raio_max_km, preco_hora, bio, chave_pix
     *
     * @throws CompletarCadastroException
     */
    public function executar(
        User $user,
        array $dados,
        string $ip,
        string $userAgent,
        ?string $documentoComprobatorioPath,
        ?Carbon $aceitoEm = null,
    ): AceiteEletronico {
        $aceitoEm ??= now();

        return DB::transaction(function () use ($user, $dados, $ip, $userAgent, $documentoComprobatorioPath, $aceitoEm): AceiteEletronico {
            // Trava a linha do usuário até o fim da transação (evita corrida de duplo-submit).
            $user = User::query()->whereKey($user->getKey())->lockForUpdate()->firstOrFail();

            $estado = $user->funnelState();
            if ($estado !== 'await_cadastro') {
                throw new FunilInvalidoException($estado);
            }

            $profile = $user->profissionalProfile;
            $tipoPessoa = $profile->tipo_pessoa;

            $documento = DocumentoValidator::normalizar((string) $dados['documento']);
            $hash = $this->documentoHash($documento);

            // CA-3 — unicidade do documento no sistema (sobre o hash determinístico).
            $duplicado = $profile->newQuery()
                ->where('documento_hash', $hash)
                ->where('user_id', '!=', $user->id)
                ->exists();
            if ($duplicado) {
                throw new DocumentoDuplicadoException;
            }

            $versao = $this->versaoAtivaPara($tipoPessoa);
            $contexto = $this->montarContexto($user, $dados, $ip, $userAgent, $aceitoEm);
            $conteudoRenderizado = $this->renderer->renderAdesao($versao->conteudo, $contexto);

            // Campos sensíveis criptografados em repouso pelo Encrypted Cast (ADR-009).
            $profile->forceFill([
                'documento_encrypted' => $documento,
                'documento_tipo' => DocumentoValidator::tipoEsperado($tipoPessoa),
                'documento_hash' => $hash,
                'funcoes_secundarias' => $dados['funcoes_secundarias'] ?? [],
                'raio_max_km' => $dados['raio_max_km'],
                'preco_hora' => $dados['preco_hora'],
                'bio' => $dados['bio'] ?? null,
                'chave_pix_encrypted' => $dados['chave_pix'],
                'documento_comprobatorio_path' => $documentoComprobatorioPath,
            ])->save();

            $aceite = AceiteEletronico::create([
                'template_versao_id' => $versao->id,
                'user_id' => $user->id,
                'conteudo_renderizado' => $conteudoRenderizado,
                'dados_renderizados' => $contexto,
                'ip' => $ip,
                'fingerprint' => $this->fingerprint($userAgent, $ip, $aceitoEm),
            ]);

            // Transição atômica liberado → ativo (ADR-009 Decisão 2).
            $user->forceFill([
                'status' => 'ativo',
                'cadastro_completed_at' => $aceitoEm,
            ])->save();

            return $aceite;
        });
    }

    /**
     * Mapa flat `ns.campo => valor` para a renderização da Seção 1 + Assinatura (adesão).
     *
     * @param  array<string,mixed>  $dados
     * @return array<string,string>
     */
    private function montarContexto(User $user, array $dados, string $ip, string $userAgent, Carbon $aceitoEm): array
    {
        $profile = $user->profissionalProfile;
        $tipoPessoa = $profile->tipo_pessoa;
        $documento = DocumentoValidator::normalizar((string) $dados['documento']);

        return [
            'profissional.nome' => $user->name,
            'profissional.documento' => DocumentoValidator::formatar($documento, $tipoPessoa),
            // Endereço não é coletado no completar-cadastro (story §3): composto do pré-cadastro.
            'profissional.endereco_completo' => trim(($profile->bairro ?? '').', '.($profile->cidade ?? ''), ', '),
            'aceite.timestamp' => $aceitoEm->format('d/m/Y H:i:s'),
            'aceite.ip' => $ip,
            'aceite.fingerprint' => $this->fingerprint($userAgent, $ip, $aceitoEm),
        ];
    }

    /** Versão ativa do template aplicável ao tipo de pessoa (PDR-001). */
    private function versaoAtivaPara(string $tipoPessoa): TemplateVersao
    {
        $slug = $tipoPessoa === 'PF' ? 'pf_autonomo_eventual' : 'mei_pj_b2b';

        $template = Template::where('slug', $slug)->with('versaoAtiva')->first();
        $versao = $template?->versaoAtiva;

        if ($versao === null) {
            throw new TemplateIndisponivelException($slug);
        }

        return $versao;
    }

    /**
     * Hash determinístico do documento para enforçar unicidade sobre dado criptografado
     * (ADR-009 §evolução). HMAC-SHA256 com pepper = APP_KEY (secret estável por ambiente).
     */
    private function documentoHash(string $documentoNormalizado): string
    {
        return hash_hmac('sha256', $documentoNormalizado, (string) config('app.key'));
    }

    /** ADR-010 §campos — fingerprint = SHA-256 de `user_agent:ip:data`. */
    private function fingerprint(string $userAgent, string $ip, Carbon $aceitoEm): string
    {
        return hash('sha256', $userAgent.':'.$ip.':'.$aceitoEm->format('Y-m-d'));
    }
}
