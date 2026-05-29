import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../ds/tokens.dart';
import 'cadastro_service.dart';

/// Tela de pré-cadastro de profissional (STORY-017 — SCREEN-STORY-017, Vista A + B).
/// Pública (sem auth). Perfil pré-login = profissional/verde (DDR-001).
/// Não autentica após o envio — o usuário aguarda aprovação (SLA 24h).
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
  _Banner? _banner;

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
        setState(() => _banner = _Banner.generic(message));
      case CadastroThrottle():
        setState(() => _banner = _Banner.throttle());
      case CadastroServerError():
        setState(() => _banner = _Banner.server());
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
                ? _SuccessView(isDesktop: isDesktop)
                : (isDesktop
                      ? Card(
                          child: Padding(
                            padding: const EdgeInsets.all(TurniSpacing.xl),
                            child: _buildForm(isDark, isDesktop),
                          ),
                        )
                      : _buildForm(isDark, isDesktop)),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(bool isDark, bool isDesktop) {
    final accent = isDark ? TurniColors.accentDark : TurniColors.accentLight;

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

          _section('Seus dados'),
          _textField(
            key: 'input-nome',
            controller: _nome,
            label: 'Nome completo',
            hint: 'Ex.: Diego Almeida',
            textCapitalization: TextCapitalization.words,
            field: 'name',
            validator: (v) {
              final t = v?.trim() ?? '';
              if (t.isEmpty) return 'Informe seu nome completo.';
              if (t.length < 3) return 'O nome deve ter ao menos 3 caracteres.';
              if (t.length > 120) {
                return 'O nome deve ter no máximo 120 caracteres.';
              }
              return _serverErrors['name'];
            },
          ),
          _textField(
            key: 'input-email',
            controller: _email,
            label: 'E-mail',
            hint: 'seunome@email.com',
            keyboardType: TextInputType.emailAddress,
            field: 'email',
            validator: (v) {
              final t = v?.trim() ?? '';
              if (t.isEmpty) return 'Informe seu e-mail.';
              if (!t.contains('@') || !t.contains('.')) {
                return 'Informe um e-mail válido (ex.: nome@dominio.com).';
              }
              return _serverErrors['email'];
            },
          ),
          _textField(
            key: 'input-telefone',
            controller: _telefone,
            label: 'Telefone',
            hint: 'Ex.: (11) 91234-5678',
            keyboardType: TextInputType.phone,
            field: 'telefone',
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

          _section('Onde você atua'),
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

          _section('Tipo de cadastro'),
          _segmented(accent, isDark),
          if (_tipoError != null) _errorText(_tipoError!),
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

          _section('Sua foto'),
          _photoField(accent, isDark),

          _section('Sua senha'),
          _passwordField(
            key: 'input-password',
            controller: _senha,
            label: 'Senha',
            obscure: _obscureSenha,
            onToggle: () => setState(() => _obscureSenha = !_obscureSenha),
            helper:
                'Use 10+ caracteres, com letras maiúsculas, minúsculas e números.',
            field: 'password',
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
          _passwordField(
            key: 'input-password-confirm',
            controller: _confirma,
            label: 'Confirmar senha',
            obscure: _obscureConfirma,
            onToggle: () =>
                setState(() => _obscureConfirma = !_obscureConfirma),
            field: 'password_confirmation',
            validator: (v) {
              if ((v ?? '') != _senha.text) return 'As senhas não conferem.';
              return null;
            },
          ),

          const SizedBox(height: TurniSpacing.sm),
          _termosCheckbox(accent, isDark),
          if (_termosError != null) _errorText(_termosError!),

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
            _BannerWidget(
              banner: _banner!,
              isDark: isDark,
              onLogin: () => context.go('/login'),
              onRetry: _submit,
            ),
          ],
        ],
      ),
    );
  }

  Widget _cidadeField() => _textField(
    key: 'input-cidade',
    controller: _cidade,
    label: 'Cidade',
    textCapitalization: TextCapitalization.words,
    field: 'cidade',
    validator: (v) => (v?.trim().isEmpty ?? true)
        ? 'Informe sua cidade.'
        : _serverErrors['cidade'],
  );

  Widget _bairroField() => _textField(
    key: 'input-bairro',
    controller: _bairro,
    label: 'Bairro',
    textCapitalization: TextCapitalization.words,
    field: 'bairro',
    validator: (v) => (v?.trim().isEmpty ?? true)
        ? 'Informe seu bairro.'
        : _serverErrors['bairro'],
  );

  Widget _funcaoField() {
    return Padding(
      key: const Key('input-funcao-field'),
      padding: const EdgeInsets.only(top: TurniSpacing.md),
      child: DropdownButtonFormField<int>(
        key: const Key('input-funcao'),
        initialValue: _funcaoId,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Função pretendida',
          hintText: 'Escolha a principal',
        ),
        items: _funcoes
            .map((f) => DropdownMenuItem(value: f.id, child: Text(f.nome)))
            .toList(),
        onChanged: (v) => setState(() => _funcaoId = v),
        validator: (v) => v == null
            ? 'Selecione a função pretendida.'
            : _serverErrors['funcao_id'],
      ),
    );
  }

  Widget _segmented(Color accent, bool isDark) {
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

  Widget _photoField(Color accent, bool isDark) {
    final border = isDark
        ? TurniColors.borderSubtleDark
        : TurniColors.borderStrongLight;
    if (_foto != null) {
      return Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: accent,
            child: Icon(
              Icons.check,
              color: isDark
                  ? TurniColors.onAccentDark
                  : TurniColors.onAccentLight,
            ),
          ),
          const SizedBox(width: TurniSpacing.md),
          TextButton(
            key: const Key('btn-trocar-foto'),
            onPressed: _pickFoto,
            style: TextButton.styleFrom(foregroundColor: accent),
            child: const Text('Trocar foto'),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label: 'Adicionar foto',
          onTap: _pickFoto,
          excludeSemantics: true,
          child: InkWell(
            key: const Key('input-foto'),
            onTap: _pickFoto,
            borderRadius: const BorderRadius.all(TurniRadius.lg),
            child: Container(
              padding: const EdgeInsets.all(TurniSpacing.md),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _fotoError != null
                      ? (isDark
                            ? TurniColors.errorDark
                            : TurniColors.errorLight)
                      : border,
                  width: 2,
                  style: BorderStyle.solid,
                ),
                borderRadius: const BorderRadius.all(TurniRadius.lg),
              ),
              child: Row(
                children: [
                  Icon(Icons.add_a_photo_outlined, color: accent),
                  const SizedBox(width: TurniSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Adicionar foto',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? TurniColors.textStrongDark
                                : TurniColors.textStrongLight,
                          ),
                        ),
                        Text(
                          'JPG ou PNG, até 5 MB.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? TurniColors.textMutedDark
                                : TurniColors.textMutedLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_fotoError != null) _errorText(_fotoError!),
      ],
    );
  }

  Widget _termosCheckbox(Color accent, bool isDark) {
    final textColor = isDark
        ? TurniColors.textStrongDark
        : TurniColors.textStrongLight;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          key: const Key('check-termos'),
          value: _termos,
          activeColor: accent,
          onChanged: (v) => setState(() {
            _termos = v ?? false;
            if (_termos) _termosError = null;
          }),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: TurniSpacing.sm),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Li e aceito os ', style: TextStyle(color: textColor)),
                InkWell(
                  key: const Key('link-termos'),
                  onTap: () {},
                  child: Text(
                    'Termos de Uso',
                    style: TextStyle(
                      color: accent,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                Text(' e a ', style: TextStyle(color: textColor)),
                InkWell(
                  key: const Key('link-privacidade'),
                  onTap: () {},
                  child: Text(
                    'Política de Privacidade',
                    style: TextStyle(
                      color: accent,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                Text('.', style: TextStyle(color: textColor)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── helpers de UI ──

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(
      top: TurniSpacing.lg,
      bottom: TurniSpacing.sm,
    ),
    child: Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: .4,
        color: Color(0xFF6F7C72),
      ),
    ),
  );

  Widget _textField({
    required String key,
    required TextEditingController controller,
    required String label,
    required String field,
    String? hint,
    String? helper,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return Padding(
      // Wrapper keyed: inserções condicionais de erros (tipo/foto/termos) reordenam
      // os filhos do Column; sem key aqui o FormFieldState seria recriado e perderia
      // o errorText recém-validado.
      key: Key('$key-field'),
      padding: const EdgeInsets.only(top: TurniSpacing.md),
      child: TextFormField(
        key: Key(key),
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helper,
          helperMaxLines: 2,
          errorMaxLines: 3,
        ),
        validator: validator,
      ),
    );
  }

  Widget _passwordField({
    required String key,
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    required String field,
    String? helper,
    String? Function(String?)? validator,
  }) {
    return Padding(
      key: Key('$key-field'),
      padding: const EdgeInsets.only(top: TurniSpacing.md),
      child: TextFormField(
        key: Key(key),
        controller: controller,
        obscureText: obscure,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          helperMaxLines: 2,
          errorMaxLines: 3,
          suffixIcon: IconButton(
            key: Key('$key-toggle'),
            tooltip: obscure ? 'Mostrar senha' : 'Ocultar senha',
            icon: Icon(
              obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
            onPressed: onToggle,
          ),
        ),
        validator: validator,
      ),
    );
  }

  Widget _errorText(String text) => Padding(
    padding: const EdgeInsets.only(top: TurniSpacing.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline, size: 16, color: TurniColors.errorLight),
        const SizedBox(width: TurniSpacing.xs),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: TurniColors.errorLight,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}

// ──────────────────────────────────────────────────────────────
// Vista B — Recebido (sucesso)
// ──────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.isDesktop});
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;
    return ConstrainedBox(
      key: const Key('panel-cadastro-recebido'),
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'TURNI.',
            style: TextStyle(
              fontFamily: 'BebasNeue',
              fontSize: 40,
              color: TurniColors.brandGreen,
              height: 1.0,
            ),
          ),
          const SizedBox(height: TurniSpacing.lg),
          Semantics(
            label: 'Sucesso',
            liveRegion: true,
            child: const Icon(
              Icons.check_circle_outline,
              size: 56,
              color: TurniColors.successLight,
            ),
          ),
          const SizedBox(height: TurniSpacing.md),
          Text(
            'Cadastro recebido.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: TurniSpacing.sm),
          Text(
            'Em até 24h a equipe Turni revisa seu cadastro e envia uma notificação por e-mail.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: muted),
          ),
          const SizedBox(height: TurniSpacing.lg),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              key: const Key('btn-voltar-home'),
              onPressed: () => context.go('/'),
              style: FilledButton.styleFrom(
                backgroundColor: isDark
                    ? TurniColors.accentDark
                    : TurniColors.accentLight,
                shape: const StadiumBorder(),
              ),
              child: const Text(
                'Voltar à home',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Banner de estado
// ──────────────────────────────────────────────────────────────

enum _BannerKind { generic, throttle, server }

class _Banner {
  final _BannerKind kind;
  final String message;
  const _Banner._(this.kind, this.message);

  factory _Banner.generic(String message) =>
      _Banner._(_BannerKind.generic, message);
  factory _Banner.throttle() => const _Banner._(
    _BannerKind.throttle,
    'Muitas tentativas. Aguarde alguns minutos antes de tentar novamente.',
  );
  factory _Banner.server() =>
      const _Banner._(_BannerKind.server, 'Não conseguimos enviar agora.');
}

class _BannerWidget extends StatelessWidget {
  const _BannerWidget({
    required this.banner,
    required this.isDark,
    required this.onLogin,
    required this.onRetry,
  });

  final _Banner banner;
  final bool isDark;
  final VoidCallback onLogin;
  final VoidCallback onRetry;

  Key get _key => switch (banner.kind) {
    _BannerKind.generic => const Key('banner-cadastro-erro'),
    _BannerKind.throttle => const Key('banner-throttle'),
    _BannerKind.server => const Key('banner-servidor'),
  };

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? TurniColors.errorSoftDark : TurniColors.errorSoftLight;
    final color = isDark ? TurniColors.errorDark : TurniColors.errorLight;
    final textColor = isDark
        ? TurniColors.textStrongDark
        : TurniColors.textStrongLight;

    return Semantics(
      liveRegion: true,
      child: Container(
        key: _key,
        padding: const EdgeInsets.all(TurniSpacing.md),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: color.withAlpha(128)),
          borderRadius: const BorderRadius.all(TurniRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, size: 18, color: color),
                const SizedBox(width: TurniSpacing.sm),
                Expanded(
                  child: Text(
                    banner.message,
                    style: TextStyle(fontSize: 13, color: textColor),
                  ),
                ),
              ],
            ),
            if (banner.kind == _BannerKind.generic)
              TextButton(
                onPressed: onLogin,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 36),
                ),
                child: const Text('Já tem conta? Entrar'),
              ),
            if (banner.kind == _BannerKind.server)
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 36),
                ),
                child: const Text('Tentar de novo'),
              ),
          ],
        ),
      ),
    );
  }
}
