import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'shared/cadastro_types.dart';

// Tipos de resultado de cadastro (Success/ValidationError/Generic/Throttle/Server)
// reusados do helper compartilhado (IDR-012).
export 'shared/cadastro_types.dart'
    show
        CadastroResult,
        CadastroSuccess,
        CadastroValidationError,
        CadastroGenericError,
        CadastroThrottle,
        CadastroServerError;

/// Arquivo comprobatório selecionado (bytes + nome). JPG/PNG/PDF (CA-5).
class ArquivoUpload {
  final Uint8List bytes;
  final String filename;

  const ArquivoUpload({required this.bytes, required this.filename});
}

/// Contexto do formulário de completar cadastro (GET .../completar/contexto).
class CompletarContexto {
  final String nome;
  final String tipoPessoa; // PF | MEI | PJ
  final String documentoTipo; // CPF | CNPJ
  final String?
  funcaoId; // função primária (excluída do multi-select de secundárias)

  const CompletarContexto({
    required this.nome,
    required this.tipoPessoa,
    required this.documentoTipo,
    this.funcaoId,
  });

  factory CompletarContexto.fromJson(Map<String, dynamic> json) =>
      CompletarContexto(
        nome: json['nome'] as String? ?? '',
        tipoPessoa: json['tipo_pessoa'] as String? ?? 'PF',
        documentoTipo: json['documento_tipo'] as String? ?? 'CPF',
        funcaoId: json['funcao_id'] as String?,
      );
}

/// Resultado do preview do contrato.
sealed class PreviewResult {}

class PreviewSuccess extends PreviewResult {
  final String conteudo;
  PreviewSuccess(this.conteudo);
}

class PreviewError extends PreviewResult {
  final String message;
  PreviewError(this.message);
}

/// Serviço do completar cadastro do profissional (STORY-023).
///
/// Endpoints são autenticados (sessão Sanctum). **Não** buscamos /sanctum/csrf-cookie
/// aqui: refazer o handshake CSRF no meio de uma sessão ativa derruba a sessão (401)
/// — o cookie de sessão já trafega same-origin (mesma regra de markWelcomeSeen / IDR-019).
class CompletarCadastroService {
  CompletarCadastroService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  /// GET contexto (tipo_pessoa, documento_tipo, nome, função primária).
  Future<CompletarContexto?> fetchContexto() async {
    http.Response res;
    try {
      res = await _client.get(
        Uri.parse(
          '$cadastroApiBase/api/cadastro/profissional/completar/contexto',
        ),
        headers: {'Accept': 'application/json'},
      );
    } catch (_) {
      return null;
    }
    if (res.statusCode != 200) return null;
    return CompletarContexto.fromJson(_json(res.body));
  }

  /// POST preview — renderiza o contrato com o documento informado (CA-7).
  Future<PreviewResult> preview(String documento) async {
    http.Response res;
    try {
      res = await _client.post(
        Uri.parse(
          '$cadastroApiBase/api/cadastro/profissional/completar/preview',
        ),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'documento': documento}),
      );
    } catch (_) {
      return PreviewError(
        'Não foi possível carregar o contrato. Tente novamente.',
      );
    }

    final data = _json(res.body);
    if (res.statusCode == 200) {
      return PreviewSuccess(data['conteudo'] as String? ?? '');
    }
    return PreviewError(
      _firstError(data) ??
          'Não foi possível carregar o contrato. Verifique o documento.',
    );
  }

  /// POST completar (multipart) — gera o aceite e conclui o cadastro (CA-9/12).
  Future<CadastroResult> completar({
    required String documento,
    required List<String> funcoesSecundarias,
    required int raioMaxKm,
    required String precoHora,
    required String bio,
    required String chavePix,
    required List<ArquivoUpload> documentos,
  }) async {
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('$cadastroApiBase/api/cadastro/profissional/completar'),
          )
          ..headers['Accept'] = 'application/json'
          ..fields['documento'] = documento
          ..fields['raio_max_km'] = raioMaxKm.toString()
          ..fields['preco_hora'] = precoHora
          ..fields['bio'] = bio
          ..fields['chave_pix'] = chavePix;

    for (var i = 0; i < funcoesSecundarias.length; i++) {
      request.fields['funcoes_secundarias[$i]'] = funcoesSecundarias[i];
    }
    for (final arquivo in documentos) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'documentos_comprobatorios[]',
          arquivo.bytes,
          filename: arquivo.filename,
          contentType: _mediaTypeFor(arquivo.filename),
        ),
      );
    }

    http.Response res;
    try {
      final streamed = await _client.send(request);
      res = await http.Response.fromStream(streamed);
    } catch (_) {
      return CadastroServerError();
    }

    final data = _json(res.body);
    switch (res.statusCode) {
      case 201:
        return CadastroSuccess(
          data['message'] as String? ?? 'Cadastro concluído!',
        );
      case 422:
        final errors = data['errors'] as Map<String, dynamic>?;
        if (errors != null && errors.isNotEmpty) {
          return CadastroValidationError(_flatten(errors));
        }
        return CadastroGenericError(
          data['message'] as String? ?? 'Verifique os dados e tente novamente.',
        );
      case 429:
        return CadastroThrottle();
      default:
        return CadastroServerError();
    }
  }

  MediaType _mediaTypeFor(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) return MediaType('application', 'pdf');
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    return MediaType('image', 'jpeg');
  }

  Map<String, dynamic> _json(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Map<String, String> _flatten(Map<String, dynamic> errors) {
    final out = <String, String>{};
    errors.forEach((field, messages) {
      if (messages is List && messages.isNotEmpty) {
        out[field] = messages.first.toString();
      }
    });
    return out;
  }

  String? _firstError(Map<String, dynamic> data) {
    final errors = data['errors'] as Map<String, dynamic>?;
    if (errors != null && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) return first.first.toString();
    }
    return data['message'] as String?;
  }
}
