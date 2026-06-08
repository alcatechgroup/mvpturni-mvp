import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turni_webapp/core/theme/theme_mode_controller.dart';

// STORY-077 — alternância de tema consolidada no Perfil (DDR-003). O modo é
// persistido (SharedPreferences) e resolve `system` pela plataforma.

void main() {
  final c = ThemeModeController.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await c.setMode(ThemeMode.system);
  });

  test('(a) feliz — padrão é system; setDark(true) vira dark e persiste', () async {
    await c.load();
    expect(c.mode, ThemeMode.system);

    await c.setDark(true);
    expect(c.mode, ThemeMode.dark);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('turni_theme_mode'), 'dark');
  });

  test('(a) feliz — setDark(false) vira light e persiste', () async {
    await c.setDark(false);
    expect(c.mode, ThemeMode.light);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('turni_theme_mode'), 'light');
  });

  test('(c) exceção — valor persistido inválido cai em system (sem crash)', () async {
    SharedPreferences.setMockInitialValues({'turni_theme_mode': 'arco-iris'});
    await c.load();
    expect(c.mode, ThemeMode.system);
  });

  test('(d) borda — isDark resolve system pela plataforma', () async {
    await c.setMode(ThemeMode.system);
    expect(c.isDark(Brightness.dark), isTrue);
    expect(c.isDark(Brightness.light), isFalse);

    await c.setMode(ThemeMode.dark);
    expect(c.isDark(Brightness.light), isTrue); // modo explícito ignora a plataforma

    await c.setMode(ThemeMode.light);
    expect(c.isDark(Brightness.dark), isFalse);
  });

  test('(d) borda — notifica ouvintes ao trocar o modo', () async {
    var notified = 0;
    void listener() => notified++;
    c.addListener(listener);
    addTearDown(() => c.removeListener(listener));
    await c.setDark(true);
    expect(notified, greaterThanOrEqualTo(1));
  });
}
