import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turni_webapp/features/app/shell/app_shell_view.dart';
import 'package:turni_webapp/features/app/shell/shell_chrome.dart';

// STORY-077 — testes de widget do shell adaptativo (apresentacional, sem router).
// CA-1 (forma por breakpoint), CA-2 (destinos por papel na nav), CA-4 (chrome por
// perfil), CA-5 (toque ≥48dp), CA-6 (a11y: label + semântica de selecionado).

/// Monta o [AppShellView] numa viewport de largura [width].
Future<void> _pumpAt(
  WidgetTester tester, {
  required double width,
  String role = 'profissional',
  int currentIndex = 0,
  ValueChanged<int>? onSelect,
  VoidCallback? onNovaVaga,
  VoidCallback? onLogout,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness, useMaterial3: true),
      home: AppShellView(
        role: role,
        currentIndex: currentIndex,
        onDestinationSelected: onSelect ?? (_) {},
        onNovaVaga: onNovaVaga ?? () {},
        onLogout: onLogout ?? () {},
        child: const Center(child: Text('conteúdo')),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('CA-1 — forma da navegação por breakpoint (DDR-001 §5.6)', () {
    testWidgets('(a) compact (<600) → NavigationBar inferior', (tester) async {
      await _pumpAt(tester, width: 400);
      expect(find.byKey(const Key('shell-nav-bar')), findsOneWidget);
      expect(find.byKey(const Key('shell-nav-rail')), findsNothing);
      expect(find.byKey(const Key('shell-nav-drawer')), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('(d) borda 599 ainda é compact; 600 vira rail', (tester) async {
      await _pumpAt(tester, width: 599);
      expect(find.byKey(const Key('shell-nav-bar')), findsOneWidget);
      await _pumpAt(tester, width: 600);
      expect(find.byKey(const Key('shell-nav-rail')), findsOneWidget);
    });

    testWidgets('(a) medium (600–839) → NavigationRail recolhida', (
      tester,
    ) async {
      await _pumpAt(tester, width: 700);
      expect(find.byKey(const Key('shell-nav-rail')), findsOneWidget);
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isFalse);
    });

    testWidgets('(a) expanded (840–1199) → NavigationRail estendida', (
      tester,
    ) async {
      await _pumpAt(tester, width: 1000);
      expect(find.byKey(const Key('shell-nav-rail')), findsOneWidget);
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isTrue);
    });

    testWidgets('(d) borda 1199 ainda é rail; 1200 vira drawer', (
      tester,
    ) async {
      await _pumpAt(tester, width: 1199);
      expect(find.byKey(const Key('shell-nav-rail')), findsOneWidget);
      expect(find.byKey(const Key('shell-nav-drawer')), findsNothing);
      await _pumpAt(tester, width: 1200);
      expect(find.byKey(const Key('shell-nav-drawer')), findsOneWidget);
      expect(find.byKey(const Key('shell-nav-rail')), findsNothing);
    });

    testWidgets('(a) large (≥1200) → sidebar persistente (drawer)', (
      tester,
    ) async {
      await _pumpAt(tester, width: 1300);
      expect(find.byKey(const Key('shell-nav-drawer')), findsOneWidget);
      // O conteúdo continua presente ao lado da sidebar.
      expect(find.text('conteúdo'), findsOneWidget);
    });
  });

  group('CA-2 — destinos do papel aparecem na navegação', () {
    testWidgets('(a) profissional vê Vagas/Turnos/Perfil na bottom bar', (
      tester,
    ) async {
      await _pumpAt(tester, width: 400, role: 'profissional');
      final bar = find.byKey(const Key('shell-nav-bar'));
      expect(
        find.descendant(of: bar, matching: find.text('Vagas')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bar, matching: find.text('Turnos')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bar, matching: find.text('Perfil')),
        findsOneWidget,
      );
    });

    testWidgets(
      '(b) papel desconhecido → sem destinos (fail-secure), sem crash',
      (tester) async {
        await _pumpAt(tester, width: 400, role: 'admin');
        // Sem destinos, não há NavigationBar (M3 exige ≥2); o shell não quebra e
        // ainda mostra o conteúdo.
        expect(find.text('conteúdo'), findsOneWidget);
        expect(find.byType(NavigationBar), findsNothing);
      },
    );

    testWidgets('(d) contratante vê "Nova vaga" no rail; profissional não', (
      tester,
    ) async {
      await _pumpAt(tester, width: 1000, role: 'contratante');
      expect(find.byKey(const Key('shell-fab-nova-vaga')), findsOneWidget);
      await _pumpAt(tester, width: 1000, role: 'profissional');
      expect(find.byKey(const Key('shell-fab-nova-vaga')), findsNothing);
    });
  });

  group(
    'CA-3 — estado ativo reflete o índice e navegação dispara callback',
    () {
      testWidgets(
        '(a) índice ativo destaca o destino e tap chama onDestinationSelected',
        (tester) async {
          var selected = -1;
          await _pumpAt(
            tester,
            width: 400,
            currentIndex: 0,
            onSelect: (i) => selected = i,
          );
          final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
          expect(bar.selectedIndex, 0);
          await tester.tap(find.text('Turnos'));
          await tester.pumpAndSettle();
          expect(selected, 1);
        },
      );
    },
  );

  group('CA-4 — chrome da navegação segue o perfil nos dois temas', () {
    testWidgets('(a) bottom bar profissional pintada no chrome verde-sage', (
      tester,
    ) async {
      await _pumpAt(tester, width: 400, role: 'profissional');
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.backgroundColor, ShellChrome.forRole('profissional').surface);
    });

    testWidgets(
      '(a) bottom bar contratante pintada no chrome mostarda — mesmo no escuro',
      (tester) async {
        await _pumpAt(
          tester,
          width: 400,
          role: 'contratante',
          brightness: Brightness.dark,
        );
        final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
        expect(bar.backgroundColor, ShellChrome.forRole('contratante').surface);
      },
    );

    testWidgets('(a) sidebar desktop pintada no chrome do perfil', (
      tester,
    ) async {
      await _pumpAt(tester, width: 1300, role: 'contratante');
      final drawer = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(const Key('shell-nav-drawer')),
              matching: find.byType(Container),
            )
            .first,
      );
      final deco = drawer.decoration as BoxDecoration?;
      final color = deco?.color ?? drawer.color;
      expect(color, ShellChrome.forRole('contratante').surface);
    });
  });

  group('CA-5/CA-6 — toque ≥48dp, label acessível e Sair', () {
    testWidgets('(d) bottom bar tem altura de toque ≥48dp', (tester) async {
      await _pumpAt(tester, width: 400);
      final size = tester.getSize(find.byType(NavigationBar));
      expect(size.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('(a) sidebar expõe Sair com semântica de botão (CA-6)', (
      tester,
    ) async {
      await _pumpAt(tester, width: 1300);
      expect(find.byKey(const Key('shell-logout')), findsOneWidget);
    });

    testWidgets(
      '(a) destinos têm rótulo textual visível (ícone + label, CA-6)',
      (tester) async {
        await _pumpAt(tester, width: 1300, role: 'profissional');
        final drawer = find.byKey(const Key('shell-nav-drawer'));
        expect(
          find.descendant(of: drawer, matching: find.text('Vagas')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: drawer, matching: find.text('Turnos')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: drawer, matching: find.text('Perfil')),
          findsOneWidget,
        );
      },
    );
  });

  group('sidebar desktop — identidade e marca', () {
    testWidgets(
      '(a) com nome, mostra o user pill (nome + iniciais) e a tag do papel',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(1300, 900);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: AppShellView(
              role: 'contratante',
              userName: 'Marina Souza',
              currentIndex: 0,
              onDestinationSelected: (_) {},
              onNovaVaga: () {},
              onLogout: () {},
              child: const SizedBox.shrink(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final drawer = find.byKey(const Key('shell-nav-drawer'));
        expect(
          find.descendant(of: drawer, matching: find.text('Marina Souza')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: drawer, matching: find.text('MS')),
          findsOneWidget,
        );
        // Tag do papel em caixa-alta.
        expect(
          find.descendant(of: drawer, matching: find.text('CONTRATANTE')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '(d) borda — sem nome, o user pill não aparece (sem linha vazia)',
      (tester) async {
        await _pumpAt(
          tester,
          width: 1300,
          role: 'profissional',
        ); // userName padrão ''
        final drawer = find.byKey(const Key('shell-nav-drawer'));
        // A tag do papel ainda aparece, mas não há pill de usuário.
        expect(
          find.descendant(of: drawer, matching: find.text('PROFISSIONAL')),
          findsOneWidget,
        );
        expect(find.byType(CircleAvatar), findsNothing);
      },
    );
  });

  group('regressão — SnackBar da tela interna não cobre a barra de ação', () {
    // Sob a Scaffold aninhada do shell, sem um ScaffoldMessenger próprio do
    // conteúdo, o SnackBar de uma tela interna sobe para o mensageiro RAIZ e
    // renderiza no rodapé da JANELA, cobrindo a `bottomNavigationBar` de ação da
    // tela (ex.: o "Retirar" do detalhe da vaga). Este teste fixa que o SnackBar
    // fica ACIMA da barra de ação interna (comportamento pré-shell preservado).
    testWidgets('(c) SnackBar renderiza acima da bottomNavigationBar interna', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1300, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Tela interna: Scaffold com barra de ação (botão "Retirar") embaixo e um
      // gatilho que dispara um SnackBar via o ScaffoldMessenger em escopo.
      final inner = Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              key: const Key('inner-toast-trigger'),
              onPressed: () => ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('feito'))),
              child: const Text('toast'),
            ),
          ),
        ),
        bottomNavigationBar: SizedBox(
          height: 72,
          child: Center(
            child: ElevatedButton(
              key: const Key('inner-acao-btn'),
              onPressed: () {},
              child: const Text('Retirar'),
            ),
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AppShellView(
            role: 'profissional',
            currentIndex: 0,
            onDestinationSelected: (_) {},
            onNovaVaga: () {},
            onLogout: () {},
            child: inner,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('inner-toast-trigger')));
      await tester.pump(); // dispara o SnackBar
      await tester.pump(const Duration(milliseconds: 400)); // entra na tela

      expect(find.byType(SnackBar), findsOneWidget);
      final snack = tester.getRect(find.byType(SnackBar));
      final acao = tester.getRect(find.byKey(const Key('inner-acao-btn')));
      // O SnackBar fica acima da barra de ação interna — não a cobre.
      expect(
        snack.bottom,
        lessThanOrEqualTo(acao.top + 1),
        reason:
            'SnackBar (bottom=${snack.bottom}) cobriu a barra de ação '
            '(top=${acao.top}) — mensageiro do conteúdo não escopou o toast',
      );
    });
  });
}
