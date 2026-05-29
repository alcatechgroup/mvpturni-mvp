import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// Tipos e helper HTTP compartilhados entre os pré-cadastros públicos
/// (profissional — STORY-017, contratante — STORY-018). IDR-012.
///
/// O fluxo de submit é idêntico nos dois: CSRF cookie do Sanctum → POST multipart
/// (campos de texto + foto) → mapeamento da resposta para um [CadastroResult]. A única
/// diferença entre os perfis é o conjunto de campos e o path — por isso o helper recebe
/// os campos já montados e o path como parâmetros.

// URL base da API — injetada via dart-define em build/CI (mesma convenção do AuthService).
const cadastroApiBase = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8001',
);

/// Dados da foto selecionada (bytes + nome), desacoplado do image_picker para testes.
class FotoUpload {
  final Uint8List bytes;
  final String filename;

  const FotoUpload({required this.bytes, required this.filename});
}

/// Resultado de um pré-cadastro.
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

/// Executa o submit multipart de um pré-cadastro público e mapeia a resposta.
///
/// [path] ex.: `/api/cadastro/profissional` ou `/api/cadastro/contratante`.
/// [fields] campos de texto já montados (chaves = nomes esperados pela API).
/// [foto] arquivo da foto (multipart `foto`).
Future<CadastroResult> postCadastroMultipart({
  required http.Client client,
  required String path,
  required Map<String, String> fields,
  required FotoUpload foto,
}) async {
  // 1. CSRF cookie do Sanctum (o browser anexa o cookie nas requisições seguintes).
  try {
    await client.get(Uri.parse('$cadastroApiBase/sanctum/csrf-cookie'));
  } catch (_) {
    // Dev local sem Sanctum completo: segue para o POST mesmo assim.
  }

  // 2. POST multipart.
  final request =
      http.MultipartRequest('POST', Uri.parse('$cadastroApiBase$path'))
        ..headers['Accept'] = 'application/json'
        ..fields.addAll(fields)
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
    final streamed = await client.send(request);
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
