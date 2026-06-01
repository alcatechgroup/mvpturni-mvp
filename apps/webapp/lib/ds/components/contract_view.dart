import 'package:flutter/material.dart';

import '../tokens.dart';

/// Renderizador leve de Markdown para o contrato do aceite (STORY-023 CA-7).
///
/// Sem dependência externa: o conteúdo vem do servidor (texto jurídico já renderizado,
/// com placeholders substituídos) e usa um subconjunto previsível — títulos (`#`..`###`),
/// negrito (`**`), divisórias (`---`), itens (`-`) e linhas de tabela (`|`). Foco em
/// legibilidade (escala de fonte/espaçamento) e tema dual. Texto selecionável (a11y).
class ContractView extends StatelessWidget {
  const ContractView(this.markdown, {super.key});

  final String markdown;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? TurniColors.textStrongDark
        : TurniColors.textStrongLight;
    final mutedColor = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;

    final blocks = <Widget>[];
    for (final rawLine in markdown.split('\n')) {
      final line = rawLine.trimRight();

      if (line.trim().isEmpty) {
        blocks.add(const SizedBox(height: TurniSpacing.sm));
        continue;
      }
      if (line.trim() == '---') {
        blocks.add(
          const Padding(
            padding: EdgeInsets.symmetric(vertical: TurniSpacing.sm),
            child: Divider(height: 1),
          ),
        );
        continue;
      }
      if (line.startsWith('### ')) {
        blocks.add(_heading(context, line.substring(4), 16));
        continue;
      }
      if (line.startsWith('## ')) {
        blocks.add(_heading(context, line.substring(3), 19));
        continue;
      }
      if (line.startsWith('# ')) {
        blocks.add(_heading(context, line.substring(2), 23));
        continue;
      }
      // Linha de tabela markdown — monospace, preserva alinhamento de colunas.
      if (line.trimLeft().startsWith('|')) {
        if (RegExp(r'^\s*\|[\s:|-]+\|?\s*$').hasMatch(line)) {
          continue; // separador de cabeçalho (|---|---|) — não renderiza
        }
        blocks.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: SelectableText(
              line.replaceAll('**', ''),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: textColor,
              ),
            ),
          ),
        );
        continue;
      }
      final bullet = line.trimLeft().startsWith('- ');
      blocks.add(
        Padding(
          padding: EdgeInsets.only(
            top: 2,
            bottom: 2,
            left: bullet ? TurniSpacing.md : 0,
          ),
          child: SelectableText.rich(
            _inline(
              bullet ? '• ${line.trimLeft().substring(2)}' : line,
              textColor,
            ),
            style: TextStyle(fontSize: 14, height: 1.5, color: textColor),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...blocks,
        const SizedBox(height: TurniSpacing.sm),
        Text(
          'Leia o contrato por inteiro antes de aceitar.',
          style: TextStyle(
            fontSize: 12,
            fontStyle: FontStyle.italic,
            color: mutedColor,
          ),
        ),
      ],
    );
  }

  Widget _heading(BuildContext context, String text, double size) {
    return Padding(
      padding: const EdgeInsets.only(
        top: TurniSpacing.sm,
        bottom: TurniSpacing.xs,
      ),
      child: SelectableText.rich(
        _inline(
          text,
          Theme.of(context).brightness == Brightness.dark
              ? TurniColors.textStrongDark
              : TurniColors.textStrongLight,
        ),
        style: TextStyle(fontSize: size, fontWeight: FontWeight.w700),
      ),
    );
  }

  /// Converte `**negrito**` em TextSpans; o resto é texto normal.
  TextSpan _inline(String text, Color color) {
    final spans = <TextSpan>[];
    final parts = text.split('**');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      spans.add(
        TextSpan(
          text: parts[i],
          style: TextStyle(
            color: color,
            fontWeight: i.isOdd ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      );
    }
    return TextSpan(children: spans);
  }
}
