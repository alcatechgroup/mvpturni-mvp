import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../ds/components/app_version_label.dart';
import '../../ds/tokens.dart';
import 'cadastro_service.dart';
import 'shared/cadastro_widgets.dart';

/// Tela de pré-cadastro de profissional (STORY-017 — SCREEN-STORY-017, Vista A + B).
/// Pública (sem auth). Perfil pré-login = profissional/verde (DDR-001).
/// Não autentica após o envio — o usuário aguarda aprovação (SLA 24h).
/// Componentes de formulário em `shared/` (IDR-012), compartilhados com o contratante.
class PreCadastroProfissionalScreen extends StatefulWidget {
  const PreCadastroProfissionalScreen({
    super.key,
    this.service,
    this.photoPicker,
  });

  /// Injetável para teste; em produção usa o serviço real.
  final CadastroService? service;

  /// Injetável para teste; em produção usa o image_picker.
  final Future<FotoUpload?> Function()? photoPicker;

  @override
  State<PreCadastroProfissionalScreen> createState() =>
      _PreCadastroProfissionalScreenState();
}

class _PreCadastroProfissionalScreenState
    extends State<PreCadastroProfissionalScreen> {
  late final CadastroService _service = widget.service ?? CadastroService();

  final _formKey = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _telefone = TextEditingController();
  final _cidade = TextEditingController();
  final _bairro = TextEditingController();
  final _senha = TextEditingController();
  final _confirma = TextEditingController();

  List<Funcao> _funcoes = [];
  int? _funcaoId;
  String? _tipoPessoa; // PF | MEI | PJ — nenhum selecionado por padrão
  FotoUpload? _foto;

  bool _obscureSenha = true;
  bool _obscureConfirma = true;
  bool _termos = false;

  bool _loading = false;
  bool _submitted = false; // troca para a Vista B (recebido)

  // Erros que não são de TextFormField (mostrados manualmente).
  String? _tipoError;
  String? _fotoError;
  String? _termosError;

  // Erros vindos do servidor (422 por campo), consultados pelos validators.
  final Map<String, String> _serverErrors = {};

  // Banner de estado (erro genérico / throttle / servidor).
  CadastroBanner? _banner;

  @override
  void initState() {
    super.initState();
    _loadFuncoes();
  }

  Future<void> _loadFuncoes() async {
    final funcoes = await _service.fetchFuncoes();
    if (!mounted) return;
    setState(() => _funcoes = funcoes);
  }

  @override
  void dispose() {
    for (final c in [
      _nome,
      _email,
      _telefone,
      _cidade,
      _bairro,
      _senha,
      _confirma,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickFoto() async {
    final picker = widget.photoPicker ?? _defaultPhotoPicker;
    FotoUpload? foto;
    try {
      foto = await picker();
    } catch (_) {
      // Falha/cancelamento ao selecionar — mantém sem foto; a validação cobra.
      return;
    }
    if (foto == null || !mounted) return;

    final lower = foto.filename.toLowerCase();
    final extOk =
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png');
    if (!extOk) {
      setState(() => _fotoError = 'A foto deve ser JPG ou PNG.');
      return;
    }
    if (foto.bytes.length > 5 * 1024 * 1024) {
      setState(() => _fotoError = 'A foto deve ter no máximo 5 MB.');
      return;
    }
    setState(() {
      _foto = foto;
      _fotoError = null;
    });
  }

  Future<FotoUpload?> _defaultPhotoPicker() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return FotoUpload(bytes: bytes, filename: file.name);
  }

  bool _validateExtras() {
    setState(() {
      _tipoError = _tipoPessoa == null
          ? 'Selecione o tipo de cadastro: PF, MEI ou PJ.'
          : null;
      _fotoError = _foto == null ? 'Adicione uma foto.' : _fotoError;
      _termosError = !_termos
          ? 'É necessário aceitar os Termos de Uso e a Política de Privacidade.'
          : null;
    });
    return _tipoError == null && _foto != null && _termosError == null;
  }

  Future<void> _submit() async {
    _serverErrors.clear();
    final formOk = _formKey.currentState!.validate();
    final extrasOk = _validateExtras();
    if (!formOk || !extrasOk) return;

    setState(() {
      _loading = true;
      _banner = null;
    });

    final result = await _service.cadastrar(
      name: _nome.text.trim(),
      email: _email.text.trim(),
      telefone: _telefone.text.trim(),
      cidade: _cidade.text.trim(),
      bairro: _bairro.text.trim(),
      funcaoId: _funcaoId!,
      tipoPessoa: _tipoPessoa!,
      password: _senha.text,
      passwordConfirmation: _confirma.text,
      termosAceitos: _termos,
      foto: _foto!,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    switch (result) {
      case CadastroSuccess():
        setState(() => _submitted = true);
      case CadastroValidationError(:final errors):
        setState(() => _serverErrors.addAll(errors));
        _formKey.currentState!.validate();
        if (errors.containsKey('foto')) {
          setState(() => _fotoError = errors['foto']);
        }
      case CadastroGenericError(:final message):
        setState(() => _banner = CadastroBanner.generic(message));
      case CadastroThrottle():
        setState(() => _banner = CadastroBanner.throttle());
      case CadastroServerError():
        setState(() => _banner = CadastroBanner.server());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfacePage = isDark
        ? TurniColors.surfacePageDark
        : TurniColors.surfacePageLight;
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 840;
    final accent = isDark ? TurniColors.accentDark : TurniColors.accentLight;

    return Scaffold(
      key: const Key('screen-cadastro-profissional'),
      backgroundColor: surfacePage,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: TurniSpacing.lg,
            vertical: isDesktop ? TurniSpacing.x3l : TurniSpacing.x2l,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isDesktop ? 560 : 480),
            child: _submitted
                ? CadastroSuccessView(accent: accent)
                : (isDesktop
                      ? Card(
                          child: Padding(
                            padding: const EdgeInsets.all(TurniSpacing.xl),
                            child: _buildForm(isDark, isDesktop, accent),
                          ),
                        )
                      : _buildForm(isDark, isDesktop, accent)),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(bool isDark, bool isDesktop, Color accent) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const Key('link-entrar'),
              onPressed: () => context.go('/login'),
              style: TextButton.styleFrom(foregroundColor: accent),
              child: const Text('Já tem conta? Entrar'),
            ),
          ),
          Semantics(
            label: 'Turni',
            header: true,
            child: const Text(
              'TURNI.',
              style: TextStyle(
                fontFamily: 'BebasNeue',
                fontSize: 40,
                color: TurniColors.brandGreen,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(height: TurniSpacing.md),
          Text(
            'Criar conta de profissional',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: TurniSpacing.xs),
          Text(
            'Leva 2 minutos. A equipe Turni revisa em até 24h.',
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? TurniColors.textMutedDark
                  : TurniColors.textMutedLight,
            ),
          ),

          const CadastroSection('Seus dados'),
          CadastroTextField(
            fieldKey: 'input-nome',
            controller: _nome,
            label: 'Nome completo',
            hint: 'Ex.: Diego Almeida',
            textCapitalization: TextCapitalization.words,
            validator: (v) {
              final t = v?.trim() ?? '';
              if (t.isEmpty) return 'Informe seu nome completo.';
              if (t.length < 3) return 'O nome deve ter ao menos 3 caracteres.';
              if (t.length > 120)
                return 'O nome deve ter no máximo 120 caracteres.';
              return _serverErrors['name'];
            },
          ),
          CadastroTextField(
            fieldKey: 'input-email',
            controller: _email,
            label: 'E-mail',
            hint: 'seunome@email.com',
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              final t = v?.trim() ?? '';
              if (t.isEmpty) return 'Informe seu e-mail.';
              if (!t.contains('@') || !t.contains('.')) {
                return 'Informe um e-mail válido (ex.: nome@dominio.com).';
              }
              return _serverErrors['email'];
            },
          ),
          CadastroTextField(
            fieldKey: 'input-telefone',
            controller: _telefone,
            label: 'Telefone',
            hint: 'Ex.: (11) 91234-5678',
            keyboardType: TextInputType.phone,
            helper: 'Use o número com DDD que recebe WhatsApp.',
            validator: (v) {
              final t = v?.trim() ?? '';
              if (t.isEmpty) return 'Informe seu telefone.';
              final digits = t.replaceAll(RegExp(r'\D'), '');
              if (digits.length < 10 || digits.length > 11) {
                return 'Informe um telefone válido com DDD (ex.: (11) 91234-5678).';
              }
              return _serverErrors['telefone'];
            },
          ),

          const CadastroSection('Onde você atua'),
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _cidadeField()),
                const SizedBox(width: TurniSpacing.md),
                Expanded(child: _bairroField()),
              ],
            )
          else ...[
            _cidadeField(),
            _bairroField(),
          ],
          _funcaoField(),

          const CadastroSection('Tipo de cadastro'),
          _segmented(accent),
          if (_tipoError != null) CadastroErrorText(_tipoError!),
          Padding(
            padding: const EdgeInsets.only(top: TurniSpacing.xs),
            child: Text(
              'Você envia seu documento depois da aprovação.',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? TurniColors.textMutedDark
                    : TurniColors.textMutedLight,
              ),
            ),
          ),

          const CadastroSection('Sua foto'),
          CadastroPhotoField(
            foto: _foto,
            error: _fotoError,
            onPick: _pickFoto,
            accent: accent,
            isDark: isDark,
          ),

          const CadastroSection('Sua senha'),
          CadastroPasswordField(
            fieldKey: 'input-password',
            controller: _senha,
            label: 'Senha',
            obscure: _obscureSenha,
            onToggle: () => setState(() => _obscureSenha = !_obscureSenha),
            helper:
                'Use 10+ caracteres, com letras maiúsculas, minúsculas e números.',
            validator: (v) {
              final t = v ?? '';
              final strong =
                  t.length >= 10 &&
                  RegExp(r'[A-Z]').hasMatch(t) &&
                  RegExp(r'[a-z]').hasMatch(t) &&
                  RegExp(r'\d').hasMatch(t);
              if (!strong) {
                return 'A senha deve ter ao menos 10 caracteres, com maiúscula, minúscula e número.';
              }
              return _serverErrors['password'];
            },
          ),
          CadastroPasswordField(
            fieldKey: 'input-password-confirm',
            controller: _confirma,
            label: 'Confirmar senha',
            obscure: _obscureConfirma,
            onToggle: () =>
                setState(() => _obscureConfirma = !_obscureConfirma),
            validator: (v) {
              if ((v ?? '') != _senha.text) return 'As senhas não conferem.';
              return null;
            },
          ),

          const SizedBox(height: TurniSpacing.sm),
          CadastroTermsCheckbox(
            value: _termos,
            onChanged: (v) => setState(() {
              _termos = v;
              if (_termos) _termosError = null;
            }),
            accent: accent,
            isDark: isDark,
          ),
          if (_termosError != null) CadastroErrorText(_termosError!),

          const SizedBox(height: TurniSpacing.md),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              key: const Key('btn-submit-cadastro'),
              onPressed: _loading ? null : _submit,
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
                  : const Text(
                      'Enviar cadastro',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),

          if (_banner != null) ...[
            const SizedBox(height: TurniSpacing.md),
            CadastroBannerWidget(
              banner: _banner!,
              isDark: isDark,
              onLogin: () => context.go('/login'),
              onRetry: _submit,
            ),
          ],

          // Versão rodando no dispositivo — rodapé discreto (STORY-037 CA-9).
          const SizedBox(height: TurniSpacing.lg),
          const Center(
            child: AppVersionLabel(
              key: Key('app-version-label-cadastro-profissional'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cidadeField() => CadastroTextField(
    fieldKey: 'input-cidade',
    controller: _cidade,
    label: 'Cidade',
    textCapitalization: TextCapitalization.words,
    validator: (v) => (v?.trim().isEmpty ?? true)
        ? 'Informe sua cidade.'
        : _serverErrors['cidade'],
  );

  Widget _bairroField() => CadastroTextField(
    fieldKey: 'input-bairro',
    controller: _bairro,
    label: 'Bairro',
    textCapitalization: TextCapitalization.words,
    validator: (v) => (v?.trim().isEmpty ?? true)
        ? 'Informe seu bairro.'
        : _serverErrors['bairro'],
  );

  Widget _funcaoField() => CadastroDropdownField<int>(
    fieldKey: 'input-funcao',
    label: 'Função pretendida',
    hint: 'Escolha a principal',
    value: _funcaoId,
    items: _funcoes
        .map((f) => DropdownMenuItem(value: f.id, child: Text(f.nome)))
        .toList(),
    onChanged: (v) => setState(() => _funcaoId = v),
    validator: (v) => v == null
        ? 'Selecione a função pretendida.'
        : _serverErrors['funcao_id'],
  );

  Widget _segmented(Color accent) {
    return Semantics(
      label: 'Tipo de pessoa',
      child: SegmentedButton<String>(
        key: const Key('segmented-tipo-pessoa'),
        segments: const [
          ButtonSegment(
            value: 'PF',
            label: Text('PF', key: Key('segment-pf')),
          ),
          ButtonSegment(
            value: 'MEI',
            label: Text('MEI', key: Key('segment-mei')),
          ),
          ButtonSegment(
            value: 'PJ',
            label: Text('PJ', key: Key('segment-pj')),
          ),
        ],
        selected: _tipoPessoa == null ? <String>{} : {_tipoPessoa!},
        emptySelectionAllowed: true,
        showSelectedIcon: false,
        onSelectionChanged: (s) => setState(() {
          _tipoPessoa = s.isEmpty ? null : s.first;
          _tipoError = null;
        }),
      ),
    );
  }
}
