/// Formatação monetária pt-BR sem dependência de intl (DDR-002).
///
/// Promovido de helper privado (4º uso: feed, minhas vagas, detalhe da vaga e o dialog de
/// aceite da STORY-058 — regra de três estourada). Mesmo comportamento dos originais.
library;

String _dois(int n) => n.toString().padLeft(2, '0');

/// "R$ 1.234,56" a partir de um double (reais).
String formatBRL(double valor) {
  final centavos = (valor * 100).round();
  final reais = (centavos ~/ 100).toString();
  final cents = _dois(centavos % 100);
  final buf = StringBuffer();
  for (var i = 0; i < reais.length; i++) {
    if (i > 0 && (reais.length - i) % 3 == 0) buf.write('.');
    buf.write(reais[i]);
  }
  return 'R\$ $buf,$cents';
}

/// "R$ 1.234,56" a partir da string decimal do backend ("1234.56" — cast decimal:2).
String formatBRLDecimal(String valorDecimal) =>
    formatBRL(double.tryParse(valorDecimal) ?? 0);
