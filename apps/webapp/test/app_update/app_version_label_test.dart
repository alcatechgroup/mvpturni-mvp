import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turni_webapp/core/app_update/app_version.dart';
import 'package:turni_webapp/ds/components/app_version_label.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('mostra "Turni · <tag>" para release', (tester) async {
    await tester.pumpWidget(
      host(const AppVersionLabel(version: AppVersion('v0.1.0-rc.24'))),
    );
    expect(find.text('Turni · v0.1.0-rc.24'), findsOneWidget);
  });

  testWidgets('mostra "Turni · dev" em build local', (tester) async {
    await tester.pumpWidget(
      host(const AppVersionLabel(version: AppVersion('dev'))),
    );
    expect(find.text('Turni · dev'), findsOneWidget);
  });

  testWidgets('sem version injetada usa o default "dev" (CA-12)', (
    tester,
  ) async {
    // A suíte roda sem --dart-define=APP_VERSION → AppVersion.current() == dev.
    await tester.pumpWidget(host(const AppVersionLabel()));
    expect(find.text('Turni · dev'), findsOneWidget);
  });

  testWidgets('é discreto: body-xs (12) e textMuted', (tester) async {
    await tester.pumpWidget(
      host(const AppVersionLabel(version: AppVersion('v1.2.3'))),
    );
    final text = tester.widget<Text>(find.text('Turni · v1.2.3'));
    expect(text.style?.fontSize, 12);
    expect(text.textAlign, TextAlign.center);
  });
}
