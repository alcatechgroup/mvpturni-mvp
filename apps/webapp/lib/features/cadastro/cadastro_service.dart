import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

// URL base da API — injetada via dart-define em build/CI (mesma convenção do AuthService).
const _apiBase = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8001',
);

/// Função pretendida (vem de GET /api/funcoes — STORY-017 / IDR-008).
class Funcao {
  final int id;
  final String nome;

  const Funcao({required this.id, required this.nome});

  factory Funcao.fromJson(Map<String, dynamic> json) =>
      Funcao(id: json['id'] as int, nome: json['nome'] as String);
}

/// Dados da foto selecionada (bytes + nome), desacoplado do image_picker para testes.
class FotoUpload {
  final Uint8List bytes;
  final String filename;

  const FotoUpload({required this.bytes, required this.filename});
}

/// Resultado do pré-cadastro.
sealed class CadastroResult {}

class CadastroSuccess extends CadastroResult {
  final String message;
  CadastroSuccess(this.message);
}

/// Erros de validação por campo (422 com `errors`). Chave = campo da API.
class CadastroValidationError extends CadastroResult {
  final Map<String, String> errors;
  CadastroValidationError(this.errors);
}

/// Erro genérico de cadastro (CA-4 — e-mail já existe / falha; sem enumeração).
class CadastroGenericError extends CadastroResult {
  final String message;
  CadastroGenericError(this.message);
}

class CadastroThrottle extends CadastroResult {}

class CadastroServerError extends CadastroResult {}

/// Serviço do pré-cadastro de profissional (STORY-017).
class CadastroService {
  CadastroService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// GET /api/funcoes — lista funções ativas para o select.
  Future<List<Funcao>> fetchFuncoes() async {
    final response = await _client.get(
      Uri.parse('$_apiBase/api/funcoes'),
      headers: {'Accept': 'application/json'},
    );
    if (response.statusCode != 200) return [];
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final list = (data['data'] as List? ?? []);
    return list
        .map((e) => Funcao.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// POST /api/cadastro/profissional (multipart). Não autentica — o usuário aguarda
  /// aprovação. Segue o padrão CSRF do Sanctum usado no login (ADR-007 §b).
  Future<CadastroResult> cadastrar({
    required String name,
    required String email,
    required String telefone,
    required String cidade,
    required String bairro,
    required int funcaoId,
    required String tipoPessoa,
    required String password,
    required String passwordConfirmation,
    required bool termosAceitos,
    required FotoUpload foto,
  }) async {
    // 1. CSRF cookie do Sanctum (o browser anexa o cookie nas requisições seguintes).
    try {
      await _client.get(Uri.parse('$_apiBase/sanctum/csrf-cookie'));
    } catch (_) {
      // Dev local sem Sanctum completo: segue para o POST mesmo assim.
    }

    // 2. POST multipart.
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('$_apiBase/api/cadastro/profissional'),
          )
          ..headers['Accept'] = 'application/json'
          ..fields['name'] = name
          ..fields['email'] = email
          ..fields['telefone'] = telefone
          ..fields['cidade'] = cidade
          ..fields['bairro'] = bairro
          ..fields['funcao_id'] = funcaoId.toString()
          ..fields['tipo_pessoa'] = tipoPessoa
          ..fields['password'] = password
          ..fields['password_confirmation'] = passwordConfirmation
          ..fields['termos_aceitos'] = termosAceitos ? '1' : '0'
          ..files.add(
            http.MultipartFile.fromBytes(
              'foto',
              foto.bytes,
              filename: foto.filename,
              contentType: _mediaTypeFor(foto.filename),
            ),
          );

    http.Response response;
    try {
      final streamed = await _client.send(request);
      response = await http.Response.fromStream(streamed);
    } catch (_) {
      return CadastroServerError();
    }

    final data = _parseJson(response.body);

    switch (response.statusCode) {
      case 201:
        return CadastroSuccess(
          data['message'] as String? ??
              'Cadastro recebido. Em até 24h a equipe Turni revisa e envia notificação por e-mail.',
        );
      case 422:
        final errors = data['errors'] as Map<String, dynamic>?;
        if (errors != null && errors.isNotEmpty) {
          return CadastroValidationError(_flattenErrors(errors));
        }
        return CadastroGenericError(
          data['message'] as String? ??
              'Não foi possível concluir o cadastro. Verifique os dados e tente novamente.',
        );
      case 429:
        return CadastroThrottle();
      default:
        return CadastroServerError();
    }
  }

  MediaType _mediaTypeFor(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    return MediaType('image', 'jpeg'); // jpg/jpeg default
  }

  Map<String, String> _flattenErrors(Map<String, dynamic> errors) {
    final out = <String, String>{};
    errors.forEach((field, messages) {
      if (messages is List && messages.isNotEmpty) {
        out[field] = messages.first.toString();
      }
    });
    return out;
  }

  Map<String, dynamic> _parseJson(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}
