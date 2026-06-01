import 'package:flutter/services.dart';

/// Máscaras de digitação do completar cadastro (STORY-023): documento por tipo_pessoa
/// (CPF `000.000.000-00` / CNPJ `00.000.000/0000-00`) e valor monetário em centavos
/// (`R$ 1.234,56`). O backend valida dígitos verificadores e numérico — aqui é só UX.

/// Formata CPF (PF) ou CNPJ (MEI/PJ) conforme digita; descarta não-dígitos e limita o
/// comprimento ao do documento.
class DocumentoInputFormatter extends TextInputFormatter {
  DocumentoInputFormatter(this.tipoDocumento); // 'CPF' | 'CNPJ'

  final String tipoDocumento;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final cpf = tipoDocumento == 'CPF';
    final max = cpf ? 11 : 14;
    var d = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (d.length > max) d = d.substring(0, max);

    final masked = cpf ? _mascaraCpf(d) : _mascaraCnpj(d);
    return TextEditingValue(
      text: masked,
      selection: TextSelection.collapsed(offset: masked.length),
    );
  }

  String _mascaraCpf(String d) {
    final b = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i == 3 || i == 6) b.write('.');
      if (i == 9) b.write('-');
      b.write(d[i]);
    }
    return b.toString();
  }

  String _mascaraCnpj(String d) {
    final b = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i == 2 || i == 5) b.write('.');
      if (i == 8) b.write('/');
      if (i == 12) b.write('-');
      b.write(d[i]);
    }
    return b.toString();
  }
}

/// Formata valor monetário em centavos conforme digita: os dígitos preenchem da direita
/// para a esquerda (`4` → `R$ 0,04`, `4500` → `R$ 45,00`, `450000` → `R$ 4.500,00`).
class MoedaInputFormatter extends TextInputFormatter {
  static const _maxDigitos = 9; // até R$ 9.999.999,99

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var d = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (d.isEmpty) return const TextEditingValue();
    if (d.length > _maxDigitos) d = d.substring(0, _maxDigitos);

    final texto = 'R\$ ${_formatarCentavos(int.parse(d))}';
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }

  static String _formatarCentavos(int centavos) {
    final reais = (centavos ~/ 100).toString();
    final dec = (centavos % 100).toString().padLeft(2, '0');

    final b = StringBuffer();
    for (var i = 0; i < reais.length; i++) {
      if (i > 0 && (reais.length - i) % 3 == 0) b.write('.');
      b.write(reais[i]);
    }
    return '$b,$dec';
  }
}

/// Converte o texto monetário (`R$ 1.234,56`) no número (`1234.56`) que o backend espera.
double moedaParaNumero(String texto) {
  final d = texto.replaceAll(RegExp(r'\D'), '');
  if (d.isEmpty) return 0;
  return int.parse(d) / 100;
}
