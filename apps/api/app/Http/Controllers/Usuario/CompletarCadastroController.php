<?php

namespace App\Http\Controllers\Usuario;

use App\Domain\Aceites\CompletarCadastroException;
use App\Domain\Aceites\CompletarCadastroProfissional;
use App\Domain\Aceites\DocumentoDuplicadoException;
use App\Http\Controllers\Controller;
use App\Http\Requests\CompletarCadastroProfissionalRequest;
use App\Models\User;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;

/**
 * STORY-023 — Completar cadastro do profissional + geração do AceiteEletronico.
 *
 * FORA do FunnelGuard de propósito (convenção `/api/usuarios/me/*` — IDR-014): o usuário que
 * submete está em `await_cadastro`, estado que o guard bloquearia com 423. Protegido por sessão
 * (auth:web) + WebAppOnly. O aceite nasce só no clique de "Aceito e concluir cadastro" (decisão PO).
 */
class CompletarCadastroController extends Controller
{
    public function __construct(private readonly CompletarCadastroProfissional $service = new CompletarCadastroProfissional) {}

    /**
     * GET /api/usuarios/me/completar-cadastro/contexto.
     * Contexto mínimo para a tela montar o campo de documento (CPF vs CNPJ) — fora do FunnelGuard.
     */
    public function contexto(): JsonResponse
    {
        /** @var User $user */
        $user = Auth::user();
        $profile = $user->profissionalProfile;
        $tipoPessoa = $profile->tipo_pessoa;

        return response()->json([
            'tipo_pessoa' => $tipoPessoa,
            'documento_tipo' => $tipoPessoa === 'PF' ? 'CPF' : 'CNPJ',
        ]);
    }

    /**
     * POST /api/usuarios/me/completar-cadastro/preview (CA-7).
     * Renderiza o contrato com os dados do usuário, sem persistir nada. Mesmo motor do aceite.
     */
    public function preview(CompletarCadastroProfissionalRequest $request): JsonResponse
    {
        /** @var User $user */
        $user = Auth::user();
        $profile = $user->profissionalProfile;

        $conteudo = $this->service->renderizarPreview(
            $user,
            $request->validated(),
            (string) $request->ip(),
            (string) $request->userAgent(),
        );

        return response()->json([
            'tipo_pessoa' => $profile->tipo_pessoa,
            'conteudo_renderizado' => $conteudo,
        ]);
    }

    /**
     * POST /api/usuarios/me/completar-cadastro (CA-9/10/12).
     * Transação atômica: campos sensíveis + AceiteEletronico imutável + transição para `ativo`.
     */
    public function completar(CompletarCadastroProfissionalRequest $request): JsonResponse
    {
        /** @var User $user */
        $user = Auth::user();

        // Documento comprobatório em disco privado, path não-enumerável (ADR-004 / CA-5).
        $docPath = $request->file('documento_comprobatorio')->store('profissionais/documentos');

        try {
            $aceite = $this->service->executar(
                $user,
                $request->validated(),
                (string) $request->ip(),
                (string) $request->userAgent(),
                $docPath,
            );
        } catch (DocumentoDuplicadoException|UniqueConstraintViolationException $e) {
            Storage::delete($docPath);

            return response()->json([
                'message' => 'Não foi possível concluir o cadastro. Verifique os dados e tente novamente.',
                'code' => 'documento_duplicado',
            ], 422);
        } catch (CompletarCadastroException $e) {
            Storage::delete($docPath);

            return response()->json([
                'message' => 'Não foi possível concluir o cadastro. Recarregue a página e tente novamente.',
                'code' => $e->code(),
            ], 422);
        } catch (\Throwable $e) {
            // Sem aceite criado (rollback) → remove o documento órfão do storage.
            Storage::delete($docPath);
            throw $e;
        }

        // CA-17 — log estruturado (ADR-008), sem PII clara (sem nome/CPF/e-mail no contexto).
        Log::info('user.cadastro_completed', [
            'event' => 'user.cadastro_completed',
            'user_id' => $user->id,
            'role' => $user->role,
            'tipo_pessoa' => $user->profissionalProfile->tipo_pessoa,
            'template_versao_id' => $aceite->template_versao_id,
        ]);

        $user->refresh();

        return response()->json([
            'success' => true,
            'message' => 'Cadastro concluído. Bem-vindo ao Turni!',
            'status' => $user->status,
            'cadastro_completo' => $user->cadastro_completed_at !== null,
            'aceite_id' => $aceite->id,
        ], 201);
    }
}
