import 'dart:convert';

import 'package:http/http.dart' as http;

// Mesma origem do auth_service: em homolog/prod o Firebase reescreve /forgot-password
// e /reset-password para o Cloud Run da api (STORY-021 CA-13b); em dev o router.php
// faz o proxy. Same-origin permite o cookie de sessão Sanctum trafegar.
const _apiBase = String.fromEnvironment('API_BASE_URL', defaultValue: '');

/// Resultado de uma operação de reset de senha (STORY-021 CA-6/CA-13b).
sealed class ResetResult {
  const ResetResult();
}

/// Sucesso. Para "esqueci a senha" é sempre devolvido em qualquer e-mail
/// (anti-enumeração — o servidor responde neutro).
class ResetOk extends ResetResult {
  const ResetOk();
}

/// Token de redefinição inválido ou expirado (link velho).
class ResetInvalidToken extends ResetResult {
  const ResetInvalidToken();
}

/// Erro de validação (ex.: senha fraca) — mensagem pronta para exibir.
class ResetValidationError extends ResetResult {
  const ResetValidationError(this.message);
  final String message;
}

/// Falha de rede / servidor indisponível.
class ResetNetworkError extends ResetResult {
  const ResetNetworkError();
}

/// Serviço do fluxo de recuperação de senha (Fortify via api).
/// Endpoints na raiz (/forgot-password, /reset-password) — reescritos pelo Firebase
/// para o api e excluídos do CSRF (mesmo modelo do /api/login — STORY-021 CA-13b).
class PasswordResetService {
  PasswordResetService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Future<void> _csrf() async {
    try {
      await _client.get(Uri.parse('$_apiBase/sanctum/csrf-cookie'));
    } catch (_) {
      // Dev local sem Sanctum completo: segue mesmo assim.
    }
  }

  /// POST /forgot-password — dispara o e-mail com o link. Resposta sempre neutra
  /// (CA-7): não revela se o e-mail existe. Só sinaliza erro de rede.
  Future<ResetResult> requestReset(String email) async {
    await _csrf();
    try {
      final r = await _client.post(
        Uri.parse('$_apiBase/forgot-password'),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'email': email}),
      );
      // 200/422 → resposta neutra (anti-enumeração). Só 5xx/0 vira erro de rede.
      if (r.statusCode >= 500 || r.statusCode == 0) {
        return const ResetNetworkError();
      }
      return const ResetOk();
    } catch (_) {
      return const ResetNetworkError();
    }
  }

  /// POST /reset-password — redefine a senha com o token do e-mail.
  Future<ResetResult> reset({
    required String token,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    await _csrf();
    http.Response r;
    try {
      r = await _client.post(
        Uri.parse('$_apiBase/reset-password'),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'token': token,
          'email': email,
          'password': password,
          'password_confirmation': passwordConfirmation,
        }),
      );
    } catch (_) {
      return const ResetNetworkError();
    }

    if (r.statusCode == 200) return const ResetOk();

    if (r.statusCode == 422) {
      final data = _parseJson(r.body);
      final errors = (data['errors'] as Map<String, dynamic>?) ?? const {};
      // Token inválido/expirado: Fortify devolve erro no campo `email`.
      if (errors.containsKey('email')) return const ResetInvalidToken();
      final first = errors.values
          .whereType<List>()
          .expand((e) => e)
          .map((e) => e.toString())
          .firstWhere(
            (_) => true,
            orElse: () => 'Não foi possível redefinir a senha.',
          );
      return ResetValidationError(first);
    }

    return const ResetNetworkError();
  }

  Map<String, dynamic> _parseJson(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}
