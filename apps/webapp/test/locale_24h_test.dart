import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turni_webapp/features/auth/auth_service.dart';
import 'package:turni_webapp/main.dart';

// DDR-002 — o app inteiro usa pt-BR e horário 24h (sem AM/PM). Garante que o
// MediaQuery resolvido sob o app força alwaysUse24HourFormat=true (o que faz o
// showTimePicker e formatações sensíveis ao MediaQuery saírem em 24h).

void main() {
  testWidgets('força horário 24h em todo o app (DDR-002)', (tester) async {
    AuthService().debugSetSession(
      null,
    ); // sem sessão → cai em /login (tem Scaffold)
    await tester.pumpWidget(const TurniApp());
    await tester.pumpAndSettle();

    final ctx = tester.element(find.byType(Scaffold).first);
    expect(MediaQuery.of(ctx).alwaysUse24HourFormat, isTrue);
  });

  testWidgets('locale do app é pt-BR (DDR-002)', (tester) async {
    AuthService().debugSetSession(null);
    await tester.pumpWidget(const TurniApp());
    await tester.pumpAndSettle();

    final ctx = tester.element(find.byType(Scaffold).first);
    expect(Localizations.localeOf(ctx), const Locale('pt', 'BR'));
  });
}
