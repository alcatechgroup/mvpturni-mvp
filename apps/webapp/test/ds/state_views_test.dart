import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turni_webapp/ds/components/state_views.dart';
import 'package:turni_webapp/ds/theme.dart';

// STORY-079 — cobertura dos três estados padronizados do DS.
// Cobre o exigido pela CA-6: lista vazia mostra o estado certo; erro mostra
// "tentar de novo" e o retry re-dispara; carregamento mostra skeleton.

Widget _host(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: brightness == Brightness.dark ? buildDarkTheme() : buildLightTheme(),
    home: Scaffold(body: child),
  );
}

void main() {
  group('TurniEmptyState', () {
    testWidgets('mostra ícone, título e mensagem do próximo passo', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const TurniEmptyState(
            key: Key('vazio-x'),
            icon: Icons.work_outline,
            title: 'Você ainda não publicou vagas',
            message: 'Publique uma vaga para começar.',
          ),
        ),
      );

      expect(find.byKey(const Key('vazio-x')), findsOneWidget);
      expect(find.text('Você ainda não publicou vagas'), findsOneWidget);
      expect(find.text('Publique uma vaga para começar.'), findsOneWidget);
      expect(find.byIcon(Icons.work_outline), findsOneWidget);
    });

    testWidgets('sem action não renderiza CTA; com action renderiza', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const TurniEmptyState(
            icon: Icons.search,
            title: 'Nada aqui',
            message: 'Volte depois.',
          ),
        ),
      );
      expect(find.byType(FilledButton), findsNothing);

      await tester.pumpWidget(
        _host(
          TurniEmptyState(
            icon: Icons.search,
            title: 'Nada aqui',
            message: 'Volte depois.',
            action: FilledButton(
              key: const Key('cta-x'),
              onPressed: () {},
              child: const Text('Fazer algo'),
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('cta-x')), findsOneWidget);
    });
  });

  group('TurniRetryState', () {
    testWidgets('erro não é só cor: tem ícone + texto', (tester) async {
      await tester.pumpWidget(
        _host(
          TurniRetryState(
            key: const Key('erro-x'),
            title: 'Não foi possível carregar as vagas.',
            onRetry: () {},
          ),
        ),
      );

      expect(find.byKey(const Key('erro-x')), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Não foi possível carregar as vagas.'), findsOneWidget);
      expect(find.text('Verifique sua conexão.'), findsOneWidget);
      expect(find.text('Tentar de novo'), findsOneWidget);
    });

    testWidgets('"Tentar de novo" re-dispara onRetry', (tester) async {
      var tentativas = 0;
      await tester.pumpWidget(
        _host(
          TurniRetryState(
            title: 'Não foi possível carregar.',
            retryKey: const Key('retry-x'),
            onRetry: () => tentativas++,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('retry-x')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('retry-x')));
      await tester.pump();

      expect(tentativas, 2);
    });

    testWidgets('alvo de toque do retry ≥48dp', (tester) async {
      await tester.pumpWidget(
        _host(
          TurniRetryState(
            title: 'Erro',
            retryKey: const Key('retry-x'),
            onRetry: () {},
          ),
        ),
      );
      final size = tester.getSize(find.byKey(const Key('retry-x')));
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });

  group('skeleton', () {
    testWidgets('TurniSkeletonList rende N cards e não anuncia', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const TurniSkeletonList(key: Key('skeleton-x'), count: 3)),
      );

      expect(find.byKey(const Key('skeleton-x')), findsOneWidget);
      expect(find.byType(TurniSkeletonCard), findsNWidgets(3));
      expect(find.byType(ExcludeSemantics), findsWidgets);
    });

    testWidgets('itemBuilder custom (linha com avatar) é usado', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          TurniSkeletonList(
            count: 2,
            itemBuilder: (_) => const Row(
              children: [
                TurniSkeletonBox(width: 40, circle: true),
                SizedBox(width: 8),
                Expanded(child: TurniSkeletonBox(width: double.infinity)),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(TurniSkeletonCard), findsNothing);
      expect(find.byType(TurniSkeletonBox), findsNWidgets(4));
    });

    testWidgets('TurniSkeletonBox circle usa width como diâmetro', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const TurniSkeletonBox(width: 40, circle: true)),
      );
      final size = tester.getSize(find.byType(TurniSkeletonBox));
      expect(size.width, 40);
      expect(size.height, 40);
    });
  });

  testWidgets('rende no tema escuro sem estourar', (tester) async {
    await tester.pumpWidget(
      _host(
        const TurniEmptyState(
          icon: Icons.search,
          title: 'Nada',
          message: 'Volte depois.',
        ),
        brightness: Brightness.dark,
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
