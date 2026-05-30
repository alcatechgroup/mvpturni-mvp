import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ds/tokens.dart';
import 'password_reset_service.dart';

/// Redefinição de senha (STORY-021 CA-6/CA-13b — SCREEN-STORY-016 Tela F).
/// Destino do link do e-mail `recuperacao_senha`: /redefinir-senha?token=…&email=…
/// O usuário define a nova senha → POST /reset-password (Fortify via api).
class RedefinirSenhaScreen extends StatefulWidget {
  const RedefinirSenhaScreen({
    super.key,
    required this.token,
    required this.email,
    this.service,
  });

  final String token;
  final String email;

  /// Injetável em testes.
  final PasswordResetService? service;

  @override
  State<RedefinirSenhaScreen> createState() => _RedefinirSenhaScreenState();
}

class _RedefinirSenhaScreenState extends State<RedefinirSenhaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  late final PasswordResetService _service =
      widget.service ?? PasswordResetService();

  bool _obscure = true;
  bool _loading = false;
  bool _done = false;
  String? _error;
  bool _tokenInvalido = false;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await _service.reset(
      token: widget.token,
      email: widget.email,
      password: _passwordCtrl.text,
      passwordConfirmation: _confirmCtrl.text,
    );

    if (!mounted) return;
    setState(() {
      _loading = false;
      switch (result) {
        case ResetOk():
          _done = true;
        case ResetInvalidToken():
          _tokenInvalido = true;
        case ResetValidationError(:final message):
          _error = message;
        case ResetNetworkError():
          _error =
              'Não conseguimos redefinir agora. Tente de novo em instantes.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? TurniColors.accentDark : TurniColors.accentLight;
    final surfacePage = isDark
        ? TurniColors.surfacePageDark
        : TurniColors.surfacePageLight;
    final textMuted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;

    return Scaffold(
      key: const Key('screen-redefinir-senha'),
      backgroundColor: surfacePage,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(TurniSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TURNI.',
                  semanticsLabel: 'Turni',
                  style: TextStyle(
                    fontFamily: 'BebasNeue',
                    fontSize: 36,
                    fontWeight: FontWeight.w400,
                    color: TurniColors.brandGreen,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: TurniSpacing.lg),
                if (_done)
                  _buildDone(context, accent)
                else if (_tokenInvalido ||
                    widget.token.isEmpty ||
                    widget.email.isEmpty)
                  _buildTokenInvalido(context, accent, textMuted)
                else
                  _buildForm(context, accent, textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, Color accent, Color textMuted) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Defina uma nova senha para ${widget.email}.',
            style: TextStyle(fontSize: 14, color: textMuted),
          ),
          const SizedBox(height: TurniSpacing.xl),
          TextFormField(
            key: const Key('input-password'),
            controller: _passwordCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Nova senha',
              suffixIcon: IconButton(
                key: const Key('toggle-obscure'),
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Este campo é obrigatório.';
              if (v.length < 8) {
                return 'A senha deve ter ao menos 8 caracteres.';
              }
              return null;
            },
          ),
          const SizedBox(height: TurniSpacing.lg),
          TextFormField(
            key: const Key('input-password-confirm'),
            controller: _confirmCtrl,
            obscureText: _obscure,
            decoration: const InputDecoration(
              labelText: 'Confirme a nova senha',
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Este campo é obrigatório.';
              if (v != _passwordCtrl.text) return 'As senhas não coincidem.';
              return null;
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: TurniSpacing.md),
            Text(
              _error!,
              key: const Key('redefinir-error'),
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: TurniSpacing.lg),
          SizedBox(
            height: 52,
            child: FilledButton(
              key: const Key('btn-submit-redefinir'),
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
                  : const Text('Redefinir senha'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDone(BuildContext context, Color accent) {
    return Column(
      key: const Key('redefinir-success'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: Container(
            padding: const EdgeInsets.all(TurniSpacing.md),
            decoration: BoxDecoration(
              color: TurniColors.successSoftLight,
              border: Border.all(
                color: TurniColors.successLight.withAlpha(128),
              ),
              borderRadius: BorderRadius.all(TurniRadius.md),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 18,
                  color: TurniColors.successLight,
                ),
                SizedBox(width: TurniSpacing.sm),
                Expanded(
                  child: Text(
                    'Senha redefinida com sucesso. Você já pode entrar com a nova senha.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: TurniSpacing.lg),
        SizedBox(
          height: 52,
          child: FilledButton(
            key: const Key('btn-ir-login'),
            onPressed: () => context.go('/login'),
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              shape: const StadiumBorder(),
            ),
            child: const Text('Ir para o login'),
          ),
        ),
      ],
    );
  }

  Widget _buildTokenInvalido(
    BuildContext context,
    Color accent,
    Color textMuted,
  ) {
    return Column(
      key: const Key('redefinir-token-invalido'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Este link de redefinição é inválido ou expirou. Peça um novo link.',
          style: TextStyle(fontSize: 14, color: textMuted),
        ),
        const SizedBox(height: TurniSpacing.lg),
        SizedBox(
          height: 52,
          child: FilledButton(
            key: const Key('btn-pedir-novo-link'),
            onPressed: () => context.go('/esqueci-minha-senha'),
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              shape: const StadiumBorder(),
            ),
            child: const Text('Pedir novo link'),
          ),
        ),
      ],
    );
  }
}
