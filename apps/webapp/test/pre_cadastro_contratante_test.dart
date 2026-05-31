import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turni_webapp/ds/theme.dart';
import 'package:turni_webapp/features/cadastro/contratante_cadastro_service.dart';
import 'package:turni_webapp/features/cadastro/pre_cadastro_contratante_screen.dart';

// STORY-018 — widget tests da tela de pré-cadastro de contratante (CA-2, CA-5, CA-6, CA-7).

/// Serviço fake — não toca a rede. Devolve uma função fixa de resultado.
class _FakeService extends ContratanteCadastroService {
  _FakeService(this._result);
  final CadastroResult Function() _result;

  @override
  Future<CadastroResult> cadastrar({
    required String name,
    required String email,
    required String telefone,
    required String nomeEstabelecimento,
    required String tipoOperacao,
    required String cidade,
    required String password,
    required String passwordConfirmation,
    required bool termosAceitos,
    required FotoUpload foto,
  }) async => _result();
}

Future<FotoUpload?> _fakePhoto() async =>
    FotoUpload(bytes: Uint8List.fromList([1, 2, 3]), filename: 'foto.jpg');

Future<void> _pump(
  WidgetTester tester, {
  required CadastroResult Function() result,
  Future<FotoUpload?> Function()? photo,
}) async {
  await tester.binding.setSurfaceSize(const Size(420, 3200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: buildLightTheme(),
      home: PreCadastroContratanteScreen(
        service: _FakeService(result),
        photoPicker: photo ?? _fakePhoto,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _fillValid(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('input-nome')), 'Maria Souza');
  await tester.enterText(
    find.byKey(const Key('input-email')),
    'maria@email.com',
  );
  await tester.enterText(
    find.byKey(const Key('input-telefone')),
    '(11) 91234-5678',
  );
  await tester.enterText(
    find.byKey(const Key('input-estabelecimento')),
    'Bar do Porto',
  );
  await tester.enterText(find.byKey(const Key('input-cidade')), 'São Paulo');
  await tester.enterText(
    find.byKey(const Key('input-password')),
    'SenhaForte10',
  );
  await tester.enterText(
    find.byKey(const Key('input-password-confirm')),
    'SenhaForte10',
  );

  // Tipo de operação (dropdown)
  await tester.tap(find.byKey(const Key('input-tipo-operacao')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Restaurante').last);
  await tester.pumpAndSettle();

  // Foto (via picker injetado)
  await tester.tap(find.byKey(const Key('input-foto')));
  await tester.pumpAndSettle();

  // Termos
  await tester.tap(find.byKey(const Key('check-termos')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renderiza os campos principais e o CTA (CA-2)', (tester) async {
    await _pump(tester, result: () => CadastroSuccess('ok'));

    expect(
      find.byKey(const Key('screen-cadastro-contratante')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('input-nome')), findsOneWidget);
    expect(find.byKey(const Key('input-email')), findsOneWidget);
    expect(find.byKey(const Key('input-estabelecimento')), findsOneWidget);
    expect(find.byKey(const Key('input-tipo-operacao')), findsOneWidget);
    expect(find.byKey(const Key('input-foto')), findsOneWidget);
    expect(find.byKey(const Key('check-termos')), findsOneWidget);
    expect(find.byKey(const Key('btn-submit-cadastro')), findsOneWidget);
    expect(find.text('Criar conta de estabelecimento'), findsOneWidget);
    // Contratante não tem tipo de pessoa.
    expect(find.byKey(const Key('segmented-tipo-pessoa')), findsNothing);
    // Rótulo de versão discreto no rodapé (STORY-037 CA-10).
    expect(
      find.byKey(const Key('app-version-label-cadastro-contratante')),
      findsOneWidget,
    );
  });

  testWidgets('submit vazio mostra erros de campo e bloqueia (CA-2/CA-5)', (
    tester,
  ) async {
    await _pump(tester, result: () => CadastroSuccess('ok'));

    await tester.tap(find.byKey(const Key('btn-submit-cadastro')));
    await tester.pumpAndSettle();

    expect(find.text('Informe o nome do responsável.'), findsOneWidget);
    expect(find.text('Informe o nome do estabelecimento.'), findsOneWidget);
    expect(find.text('Selecione o tipo de operação.'), findsOneWidget);
    expect(find.text('Adicione uma foto.'), findsOneWidget);
    expect(
      find.text(
        'É necessário aceitar os Termos de Uso e a Política de Privacidade.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('panel-cadastro-recebido')), findsNothing);
  });

  testWidgets('caminho feliz envia e mostra a tela de recebido (CA-7)', (
    tester,
  ) async {
    await _pump(tester, result: () => CadastroSuccess('Cadastro recebido.'));
    await _fillValid(tester);

    await tester.tap(find.byKey(const Key('btn-submit-cadastro')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('panel-cadastro-recebido')), findsOneWidget);
    expect(find.text('Cadastro recebido.'), findsOneWidget);
    expect(find.byKey(const Key('btn-voltar-home')), findsOneWidget);
  });

  testWidgets(
    'e-mail já existente mostra banner genérico sem enumeração (CA-4)',
    (tester) async {
      await _pump(
        tester,
        result: () => CadastroGenericError(
          'Não foi possível concluir o cadastro. Verifique os dados e tente novamente.',
        ),
      );
      await _fillValid(tester);

      await tester.tap(find.byKey(const Key('btn-submit-cadastro')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('banner-cadastro-erro')), findsOneWidget);
      expect(
        find.textContaining('Não foi possível concluir o cadastro'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('panel-cadastro-recebido')), findsNothing);
    },
  );

  testWidgets('senha fraca é bloqueada client-side', (tester) async {
    await _pump(tester, result: () => CadastroSuccess('ok'));
    await tester.enterText(find.byKey(const Key('input-password')), 'fraca');
    await tester.tap(find.byKey(const Key('btn-submit-cadastro')));
    await tester.pumpAndSettle();

    expect(find.textContaining('ao menos 10 caracteres'), findsOneWidget);
  });
}
