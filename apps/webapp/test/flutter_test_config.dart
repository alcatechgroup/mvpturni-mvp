import 'dart:async';

import 'package:turni_webapp/ds/typography.dart';

// Carregado automaticamente pelo `flutter test` para TODA a suíte (convenção do
// flutter_test). STORY-080: liga o seam de tipografia para usar a fonte padrão em
// vez de Google Fonts. Sem isto, `dsTextTheme`/`dsMono` (DS) tentam baixar o .ttf
// de fonts.gstatic.com em runtime — e o gate de a11y (`textContrastGuideline`)
// rasteriza o texto dentro de `runAsync`, forçando esse fetch a estourar quando não
// há rede (CI, sandbox). A família da fonte não afeta o contraste WCAG (cor+tamanho),
// então a suíte inteira passa a rodar offline e determinística. Ver lib/ds/typography.dart.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  useSystemFontsForTests = true;
  await testMain();
}
