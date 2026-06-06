// integration_test — STORY-064 (E2E browser real: ciclo completo do turno, CA-8)
// + STORY-065 (ciclo FINANCEIRO: captura + Pix — CA-4/CA-7).
//
// Same-origin (proxy + --web-launch-url, IDR-021) contra o BACKEND REAL, com o par
// exclusivo `*.checkout.seed` (turno `confirmado` dentro da janela de check-in).
// UM cenário percorre o ciclo inteiro `confirmado → finalizado → Pix enviado`,
// BILATERAL de verdade:
//
//   1. profissional gera o PIN de check-in (061) e o contratante valida (062) → `ativo`;
//   2. profissional gera o PIN de check-out (CA-1/CA-2 — sem janela, geo silenciosa) e
//      o cronômetro congela em "Aguardando validação — duração:" (CA-6);
//   3. contratante valida o check-out (CA-3) → `finalizado`: snackbar, badge,
//      "Turno finalizado — duração:" no cronômetro (CA-6) e trilha (CA-7);
//   4. (065) o worker captura e dispara o Pix via fake; o webhook confirma; o
//      PROFISSIONAL vê "Pix enviado em HH:MM" no card de valor (polling silencioso —
//      sem refresh manual) + "Pix enviado" na trilha com o valor integral.
//
// Pré-requisitos do passo 4: worker de filas e fake `pagarme-mock` de pé (make up),
// fake em modo sucesso com SLA 0 (defaults do compose). O perfil do profissional do
// seed carrega chave Pix (TurnosSeeder/PixFalhaSeeder garantem).
//
// O cenário CONSOME o turno (finalizado é terminal); o TurnosSeeder recria o par no
// próximo `_e2e-seed` (recriaConsumido — exclusivo do checkout.seed). A POSIÇÃO é
// injetada via `debugCapturarPosicaoOverride` (mesmo padrão da 061/062).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turni_webapp/features/turno/geolocalizacao.dart';

import '../helpers/login_helper.dart';
import '../helpers/pump_app.dart';
import '../helpers/route_helper.dart';

const _profissionalSeed = 'profissional.checkout.seed@turni.local';
const _contratanteSeed = 'contratante.checkout.seed@turni.local';
const _senha = 'password';

/// Card raiz de turno: `turno-card-{uuid}` (36 chars de uuid, sem sufixo).
final _cardDeTurno = find.byWidgetPredicate((w) {
  final k = w.key;
  return k is ValueKey<String> &&
      k.value.startsWith('turno-card-') &&
      k.value.length == 'turno-card-'.length + 36;
}, description: 'card raiz de turno');

Finder _cardComEstado(String estadoLabel) =>
    find.ancestor(of: find.text(estadoLabel), matching: _cardDeTurno).first;

/// Pumpa até [cond] (ou estoura [timeout]) — para condições de estado.
Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() cond, {
  Duration timeout = const Duration(seconds: 20),
  required String descricao,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!cond()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('condição não satisfeita em ${timeout.inSeconds}s: $descricao');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Loga o PROFISSIONAL e navega até a lista de turnos dele.
Future<void> _proAteOsTurnos(WidgetTester tester) async {
  await pumpApp(tester);
  assertOnRoute(tester, '/login');
  await loginAs(tester, email: _profissionalSeed, password: _senha);
  await awaitRouteChange(tester, '/');
  await tester.pumpAndSettle();
  await pumpUntilFound(tester, find.byKey(const Key('feed-screen')));

  await tester.tap(find.byKey(const Key('feed-meus-turnos-btn')));
  await tester.pumpAndSettle();
  await pumpUntilFound(tester, find.byKey(const Key('meus-turnos-screen')));
}

/// Loga o CONTRATANTE e navega até o detalhe do card com [estadoLabel].
Future<void> _contratanteAteODetalhe(
  WidgetTester tester,
  String estadoLabel,
) async {
  await pumpApp(tester);
  assertOnRoute(tester, '/login');
  await loginAs(tester, email: _contratanteSeed, password: _senha);
  await awaitRouteChange(tester, '/');
  await tester.pumpAndSettle();
  await pumpUntilFound(tester, find.byKey(const Key('minhas-vagas-screen')));

  await tester.tap(find.byKey(const Key('minhas-vagas-turnos-btn')));
  await awaitRouteChange(tester, '/contratante/turnos');
  await pumpUntilFound(
    tester,
    find.byKey(const Key('contratante-turnos-screen')),
  );

  await tester.tap(_cardComEstado(estadoLabel));
  await tester.pumpAndSettle();
  await pumpUntilFound(tester, find.byKey(const Key('turno-detalhe-screen')));
}

/// Digita [pin] no campo [inputKey] e toca em [btnKey]; retorna quando a resposta
/// foi processada (botão reabilitado ou área trocada) — padrão da 062.
Future<void> _validarCom(
  WidgetTester tester,
  String pin, {
  required Key inputKey,
  required Key btnKey,
}) async {
  final input = find.byKey(inputKey);
  final btn = find.byKey(btnKey);

  await tester.ensureVisible(input);
  await tester.enterText(input, pin);
  await tester.pump();

  await tester.ensureVisible(btn);
  await _pumpUntil(
    tester,
    () => tester.widget<FilledButton>(btn).enabled,
    descricao: 'botão Validar habilitado (4 dígitos, sem request em voo)',
  );
  await tester.tap(btn);
  await tester.pump(); // _validando=true é síncrono

  await _pumpUntil(
    tester,
    () => btn.evaluate().isEmpty || tester.widget<FilledButton>(btn).enabled,
    descricao: 'resposta da validação processada',
  );
}

void main() {
  tearDown(() => debugCapturarPosicaoOverride = null);

  testWidgets(
    'ciclo completo confirmado → finalizado (CA-8): check-in bilateral, cronômetro, '
    'check-out bilateral, duração final e trilha',
    (tester) async {
      debugCapturarPosicaoOverride = () async =>
          const PosicaoGeo(lat: -23.550135, lng: -46.63, accuracyM: 10);

      // ── 1a. PROFISSIONAL gera o PIN de check-in (061) ──
      await _proAteOsTurnos(tester);
      final confirmado = find
          .ancestor(of: find.text('Confirmado'), matching: _cardDeTurno)
          .evaluate()
          .isNotEmpty;
      await tester.tap(
        _cardComEstado(confirmado ? 'Confirmado' : 'Aguardando check-in'),
      );
      await tester.pumpAndSettle();
      await pumpUntilFound(
        tester,
        find.byKey(const Key('turno-detalhe-screen')),
      );

      final gerarCheckin = confirmado
          ? find.byKey(const Key('turno-pin-gerar-btn'))
          : find.byKey(const Key('turno-pin-regen-btn'));
      await pumpUntilFound(tester, gerarCheckin);
      await tester.ensureVisible(gerarCheckin);
      await tester.tap(gerarCheckin);
      await pumpUntilFound(
        tester,
        find.byKey(const Key('pin-checkin-screen')),
        timeout: const Duration(seconds: 20),
      );
      final pinCheckin = tester
          .widget<Text>(find.byKey(const Key('pin-checkin-codigo')))
          .data!;
      expect(pinCheckin, matches(RegExp(r'^\d{4}$')));
      await tester.tap(find.byKey(const Key('pin-checkin-voltar')).first);
      await tester.pumpAndSettle();

      // ── 1b. CONTRATANTE valida o check-in (062) → ativo ──
      await _contratanteAteODetalhe(tester, 'Aguardando check-in');
      await pumpUntilFound(
        tester,
        find.byKey(const Key('validar-checkin-area')),
      );
      await _validarCom(
        tester,
        pinCheckin,
        inputKey: const Key('validar-checkin-pin-input'),
        btnKey: const Key('validar-checkin-btn'),
      );
      await pumpUntilFound(
        tester,
        find.text('Check-in validado'),
        timeout: const Duration(seconds: 20),
      );
      await tester.pumpAndSettle();
      // Cronômetro vivo nos dois lados a partir daqui (063).
      await pumpUntilFound(tester, find.byKey(const Key('cronometro-card')));

      // ── 2. PROFISSIONAL gera o PIN de check-out (CA-1/CA-2) ──
      await _proAteOsTurnos(tester);
      await tester.tap(_cardComEstado('Em andamento'));
      await tester.pumpAndSettle();
      await pumpUntilFound(
        tester,
        find.byKey(const Key('turno-detalhe-screen')),
      );
      await pumpUntilFound(tester, find.byKey(const Key('cronometro-card')));

      final gerarCheckout = find.byKey(const Key('turno-checkout-gerar-btn'));
      await pumpUntilFound(tester, gerarCheckout);
      await tester.ensureVisible(gerarCheckout);
      await tester.tap(gerarCheckout);
      await pumpUntilFound(
        tester,
        find.byKey(const Key('pin-checkout-screen')),
        timeout: const Duration(seconds: 20),
      );

      // CA-2 — PIN em plaintext UMA vez, SEM nota de geofencing (silenciosa).
      final pinCheckout = tester
          .widget<Text>(find.byKey(const Key('pin-checkout-codigo')))
          .data!;
      expect(pinCheckout, matches(RegExp(r'^\d{4}$')));
      expect(find.byKey(const Key('pin-checkin-geo-nota')), findsNothing);

      await tester.tap(find.byKey(const Key('pin-checkout-voltar')).first);
      await tester.pumpAndSettle();

      // CA-6 — cronômetro congelado com a microcopy aprovada da 064.
      await pumpUntilFound(
        tester,
        find.byKey(const Key('cronometro-aguardando-checkout')),
        timeout: const Duration(seconds: 20),
      );
      expect(
        find.textContaining('Aguardando validação — duração:'),
        findsOneWidget,
      );

      // ── 3. CONTRATANTE valida o check-out (CA-3) → finalizado ──
      await _contratanteAteODetalhe(tester, 'Aguardando check-out');
      await pumpUntilFound(
        tester,
        find.byKey(const Key('validar-checkout-area')),
      );
      // SEM card de aviso de geofencing no check-out (diferença intencional da 062).
      expect(find.byKey(const Key('validar-checkin-geo-aviso')), findsNothing);

      await _validarCom(
        tester,
        pinCheckout,
        inputKey: const Key('validar-checkout-pin-input'),
        btnKey: const Key('validar-checkout-btn'),
      );

      await pumpUntilFound(
        tester,
        find.byKey(const Key('validar-checkout-sucesso')),
        timeout: const Duration(seconds: 20),
      );
      await pumpUntilFound(
        tester,
        find.text('Check-out validado'),
        timeout: const Duration(seconds: 20),
      );
      await tester.pumpAndSettle();

      // CA-3/CA-6/CA-7 — estado final: badge, cronômetro final e trilha.
      expect(
        find.descendant(
          of: find.byKey(const Key('turno-detalhe-estado')),
          matching: find.text('Finalizado'),
        ),
        findsOneWidget,
      );
      await pumpUntilFound(
        tester,
        find.byKey(const Key('cronometro-finalizado')),
      );
      expect(
        find.textContaining('Turno finalizado — duração:'),
        findsOneWidget,
      );
      expect(find.text('Turno finalizado.'), findsOneWidget);
      expect(find.byKey(const Key('validar-checkout-area')), findsNothing);

      // ── 4. (065 CA-4) PROFISSIONAL vê o Pix chegar — sem refresh manual ──
      // O worker processa captura + Pix contra o fake (SLA 0) e o webhook grava
      // `pix.enviado`; a linha do card troca via polling silencioso (10s/tick).
      await _proAteOsTurnos(tester);
      await tester.tap(_cardComEstado('Finalizado'));
      await tester.pumpAndSettle();
      await pumpUntilFound(
        tester,
        find.byKey(const Key('turno-detalhe-screen')),
      );

      // A linha de status existe desde o primeiro frame (a caminho OU já enviado —
      // o fake confirma rápido demais para fixar o intermediário aqui; o estado
      // "a caminho" determinístico é coberto nos widget tests da 065).
      await pumpUntilFound(
        tester,
        find.byKey(const Key('turno-detalhe-pix-status')),
      );

      // Flip para "Pix enviado em HH:MM" — espera generosa: job do worker (poll da
      // fila ~2s) + webhook do fake + tick do polling da tela (10s).
      await _pumpUntil(
        tester,
        () => find
            .byKey(const Key('turno-detalhe-pix-enviado'))
            .evaluate()
            .isNotEmpty,
        timeout: const Duration(seconds: 60),
        descricao: 'linha "Pix enviado em HH:MM" no card de valor (CA-4)',
      );
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(const Key('turno-detalhe-pix-enviado')),
                matching: find.byType(Text),
              ),
            )
            .data,
        matches(RegExp(r'^Pix enviado em \d{2}:\d{2}$')), // 24h (DDR-002)
      );

      // Trilha (timeline 060): "Pix enviado" + valor integral do profissional.
      await _pumpUntil(
        tester,
        () => find.text('Pix enviado').evaluate().isNotEmpty,
        timeout: const Duration(seconds: 15),
        descricao: 'evento "Pix enviado" na trilha',
      );
      expect(find.textContaining('enviados para você.'), findsOneWidget);
    },
  );
}
