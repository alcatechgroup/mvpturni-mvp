<?php

namespace App\Http\Controllers\Cadastro;

use App\Domain\Cadastro\DocumentoDuplicadoException;
use App\Domain\Cadastro\DocumentoValidator;
use App\Domain\Contratos\TemplateIndisponivelException;
use App\Http\Controllers\Controller;
use App\Http\Requests\CompletarCadastroProfissionalRequest;
use App\Models\User;
use App\Services\CompletarCadastroProfissionalService;
use Illuminate\Database\QueryException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;

/**
 * STORY-023 — Completar cadastro do profissional + geração do AceiteEletronico.
 *
 *  - preview(): renderiza o contrato com os dados informados (carimbos de assinatura
 *    pendentes) para o último passo do formulário, antes do aceite.
 *  - store(): no clique de "Aceito e concluir cadastro", gera o aceite imutável em
 *    transação atômica e transiciona o usuário para `ativo` (CA-9/10/12).
 *
 * Fora do FunnelGuard: o usuário aqui está em `await_cadastro` (o guard o bloquearia).
 * O authorize() do FormRequest garante o estado correto.
 */
class CompletarCadastroProfissionalController extends Controller
{
    public function __construct(private readonly CompletarCadastroProfissionalService $service) {}

    /** Preview do contrato renderizado (CA-7). Não persiste nada. */
    public function preview(Request $request): JsonResponse
    {
        $user = $this->profissionalEmCadastro($request);

        $data = $request->validate(['documento' => ['required', 'string', 'max:20']]);

        $tipoPessoa = $user->profissionalProfile->tipo_pessoa;
        if (! DocumentoValidator::validarParaTipoPessoa($tipoPessoa, $data['documento'])) {
            $doc = DocumentoValidator::tipoDocumento($tipoPessoa);

            return response()->json([
                'message' => "Informe um {$doc} válido para visualizar o contrato.",
                'errors' => ['documento' => ["Informe um {$doc} válido."]],
            ], 422);
        }

        return response()->json([
            'conteudo' => $this->service->previewContrato($user, $data['documento']),
        ]);
    }

    /** Aceite final: gera o AceiteEletronico e conclui o cadastro (CA-9/10/12). */
    public function store(CompletarCadastroProfissionalRequest $request): JsonResponse
    {
        $user = $request->user();
        $dados = $request->safe()->except('documentos_comprobatorios');

        // Documentos comprobatórios em disco privado, path não-enumerável (CA-5 / ADR-004).
        $paths = [];
        foreach ($request->file('documentos_comprobatorios') as $arquivo) {
            $paths[] = $arquivo->store('profissionais/documentos');
        }
        $dados['documentos_comprobatorios'] = $paths;

        try {
            $aceite = $this->service->completar(
                $user,
                $dados,
                (string) $request->ip(),
                (string) $request->userAgent(),
            );
        } catch (DocumentoDuplicadoException|QueryException $e) {
            $this->limparArquivos($paths);

            // Index único é a 2ª camada (corrida) — mas só trata violação de unicidade aqui.
            if ($e instanceof QueryException && ! str_contains($e->getMessage(), 'documento_hash')) {
                throw $e;
            }

            return response()->json([
                'message' => 'Não foi possível concluir o cadastro. Verifique os dados e tente novamente.',
                'errors' => ['documento' => ['Não foi possível usar este documento.']],
            ], 422);
        } catch (TemplateIndisponivelException $e) {
            $this->limparArquivos($paths);
            Log::error('cadastro.template_indisponivel', ['user_id' => $user->id, 'erro' => $e->getMessage()]);

            return response()->json([
                'message' => 'Contrato indisponível no momento. Tente novamente em instantes.',
            ], 503);
        } catch (\Throwable $e) {
            $this->limparArquivos($paths);
            throw $e;
        }

        // CA-17 — log estruturado (ADR-008), sem dado pessoal claro.
        Log::info('user.cadastro_completed', [
            'event' => 'user.cadastro_completed',
            'user_id' => $user->id,
            'role' => $user->role,
            'tipo_pessoa' => $user->profissionalProfile->tipo_pessoa,
            'template_versao_id' => $aceite->template_versao_id,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Cadastro concluído! Aceite registrado.',
            'aceite_id' => $aceite->id,
        ], 201);
    }

    private function profissionalEmCadastro(Request $request): User
    {
        $user = $request->user();

        abort_unless(
            $user !== null && $user->isProfissional() && $user->funnelState() === 'await_cadastro',
            403,
            'Acesso restrito ao completar cadastro do profissional.',
        );

        return $user;
    }

    /** @param list<string> $paths */
    private function limparArquivos(array $paths): void
    {
        foreach ($paths as $path) {
            Storage::delete($path);
        }
    }
}
