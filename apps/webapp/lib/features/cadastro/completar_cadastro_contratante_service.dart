import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'completar_cadastro_service.dart'
    show PreviewError, PreviewResult, PreviewSuccess;
import 'shared/cadastro_types.dart';

// Reusa os tipos de resultado (Success/ValidationError/...) e de preview do profissional.
export 'completar_cadastro_service.dart'
    show PreviewResult, PreviewSuccess, PreviewError;
export 'shared/cadastro_types.dart'
    show
        CadastroResult,
        CadastroSuccess,
        CadastroValidationError,
        CadastroGenericError,
        CadastroThrottle,
        CadastroServerError;

/// Contexto do formulário de completar cadastro do contratante (GET .../completar/contexto).
class CompletarContratanteContexto {
  final String nome;
  final String nomeEstabelecimento;
  final String cidade;

  const CompletarContratanteContexto({
    required this.nome,
    required this.nomeEstabelecimento,
    required this.cidade,
  });

  factory CompletarContratanteContexto.fromJson(Map<String, dynamic> json) =>
      CompletarContratanteContexto(
        nome: json['nome'] as String? ?? '',
        nomeEstabelecimento: json['nome_estabelecimento'] as String? ?? '',
        cidade: json['cidade'] as String? ?? '',
      );
}

/// Endereço retornado pela busca de CEP (CA-4 / IDR-024).
class EnderecoCep {
  final String logradouro;
  final String bairro;
  final String cidade;
  final String uf;

  const EnderecoCep({
    required this.logradouro,
    required this.bairro,
    required this.cidade,
    required this.uf,
  });

  factory EnderecoCep.fromJson(Map<String, dynamic> json) => EnderecoCep(
    logradouro: json['logradouro'] as String? ?? '',
    bairro: json['bairro'] as String? ?? '',
    cidade: json['cidade'] as String? ?? '',
    uf: json['uf'] as String? ?? '',
  );
}

/// Serviço do completar cadastro do contratante (STORY-024).
///
/// Endpoints autenticados (sessão Sanctum). **Não** buscamos /sanctum/csrf-cookie aqui:
/// refazer o handshake CSRF no meio da sessão ativa derruba a sessão (401 — IDR-019).
class CompletarCadastroContratanteService {
  CompletarCadastroContratanteService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  String get _base => '$cadastroApiBase/api/cadastro/contratante/completar';

  /// GET contexto (nome do responsável, nome do estabelecimento, cidade).
  Future<CompletarContratanteContexto?> fetchContexto() async {
    http.Response res;
    try {
      res = await _client.get(
        Uri.parse('$_base/contexto'),
        headers: {'Accept': 'application/json'},
      );
    } catch (_) {
      return null;
    }
    if (res.statusCode != 200) return null;
    return CompletarContratanteContexto.fromJson(_json(res.body));
  }

  /// GET busca de endereço por CEP. Fail-soft: null quando indisponível (204) ou erro.
  Future<EnderecoCep?> buscarCep(String cep) async {
    final digitos = cep.replaceAll(RegExp(r'\D'), '');
    if (digitos.length != 8) return null;

    http.Response res;
    try {
      res = await _client.get(
        Uri.parse('$_base/cep/$digitos'),
        headers: {'Accept': 'application/json'},
      );
    } catch (_) {
      return null;
    }
    if (res.statusCode != 200) return null;
    return EnderecoCep.fromJson(_json(res.body));
  }

  /// POST preview — renderiza os termos com os dados informados (CA-7).
  ///
  /// @param dados cnpj + (opcional) campos de endereço para compor o documento.
  Future<PreviewResult> preview(Map<String, String> dados) async {
    http.Response res;
    try {
      res = await _client.post(
        Uri.parse('$_base/preview'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(dados),
      );
    } catch (_) {
      return PreviewError(
        'Não foi possível carregar os termos. Tente novamente.',
      );
    }

    final data = _json(res.body);
    if (res.statusCode == 200) {
      return PreviewSuccess(data['conteudo'] as String? ?? '');
    }
    return PreviewError(
      _firstError(data) ??
          'Não foi possível carregar os termos. Verifique o CNPJ.',
    );
  }

  /// POST completar (multipart) — gera o aceite e conclui o cadastro (CA-9/12).
  ///
  /// @param campos pares de campos de texto (cnpj, endereço, perfil, redes, contatos).
  /// @param logo arquivo opcional de logo (JPG/PNG).
  Future<CadastroResult> completar({
    required Map<String, String> campos,
    FotoUpload? logo,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse(_base))
      ..headers['Accept'] = 'application/json'
      ..fields.addAll(campos);

    if (logo != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'logo',
          logo.bytes,
          filename: logo.filename,
          contentType: _mediaTypeFor(logo.filename),
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
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    return MediaType('image', 'jpeg');
  }

  Map<String, dynamic> _json(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : {};
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
