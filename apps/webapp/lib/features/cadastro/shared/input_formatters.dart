import 'package:flutter/services.dart';

/// Formatters de entrada do Turni (sem dependência externa — máscaras simples).

/// Máscara de documento: CPF `000.000.000-00` (isCpf) ou CNPJ `00.000.000/0000-00`.
class DocumentoInputFormatter extends TextInputFormatter {
  DocumentoInputFormatter({required this.isCpf});

  final bool isCpf;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final max = isCpf ? 11 : 14;
    if (digits.length > max) {
      digits = digits.substring(0, max);
    }

    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (isCpf) {
        if (i == 3 || i == 6) {
          buf.write('.');
        } else if (i == 9) {
          buf.write('-');
        }
      } else {
        if (i == 2 || i == 5) {
          buf.write('.');
        } else if (i == 8) {
          buf.write('/');
        } else if (i == 12) {
          buf.write('-');
        }
      }
      buf.write(digits[i]);
    }

    final text = buf.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Máscara monetária BRL baseada em centavos: o usuário digita dígitos e o valor
/// preenche da direita (ex.: "4500" → "45,00"; "123456" → "1.234,56").
class MoedaInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }
    if (digits.length > 11) {
      digits = digits.substring(0, 11); // teto defensivo
    }

    final centavos = int.parse(digits);
    final reais = centavos ~/ 100;
    final resto = centavos % 100;
    final reaisStr = reais.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]}.',
    );
    final text = '$reaisStr,${resto.toString().padLeft(2, '0')}';

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Converte um valor BRL mascarado ("1.234,56") para string numérica ("1234.56").
/// Vazio → string vazia (o validator/servidor cobra).
String brlParaNumero(String mascarado) =>
    mascarado.replaceAll('.', '').replaceAll(',', '.').trim();
