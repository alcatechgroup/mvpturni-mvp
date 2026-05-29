import 'dart:convert';

import 'package:http/http.dart' as http;

import 'shared/cadastro_types.dart';

// Tipos compartilhados (FotoUpload, CadastroResult e variantes) ficam em shared/ desde a
// STORY-018 (IDR-012). Re-exportados aqui para manter os imports existentes da STORY-017.
export 'shared/cadastro_types.dart';

/// Função pretendida (vem de GET /api/funcoes — STORY-017 / IDR-008).
class Funcao {
  final int id;
  final String nome;

  const Funcao({required this.id, required this.nome});

  factory Funcao.fromJson(Map<String, dynamic> json) =>
      Funcao(id: json['id'] as int, nome: json['nome'] as String);
}

/// Serviço do pré-cadastro de profissional (STORY-017).
class CadastroService {
  CadastroService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// GET /api/funcoes — lista funções ativas para o select.
  Future<List<Funcao>> fetchFuncoes() async {
    final response = await _client.get(
      Uri.parse('$cadastroApiBase/api/funcoes'),
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
  /// aprovação. CSRF/multipart/parse no helper compartilhado (IDR-012).
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
  }) {
    return postCadastroMultipart(
      client: _client,
      path: '/api/cadastro/profissional',
      foto: foto,
      fields: {
        'name': name,
        'email': email,
        'telefone': telefone,
        'cidade': cidade,
        'bairro': bairro,
        'funcao_id': funcaoId.toString(),
        'tipo_pessoa': tipoPessoa,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'termos_aceitos': termosAceitos ? '1' : '0',
      },
    );
  }
}
