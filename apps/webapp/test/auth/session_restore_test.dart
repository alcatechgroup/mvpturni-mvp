import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turni_webapp/features/auth/auth_service.dart';

// STORY-046 / IDR-025 — a sessão persistida é restaurada no boot (loadFromPrefs),
// para que reload/URL digitada/bookmark numa rota protegida não caiam em /login.

void main() {
  test('restaura a sessão persistida (boot frio)', () async {
    SharedPreferences.setMockInitialValues({
      'turni_session': jsonEncode({
        'id': 'user-123',
        'name': 'Contratante Teste',
        'role': 'contratante',
        'status': 'ativo',
        'welcome_visto': true,
        'cadastro_completo': true,
      }),
    });
    AuthService().debugSetSession(null);

    await AuthService().loadFromPrefs();

    expect(AuthService().session, isNotNull);
    expect(AuthService().session!.role, 'contratante');
    expect(AuthService().session!.funnelState, FunnelState.active);
    // STORY-088 — o id do usuário fica disponível p/ GET /api/perfil/{id}.
    expect(AuthService().session!.id, 'user-123');
  });

  test('storage vazio mantém sessão nula (cai em /login, correto)', () async {
    SharedPreferences.setMockInitialValues({});
    AuthService().debugSetSession(null);

    await AuthService().loadFromPrefs();

    expect(AuthService().session, isNull);
  });

  test('sessão corrompida é descartada sem quebrar o boot (borda)', () async {
    SharedPreferences.setMockInitialValues({'turni_session': 'não-é-json'});
    AuthService().debugSetSession(null);

    await AuthService().loadFromPrefs();

    expect(AuthService().session, isNull);
  });
}
