// STORY-023 — tela de completar cadastro do profissional (SCREEN-STORY-023).
// Cobre: contexto CPF/CNPJ, navegação dos 3 passos, validação, preview, gating do
// aceite (CA-8), submit feliz (CA-12), erro de documento duplicado, seletor de funções.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:turni_webapp/features/auth/auth_service.dart';
import 'package:turni_webapp/features/cadastro/cadastro_service.dart';
import 'package:turni_webapp/features/cadastro/completar_cadastro_service.dart';
import 'package:turni_webapp/features/funnel/completar_cadastro_screen.dart';

class _FakeService extends CompletarCadastroService {
  _FakeService({
    this.tipo = 'CPF',
    PreviewResult? preview,
    CompletarResult? completar,
  }) : _preview = preview ?? PreviewSuccess('Contrato de adesão. Termos.'),
       _completar = completar ?? CompletarSuccess();

  final String tipo;
  final PreviewResult _preview;
  final CompletarResult _completar;

  @override
  Future<String> fetchDocumentoTipo() async => tipo;

  @override
  Future<PreviewResult> preview(CompletarCadastroDados dados) async => _preview;

  @override
  Future<CompletarResult> completar(
    CompletarCadastroDados dados,
    FotoUpload documento,
  ) async => _completar;
}

class _FakeFuncoes extends CadastroService {
  @override
  Future<List<Funcao>> fetchFuncoes() async => const [
    Funcao(id: 1, nome: 'Garçom'),
    Funcao(id: 2, nome: 'Bartender'),
  ];
}

Future<FotoUpload?> _fakePicker() async =>
    FotoUpload(bytes: Uint8List.fromList([1, 2, 3]), filename: 'rg.jpg');

/// Garante o widget visível (o form rola) antes de tocar.
Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

Widget _app(CompletarCadastroService service) {
  final router = GoRouter(
    initialLocation: '/completar-cadastro',
    routes: [
      GoRoute(
        path: '/completar-cadastro',
        builder: (c, s) => CompletarCadastroScreen(
          service: service,
          funcoesService: _FakeFuncoes(),
          documentPicker: _fakePicker,
        ),
      ),
      GoRoute(
        path: '/',
        builder: (c, s) => const Scaffold(body: Text('home')),
      ),
      GoRoute(
        path: '/login',
        builder: (c, s) => const Scaffold(body: Text('login')),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

/// Preenche os 3 passos e chega ao preview.
Future<void> _ateOPreview(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('input-documento')),
    '52998224725',
  );
  await _tap(tester, const Key('btn-continuar'));

  await tester.enterText(find.byKey(const Key('input-raio')), '30');
  await tester.enterText(find.byKey(const Key('input-preco-hora')), '45');
  await _tap(tester, const Key('btn-continuar'));

  await tester.enterText(
    find.byKey(const Key('input-chave-pix')),
    'diego@pix.com',
  );
  await _tap(tester, const Key('field-documento-upload'));
  await _tap(tester, const Key('btn-continuar'));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService().debugSetSession(
      const UserSession(
        name: 'Diego',
        role: 'profissional',
        status: 'liberado',
        welcomeVisto: true,
        cadastroCompleto: false,
      ),
    );
  });

  tearDown(() => AuthService().debugSetSession(null));

  testWidgets('monta a tela e mostra o campo de CPF para PF', (tester) async {
    await tester.pumpWidget(_app(_FakeService(tipo: 'CPF')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('screen-completar-cadastro')), findsOneWidget);
    expect(find.text('CPF'), findsWidgets);
  });

  testWidgets('mostra CNPJ quando o perfil é MEI/PJ', (tester) async {
    await tester.pumpWidget(_app(_FakeService(tipo: 'CNPJ')));
    await tester.pumpAndSettle();

    expect(find.text('CNPJ'), findsWidgets);
  });

  testWidgets('CPF vazio bloqueia o avanço do passo 1', (tester) async {
    await tester.pumpWidget(_app(_FakeService()));
    await tester.pumpAndSettle();

    await _tap(tester, const Key('btn-continuar'));

    // continua no passo 1 — campo de chave Pix (passo 3) não está visível ainda
    expect(find.text('Informe seu CPF.'), findsOneWidget);
  });

  testWidgets('fluxo feliz: 3 passos → preview → aceite → conclusão', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_FakeService()));
    await tester.pumpAndSettle();

    await _ateOPreview(tester);

    // preview exibido
    expect(find.byKey(const Key('contract-preview-body')), findsOneWidget);

    // CA-8 — CTA desabilitado antes do checkbox
    final ctaAntes = tester.widget<FilledButton>(
      find.byKey(const Key('btn-aceito-concluir')),
    );
    expect(ctaAntes.onPressed, isNull);

    // contrato curto coube sem rolar → checkbox habilitado; marca o aceite
    await _tap(tester, const Key('check-aceite'));

    final ctaDepois = tester.widget<FilledButton>(
      find.byKey(const Key('btn-aceito-concluir')),
    );
    expect(ctaDepois.onPressed, isNotNull);

    await _tap(tester, const Key('btn-aceito-concluir'));

    // CA-12 — tela de conclusão
    expect(find.byKey(const Key('screen-cadastro-concluido')), findsOneWidget);
  });

  testWidgets('documento duplicado mostra banner de erro', (tester) async {
    await tester.pumpWidget(
      _app(
        _FakeService(
          completar: CompletarGenericError(
            'Não foi possível concluir o cadastro. Verifique os dados e tente novamente.',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _ateOPreview(tester);
    await _tap(tester, const Key('check-aceite'));
    await _tap(tester, const Key('btn-aceito-concluir'));

    expect(find.byKey(const Key('banner-cadastro-erro')), findsOneWidget);
    expect(find.byKey(const Key('screen-cadastro-concluido')), findsNothing);
  });

  testWidgets(
    'seletor de funções: bottom sheet com busca seleciona e vira chip',
    (tester) async {
      await tester.pumpWidget(_app(_FakeService()));
      await tester.pumpAndSettle();

      // passo 1 → 2
      await tester.enterText(
        find.byKey(const Key('input-documento')),
        '52998224725',
      );
      await _tap(tester, const Key('btn-continuar'));

      await _tap(tester, const Key('btn-add-funcoes'));

      expect(find.byKey(const Key('input-busca-funcoes')), findsOneWidget);
      await _tap(tester, const Key('func-opt-1'));
      await _tap(tester, const Key('btn-concluir-funcoes'));

      expect(
        find.byKey(const Key('chips-funcoes-secundarias')),
        findsOneWidget,
      );
    },
  );
}
