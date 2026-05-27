// Smoke test do WebApp (CA-10): garante que o aparato de teste do Flutter está
// plugado e que o placeholder da rota raiz renderiza. E2E em browser real entra
// em STORY-008.
import 'package:flutter_test/flutter_test.dart';
import 'package:turni_webapp/main.dart';

void main() {
  testWidgets('WebApp renderiza o placeholder do Turni', (WidgetTester tester) async {
    await tester.pumpWidget(const TurniApp());

    expect(find.text('Turni'), findsOneWidget);
  });
}
