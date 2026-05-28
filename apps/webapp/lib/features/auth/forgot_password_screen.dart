import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ds/tokens.dart';

/// Stub de recuperação de senha (CA-5 — SCREEN-STORY-016 Tela E).
/// Tela real com envio de e-mail chega em STORY-021.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    // Stub: aguarda 1s simulando envio (Fortify real vem em STORY-021).
    await Future.delayed(const Duration(seconds: 1));
    if (mounted)
      setState(() {
        _loading = false;
        _sent = true;
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
      key: const Key('screen-forgot-password'),
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
                TextButton.icon(
                  onPressed: () => context.go('/login'),
                  style: TextButton.styleFrom(
                    foregroundColor: accent,
                    padding: EdgeInsets.zero,
                  ),
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Voltar para login'),
                ),
                const SizedBox(height: TurniSpacing.xl),
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
                Text(
                  'Informe seu e-mail e enviaremos um link para redefinir sua senha.',
                  style: TextStyle(fontSize: 14, color: textMuted),
                ),
                const SizedBox(height: TurniSpacing.xl),
                if (_sent)
                  _SuccessBanner(isDark: isDark)
                else
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          key: const Key('input-email'),
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'E-mail',
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty)
                              return 'Este campo é obrigatório.';
                            if (!v.contains('@')) return 'E-mail inválido.';
                            return null;
                          },
                        ),
                        const SizedBox(height: TurniSpacing.lg),
                        SizedBox(
                          height: 52,
                          child: FilledButton(
                            key: const Key('btn-submit-forgot'),
                            onPressed: _loading ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: accent,
                              shape: const StadiumBorder(),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Enviar link'),
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
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('banner-forgot-success'),
        padding: const EdgeInsets.all(TurniSpacing.md),
        decoration: BoxDecoration(
          color: TurniColors.successSoftLight,
          border: Border.all(color: TurniColors.successLight.withAlpha(128)),
          borderRadius: BorderRadius.all(TurniRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 18,
              color: TurniColors.successLight,
            ),
            const SizedBox(width: TurniSpacing.sm),
            const Expanded(
              child: Text(
                'Se este e-mail estiver cadastrado, você receberá um link em instantes.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
