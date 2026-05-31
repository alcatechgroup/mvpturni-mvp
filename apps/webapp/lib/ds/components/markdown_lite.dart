import 'package:flutter/material.dart';

/// STORY-023 — Renderizador de markdown **mínimo** (sem dependência externa) para exibir
/// o contrato de adesão formatado: headings (#/##/###), negrito (**), itálico (*),
/// divisórias (---), listas (- ) e tabelas (| | |). Cobre exatamente o que o texto-seed
/// dos templates usa — não é um motor de markdown completo.
class MarkdownLite extends StatelessWidget {
  const MarkdownLite({
    super.key,
    required this.data,
    required this.color,
    required this.muted,
  });

  final String data;
  final Color color;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _blocks(),
      ),
    );
  }

  List<Widget> _blocks() {
    final lines = data.replaceAll('\r\n', '\n').split('\n');
    final out = <Widget>[];

    for (var i = 0; i < lines.length;) {
      final line = lines[i];
      final t = line.trim();

      if (t.isEmpty) {
        out.add(const SizedBox(height: 8));
        i++;
        continue;
      }
      if (RegExp(r'^([-*_])\1{2,}$').hasMatch(t)) {
        out.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: muted.withAlpha(90)),
          ),
        );
        i++;
        continue;
      }
      if (t.startsWith('### ')) {
        out.add(_heading(t.substring(4), 15));
        i++;
        continue;
      }
      if (t.startsWith('## ')) {
        out.add(_heading(t.substring(3), 18));
        i++;
        continue;
      }
      if (t.startsWith('# ')) {
        out.add(_heading(t.substring(2), 22));
        i++;
        continue;
      }
      // Tabela: bloco contíguo de linhas que começam com `|`.
      if (t.startsWith('|')) {
        final block = <String>[];
        while (i < lines.length && lines[i].trim().startsWith('|')) {
          block.add(lines[i].trim());
          i++;
        }
        out.add(_table(block));
        continue;
      }
      if (t.startsWith('- ') || t.startsWith('* ')) {
        out.add(_bullet(t.substring(2)));
        i++;
        continue;
      }
      out.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text.rich(
            TextSpan(children: _inline(t, _body())),
            style: _body(),
          ),
        ),
      );
      i++;
    }
    return out;
  }

  TextStyle _body() => TextStyle(fontSize: 14, height: 1.5, color: color);

  Widget _heading(String text, double size) => Padding(
    padding: EdgeInsets.only(top: size >= 18 ? 14 : 10, bottom: 4),
    child: Text.rich(
      TextSpan(
        children: _inline(
          text,
          TextStyle(fontSize: size, fontWeight: FontWeight.w700, color: color),
        ),
      ),
    ),
  );

  Widget _bullet(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 2, left: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, right: 8),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: muted, shape: BoxShape.circle),
          ),
        ),
        Expanded(child: Text.rich(TextSpan(children: _inline(text, _body())))),
      ],
    ),
  );

  Widget _table(List<String> rows) {
    // Remove a linha separadora (ex.: |---|---|) e parte as células por `|`.
    bool isSep(String r) =>
        RegExp(r'^\|[\s:|-]+\|$').hasMatch(r) && r.contains('-');
    final dataRows = rows.where((r) => !isSep(r)).toList();

    List<String> cells(String r) {
      var s = r.trim();
      if (s.startsWith('|')) s = s.substring(1);
      if (s.endsWith('|')) s = s.substring(0, s.length - 1);
      return s.split('|').map((c) => c.trim()).toList();
    }

    final parsed = dataRows.map(cells).toList();
    if (parsed.isEmpty) return const SizedBox.shrink();
    final cols = parsed.map((r) => r.length).reduce((a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Table(
        border: TableBorder.all(color: muted.withAlpha(100)),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(1.4)},
        children: [
          for (final row in parsed)
            TableRow(
              children: [
                for (var c = 0; c < cols; c++)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Text.rich(
                      TextSpan(
                        children: _inline(
                          c < row.length ? row[c] : '',
                          _body().copyWith(fontSize: 13),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  /// Negrito `**x**` e itálico `*x*` inline.
  List<InlineSpan> _inline(String text, TextStyle base) {
    final spans = <InlineSpan>[];
    final re = RegExp(r'(\*\*[^*]+\*\*|\*[^*]+\*)');
    var last = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start), style: base));
      }
      final tok = m.group(0)!;
      if (tok.startsWith('**')) {
        spans.add(
          TextSpan(
            text: tok.substring(2, tok.length - 2),
            style: base.copyWith(fontWeight: FontWeight.w700),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: tok.substring(1, tok.length - 1),
            style: base.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      }
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last), style: base));
    }
    return spans;
  }
}
