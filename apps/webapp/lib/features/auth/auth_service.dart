import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// URL base da API — injetada via dart-define em build/CI. Default vazio = mesma
// origem: em produção o Firebase reescreve /api e /sanctum para o Cloud Run; em dev
// local o router.php do container webapp faz o proxy para o container `api`. Same-origin
// é o que permite o cookie de sessão Sanctum (SameSite=lax) trafegar.
const _apiBase = String.fromEnvironment('API_BASE_URL', defaultValue: '');

/// Representa o estado do funil do usuário logado (ADR-009).
enum FunnelState {
  awaitApproval('await_approval'),
  awaitWelcome('await_welcome'),
  awaitCadastro('await_cadastro'),
  rejected('rejected'),
  active('active');

  const FunnelState(this.apiValue);
  final String apiValue;

  static FunnelState fromApiValue(String? value) {
    return values.firstWhere(
      (e) => e.apiValue == value,
      orElse: () => FunnelState.active,
    );
  }
}

/// Sessão do usuário (payload do POST /api/login).
class UserSession {
  final String name;
  final String role;
  final String status;
  final bool welcomeVisto;
  final bool cadastroCompleto;

  const UserSession({
    this.name = '',
    required this.role,
    required this.status,
    required this.welcomeVisto,
    required this.cadastroCompleto,
  });

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      name: json['name'] as String? ?? '',
      role: json['role'] as String,
      status: json['status'] as String,
      welcomeVisto: json['welcome_visto'] as bool? ?? false,
      cadastroCompleto: json['cadastro_completo'] as bool? ?? false,
    );
  }

  /// Primeiro nome para saudação ("Bem-vindo(a), {firstName}!"). Vazio se sem nome.
  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  UserSession copyWith({bool? welcomeVisto, bool? cadastroCompleto}) {
    return UserSession(
      name: name,
      role: role,
      status: status,
      welcomeVisto: welcomeVisto ?? this.welcomeVisto,
      cadastroCompleto: cadastroCompleto ?? this.cadastroCompleto,
    );
  }

  FunnelState get funnelState {
    if (status == 'pendente_aprovacao') return FunnelState.awaitApproval;
    if (status == 'recusado') return FunnelState.rejected;
    if (status == 'liberado' && !welcomeVisto) return FunnelState.awaitWelcome;
    if (status == 'liberado' && !cadastroCompleto) {
      return FunnelState.awaitCadastro;
    }
    return FunnelState.active;
  }

  bool get canAccessApp => status == 'ativo' || status == 'liberado';
}

/// Resultado do login.
sealed class LoginResult {}

class LoginSuccess extends LoginResult {
  final UserSession session;
  LoginSuccess(this.session);
}

class LoginAdminRedirect extends LoginResult {
  final String backofficeUrl;
  LoginAdminRedirect(this.backofficeUrl);
}

class LoginError extends LoginResult {
  final String message;
  final String? code;
  LoginError(this.message, {this.code});
}

class LoginThrottle extends LoginResult {
  final int retryAfter;
  LoginThrottle(this.retryAfter);
}

/// Serviço de autenticação — Sanctum SPA cookie (ADR-007 §b).
/// Em Flutter Web, o browser gerencia os cookies httpOnly automaticamente.
class AuthService extends ChangeNotifier {
  static const _sessionKey = 'turni_session';

  UserSession? _session;
  UserSession? get session => _session;
  bool get isLoggedIn => _session != null;

  static final AuthService _instance = AuthService._();
  factory AuthService() => _instance;
  AuthService._();

  final _client = http.Client();

  /// Injeta uma sessão diretamente — uso restrito a testes de widget, que
  /// precisam montar telas pós-login sem passar pelo fluxo de rede do login.
  @visibleForTesting
  void debugSetSession(UserSession? session) {
    _session = session;
    notifyListeners();
  }

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw != null) {
      try {
        _session = UserSession.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        notifyListeners();
      } catch (_) {
        await prefs.remove(_sessionKey);
      }
    }
  }

  Future<LoginResult> login(String email, String password) async {
    // 1. Obtém CSRF cookie do Sanctum (ADR-007 §b)
    try {
      await _client.get(Uri.parse('$_apiBase/sanctum/csrf-cookie'));
    } catch (_) {
      // Se falhar, tenta o login mesmo assim (dev local sem Sanctum completo)
    }

    // 2. POST /api/login
    http.Response response;
    try {
      response = await _client.post(
        Uri.parse('$_apiBase/api/login'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'email': email, 'password': password}),
      );
    } catch (e) {
      return LoginError('Não conseguimos entrar agora. Tentar de novo.');
    }

    final data = _parseJson(response.body);

    switch (response.statusCode) {
      case 200:
        final s = UserSession.fromJson(data);
        await _saveSession(s);
        _session = s;
        notifyListeners();
        return LoginSuccess(s);

      case 403:
        if (data['code'] == 'admin_must_use_backoffice') {
          return LoginAdminRedirect(data['backoffice_url'] as String? ?? '');
        }
        return LoginError(data['message'] as String? ?? 'Acesso negado.');

      case 429:
        return LoginThrottle(data['retry_after'] as int? ?? 60);

      case 422:
        final msg = _extractValidationMessage(data);
        return LoginError(msg);

      default:
        return LoginError(
          'E-mail ou senha incorretos.',
          code: 'invalid_credentials',
        );
    }
  }

  /// Marca a tela de welcome como vista (STORY-022 CA-4).
  /// POST /api/usuarios/me/welcome-visto — idempotente no servidor. Em sucesso,
  /// atualiza a sessão local (welcome_visto=true) e notifica o router. Retorna
  /// `true` em sucesso; `false` em erro de rede/servidor (a tela mostra banner).
  Future<bool> markWelcomeSeen() async {
    http.Response response;
    try {
      response = await _client.post(
        Uri.parse('$_apiBase/api/usuarios/me/welcome-visto'),
        headers: {'Accept': 'application/json'},
      );
    } catch (_) {
      return false;
    }

    if (response.statusCode != 200) return false;

    // Reidrata a sessão com o estado retornado pelo servidor (fonte de verdade).
    final data = _parseJson(response.body);
    final updated = (_session ?? UserSession.fromJson(data)).copyWith(
      welcomeVisto: data['welcome_visto'] as bool? ?? true,
      cadastroCompleto: data['cadastro_completo'] as bool?,
    );
    await _saveSession(updated);
    _session = updated;
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    try {
      await _client.post(
        Uri.parse('$_apiBase/api/logout'),
        headers: {'Accept': 'application/json'},
      );
    } catch (_) {}

    _session = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    notifyListeners();
  }

  Future<void> _saveSession(UserSession s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _sessionKey,
      jsonEncode({
        'name': s.name,
        'role': s.role,
        'status': s.status,
        'welcome_visto': s.welcomeVisto,
        'cadastro_completo': s.cadastroCompleto,
      }),
    );
  }

  Map<String, dynamic> _parseJson(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  String _extractValidationMessage(Map<String, dynamic> data) {
    final errors = data['errors'] as Map<String, dynamic>?;
    if (errors != null && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) {
        return first.first.toString();
      }
    }
    return data['message'] as String? ??
        'Verifique os campos e tente novamente.';
  }
}
