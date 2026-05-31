import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'core/app_update/app_update.dart';
import 'core/app_update/widgets/update_banner.dart';
import 'ds/theme.dart';
import 'router.dart';

// WebApp do Turni — Flutter Web (ADR-001).
// Design System: DDR-001. Roteamento: go_router. Tema: dual-theme (DDR-001 D2).
void main() {
  // URL por path (/login, /welcome) em vez de hash (/#/login) — deep links e o
  // funnel guard (STORY-016) dependem de rotas reais. O servidor faz fallback SPA.
  usePathUrlStrategy();
  // Auto-atualização do WebApp (STORY-037 / IDR-017): inicia polling + triggers.
  // No-op em dev (sem --dart-define=APP_VERSION).
  appUpdate.start();
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
