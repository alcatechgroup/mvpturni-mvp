// integration_test — STORY-061 (E2E browser real: geração do PIN de check-in, CA-9).
//
// Same-origin (proxy + --web-launch-url, IDR-021) contra o BACKEND REAL, com o usuário
// exclusivo do turno PIN (`profissional.pin.seed` — turno `confirmado` DENTRO da janela,
// estabelecimento geolocalizado em SP centro). Os 3 caminhos de geolocalização (CA-2/CA-9):
//
//   1. concedida (no raio)  → PIN + "Localização confirmada — você está no local."
//   2. negada               → PIN + aviso "(permissão negada)" — PDR-008 nunca bloqueia
//   3. timeout              → PIN + aviso "(tempo esgotado)"
//
// A POSIÇÃO é injetada via `debugCapturarPosicaoOverride` (padrão debugSetSession): o
// browser do harness não tem como conceder a permissão de geolocalização programaticamente
// (prompt nativo do Chrome); a ponte JS real (`navigator.geolocation`) foi validada na PoC
// da STORY-057. Todo o resto é real: POST, hash bcrypt, Haversine, transição de estado,
// audit log e o cancelamento que devolve o turno a `confirmado` — o que também torna cada
// cenário IDEMPOTENTE (o turno termina como começou).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turni_webapp/features/turno/geolocalizacao.dart';

import '../helpers/login_helper.dart';
import '../helpers/pump_app.dart';
import '../helpers/route_helper.dart';

const _profissionalPinSeed = 'profissional.pin.seed@turni.local';
const _pinSeedPassword = 'password';

/// Card raiz de turno: `turno-card-{uuid}` (36 chars de uuid, sem sufixo).
final _cardDeTurno = find.byWidgetPredicate((w) {
  final k = w.key;
  return k is ValueKey<String> &&
      k.value.startsWith('turno-card-') &&
      k.value.length == 'turno-card-'.length + 36;
}, description: 'card raiz de turno');

/// Loga o profissional do turno PIN e navega lista → detalhe (única carta dele).
Future<void> _ateODetalhe(WidgetTester tester) async {
  await pumpApp(tester);
  assertOnRoute(tester, '/login');

  await loginAs(
    tester,
    email: _profissionalPinSeed,
    password: _pinSeedPassword,
  );
  await awaitRouteChange(tester, '/');
  await tester.pumpAndSettle();
  await pumpUntilFound(tester, find.byKey(const Key('feed-screen')));

  await goToTurnos(tester, profissional: true);
  await tester.pumpAndSettle();
  await pumpUntilFound(tester, find.byKey(const Key('meus-turnos-screen')));
  expect(_cardDeTurno, findsWidgets);

  await tester.tap(_cardDeTurno.first);
  await tester.pumpAndSettle();
  await pumpUntilFound(tester, find.byKey(const Key('turno-detalhe-screen')));
}

/// Gera o PIN com a posição injetada, valida a tela do PIN + nota e CANCELA
/// (volta a `confirmado` — restaura o estado para o próximo cenário).
Future<void> _geraValidaECancela(
  WidgetTester tester, {
  required PosicaoGeo posicao,
  required String notaEsperada,
}) async {
  debugCapturarPosicaoOverride = () async => posicao;

  // Janela aberta (seed): botão habilitado.
  await pumpUntilFound(tester, find.byKey(const Key('turno-pin-gerar-btn')));
  expect(find.text('Chegou ao local?'), findsOneWidget);

  await tester.tap(find.byKey(const Key('turno-pin-gerar-btn')));
  // Loading "um gesto só" + POST real → tela do PIN.
  await pumpUntilFound(
    tester,
    find.byKey(const Key('pin-checkin-screen')),
    timeout: const Duration(seconds: 20),
  );

  // PIN plaintext de 4 dígitos (CA-4/CA-5) + microcopy fixa + nota de geofencing.
  final codigo = tester.widget<Text>(
    find.byKey(const Key('pin-checkin-codigo')),
  );
  expect(codigo.data, matches(RegExp(r'^\d{4}$')));
  expect(codigo.style!.fontSize, greaterThanOrEqualTo(64));
  expect(
    find.text('Mostre este PIN ao contratante para validar a chegada'),
    findsOneWidget,
  );
  expect(find.textContaining(notaEsperada), findsOneWidget);

  // Cancelar (CA-5): volta ao detalhe; o reload mostra o turno `confirmado` de novo.
  await tester.tap(find.byKey(const Key('pin-checkin-cancelar-btn')));
  await pumpUntilFound(
    tester,
    find.byKey(const Key('turno-pin-gerar-btn')),
    timeout: const Duration(seconds: 20),
  );
  // Drena a animação de pop da rota (o botão do detalhe aparece ANTES de a tela do
  // PIN sair da árvore) e os microtasks de foco — sem isso o assert abaixo e o
  // teardown do teste ficam flaky (FocusManager disposed).
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('pin-checkin-screen')), findsNothing);
  expect(find.text('Chegou ao local?'), findsOneWidget);
}

void main() {
  tearDown(() => debugCapturarPosicaoOverride = null);

  testWidgets(
    'geo concedida (no raio): gerar → PIN + localização confirmada → cancelar (CA-2/4/5)',
    (tester) async {
      await _ateODetalhe(tester);
      await _geraValidaECancela(
        tester,
        // ~15m do estabelecimento do seed (-23.55, -46.63) — dentro do raio de 100m.
        posicao: const PosicaoGeo(lat: -23.550135, lng: -46.63, accuracyM: 10),
        notaEsperada: 'Localização confirmada — você está no local.',
      );

      // Timeline ganhou a trilha do ciclo (CA-7 visível na UI).
      expect(find.text('PIN de check-in gerado'), findsWidgets);
      expect(find.text('PIN de check-in cancelado'), findsWidgets);
    },
  );

  testWidgets(
    'geo negada: PIN gerado mesmo assim + aviso honesto (PDR-008 não bloqueia)',
    (tester) async {
      await _ateODetalhe(tester);
      await _geraValidaECancela(
        tester,
        posicao: const PosicaoGeo(razao: 'permissao_negada'),
        notaEsperada:
            'Sua localização não pôde ser confirmada (permissão negada).',
      );
    },
  );

  testWidgets('geo timeout: PIN gerado + aviso de tempo esgotado', (
    tester,
  ) async {
    await _ateODetalhe(tester);
    await _geraValidaECancela(
      tester,
      posicao: const PosicaoGeo(razao: 'timeout'),
      notaEsperada: 'Sua localização não pôde ser confirmada (tempo esgotado).',
    );
  });
}
