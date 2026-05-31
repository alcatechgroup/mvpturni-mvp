import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'shared/cadastro_types.dart';

/// STORY-023 — Serviço do completar-cadastro do profissional.
///
/// Dois endpoints (FORA do FunnelGuard — IDR-014):
///  - `POST /api/usuarios/me/completar-cadastro/preview` (JSON) → contrato renderizado, sem persistir.
///  - `POST /api/usuarios/me/completar-cadastro` (multipart) → gera o AceiteEletronico e vira `ativo`.
///
/// Mesma mecânica de cookie/CSRF dos demais serviços (Sanctum SPA): GET csrf-cookie + POST.

// ── Resultado do preview ────────────────────────────────────────────────────
sealed class PreviewResult {}

class PreviewSuccess extends PreviewResult {
  final String conteudo;
  PreviewSuccess(this.conteudo);
}

class PreviewValidationError extends PreviewResult {
  final Map<String, String> errors;
  PreviewValidationError(this.errors);
}

class PreviewServerError extends PreviewResult {}

// ── Resultado do completar (submit final) ───────────────────────────────────
sealed class CompletarResult {}

class CompletarSuccess extends CompletarResult {}

class CompletarValidationError extends CompletarResult {
  final Map<String, String> errors;
  CompletarValidationError(this.errors);
}

/// 422 genérico com `code` (documento_duplicado | funil_invalido | template_indisponivel).
class CompletarGenericError extends CompletarResult {
  final String message;
  CompletarGenericError(this.message);
}

class CompletarServerError extends CompletarResult {}

/// Campos de texto do completar-cadastro (compartilhados entre preview e submit).
class CompletarCadastroDados {
  final String documento;
  final String raioMaxKm;
  final String precoHora;
  final String bio;
  final String chavePix;
  final List<int> funcoesSecundarias;

  const CompletarCadastroDados({
    required this.documento,
    required this.raioMaxKm,
    required this.precoHora,
    required this.bio,
    required this.chavePix,
    this.funcoesSecundarias = const [],
  });

  /// Campos comuns como strings de formulário (multipart usa chaves indexadas p/ array).
  Map<String, String> toFields() {
    final fields = <String, String>{
      'documento': documento,
      'raio_max_km': raioMaxKm,
      'preco_hora': precoHora,
      'bio': bio,
      'chave_pix': chavePix,
    };
    for (var i = 0; i < funcoesSecundarias.length; i++) {
      fields['funcoes_secundarias[$i]'] = funcoesSecundarias[i].toString();
    }
    return fields;
  }
}

class CompletarCadastroService {
  CompletarCadastroService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static const _contextoPath = '/api/usuarios/me/completar-cadastro/contexto';
  static const _previewPath = '/api/usuarios/me/completar-cadastro/preview';
  static const _completarPath = '/api/usuarios/me/completar-cadastro';

  /// Contexto da tela: `documento_tipo` (CPF|CNPJ) conforme o tipo de pessoa do perfil.
  /// Default 'CPF' em falha de rede (a validação real é server-side de qualquer forma).
  Future<String> fetchDocumentoTipo() async {
    try {
      final response = await _client.get(
        Uri.parse('$cadastroApiBase$_contextoPath'),
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode != 200) return 'CPF';
      return _parseJson(response.body)['documento_tipo'] as String? ?? 'CPF';
    } catch (_) {
      return 'CPF';
    }
  }

  // Endpoints autenticados (auth:web) usam só o cookie de sessão same-origin — NÃO chamamos
  // /sanctum/csrf-cookie aqui: hit no csrf-cookie no meio de uma sessão ativa regenera a
  // sessão e desloga o usuário (401). Mesmo padrão de AuthService.markWelcomeSeen.

  /// Renderiza o contrato com os dados do usuário (não persiste). CA-7.
  Future<PreviewResult> preview(CompletarCadastroDados dados) async {
    http.Response response;
    try {
      response = await _client.post(
        Uri.parse('$cadastroApiBase$_previewPath'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'documento': dados.documento,
          'raio_max_km': int.tryParse(dados.raioMaxKm) ?? dados.raioMaxKm,
          'preco_hora':
              num.tryParse(dados.precoHora.replaceAll(',', '.')) ??
              dados.precoHora,
          'chave_pix': dados.chavePix,
        }),
      );
    } catch (_) {
      return PreviewServerError();
    }

    final data = _parseJson(response.body);
    switch (response.statusCode) {
      case 200:
        return PreviewSuccess(data['conteudo_renderizado'] as String? ?? '');
      case 422:
        return PreviewValidationError(_flattenErrors(data));
      default:
        return PreviewServerError();
    }
  }

  /// Submit final: gera o AceiteEletronico, criptografa e transiciona para `ativo`. CA-9/10/12.
  Future<CompletarResult> completar(
    CompletarCadastroDados dados,
    FotoUpload documento,
  ) async {
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('$cadastroApiBase$_completarPath'),
          )
          ..headers['Accept'] = 'application/json'
          ..fields.addAll(dados.toFields())
          ..files.add(
            http.MultipartFile.fromBytes(
              'documento_comprobatorio',
              documento.bytes,
              filename: documento.filename,
              contentType: _mediaTypeFor(documento.filename),
            ),
          );

    http.Response response;
    try {
      final streamed = await _client.send(request);
      response = await http.Response.fromStream(streamed);
    } catch (_) {
      return CompletarServerError();
    }

    final data = _parseJson(response.body);
    switch (response.statusCode) {
      case 201:
        return CompletarSuccess();
      case 422:
        final errors = data['errors'] as Map<String, dynamic>?;
        if (errors != null && errors.isNotEmpty) {
          return CompletarValidationError(_flattenErrors(data));
        }
        return CompletarGenericError(
          data['message'] as String? ??
              'Não foi possível concluir o cadastro. Verifique os dados e tente novamente.',
        );
      default:
        return CompletarServerError();
    }
  }

  MediaType _mediaTypeFor(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.pdf')) return MediaType('application', 'pdf');
    return MediaType('image', 'jpeg');
  }

  Map<String, String> _flattenErrors(Map<String, dynamic> data) {
    final errors = data['errors'] as Map<String, dynamic>? ?? {};
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
