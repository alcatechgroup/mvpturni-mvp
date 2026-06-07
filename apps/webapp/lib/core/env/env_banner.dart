import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../features/auth/auth_service.dart';

/// Ambiente de execução do WebApp (STORY-075 / PDR-017).
///
/// Injetado em build de release via `--dart-define=TURNI_ENV=homolog|production`
/// (release.yml deriva da tag: rc → homolog, final → production). Build local
/// sem dart-define cai em `local` → banner não aparece (CA-2). NÃO reusa o
/// APP_ENV do Laravel: em homolog os backends rodam com APP_ENV=production
/// (otimizações), então o nome dedicado evita a semântica conflitante.
const turniEnv = String.fromEnvironment('TURNI_ENV', defaultValue: 'local');

/// Injeta o banner "Ambiente de teste — pagamentos simulados" no topo de toda
/// tela autenticada quando o ambiente é homolog (STORY-075 / PDR-017).
///
/// Plugado uma única vez no `MaterialApp.builder`, como o UpdateBannerHost
/// (STORY-037). Diferenças deliberadas:
/// - EMPURRA o conteúdo (Column), não sobrepõe — persistente, sem cobrir AppBar;
/// - só com sessão ativa ([AuthService] é ChangeNotifier): pré-auth fica sem
///   banner (CA-4) sem duplicar a lista de rotas públicas do funnel guard;
/// - match exato de `homolog` — qualquer outro valor é fail-safe (não mostra).
class EnvBannerHost extends StatelessWidget {
  const EnvBannerHost({
    super.key,
    required this.auth,
    required this.child,
    this.ambiente = turniEnv,
  });

  final AuthService auth;
  final Widget child;

  /// Sobrescrevível em teste; default é o valor de build ([turniEnv]).
  final String ambiente;

  @override
  Widget build(BuildContext context) {
    if (ambiente != 'homolog') return child;

    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        if (!auth.isLoggedIn) return child;
        return Column(
          children: [
            const EnvBanner(),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}

/// Faixa de aviso persistente — não dispensável (CA-5, PDR-017 fixa).
/// Tokens DDR-001 §4, padrão preferido de feedback: fundo `warning.soft` +
/// texto neutro alto-contraste (≈14:1, AAA — CA-7) + ícone na cor `warning`.
class EnvBanner extends StatelessWidget {
  const EnvBanner({super.key});

  static const microcopy = 'Ambiente de teste — pagamentos simulados';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark
        ? TurniColors.warnSoftDark
        : TurniColors.warnSoftLight;
    final iconColor = isDark ? TurniColors.warnDark : TurniColors.warnLight;
    final textColor = isDark
        ? TurniColors.textStrongDark
        : TurniColors.textStrongLight;

    return Semantics(
      container: true,
      label: 'Aviso: $microcopy',
      // O texto interno é redundante para o leitor de tela; o label acima já
      // entrega a mensagem completa com o prefixo de aviso.
      excludeSemantics: true,
      child: Material(
        color: background,
        child: SafeArea(
          bottom: false,
          child: Container(
            key: const Key('env-banner'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: TurniSpacing.md,
              vertical: TurniSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: iconColor),
                const SizedBox(width: TurniSpacing.sm),
                Flexible(
                  child: Text(
                    microcopy,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
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
