<?php

namespace App\Http\Controllers\Cadastro;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreProfissionalPreCadastroRequest;
use App\Models\ProfissionalProfile;
use App\Models\User;
use App\Support\Pii;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;

/**
 * STORY-017 — Pré-cadastro público de profissional (PF/MEI/PJ).
 *
 * Cria User(role=profissional, status=pendente_aprovacao) + ProfissionalProfile com
 * os campos mínimos pré-aprovação (domain/usuario.md). NÃO autentica o usuário —
 * ele aguarda aprovação manual (SLA 24h). NÃO coleta documento (PDR-001 / CA-14).
 */
class ProfissionalCadastroController extends Controller
{
    public function store(StoreProfissionalPreCadastroRequest $request): JsonResponse
    {
        $data = $request->validated();

        // CA-4 — proteção contra enumeração: verificação server-side da unicidade do
        // e-mail (chave única do sistema, domain/usuario.md), com resposta genérica
        // que não revela se o e-mail já existe.
        if (User::where('email', $data['email'])->exists()) {
            return response()->json([
                'message' => 'Não foi possível concluir o cadastro. Verifique os dados e tente novamente.',
                'code' => 'cadastro_nao_concluido',
                'hint' => 'Já tem conta? Faça login.',
            ], 422);
        }

        // Foto em path não-enumerável (hash aleatório do store) no disco configurado
        // (ADR-004: local/minio em dev, Cloud Storage em prod). Disco privado — sem
        // URL pública direta; o admin acessa via rota controlada na STORY-019 (CA-13).
        $fotoPath = $request->file('foto')->store('profissionais/fotos');

        try {
            $user = DB::transaction(function () use ($data, $fotoPath) {
                $user = User::create([
                    'name' => $data['name'],
                    'email' => $data['email'],
                    'password' => $data['password'], // cast 'hashed' → Argon2id (ADR-007 / CA-3)
                    'role' => 'profissional',
                    'status' => 'pendente_aprovacao',
                ]);

                ProfissionalProfile::create([
                    'user_id' => $user->id,
                    'tipo_pessoa' => $data['tipo_pessoa'],
                    'telefone' => $data['telefone'],
                    'cidade' => $data['cidade'],
                    'bairro' => $data['bairro'],
                    'funcao_id' => $data['funcao_id'],
                    'foto_path' => $fotoPath,
                    'termos_aceitos_at' => now(), // consentimento explícito (LGPD)
                ]);

                return $user;
            });
        } catch (\Throwable $e) {
            // Sem usuário criado → remove a foto órfã para não acumular lixo no storage.
            Storage::delete($fotoPath);
            throw $e;
        }

        // CA-12 — log estruturado (ADR-008), NÃO audit log de admin. E-mail mascarado;
        // senha jamais entra no contexto.
        Log::info('user.preregistered', [
            'event' => 'user.preregistered',
            'tipo_pessoa' => $user->profissionalProfile->tipo_pessoa,
            'masked_email' => Pii::maskEmail($user->email),
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Cadastro recebido. Em até 24h a equipe Turni revisa e envia notificação por e-mail.',
        ], 201);
    }
}
