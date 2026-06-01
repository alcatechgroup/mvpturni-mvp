import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../ds/components/app_version_label.dart';
import '../../ds/components/contract_view.dart';
import '../../ds/tokens.dart';
import '../auth/auth_service.dart';
import 'completar_cadastro_contratante_service.dart';
import 'shared/cadastro_types.dart';
import 'shared/cadastro_widgets.dart';
import 'shared/input_formatters.dart';

/// Fase do fluxo de completar cadastro do contratante (STORY-024).
enum _Fase { form, preview, sucesso }

/// Seam de E2E (IDR-021/harness): o picker de imagem abre diálogo nativo que o Chrome
/// headless do `flutter drive` não dirige. Sob `--dart-define=E2E_FAKE_PICKER=true`
/// (só no gate E2E — nunca em produção), o picker devolve um arquivo em memória.
const _e2eFakePicker = bool.fromEnvironment('E2E_FAKE_PICKER');

/// UFs brasileiras (dropdown de endereço).
const _ufs = [
  'AC',
  'AL',
  'AP',
  'AM',
  'BA',
  'CE',
  'DF',
  'ES',
  'GO',
  'MA',
  'MT',
  'MS',
  'MG',
  'PA',
  'PB',
  'PR',
  'PE',
  'PI',
  'RJ',
  'RN',
  'RS',
  'RO',
  'RR',
  'SC',
  'SP',
  'SE',
  'TO',
];

/// Faixas de quantidade de funcionários (domain/usuario.md §Contratante).
const _faixasFuncionarios = ['1-10', '11-50', '51-200', '200+'];

/// Tela de completar cadastro do contratante + aceite eletrônico (STORY-024).
///
/// Wizard de 3 passos (Identidade do Estabelecimento / Operação / Cultura & Contatos),
/// seguido de revisão dos termos renderizados (`termos_plataforma_contratante` — IDR-023)
/// com checkbox de consentimento explícito (CA-7/8). O aceite é gerado no servidor em
/// transação atômica; a sessão vira `ativo` (plano Member Start) e o router leva à home.
/// Tema do papel contratante (mostarda — DDR-001 / tokens.md §6).
class CompletarCadastroContratanteScreen extends StatefulWidget {
  const CompletarCadastroContratanteScreen({
    super.key,
    this.service,
    this.logoPicker,
    this.auth,
  });

  final CompletarCadastroContratanteService? service;
  final Future<FotoUpload?> Function()? logoPicker;
  final AuthService? auth;

  @override
  State<CompletarCadastroContratanteScreen> createState() =>
      _CompletarCadastroContratanteScreenState();
}

class _CompletarCadastroContratanteScreenState
    extends State<CompletarCadastroContratanteScreen> {
  late final CompletarCadastroContratanteService _service =
      widget.service ?? CompletarCadastroContratanteService();
  late final AuthService _auth = widget.auth ?? AuthService();

  // Uma form key por passo — validação por passo ao avançar.
  final _form1 = GlobalKey<FormState>();
  final _form2 = GlobalKey<FormState>();
  final _form3 = GlobalKey<FormState>();

  final _cnpj = TextEditingController();
  final _cep = TextEditingController();
  final _logradouro = TextEditingController();
  final _numero = TextEditingController();
  final _bairro = TextEditingController();
  final _cidade = TextEditingController();
  final _complemento = TextEditingController();
  final _apelido = TextEditingController();
  final _segmento = TextEditingController();
  final _ano = TextEditingController();
  final _turnos = TextEditingController();
  final _cultura = TextEditingController();
  final _site = TextEditingController();
  final _instagram = TextEditingController();

  String? _uf;
  String? _qtdFuncionarios;
  final List<_ContatoControllers> _contatos = [];
  FotoUpload? _logo;
  String? _logoError;

  CompletarContratanteContexto? _contexto;

  _Fase _fase = _Fase.form;
  int _step = 0; // 0..2
  String _contrato = '';
  bool _aceitou = false;

  bool _loading = false;
  bool _buscandoCep = false;
  CadastroBanner? _banner;
  String? _cepAviso;
  final Map<String, String> _serverErrors = {};

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final contexto = await _service.fetchContexto();
    if (!mounted) return;
    setState(() {
      _contexto = contexto;
      // Pré-preenche a cidade já informada no pré-cadastro (o usuário pode ajustar).
      if (_cidade.text.isEmpty && (contexto?.cidade ?? '').isNotEmpty) {
        _cidade.text = contexto!.cidade;
      }
    });
  }

  @override
  void dispose() {
    for (final c in [
      _cnpj,
      _cep,
      _logradouro,
      _numero,
      _bairro,
      _cidade,
      _complemento,
      _apelido,
      _segmento,
      _ano,
      _turnos,
      _cultura,
      _site,
      _instagram,
    ]) {
      c.dispose();
    }
    for (final c in _contatos) {
      c.dispose();
    }
    super.dispose();
  }

  Color _accent(bool isDark) => isDark
      ? TurniColors.contratanteAccentDark
      : TurniColors.contratanteAccentLight;

  // ── Navegação entre passos ─────────────────────────────────────────────────

  void _avancar() {
    final key = _step == 0 ? _form1 : _form2;
    if (key.currentState?.validate() != true) return;
    setState(() {
      _step += 1;
      _banner = null;
    });
  }

  void _voltarStep() => setState(() => _step -= 1);

  Future<void> _buscarCep() async {
    final cep = _cep.text.replaceAll(RegExp(r'\D'), '');
    if (cep.length != 8) {
      setState(() => _cepAviso = 'Digite um CEP com 8 dígitos para buscar.');
      return;
    }
    setState(() {
      _buscandoCep = true;
      _cepAviso = null;
    });
    final endereco = await _service.buscarCep(cep);
    if (!mounted) return;
    setState(() {
      _buscandoCep = false;
      if (endereco == null) {
        // CA-4 — falha não bloqueia: preenche manualmente.
        _cepAviso =
            'Não encontramos esse CEP agora — preencha o endereço manualmente.';
      } else {
        if (endereco.logradouro.isNotEmpty) {
          _logradouro.text = endereco.logradouro;
        }
        if (endereco.bairro.isNotEmpty) {
          _bairro.text = endereco.bairro;
        }
        if (endereco.cidade.isNotEmpty) {
          _cidade.text = endereco.cidade;
        }
        if (endereco.uf.isNotEmpty) {
          _uf = endereco.uf;
        }
        _cepAviso = null;
      }
    });
  }

  Future<void> _pickLogo() async {
    final picker = widget.logoPicker ?? _defaultLogoPicker;
    FotoUpload? logo;
    try {
      logo = await picker();
    } catch (_) {
      return;
    }
    if (logo == null || !mounted) return;

    final lower = logo.filename.toLowerCase();
    if (!(lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png'))) {
      setState(() => _logoError = 'A logo deve ser JPG ou PNG.');
      return;
    }
    if (logo.bytes.length > 5 * 1024 * 1024) {
      setState(() => _logoError = 'A logo deve ter no máximo 5 MB.');
      return;
    }
    setState(() {
      _logo = logo;
      _logoError = null;
    });
  }

  Future<FotoUpload?> _defaultLogoPicker() async {
    if (_e2eFakePicker) {
      return FotoUpload(
        bytes: Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10]),
        filename: 'logo-e2e.jpg',
      );
    }
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return null;
    return FotoUpload(bytes: await file.readAsBytes(), filename: file.name);
  }

  // ── Endereço (campos não-vazios) para preview/submit ────────────────────────
  Map<String, String> _camposEndereco() {
    final out = <String, String>{};
    void add(String k, String v) {
      if (v.trim().isNotEmpty) out[k] = v.trim();
    }

    add('cep', _cep.text);
    add('logradouro', _logradouro.text);
    add('numero', _numero.text);
    add('bairro', _bairro.text);
    add('cidade', _cidade.text);
    if (_uf != null) out['uf'] = _uf!;
    add('complemento', _complemento.text);
    return out;
  }

  /// Passo 3 → preview: valida o passo e busca o preview dos termos (CA-7).
  Future<void> _revisar() async {
    _serverErrors.clear();
    if (_form3.currentState?.validate() != true) return;

    setState(() {
      _loading = true;
      _banner = null;
    });

    final dados = {'cnpj': _cnpj.text.trim(), ..._camposEndereco()};
    final result = await _service.preview(dados);
    if (!mounted) return;
    setState(() => _loading = false);

    switch (result) {
      case PreviewSuccess(:final conteudo):
        setState(() {
          _contrato = conteudo;
          _aceitou = false;
          _fase = _Fase.preview;
        });
      case PreviewError(:final message):
        setState(() => _banner = CadastroBanner.generic(message));
    }
  }

  /// Monta o payload completo de campos (texto) para o submit.
  Map<String, String> _camposCompletos() {
    final campos = <String, String>{
      'cnpj': _cnpj.text.trim(),
      ..._camposEndereco(),
      'segmento': _segmento.text.trim(),
      'ano_fundacao': _ano.text.replaceAll(RegExp(r'\D'), ''),
      'qtd_funcionarios': _qtdFuncionarios ?? '',
    };
    void opc(String k, String v) {
      if (v.trim().isNotEmpty) campos[k] = v.trim();
    }

    opc('apelido_estabelecimento', _apelido.text);
    opc('turnos_operacao', _turnos.text);
    opc('cultura_valores', _cultura.text);
    opc('site', _site.text);
    if (_instagram.text.trim().isNotEmpty) {
      campos['redes_sociais[instagram]'] = _instagram.text.trim();
    }
    var i = 0;
    for (final c in _contatos) {
      if (c.nome.text.trim().isEmpty && c.funcao.text.trim().isEmpty) continue;
      campos['contatos_adicionais[$i][nome]'] = c.nome.text.trim();
      campos['contatos_adicionais[$i][funcao]'] = c.funcao.text.trim();
      if (c.telefone.text.trim().isNotEmpty) {
        campos['contatos_adicionais[$i][telefone]'] = c.telefone.text.trim();
      }
      i++;
    }
    return campos;
  }

  /// Clique em "Aceito e concluir cadastro" — gera o aceite (CA-9/12).
  Future<void> _aceitar() async {
    setState(() {
      _loading = true;
      _banner = null;
    });

    final result = await _service.completar(
      campos: _camposCompletos(),
      logo: _logo,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    switch (result) {
      case CadastroSuccess():
        await _auth.markCadastroCompleto();
        if (!mounted) return;
        setState(() => _fase = _Fase.sucesso);
      case CadastroValidationError(:final errors):
        setState(() {
          _serverErrors.addAll(errors);
          _fase = _Fase.form;
          // Volta ao passo que contém o primeiro campo com erro.
          _step = _stepDoErro(errors.keys);
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _form1.currentState?.validate();
          _form2.currentState?.validate();
          _form3.currentState?.validate();
        });
      case CadastroGenericError(:final message):
        setState(() => _banner = CadastroBanner.generic(message));
      case CadastroThrottle():
        setState(() => _banner = CadastroBanner.throttle());
      case CadastroServerError():
        setState(() => _banner = CadastroBanner.server());
    }
  }

  int _stepDoErro(Iterable<String> campos) {
    const passo1 = {
      'cnpj',
      'cep',
      'logradouro',
      'numero',
      'bairro',
      'cidade',
      'uf',
      'complemento',
      'apelido_estabelecimento',
    };
    const passo2 = {
      'segmento',
      'ano_fundacao',
      'qtd_funcionarios',
      'turnos_operacao',
    };
    for (final c in campos) {
      if (passo1.contains(c)) return 0;
      if (passo2.contains(c)) return 1;
    }
    return 2;
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _accent(isDark);
    final surfacePage = isDark
        ? TurniColors.surfacePageDark
        : TurniColors.surfacePageLight;
    final isDesktop = MediaQuery.sizeOf(context).width >= 840;

    return Scaffold(
      key: const Key('completar-cadastro:screen'),
      backgroundColor: surfacePage,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: TurniSpacing.lg,
            vertical: isDesktop ? TurniSpacing.x3l : TurniSpacing.x2l,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isDesktop ? 640 : 480),
            child: switch (_fase) {
              _Fase.form => _formView(isDark, accent),
              _Fase.preview => _previewView(isDark, accent),
              _Fase.sucesso => _sucessoView(accent),
            },
          ),
        ),
      ),
    );
  }

  Widget _formView(bool isDark, Color accent) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(_tituloPasso, _subtituloPasso, isDark),
        _Progresso(step: _step, accent: accent, isDark: isDark),
        const SizedBox(height: TurniSpacing.sm),
        switch (_step) {
          0 => _stepIdentidade(isDark, accent),
          1 => _stepOperacao(isDark, accent),
          _ => _stepCultura(isDark, accent),
        },
        const SizedBox(height: TurniSpacing.lg),
        _navPasso(accent),
        if (_banner != null) ...[
          const SizedBox(height: TurniSpacing.md),
          CadastroBannerWidget(
            banner: _banner!,
            isDark: isDark,
            onLogin: () => context.go('/login'),
            onRetry: _revisar,
          ),
        ],
        const SizedBox(height: TurniSpacing.lg),
        const Center(
          child: AppVersionLabel(
            key: Key('app-version-label-completar-cadastro-contratante'),
          ),
        ),
      ],
    );
  }

  String get _tituloPasso => switch (_step) {
    0 =>
      (_contexto?.nomeEstabelecimento ?? '').isNotEmpty
          ? 'Complete o cadastro de ${_contexto!.nomeEstabelecimento}'
          : 'Complete o cadastro do seu negócio',
    1 => 'Como seu negócio opera',
    _ => 'Cultura e contatos',
  };

  String get _subtituloPasso => switch (_step) {
    0 => 'Esses dados ficam protegidos. O CNPJ é criptografado.',
    1 => 'Conte um pouco da operação do estabelecimento.',
    _ => 'Quase lá — revise os termos no próximo passo.',
  };

  Widget _stepIdentidade(bool isDark, Color accent) {
    return Form(
      key: _form1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CadastroSection('CNPJ'),
          CadastroTextField(
            fieldKey: 'completar-cadastro:cnpj',
            controller: _cnpj,
            label: 'CNPJ',
            hint: '00.000.000/0000-00',
            keyboardType: TextInputType.number,
            inputFormatters: [DocumentoInputFormatter('CNPJ')],
            helper: 'Usado no contrato. Fica criptografado.',
            validator: (v) {
              final d = (v ?? '').replaceAll(RegExp(r'\D'), '');
              if (d.isEmpty) return 'Informe o CNPJ do estabelecimento.';
              if (d.length != 14) {
                return 'Informe um CNPJ válido com 14 dígitos.';
              }
              return _serverErrors['cnpj'];
            },
          ),
          const CadastroSection('Endereço'),
          _cepRow(isDark, accent),
          if (_cepAviso != null) CadastroErrorText(_cepAviso!),
          CadastroTextField(
            fieldKey: 'completar-cadastro:logradouro',
            controller: _logradouro,
            label: 'Logradouro',
            hint: 'Rua, avenida...',
            textCapitalization: TextCapitalization.words,
            validator: (v) => (v ?? '').trim().isEmpty
                ? 'Informe o logradouro.'
                : _serverErrors['logradouro'],
          ),
          CadastroTextField(
            fieldKey: 'completar-cadastro:numero',
            controller: _numero,
            label: 'Número',
            hint: 'Ex.: 100',
            validator: (v) => (v ?? '').trim().isEmpty
                ? 'Informe o número.'
                : _serverErrors['numero'],
          ),
          CadastroTextField(
            fieldKey: 'completar-cadastro:bairro',
            controller: _bairro,
            label: 'Bairro',
            textCapitalization: TextCapitalization.words,
            validator: (v) => (v ?? '').trim().isEmpty
                ? 'Informe o bairro.'
                : _serverErrors['bairro'],
          ),
          CadastroTextField(
            fieldKey: 'completar-cadastro:cidade',
            controller: _cidade,
            label: 'Cidade',
            textCapitalization: TextCapitalization.words,
            validator: (v) => (v ?? '').trim().isEmpty
                ? 'Informe a cidade.'
                : _serverErrors['cidade'],
          ),
          CadastroDropdownField<String>(
            fieldKey: 'completar-cadastro:uf',
            label: 'UF',
            hint: 'Selecione',
            value: _uf,
            items: _ufs
                .map((uf) => DropdownMenuItem(value: uf, child: Text(uf)))
                .toList(),
            onChanged: (v) => setState(() => _uf = v),
            validator: (v) =>
                v == null ? 'Selecione a UF.' : _serverErrors['uf'],
          ),
          CadastroTextField(
            fieldKey: 'completar-cadastro:complemento',
            controller: _complemento,
            label: 'Complemento (opcional)',
            hint: 'Sala, andar...',
          ),
          const CadastroSection('Identificação'),
          CadastroTextField(
            fieldKey: 'completar-cadastro:apelido',
            controller: _apelido,
            label: 'Apelido do estabelecimento (opcional)',
            hint: 'Nome curto usado na plataforma',
            validator: (v) => (v ?? '').length > 60
                ? 'O apelido deve ter no máximo 60 caracteres.'
                : null,
          ),
        ],
      ),
    );
  }

  Widget _cepRow(bool isDark, Color accent) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: CadastroTextField(
            fieldKey: 'completar-cadastro:cep',
            controller: _cep,
            label: 'CEP',
            hint: '00000-000',
            keyboardType: TextInputType.number,
            inputFormatters: [CepInputFormatter()],
            validator: (v) {
              final d = (v ?? '').replaceAll(RegExp(r'\D'), '');
              if (d.length != 8) return 'Informe um CEP válido.';
              return _serverErrors['cep'];
            },
          ),
        ),
        const SizedBox(width: TurniSpacing.sm),
        Padding(
          padding: const EdgeInsets.only(top: TurniSpacing.lg),
          child: OutlinedButton(
            key: const Key('completar-cadastro:cep-buscar'),
            onPressed: _buscandoCep ? null : _buscarCep,
            style: OutlinedButton.styleFrom(
              foregroundColor: accent,
              side: BorderSide(color: accent),
              minimumSize: const Size(72, 56),
            ),
            child: _buscandoCep
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Buscar'),
          ),
        ),
      ],
    );
  }

  Widget _stepOperacao(bool isDark, Color accent) {
    final anoAtual = DateTime.now().year;
    return Form(
      key: _form2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CadastroTextField(
            fieldKey: 'completar-cadastro:segmento',
            controller: _segmento,
            label: 'Segmento',
            hint: 'Ex.: Restaurante italiano, bar, hotel...',
            textCapitalization: TextCapitalization.sentences,
            validator: (v) => (v ?? '').trim().isEmpty
                ? 'Informe o segmento.'
                : _serverErrors['segmento'],
          ),
          CadastroTextField(
            fieldKey: 'completar-cadastro:ano-fundacao',
            controller: _ano,
            label: 'Ano de fundação',
            hint: 'Ex.: 2015',
            keyboardType: TextInputType.number,
            validator: (v) {
              final n = int.tryParse((v ?? '').replaceAll(RegExp(r'\D'), ''));
              if (n == null) return 'Informe o ano de fundação.';
              if (n < 1900 || n > anoAtual) {
                return 'Informe um ano entre 1900 e $anoAtual.';
              }
              return _serverErrors['ano_fundacao'];
            },
          ),
          CadastroDropdownField<String>(
            fieldKey: 'completar-cadastro:qtd-funcionarios',
            label: 'Quantidade de funcionários',
            hint: 'Selecione uma faixa',
            value: _qtdFuncionarios,
            items: _faixasFuncionarios
                .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                .toList(),
            onChanged: (v) => setState(() => _qtdFuncionarios = v),
            validator: (v) => v == null
                ? 'Selecione uma faixa.'
                : _serverErrors['qtd_funcionarios'],
          ),
          CadastroTextField(
            fieldKey: 'completar-cadastro:turnos',
            controller: _turnos,
            label: 'Turnos de operação típicos (opcional)',
            hint: 'Ex.: Almoço e jantar',
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
    );
  }

  Widget _stepCultura(bool isDark, Color accent) {
    final muted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;
    return Form(
      key: _form3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CadastroTextField(
            fieldKey: 'completar-cadastro:cultura',
            controller: _cultura,
            label: 'Cultura e valores-chave (opcional)',
            hint: 'O que define o seu negócio?',
            textCapitalization: TextCapitalization.sentences,
            validator: (v) => (v ?? '').length > 1000
                ? 'Use no máximo 1000 caracteres.'
                : null,
          ),
          CadastroTextField(
            fieldKey: 'completar-cadastro:site',
            controller: _site,
            label: 'Site (opcional)',
            hint: 'https://...',
            keyboardType: TextInputType.url,
          ),
          CadastroTextField(
            fieldKey: 'completar-cadastro:rede-instagram',
            controller: _instagram,
            label: 'Instagram (opcional)',
            hint: 'https://instagram.com/seunegocio',
            keyboardType: TextInputType.url,
          ),
          const CadastroSection('Contatos adicionais (opcional)'),
          Text(
            'Gerente, chef, sommelier... pessoas de contato no estabelecimento.',
            style: TextStyle(fontSize: 13, color: muted),
          ),
          ..._contatosFields(accent, muted),
          const SizedBox(height: TurniSpacing.sm),
          OutlinedButton.icon(
            key: const Key('completar-cadastro:contato-add'),
            onPressed: () =>
                setState(() => _contatos.add(_ContatoControllers())),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Adicionar contato'),
            style: OutlinedButton.styleFrom(
              foregroundColor: accent,
              side: BorderSide(color: accent),
            ),
          ),
          const CadastroSection('Logo (opcional)'),
          _logoField(isDark, accent, muted),
        ],
      ),
    );
  }

  List<Widget> _contatosFields(Color accent, Color muted) {
    final widgets = <Widget>[];
    for (var i = 0; i < _contatos.length; i++) {
      final c = _contatos[i];
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: TurniSpacing.sm),
          child: Column(
            children: [
              CadastroTextField(
                fieldKey: 'completar-cadastro:contato-$i-nome',
                controller: c.nome,
                label: 'Nome',
                validator: (v) => (v ?? '').trim().isEmpty
                    ? 'Informe o nome do contato.'
                    : null,
              ),
              CadastroTextField(
                fieldKey: 'completar-cadastro:contato-$i-funcao',
                controller: c.funcao,
                label: 'Função',
                validator: (v) => (v ?? '').trim().isEmpty
                    ? 'Informe a função do contato.'
                    : null,
              ),
              CadastroTextField(
                fieldKey: 'completar-cadastro:contato-$i-telefone',
                controller: c.telefone,
                label: 'Telefone (opcional)',
                keyboardType: TextInputType.phone,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: Key('completar-cadastro:contato-$i-remover'),
                  onPressed: () => setState(() {
                    _contatos.removeAt(i).dispose();
                  }),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Remover'),
                  style: TextButton.styleFrom(foregroundColor: accent),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  Widget _logoField(bool isDark, Color accent, Color muted) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          key: const Key('completar-cadastro:logo-anexar'),
          onPressed: _pickLogo,
          icon: const Icon(Icons.upload_file),
          label: Text(_logo == null ? 'Anexar logo' : 'Trocar logo'),
          style: OutlinedButton.styleFrom(
            foregroundColor: accent,
            side: BorderSide(color: accent),
          ),
        ),
        if (_logo != null)
          Padding(
            padding: const EdgeInsets.only(top: TurniSpacing.xs),
            child: Text(
              _logo!.filename,
              key: const Key('completar-cadastro:logo-nome'),
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ),
        if (_logoError != null) CadastroErrorText(_logoError!),
      ],
    );
  }

  Widget _navPasso(Color accent) {
    final ultimo = _step == 2;
    return Row(
      children: [
        if (_step > 0) ...[
          Expanded(
            child: OutlinedButton(
              key: const Key('completar-cadastro:voltar-step'),
              onPressed: _loading ? null : _voltarStep,
              style: OutlinedButton.styleFrom(
                foregroundColor: accent,
                side: BorderSide(color: accent),
                minimumSize: const Size(0, 52),
              ),
              child: const Text('Voltar'),
            ),
          ),
          const SizedBox(width: TurniSpacing.sm),
        ],
        Expanded(
          flex: 2,
          child: _botao(
            key: ultimo
                ? 'completar-cadastro:revisar'
                : 'completar-cadastro:continuar',
            label: ultimo ? 'Revisar termos' : 'Continuar',
            onPressed: _loading ? null : (ultimo ? _revisar : _avancar),
            accent: accent,
          ),
        ),
      ],
    );
  }

  Widget _previewView(bool isDark, Color accent) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(
          'Revise e aceite os termos',
          'Leia os Termos de Adesão à Plataforma com seus dados. Você só conclui o cadastro após aceitar.',
          isDark,
        ),
        Container(
          key: const Key('completar-cadastro:contrato'),
          padding: const EdgeInsets.all(TurniSpacing.md),
          decoration: BoxDecoration(
            color: isDark ? TurniColors.surfaceDark : TurniColors.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? TurniColors.borderSubtleDark
                  : TurniColors.borderSubtleLight,
            ),
          ),
          constraints: const BoxConstraints(maxHeight: 420),
          child: SingleChildScrollView(child: ContractView(_contrato)),
        ),
        const SizedBox(height: TurniSpacing.md),
        _consentimento(isDark, accent),
        const SizedBox(height: TurniSpacing.md),
        _botao(
          key: 'completar-cadastro:concluir',
          label: 'Aceito e concluir cadastro',
          onPressed: (_aceitou && !_loading) ? _aceitar : null,
          accent: accent,
        ),
        const SizedBox(height: TurniSpacing.sm),
        Center(
          child: TextButton(
            key: const Key('completar-cadastro:voltar'),
            onPressed: _loading
                ? null
                : () => setState(() => _fase = _Fase.form),
            style: TextButton.styleFrom(foregroundColor: accent),
            child: const Text('Voltar e editar os dados'),
          ),
        ),
        if (_banner != null) ...[
          const SizedBox(height: TurniSpacing.md),
          CadastroBannerWidget(
            banner: _banner!,
            isDark: isDark,
            onLogin: () => context.go('/login'),
            onRetry: _aceitar,
          ),
        ],
      ],
    );
  }

  Widget _sucessoView(Color accent) {
    return Column(
      key: const Key('completar-cadastro:sucesso'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle, color: accent, size: 56),
        const SizedBox(height: TurniSpacing.md),
        Text(
          'Cadastro concluído!',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: TurniSpacing.sm),
        const Text(
          'Seu aceite foi registrado e o estabelecimento já está ativo na Turni. '
          'Em breve você poderá publicar vagas por aqui.',
          style: TextStyle(fontSize: 15, height: 1.5),
        ),
        const SizedBox(height: TurniSpacing.xl),
        _botao(
          key: 'completar-cadastro:continuar-home',
          label: 'Continuar',
          onPressed: () => context.go('/'),
          accent: accent,
        ),
      ],
    );
  }

  /// Consentimento explícito dos Termos de Adesão (CA-8). Distinto do aceite de
  /// Termos/Política do pré-cadastro.
  Widget _consentimento(bool isDark, Color accent) {
    final textColor = isDark
        ? TurniColors.textStrongDark
        : TurniColors.textStrongLight;
    return InkWell(
      key: const Key('completar-cadastro:aceite'),
      onTap: () => setState(() => _aceitou = !_aceitou),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _aceitou,
            activeColor: accent,
            onChanged: (v) => setState(() => _aceitou = v ?? false),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: TurniSpacing.sm),
              child: Text(
                'Li, entendi e aceito os Termos de Adesão à Plataforma apresentados acima.',
                style: TextStyle(color: textColor, fontSize: 14, height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(String titulo, String subtitulo, bool isDark) {
    final muted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            titulo,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: TurniSpacing.xs),
        Text(subtitulo, style: TextStyle(fontSize: 14, color: muted)),
        const SizedBox(height: TurniSpacing.md),
      ],
    );
  }

  Widget _botao({
    required String key,
    required String label,
    required VoidCallback? onPressed,
    required Color accent,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        key: Key(key),
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          shape: const StadiumBorder(),
        ),
        child: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

/// Controllers de uma linha de contato adicional (lista dinâmica).
class _ContatoControllers {
  final nome = TextEditingController();
  final funcao = TextEditingController();
  final telefone = TextEditingController();

  void dispose() {
    nome.dispose();
    funcao.dispose();
    telefone.dispose();
  }
}

/// Barra de progresso dos 3 passos do wizard.
class _Progresso extends StatelessWidget {
  const _Progresso({
    required this.step,
    required this.accent,
    required this.isDark,
  });

  final int step; // 0..2
  final Color accent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final muted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;
    return Semantics(
      label: 'Passo ${step + 1} de 3',
      child: Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: i <= step ? accent : muted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (i < 2) const SizedBox(width: TurniSpacing.xs),
          ],
          const SizedBox(width: TurniSpacing.sm),
          Text('${step + 1}/3', style: TextStyle(fontSize: 12, color: muted)),
        ],
      ),
    );
  }
}
