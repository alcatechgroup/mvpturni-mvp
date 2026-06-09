// Guard estrutural (IDR — E2E binding): todo arquivo-FOLHA de `integration_test/`
// (em subpasta de feature, ex.: `integration_test/turnos/avaliar_turno_test.dart`)
// DEVE inicializar o binding chamando `IntegrationTestWidgetsFlutterBinding
// .ensureInitialized()` no seu `main()`.
//
// Por quê: rodar uma suíte isolada via `flutter drive`/`make e2e-webapp-pinned`
// (E2E_TARGET=integration_test/<feature>_test.dart) trava em "Timed out receiving
// message from renderer" se NENHUM leaf da suíte inicializa o binding — o app sobe,
// o Chrome conecta, mas nenhum teste roda. A suíte `turnos/` foi a única que nasceu
// sem isso (dependia de `web_test.dart` rodar `auth` antes), causando travas
// recorrentes. Este teste — que roda no `flutter test` (logo, no `make test` e no
// hook de pré-push) — impede que aconteça de novo em silêncio.
//
// Convenção verificada:
//   - LEAF  = `integration_test/<feature>/*_test.dart`  → precisa do ensureInitialized.
//   - ENTRYPOINT = `integration_test/*_test.dart` (nível raiz) → só encadeia `main()`s,
//     não é verificado aqui.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'todo leaf de integration_test/ inicializa o IntegrationTestWidgetsFlutterBinding',
    () {
      final raiz = Directory('integration_test');
      expect(
        raiz.existsSync(),
        isTrue,
        reason:
            'Esperava rodar a partir de apps/webapp/ (cwd do flutter test).',
      );

      final faltando = <String>[];
      for (final ent in raiz.listSync(recursive: true)) {
        if (ent is! File) continue;
        final caminho = ent.path.replaceAll(r'\', '/');
        if (!caminho.endsWith('_test.dart')) continue;

        // Só leaves (em subpasta de feature); entrypoints do nível raiz são encadeamento puro.
        final relativo = caminho.substring('integration_test/'.length);
        final ehLeaf = relativo.contains('/');
        if (!ehLeaf) continue;

        final fonte = ent.readAsStringSync();
        if (!fonte.contains(
          'IntegrationTestWidgetsFlutterBinding.ensureInitialized()',
        )) {
          faltando.add(relativo);
        }
      }

      expect(
        faltando,
        isEmpty,
        reason:
            'Estes leaves de integration_test/ NÃO chamam '
            'IntegrationTestWidgetsFlutterBinding.ensureInitialized() no main() — '
            'a suíte trava ("Timed out receiving message from renderer") ao rodar '
            'isolada. Adicione a chamada como 1ª linha do main():\n  - ${faltando.join('\n  - ')}',
      );
    },
  );
}
