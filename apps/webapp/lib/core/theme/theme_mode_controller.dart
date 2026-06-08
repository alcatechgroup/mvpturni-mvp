import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modo de tema do WebApp (DDR-001 D2: claro padrão + escuro via
/// `prefers-color-scheme`). A alternância manual vive no Perfil (DDR-003) e é
/// persistida — sobrepõe a preferência do sistema quando o usuário escolhe.
///
/// Singleton (como [AuthService]/`NotificacoesController`): o `MaterialApp` ouve
/// e o Perfil escreve.
class ThemeModeController extends ChangeNotifier {
  ThemeModeController._();
  static final ThemeModeController instance = ThemeModeController._();

  static const _key = 'turni_theme_mode';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  /// Relê o modo persistido. Valor inválido/ausente cai em `system`.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _setMode(_parse(prefs.getString(_key)));
  }

  /// Grava e notifica. `system` não fixa preferência manual (mantém o sistema).
  Future<void> setMode(ThemeMode mode) async {
    _setMode(mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  /// Atalho do switch "Tema escuro" do Perfil.
  Future<void> setDark(bool dark) =>
      setMode(dark ? ThemeMode.dark : ThemeMode.light);

  /// O tema está efetivamente escuro? Resolve `system` pela [platform].
  bool isDark(Brightness platform) =>
      _mode == ThemeMode.dark ||
      (_mode == ThemeMode.system && platform == Brightness.dark);

  void _setMode(ThemeMode mode) {
    if (_mode == mode) {
      notifyListeners();
      return;
    }
    _mode = mode;
    notifyListeners();
  }

  static ThemeMode _parse(String? raw) => switch (raw) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}
