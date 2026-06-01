import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turni_webapp/ds/theme.dart';
import 'package:turni_webapp/features/auth/auth_service.dart';
import 'package:turni_webapp/features/cadastro/cadastro_service.dart';
import 'package:turni_webapp/features/cadastro/completar_cadastro_screen.dart';
import 'package:turni_webapp/features/cadastro/completar_cadastro_service.dart';

// STORY-023 — widget tests do completar cadastro do profissional (CA-1/2/7/8/12).

class _FakeCatalogo extends CadastroService {
  @override
  Future<List<Funcao>> fetchFuncoes() async => const [
    Funcao(id: 1, nome: 'Garçom / Garçonete'),
    Funcao(id: 2, nome: 'Bartender'),
  ];
}

class _FakeService extends CompletarCadastroService {
  _FakeService({this.previewResult, this.completarResult});

  final PreviewResult Function()? previewResult;
  final CadastroResult Function()? completarResult;
  int completarCalls = 0;

  @override
  Future<CompletarContexto?> fetchContexto() async => const CompletarContexto(
    nome: 'Maria Silva',
    tipoPessoa: 'PF',
    documentoTipo: 'CPF',
    funcaoId: 1,
  );

  @override
  Future<PreviewResult> preview(String documento) async =>
      previewResult?.call() ??
      PreviewSuccess(
        '# Contrato\n\n## Seção 1 — Termos gerais\n'
        'Nome: **Maria Silva**\nCPF: 111.444.777-35\n\n'
        '## Assinatura eletrônica\n— preenchido no momento do aceite —',
      );

  @override
  Future<CadastroResult> completar({
    required String documento,
    required List<int> funcoesSecundarias,
    required int raioMaxKm,
    required String precoHora,
    required String bio,
    required String chavePix,
    required List<ArquivoUpload> documentos,
  }) async {
    completarCalls++;
    return completarResult?.call() ?? CadastroSuccess('Cadastro concluído!');
  }
}

Future<List<ArquivoUpload>?> _fakeDocs() async => [
  ArquivoUpload(bytes: Uint8List.fromList([1, 2, 3]), filename: 'rg.jpg'),
];

UserSession _liberadoSession() => const UserSession(
  name: 'Maria Silva',
  role: 'profissional',
  status: 'liberado',
  welcomeVisto: true,
  cadastroCompleto: false,
);

Future<void> _pump(
  WidgetTester tester, {
  _FakeService? service,
  Future<List<ArquivoUpload>?> Function()? docs,
}) async {
  await tester.binding.setSurfaceSize(const Size(480, 4000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: buildLightTheme(),
      home: CompletarCadastroScreen(
        service: service ?? _FakeService(),
        catalogo: _FakeCatalogo(),
        documentPicker: docs ?? _fakeDocs,
        auth: AuthService()..debugSetSession(_liberadoSession()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _preencher(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('input-documento')),
    '111.444.777-35',
  );
  await tester.enterText(find.byKey(const Key('input-raio')), '15');
  await tester.enterText(find.byKey(const Key('input-preco')), '45');
  await tester.enterText(
    find.byKey(const Key('input-pix')),
    'maria@exemplo.com',
  );
  await tester.tap(find.byKey(const Key('btn-anexar-documentos')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'CA-1: renderiza a tela com rótulo de documento conforme tipo_pessoa (PF→CPF)',
    (tester) async {
      await _pump(tester);
      expect(
        find.byKey(const Key('screen-completar-cadastro')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('input-documento')), findsOneWidget);
      expect(find.text('SEU DOCUMENTO (CPF)'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'CPF'), findsOneWidget);
    },
  );

  testWidgets('CA-2: formulário vazio bloqueia revisão e mostra erros', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('btn-revisar-contrato')));
    await tester.pumpAndSettle();

    // Permanece na fase de formulário (preview não aparece).
    expect(find.byKey(const Key('contract-preview')), findsNothing);
    expect(find.textContaining('Informe seu CPF.'), findsOneWidget);
    expect(find.textContaining('documento comprobatório'), findsWidgets);
  });

  testWidgets(
    'CA-7/8: revisar mostra contrato e botão de aceite só habilita com checkbox',
    (tester) async {
      await _pump(tester);
      await _preencher(tester);

      await tester.tap(find.byKey(const Key('btn-revisar-contrato')));
      await tester.pumpAndSettle();

      // Fase preview: contrato renderizado com dados do usuário.
      expect(find.byKey(const Key('contract-preview')), findsOneWidget);
      expect(find.textContaining('Maria Silva'), findsWidgets);
      expect(find.textContaining('111.444.777-35'), findsWidgets);

      // Botão de aceite começa DESABILITADO (checkbox não marcado).
      FilledButton botao() =>
          tester.widget<FilledButton>(find.byKey(const Key('btn-aceitar')));
      expect(botao().onPressed, isNull);

      // Marca o checkbox → habilita.
      await tester.tap(find.byKey(const Key('checkbox-aceite')));
      await tester.pumpAndSettle();
      expect(botao().onPressed, isNotNull);
    },
  );

  testWidgets(
    'CA-12: aceitar conclui o cadastro, marca sessão e mostra sucesso',
    (tester) async {
      final service = _FakeService();
      await _pump(tester, service: service);
      await _preencher(tester);

      await tester.tap(find.byKey(const Key('btn-revisar-contrato')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('checkbox-aceite')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn-aceitar')));
      await tester.pumpAndSettle();

      expect(service.completarCalls, 1);
      expect(find.byKey(const Key('completar-sucesso')), findsOneWidget);
      expect(find.text('Cadastro concluído!'), findsOneWidget);
      expect(AuthService().session!.cadastroCompleto, isTrue);
      expect(AuthService().session!.funnelState, FunnelState.active);
    },
  );

  testWidgets(
    'erro de validação do servidor volta ao formulário e exibe o erro',
    (tester) async {
      final service = _FakeService(
        completarResult: () => CadastroValidationError({
          'documento': 'Não foi possível usar este documento.',
        }),
      );
      await _pump(tester, service: service);
      await _preencher(tester);
      await tester.tap(find.byKey(const Key('btn-revisar-contrato')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('checkbox-aceite')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn-aceitar')));
      await tester.pumpAndSettle();

      // Voltou ao formulário (contrato sumiu) e mostra o erro do campo.
      expect(find.byKey(const Key('contract-preview')), findsNothing);
      expect(find.byKey(const Key('input-documento')), findsOneWidget);
      expect(
        find.textContaining('Não foi possível usar este documento.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('preview com erro mostra banner e não avança', (tester) async {
    final service = _FakeService(
      previewResult: () => PreviewError('Documento inválido.'),
    );
    await _pump(tester, service: service);
    await _preencher(tester);
    await tester.tap(find.byKey(const Key('btn-revisar-contrato')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('contract-preview')), findsNothing);
    expect(find.textContaining('Documento inválido.'), findsOneWidget);
  });

  testWidgets('CA-5: anexar documento exibe o nome do arquivo', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('btn-anexar-documentos')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lista-documentos')), findsOneWidget);
    expect(find.textContaining('rg.jpg'), findsOneWidget);
  });

  testWidgets('CA-5: documento com extensão inválida é rejeitado', (
    tester,
  ) async {
    await _pump(
      tester,
      docs: () async => [
        ArquivoUpload(bytes: Uint8List.fromList([1]), filename: 'malware.exe'),
      ],
    );
    await tester.tap(find.byKey(const Key('btn-anexar-documentos')));
    await tester.pumpAndSettle();
    expect(find.textContaining('JPG, PNG ou PDF'), findsWidgets);
  });
}
