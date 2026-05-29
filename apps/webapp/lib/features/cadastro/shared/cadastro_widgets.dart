import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ds/tokens.dart';
import 'cadastro_types.dart';

/// Widgets compartilhados dos pré-cadastros públicos (profissional — STORY-017,
/// contratante — STORY-018). IDR-012. Cada widget é parametrizado pelo `accent` do
/// perfil (verde no profissional, mostarda no contratante — DDR-001 / tokens.md §6),
/// e preserva os identificadores lógicos (`Key`) das specs (SCREEN-017/018 §A.8) para
/// que os widget tests e o E2E ancorem sem fragilidade.

/// Título de seção (rótulo visual de agrupamento — não é campo).
class CadastroSection extends StatelessWidget {
  const CadastroSection(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: TurniSpacing.lg, bottom: TurniSpacing.sm),
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
}

/// Linha de erro associada a um campo não-`TextFormField` (tipo/foto/termos).
class CadastroErrorText extends StatelessWidget {
  const CadastroErrorText(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).brightness == Brightness.dark
        ? TurniColors.errorDark
        : TurniColors.errorLight;
    return Padding(
      padding: const EdgeInsets.only(top: TurniSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 16, color: error),
          const SizedBox(width: TurniSpacing.xs),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Campo de texto padrão. O wrapper é keyed (`$fieldKey-field`) porque inserções
/// condicionais de erros reordenam os filhos do Column; sem isso o FormFieldState
/// seria recriado e perderia o errorText recém-validado.
class CadastroTextField extends StatelessWidget {
  // A key vai no widget (filho direto do Column) para que o elemento seja casado por
  // key — e não por posição — quando erros condicionais (tipo/foto/termos) são inseridos
  // acima e reordenam os irmãos. Sem isso o FormFieldState seria recriado e perderia o
  // errorText recém-validado.
  CadastroTextField({
    Key? key,
    required this.fieldKey,
    required this.controller,
    required this.label,
    this.hint,
    this.helper,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
  }) : super(key: key ?? ValueKey('$fieldKey-field'));

  final String fieldKey;
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? helper;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: TurniSpacing.md),
    child: TextFormField(
      key: Key(fieldKey),
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

/// Campo de senha com toggle mostrar/ocultar. Toggle: `Key('$fieldKey-toggle')`.
class CadastroPasswordField extends StatelessWidget {
  CadastroPasswordField({
    Key? key,
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
    this.helper,
    this.validator,
  }) : super(key: key ?? ValueKey('$fieldKey-field'));

  final String fieldKey;
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  final String? helper;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: TurniSpacing.md),
    child: TextFormField(
      key: Key(fieldKey),
      controller: controller,
      obscureText: obscure,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        helperMaxLines: 2,
        errorMaxLines: 3,
        suffixIcon: IconButton(
          key: Key('$fieldKey-toggle'),
          tooltip: obscure ? 'Mostrar senha' : 'Ocultar senha',
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
          onPressed: onToggle,
        ),
      ),
      validator: validator,
    ),
  );
}

/// Select genérico (`DropdownButtonFormField<T>`). Profissional usa `<int>` (função);
/// contratante usa `<String>` (tipo de operação). Wrapper keyed `$fieldKey-field`.
class CadastroDropdownField<T> extends StatelessWidget {
  CadastroDropdownField({
    Key? key,
    required this.fieldKey,
    required this.label,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
  }) : super(key: key ?? ValueKey('$fieldKey-field'));

  final String fieldKey;
  final String label;
  final String hint;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? Function(T?)? validator;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: TurniSpacing.md),
    child: DropdownButtonFormField<T>(
      key: Key(fieldKey),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, hintText: hint),
      items: items,
      onChanged: onChanged,
      validator: validator,
    ),
  );
}

/// Área de upload de foto do perfil/avatar. Key `input-foto` (vazio) / `btn-trocar-foto`.
class CadastroPhotoField extends StatelessWidget {
  const CadastroPhotoField({
    super.key,
    required this.foto,
    required this.error,
    required this.onPick,
    required this.accent,
    required this.isDark,
  });

  final FotoUpload? foto;
  final String? error;
  final VoidCallback onPick;
  final Color accent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final border = isDark
        ? TurniColors.borderSubtleDark
        : TurniColors.borderStrongLight;

    if (foto != null) {
      return Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: accent,
            child: Icon(
              Icons.check,
              color: isDark ? TurniColors.onAccentDark : TurniColors.onAccentLight,
            ),
          ),
          const SizedBox(width: TurniSpacing.md),
          TextButton(
            key: const Key('btn-trocar-foto'),
            onPressed: onPick,
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
          onTap: onPick,
          excludeSemantics: true,
          child: InkWell(
            key: const Key('input-foto'),
            onTap: onPick,
            borderRadius: const BorderRadius.all(TurniRadius.lg),
            child: Container(
              padding: const EdgeInsets.all(TurniSpacing.md),
              decoration: BoxDecoration(
                border: Border.all(
                  color: error != null
                      ? (isDark ? TurniColors.errorDark : TurniColors.errorLight)
                      : border,
                  width: 2,
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
        if (error != null) CadastroErrorText(error!),
      ],
    );
  }
}

/// Checkbox de aceite dos Termos + links (Key `check-termos`, `link-termos`,
/// `link-privacidade`). Os links são placeholders no MVP (SCREEN §A.9).
class CadastroTermsCheckbox extends StatelessWidget {
  const CadastroTermsCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.accent,
    required this.isDark,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Color accent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textColor = isDark
        ? TurniColors.textStrongDark
        : TurniColors.textStrongLight;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          key: const Key('check-termos'),
          value: value,
          activeColor: accent,
          onChanged: (v) => onChanged(v ?? false),
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
}

/// Vista B — Recebido (sucesso pós-submit). Key `panel-cadastro-recebido` /
/// `btn-voltar-home`. Texto e accent parametrizados por perfil.
class CadastroSuccessView extends StatelessWidget {
  const CadastroSuccessView({
    super.key,
    required this.accent,
    this.title = 'Cadastro recebido.',
    this.body =
        'Em até 24h a equipe Turni revisa seu cadastro e envia uma notificação por e-mail.',
    this.ctaLabel = 'Voltar à home',
  });

  final Color accent;
  final String title;
  final String body;
  final String ctaLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? TurniColors.textMutedDark : TurniColors.textMutedLight;
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
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: TurniSpacing.sm),
          Text(
            body,
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
                backgroundColor: accent,
                shape: const StadiumBorder(),
              ),
              child: Text(
                ctaLabel,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Banner de estado (erro genérico / throttle / servidor)
// ──────────────────────────────────────────────────────────────

enum CadastroBannerKind { generic, throttle, server }

class CadastroBanner {
  final CadastroBannerKind kind;
  final String message;
  const CadastroBanner._(this.kind, this.message);

  factory CadastroBanner.generic(String message) =>
      CadastroBanner._(CadastroBannerKind.generic, message);
  factory CadastroBanner.throttle() => const CadastroBanner._(
    CadastroBannerKind.throttle,
    'Muitas tentativas. Aguarde alguns minutos antes de tentar novamente.',
  );
  factory CadastroBanner.server() => const CadastroBanner._(
    CadastroBannerKind.server,
    'Não conseguimos enviar agora.',
  );
}

class CadastroBannerWidget extends StatelessWidget {
  const CadastroBannerWidget({
    super.key,
    required this.banner,
    required this.isDark,
    required this.onLogin,
    required this.onRetry,
  });

  final CadastroBanner banner;
  final bool isDark;
  final VoidCallback onLogin;
  final VoidCallback onRetry;

  Key get _key => switch (banner.kind) {
    CadastroBannerKind.generic => const Key('banner-cadastro-erro'),
    CadastroBannerKind.throttle => const Key('banner-throttle'),
    CadastroBannerKind.server => const Key('banner-servidor'),
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
            if (banner.kind == CadastroBannerKind.generic)
              TextButton(
                onPressed: onLogin,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 36),
                ),
                child: const Text('Já tem conta? Entrar'),
              ),
            if (banner.kind == CadastroBannerKind.server)
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
