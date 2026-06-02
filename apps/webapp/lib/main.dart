import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'core/app_update/app_update.dart';
import 'core/app_update/widgets/update_banner.dart';
import 'core/install/install.dart';
import 'ds/theme.dart';
import 'features/auth/auth_service.dart';
import 'router.dart';

// WebApp do Turni — Flutter Web (ADR-001).
// Design System: DDR-001. Roteamento: go_router. Tema: dual-theme (DDR-001 D2).
Future<void> main() async {
  // Necessário antes de usar plugins (SharedPreferences) num main() assíncrono.
  WidgetsFlutterBinding.ensureInitialized();
  // URL por path (/login, /welcome) em vez de hash (/#/login) — deep links e o
  // funnel guard (STORY-016) dependem de rotas reais. O servidor faz fallback SPA.
  usePathUrlStrategy();
  // Restaura a sessão persistida ANTES do primeiro roteamento (STORY-046 / IDR-025).
  // Sem isto, todo reload/URL digitada/bookmark começa com sessão nula e o funnel
  // guard manda qualquer rota protegida para /login — mesmo com o cookie Sanctum
  // ainda válido no browser. O login já grava a sessão; aqui o boot a relê.
  await AuthService().loadFromPrefs();
  // Auto-atualização do WebApp (STORY-037 / IDR-017): inicia polling + triggers.
  // No-op em dev (sem --dart-define=APP_VERSION).
  appUpdate.start();
  // Ação "Instalar app" (STORY-042 / IDR-020): escuta beforeinstallprompt/standalone
  // do script pré-Flutter. Funciona em qualquer build (independe de versão).
  installController.start();
  runApp(const TurniApp());
}

class TurniApp extends StatelessWidget {
  const TurniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Turni',
      debugShowCheckedModeBanner: false,
      // Dual-theme: claro padrão + escuro via prefers-color-scheme (DDR-001 D2, PDR-013).
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.system,
      routerConfig: router,
      // Banner "Nova versão disponível" no topo de qualquer rota (STORY-037 CA-4).
      builder: (context, child) => UpdateBannerHost(
        controller: appUpdate,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
