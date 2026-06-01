import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turni_webapp/ds/theme.dart';
import 'package:turni_webapp/features/auth/auth_service.dart';
import 'package:turni_webapp/features/cadastro/completar_cadastro_contratante_screen.dart';
import 'package:turni_webapp/features/cadastro/completar_cadastro_contratante_service.dart';
import 'package:turni_webapp/features/cadastro/shared/cadastro_types.dart';

// STORY-024 — widget tests do completar cadastro do contratante (CA-1/2/4/7/8/12).

class _FakeService extends CompletarCadastroContratanteService {
  _FakeService({this.cep, this.previewResult, this.completarResult});

  final EnderecoCep? cep;
  final PreviewResult Function()? previewResult;
  final CadastroResult Function()? completarResult;
  int completarCalls = 0;
  Map<String, String>? ultimoCampos;

  @override
  Future<CompletarContratanteContexto?> fetchContexto() async =>
      const CompletarContratanteContexto(
        nome: 'Zé Responsável',
        nomeEstabelecimento: 'Bar do Zé',
        cidade: 'São Paulo',
      );

  @override
  Future<EnderecoCep?> buscarCep(String cep) async => this.cep;

  @override
  Future<PreviewResult> preview(Map<String, String> dados) async =>
      previewResult?.call() ??
      PreviewSuccess(
        '# Termos de Adesão à Plataforma — Contratante\n\n'
        '## Seção 1\nRazão Social: **Bar do Zé**\nCNPJ: 11.222.333/0001-81\n'
        'Taxa Turni: 15%\n\n## Assinatura\n— preenchido no momento do aceite —',
      );

  @override
  Future<CadastroResult> completar({
    required Map<String, String> campos,
    FotoUpload? logo,
  }) async {
    completarCalls++;
    ultimoCampos = campos;
    return completarResult?.call() ?? CadastroSuccess('Cadastro concluído!');
  }
}

UserSession _contratanteSession() => const UserSession(
  name: 'Zé Responsável',
  role: 'contratante',
  status: 'liberado',
  welcomeVisto: true,
  cadastroCompleto: false,
);

Future<void> _pump(WidgetTester tester, {_FakeService? service}) async {
  await tester.binding.setSurfaceSize(const Size(480, 3000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: buildLightTheme(),
      home: CompletarCadastroContratanteScreen(
        service: service ?? _FakeService(),
        logoPicker: () async => FotoUpload(
          bytes: Uint8List.fromList([1, 2, 3]),
          filename: 'logo.png',
        ),
        auth: AuthService()..debugSetSession(_contratanteSession()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _selecionarDropdown(
  WidgetTester tester,
  String fieldKey,
  String valor,
) async {
  await tester.ensureVisible(find.byKey(Key(fieldKey)));
  await tester.tap(find.byKey(Key(fieldKey)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(valor).last);
  await tester.pumpAndSettle();
}

Future<void> _preencherPasso1(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('completar-cadastro:cnpj')),
    '11222333000181',
  );
  await tester.enterText(
    find.byKey(const Key('completar-cadastro:cep')),
    '01001000',
  );
  await tester.enterText(
    find.byKey(const Key('completar-cadastro:logradouro')),
    'Praça da Sé',
  );
  await tester.enterText(
    find.byKey(const Key('completar-cadastro:numero')),
    '100',
  );
  await tester.enterText(
    find.byKey(const Key('completar-cadastro:bairro')),
    'Sé',
  );
  await _selecionarDropdown(tester, 'completar-cadastro:uf', 'SP');
}

Future<void> _avancar(WidgetTester tester) async {
  await tester.ensureVisible(
    find.byKey(const Key('completar-cadastro:continuar')),
  );
  await tester.tap(find.byKey(const Key('completar-cadastro:continuar')));
  await tester.pumpAndSettle();
}

Future<void> _preencherPasso2(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('completar-cadastro:segmento')),
    'Bar e petiscaria',
  );
  await tester.enterText(
    find.byKey(const Key('completar-cadastro:ano-fundacao')),
    '2015',
  );
  await _selecionarDropdown(
    tester,
    'completar-cadastro:qtd-funcionarios',
    '11-50',
  );
}

/// Vai do passo 1 até a fase de preview (passo 1 → 2 → 3 → Revisar).
Future<void> _ateoPreview(WidgetTester tester) async {
  await _preencherPasso1(tester);
  await _avancar(tester);
  await _preencherPasso2(tester);
  await _avancar(tester);
  await tester.ensureVisible(
    find.byKey(const Key('completar-cadastro:revisar')),
  );
  await tester.tap(find.byKey(const Key('completar-cadastro:revisar')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'CA-1: renderiza o passo 1 com CNPJ e título do estabelecimento',
    (tester) async {
      await _pump(tester);
      expect(
        find.byKey(const Key('completar-cadastro:screen')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('completar-cadastro:cnpj')), findsOneWidget);
      expect(find.textContaining('Bar do Zé'), findsOneWidget);
    },
  );

  testWidgets('CA-2: passo 1 vazio bloqueia avanço e mostra erros', (
    tester,
  ) async {
    await _pump(tester);
    // cidade vem pré-preenchida; limpa para validar o estado vazio.
    await tester.enterText(
      find.byKey(const Key('completar-cadastro:cidade')),
      '',
    );
    await tester.tap(find.byKey(const Key('completar-cadastro:continuar')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Informe o CNPJ'), findsOneWidget);
    // Não avançou: segmento (passo 2) não aparece.
    expect(find.byKey(const Key('completar-cadastro:segmento')), findsNothing);
  });

  testWidgets('CA-4: buscar CEP preenche logradouro/bairro/cidade/UF', (
    tester,
  ) async {
    final service = _FakeService(
      cep: const EnderecoCep(
        logradouro: 'Praça da Sé',
        bairro: 'Sé',
        cidade: 'São Paulo',
        uf: 'SP',
      ),
    );
    await _pump(tester, service: service);
    await tester.enterText(
      find.byKey(const Key('completar-cadastro:cep')),
      '01001000',
    );
    await tester.tap(find.byKey(const Key('completar-cadastro:cep-buscar')));
    await tester.pumpAndSettle();

    final logradouro = tester.widget<TextFormField>(
      find.byKey(const Key('completar-cadastro:logradouro')),
    );
    expect(logradouro.controller?.text, 'Praça da Sé');
  });

  testWidgets('CA-4: CEP não encontrado mostra aviso não-bloqueante', (
    tester,
  ) async {
    final service = _FakeService(cep: null); // serviço retorna null (falha/404)
    await _pump(tester, service: service);
    await tester.enterText(
      find.byKey(const Key('completar-cadastro:cep')),
      '99999999',
    );
    await tester.tap(find.byKey(const Key('completar-cadastro:cep-buscar')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('preencha o endereço manualmente'),
      findsOneWidget,
    );
  });

  testWidgets('wizard: navega passo 1 → 2 → 3 e contatos add/remove', (
    tester,
  ) async {
    await _pump(tester);
    await _preencherPasso1(tester);
    await _avancar(tester);
    expect(
      find.byKey(const Key('completar-cadastro:segmento')),
      findsOneWidget,
    );

    await _preencherPasso2(tester);
    await _avancar(tester);
    expect(find.byKey(const Key('completar-cadastro:cultura')), findsOneWidget);

    // Adiciona um contato e depois remove (lista dinâmica).
    await tester.ensureVisible(
      find.byKey(const Key('completar-cadastro:contato-add')),
    );
    await tester.tap(find.byKey(const Key('completar-cadastro:contato-add')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('completar-cadastro:contato-0-nome')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const Key('completar-cadastro:contato-0-remover')),
    );
    await tester.tap(
      find.byKey(const Key('completar-cadastro:contato-0-remover')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('completar-cadastro:contato-0-nome')),
      findsNothing,
    );
  });

  testWidgets(
    'CA-7/8: revisar mostra termos e botão só habilita com checkbox',
    (tester) async {
      await _pump(tester);
      await _ateoPreview(tester);

      expect(
        find.byKey(const Key('completar-cadastro:contrato')),
        findsOneWidget,
      );
      expect(find.textContaining('Bar do Zé'), findsWidgets);
      expect(find.textContaining('15%'), findsWidgets);

      FilledButton botao() => tester.widget<FilledButton>(
        find.byKey(const Key('completar-cadastro:concluir')),
      );
      expect(botao().onPressed, isNull);

      await tester.tap(find.byKey(const Key('completar-cadastro:aceite')));
      await tester.pumpAndSettle();
      expect(botao().onPressed, isNotNull);
    },
  );

  testWidgets('CA-12: aceitar conclui, marca sessão ativa e mostra sucesso', (
    tester,
  ) async {
    final service = _FakeService();
    await _pump(tester, service: service);
    await _ateoPreview(tester);
    await tester.tap(find.byKey(const Key('completar-cadastro:aceite')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('completar-cadastro:concluir')));
    await tester.pumpAndSettle();

    expect(service.completarCalls, 1);
    // Envia o CNPJ (mascarado — o backend normaliza) e a faixa selecionada.
    expect(service.ultimoCampos?['cnpj'], '11.222.333/0001-81');
    expect(service.ultimoCampos?['qtd_funcionarios'], '11-50');
    expect(find.byKey(const Key('completar-cadastro:sucesso')), findsOneWidget);
    expect(AuthService().session!.cadastroCompleto, isTrue);
    expect(AuthService().session!.funnelState, FunnelState.active);
  });

  testWidgets(
    'erro de validação do servidor volta ao formulário e exibe o erro',
    (tester) async {
      final service = _FakeService(
        completarResult: () => CadastroValidationError({
          'cnpj': 'Não foi possível usar este CNPJ.',
        }),
      );
      await _pump(tester, service: service);
      await _ateoPreview(tester);
      await tester.tap(find.byKey(const Key('completar-cadastro:aceite')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('completar-cadastro:concluir')));
      await tester.pumpAndSettle();

      // Voltou ao formulário (no passo 1, que contém o cnpj) e mostra o erro.
      expect(
        find.byKey(const Key('completar-cadastro:contrato')),
        findsNothing,
      );
      expect(find.byKey(const Key('completar-cadastro:cnpj')), findsOneWidget);
      expect(
        find.textContaining('Não foi possível usar este CNPJ.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('preview com erro mostra banner e não avança', (tester) async {
    final service = _FakeService(
      previewResult: () => PreviewError('Não foi possível carregar os termos.'),
    );
    await _pump(tester, service: service);
    await _preencherPasso1(tester);
    await _avancar(tester);
    await _preencherPasso2(tester);
    await _avancar(tester);
    await tester.ensureVisible(
      find.byKey(const Key('completar-cadastro:revisar')),
    );
    await tester.tap(find.byKey(const Key('completar-cadastro:revisar')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('completar-cadastro:contrato')), findsNothing);
    expect(
      find.textContaining('Não foi possível carregar os termos.'),
      findsOneWidget,
    );
  });

  testWidgets('CA-5: logo com extensão inválida é rejeitada', (tester) async {
    await tester.binding.setSurfaceSize(const Size(480, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: CompletarCadastroContratanteScreen(
          service: _FakeService(),
          logoPicker: () async =>
              FotoUpload(bytes: Uint8List.fromList([1]), filename: 'logo.exe'),
          auth: AuthService()..debugSetSession(_contratanteSession()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _preencherPasso1(tester);
    await _avancar(tester);
    await _preencherPasso2(tester);
    await _avancar(tester);

    await tester.ensureVisible(
      find.byKey(const Key('completar-cadastro:logo-anexar')),
    );
    await tester.tap(find.byKey(const Key('completar-cadastro:logo-anexar')));
    await tester.pumpAndSettle();
    expect(find.textContaining('JPG ou PNG'), findsOneWidget);
  });
}
