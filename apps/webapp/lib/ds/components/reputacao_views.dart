import 'package:flutter/material.dart';

import '../../core/time/turni_datetime.dart';
import '../tokens.dart';

// STORY-088 — componentes de reputação do DS (SCREEN-084 §3/§5/§6 / DDR-004).
// Entram no DS via DDR-004 (display.rating, badge.nivel, meter.xp, card.depoimento).
// Regras herdadas dos tokens: "nunca só cor" — estrela/ícone sempre acompanham número/texto;
// AA por construção (texto forte/muted). Os widgets são puros: recebem dados já calculados pela
// API (score/nível/XP recomputados — STORY-085) e só apresentam.

/// `display.rating` — score público de relance: média 1-casa + estrelas decorativas + contagem,
/// ou o selo "Novo" (DDR-004) enquanto a pessoa tem menos de 3 avaliações. As estrelas são
/// `ExcludeSemantics` (decorativas); o nó semântico anuncia o **número** (vírgula pt-BR) ou o selo.
class TurniRatingDisplay extends StatelessWidget {
  const TurniRatingDisplay({
    super.key,
    required this.score,
    required this.totalAvaliacoes,
    required this.seloNovo,
    required this.accent,
  });

  final double score;
  final int totalAvaliacoes;
  final bool seloNovo;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textStrong = isDark
        ? TurniColors.textStrongDark
        : TurniColors.textStrongLight;
    final textMuted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;

    final Widget visual;
    final String semantica;

    if (seloNovo) {
      final selo = totalAvaliacoes == 0
          ? 'Novo na plataforma'
          : 'Novo · $totalAvaliacoes ${totalAvaliacoes == 1 ? 'avaliação' : 'avaliações'}';
      semantica = selo;
      visual = Container(
        padding: const EdgeInsets.symmetric(
          horizontal: TurniSpacing.sm,
          vertical: TurniSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: const BorderRadius.all(TurniRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 16, color: accent),
            const SizedBox(width: TurniSpacing.xs),
            Text(
              selo,
              style: TextStyle(
                color: accent,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    } else {
      final scoreTxt = score.toStringAsFixed(1);
      final contagem =
          '$totalAvaliacoes ${totalAvaliacoes == 1 ? 'avaliação' : 'avaliações'}';
      semantica = '${scoreTxt.replaceAll('.', ',')} de 5, $contagem';
      visual = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            scoreTxt,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: textStrong,
              height: 1,
            ),
          ),
          const SizedBox(width: TurniSpacing.xs),
          Icon(Icons.star_rounded, size: 24, color: accent),
          const SizedBox(width: TurniSpacing.sm),
          Text(contagem, style: TextStyle(color: textMuted, fontSize: 14)),
        ],
      );
    }

    return Semantics(
      key: const Key('perfil-score'),
      container: true,
      label: semantica,
      child: ExcludeSemantics(child: visual),
    );
  }
}

/// `badge.nivel` — nível do profissional (Iniciante/Confiável/Destaque/Elite) como pílula com
/// ícone + **texto** (nunca só ícone — a11y). O valor persistido sem acento ("Confiavel") vira o
/// rótulo acentuado de exibição. Só aparece no perfil do profissional (contratante não tem nível).
class TurniNivelBadge extends StatelessWidget {
  const TurniNivelBadge({super.key, required this.nivel});

  final String nivel;

  /// Valor persistido (enum NivelProfissional) → rótulo de exibição (SCREEN-084 §5).
  static const _rotulos = {
    'Iniciante': 'Iniciante',
    'Confiavel': 'Confiável',
    'Destaque': 'Destaque',
    'Elite': 'Elite',
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? TurniColors.accentDark : TurniColors.accentLight;
    final rotulo = _rotulos[nivel] ?? nivel;

    return Container(
      key: const Key('perfil-nivel-badge'),
      padding: const EdgeInsets.symmetric(
        horizontal: TurniSpacing.sm,
        vertical: TurniSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: const BorderRadius.all(TurniRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_rounded, size: 16, color: accent),
          const SizedBox(width: TurniSpacing.xs),
          Text(
            rotulo,
            style: TextStyle(
              color: accent,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// `meter.xp` — progresso de XP até o próximo nível (só profissional, e só para o próprio dono —
/// XP é privado, STORY-085). Barra + rótulo textual ("Faltam {k} XP para {próximo nível}") — a
/// barra nunca informa sozinha (a11y: `Semantics(value:)`). No topo da trilha (Elite), não há
/// próximo nível: barra cheia + "Nível máximo alcançado".
class TurniXpMeter extends StatelessWidget {
  const TurniXpMeter({
    super.key,
    required this.xp,
    required this.xpProximoNivel,
    required this.nivel,
    required this.accent,
  });

  final int xp;

  /// XP que falta para o próximo limiar; `null` = nível máximo (Elite).
  final int? xpProximoNivel;

  /// Nível atual (enum) — usado para nomear o próximo nível no rótulo.
  final String nivel;
  final Color accent;

  /// Próximo nível na trilha (rótulo de exibição) a partir do atual.
  static const _proximo = {
    'Iniciante': 'Confiável',
    'Confiavel': 'Destaque',
    'Destaque': 'Elite',
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;
    final trilho = isDark
        ? TurniColors.borderSubtleDark
        : TurniColors.borderSubtleLight;

    final maxNivel = xpProximoNivel == null;
    final total = maxNivel ? xp : xp + xpProximoNivel!;
    final valor = maxNivel || total == 0 ? 1.0 : xp / total;
    final rotulo = maxNivel
        ? 'Nível máximo alcançado'
        : 'Faltam $xpProximoNivel XP para ${_proximo[nivel] ?? 'o próximo nível'}';

    return Semantics(
      key: const Key('perfil-xp-meter'),
      value: rotulo,
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'XP',
                style: TextStyle(
                  color: textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(width: TurniSpacing.sm),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(TurniRadius.full),
                  child: LinearProgressIndicator(
                    value: valor,
                    minHeight: 8,
                    backgroundColor: trilho,
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
              ),
              if (!maxNivel) ...[
                const SizedBox(width: TurniSpacing.sm),
                Text(
                  '$xp/$total',
                  style: TextStyle(color: textMuted, fontSize: 12),
                ),
              ],
            ],
          ),
          const SizedBox(height: TurniSpacing.xs),
          ExcludeSemantics(
            child: Text(
              rotulo,
              style: TextStyle(color: textMuted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// `card.depoimento` — uma avaliação recebida com comentário: estrelas (decorativas) + texto +
/// linha de autor. Nominal (sobre o profissional): "{Estabelecimento} · {Função} · {data}".
/// Anônimo (sobre o contratante, LGPD/DDR-004): "Profissional · {Função} · {data}" — sem nome.
/// `data` vira data relativa pt-BR (TurniDateTime.tempoRelativo).
class TurniDepoimentoCard extends StatelessWidget {
  const TurniDepoimentoCard({
    super.key,
    required this.estrelas,
    required this.comentario,
    required this.autorNome,
    required this.funcao,
    required this.data,
    required this.accent,
  });

  final int estrelas;
  final String comentario;

  /// Nome do estabelecimento (nominal) ou `null` (anônimo → "Profissional").
  final String? autorNome;
  final String? funcao;
  final DateTime? data;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? TurniColors.surfaceDark : TurniColors.surfaceLight;
    final border = isDark
        ? TurniColors.borderSubtleDark
        : TurniColors.borderSubtleLight;
    final textStrong = isDark
        ? TurniColors.textStrongDark
        : TurniColors.textStrongLight;
    final textMuted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;
    final vazio = isDark
        ? TurniColors.borderSubtleDark
        : TurniColors.borderSubtleLight;

    final autor = autorNome ?? 'Profissional';
    final partes = <String>[
      autor,
      if (funcao != null && funcao!.isNotEmpty) funcao!,
      if (data != null) TurniDateTime.tempoRelativo(data!),
    ];

    return Container(
      padding: const EdgeInsets.all(TurniSpacing.md),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.all(TurniRadius.md),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (i) {
                final cheia = i < estrelas;
                return Icon(
                  cheia ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 16,
                  color: cheia ? accent : vazio,
                );
              }),
            ),
          ),
          const SizedBox(height: TurniSpacing.xs),
          Semantics(
            label: '$estrelas de 5 estrelas',
            child: Text(
              comentario,
              style: TextStyle(color: textStrong, fontSize: 14.5, height: 1.4),
            ),
          ),
          const SizedBox(height: TurniSpacing.xs),
          Text(
            partes.join(' · '),
            style: TextStyle(color: textMuted, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}
