import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turni_webapp/features/cadastro/shared/input_formatters.dart';

// STORY-023 — máscaras de digitação (CPF/CNPJ + valor monetário).

String _aplica(TextInputFormatter f, String entrada) => f
    .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: entrada))
    .text;

void main() {
  group('DocumentoInputFormatter', () {
    test('mascara CPF e limita a 11 dígitos', () {
      final f = DocumentoInputFormatter('CPF');
      expect(_aplica(f, '11144477735'), '111.444.777-35');
      expect(_aplica(f, '111'), '111');
      expect(_aplica(f, '1114447'), '111.444.7');
      expect(
        _aplica(f, '111444777359999'),
        '111.444.777-35',
      ); // excedente cortado
    });

    test('mascara CNPJ e limita a 14 dígitos', () {
      final f = DocumentoInputFormatter('CNPJ');
      expect(_aplica(f, '11222333000181'), '11.222.333/0001-81');
      expect(_aplica(f, '112223330001819999'), '11.222.333/0001-81');
    });
  });

  group('MoedaInputFormatter', () {
    final f = MoedaInputFormatter();
    test('preenche centavos da direita para a esquerda', () {
      expect(_aplica(f, '4'), 'R\$ 0,04');
      expect(_aplica(f, '45'), 'R\$ 0,45');
      expect(_aplica(f, '4500'), 'R\$ 45,00');
      expect(_aplica(f, '450000'), 'R\$ 4.500,00');
    });
    test('vazio fica vazio', () {
      expect(_aplica(f, ''), '');
      expect(_aplica(f, 'abc'), '');
    });
  });

  group('moedaParaNumero', () {
    test('converte texto mascarado em número', () {
      expect(moedaParaNumero('R\$ 45,00'), 45.0);
      expect(moedaParaNumero('R\$ 4.500,00'), 4500.0);
      expect(moedaParaNumero(''), 0);
    });
  });
}
