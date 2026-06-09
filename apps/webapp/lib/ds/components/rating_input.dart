import 'package:flutter/material.dart';

import '../tokens.dart';

/// STORY-087 — `input.rating` do DS (SCREEN-084 §3/§5/§6). Cinco estrelas obrigatórias
/// (1–5): alvos ≥48dp, centradas; a estrela cheia/vazia se distingue pelo ÍCONE
/// (`star_rounded` × `star_border_rounded`), não só pela cor (regra de ouro dos tokens —
/// AA). O helper textual abaixo duplica a informação da cor: "Toque para avaliar" quando
/// vazio, e a palavra do nível ("Ruim".."Ótimo") quando escolhido. Em erro, a mensagem
/// associada substitui o helper (vinculada ao grupo, não global).
///
/// Estado é do chamador (a tela controla o `value` e o `errorText`) — o widget é um
/// controle puro: emite `onChanged(n)` ao tocar a n-ésima estrela.
class TurniRatingInput extends StatelessWidget {
  const TurniRatingInput({
    super.key,
    required this.value,
    required this.onChanged,
    required this.accent,
    this.errorText,
  });

  /// Valor atual: 0 = nenhuma escolhida; 1–5 escolhido.
  final int value;

  /// Emite a estrela tocada (1–5).
  final ValueChanged<int> onChanged;

  /// Cor da estrela preenchida (acento do perfil — sage/mostarda).
  final Color accent;

  /// Quando não-nulo, substitui o helper por uma mensagem de erro associada.
  final String? errorText;

  /// Palavra do nível por valor (SCREEN-084 §5).
  static const _palavras = {
    1: 'Ruim',
    2: 'Regular',
    3: 'Bom',
    4: 'Muito bom',
    5: 'Ótimo',
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;
    final vazio = isDark
        ? TurniColors.borderSubtleDark
        : TurniColors.borderSubtleLight;
    final errorInk = isDark ? TurniColors.errorDark : TurniColors.errorLight;

    final helper = value >= 1 && value <= 5
        ? _palavras[value]!
        : 'Toque para avaliar';

    return Semantics(
      key: const Key('avaliacao-estrelas'),
      container: true,
      label: value >= 1
          ? 'Avaliação, $value de 5 estrelas'
          : 'Avaliação, nenhuma estrela escolhida',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final n = i + 1;
              final cheia = n <= value;
              return Semantics(
                button: true,
                label: '$n ${n == 1 ? 'estrela' : 'estrelas'}',
                selected: cheia,
                child: IconButton(
                  key: Key('avaliacao-estrela-$n'),
                  iconSize: 40,
                  // Alvo ≥48dp (40 do ícone + padding) — toque confortável (§6).
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  tooltip: '$n ${n == 1 ? 'estrela' : 'estrelas'}',
                  onPressed: () => onChanged(n),
                  icon: ExcludeSemantics(
                    child: Icon(
                      cheia ? Icons.star_rounded : Icons.star_border_rounded,
                      color: cheia ? accent : vazio,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: TurniSpacing.xs),
          if (errorText != null)
            Semantics(
              liveRegion: true,
              child: Text(
                errorText!,
                key: const Key('avaliacao-estrelas-erro'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: errorInk,
                ),
              ),
            )
          else
            Text(
              helper,
              key: const Key('avaliacao-estrelas-helper'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: textMuted,
                fontWeight: value >= 1 ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
        ],
      ),
    );
  }
}
