import 'package:http/http.dart' as http;

import 'shared/cadastro_types.dart';

// Tipos compartilhados (FotoUpload, CadastroResult) ficam em shared/ (IDR-012).
export 'shared/cadastro_types.dart';

/// Tipo de operação do estabelecimento (lista estática — IDR-012; não vem da API).
/// Espelha `domain/usuario.md` §Contratante e SCREEN-STORY-018 §A.4.
class TipoOperacao {
  final String value;
  final String label;

  const TipoOperacao(this.value, this.label);

  static const opcoes = <TipoOperacao>[
    TipoOperacao('restaurante', 'Restaurante'),
    TipoOperacao('bar', 'Bar'),
    TipoOperacao('hotel', 'Hotel / Pousada'),
    TipoOperacao('evento', 'Eventos'),
    TipoOperacao('catering', 'Catering / Buffet'),
    TipoOperacao('outro', 'Outro'),
  ];
}

/// Serviço do pré-cadastro de contratante (STORY-018). Contratante é sempre PJ —
/// não há `tipo_pessoa`; CNPJ/endereço só na STORY-024.
class ContratanteCadastroService {
  ContratanteCadastroService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  /// POST /api/cadastro/contratante (multipart). Não autentica — o usuário aguarda
  /// aprovação. CSRF/multipart/parse no helper compartilhado (IDR-012).
  Future<CadastroResult> cadastrar({
    required String name,
    required String email,
    required String telefone,
    required String nomeEstabelecimento,
    required String tipoOperacao,
    required String cidade,
    required String password,
    required String passwordConfirmation,
    required bool termosAceitos,
    required FotoUpload foto,
  }) {
    return postCadastroMultipart(
      client: _client,
      path: '/api/cadastro/contratante',
      foto: foto,
      fields: {
        'name': name,
        'email': email,
        'telefone': telefone,
        'nome_estabelecimento': nomeEstabelecimento,
        'tipo_operacao': tipoOperacao,
        'cidade': cidade,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'termos_aceitos': termosAceitos ? '1' : '0',
      },
    );
  }
}
